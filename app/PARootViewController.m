#import "PARootViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PAUpdater.h"
#import "PATheme.h"

// ======================= Dong ho vong tua (phong cach mong, sang) =======================
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
    CGFloat R = MIN(W / 2, H * 0.62) - 12;
    if (R < 40) return;
    CGPoint ct = CGPointMake(W / 2, MIN(H * 0.57, R + 14));
    double maxV = ceil((self.redline + 1000) / 1000.0) * 1000;
    CGFloat a0 = M_PI * 0.75, a1 = M_PI * 2.25;
    CGFloat (^ang)(double) = ^CGFloat(double v) { return a0 + (a1 - a0) * fmin(1, fmax(0, v / maxV)); };

    // vong nen mong + vach do
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineWidth(c, 5);
    [PA_LINE setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, a0, a1, 0); CGContextStrokePath(c);
    [[PA_RED colorWithAlphaComponent:0.9] setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, ang(self.redline), a1, 0); CGContextStrokePath(c);
    // vong tua: vang champagne co quang sang nhe
    if (self.rpm > 1) {
        UIColor *col = self.rpm > self.redline * 0.97 ? PA_RED : PA_AMBER;
        CGContextSaveGState(c);
        CGContextSetShadowWithColor(c, CGSizeZero, 10, [col colorWithAlphaComponent:0.7].CGColor);
        [col setStroke];
        CGContextSetLineWidth(c, 5);
        CGContextAddArc(c, ct.x, ct.y, R, a0, ang(self.rpm), 0); CGContextStrokePath(c);
        CGContextRestoreGState(c);
    }
    // vach chia mong
    NSDictionary *num = @{ NSFontAttributeName: PAFont(12, UIFontWeightMedium), NSForegroundColorAttributeName: PA_MUTED };
    NSDictionary *numRed = @{ NSFontAttributeName: PAFont(12, UIFontWeightMedium), NSForegroundColorAttributeName: PA_RED };
    for (int v = 0; v <= (int)maxV; v += 250) {
        CGFloat a = ang(v); BOOL major = v % 1000 == 0, mid = v % 500 == 0;
        CGFloat r1 = R - 10, r2 = R - (major ? 20 : (mid ? 15 : 13));
        [[(v >= self.redline ? PA_RED : PA_MUTED) colorWithAlphaComponent:major ? 1 : 0.55] setStroke];
        CGContextSetLineWidth(c, major ? 1.8 : 1);
        CGContextSetLineCap(c, kCGLineCapButt);
        CGContextMoveToPoint(c, ct.x + cos(a) * r1, ct.y + sin(a) * r1);
        CGContextAddLineToPoint(c, ct.x + cos(a) * r2, ct.y + sin(a) * r2);
        CGContextStrokePath(c);
        if (major) {
            NSString *t = [NSString stringWithFormat:@"%d", v / 1000];
            NSDictionary *at = v >= self.redline ? numRed : num;
            CGSize sz = [t sizeWithAttributes:at];
            CGFloat rr = R - 34;
            [t drawAtPoint:CGPointMake(ct.x + cos(a) * rr - sz.width / 2, ct.y + sin(a) * rr - sz.height / 2) withAttributes:at];
        }
    }
    // dau kim
    CGFloat a = ang(self.rpm);
    CGPoint tip = CGPointMake(ct.x + cos(a) * R, ct.y + sin(a) * R);
    [PA_FG setFill];
    CGContextFillEllipseInRect(c, CGRectMake(tip.x - 4.5, tip.y - 4.5, 9, 9));

    // toc do: chu so manh, lon
    NSString *sp = [NSString stringWithFormat:@"%.0f", self.speed];
    NSDictionary *spA = @{ NSFontAttributeName: PAMono(R * 0.5, UIFontWeightThin), NSForegroundColorAttributeName: PA_FG };
    CGSize s1 = [sp sizeWithAttributes:spA];
    [sp drawAtPoint:CGPointMake(ct.x - s1.width / 2, ct.y - s1.height * 0.6) withAttributes:spA];
    NSDictionary *uA = @{ NSFontAttributeName: PAFont(11, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @3 };
    NSString *u = @"KM/H";
    CGSize s2 = [u sizeWithAttributes:uA];
    [u drawAtPoint:CGPointMake(ct.x - s2.width / 2, ct.y + s1.height * 0.36) withAttributes:uA];
    // so + vong tua
    NSString *g = !self.running ? @"OFF" : (self.speed < 1 ? @"N" : [NSString stringWithFormat:@"%d", self.gear + 1]);
    NSDictionary *gA = @{ NSFontAttributeName: PAFont(17, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_AMBER };
    CGSize s3 = [g sizeWithAttributes:gA];
    CGFloat gy = ct.y + s1.height * 0.36 + s2.height + 12;
    CGRect pill = CGRectMake(ct.x - MAX(30, s3.width + 18) / 2, gy, MAX(30, s3.width + 18), s3.height + 6);
    UIBezierPath *pp = [UIBezierPath bezierPathWithRoundedRect:pill cornerRadius:pill.size.height / 2];
    [[PA_AMBER colorWithAlphaComponent:0.7] setStroke]; pp.lineWidth = 1; [pp stroke];
    [g drawAtPoint:CGPointMake(ct.x - s3.width / 2, gy + 3) withAttributes:gA];
    NSString *rp = [NSString stringWithFormat:@"%.0f v/p", round(self.rpm / 10) * 10];
    NSDictionary *rA = @{ NSFontAttributeName: PAMono(12, UIFontWeightMedium), NSForegroundColorAttributeName: PA_MUTED };
    CGSize s4 = [rp sizeWithAttributes:rA];
    [rp drawAtPoint:CGPointMake(ct.x - s4.width / 2, CGRectGetMaxY(pill) + 6) withAttributes:rA];
}
@end

// ======================= Tab Lai xe =======================
@implementation PARootViewController {
    UIStackView *_stack;
    PAGaugeView *_gauge;
    CADisplayLink *_link;
    UIButton *_startBtn, *_updateBtn, *_permBtn;
    UILabel *_chipCar, *_chipGps, *_chipSensor;
    UILabel *_carName, *_carSub;
    NSArray<UILabel *> *_hud;
    NSUInteger _frameN;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"NDA Drive";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Lái xe" image:[UIImage systemImageNamed:@"gauge"] tag:0];
    }
    return self;
}

