#import "PAEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "PAMotion.h"

NSString *const PAEngineDidUpdateNotification = @"PAEngineDidUpdateNotification";

// Thong bao Darwin do tweak trong SpringBoard gui sang
static NSString *const kNotifyCarPlayOn  = @"com.ndarealty.ndadrive.carplay.on";
static NSString *const kNotifyCarPlayOff = @"com.ndarealty.ndadrive.carplay.off";

@interface PAEngine () <CLLocationManagerDelegate>
@end

@implementation PAEngine {
    PASynth _synth;
    AVAudioEngine *_audio;
    AVAudioSourceNode *_source;
    CLLocationManager *_lm;
    PAMotion *_motion;
    BOOL _booted, _routeCarPlay, _tweakCarPlay, _manualRun, _locating;
    BOOL _userOff, _lastCarPlay, _sessionReady, _restarting;
    double _lastFixSpeed, _lastFixAccel, _lastTestSpeed;
    NSTimeInterval _lastFixTime;
    dispatch_source_t _tick;
    NSUInteger _tickCount;
}

+ (instancetype)shared {
    static PAEngine *e; static dispatch_once_t once;
    dispatch_once(&once, ^{ e = [PAEngine new]; });
    return e;
}

- (instancetype)init {
    if ((self = [super init])) {
        pa_init(&_synth);
        _gpsSpeedKmh = -1;
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        [d registerDefaults:@{ @"enabled": @YES, @"onlyWithCarPlay": @YES, @"preset": @"gt3",
                               @"volume": @0.7, @"tone": @0.5, @"pops": @YES, @"shiftPop": @YES,
                               @"autoVolume": @YES, @"speedTrim": @0.0, @"responseMode": @1 }];
        _enabled = [d boolForKey:@"enabled"];
        _onlyWithCarPlay = [d boolForKey:@"onlyWithCarPlay"];
        _presetKey = [d stringForKey:@"preset"] ?: @"gt3";
        _volume = [d doubleForKey:@"volume"];
        _toneAmount = [d doubleForKey:@"tone"];
        _popsEnabled = [d boolForKey:@"pops"];
        _shiftPopEnabled = [d boolForKey:@"shiftPop"];
        _autoVolume = [d boolForKey:@"autoVolume"];
        _speedTrim = [d doubleForKey:@"speedTrim"];
        _responseMode = [d integerForKey:@"responseMode"];
        [self applySettings];
    }
    return self;
}

- (PASynth *)synth { return &_synth; }

#pragma mark - Cai dat

- (void)save:(id)value key:(NSString *)key { [NSUserDefaults.standardUserDefaults setObject:value forKey:key]; }

- (void)applySettings {
    _synth.presetIndex = pa_preset_index(_presetKey.UTF8String);
    _synth.volume = _volume;
    _synth.toneAmt = _toneAmount;
    _synth.pops = _popsEnabled;
    _synth.shiftPop = _shiftPopEnabled;
    _synth.autoVol = _autoVolume;
    PAMotion *mo = _motion;
    mo.speedTrim = _speedTrim;
    mo.responseScale = _responseMode == 0 ? 0.6 : (_responseMode == 2 ? 1.6 : 1.0);
}

- (id)motion { return _motion; }
- (void)setAutoVolume:(BOOL)v { _autoVolume = v; [self save:@(v) key:@"autoVolume"]; [self applySettings]; }
- (void)setSpeedTrim:(double)v { _speedTrim = v; [self save:@(v) key:@"speedTrim"]; [self applySettings]; }
- (void)setResponseMode:(NSInteger)v { _responseMode = v; [self save:@(v) key:@"responseMode"]; [self applySettings]; }

- (void)setEnabled:(BOOL)v { _enabled = v; [self save:@(v) key:@"enabled"]; [self evaluate]; }
- (void)setOnlyWithCarPlay:(BOOL)v { _onlyWithCarPlay = v; [self save:@(v) key:@"onlyWithCarPlay"]; [self evaluate]; }
- (void)setPresetKey:(NSString *)v { _presetKey = [v copy]; [self save:v key:@"preset"]; [self applySettings]; }
- (void)setVolume:(double)v { _volume = v; [self save:@(v) key:@"volume"]; [self applySettings]; }
- (void)setToneAmount:(double)v { _toneAmount = v; [self save:@(v) key:@"tone"]; [self applySettings]; }
- (void)setPopsEnabled:(BOOL)v { _popsEnabled = v; [self save:@(v) key:@"pops"]; [self applySettings]; }
- (void)setShiftPopEnabled:(BOOL)v { _shiftPopEnabled = v; [self save:@(v) key:@"shiftPop"]; [self applySettings]; }
- (void)setTestMode:(BOOL)v { _testMode = v; _lastTestSpeed = _testSpeedKmh; _motion.feedSynth = !v; [self evaluate]; }

#pragma mark - Khoi dong

