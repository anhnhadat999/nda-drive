#import "PARootViewController.h"
#import "PAEngine.h"

// ---------- Bang mau (giao dien toi, kieu bang dong ho xe ban dem) ----------
#define C_BG     [UIColor colorWithRed:0.051 green:0.059 blue:0.071 alpha:1]
#define C_CARD   [UIColor colorWithRed:0.082 green:0.094 blue:0.114 alpha:1]
#define C_LINE   [UIColor colorWithRed:0.149 green:0.169 blue:0.200 alpha:1]
#define C_FG     [UIColor colorWithRed:0.914 green:0.902 blue:0.875 alpha:1]
#define C_MUTED  [UIColor colorWithRed:0.541 green:0.561 blue:0.596 alpha:1]
#define C_AMBER  [UIColor colorWithRed:1.000 green:0.690 blue:0.125 alpha:1]
#define C_RED    [UIColor colorWithRed:1.000 green:0.290 blue:0.239 alpha:1]
#define C_GREEN  [UIColor colorWithRed:0.290 green:0.820 blue:0.470 alpha:1]

static UIFont *PAFont(CGFloat size, UIFontWeight w) {
    UIFont *f = [UIFont systemFontOfSize:size weight:w];
    UIFontDescriptor *d = [f.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return d ? [UIFont fontWithDescriptor:d size:size] : f;
}

// ======================= Dong ho vong tua =======================
@interface PAGaugeView : UIView
@property (nonatomic) double rpm, redline, speed;
@property (nonatomic) int gear;
@property (nonatomic) BOOL running;
@property (nonatomic, copy) NSString *caption;
@end

@implementation PAGaugeView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; _redline = 9000; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGFloat R = MIN(W / 2, H * 0.58) - 18;
    if (R < 40) return;
    CGPoint ct = CGPointMake(W / 2, MIN(H * 0.56, R + 22));
    double maxV = ceil((self.redline + 1000) / 1000.0) * 1000;
    CGFloat a0 = M_PI * 0.78, a1 = M_PI * 2.22;
    CGFloat (^ang)(double) = ^CGFloat(double v) { return a0 + (a1 - a0) * fmin(1, fmax(0, v / maxV)); };

    CGContextSetLineCap(c, kCGLineCapButt);
    CGContextSetLineWidth(c, 16);
    [C_LINE setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, a0, a1, 0); CGContextStrokePath(c);
    [[C_RED colorWithAlphaComponent:0.85] setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, ang(self.redline), a1, 0); CGContextStrokePath(c);
    if (self.rpm > 1) {
        [(self.rpm > self.redline * 0.97 ? C_RED : C_AMBER) setStroke];
        CGContextAddArc(c, ct.x, ct.y, R, a0, ang(self.rpm), 0); CGContextStrokePath(c);
    }
    // vach chia + so
    NSDictionary *num = @{ NSFontAttributeName: PAFont(14, UIFontWeightBold), NSForegroundColorAttributeName: C_MUTED };
    NSDictionary *numRed = @{ NSFontAttributeName: PAFont(14, UIFontWeightBold), NSForegroundColorAttributeName: C_RED };
    for (int v = 0; v <= (int)maxV; v += 500) {
        CGFloat a = ang(v); BOOL major = v % 1000 == 0;
        CGFloat r1 = R - 12, r2 = R - (major ? 26 : 19);
        [(v >= self.redline ? C_RED : C_MUTED) setStroke];
        CGContextSetLineWidth(c, major ? 2.5 : 1.5);
        CGContextMoveToPoint(c, ct.x + cos(a) * r1, ct.y + sin(a) * r1);
        CGContextAddLineToPoint(c, ct.x + cos(a) * r2, ct.y + sin(a) * r2);
        CGContextStrokePath(c);
        if (major) {
            NSString *t = [NSString stringWithFormat:@"%d", v / 1000];
            NSDictionary *at = v >= self.redline ? numRed : num;
            CGSize sz = [t sizeWithAttributes:at];
            CGFloat rr = R - 42;
            [t drawAtPoint:CGPointMake(ct.x + cos(a) * rr - sz.width / 2, ct.y + sin(a) * rr - sz.height / 2) withAttributes:at];
        }
    }
    // kim
    CGFloat a = ang(self.rpm);
    [C_AMBER setStroke];
    CGContextSetLineWidth(c, 4); CGContextSetLineCap(c, kCGLineCapRound);
    CGContextMoveToPoint(c, ct.x + cos(a) * R * 0.55, ct.y + sin(a) * R * 0.55);
    CGContextAddLineToPoint(c, ct.x + cos(a) * (R - 6), ct.y + sin(a) * (R - 6));
    CGContextStrokePath(c);

    // so lieu o giua
    NSString *sp = [NSString stringWithFormat:@"%.0f", self.speed];
    NSDictionary *spA = @{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:R * 0.42 weight:UIFontWeightHeavy], NSForegroundColorAttributeName: C_FG };
    CGSize s1 = [sp sizeWithAttributes:spA];
    [sp drawAtPoint:CGPointMake(ct.x - s1.width / 2, ct.y - s1.height * 0.62) withAttributes:spA];
    NSDictionary *uA = @{ NSFontAttributeName: PAFont(12, UIFontWeightSemibold), NSForegroundColorAttributeName: C_MUTED, NSKernAttributeName: @2 };
    NSString *u = @"KM/H";
    CGSize s2 = [u sizeWithAttributes:uA];
    [u drawAtPoint:CGPointMake(ct.x - s2.width / 2, ct.y + s1.height * 0.36) withAttributes:uA];
    NSString *g = !self.running ? @"OFF" : (self.speed < 1 ? @"N" : [NSString stringWithFormat:@"%d", self.gear + 1]);
    NSString *info = [NSString stringWithFormat:@"%@   ·   %.0f v/p", g, self.rpm];
    NSDictionary *iA = @{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightBold], NSForegroundColorAttributeName: C_AMBER };
    CGSize s3 = [info sizeWithAttributes:iA];
    [info drawAtPoint:CGPointMake(ct.x - s3.width / 2, ct.y + s1.height * 0.36 + s2.height + 6) withAttributes:iA];
    if (self.caption.length) {
        NSDictionary *cA = @{ NSFontAttributeName: PAFont(13, UIFontWeightMedium), NSForegroundColorAttributeName: C_MUTED };
        CGSize s4 = [self.caption sizeWithAttributes:cA];
        [self.caption drawAtPoint:CGPointMake(ct.x - s4.width / 2, MIN(H - s4.height - 2, ct.y + R * 0.78)) withAttributes:cA];
    }
}
@end

