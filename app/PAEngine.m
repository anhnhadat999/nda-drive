#import "PAEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "PAMotion.h"
#import "PALog.h"
#import "PADiag.h"
#import "PAAcousticMeasure.h"
#import "PAVehicles.h"
#import "PAProfiles.h"

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
    BOOL _userOff, _lastCarPlay, _sessionReady, _restarting, _measuring;
    BOOL _motionRun; double _movingT, _stillT;   // tu phat hien xe chay
    double _lastGpsKick, _lastImuKick;
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
                               @"autoVolume": @YES, @"speedTrim": @0.0, @"responseMode": @1, @"rearFx": @YES, @"learn": @YES, @"record": @YES, @"rearAmt": @0.7, @"subAmt": @0.6, @"growl": @0.6, @"crisp": @0.6, @"car0to100": @5.8, @"carHP": @349.0, @"carWeight": @1900.0, @"interior": @0.4, @"mech": @0.3, @"collectMode": @NO, @"acousticCorr": @YES, @"latComp": @YES, @"vehicle": @"vf7-plus", @"autoProfile": @YES, @"tester": @"" }];
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
        _rearEffect = [d boolForKey:@"rearFx"];
        _learnEnabled = [d boolForKey:@"learn"];
        _recordEnabled = [d boolForKey:@"record"];
        _rearAmount = [d doubleForKey:@"rearAmt"];
        _subAmount = [d doubleForKey:@"subAmt"];
        _growl = [d doubleForKey:@"growl"];
        _crispness = [d doubleForKey:@"crisp"];
        _car0to100 = [d doubleForKey:@"car0to100"];
        _carHP = [d doubleForKey:@"carHP"];
        _carWeight = [d doubleForKey:@"carWeight"];
        _interior = [d doubleForKey:@"interior"];
        _mechanical = [d doubleForKey:@"mech"];
        _collectMode = [d boolForKey:@"collectMode"];
        _latencyComp = [d boolForKey:@"latComp"];
        _acousticCorrection = [d boolForKey:@"acousticCorr"];
        _vehicleId = [d stringForKey:@"vehicle"] ?: @"vf7-plus";
        _autoProfile = [d boolForKey:@"autoProfile"];
        _testerTag = [d stringForKey:@"tester"] ?: @"";
        _headingDeg = -1;
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
    _synth.rearFx = _rearEffect;
    _synth.rearAmt = _rearAmount;
    _synth.subAmt = _subAmount;
    _synth.growl = _growl;
    _synth.crisp = _crispness;
    // Tu thong so xe that tinh ra do boc va nguong gioi han cong suat:
    // perfCap = gia toc dinh toc do thap (tu 0-100); perfKnee = toc do bat dau gioi han boi cong suat (tu ma luc/khoi luong)
    double cap = _car0to100 > 1 ? 27.78 / _car0to100 * 1.4 : 0;
    _synth.perfCap = cap;
    if (cap > 0.5 && _carHP > 10 && _carWeight > 100) {
        double pW = _carHP * 746.0 * 0.85;                 // cong suat thuc (W), hieu suat ~85%
        double knee = pW / (_carWeight * cap) * 3.6;       // km/h
        _synth.perfKnee = fmax(25, fmin(160, knee));
    } else _synth.perfKnee = 50;
    _synth.interior = _interior;
    _synth.mute = _collectMode || !_enabled;
    _synth.mech = _mechanical;
    PAAcousticResult ar;
    BOOL hasAr = [PAAcousticMeasure loadSaved:&ar];
    if (hasAr) { for (int k = 0; k < 9; k++) _synth.corrDb[k] = ar.corrDb[k]; _synth.corrVer++; }
    _synth.corrOn = hasAr && _acousticCorrection;
    PAMotion *mo = _motion;
    mo.speedTrim = _speedTrim;
    mo.learnEnabled = _learnEnabled;
    mo.recordEnabled = _recordEnabled || _collectMode;   // thu thap im lang luon ghi
    mo.responseScale = _responseMode == 0 ? 0.6 : (_responseMode == 2 ? 1.6 : 1.0);
}

- (id)motion { return _motion; }
- (void)setAcousticCorrection:(BOOL)v { _acousticCorrection = v; [self save:@(v) key:@"acousticCorr"]; [self applySettings]; }
- (void)reloadAcoustic { [self applySettings]; }

