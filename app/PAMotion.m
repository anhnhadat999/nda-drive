#import "PAMotion.h"
#import <CoreMotion/CoreMotion.h>
#import "PALog.h"
#import "PADiag.h"

@implementation PAMotion {
    double _newIntv, _lastNewWall, _lastRawSpeed, _lastRawCourse; int _newFixFlag; BOOL _fromCar;
    PASynth *_synth;
    PAFusion _f;
    CMMotionManager *_mm;
    CMAltimeter *_alt;
    NSOperationQueue *_q;      // MOT luong duy nhat cho moi phep tinh cua bo loc
    NSUInteger _n;
    BOOL _savedOnce;
    volatile double _lastImuWall, _lastGpsWall, _prevGpsV, _prevGpsT;
    volatile long _imuCount, _gpsCountI;
    long _imuCountPrev, _gpsCountPrev; double _rateT;
    BOOL _rawMode;
    double _rawG[3], _lastRot[3];
    volatile double _altM;
    PALearn _learn; double _learnLastTs; long _learnN;
    // ghi chuyen di (chi dung tren _q)
    NSFileHandle *_trip; NSURL *_tripURL; NSMutableString *_tripBuf;
    double _tripT0, _tripDist, _tripVmax, _tripAmax, _tripBmax, _tripLastTs; long _tripRows; NSDate *_tripStart;
    double _lastSavedTheta;
}

- (instancetype)initWithSynth:(PASynth *)synth {
    if ((self = [super init])) {
        _synth = synth;
        _feedSynth = YES;
        _responseScale = 1;
        _gpsAccuracy = -1; _gpsRawKmh = -1;
        _sourceName = @"Chưa có";
        _learnEnabled = YES;
        pal_init(&_learn);
        NSData *saved = [NSUserDefaults.standardUserDefaults dataForKey:@"learn.v1"];
        if (saved.length == sizeof(PALearn)) memcpy(&_learn, saved.bytes, sizeof(PALearn));   // ho so da hoc tu cac chuyen truoc
        _learned = _learn;
        [self pushLearnToSynth];
        paf_init(&_f);
        _mm = [CMMotionManager new];
        _alt = [CMAltimeter new];
        _q = [NSOperationQueue new];
        _q.maxConcurrentOperationCount = 1;
        _q.qualityOfService = NSQualityOfServiceUserInteractive;
        _q.name = @"com.ndarealty.ndadrive.motion";
    }
    return self;
}

- (void)start {
    if (_running) return;
    _running = YES;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL has = [d objectForKey:@"cal.theta"] != nil;
    double th = [d doubleForKey:@"cal.theta"];
    double gx = [d doubleForKey:@"cal.gx"], gy = [d doubleForKey:@"cal.gy"], gz = [d doubleForKey:@"cal.gz"];
    [_q addOperationWithBlock:^{
        paf_init(&self->_f);
        double g[3] = { gx, gy, gz };
        if (has) paf_load_calibration(&self->_f, th, g);   // dung lai can chinh lan truoc neu may van gan dung goc
        self->_savedOnce = has; self->_lastSavedTheta = th;
    }];

    _lastImuWall = _lastGpsWall = NSProcessInfo.processInfo.systemUptime;
    [self startMotionUpdates];
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        __weak typeof(self) ws = self;
        [_alt startRelativeAltitudeUpdatesToQueue:_q withHandler:^(CMAltitudeData *d, NSError *err) {
            typeof(self) ss = ws;
            if (d && ss) { ss->_altM = d.relativeAltitude.doubleValue; paf_baro(&ss->_f, d.relativeAltitude.doubleValue, d.timestamp); }
            if (err) PALog(@"Ap ke loi: %@", err.localizedDescription);
        }];
    }
    PALog(@"Cam bien: bat dau (deviceMotion %@, accelerometer %@, gyro %@)",
          _mm.isDeviceMotionAvailable ? @"co" : @"KHONG", _mm.isAccelerometerAvailable ? @"co" : @"KHONG", _mm.isGyroAvailable ? @"co" : @"KHONG");
    // Sau 2 giay ma chua nhan duoc mau nao -> chuyen sang doc gia toc ke + con quay tho
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_running && self->_imuCount == 0) [self startRawSensors];
    });
}

