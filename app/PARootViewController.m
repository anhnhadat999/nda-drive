#import "PARootViewController.h"
#import "PAEngine.h"
#import "PAUpdater.h"
#import "PATheme.h"

// ======================= Dong ho vong tua =======================
@interface PAGaugeView : UIView
@property (nonatomic) double rpm, redline, speed;
@property (nonatomic) int gear;
@property (nonatomic) BOOL running;
@end

@implementation PAGaugeView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; _redline = 9000; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGFloat R = MIN(W / 2, H * 0.6) - 14;
    if (R < 40) return;
    CGPoint ct = CGPointMake(W / 2, MIN(H * 0.56, R + 18));
    double maxV = ceil((self.redline + 1000) / 1000.0) * 1000;
    CGFloat a0 = M_PI * 0.78, a1 = M_PI * 2.22;
    CGFloat (^ang)(double) = ^CGFloat(double v) { return a0 + (a1 - a0) * fmin(1, fmax(0, v / maxV)); };

    CGContextSetLineCap(c, kCGLineCapButt);
    CGContextSetLineWidth(c, 14);
    [PA_LINE setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, a0, a1, 0); CGContextStrokePath(c);
    [[PA_RED colorWithAlphaComponent:0.85] setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, ang(self.redline), a1, 0); CGContextStrokePath(c);
    if (self.rpm > 1) {
        [(self.rpm > self.redline * 0.97 ? PA_RED : PA_AMBER) setStroke];
        CGContextAddArc(c, ct.x, ct.y, R, a0, ang(self.rpm), 0); CGContextStrokePath(c);
    }
    NSDictionary *num = @{ NSFontAttributeName: PAFont(13, UIFontWeightBold), NSForegroundColorAttributeName: PA_MUTED };
    NSDictionary *numRed = @{ NSFontAttributeName: PAFont(13, UIFontWeightBold), NSForegroundColorAttributeName: PA_RED };
    for (int v = 0; v <= (int)maxV; v += 500) {
        CGFloat a = ang(v); BOOL major = v % 1000 == 0;
        CGFloat r1 = R - 11, r2 = R - (major ? 24 : 17);
        [(v >= self.redline ? PA_RED : PA_MUTED) setStroke];
        CGContextSetLineWidth(c, major ? 2.5 : 1.5);
        CGContextMoveToPoint(c, ct.x + cos(a) * r1, ct.y + sin(a) * r1);
        CGContextAddLineToPoint(c, ct.x + cos(a) * r2, ct.y + sin(a) * r2);
        CGContextStrokePath(c);
        if (major) {
            NSString *t = [NSString stringWithFormat:@"%d", v / 1000];
            NSDictionary *at = v >= self.redline ? numRed : num;
            CGSize sz = [t sizeWithAttributes:at];
            CGFloat rr = R - 38;
            [t drawAtPoint:CGPointMake(ct.x + cos(a) * rr - sz.width / 2, ct.y + sin(a) * rr - sz.height / 2) withAttributes:at];
        }
    }
    CGFloat a = ang(self.rpm);
    [PA_AMBER setStroke];
    CGContextSetLineWidth(c, 4); CGContextSetLineCap(c, kCGLineCapRound);
    CGContextMoveToPoint(c, ct.x + cos(a) * R * 0.55, ct.y + sin(a) * R * 0.55);
    CGContextAddLineToPoint(c, ct.x + cos(a) * (R - 6), ct.y + sin(a) * (R - 6));
    CGContextStrokePath(c);

    NSString *sp = [NSString stringWithFormat:@"%.0f", self.speed];
    NSDictionary *spA = @{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:R * 0.44 weight:UIFontWeightHeavy], NSForegroundColorAttributeName: PA_FG };
    CGSize s1 = [sp sizeWithAttributes:spA];
    [sp drawAtPoint:CGPointMake(ct.x - s1.width / 2, ct.y - s1.height * 0.62) withAttributes:spA];
    NSDictionary *uA = @{ NSFontAttributeName: PAFont(12, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @2 };
    NSString *u = @"KM/H";
    CGSize s2 = [u sizeWithAttributes:uA];
    [u drawAtPoint:CGPointMake(ct.x - s2.width / 2, ct.y + s1.height * 0.36) withAttributes:uA];
    NSString *g = !self.running ? @"OFF" : (self.speed < 1 ? @"N" : [NSString stringWithFormat:@"%d", self.gear + 1]);
    NSString *info = [NSString stringWithFormat:@"%@   ·   %.0f v/p", g, self.rpm];
    NSDictionary *iA = @{ NSFontAttributeName: [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightBold], NSForegroundColorAttributeName: PA_AMBER };
    CGSize s3 = [info sizeWithAttributes:iA];
    [info drawAtPoint:CGPointMake(ct.x - s3.width / 2, ct.y + s1.height * 0.36 + s2.height + 6) withAttributes:iA];
}
@end

