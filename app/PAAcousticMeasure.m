#import "PAAcousticMeasure.h"
#import "PAEngine.h"
#import "PALog.h"
#import "PADiag.h"
#import <AVFoundation/AVFoundation.h>

static const double kF1 = 40, kF2 = 16000, kT = 8, kPre = 1.0, kPost = 3.5;   // CarPlay khong day tre toi 1-2 s

@implementation PAAcousticMeasure

+ (AVAudioSessionPortDescription *)portOfType:(NSString *)type {
    for (AVAudioSessionPortDescription *p in AVAudioSession.sharedInstance.availableInputs) if ([p.portType isEqualToString:type]) return p;
    return nil;
}
+ (BOOL)carMicAvailable { return [self portOfType:AVAudioSessionPortCarAudio] != nil; }

+ (BOOL)loadSaved:(PAAcousticResult *)r {
    NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:@"acoustic.v1"];
    if (d.length != sizeof(PAAcousticResult)) return NO;
    memcpy(r, d.bytes, sizeof *r); return r->valid;
}
+ (void)save:(PAAcousticResult)r { [NSUserDefaults.standardUserDefaults setObject:[NSData dataWithBytes:&r length:sizeof r] forKey:@"acoustic.v1"]; }

+ (void)runUsingCarMic:(BOOL)carMic progress:(void (^)(NSString *))progress done:(void (^)(PAAcousticResult, NSString *))done {
    PAAcousticResult empty; memset(&empty, 0, sizeof empty);
    AVAudioSession *as = AVAudioSession.sharedInstance;
    if (as.isOtherAudioPlaying) { done(empty, @"Đang có nhạc hoặc âm thanh khác phát. Tắt nhạc rồi đo lại."); return; }
    [as requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) { done(empty, @"Chưa cấp quyền micro. Vào Cài đặt iPhone → NDA Drive → bật Micro."); return; }
            [self startMeasure:carMic progress:progress done:done];
        });
    }];
}

+ (NSString *)outType { return AVAudioSession.sharedInstance.currentRoute.outputs.firstObject.portType ?: @""; }
+ (NSString *)inType { return AVAudioSession.sharedInstance.currentRoute.inputs.firstObject.portType ?: @""; }

// Thu lan luot cac cach cai dat phien am thanh, giu cach dau tien ma: dau ra VAN la loa xe (CarPlay)
// va dau vao dung mic da chon. (iOS hay tu chuyen tieng sang loa iPhone khi bat mic iPhone.)
+ (BOOL)setupSessionCarMic:(BOOL)carMic wantCar:(BOOL)wantCar log:(NSMutableArray *)log {
    AVAudioSession *as = AVAudioSession.sharedInstance;
    AVAudioSessionCategoryOptions base = AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionAllowAirPlay;
    NSArray *modes = @[AVAudioSessionModeMeasurement, AVAudioSessionModeDefault, AVAudioSessionModeVideoRecording];
    for (int pref = 1; pref >= 0; pref--) {
        for (NSString *mode in modes) {
            NSError *err = nil;
            [as setCategory:AVAudioSessionCategoryPlayAndRecord mode:mode options:base error:&err];
            [as setActive:YES error:&err];
            AVAudioSessionPortDescription *port = [self portOfType:carMic ? AVAudioSessionPortCarAudio : AVAudioSessionPortBuiltInMic];
            if (pref && port) [as setPreferredInput:port error:nil];
            if (!pref) [as setPreferredInput:nil error:nil];
            [NSThread sleepForTimeInterval:0.35];            // cho iOS doi duong am thanh xong
            NSString *o = [self outType], *i = [self inType];
            BOOL outOk = !wantCar || [o isEqualToString:AVAudioSessionPortCarAudio];
            BOOL inOk = carMic ? [i isEqualToString:AVAudioSessionPortCarAudio] : [i isEqualToString:AVAudioSessionPortBuiltInMic];
            [log addObject:[NSString stringWithFormat:@"%@/%@: ra %@, vao %@", [mode stringByReplacingOccurrencesOfString:@"AVAudioSessionMode" withString:@""], pref ? @"chon mic" : @"tu dong", o, i]];
            if (outOk && inOk) return YES;
        }
    }
    return NO;
}