- (void)startMotionUpdates {
    if (_mm.isDeviceMotionAvailable) {
        _mm.deviceMotionUpdateInterval = 0.01; // 100 lan/giay
        __weak typeof(self) ws = self;
        [_mm startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                 toQueue:_q
                                             withHandler:^(CMDeviceMotion *m, NSError *err) {
            if (m) [ws handleMotion:m];
            else if (err) { typeof(self) ss = ws; if (ss) ss->_lastError = err.localizedDescription; PALog(@"deviceMotion loi: %@", err.localizedDescription); [PADiag.shared bump:@"imu_error"]; }
        }];
    }
}

// Duong du phong: gia toc ke tho (co ca trong luc) + con quay, tu tach trong luc bang loc thong thap
- (void)startRawSensors {
    if (!_mm.isAccelerometerAvailable) { _lastError = @"Máy không có gia tốc kế"; return; }
    PALog(@"Khong nhan duoc deviceMotion -> dung gia toc ke tho");
    [PADiag.shared bump:@"imu_raw_fallback"];
    _rawMode = YES;
    _sourceName = @"Gia tốc kế thô";
    [_mm stopDeviceMotionUpdates];
    if (_mm.isGyroAvailable) {
        _mm.gyroUpdateInterval = 0.01;
        [_mm startGyroUpdatesToQueue:_q withHandler:^(CMGyroData *g, NSError *e) {
            if (g) { self->_lastRot[0] = g.rotationRate.x; self->_lastRot[1] = g.rotationRate.y; self->_lastRot[2] = g.rotationRate.z; }
        }];
    }
    _mm.accelerometerUpdateInterval = 0.01;
    __weak typeof(self) ws = self;
    [_mm startAccelerometerUpdatesToQueue:_q withHandler:^(CMAccelerometerData *a, NSError *err) {
        typeof(self) ss = ws; if (!ss) return;
        if (!a) { if (err) ss->_lastError = err.localizedDescription; return; }
        double raw[3] = { a.acceleration.x, a.acceleration.y, a.acceleration.z };   // don vi g
        if (ss->_rawG[0] == 0 && ss->_rawG[1] == 0 && ss->_rawG[2] == 0) memcpy(ss->_rawG, raw, sizeof raw);
        for (int i = 0; i < 3; i++) ss->_rawG[i] += (raw[i] - ss->_rawG[i]) * 0.02;   // trong luc ~ thanh phan cham
        const double G = 9.80665;
        double ua[3] = { (raw[0] - ss->_rawG[0]) * G, (raw[1] - ss->_rawG[1]) * G, (raw[2] - ss->_rawG[2]) * G };
        [ss feedIMU:ua gravity:ss->_rawG rot:ss->_lastRot time:a.timestamp];
    }];
}

- (void)restartSensors {
    if (!_running) return;
    PALog(@"Cam bien: khoi dong lai (im lang %.1f s)", self.imuAge);
    if (_rawMode) { [_mm stopAccelerometerUpdates]; [_mm stopGyroUpdates]; _rawMode = NO; [self startRawSensors]; return; }
    [_mm stopDeviceMotionUpdates];
    [self startMotionUpdates];
}