// ======================= Man hinh chinh =======================
@implementation PARootViewController {
    UIStackView *_stack;
    PAGaugeView *_gauge;
    CADisplayLink *_link;
    UIButton *_startBtn, *_permBtn;
    UILabel *_chipCar, *_chipGps, *_chipSensor;
    UIStackView *_cards;
    NSMutableArray<UIButton *> *_cardBtns;
    UISwitch *_enabledSw, *_onlyCarSw, *_popsSw, *_shiftSw, *_testSw;
    UISlider *_volSl, *_toneSl, *_testSl;
    UILabel *_testVal, *_volVal, *_toneVal;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = C_BG;
    self.navigationController.navigationBarHidden = YES;

    UIScrollView *sv = [UIScrollView new];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.alwaysBounceVertical = YES;
    sv.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [self.view addSubview:sv];
    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 14;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [sv addSubview:_stack];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:g.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_stack.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:6],
        [_stack.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-36],
        [_stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [_stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
    ]];

    PAEngine *e = PAEngine.shared;

    // --- Tieu de ---
    UILabel *title = [UILabel new];
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:@"NDA DRIVE  " attributes:@{ NSFontAttributeName: PAFont(26, UIFontWeightHeavy), NSForegroundColorAttributeName: C_FG }];
    [t appendAttributedString:[[NSAttributedString alloc] initWithString:@"PÔ ẢO" attributes:@{ NSFontAttributeName: PAFont(26, UIFontWeightHeavy), NSForegroundColorAttributeName: C_AMBER }]];
    title.attributedText = t;
    [_stack addArrangedSubview:title];

    // --- Chip trang thai ---
    _chipCar = [self chip]; _chipGps = [self chip]; _chipSensor = [self chip];
    UIStackView *chips = [[UIStackView alloc] initWithArrangedSubviews:@[_chipCar, _chipGps, _chipSensor]];
    chips.spacing = 8; chips.distribution = UIStackViewDistributionFillEqually;
    [_stack addArrangedSubview:chips];

    // --- Dong ho ---
    _gauge = [PAGaugeView new];
    [_gauge.heightAnchor constraintEqualToAnchor:_gauge.widthAnchor multiplier:0.86].active = YES;
    [_stack addArrangedSubview:_gauge];

    // --- Nut no may ---
    _startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _startBtn.titleLabel.font = PAFont(22, UIFontWeightHeavy);
    _startBtn.layer.cornerRadius = 16;
    [_startBtn.heightAnchor constraintEqualToConstant:64].active = YES;
    [_startBtn addTarget:self action:@selector(toggleEngine) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_startBtn];

    _permBtn = [self linkButton:@"⚠️ Cấp quyền vị trí: chọn \"Luôn luôn\"" action:@selector(askPermission)];
    [_stack addArrangedSubview:_permBtn];

    // --- Chon xe (the luot ngang) ---
    [_stack addArrangedSubview:[self header:@"CHỌN XE"]];
    UIScrollView *hs = [UIScrollView new];
    hs.showsHorizontalScrollIndicator = NO;
    hs.translatesAutoresizingMaskIntoConstraints = NO;
    _cards = [UIStackView new];
    _cards.spacing = 10;
    _cards.translatesAutoresizingMaskIntoConstraints = NO;
    [hs addSubview:_cards];
    [NSLayoutConstraint activateConstraints:@[
        [_cards.topAnchor constraintEqualToAnchor:hs.contentLayoutGuide.topAnchor], [_cards.bottomAnchor constraintEqualToAnchor:hs.contentLayoutGuide.bottomAnchor],
        [_cards.leadingAnchor constraintEqualToAnchor:hs.contentLayoutGuide.leadingAnchor], [_cards.trailingAnchor constraintEqualToAnchor:hs.contentLayoutGuide.trailingAnchor],
        [_cards.heightAnchor constraintEqualToAnchor:hs.frameLayoutGuide.heightAnchor],
        [hs.heightAnchor constraintEqualToConstant:96],
    ]];
    _cardBtns = [NSMutableArray array];
    for (int i = 0; i < PA_PRESET_COUNT; i++) {
        const PAPreset *p = &PA_PRESETS[i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = i;
        b.layer.cornerRadius = 14; b.layer.borderWidth = 1.5;
        b.backgroundColor = C_CARD;
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        b.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 12);
        b.titleLabel.numberOfLines = 3;
        NSString *car = @(p->car);
        NSRange dot = [car rangeOfString:@" · "];
        NSString *sub = dot.location != NSNotFound ? [car substringToIndex:dot.location] : car;
        NSMutableAttributedString *as = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", @(p->name)]
            attributes:@{ NSFontAttributeName: PAFont(16, UIFontWeightBold), NSForegroundColorAttributeName: C_FG }];
        [as appendAttributedString:[[NSAttributedString alloc] initWithString:sub attributes:@{ NSFontAttributeName: PAFont(12, UIFontWeightMedium), NSForegroundColorAttributeName: C_MUTED }]];
        [b setAttributedTitle:as forState:UIControlStateNormal];
        [b.widthAnchor constraintEqualToConstant:156].active = YES;
        [b addTarget:self action:@selector(pickPreset:) forControlEvents:UIControlEventTouchUpInside];
        [_cards addArrangedSubview:b];
        [_cardBtns addObject:b];
    }
    [_stack addArrangedSubview:hs];

    // --- Am thanh ---
    [_stack addArrangedSubview:[self header:@"ÂM THANH"]];
    UIStackView *snd = [self card];
    _volSl = [self slider:@"Âm lượng" in:snd value:&_volVal];
    _toneSl = [self slider:@"Độ đanh của pô" in:snd value:&_toneVal];
    _popsSw = [self switchRow:@"Nổ lụp bụp khi nhả ga" in:snd];
    _shiftSw = [self switchRow:@"Tiếng \"bụp\" khi lên số" in:snd];

    // --- Hoat dong ---
    [_stack addArrangedSubview:[self header:@"HOẠT ĐỘNG"]];
    UIStackView *run = [self card];
    _enabledSw = [self switchRow:@"Bật pô ảo" in:run];
    _onlyCarSw = [self switchRow:@"Tự nổ máy khi kết nối CarPlay" in:run];
    [run addArrangedSubview:[self note:@"Gắn iPhone cố định trên giá. Lần đầu lái, tăng tốc và phanh vài lần để máy học hướng xe."]];

    // --- Thu khi do xe ---
    [_stack addArrangedSubview:[self header:@"THỬ KHI ĐỖ XE"]];
    UIStackView *ts = [self card];
    _testSw = [self switchRow:@"Giả lập tốc độ (không dùng GPS)" in:ts];
    _testSl = [self slider:@"Tốc độ giả lập" in:ts value:&_testVal];
    _testSl.maximumValue = 220;

    _enabledSw.on = e.enabled; _onlyCarSw.on = e.onlyWithCarPlay;
    _volSl.value = e.volume; _toneSl.value = e.toneAmount;
    _popsSw.on = e.popsEnabled; _shiftSw.on = e.shiftPopEnabled;
    _testSw.on = e.testMode; _testSl.value = e.testSpeedKmh;

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:PAEngineDidUpdateNotification object:nil];
    [self refresh];
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_link invalidate];
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)];
    _link.preferredFramesPerSecond = 30;
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_link invalidate]; _link = nil; }

