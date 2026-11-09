#import "PAAcousticMeasure.h"
#import "PAEngine.h"
#import "PALog.h"
#import "PADiag.h"
#import <AVFoundation/AVFoundation.h>

static const double kF1 = 40, kF2 = 16000, kT = 8, kPre = 1.0, kPost = 1.2;

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

+ (void)startMeasure:(BOOL)carMic progress:(void (^)(NSString *))progress done:(void (^)(PAAcousticResult, NSString *))done {
    PAAcousticResult empty; memset(&empty, 0, sizeof empty);
    PAEngine *eng = PAEngine.shared;
    [eng pauseForMeasurement];                       // tam dung tieng po trong luc do
    AVAudioSession *as = AVAudioSession.sharedInstance;
    NSError *err = nil;
    AVAudioSessionCategoryOptions opt = AVAudioSessionCategoryOptionMixWithOthers;
    if (!carMic) opt |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    // Che do "Measurement": tat xu ly tu dong cua mic (giam on, tu chinh am luong) de do chinh xac
    [as setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeMeasurement options:opt error:&err];
    [as setActive:YES error:&err];
    AVAudioSessionPortDescription *port = [self portOfType:carMic ? AVAudioSessionPortCarAudio : AVAudioSessionPortBuiltInMic];
    if (carMic && !port) { [eng resumeAfterMeasurement]; done(empty, @"Không thấy mic xe. Kết nối CarPlay rồi thử lại, hoặc chọn mic iPhone."); return; }
    if (port) [as setPreferredInput:port error:nil];
    PALog(@"Do am hoc: mic %@, dau ra %@", port.portName ?: @"?", as.currentRoute.outputs.firstObject.portName ?: @"?");

    AVAudioEngine *ae = [AVAudioEngine new];
    AVAudioInputNode *in = ae.inputNode;
    AVAudioFormat *inFmt = [in outputFormatForBus:0];
    double sr = inFmt.sampleRate > 0 ? inFmt.sampleRate : 48000;
    int nS = (int)(kT * sr);
    AVAudioFormat *mono = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sr channels:1];
    AVAudioPCMBuffer *buf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:mono frameCapacity:nS];
    buf.frameLength = paa_make_sweep(buf.floatChannelData[0], nS, sr, kF1, kF2, kT, 0.5);
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
    [ae prepare];
    if (![ae startAndReturnError:&err]) {
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
        [in removeTapOnBus:0];
        [pl stop]; [ae stop];
        progress(@"Đang phân tích…");
        dispatch_async(q, ^{
            int nY = (int)(rec.length / sizeof(float));
            PAAcousticResult r;
            paa_analyze(sweepCopy, nS, rec.bytes, nY, playStart, sr, kF1, kF2, kT, &r);
            free(sweepCopy);
            [rec setLength:0];                       // xoa am thanh thu duoc ngay sau khi phan tich
            dispatch_async(dispatch_get_main_queue(), ^{
                [eng resumeAfterMeasurement];
                PALog(@"Do am hoc xong: tre %.1f ms, SNR %.0f dB, on nen %.0f dBFS, hop le %d", r.latencyMs, r.snrDb, r.noiseDbfs, r.valid);
                [PADiag.shared bump:r.valid ? @"acoustic_ok" : @"acoustic_low_snr"];
                if (!r.valid) { done(r, [NSString stringWithFormat:@"Tiếng đo quá nhỏ so với tiếng ồn (SNR %.0f dB). Tăng âm lượng xe, đóng cửa, tắt điều hòa rồi đo lại.", r.snrDb]); return; }
                [self save:r];
                done(r, nil);
            });
        });
    });
}

@end