+ (NSURL *)tripsFolder {
    NSURL *u = [PADataDir() URLByAppendingPathComponent:@"trips" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
    return u;
}

- (void)startTrip {
    if (!_recordEnabled) return;
    [_q addOperationWithBlock:^{
        if (self->_trip) return;
        NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = @"yyyyMMdd_HHmmss";
        self->_tripStart = [NSDate date];
        self->_tripURL = [[PAMotion tripsFolder] URLByAppendingPathComponent:[NSString stringWithFormat:@"trip_%@.csv", [df stringFromDate:self->_tripStart]]];
        NSString *head = @"t_s,gps_kmh,gps_acc_ms,fused_kmh,a_long_ms2,ax,ay,az,gyro_rads,grade_pct,tilt_deg,calibrated,stationary,gps_ok,src,synth_kmh,rpm,gear,load,state,cal_theta_deg,rx,ry,rz,gvx,gvy,gvz,gps_new,gps_delay_s,cal_turn,gps_car,lead_ms,audio_lat_ms\n";
        [head writeToURL:self->_tripURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        self->_trip = [NSFileHandle fileHandleForWritingToURL:self->_tripURL error:nil];
        [self->_trip seekToEndOfFile];
        self->_tripBuf = [NSMutableString string];
        self->_tripT0 = 0; self->_tripDist = 0; self->_tripVmax = 0; self->_tripAmax = 0; self->_tripBmax = 0; self->_tripRows = 0; self->_tripLastTs = 0;
        PALog(@"Ghi chuyen di: %@", self->_tripURL.lastPathComponent);
    }];
    // Giu toi da 40 chuyen gan nhat
    NSArray *files = [[NSFileManager.defaultManager contentsOfDirectoryAtURL:[PAMotion tripsFolder] includingPropertiesForKeys:nil options:0 error:nil]
                      sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) { return [a.lastPathComponent compare:b.lastPathComponent]; }];
    NSArray *csv = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'csv'"]];
    for (NSInteger i = 0; i + 40 < (NSInteger)csv.count; i++) {
        [NSFileManager.defaultManager removeItemAtURL:csv[i] error:nil];
        [NSFileManager.defaultManager removeItemAtURL:[csv[i] URLByAppendingPathExtension:@"json"] error:nil];
    }
}

- (void)stopTrip {
    [_q addOperationWithBlock:^{
        if (!self->_trip) return;
        [self->_trip writeData:[self->_tripBuf dataUsingEncoding:NSUTF8StringEncoding]];
        [self->_trip closeFile]; self->_trip = nil;
        double dur = -[self->_tripStart timeIntervalSinceNow];
        NSDictionary *sum = @{ @"file": self->_tripURL.lastPathComponent, @"start": @([self->_tripStart timeIntervalSince1970]),
            @"duration_s": @(round(dur)), @"distance_km": @(round(self->_tripDist * 100) / 100), @"vmax_kmh": @(round(self->_tripVmax * 10) / 10),
            @"accel_max_ms2": @(round(self->_tripAmax * 100) / 100), @"brake_max_ms2": @(round(self->_tripBmax * 100) / 100),
            @"rows": @(self->_tripRows), @"app": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
            @"zero_to_100_est_s": @(round(pal_zero_to_100(&self->_learn) * 10) / 10), @"sport": @(round(pal_sport(&self->_learn) * 100) / 100) };
        NSData *js = [NSJSONSerialization dataWithJSONObject:sum options:NSJSONWritingPrettyPrinted error:nil];
        [js writeToURL:[self->_tripURL URLByAppendingPathExtension:@"json"] atomically:YES];
        PALog(@"Ket thuc chuyen di: %.1f km, %.0f s, %ld mau", self->_tripDist, dur, self->_tripRows);
        if (dur < 20 || self->_tripRows < 100) {   // bo chuyen qua ngan (bat/tat thu)
            [NSFileManager.defaultManager removeItemAtURL:self->_tripURL error:nil];
            [NSFileManager.defaultManager removeItemAtURL:[self->_tripURL URLByAppendingPathExtension:@"json"] error:nil];
        }
    }];
}

// goi tren _q, 10 lan/giay
- (void)recordRow:(double)ts ua:(double *)ua rot:(double *)rr gravity:(double *)gr {
    if (!_trip) return;
    if (_tripT0 == 0) _tripT0 = ts;
    double v = _f.v * 3.6, dt = _tripLastTs > 0 ? ts - _tripLastTs : 0;
    _tripLastTs = ts;
    if (dt > 0 && dt < 1) _tripDist += v / 3600.0 * dt;
    if (v > _tripVmax) _tripVmax = v;
    if (_f.calibrated) { if (_f.aLongRaw > _tripAmax) _tripAmax = _f.aLongRaw; if (-_f.aLongRaw > _tripBmax) _tripBmax = -_f.aLongRaw; }
    double gm = sqrt(rr[0] * rr[0] + rr[1] * rr[1] + rr[2] * rr[2]);
    double gn = sqrt(gr[0] * gr[0] + gr[1] * gr[1] + gr[2] * gr[2]);
    double tilt = gn > 0 ? acos(fmin(1, fabs(gr[2]) / gn)) * 180 / M_PI : 0;
    [_tripBuf appendFormat:@"%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.1f,%d,%d,%d,%d,%.2f,%.0f,%d,%.2f,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.2f,%d,%d,%.0f,%.0f\n",
        ts - _tripT0, _gpsRawKmh, _gpsAccuracy, v, _f.calibrated ? _f.aLongRaw : _f.a, ua[0], ua[1], ua[2], gm, _f.grade * 100, tilt,
        _f.calibrated, _f.stationary, _f.gpsOk, _rawMode ? 2 : 1, _synth->speed, _synth->rpm, _synth->gear + 1, _synth->load, (int)_synth->state, _f.theta * 180 / M_PI,
        rr[0], rr[1], rr[2], gr[0], gr[1], gr[2], _newFixFlag, self.gpsDelayEst, _f.calByTurn, _fromCar, _synth->leadS * 1000, self.audioLatencyMs];
    _newFixFlag = 0;
    _tripRows++;
    if (_tripRows % 20 == 0) {           // ghi xuong may moi 2 giay
        [_trip writeData:[_tripBuf dataUsingEncoding:NSUTF8StringEncoding]];
        [_tripBuf setString:@""];
    }
}

- (void)pushLearnToSynth {
    for (int i = 0; i < PAL_BINS && i < 5; i++) _synth->learnCap[i] = fmax(_learn.accPeak[i], _learn.accP95[i]);
    _synth->learnSport = pal_sport(&_learn);
    _synth->learnOn = _learnEnabled && pal_confidence(&_learn) > 0.05;
}

- (void)setLearnEnabled:(BOOL)v { _learnEnabled = v; if (_synth) _synth->learnOn = v && pal_confidence(&_learn) > 0.05; }

- (void)resetLearning {
    [_q addOperationWithBlock:^{
        pal_init(&self->_learn);
        [self pushLearnToSynth];
        PALearn copy = self->_learn;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_learned = copy;
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"learn.v1"];
        });
    }];
    PALog(@"Hoc thich nghi: dat lai");
}