#pragma mark - Thanh phan giao dien

- (UILabel *)chip {
    UILabel *l = [UILabel new];
    l.font = PAFont(12, UIFontWeightSemibold);
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 10; l.layer.borderWidth = 1; l.layer.borderColor = C_LINE.CGColor;
    l.clipsToBounds = YES;
    l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = 0.7;
    [l.heightAnchor constraintEqualToConstant:28].active = YES;
    return l;
}
- (void)setChip:(UILabel *)l text:(NSString *)t ok:(BOOL)ok {
    l.text = t;
    l.textColor = ok ? C_GREEN : C_MUTED;
    l.layer.borderColor = (ok ? [C_GREEN colorWithAlphaComponent:0.5] : C_LINE).CGColor;
}
- (UILabel *)header:(NSString *)text {
    UILabel *h = [UILabel new];
    h.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName: PAFont(12, UIFontWeightBold), NSForegroundColorAttributeName: C_MUTED, NSKernAttributeName: @1.5 }];
    return h;
}
- (UIStackView *)card {
    UIStackView *inner = [UIStackView new];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 12;
    inner.layoutMarginsRelativeArrangement = YES;
    inner.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(14, 14, 14, 14);
    UIView *bg = [UIView new];
    bg.backgroundColor = C_CARD; bg.layer.cornerRadius = 16; bg.layer.borderWidth = 1; bg.layer.borderColor = C_LINE.CGColor;
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    [inner insertSubview:bg atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [bg.topAnchor constraintEqualToAnchor:inner.topAnchor], [bg.bottomAnchor constraintEqualToAnchor:inner.bottomAnchor],
        [bg.leadingAnchor constraintEqualToAnchor:inner.leadingAnchor], [bg.trailingAnchor constraintEqualToAnchor:inner.trailingAnchor]]];
    [_stack addArrangedSubview:inner];
    return inner;
}
- (UISwitch *)switchRow:(NSString *)name in:(UIStackView *)parent {
    UILabel *l = [UILabel new]; l.text = name; l.numberOfLines = 0; l.textColor = C_FG; l.font = PAFont(16, UIFontWeightMedium);
    UISwitch *s = [UISwitch new];
    s.onTintColor = C_AMBER;
    [s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    [s setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, s]];
    row.alignment = UIStackViewAlignmentCenter; row.spacing = 12;
    [parent addArrangedSubview:row];
    return s;
}
- (UISlider *)slider:(NSString *)name in:(UIStackView *)parent value:(UILabel * __strong *)valOut {
    UILabel *l = [UILabel new]; l.text = name; l.font = PAFont(15, UIFontWeightMedium); l.textColor = C_MUTED;
    UILabel *v = [UILabel new]; v.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold]; v.textColor = C_FG;
    v.textAlignment = NSTextAlignmentRight;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, v]];
    UISlider *s = [UISlider new];
    s.minimumTrackTintColor = C_AMBER;
    [s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    [parent addArrangedSubview:row];
    [parent setCustomSpacing:4 afterView:row];
    [parent addArrangedSubview:s];
    if (valOut) *valOut = v;
    return s;
}
- (UIButton *)linkButton:(NSString *)title action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:C_AMBER forState:UIControlStateNormal];
    b.titleLabel.font = PAFont(15, UIFontWeightSemibold);
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UILabel *)note:(NSString *)text {
    UILabel *l = [UILabel new];
    l.text = text; l.numberOfLines = 0; l.font = PAFont(13, UIFontWeightRegular); l.textColor = C_MUTED;
    return l;
}