+ (void)startMeasure:(BOOL)carMic progress:(void (^)(NSString *))progress done:(void (^)(PAAcousticResult, NSString *))done {
    PAAcousticResult empty; memset(&empty, 0, sizeof empty);
    PAEngine *eng = PAEngine.shared;
    BOOL wantCar = [[self outType] isEqualToString:AVAudioSessionPortCarAudio] || eng.carPlayConnected;
    [eng pauseForMeasurement];                       // tam dung tieng po trong luc do
    progress(@"Đang chuẩn bị đường âm thanh…");
    NSMutableArray *slog = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL ok = [self setupSessionCarMic:carMic wantCar:wantCar log:slog];
        dispatch_async(dispatch_get_main_queue(), ^{
            PALog(@"Do am hoc: thu duong am thanh: %@", [slog componentsJoinedByString:@" | "]);
            [NSUserDefaults.standardUserDefaults setObject:slog forKey:@"acoustic.routes"];
            if (!ok) {
                [eng resumeAfterMeasurement];
                done(empty, carMic
                    ? @"Không dùng được mic xe trong khi phát ra loa xe. Hãy chọn \"Mic iPhone\"."
                    : @"iOS không cho dùng mic iPhone trong khi phát ra loa xe qua CarPlay (tiếng bị chuyển sang loa iPhone). Hãy thử \"Mic xe (CarPlay)\".");
                return;
            }
            [self runEngineCarMic:carMic progress:progress done:done];
        });
    });
}