- (double)imuAge { return NSProcessInfo.processInfo.systemUptime - _lastImuWall; }

// Tinh tan so mau (goi tu luong chinh ~1 lan/giay)
- (void)updateRates {
    double now = NSProcessInfo.processInfo.systemUptime;
    if (_rateT > 0 && now - _rateT >= 0.9) {
        _imuHz = (_imuCount - _imuCountPrev) / (now - _rateT);
        _gpsHz = (_gpsCountI - _gpsCountPrev) / (now - _rateT);
        _imuCountPrev = _imuCount; _gpsCountPrev = _gpsCountI; _rateT = now;
    } else if (_rateT == 0) { _rateT = now; _imuCountPrev = _imuCount; _gpsCountPrev = _gpsCountI; }
}
- (double)gpsAge { return NSProcessInfo.processInfo.systemUptime - _lastGpsWall; }
- (double)gpsDelayEst { return _f.dlyN > 6 ? _f.gpsDelay : 0; }
- (BOOL)calByTurn { return _f.calByTurn; }
- (double)aLongNow { return _f.calibrated ? _f.aLongRaw : _f.a; }
- (double)gpsNewInterval { return _newIntv; }
- (BOOL)gpsFromCar { return _fromCar; }
- (double)gpsRepeatRatio { return _f.gpsTotal > 0 ? (double)_f.gpsRepTotal / _f.gpsTotal : 0; }
- (BOOL)gpsOnlyFallback { return _running && self.imuAge > 0.5; }