// ======================= Tab Lai xe =======================
@implementation PARootViewController {
    UIStackView *_stack;
    PAGaugeView *_gauge;
    CADisplayLink *_link;
    UIButton *_startBtn, *_updateBtn, *_permBtn;
    UILabel *_chipCar, *_chipGps, *_chipSensor;
    UILabel *_carName, *_carSub, *_carSpec;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Lái xe";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Lái xe" image:[UIImage systemImageNamed:@"speedometer"] tag:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PA_BG;

    UIScrollView *sv = [UIScrollView new];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.alwaysBounceVertical = YES;
    [self.view addSubview:sv];
    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 14;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [sv addSubview:_stack];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.view.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_stack.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:4],
        [_stack.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-24],
        [_stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [_stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
    ]];

    // dai bao ban moi
    _updateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _updateBtn.backgroundColor = [PA_AMBER colorWithAlphaComponent:0.15];
    _updateBtn.layer.cornerRadius = 12; _updateBtn.layer.borderWidth = 1; _updateBtn.layer.borderColor = PA_AMBER.CGColor;
    _updateBtn.titleLabel.font = PAFont(15, UIFontWeightSemibold);
    [_updateBtn setTitleColor:PA_AMBER forState:UIControlStateNormal];
    [_updateBtn.heightAnchor constraintEqualToConstant:44].active = YES;
    [_updateBtn addTarget:PAUpdater.shared action:@selector(openUpdateInSileo) forControlEvents:UIControlEventTouchUpInside];
    _updateBtn.hidden = YES;
    [_stack addArrangedSubview:_updateBtn];

    // chip trang thai
    _chipCar = [self chip]; _chipGps = [self chip]; _chipSensor = [self chip];
    UIStackView *chips = [[UIStackView alloc] initWithArrangedSubviews:@[_chipCar, _chipGps, _chipSensor]];
    chips.spacing = 8; chips.distribution = UIStackViewDistributionFillEqually;
    [_stack addArrangedSubview:chips];

    // dong ho
    _gauge = [PAGaugeView new];
    [_gauge.heightAnchor constraintEqualToAnchor:_gauge.widthAnchor multiplier:0.80].active = YES;
    [_stack addArrangedSubview:_gauge];

    // nut no may
    _startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _startBtn.titleLabel.font = PAFont(22, UIFontWeightHeavy);
    _startBtn.layer.cornerRadius = 16;
    [_startBtn.heightAnchor constraintEqualToConstant:62].active = YES;
    [_startBtn addTarget:self action:@selector(toggleEngine) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_startBtn];

    _permBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_permBtn setTitle:@"Cấp quyền vị trí: chọn \"Luôn luôn\"" forState:UIControlStateNormal];
    [_permBtn setTitleColor:PA_AMBER forState:UIControlStateNormal];
    _permBtn.titleLabel.font = PAFont(15, UIFontWeightSemibold);
    [_permBtn addTarget:self action:@selector(askPermission) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_permBtn];

    // the xe dang chon (cham de doi xe)
    UIControl *card = [UIControl new];
    card.backgroundColor = PA_CARD;
    card.layer.cornerRadius = 18; card.layer.borderWidth = 1; card.layer.borderColor = PA_LINE.CGColor;
    [card addTarget:self action:@selector(openCars) forControlEvents:UIControlEventTouchUpInside];
    UILabel *cap = [UILabel new];
    cap.attributedText = [[NSAttributedString alloc] initWithString:@"XE ĐANG CHỌN" attributes:@{ NSFontAttributeName: PAFont(12, UIFontWeightBold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @1.5 }];
    _carName = [UILabel new]; _carName.font = PAFont(30, UIFontWeightHeavy); _carName.textColor = PA_FG; _carName.adjustsFontSizeToFitWidth = YES; _carName.minimumScaleFactor = 0.6;
    _carSub = [UILabel new]; _carSub.font = PAFont(14, UIFontWeightMedium); _carSub.textColor = PA_MUTED; _carSub.numberOfLines = 2;
    _carSpec = [UILabel new]; _carSpec.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightSemibold]; _carSpec.textColor = PA_AMBER;
    UILabel *change = [UILabel new]; change.text = @"Đổi xe ›"; change.font = PAFont(15, UIFontWeightSemibold); change.textColor = PA_AMBER;
    for (UIView *v in @[cap, _carName, _carSub, _carSpec, change]) { v.translatesAutoresizingMaskIntoConstraints = NO; v.userInteractionEnabled = NO; [card addSubview:v]; }
    [NSLayoutConstraint activateConstraints:@[
        [cap.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [cap.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [change.centerYAnchor constraintEqualToAnchor:cap.centerYAnchor],
        [change.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [_carName.topAnchor constraintEqualToAnchor:cap.bottomAnchor constant:6],
        [_carName.leadingAnchor constraintEqualToAnchor:cap.leadingAnchor],
        [_carName.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [_carSub.topAnchor constraintEqualToAnchor:_carName.bottomAnchor constant:2],
        [_carSub.leadingAnchor constraintEqualToAnchor:cap.leadingAnchor],
        [_carSub.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [_carSpec.topAnchor constraintEqualToAnchor:_carSub.bottomAnchor constant:8],
        [_carSpec.leadingAnchor constraintEqualToAnchor:cap.leadingAnchor],
        [_carSpec.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [_carSpec.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];
    [_stack addArrangedSubview:card];

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(refresh) name:PAEngineDidUpdateNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:PAUpdaterDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:@"PAPresetChanged" object:nil];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    [_link invalidate];
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)];
    _link.preferredFramesPerSecond = 30;
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    [self refresh];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_link invalidate]; _link = nil; }

- (UILabel *)chip {
    UILabel *l = [UILabel new];
    l.font = PAFont(12, UIFontWeightSemibold);
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 10; l.layer.borderWidth = 1; l.layer.borderColor = PA_LINE.CGColor;
    l.clipsToBounds = YES;
    l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = 0.7;
    [l.heightAnchor constraintEqualToConstant:28].active = YES;
    return l;
}
- (void)setChip:(UILabel *)l text:(NSString *)t ok:(BOOL)ok {
    l.text = t;
    l.textColor = ok ? PA_GREEN : PA_MUTED;
    l.layer.borderColor = (ok ? [PA_GREEN colorWithAlphaComponent:0.5] : PA_LINE).CGColor;
}

- (void)toggleEngine {
    PAEngine *e = PAEngine.shared;
    if (e.engineOn) [e manualStop]; else [e manualStart];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy] impactOccurred];
    [self refresh];
}
- (void)askPermission { [PAEngine.shared requestLocationPermission]; }
- (void)openCars { self.tabBarController.selectedIndex = 1; }

- (void)frame:(CADisplayLink *)l {
    PASynth *s = PAEngine.shared.synth;
    int pi = s->presetIndex;
    if (pi < 0 || pi >= PA_PRESET_COUNT) pi = 0;
    _gauge.redline = PA_PRESETS[pi].redline;
    _gauge.rpm = s->rpm;
    _gauge.speed = s->speed;
    _gauge.gear = s->gear;
    _gauge.running = s->state != PA_OFF;
    [_gauge setNeedsDisplay];
}

- (void)refresh {
    PAEngine *e = PAEngine.shared;
    PAUpdater *u = PAUpdater.shared;
    BOOL on = e.engineOn;
    [_startBtn setTitle:(on ? @"TẮT MÁY" : @"NỔ MÁY") forState:UIControlStateNormal];
    _startBtn.backgroundColor = on ? UIColor.clearColor : PA_RED;
    [_startBtn setTitleColor:(on ? PA_RED : UIColor.whiteColor) forState:UIControlStateNormal];
    _startBtn.layer.borderWidth = on ? 2 : 0;
    _startBtn.layer.borderColor = PA_RED.CGColor;

    [self setChip:_chipCar text:(e.carPlayConnected ? @"CarPlay ✓" : @"CarPlay ✗") ok:e.carPlayConnected];
    [self setChip:_chipGps text:(e.gpsSpeedKmh < 0 ? @"GPS —" : [NSString stringWithFormat:@"GPS %.0f", e.gpsSpeedKmh]) ok:e.gpsSpeedKmh >= 0];
    NSString *sens = e.sensorStatusText;
    BOOL learned = [sens rangeOfString:@"✓"].location != NSNotFound;
    [self setChip:_chipSensor text:(learned ? @"Cảm biến ✓" : ([sens isEqualToString:@"Tắt"] ? @"Cảm biến —" : @"Đang học…")) ok:learned];
    _permBtn.hidden = [e.locationStatusText rangeOfString:@"✓"].location != NSNotFound;

    _updateBtn.hidden = !u.updateAvailable;
    [_updateBtn setTitle:[NSString stringWithFormat:@"Có bản mới %@ – chạm để cập nhật", u.latestVersion ?: @""] forState:UIControlStateNormal];

    int pi = pa_preset_index(e.presetKey.UTF8String);
    const PAPreset *p = &PA_PRESETS[pi];
    _carName.text = @(p->name);
    _carSub.text = @(p->car);
    _carSpec.text = [NSString stringWithFormat:@"%d xi-lanh · tối đa %.0f v/p%@", p->cyl, p->redline, p->turbo ? @" · turbo" : @""];
}

@end