- (UIView *)cardWith:(UIView *)content inset:(CGFloat)inset {
    UIView *card = [UIView new];
    card.backgroundColor = PA_CARD;
    card.layer.cornerRadius = 20; card.layer.borderWidth = 0.5; card.layer.borderColor = PA_LINE.CGColor;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:inset], [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-inset],
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:inset], [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-inset]]];
    return card;
}

- (UILabel *)caption:(NSString *)t {
    UILabel *l = [UILabel new];
    l.attributedText = [[NSAttributedString alloc] initWithString:t attributes:@{ NSFontAttributeName: PAFont(10.5, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @1.6 }];
    return l;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PA_BG;
    UIScrollView *sv = [UIScrollView new];
    sv.translatesAutoresizingMaskIntoConstraints = NO; sv.alwaysBounceVertical = YES;
    [self.view addSubview:sv];
    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical; _stack.spacing = 14;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [sv addSubview:_stack];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.view.topAnchor], [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_stack.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:4],
        [_stack.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-28],
        [_stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:18],
        [_stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-18],
    ]];

    _updateBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _updateBtn.backgroundColor = [PA_AMBER colorWithAlphaComponent:0.12];
    _updateBtn.layer.cornerRadius = 14; _updateBtn.layer.borderWidth = 0.5; _updateBtn.layer.borderColor = PA_AMBER.CGColor;
    _updateBtn.titleLabel.font = PAFont(14, UIFontWeightSemibold);
    [_updateBtn setTitleColor:PA_AMBER forState:UIControlStateNormal];
    [_updateBtn.heightAnchor constraintEqualToConstant:42].active = YES;
    [_updateBtn addTarget:PAUpdater.shared action:@selector(openUpdateInSileo) forControlEvents:UIControlEventTouchUpInside];
    _updateBtn.hidden = YES;
    [_stack addArrangedSubview:_updateBtn];

    _chipCar = [self chip]; _chipGps = [self chip]; _chipSensor = [self chip];
    UIStackView *chips = [[UIStackView alloc] initWithArrangedSubviews:@[_chipCar, _chipGps, _chipSensor]];
    chips.spacing = 8; chips.distribution = UIStackViewDistributionFillEqually;
    [_stack addArrangedSubview:chips];

    _gauge = [PAGaugeView new];
    [_gauge.heightAnchor constraintEqualToAnchor:_gauge.widthAnchor multiplier:0.82].active = YES;
    [_stack addArrangedSubview:_gauge];

    _startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _startBtn.layer.cornerRadius = 29;
    [_startBtn.heightAnchor constraintEqualToConstant:58].active = YES;
    [_startBtn addTarget:self action:@selector(toggleEngine) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_startBtn];

    _permBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_permBtn setTitle:@"Cấp quyền vị trí: chọn \"Luôn luôn\"" forState:UIControlStateNormal];
    [_permBtn setTitleColor:PA_AMBER forState:UIControlStateNormal];
    _permBtn.titleLabel.font = PAFont(14, UIFontWeightMedium);
    [_permBtn addTarget:self action:@selector(askPermission) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_permBtn];

    // the xe dang chon
    UIControl *carCtl = [UIControl new];
    [carCtl addTarget:self action:@selector(openCars) forControlEvents:UIControlEventTouchUpInside];
    UILabel *cap = [self caption:@"XE ĐANG CHỌN"];
    _carName = [UILabel new]; _carName.font = PAFont(26, UIFontWeightLight); _carName.textColor = PA_FG; _carName.adjustsFontSizeToFitWidth = YES; _carName.minimumScaleFactor = 0.6;
    _carSub = [UILabel new]; _carSub.font = PAFont(13, UIFontWeightRegular); _carSub.textColor = PA_MUTED; _carSub.numberOfLines = 2;
    UILabel *chg = [UILabel new]; chg.text = @"Đổi ›"; chg.font = PAFont(14, UIFontWeightMedium); chg.textColor = PA_AMBER;
    UIStackView *head = [[UIStackView alloc] initWithArrangedSubviews:@[cap, chg]];
    UIStackView *cs = [[UIStackView alloc] initWithArrangedSubviews:@[head, _carName, _carSub]];
    cs.axis = UILayoutConstraintAxisVertical; cs.spacing = 4; cs.userInteractionEnabled = NO;
    UIView *carCard = [self cardWith:cs inset:18];
    carCard.userInteractionEnabled = NO;
    carCtl.translatesAutoresizingMaskIntoConstraints = NO; carCard.translatesAutoresizingMaskIntoConstraints = NO;
    [carCtl addSubview:carCard];
    [NSLayoutConstraint activateConstraints:@[[carCard.topAnchor constraintEqualToAnchor:carCtl.topAnchor], [carCard.bottomAnchor constraintEqualToAnchor:carCtl.bottomAnchor],
        [carCard.leadingAnchor constraintEqualToAnchor:carCtl.leadingAnchor], [carCard.trailingAnchor constraintEqualToAnchor:carCtl.trailingAnchor]]];
    [_stack addArrangedSubview:carCtl];

    // o du lieu cam bien (truc tiep)
    NSArray *caps = @[@"NGUỒN CẢM BIẾN", @"TẦN SỐ", @"GIA TỐC X·Y·Z (m/s²)", @"CON QUAY", @"GPS", @"ĐỘ CHÍNH XÁC", @"HƯỚNG XE", @"NGHIÊNG · ÁP KẾ"];
    NSMutableArray *vals = [NSMutableArray array];
    UIStackView *grid = [UIStackView new]; grid.axis = UILayoutConstraintAxisVertical; grid.spacing = 10;
    UIStackView *title = [[UIStackView alloc] initWithArrangedSubviews:@[[self caption:@"DỮ LIỆU CẢM BIẾN · TRỰC TIẾP"]]];
    [grid addArrangedSubview:title];
    for (NSUInteger i = 0; i < caps.count; i += 2) {
        UIStackView *row = [UIStackView new]; row.distribution = UIStackViewDistributionFillEqually; row.spacing = 12;
        for (NSUInteger j = i; j < i + 2; j++) {
            UILabel *cl = [UILabel new]; cl.text = caps[j]; cl.font = PAFont(9.5, UIFontWeightSemibold); cl.textColor = PA_MUTED;
            UILabel *vl = [UILabel new]; vl.text = @"—"; vl.font = PAMono(12.5, UIFontWeightMedium); vl.textColor = PA_FG;
            vl.adjustsFontSizeToFitWidth = YES; vl.minimumScaleFactor = 0.6;
            UIStackView *cell = [[UIStackView alloc] initWithArrangedSubviews:@[cl, vl]]; cell.axis = UILayoutConstraintAxisVertical; cell.spacing = 2;
            [row addArrangedSubview:cell]; [vals addObject:vl];
        }
        [grid addArrangedSubview:row];
    }
    _hud = vals;
    [_stack addArrangedSubview:[self cardWith:grid inset:16]];

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
    l.font = PAFont(11.5, UIFontWeightMedium);
    l.textAlignment = NSTextAlignmentCenter;
    l.layer.cornerRadius = 13; l.layer.borderWidth = 0.5; l.layer.borderColor = PA_LINE.CGColor;
    l.clipsToBounds = YES; l.adjustsFontSizeToFitWidth = YES; l.minimumScaleFactor = 0.7;
    [l.heightAnchor constraintEqualToConstant:26].active = YES;
    return l;
}
- (void)setChip:(UILabel *)l text:(NSString *)t ok:(BOOL)ok {
    l.text = t;
    l.textColor = ok ? PA_GREEN : PA_MUTED;
    l.backgroundColor = ok ? [PA_GREEN colorWithAlphaComponent:0.08] : UIColor.clearColor;
    l.layer.borderColor = (ok ? [PA_GREEN colorWithAlphaComponent:0.4] : PA_LINE).CGColor;
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
    _gauge.rpm = s->rpm; _gauge.speed = s->speed; _gauge.gear = s->gear; _gauge.running = s->state != PA_OFF;
    [_gauge setNeedsDisplay];
    if (++_frameN % 8 == 0) [self updateHUD];
}