- (void)stop {
    if (!_running) return;
    _running = NO;
    PALog(@"Cam bien: tat");
    [_mm stopAccelerometerUpdates]; [_mm stopGyroUpdates]; _rawMode = NO;
    _sourceName = @"Chưa có";
    [_mm stopDeviceMotionUpdates];
    [_alt stopRelativeAltitudeUpdates];
}

// Chay tren _q
- (void)handleMotion:(CMDeviceMotion *)m {
    const double G = 9.80665;
    double ua[3] = { m.userAcceleration.x * G, m.userAcceleration.y * G, m.userAcceleration.z * G };
    double gr[3] = { m.gravity.x, m.gravity.y, m.gravity.z };
    double rr[3] = { m.rotationRate.x, m.rotationRate.y, m.rotationRate.z };
    if (!_rawMode && ![_sourceName isEqualToString:@"Chuyển động tổng hợp"]) _sourceName = @"Chuyển động tổng hợp";
    [self feedIMU:ua gravity:gr rot:rr time:m.timestamp];
}

- (void)feedIMU:(double *)ua gravity:(double *)gr rot:(double *)rr time:(double)ts {
    _imuCount++;
    _lastImuWall = NSProcessInfo.processInfo.systemUptime;
    _f.sigScale = _responseScale;
    paf_imu(&_f, ua, gr, rr, ts);
    // HOC THICH NGHI: chi hoc khi da hoc huong xe + GPS tot (du lieu tin cay)
    double ldt = _learnLastTs > 0 ? ts - _learnLastTs : 0.01;
    _learnLastTs = ts;
    if (_learnEnabled) pal_update(&_learn, _f.v * 3.6, _f.aLongRaw, ldt, _f.calibrated && _f.gpsOk && !_f.stationary);
    if (_learnN % 10 == 0) [self recordRow:ts ua:ua rot:rr gravity:gr];
    if (++_learnN % 100 == 0) {           // ~1 lan/giay
        [self pushLearnToSynth];
        PALearn copy = _learn;
        BOOL save = _learnN % 3000 == 0;  // ~30 giay luu mot lan
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_learned = copy;
            if (save) [NSUserDefaults.standardUserDefaults setObject:[NSData dataWithBytes:&copy length:sizeof(PALearn)] forKey:@"learn.v1"];
        });
    }
    double trim = 1.0 + _speedTrim;

    if (_feedSynth) {
        _synth->gpsSpeed = _f.gpsOk || _f.calibrated || _f.stationary ? _f.v * 3.6 * trim : -1;
        _synth->gpsAccel = _f.a * 3.6 * trim;
        _synth->grade = _f.grade;
        _synth->gpsAge = 0;
    }

    // luu can chinh khi vua hoc xong hoac goc thay doi dang ke (moi ~2 giay kiem tra)
    if (_f.calibrated && _n % 200 == 0 && (!_savedOnce || fabs(_f.theta - _lastSavedTheta) > 0.03)) {
        _savedOnce = YES; _lastSavedTheta = _f.theta;
        double th = _f.theta, gx = _f.gCal[0], gy = _f.gCal[1], gz = _f.gCal[2];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
            [d setDouble:th forKey:@"cal.theta"]; [d setDouble:gx forKey:@"cal.gx"];
            [d setDouble:gy forKey:@"cal.gy"]; [d setDouble:gz forKey:@"cal.gz"];
        });
    }
    if (++_n % 20 == 0) { // ~5 lan/giay: cap nhat so lieu hien thi
        double v = _f.v * 3.6 * trim, a = _f.calibrated ? _f.aLongRaw : _f.a, gp = _f.grade * 100, q = _f.quality;
        double prog = _f.calProgress, ang = _f.theta * 180 / M_PI;
        BOOL c = _f.calibrated, st = _f.stationary, ok = _f.gpsOk;
        double x = ua[0], y = ua[1], z = ua[2];
        double gm = sqrt(rr[0] * rr[0] + rr[1] * rr[1] + rr[2] * rr[2]);
        double gn = sqrt(gr[0] * gr[0] + gr[1] * gr[1] + gr[2] * gr[2]);
        double tilt = gn > 0 ? acos(fmin(1, fabs(gr[2]) / gn)) * 180 / M_PI : 0;
        double alt = _altM;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_ax = x; self->_ay = y; self->_az = z; self->_gyroMag = gm; self->_tiltDeg = tilt; self->_altitudeM = alt;
            self->_speedKmh = v; self->_accelMs2 = a; self->_gradePct = gp; self->_quality = q;
            self->_calibrated = c; self->_stationary = st; self->_gpsOk = ok;
            self->_calProgress = prog; self->_mountAngleDeg = ang;
        });
    }
}