- (void)boot {
    if (_booted) return;
    _booted = YES;

    _motion = [[PAMotion alloc] initWithSynth:&_synth];
    [self applySettings];
    _lm = [CLLocationManager new];
    _lm.delegate = self;
    _lm.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    _lm.distanceFilter = kCLDistanceFilterNone;
    _lm.activityType = CLActivityTypeAutomotiveNavigation;
    _lm.pausesLocationUpdatesAutomatically = NO;

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    AVAudioSession *as = AVAudioSession.sharedInstance;
    [nc addObserver:self selector:@selector(routeChanged:) name:AVAudioSessionRouteChangeNotification object:as];
    [nc addObserver:self selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:as];
    [nc addObserver:self selector:@selector(mediaReset:) name:AVAudioSessionMediaServicesWereResetNotification object:as];

    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, darwinCallback, (__bridge CFStringRef)kNotifyCarPlayOn, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, darwinCallback, (__bridge CFStringRef)kNotifyCarPlayOff, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

    [self startAudio];
    _routeCarPlay = [self routeIsCarPlay];

    // Nhip 5 lan/giay: cap nhat che do thu, kiem tra CarPlay, bao giao dien
    _tick = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_tick, DISPATCH_TIME_NOW, (uint64_t)(0.2 * NSEC_PER_SEC), (uint64_t)(0.05 * NSEC_PER_SEC));
    __weak typeof(self) ws = self;
    dispatch_source_set_event_handler(_tick, ^{ [ws tick]; });
    dispatch_resume(_tick);

    [self evaluate];
}

static void darwinCallback(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo) {
    PAEngine *e = (__bridge PAEngine *)observer;
    NSString *n = (__bridge NSString *)name;
    dispatch_async(dispatch_get_main_queue(), ^{
        e->_tweakCarPlay = [n isEqualToString:kNotifyCarPlayOn];
        [e evaluate];
    });
}

#pragma mark - Am thanh

- (void)configureSession {
    if (_sessionReady) return;
    AVAudioSession *as = AVAudioSession.sharedInstance;
    NSError *err = nil;
    // Phat tron cung nhac (khong lam ngat nhac/Chi duong). Chi cai dat MOT lan:
    // cai lai lien tuc se lam iOS bao "doi cau hinh" -> vong lap -> treo app.
    if (![as.category isEqualToString:AVAudioSessionCategoryPlayback] ||
        !(as.categoryOptions & AVAudioSessionCategoryOptionMixWithOthers)) {
        [as setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault
                options:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    }
    if ([as setActive:YES error:&err]) _sessionReady = YES;
    else NSLog(@"[NDADrive] Khong kich hoat duoc phien am thanh: %@", err);
}

- (void)startAudio {
    if (!_enabled) return;
    [self configureSession];
    if (!_audio) {
        _audio = [AVAudioEngine new];
        double sr = [_audio.outputNode outputFormatForBus:0].sampleRate;
        if (sr <= 0) sr = 48000;
        AVAudioFormat *fmt = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sr channels:1];
        PASynth *sp = &_synth;
        _source = [[AVAudioSourceNode alloc] initWithFormat:fmt renderBlock:^OSStatus(BOOL *isSilence, const AudioTimeStamp *ts, AVAudioFrameCount frames, AudioBufferList *abl) {
            float *out = (float *)abl->mBuffers[0].mData;
            pa_render(sp, out, (int)frames, sr);
            for (UInt32 b = 1; b < abl->mNumberBuffers; b++) memcpy(abl->mBuffers[b].mData, out, frames * sizeof(float));
            return noErr;
        }];
        [_audio attachNode:_source];
        // bo tron (mixer) tu chuyen doi tan so lay mau khi doi loa/tai nghe/CarPlay
        [_audio connect:_source to:_audio.mainMixerNode format:fmt];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(audioConfigChanged:)
                                                   name:AVAudioEngineConfigurationChangeNotification object:_audio];
    }
    if (!_audio.isRunning) {
        NSError *err = nil;
        [_audio prepare];
        if (![_audio startAndReturnError:&err]) NSLog(@"[NDADrive] Khong khoi dong duoc am thanh: %@", err);
    }
}

- (void)stopAudio {
    [_audio stop];
    _sessionReady = NO;
    [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)audioConfigChanged:(NSNotification *)n {
    // Doi loa / tai nghe / CarPlay: iOS dung bo am thanh. Chi can khoi dong LAI (khong dung lai tu dau),
    // va gop cac thong bao don dap trong 0,5 giay thanh mot lan.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_restarting) return;
        self->_restarting = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_restarting = NO;
            if (self->_enabled && self->_audio && !self->_audio.isRunning) {
                NSError *err = nil;
                [self->_audio prepare];
                [self->_audio startAndReturnError:&err];
            }
        });
    });
}

- (void)mediaReset:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter removeObserver:self name:AVAudioEngineConfigurationChangeNotification object:self->_audio];
        self->_audio = nil; self->_source = nil; self->_sessionReady = NO; [self startAudio];
    });
}

- (void)interrupted:(NSNotification *)n {
    NSUInteger type = [n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeEnded) {
        // Het cuoc goi / Siri: bat lai am thanh
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ self->_sessionReady = NO; [self startAudio]; });
    }
}