// Tam dung tieng po + tra lai phien am thanh cho viec do am hoc
- (void)pauseForMeasurement {
    _measuring = YES;
    [_audio stop];
    _sessionReady = NO;
}
- (void)resumeAfterMeasurement {
    _measuring = NO;
    NSError *err = nil;
    [AVAudioSession.sharedInstance setPreferredInput:nil error:nil];
    [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault
                                       options:AVAudioSessionCategoryOptionMixWithOthers error:&err];
    _sessionReady = NO;
    if (_audio) {   // dung lai bo may am thanh (dinh dang dau ra co the da doi)
        [NSNotificationCenter.defaultCenter removeObserver:self name:AVAudioEngineConfigurationChangeNotification object:_audio];
        _audio = nil; _source = nil;
    }
    [self startAudio];
    [self applySettings];
}
- (void)setLatencyComp:(BOOL)v { _latencyComp = v; [self save:@(v) key:@"latComp"]; [self updateLatency]; }
- (void)updateLatency {
    AVAudioSession *as = AVAudioSession.sharedInstance;
    _outputLatencyMs = (as.outputLatency + as.IOBufferDuration) * 1000;
    _synth.leadS = _latencyComp ? fmin(0.8, _outputLatencyMs / 1000.0) : 0;   // CarPlay khong day tre toi ~1 s
    ((PAMotion *)_motion).audioLatencyMs = _outputLatencyMs;
}
- (void)setSubAmount:(double)v { _subAmount = v; [self save:@(v) key:@"subAmt"]; [self applySettings]; }
- (void)setGrowl:(double)v { _growl = v; [self save:@(v) key:@"growl"]; [self applySettings]; }
- (void)setCrispness:(double)v { _crispness = v; [self save:@(v) key:@"crisp"]; [self applySettings]; }
- (void)setCar0to100:(double)v { _car0to100 = v; [self save:@(v) key:@"car0to100"]; [self applySettings]; }
- (void)setCarHP:(double)v { _carHP = v; [self save:@(v) key:@"carHP"]; [self applySettings]; }
- (void)setCarWeight:(double)v { _carWeight = v; [self save:@(v) key:@"carWeight"]; [self applySettings]; }
- (void)setInterior:(double)v { _interior = v; [self save:@(v) key:@"interior"]; [self applySettings]; }
- (void)setMechanical:(double)v { _mechanical = v; [self save:@(v) key:@"mech"]; [self applySettings]; }
- (void)setCollectMode:(BOOL)v {
    _collectMode = v; [self save:@(v) key:@"collectMode"];
    _synth.mute = v;
    [self applySettings];
    if (v && _engineOn) [_motion startTrip];
    PALog(@"Thu thap im lang: %@", v ? @"BAT" : @"tat");
    [PADiag.shared bump:v ? @"collect_on" : @"collect_off"];
    if (_engineOn) [self startAudio];
    [self evaluate];
}
- (double)perfKneeKmh { return _synth.perfKnee; }
- (void)setRearAmount:(double)v { _rearAmount = v; [self save:@(v) key:@"rearAmt"]; [self applySettings]; }
- (void)setRecordEnabled:(BOOL)v { _recordEnabled = v; [self save:@(v) key:@"record"]; [self applySettings]; if (!v) [_motion stopTrip]; }
- (void)setLearnEnabled:(BOOL)v { _learnEnabled = v; [self save:@(v) key:@"learn"]; [self applySettings]; }
- (void)setRearEffect:(BOOL)v { _rearEffect = v; [self save:@(v) key:@"rearFx"]; [self applySettings]; }
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
    [nc addObserver:self selector:@selector(didBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(willForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [nc addObserver:self selector:@selector(protectedDataLocked) name:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
    PALog(@"Khoi dong app (trang thai %ld)", (long)UIApplication.sharedApplication.applicationState);

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

- (void)didBackground {
    [PADiag.shared bump:@"app_background"];
    PALog(@"App chay nen (tat man hinh / chuyen app). May %@, GPS %@, am thanh %@",
          _engineOn ? @"dang no" : @"tat", _locating ? @"bat" : @"tat", _audio.isRunning ? @"chay" : @"dung");
    if (_engineOn) {
        // iOS de giu GPS chay nen hon khi bat chi bao vi tri nen
        _lm.allowsBackgroundLocationUpdates = YES;
        [_lm startUpdatingLocation];
        [self startAudio];
    }
}
- (void)willForeground {
    [PADiag.shared bump:@"app_foreground"];
    [self logForeground];
}
- (void)logForeground { PALog(@"App mo lai (GPS cuoi cach %.1f s, cam bien cuoi cach %.1f s)", _motion.gpsAge, _motion.imuAge); }
- (void)protectedDataLocked { PALog(@"May khoa man hinh (du lieu bao ve bi khoa)"); }

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
    [as setPreferredIOBufferDuration:0.005 error:nil];   // bo dem nho: tieng phan hoi nhanh hon
    if ([as setActive:YES error:&err]) _sessionReady = YES;
    else NSLog(@"[NDADrive] Khong kich hoat duoc phien am thanh: %@", err);
}

- (void)startAudio {
    if (!self.pipelineOn || _measuring) return;   // bo am thanh chay ca khi chi thu thap im lang (giu app song nen); tieng tat qua synth.mute
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
    [PADiag.shared bump:@"audio_config_change"];
    if (_measuring) return;
    // Doi loa / tai nghe / CarPlay: iOS dung bo am thanh. Chi can khoi dong LAI (khong dung lai tu dau),
    // va gop cac thong bao don dap trong 0,5 giay thanh mot lan.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_restarting) return;
        self->_restarting = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self->_restarting = NO;
            if (self.pipelineOn && self->_audio && !self->_audio.isRunning) {
                NSError *err = nil;
                [self->_audio prepare];
                [self->_audio startAndReturnError:&err];
            }
        });
    });
}