- (void)addLocation:(CLLocation *)loc {
    // Doi thoi diem GPS (dong ho thuc) sang dong ho cua CoreMotion (giay ke tu khi khoi dong may)
    double tFix = NSProcessInfo.processInfo.systemUptime + loc.timestamp.timeIntervalSinceNow;
    double speed = loc.speed;
    double acc = loc.speedAccuracy;  // iOS 10+; < 0 neu khong ro
    double course = loc.course;
    _gpsAccuracy = acc; _gpsRawKmh = speed >= 0 ? speed * 3.6 : -1;
    _gpsCountI++; _gpsCount = _gpsCountI;
    if (@available(iOS 15.0, *)) { _fromCar = loc.sourceInformation.isProducedByAccessory; }
    if (speed >= 0 && (speed != _lastRawSpeed || course != _lastRawCourse)) {   // ban tin MOI (khong lap so cu)
        double nw = NSProcessInfo.processInfo.systemUptime;
        if (_lastNewWall > 0 && nw - _lastNewWall < 10) _newIntv += ((nw - _lastNewWall) - _newIntv) * 0.2;
        _lastNewWall = nw; _newFixFlag = 1;
    }
    _lastRawSpeed = speed; _lastRawCourse = course;
    double nowW = NSProcessInfo.processInfo.systemUptime;
    _lastGpsWall = nowW;
    // DU PHONG: cam bien chuyen dong khong gui so lieu (thuong do iOS khi tat man hinh)
    // -> dua thang toc do GPS vao bo tao am de tieng po van theo xe.
    if (_feedSynth && speed >= 0 && nowW - _lastImuWall > 0.5) {
        double v = speed * 3.6 * (1.0 + _speedTrim);
        if (v < 1.5) v = 0;
        double dt = tFix - _prevGpsT;
        double a = (_prevGpsT > 0 && dt > 0.2 && dt < 3) ? (v - _prevGpsV) / dt : 0;
        _synth->gpsAccel = a; _synth->gpsSpeed = v; _synth->gpsAge = fmax(0, nowW - tFix);
    }
    if (speed >= 0) { _prevGpsV = speed * 3.6 * (1.0 + _speedTrim); _prevGpsT = tFix; }
    if (loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 65) return;
    [_q addOperationWithBlock:^{ paf_gps(&self->_f, speed, acc, course, tFix); }];
}

- (void)resetCalibration {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    for (NSString *k in @[@"cal.theta", @"cal.gx", @"cal.gy", @"cal.gz"]) [d removeObjectForKey:k];
    [_q addOperationWithBlock:^{
        double v = self->_f.v;
        paf_init(&self->_f);
        self->_f.v = v;                 // giu toc do hien tai, chi hoc lai huong xe
        self->_savedOnce = NO;
    }];
    _calibrated = NO; _calProgress = 0;
}

@end
