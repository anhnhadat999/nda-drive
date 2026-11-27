#import "PACarLatencyViewController.h"
#import "PAEngine.h"
#import "PACarSignal.h"
#import "PATheme.h"
#import <AVFoundation/AVFoundation.h>

// Do tin hieu CarPlay bang 3 cach:
//  1) iOS bao do tre (AVAudioSession.outputLatency) theo tung kieu phat
//  2) TAI & MAT: app phat tieng "tich" qua CarPlay moi 1,2 s; vong tron chop cham hon mot khoang dieu chinh duoc.
//     Keo thanh truot den khi chop va tich trung nhau -> do tre that (sai so ~30-50 ms, khong can thiet bi).
//  3) Tweak chan doan: dinh dang nen, tan so, do tre xe tu khai bao (qua kenh Darwin notify).
@implementation PACarLatencyViewController {
    UIView *_dot;
    UILabel *_offLbl, *_info, *_sig;
    UISlider *_slider;
    UIButton *_runBtn;
    NSTimer *_timer, *_refresh;
    BOOL _running;
}

- (UILabel *)label:(CGFloat)size color:(UIColor *)c {
    UILabel *l = [UILabel new]; l.numberOfLines = 0; l.textColor = c; l.font = [UIFont systemFontOfSize:size]; return l;
}
- (UIButton *)button:(NSString *)t action:(SEL)a filled:(BOOL)f {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    b.backgroundColor = f ? PA_AMBER : PA_CARD;
    [b setTitleColor:f ? UIColor.blackColor : PA_FG forState:UIControlStateNormal];
    b.layer.cornerRadius = 12;
    [b.heightAnchor constraintEqualToConstant:48].active = YES;
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Đo tín hiệu CarPlay";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.view.backgroundColor = PA_BG;
    UIScrollView *sv = [UIScrollView new]; sv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:sv];
    UIStackView *st = [UIStackView new]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 14; st.translatesAutoresizingMaskIntoConstraints = NO;
    [sv addSubview:st];
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [st.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:16], [st.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-24],
        [st.leadingAnchor constraintEqualToAnchor:sv.frameLayoutGuide.leadingAnchor constant:16], [st.trailingAnchor constraintEqualToAnchor:sv.frameLayoutGuide.trailingAnchor constant:-16],
    ]];

    UILabel *h1 = [self label:20 color:PA_FG]; h1.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold]; h1.text = @"Đo độ trễ bằng tai & mắt";
    UILabel *g = [self label:14 color:PA_MUTED];
    g.text = @"Khi xe đỗ, kết nối CarPlay, bấm Bắt đầu. Loa xe phát tiếng \"tích\" đều đặn, vòng tròn chớp theo.\n"
             "Kéo thanh trượt đến khi tiếng tích và lúc vòng tròn sáng TRÙNG NHAU, rồi bấm Lưu. App dùng số này để bù trễ.";
    _dot = [UIView new]; _dot.backgroundColor = PA_AMBER; _dot.alpha = 0.12; _dot.layer.cornerRadius = 60;
    [_dot.widthAnchor constraintEqualToConstant:120].active = YES; [_dot.heightAnchor constraintEqualToConstant:120].active = YES;
    UIView *dotRow = [UIView new]; [dotRow addSubview:_dot]; _dot.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[[_dot.centerXAnchor constraintEqualToAnchor:dotRow.centerXAnchor], [_dot.topAnchor constraintEqualToAnchor:dotRow.topAnchor], [_dot.bottomAnchor constraintEqualToAnchor:dotRow.bottomAnchor]]];
    _offLbl = [self label:28 color:PA_FG]; _offLbl.textAlignment = NSTextAlignmentCenter;
    _offLbl.font = [UIFont monospacedDigitSystemFontOfSize:28 weight:UIFontWeightSemibold];
    _slider = [UISlider new]; _slider.minimumValue = 0; _slider.maximumValue = 2000; _slider.tintColor = PA_AMBER;
    PAEngine *e = PAEngine.shared;
    _slider.value = e.measuredLatencyMs > 0 ? e.measuredLatencyMs : (e.outputLatencyMs > 0 ? e.outputLatencyMs : 1000);
    [_slider addTarget:self action:@selector(slid) forControlEvents:UIControlEventValueChanged];
    UIStackView *fine = [UIStackView new]; fine.spacing = 10; fine.distribution = UIStackViewDistributionFillEqually;
    [fine addArrangedSubview:[self button:@"−10 ms" action:@selector(minus) filled:NO]];
    [fine addArrangedSubview:[self button:@"+10 ms" action:@selector(plus) filled:NO]];
    _runBtn = [self button:@"Bắt đầu" action:@selector(toggle) filled:YES];
    UIButton *save = [self button:@"Lưu làm độ trễ CarPlay" action:@selector(save) filled:NO];
    _info = [self label:13 color:PA_MUTED];

    UILabel *h2 = [self label:20 color:PA_FG]; h2.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold]; h2.text = @"Tín hiệu CarPlay";
    _sig = [self label:13 color:PA_FG]; _sig.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    UIButton *test = [self button:@"Thử các kiểu phát (iOS báo trễ)" action:@selector(outTest) filled:NO];

    for (UIView *v in @[h1, g, dotRow, _offLbl, _slider, fine, _runBtn, save, _info, h2, test, _sig]) [st addArrangedSubview:v];
    [self slid];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    __weak typeof(self) ws = self;
    _refresh = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t) { [ws refresh]; }];
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [self stop]; [_refresh invalidate]; _refresh = nil; }