#pragma mark - CarPlay

- (BOOL)routeIsCarPlay {
    for (AVAudioSessionPortDescription *o in AVAudioSession.sharedInstance.currentRoute.outputs)
        if ([o.portType isEqualToString:AVAudioSessionPortCarAudio]) return YES;
    return NO;
}

- (void)routeChanged:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_routeCarPlay = [self routeIsCarPlay];
        [self evaluate];
    });
}

- (BOOL)carPlayConnected { return _routeCarPlay || _tweakCarPlay; }

#pragma mark - Quyet dinh no may / tat may

// Nut No may / Tat may luon co hieu luc. "Tat may" giu trang thai tat cho den lan ket noi CarPlay ke tiep.
- (void)manualStart { _userOff = NO; _manualRun = YES; [self evaluate]; }
- (void)manualStop { _userOff = YES; _manualRun = NO; [self evaluate]; }

- (void)evaluate {
    BOOL car = self.carPlayConnected;
    if (car && !_lastCarPlay) { _userOff = NO; }          // vua ket noi CarPlay: tu no may lai
    if (!car && _lastCarPlay) { _manualRun = NO; }        // vua rut CarPlay: tat may
    _lastCarPlay = car;
    BOOL shouldRun = _enabled && !_userOff && (_manualRun || !_onlyWithCarPlay || car);
    if (shouldRun && !_engineOn) {
        _engineOn = YES;
        [self startAudio];
        [self startLocation];
        _synth.requestStart = 1;      // tieng de may + no may
    } else if (!shouldRun && _engineOn) {
        _engineOn = NO;
        _synth.requestStop = 1;       // tat may tu tu
        [self stopLocationLater];
    }
    if (!_enabled) { [self stopLocation]; [self stopAudio]; }
    [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

- (void)tick {
    _tickCount++;
    if (_testMode) {
        double v = _testSpeedKmh;
        _synth.gpsAccel = (v - _lastTestSpeed) / 0.2 * 0.5 + _synth.gpsAccel * 0.5;
        _lastTestSpeed = v;
        _synth.gpsSpeed = v;
        _synth.gpsAge = 0;
    }
    if (_tickCount % 10 == 0) { // moi 2 giay kiem tra lai duong ra am thanh
        BOOL r = [self routeIsCarPlay];
        if (r != _routeCarPlay) { _routeCarPlay = r; [self evaluate]; }
    }
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive)
        [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

#pragma mark - GPS

- (void)requestLocationPermission { [_lm requestAlwaysAuthorization]; }

- (NSString *)sensorStatusText {
    if (!_motion.running) return @"Tắt";
    NSString *cal = _motion.calibrated ? @"đã học hướng xe ✓" : @"đang học hướng xe…";
    NSString *gps = _motion.gpsOk ? @"GPS tốt" : @"mất GPS (dùng cảm biến)";
    return [NSString stringWithFormat:@"%@ · %@ · %.0f km/h · dốc %.1f%%", cal, gps, _motion.speedKmh, _motion.gradePct];
}

- (NSString *)locationStatusText {
    switch (_lm.authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways: return @"Luôn cho phép ✓";
        case kCLAuthorizationStatusAuthorizedWhenInUse: return @"Chỉ khi dùng app (nên chọn Luôn luôn)";
        case kCLAuthorizationStatusDenied: return @"Bị từ chối – bật lại trong Cài đặt";
        case kCLAuthorizationStatusRestricted: return @"Bị hạn chế";
        default: return @"Chưa cấp quyền";
    }
}

- (void)startLocation {
    if (_locating) return;
    CLAuthorizationStatus st = _lm.authorizationStatus;
    if (st == kCLAuthorizationStatusNotDetermined) { [_lm requestAlwaysAuthorization]; }
    if (st == kCLAuthorizationStatusAuthorizedAlways || st == kCLAuthorizationStatusAuthorizedWhenInUse) {
        _lm.allowsBackgroundLocationUpdates = YES;
        _lm.showsBackgroundLocationIndicator = NO;
        [_lm startUpdatingLocation];
        _locating = YES;
    }
    if (_locating || st == kCLAuthorizationStatusNotDetermined) {
        _motion.feedSynth = !_testMode;
        [_motion start];              // gia toc ke + con quay + ap ke (100 lan/giay)
    }
}

- (void)stopLocation {
    [_motion stop];
    if (!_locating) return;
    [_lm stopUpdatingLocation];
    _locating = NO;
    _gpsSpeedKmh = -1;
    _synth.gpsSpeed = -1;
}

- (void)stopLocationLater {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_engineOn) [self stopLocation];
    });
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (_engineOn) [self startLocation];
    [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *loc in locations) [_motion addLocation:loc];   // dua vao bo hop nhat cam bien
    CLLocation *loc = locations.lastObject;
    if (loc && loc.speed >= 0) _gpsSpeedKmh = loc.speed * 3.6;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[NDADrive] Loi GPS: %@", error);
}

@end