+ (void)runEngineCarMic:(BOOL)carMic progress:(void (^)(NSString *))progress done:(void (^)(PAAcousticResult, NSString *))done {
    PAAcousticResult empty; memset(&empty, 0, sizeof empty);
    PAEngine *eng = PAEngine.shared;
    AVAudioSession *as = AVAudioSession.sharedInstance;
    NSError *err = nil;
    AVAudioSessionPortDescription *port = as.currentRoute.inputs.firstObject;
    PALog(@"Do am hoc: mic %@, dau ra %@", port.portName ?: @"?", as.currentRoute.outputs.firstObject.portName ?: @"?");

    AVAudioEngine *ae = [AVAudioEngine new];
    AVAudioInputNode *in = ae.inputNode;
    AVAudioFormat *inFmt = [in outputFormatForBus:0];
    double sr = inFmt.sampleRate > 0 ? inFmt.sampleRate : 48000;
    double f2 = fmin(kF2, 0.45 * sr);                // mic xe (che do cuoc goi) thuong chi 16 kHz -> quet toi ~7 kHz
    NSString *micName = port.portName ?: @"?", *outName = as.currentRoute.outputs.firstObject.portName ?: @"?";
    int nS = (int)(kT * sr);
    AVAudioFormat *mono = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sr channels:1];
    AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:mono frameCapacity:nS];
    buf.frameLength = paa_make_sweep(buf.floatChannelData[0], nS, sr, kF1, f2, kT, 0.6);
    float *sweepCopy = malloc(sizeof(float) * nS); memcpy(sweepCopy, buf.floatChannelData[0], sizeof(float) * nS);

    AVAudioPlayerNode *pl = [AVAudioPlayerNode new];
    [ae attachNode:pl];
    [ae connect:pl to:ae.mainMixerNode format:mono];
    NSMutableData *rec = [NSMutableData dataWithCapacity:(NSUInteger)((kPre + kT + kPost) * sr * sizeof(float))];
    dispatch_queue_t q = dispatch_queue_create("com.ndarealty.ndadrive.acoustic", DISPATCH_QUEUE_SERIAL);
    [in installTapOnBus:0 bufferSize:4096 format:inFmt block:^(AVAudioPCMBuffer *b, AVAudioTime *when) {
        NSData *chunk = [NSData dataWithBytes:b.floatChannelData[0] length:b.frameLength * sizeof(float)];
        dispatch_async(q, ^{ [rec appendData:chunk]; });
    }];
    // Kiem tra tieng quet that su duoc phat (muc dinh o dau ra) + phat hien iOS doi duong am thanh giua chung
    __block float outPk = 0; __block int cfgChanged = 0;
    [ae.mainMixerNode installTapOnBus:0 bufferSize:4096 format:nil block:^(AVAudioPCMBuffer *b, AVAudioTime *when) {
        float m = 0; for (AVAudioFrameCount i = 0; i < b.frameLength; i++) m = fmaxf(m, fabsf(b.floatChannelData[0][i]));
        dispatch_async(q, ^{ outPk = fmaxf(outPk, m); });
    }];
    id cfgObs = [NSNotificationCenter.defaultCenter addObserverForName:AVAudioEngineConfigurationChangeNotification object:ae queue:nil
                                                             usingBlock:^(NSNotification *n) { cfgChanged++; }];
    NSString *outType0 = [self outType];
    [ae prepare];
    if (![ae startAndReturnError:&err]) {
        [NSNotificationCenter.defaultCenter removeObserver:cfgObs];
        free(sweepCopy); [eng resumeAfterMeasurement];
        done(empty, [NSString stringWithFormat:@"Không bật được mic: %@", err.localizedDescription]); return;
    }
    progress(@"Đang đo tiếng ồn nền… giữ yên lặng");
    __block int playStart = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPre * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        dispatch_sync(q, ^{ playStart = (int)(rec.length / sizeof(float)); });
        [pl scheduleBuffer:buf completionHandler:nil];
        [pl play];
        progress(@"Đang phát tiếng quét tần số qua loa… (8 giây)");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((kPre + kT + kPost) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [in removeTapOnBus:0]; [ae.mainMixerNode removeTapOnBus:0];
        [pl stop]; [ae stop];
        [NSNotificationCenter.defaultCenter removeObserver:cfgObs];
        BOOL routeMoved = ![[self outType] isEqualToString:outType0];
        progress(@"Đang phân tích…");
        dispatch_async(q, ^{
            int nY = (int)(rec.length / sizeof(float));
            PAAcousticResult r;
            paa_analyze(sweepCopy, nS, rec.bytes, nY, playStart, sr, kF1, f2, kT, &r);
            float opk = outPk;
            float pk = 0; const float *yy = rec.bytes; for (int i = 0; i < nY; i++) pk = fmaxf(pk, fabsf(yy[i]));
            free(sweepCopy);
            [rec setLength:0];                       // xoa am thanh thu duoc ngay sau khi phan tich
            dispatch_async(dispatch_get_main_queue(), ^{
                [eng resumeAfterMeasurement];
                [NSUserDefaults.standardUserDefaults setObject:@{ @"mic": micName, @"out": outName, @"car_mic": @(carMic), @"sr": @(sr), @"f2": @(f2),
                    @"latency_ms": @(r.latencyMs), @"snr_db": @(r.snrDb), @"noise_dbfs": @(r.noiseDbfs), @"peak_dbfs": @(20 * log10(pk + 1e-9)), @"valid": @(r.valid), @"out_peak_dbfs": @(20 * log10(opk + 1e-9)), @"config_changes": @(cfgChanged), @"route_moved": @(routeMoved),
                    @"at": @([NSDate date].timeIntervalSince1970) } forKey:@"acoustic.last"];
                PALog(@"Do am hoc: mic %@ -> loa %@, %.0f Hz, dinh %.0f dBFS", micName, outName, sr, 20 * log10(pk + 1e-9));
                PALog(@"Do am hoc xong: tre %.1f ms, SNR %.0f dB, on nen %.0f dBFS, hop le %d", r.latencyMs, r.snrDb, r.noiseDbfs, r.valid);
                [PADiag.shared bump:r.valid ? @"acoustic_ok" : @"acoustic_low_snr"];
                if (cfgChanged || routeMoved || opk < 0.01) {
                    done(r, [NSString stringWithFormat:@"Tiếng quét không phát ra được (iOS đổi đường âm thanh giữa chừng). Đóng app (vuốt tắt), mở lại rồi đo lại.\n\nChẩn đoán: loa %@ · mic %@ · phát %.0f dBFS · đổi cấu hình %d · đổi loa %d", outName, micName, 20 * log10(opk + 1e-9), cfgChanged, routeMoved]);
                    return;
                }
                if (!r.valid) {
                    NSString *m = carMic
                        ? [NSString stringWithFormat:@"Mic xe không nghe rõ tiếng quét (SNR %.0f dB). Xe thường tự lọc bỏ tiếng loa khỏi mic (chống vọng khi gọi điện). Hãy chọn \"Mic iPhone\", đặt máy ở giữa xe rồi đo lại.", r.snrDb]
                        : [NSString stringWithFormat:@"Tiếng đo quá nhỏ so với tiếng ồn (SNR %.0f dB). Tăng âm lượng xe, đóng cửa, tắt điều hòa rồi đo lại.", r.snrDb];
                    m = [m stringByAppendingFormat:@"\n\nChẩn đoán: loa %@ · mic %@ · %.0f Hz · phát %.0f dBFS · trễ %.0f ms · mức thu đỉnh %.0f dBFS · ồn %.0f dBFS", outName, micName, sr, 20 * log10(opk + 1e-9), r.latencyMs, 20 * log10(pk + 1e-9), r.noiseDbfs];
                    done(r, m); return;
                }
                [self save:r];
                done(r, nil);
            });
        });
    });
}

@end