- (void)slid { _offLbl.text = [NSString stringWithFormat:@"%.0f ms", round(_slider.value)]; }
- (void)minus { _slider.value -= 10; [self slid]; }
- (void)plus { _slider.value += 10; [self slid]; }

- (void)toggle { _running ? [self stop] : [self start]; }
- (void)start {
    if (![PAEngine.shared playClick]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Chưa có âm thanh" message:@"Bật \"Pô ảo\" hoặc \"Thu thập im lặng\" trước (tiếng tích vẫn phát khi đang im lặng)." preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    _running = YES; [_runBtn setTitle:@"Dừng" forState:UIControlStateNormal];
    [self flashAfter:_slider.value];
    __weak typeof(self) ws = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.2 repeats:YES block:^(NSTimer *t) { [ws beat]; }];
}
- (void)stop { _running = NO; [_timer invalidate]; _timer = nil; [_runBtn setTitle:@"Bắt đầu" forState:UIControlStateNormal]; }
- (void)beat { if ([PAEngine.shared playClick]) [self flashAfter:_slider.value]; }
- (void)flashAfter:(double)ms {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ms * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        self->_dot.alpha = 1;
        [UIView animateWithDuration:0.18 delay:0.04 options:0 animations:^{ self->_dot.alpha = 0.12; } completion:nil];
    });
}
- (void)save {
    PAEngine.shared.measuredLatencyMs = round(_slider.value);
    [self refresh];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Đã lưu" message:[NSString stringWithFormat:@"Độ trễ CarPlay: %.0f ms. App sẽ dùng số này khi kết nối CarPlay và gửi kèm báo cáo.", round(_slider.value)] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
- (void)outTest {
    [self stop];
    PAEngine *e = PAEngine.shared;
    if (!e.carPlayConnected) { _info.text = @"Chưa kết nối CarPlay."; return; }
    _info.text = @"Đang thử các kiểu phát… (tiếng ngắt ~3 giây)";
    __weak typeof(self) ws = self;
    [e runCarPlayOutputTest:^(NSArray<NSDictionary *> *res, NSInteger chosen) { [ws refresh]; }];
}

- (void)refresh {
    PAEngine *e = PAEngine.shared;
    AVAudioSession *as = AVAudioSession.sharedInstance;
    NSString *out = as.currentRoute.outputs.firstObject.portName ?: @"?";
    _info.text = [NSString stringWithFormat:@"Đầu ra: %@%@ · iOS báo trễ %.0f ms · đã đo %@",
                  out, e.carPlayConnected ? @" (CarPlay)" : @"", e.outputLatencyMs,
                  e.measuredLatencyMs > 0 ? [NSString stringWithFormat:@"%.0f ms", e.measuredLatencyMs] : @"chưa"];
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"Kiểu phát đang dùng: %@\n", [e carAudioModeName:e.carAudioMode]];
    NSDictionary *t = [NSUserDefaults.standardUserDefaults dictionaryForKey:@"carplay.outTest"];
    for (NSDictionary *r in t[@"ket_qua"]) [s appendFormat:@"  %@: %@ ms, %.0f kHz%@\n", r[@"ten"], r[@"tre_ms"], [r[@"tan_so_hz"] doubleValue] / 1000, [r[@"carplay"] boolValue] ? @"" : @" (không ra CarPlay)"];
    NSDictionary *sig = [PACarSignal read];
    [s appendString:@"\nTweak chẩn đoán:\n"];
    NSDictionary *tw = sig[@"tweak"];
    for (NSString *k in [tw.allKeys sortedArrayUsingSelector:@selector(compare:)]) [s appendFormat:@"  %@: %@\n", k, tw[k]];
    NSArray *lines = sig[@"tom_tat"];
    if (lines.count) for (NSString *l in lines) [s appendFormat:@"• %@\n", l];
    else [s appendString:@"• Chưa có tín hiệu. Bật \"Chẩn đoán CarPlay (tweak)\" trong Cài đặt, khởi động lại iPhone (chạy lại jailbreak), rồi kết nối CarPlay và phát tiếng.\n"];
    _sig.text = s;
}

@end