- (void)updateHUD {
    PAMotion *m = (PAMotion *)PAEngine.shared.motion;
    BOOL on = m.running;
    NSString *(^f)(NSString *, ...) = ^NSString *(NSString *fmt, ...) { va_list ap; va_start(ap, fmt); NSString *r = [[NSString alloc] initWithFormat:fmt arguments:ap]; va_end(ap); return r; };
    _hud[0].text = on ? (m.gpsOnlyFallback && m.imuHz < 1 ? @"Chỉ GPS" : m.sourceName) : @"Tắt";
    _hud[0].textColor = on && m.imuHz > 5 ? PA_GREEN : (on ? PA_RED : PA_MUTED);
    _hud[1].text = on ? f(@"IMU %.0f Hz · GPS %.1f Hz", m.imuHz, m.gpsHz) : @"—";
    _hud[2].text = on ? f(@"%+.2f  %+.2f  %+.2f", m.ax, m.ay, m.az) : @"—";
    _hud[3].text = on ? f(@"%.2f rad/s", m.gyroMag) : @"—";
    _hud[4].text = on && m.gpsRawKmh >= 0 ? f(@"%.1f km/h · %ld mẫu", m.gpsRawKmh, (long)m.gpsCount) : (on ? @"đang chờ tín hiệu" : @"—");
    _hud[5].text = on && m.gpsAccuracy > 0 ? f(@"±%.1f m/s · %.1f s trước", m.gpsAccuracy, m.gpsAge) : (on ? f(@"%.0f s chưa có", m.gpsAge) : @"—");
    _hud[6].text = on ? (m.calibrated ? f(@"Đã học ✓ · lệch %.0f°", fabs(m.mountAngleDeg)) : f(@"Đang học %.0f%%", m.calProgress * 100)) : @"—";
    _hud[7].text = on ? f(@"%.0f° · %+.1f m", m.tiltDeg, m.altitudeM) : @"—";
    if (m.lastError.length) { _hud[0].text = @"Lỗi cảm biến"; _hud[1].text = m.lastError; }
}