- (void)mediaReset:(NSNotification *)n {
    [PADiag.shared bump:@"audio_media_reset"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter removeObserver:self name:AVAudioEngineConfigurationChangeNotification object:self->_audio];
        self->_audio = nil; self->_source = nil; self->_sessionReady = NO; [self startAudio];
    });
}

- (void)interrupted:(NSNotification *)n {
    NSUInteger type = [n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    [PADiag.shared bump:type == AVAudioSessionInterruptionTypeEnded ? @"audio_interrupt_end" : @"audio_interrupt_begin"];
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
- (void)setVehicleId:(NSString *)v { _vehicleId = [v copy]; [self save:v key:@"vehicle"]; }
- (void)setAutoProfile:(BOOL)v { _autoProfile = v; [self save:@(v) key:@"autoProfile"]; if (v) [PAProfiles.shared applyFor:_vehicleId force:NO]; }
- (void)setTesterTag:(NSString *)v { _testerTag = [v copy] ?: @""; [self save:_testerTag key:@"tester"]; }

// Chon xe: ap thong so co dinh cua hang (ma luc, trong luong, 0-100)
- (void)selectVehicle:(NSString *)vid {
    PAVehicle *v = [PAVehicles byId:vid];
    self.vehicleId = vid;
    if (v) {
        _carHP = v.hp; _carWeight = v.weightKg; _car0to100 = v.zeroTo100;
        [self save:@(_carHP) key:@"carHP"]; [self save:@(_carWeight) key:@"carWeight"]; [self save:@(_car0to100) key:@"car0to100"];
        [self applySettings];
        PALog(@"Chon xe %@: %.0f HP, %.0f kg, 0-100 %.1f s", vid, v.hp, v.weightKg, v.zeroTo100);
    }
    [PADiag.shared bump:@"vehicle_select"];
    if (_autoProfile) [PAProfiles.shared applyFor:vid force:NO];
    [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

// Tab No may: tat thu thap im lang, bat po ao va no may ngay
- (void)startDriveMode {
    if (!_enabled) { _enabled = YES; [self save:@YES key:@"enabled"]; }
    if (_collectMode) self.collectMode = NO;
    [PADiag.shared bump:@"mode_drive"];
    [self manualStart];
}
- (void)stopDriveMode { [self manualStop]; }

// Tab Theo doi: tat tieng, khong no may tay; GPS tu phat hien xe chay va ghi day du
- (void)startTracking {
    _manualRun = NO;
    if (_enabled) { _enabled = NO; [self save:@NO key:@"enabled"]; }
    if (!_recordEnabled) { _recordEnabled = YES; [self save:@YES key:@"record"]; }
    _userOff = NO;
    [PADiag.shared bump:@"mode_tracking"];
    PALog(@"Bat dau theo doi im lang");
    self.collectMode = YES;
}
- (void)stopTracking {
    PALog(@"Dung theo doi im lang");
    _motionRun = NO;
    self.collectMode = NO;
    [self evaluate];
}

- (void)manualStart { _userOff = NO; _manualRun = YES; [self evaluate]; }
- (void)manualStop { _userOff = YES; _manualRun = NO; [self evaluate]; }

- (void)evaluate {
    BOOL car = self.carPlayConnected;
    if (car && !_lastCarPlay) { _userOff = NO; [PADiag.shared bump:@"carplay_connect"]; [PADiag.shared bump:_tweakCarPlay ? @"carplay_via_tweak" : @"carplay_via_route"]; }  // vua ket noi CarPlay: tu no may lai
    if (!car && _lastCarPlay) { _manualRun = NO; [PADiag.shared bump:@"carplay_disconnect"]; }        // vua rut CarPlay: tat may
    _lastCarPlay = car;
    // May "no" (ghi chuyen di + tinh vat ly) khi: bam tay, HOAC ket noi CarPlay (neu bat tu no), HOAC tu phat hien xe dang chay
    // Tu dong (CarPlay / phat hien xe chay) chi khi dang Theo doi im lang, hoac khi bat "Tu no may" o tab No may
    BOOL autoOK = _collectMode || _onlyWithCarPlay;
    BOOL shouldRun = self.pipelineOn && !_userOff && (_manualRun || (autoOK && (car || _motionRun)));
    _synth.mute = _collectMode || !_enabled;   // tat po ao hoac dang im lang -> khong phat tieng
    if (shouldRun && !_engineOn) {
        _engineOn = YES;
        [self startAudio];
        [self startLocation];
        _synth.requestStart = 1;      // tieng de may + no may
        PALog(@"No may (%@)", car ? @"CarPlay" : _motionRun ? @"tu phat hien xe chay" : @"bam tay");
        [_motion startTrip];
        [PADiag.shared bump:car ? @"engine_start_carplay" : _motionRun ? @"engine_start_motion" : @"engine_start_manual"];
    } else if (!shouldRun && _engineOn) {
        _engineOn = NO;
        _synth.requestStop = 1;       // tat may tu tu
        PALog(@"Tat may");
        [_motion stopTrip];
        [PADiag.shared bump:@"engine_stop"];
    }
    ((PAMotion *)_motion).silentStep = NO;   // vat ly do pa_render buoc (bo am thanh luon chay)
    if (self.pipelineOn) { [self startLocation]; [self startAudio]; }   // GPS + cam bien luon chay khi bat po ao HOAC thu thap im lang
    else { [self stopLocation]; [self stopAudio]; }
    [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

- (BOOL)pipelineOn { return _enabled || _collectMode; }
- (BOOL)drivingDetected { return _motionRun; }

// Tu phat hien xe chay bang GPS (moi 0,2 s): >12 km/h lien tuc 4 s -> no may; <4 km/h lien tuc 3 phut -> tat
- (void)detectDriving {
    if (!self.pipelineOn || _testMode) return;
    double v = (_motion.gpsAge < 5 && _motion.gpsRawKmh >= 0) ? _motion.gpsRawKmh : _motion.speedKmh;
    if (v > 12) { _movingT += 0.2; _stillT = 0; }
    else { _movingT = fmax(0, _movingT - 0.4); if (v < 4) _stillT += 0.2; }
    if (!_motionRun && _movingT >= 4) {
        _motionRun = YES; _userOff = NO;
        PALog(@"Phat hien xe chay (%.0f km/h) -> no may", v);
        [PADiag.shared bump:@"drive_detected"];
        [self evaluate];
    } else if (_motionRun && _stillT >= 180) {
        _motionRun = NO; _stillT = 0;
        PALog(@"Xe dung qua 3 phut -> ket thuc chuyen");
        [PADiag.shared bump:@"drive_ended_still"];
        [self evaluate];
    }
}

- (void)tick {
    _tickCount++;
    [self detectDriving];
    if (_tickCount % 25 == 1) {   // 5 giay: thong tin phu cho thong ke chuyen
        UIDevice *dv = UIDevice.currentDevice; dv.batteryMonitoringEnabled = YES;
        _motion.battLevel = dv.batteryLevel;
        _motion.battCharging = dv.batteryState == UIDeviceBatteryStateCharging || dv.batteryState == UIDeviceBatteryStateFull;
        _motion.tripTag = [NSString stringWithFormat:@"%@|%@|%@", _vehicleId ?: @"", _testerTag.length ? _testerTag : @"chu-xe", _collectMode ? @"theo-doi" : @"po-ao"];
    }
    if (_testMode) {
        double v = _testSpeedKmh;
        _synth.gpsAccel = (v - _lastTestSpeed) / 0.2 * 0.5 + _synth.gpsAccel * 0.5;
        _lastTestSpeed = v;
        _synth.gpsSpeed = v;
        _synth.gpsAge = 0;
    }
    // Canh gac: dang no may ma GPS/cam bien im lang -> khoi dong lai
    if (_tickCount % 5 == 0) {
        [_motion updateRates];
        if (_locating) {   // thong ke chat luong cam bien moi giay
            PADiag *dg = PADiag.shared;
            [dg noteValue:_motion.imuHz forKey:@"imu_hz"];
            [dg noteValue:_motion.gpsRepeatRatio forKey:@"gps_repeat_ratio"];
            [self updateLatency];
            [dg noteValue:_outputLatencyMs forKey:@"audio_out_latency_ms"];
            if (_motion.gpsDelayEst > 0) [dg noteValue:_motion.gpsDelayEst forKey:@"gps_delay_est_s"];
            if (_motion.gpsNewInterval > 0) [dg noteValue:_motion.gpsNewInterval forKey:@"gps_new_interval_s"];
            [dg noteValue:_motion.gpsFromCar ? 1 : 0 forKey:@"gps_from_car_ratio"];
            [dg noteValue:_motion.calByTurn ? 1 : 0 forKey:@"cal_by_turn_ratio"];
            if (_motion.gpsHz > 0) [dg noteValue:_motion.gpsHz forKey:@"gps_hz"];
            if (_motion.gpsAccuracy > 0) [dg noteValue:_motion.gpsAccuracy forKey:@"gps_speed_acc_ms"];
            [dg noteValue:_motion.calibrated ? 1 : 0 forKey:@"calibrated_ratio"];
            [dg noteValue:_motion.gpsOnlyFallback ? 1 : 0 forKey:@"gps_only_fallback_ratio"];
            [dg noteValue:_motion.imuAge forKey:@"imu_age_s"];
            [dg noteValue:_motion.gpsAge forKey:@"gps_age_s"];
            if (_engineOn) [dg noteValue:UIApplication.sharedApplication.applicationState == UIApplicationStateActive ? 0 : 1 forKey:@"engine_on_background_ratio"];
        }
    }
    if (_locating) {
        double now = NSProcessInfo.processInfo.systemUptime;
        if (_motion.gpsAge > 6 && now - _lastGpsKick > 10) {
            _lastGpsKick = now;
            PALog(@"GPS im lang %.0f s -> khoi dong lai", _motion.gpsAge);
            [PADiag.shared bump:@"gps_restart"];
            [_lm stopUpdatingLocation];
            _lm.allowsBackgroundLocationUpdates = YES;
            [_lm startUpdatingLocation];
        }
        if (_motion.imuAge > 2 && now - _lastImuKick > 10) {
            _lastImuKick = now;
            [_motion restartSensors];
            [PADiag.shared bump:@"imu_restart"];
        }
        if (self.pipelineOn && !_measuring && !_audio.isRunning) { PALog(@"Am thanh dung -> bat lai"); [PADiag.shared bump:@"audio_restart"]; _sessionReady = NO; [self startAudio]; }
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
    NSString *gps = _motion.gpsOnlyFallback ? @"cảm biến tạm dừng, dùng GPS" : (_motion.gpsOk ? @"GPS tốt" : @"mất GPS (dùng cảm biến)");
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
        _lm.showsBackgroundLocationIndicator = YES;    // chi bao vi tri nen: iOS uu tien giu GPS
        [_lm startUpdatingLocation];
        [_lm startMonitoringSignificantLocationChanges]; // lop du phong
        if (CLLocationManager.headingAvailable) { _lm.headingFilter = 2; [_lm startUpdatingHeading]; }
        _locating = YES;
        PALog(@"GPS: bat (quyen %d)", (int)st);
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
    [_lm stopMonitoringSignificantLocationChanges];
    [_lm stopUpdatingHeading];
    _locating = NO;
    PALog(@"GPS: tat");
    _gpsSpeedKmh = -1;
    _synth.gpsSpeed = -1;
}

- (void)stopLocationLater {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_engineOn) [self stopLocation];
    });
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    PALog(@"Quyen vi tri doi: %d", (int)manager.authorizationStatus);
    [PADiag.shared bump:[NSString stringWithFormat:@"location_auth_%d", (int)manager.authorizationStatus]];
    if (self.pipelineOn) [self startLocation];   // vua cap quyen -> bat GPS ngay
    [NSNotificationCenter.defaultCenter postNotificationName:PAEngineDidUpdateNotification object:self];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)h {
    if (_gpsSpeedKmh > 8) return;   // dang chay: dung huong GPS (chinh xac hon la ban trong xe)
    double v = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading;
    if (v >= 0) _headingDeg = v;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *loc in locations) [_motion addLocation:loc];   // dua vao bo hop nhat cam bien
    CLLocation *loc = locations.lastObject;
    if (loc && loc.course >= 0 && loc.speed * 3.6 > 8) _headingDeg = loc.course;
    if (loc && loc.speed >= 0) _gpsSpeedKmh = loc.speed * 3.6;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    PALog(@"Loi GPS: %@", error.localizedDescription);
}

@end