#pragma mark - Su kien

- (void)pickPreset:(UIButton *)b {
    PAEngine.shared.presetKey = @(PA_PRESETS[b.tag].key);
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];
    [self refresh];
}

- (void)changed:(id)sender {
    PAEngine *e = PAEngine.shared;
    if (sender == _enabledSw) e.enabled = _enabledSw.on;
    else if (sender == _onlyCarSw) e.onlyWithCarPlay = _onlyCarSw.on;
    else if (sender == _volSl) e.volume = _volSl.value;
    else if (sender == _toneSl) e.toneAmount = _toneSl.value;
    else if (sender == _popsSw) e.popsEnabled = _popsSw.on;
    else if (sender == _shiftSw) e.shiftPopEnabled = _shiftSw.on;
    else if (sender == _testSw) e.testMode = _testSw.on;
    else if (sender == _testSl) e.testSpeedKmh = round(_testSl.value);
    [self refresh];
}

- (void)toggleEngine {
    PAEngine *e = PAEngine.shared;
    if (e.engineOn) [e manualStop]; else [e manualStart];
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [h impactOccurred];
    [self refresh];
}

- (void)askPermission { [PAEngine.shared requestLocationPermission]; }

- (void)frame:(CADisplayLink *)l {
    PASynth *s = PAEngine.shared.synth;
    int pi = s->presetIndex;
    if (pi < 0 || pi >= PA_PRESET_COUNT) pi = 0;
    const PAPreset *p = &PA_PRESETS[pi];
    _gauge.redline = p->redline;
    _gauge.rpm = s->rpm;
    _gauge.speed = s->speed;
    _gauge.gear = s->gear;
    _gauge.running = s->state != PA_OFF;
    _gauge.caption = @(p->name);
    [_gauge setNeedsDisplay];
}