- (void)refresh {
    PAEngine *e = PAEngine.shared;
    PAUpdater *u = PAUpdater.shared;
    BOOL on = e.engineOn;
    NSDictionary *bt = @{ NSFontAttributeName: PAFont(17, UIFontWeightSemibold), NSKernAttributeName: @3,
                          NSForegroundColorAttributeName: on ? PA_AMBER : PA_BG };
    [_startBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:(on ? @"TẮT MÁY" : @"NỔ MÁY") attributes:bt] forState:UIControlStateNormal];
    _startBtn.backgroundColor = on ? UIColor.clearColor : PA_AMBER;
    _startBtn.layer.borderWidth = on ? 1 : 0;
    _startBtn.layer.borderColor = PA_AMBER.CGColor;

    [self setChip:_chipCar text:(e.carPlayConnected ? @"CarPlay ✓" : @"CarPlay") ok:e.carPlayConnected];
    [self setChip:_chipGps text:(e.gpsSpeedKmh < 0 ? @"GPS" : [NSString stringWithFormat:@"GPS %.0f", e.gpsSpeedKmh]) ok:e.gpsSpeedKmh >= 0];
    PAMotion *m = (PAMotion *)e.motion;
    BOOL sens = m.running && m.imuHz > 5;
    [self setChip:_chipSensor text:(sens ? (m.calibrated ? @"Cảm biến ✓" : @"Đang học") : @"Cảm biến") ok:sens && m.calibrated];
    _permBtn.hidden = [e.locationStatusText rangeOfString:@"✓"].location != NSNotFound;

    _updateBtn.hidden = !u.updateAvailable;
    [_updateBtn setTitle:[NSString stringWithFormat:@"Có bản mới %@ · chạm để cập nhật", u.latestVersion ?: @""] forState:UIControlStateNormal];

    const PAPreset *p = &PA_PRESETS[pa_preset_index(e.presetKey.UTF8String)];
    _carName.text = @(p->name);
    _carSub.text = [NSString stringWithFormat:@"%s\n%d xi-lanh · tối đa %.0f v/p%@", p->car, p->cyl, p->redline, p->turbo ? @" · turbo" : @""];
}

@end
