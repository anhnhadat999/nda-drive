#import "PAMotion.h"
#import <CoreMotion/CoreMotion.h>

@implementation PAMotion {
    PASynth *_synth;
    PAFusion _f;
    CMMotionManager *_mm;
    CMAltimeter *_alt;
    NSOperationQueue *_q;      // MOT luong duy nhat cho moi phep tinh cua bo loc
    NSUInteger _n;
    BOOL _savedOnce;
    double _lastSavedTheta;
}

- (instancetype)initWithSynth:(PASynth *)synth {
    if ((self = [super init])) {
        _synth = synth;
        _feedSynth = YES;
        _responseScale = 1;
        _gpsAccuracy = -1; _gpsRawKmh = -1;
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
    double g[3] = { [d doubleForKey:@"cal.gx"], [d doubleForKey:@"cal.gy"], [d doubleForKey:@"cal.gz"] };
    [_q addOperationWithBlock:^{
        paf_init(&self->_f);
        if (has) paf_load_calibration(&self->_f, th, g);   // dung lai can chinh lan truoc neu may van gan dung goc
        self->_savedOnce = has; self->_lastSavedTheta = th;
    }];

    if (_mm.isDeviceMotionAvailable) {
        _mm.deviceMotionUpdateInterval = 0.01; // 100 lan/giay
        __weak typeof(self) ws = self;
        [_mm startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                 toQueue:_q
                                             withHandler:^(CMDeviceMotion *m, NSError *err) {
            if (m) [ws handleMotion:m];
        }];
    }
    if ([CMAltimeter isRelativeAltitudeAvailable]) {
        __weak typeof(self) ws = self;
        [_alt startRelativeAltitudeUpdatesToQueue:_q withHandler:^(CMAltitudeData *d, NSError *err) {
            typeof(self) ss = ws;
            if (d && ss) paf_baro(&ss->_f, d.relativeAltitude.doubleValue, d.timestamp);
        }];
    }
}

- (void)stop {
    if (!_running) return;
    _running = NO;
    [_mm stopDeviceMotionUpdates];
    [_alt stopRelativeAltitudeUpdates];
}

// Chay tren _q
- (void)handleMotion:(CMDeviceMotion *)m {
    const double G = 9.80665;
    double ua[3] = { m.userAcceleration.x * G, m.userAcceleration.y * G, m.userAcceleration.z * G };
    double gr[3] = { m.gravity.x, m.gravity.y, m.gravity.z };
    double rr[3] = { m.rotationRate.x, m.rotationRate.y, m.rotationRate.z };
    _f.sigScale = _responseScale;
    paf_imu(&_f, ua, gr, rr, m.timestamp);
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
        dispatch_async(dispatch_get_main_queue(), ^{
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