- (void)refresh {
    PAEngine *e = PAEngine.shared;
    BOOL on = e.engineOn;
    [_startBtn setTitle:(on ? @"TẮT MÁY" : @"NỔ MÁY") forState:UIControlStateNormal];
    _startBtn.backgroundColor = on ? UIColor.clearColor : C_RED;
    [_startBtn setTitleColor:(on ? C_RED : UIColor.whiteColor) forState:UIControlStateNormal];
    _startBtn.layer.borderWidth = on ? 2 : 0;
    _startBtn.layer.borderColor = C_RED.CGColor;

    [self setChip:_chipCar text:(e.carPlayConnected ? @"CarPlay ✓" : @"CarPlay ✗") ok:e.carPlayConnected];
    [self setChip:_chipGps text:(e.gpsSpeedKmh < 0 ? @"GPS —" : [NSString stringWithFormat:@"GPS %.0f", e.gpsSpeedKmh]) ok:e.gpsSpeedKmh >= 0];
    NSString *sens = e.sensorStatusText;
    BOOL learned = [sens rangeOfString:@"✓"].location != NSNotFound;
    [self setChip:_chipSensor text:(learned ? @"Cảm biến ✓" : ([sens isEqualToString:@"Tắt"] ? @"Cảm biến —" : @"Đang học…")) ok:learned];

    _permBtn.hidden = [e.locationStatusText rangeOfString:@"✓"].location != NSNotFound;

    for (UIButton *b in _cardBtns) {
        BOOL sel = [@(PA_PRESETS[b.tag].key) isEqualToString:e.presetKey];
        b.layer.borderColor = (sel ? C_AMBER : C_LINE).CGColor;
        b.backgroundColor = sel ? [C_AMBER colorWithAlphaComponent:0.12] : C_CARD;
    }
    _volVal.text = [NSString stringWithFormat:@"%.0f%%", e.volume * 100];
    _toneVal.text = e.toneAmount < 0.34 ? @"Êm" : (e.toneAmount < 0.67 ? @"Vừa" : @"Đanh");
    _testVal.text = [NSString stringWithFormat:@"%.0f km/h", e.testSpeedKmh];
    _testSl.enabled = e.testMode;
    _testSl.alpha = e.testMode ? 1 : 0.4;
}

@end
