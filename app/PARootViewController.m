#import "PARootViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PAUpdater.h"
#import "PATheme.h"
#import "PAVehicles.h"

// ======================= Cum dong ho: toc do (trai) + vong tua (phai) =======================
@interface PAClusterView : UIView
@property (nonatomic) double rpm, redline, speed, load;
@property (nonatomic) int gear;
@property (nonatomic) BOOL running;
@end

@implementation PAClusterView
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; _redline = 7000; } return self; }

static void dial(CGContextRef c, CGPoint ct, CGFloat R, double v, double maxV, double red, double step, double labelDiv, NSString *unit, NSString *big, UIColor *col) {
    CGFloat a0 = M_PI * 0.75, a1 = M_PI * 2.25;
    CGFloat (^ang)(double) = ^CGFloat(double x) { return a0 + (a1 - a0) * fmin(1, fmax(0, x / maxV)); };
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineWidth(c, 4); [PA_LINE setStroke];
    CGContextAddArc(c, ct.x, ct.y, R, a0, a1, 0); CGContextStrokePath(c);
    if (red > 0) { [[PA_RED colorWithAlphaComponent:0.85] setStroke]; CGContextAddArc(c, ct.x, ct.y, R, ang(red), a1, 0); CGContextStrokePath(c); }
    if (v > 0.5) {
        UIColor *k = red > 0 && v > red * 0.97 ? PA_RED : col;
        CGContextSaveGState(c);
        CGContextSetShadowWithColor(c, CGSizeZero, 8, [k colorWithAlphaComponent:0.7].CGColor);
        [k setStroke]; CGContextSetLineWidth(c, 4);
        CGContextAddArc(c, ct.x, ct.y, R, a0, ang(v), 0); CGContextStrokePath(c);
        CGContextRestoreGState(c);
    }
    NSDictionary *num = @{ NSFontAttributeName: PAFont(MAX(8, R * 0.11), UIFontWeightMedium), NSForegroundColorAttributeName: PA_MUTED };
    for (double x = 0; x <= maxV + 0.1; x += step) {
        CGFloat a = ang(x); BOOL major = fmod(x, labelDiv) < 0.01;
        CGFloat r1 = R - 7, r2 = R - (major ? 15 : 11);
        [[(red > 0 && x >= red ? PA_RED : PA_MUTED) colorWithAlphaComponent:major ? 1 : 0.5] setStroke];
        CGContextSetLineWidth(c, major ? 1.6 : 0.8); CGContextSetLineCap(c, kCGLineCapButt);
        CGContextMoveToPoint(c, ct.x + cos(a) * r1, ct.y + sin(a) * r1); CGContextAddLineToPoint(c, ct.x + cos(a) * r2, ct.y + sin(a) * r2); CGContextStrokePath(c);
        if (major) {
            NSString *t = [NSString stringWithFormat:@"%.0f", red > 0 ? x / 1000 : x];
            CGSize sz = [t sizeWithAttributes:num]; CGFloat rr = R - 25;
            [t drawAtPoint:CGPointMake(ct.x + cos(a) * rr - sz.width / 2, ct.y + sin(a) * rr - sz.height / 2) withAttributes:num];
        }
    }
    // kim
    CGFloat a = ang(v);
    [PA_FG setStroke]; CGContextSetLineWidth(c, 2); CGContextSetLineCap(c, kCGLineCapRound);
    CGContextMoveToPoint(c, ct.x + cos(a) * R * 0.18, ct.y + sin(a) * R * 0.18);
    CGContextAddLineToPoint(c, ct.x + cos(a) * (R - 5), ct.y + sin(a) * (R - 5)); CGContextStrokePath(c);
    [PA_CARD setFill]; [PA_LINE setStroke];
    CGContextAddEllipseInRect(c, CGRectMake(ct.x - 6, ct.y - 6, 12, 12)); CGContextDrawPath(c, kCGPathFillStroke);
    NSDictionary *bA = @{ NSFontAttributeName: PAMono(R * 0.3, UIFontWeightLight), NSForegroundColorAttributeName: PA_FG };
    CGSize bs = [big sizeWithAttributes:bA];
    [big drawAtPoint:CGPointMake(ct.x - bs.width / 2, ct.y + R * 0.3) withAttributes:bA];
    NSDictionary *uA = @{ NSFontAttributeName: PAFont(MAX(8, R * 0.1), UIFontWeightSemibold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @1.5 };
    CGSize us = [unit sizeWithAttributes:uA];
    [unit drawAtPoint:CGPointMake(ct.x - us.width / 2, ct.y + R * 0.3 + bs.height - 2) withAttributes:uA];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGFloat R = MIN(W * 0.235, H * 0.5);
    CGPoint L = CGPointMake(W * 0.255, H * 0.5), Rt = CGPointMake(W * 0.745, H * 0.5);
    dial(c, L, R, self.speed, 220, 0, 10, 40, @"KM/H", [NSString stringWithFormat:@"%.0f", self.speed], PA_AMBER);
    double maxR = ceil((self.redline + 1000) / 1000.0) * 1000;
    dial(c, Rt, R, self.rpm, maxR, self.redline, 500, 1000, @"×1000 V/P", [NSString stringWithFormat:@"%.1f", self.rpm / 1000], PA_AMBER);
    // so o giua
    NSString *g = !self.running ? @"P" : (self.speed < 1 ? @"N" : [NSString stringWithFormat:@"%d", self.gear + 1]);
    NSDictionary *gA = @{ NSFontAttributeName: PAFont(R * 0.42, UIFontWeightBold), NSForegroundColorAttributeName: self.running ? PA_AMBER : PA_MUTED };
    CGSize gs = [g sizeWithAttributes:gA];
    [g drawAtPoint:CGPointMake(W / 2 - gs.width / 2, H * 0.5 - gs.height / 2) withAttributes:gA];
    NSDictionary *cA = @{ NSFontAttributeName: PAFont(9, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @2 };
    [@"SỐ" drawAtPoint:CGPointMake(W / 2 - 7, H * 0.5 - gs.height / 2 - 12) withAttributes:cA];
    // thanh tai (do dap ga) duoi so
    CGFloat bw = W * 0.06, bh = H * 0.28, bx = W / 2 - bw / 2, by = H * 0.5 + gs.height / 2 + 6;
    if (by + bh > H) bh = H - by - 2;
    if (bh > 8) {
        UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(bx, by, bw, bh) cornerRadius:3]; [PA_LINE setFill]; [bg fill];
        double ld = fmin(1, fmax(0, self.load)); CGFloat fh = bh * ld;
        UIBezierPath *fg = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(bx, by + bh - fh, bw, fh) cornerRadius:3];
        [(ld > 0.85 ? PA_RED : PA_AMBER) setFill]; [fg fill];
    }
}
@end

// ======================= La ban dang bang cuon (phia tren dong ho) =======================
@interface PACompassView : UIView
@property (nonatomic) double heading;   // -1 = chua co
@end
@implementation PACompassView
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; _heading = -1; } return self; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    UIBezierPath *bg = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(self.bounds, 0.5, 0.5) cornerRadius:H / 2];
    [PA_CARD setFill]; [bg fill]; [PA_LINE setStroke]; bg.lineWidth = 0.5; [bg stroke];
    [bg addClip];
    double h = self.heading < 0 ? 0 : self.heading;
    CGFloat pxPerDeg = W / 120.0;
    NSArray *names = @[@"B", @"ĐB", @"Đ", @"ĐN", @"N", @"TN", @"T", @"TB"];
    NSDictionary *mA = @{ NSFontAttributeName: PAFont(13, UIFontWeightBold), NSForegroundColorAttributeName: PA_FG };
    NSDictionary *nA = @{ NSFontAttributeName: PAFont(9, UIFontWeightMedium), NSForegroundColorAttributeName: PA_MUTED };
    for (int d = -75; d <= 75; d += 5) {
        double deg = fmod(h + d + 360 * 2, 360);
        double base = round(deg / 5) * 5; double off = base - deg;
        CGFloat x = W / 2 + (d + off) * pxPerDeg;
        int bi = ((int)base) % 360;
        BOOL card = bi % 45 == 0, ten = bi % 15 == 0;
        [[PA_MUTED colorWithAlphaComponent:card ? 1 : 0.5] setStroke]; CGContextSetLineWidth(c, card ? 1.5 : 0.8);
        CGContextMoveToPoint(c, x, H - 4); CGContextAddLineToPoint(c, x, H - (card ? 12 : (ten ? 9 : 6))); CGContextStrokePath(c);
        if (card) { NSString *t = names[bi / 45]; CGSize s = [t sizeWithAttributes:mA]; [t drawAtPoint:CGPointMake(x - s.width / 2, 3) withAttributes:mA]; }
        else if (ten) { NSString *t = [NSString stringWithFormat:@"%d", bi]; CGSize s = [t sizeWithAttributes:nA]; [t drawAtPoint:CGPointMake(x - s.width / 2, 6) withAttributes:nA]; }
    }
    // vach giua + so do
    [PA_AMBER setFill];
    UIBezierPath *tri = [UIBezierPath bezierPath];
    [tri moveToPoint:CGPointMake(W / 2 - 6, H)]; [tri addLineToPoint:CGPointMake(W / 2 + 6, H)]; [tri addLineToPoint:CGPointMake(W / 2, H - 8)]; [tri closePath]; [tri fill];
    NSString *deg = self.heading < 0 ? @"—" : [NSString stringWithFormat:@"%03.0f°", h];
    NSDictionary *dA = @{ NSFontAttributeName: PAMono(11, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_AMBER };
    CGSize ds = [deg sizeWithAttributes:dA];
    UIBezierPath *pill = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(W - ds.width - 22, H / 2 - ds.height / 2 - 2, ds.width + 12, ds.height + 4) cornerRadius:6];
    [PA_BG setFill]; [pill fill];
    [deg drawAtPoint:CGPointMake(W - ds.width - 16, H / 2 - ds.height / 2) withAttributes:dA];
}
@end

// ======================= Nut START / STOP ENGINE (giong nut de xe) =======================
@interface PAStartButton : UIControl
@property (nonatomic) BOOL on;
@end
@implementation PAStartButton
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)setOn:(BOOL)on { _on = on; [self setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [UIView animateWithDuration:0.12 animations:^{ self.transform = h ? CGAffineTransformMakeScale(0.95, 0.95) : CGAffineTransformIdentity; }]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat S = MIN(self.bounds.size.width, self.bounds.size.height), cx = self.bounds.size.width / 2, cy = self.bounds.size.height / 2, R = S / 2 - 10;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    // vien kim loai ngoai
    CGFloat outer[] = { 0.42, 0.42, 0.45, 1, 0.12, 0.12, 0.14, 1 };
    CGGradientRef g1 = CGGradientCreateWithColorComponents(cs, outer, NULL, 2);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, CGRectMake(cx - R - 6, cy - R - 6, 2 * R + 12, 2 * R + 12)); CGContextClip(c);
    CGContextDrawLinearGradient(c, g1, CGPointMake(cx, cy - R - 6), CGPointMake(cx, cy + R + 6), 0);
    CGContextRestoreGState(c);
    // vong sang (den nen) — vang khi may no, trang mo khi tat
    UIColor *ring = self.on ? PA_AMBER : [UIColor colorWithWhite:0.75 alpha:0.5];
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeZero, self.on ? 16 : 4, ring.CGColor);
    [ring setStroke]; CGContextSetLineWidth(c, 3);
    CGContextAddEllipseInRect(c, CGRectMake(cx - R + 1, cy - R + 1, 2 * R - 2, 2 * R - 2)); CGContextStrokePath(c);
    CGContextRestoreGState(c);
    // mat nut den bong
    CGFloat face[] = { 0.16, 0.16, 0.18, 1, 0.03, 0.03, 0.035, 1 };
    CGGradientRef g2 = CGGradientCreateWithColorComponents(cs, face, NULL, 2);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, CGRectMake(cx - R + 5, cy - R + 5, 2 * R - 10, 2 * R - 10)); CGContextClip(c);
    CGContextDrawRadialGradient(c, g2, CGPointMake(cx - R * 0.3, cy - R * 0.4), 0, CGPointMake(cx, cy), R, kCGGradientDrawsAfterEndLocation);
    CGContextRestoreGState(c);
    CGGradientRelease(g1); CGGradientRelease(g2); CGColorSpaceRelease(cs);
    // chu
    UIColor *tc = self.on ? PA_AMBER : PA_FG;
    NSDictionary *sA = @{ NSFontAttributeName: PAFont(R * 0.13, UIFontWeightSemibold), NSForegroundColorAttributeName: [tc colorWithAlphaComponent:0.8], NSKernAttributeName: @2 };
    NSDictionary *bA = @{ NSFontAttributeName: PAFont(R * 0.22, UIFontWeightHeavy), NSForegroundColorAttributeName: tc, NSKernAttributeName: @1.5 };
    NSString *l1 = @"ENGINE", *l2 = @"START", *l3 = @"STOP";
    CGSize s1 = [l1 sizeWithAttributes:sA], s2 = [l2 sizeWithAttributes:bA], s3 = [l3 sizeWithAttributes:bA];
    CGFloat total = s1.height + s2.height + s3.height, y = cy - total / 2;
    [l1 drawAtPoint:CGPointMake(cx - s1.width / 2, y) withAttributes:sA]; y += s1.height;
    [l2 drawAtPoint:CGPointMake(cx - s2.width / 2, y) withAttributes:bA]; y += s2.height;
    [l3 drawAtPoint:CGPointMake(cx - s3.width / 2, y) withAttributes:bA];
    // den trang thai nho
    UIColor *led = self.on ? PA_GREEN : PA_RED;
    CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeZero, 6, led.CGColor); [led setFill];
    CGContextFillEllipseInRect(c, CGRectMake(cx - 3, cy + R * 0.66, 6, 6)); CGContextRestoreGState(c);
}
@end

// ======================= Tab Lai xe =======================
@implementation PARootViewController {
    UIStackView *_stack;
    PAClusterView *_gauge; PACompassView *_compass; UILabel *_modeLbl;
    CADisplayLink *_link;
    PAStartButton *_startBtn; UIButton *_updateBtn, *_permBtn;
    UILabel *_chipCar, *_chipGps, *_chipSensor;
    UILabel *_carName, *_carSub;
    NSArray<UILabel *> *_hud;
    NSUInteger _frameN;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Nổ máy";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Nổ máy" image:[UIImage systemImageNamed:@"power.circle.fill"] tag:0];
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

    _compass = [PACompassView new];
    [_compass.heightAnchor constraintEqualToConstant:36].active = YES;
    [_stack addArrangedSubview:_compass];

    _gauge = [PAClusterView new];
    [_gauge.heightAnchor constraintEqualToAnchor:_gauge.widthAnchor multiplier:0.52].active = YES;
    [_stack addArrangedSubview:_gauge];

    // nut de START / STOP ENGINE o giua
    UIView *btnBox = [UIView new];
    [btnBox.heightAnchor constraintEqualToConstant:186].active = YES;
    _startBtn = [PAStartButton new];
    _startBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [_startBtn addTarget:self action:@selector(toggleEngine) forControlEvents:UIControlEventTouchUpInside];
    [btnBox addSubview:_startBtn];
    [NSLayoutConstraint activateConstraints:@[[_startBtn.centerXAnchor constraintEqualToAnchor:btnBox.centerXAnchor], [_startBtn.centerYAnchor constraintEqualToAnchor:btnBox.centerYAnchor],
        [_startBtn.widthAnchor constraintEqualToConstant:176], [_startBtn.heightAnchor constraintEqualToConstant:176]]];
    [_stack addArrangedSubview:btnBox];
    _modeLbl = [UILabel new]; _modeLbl.font = PAFont(13, UIFontWeightMedium); _modeLbl.textColor = PA_MUTED; _modeLbl.textAlignment = NSTextAlignmentCenter; _modeLbl.numberOfLines = 0;
    [_stack addArrangedSubview:_modeLbl];

    _permBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_permBtn setTitle:@"Cấp quyền vị trí: chọn \"Luôn luôn\"" forState:UIControlStateNormal];
    [_permBtn setTitleColor:PA_AMBER forState:UIControlStateNormal];
    _permBtn.titleLabel.font = PAFont(14, UIFontWeightMedium);
    [_permBtn addTarget:self action:@selector(askPermission) forControlEvents:UIControlEventTouchUpInside];
    [_stack addArrangedSubview:_permBtn];

    // the xe dang chon
    UIControl *carCtl = [UIControl new];
    [carCtl addTarget:self action:@selector(openCars) forControlEvents:UIControlEventTouchUpInside];
    UILabel *cap = [self caption:@"XE · TIẾNG PÔ"];
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
    if (e.engineOn && !e.collectMode) [e stopDriveMode]; else [e startDriveMode];   // bam START khi dang theo doi im lang -> chuyen sang po ao
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy] impactOccurred];
    [self refresh];
}
- (void)askPermission { [PAEngine.shared requestLocationPermission]; }
- (void)openCars { self.tabBarController.selectedIndex = 2; }

- (void)frame:(CADisplayLink *)l {
    PASynth *s = PAEngine.shared.synth;
    int pi = s->presetIndex;
    if (pi < 0 || pi >= PA_PRESET_COUNT) pi = 0;
    _gauge.redline = PA_PRESETS[pi].redline;
    _gauge.rpm = s->rpm; _gauge.speed = s->speed; _gauge.gear = s->gear; _gauge.running = s->state != PA_OFF; _gauge.load = s->load;
    [_gauge setNeedsDisplay];
    if (_frameN % 3 == 0) { _compass.heading = PAEngine.shared.headingDeg; [_compass setNeedsDisplay]; }
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
    _startBtn.on = on && !e.collectMode;
    _modeLbl.text = e.collectMode ? @"Đang ở chế độ Theo dõi im lặng — bấm START để chuyển sang pô ảo"
                  : (on ? @"Máy đang nổ · bấm để tắt máy" : @"Bấm để khởi động hệ thống và nổ máy");

    [self setChip:_chipCar text:(e.carPlayConnected ? @"CarPlay ✓" : @"CarPlay") ok:e.carPlayConnected];
    [self setChip:_chipGps text:(e.gpsSpeedKmh < 0 ? @"GPS" : [NSString stringWithFormat:@"GPS %.0f", e.gpsSpeedKmh]) ok:e.gpsSpeedKmh >= 0];
    PAMotion *m = (PAMotion *)e.motion;
    BOOL sens = m.running && m.imuHz > 5;
    [self setChip:_chipSensor text:(sens ? (m.calibrated ? @"Cảm biến ✓" : @"Đang học") : @"Cảm biến") ok:sens && m.calibrated];
    _permBtn.hidden = [e.locationStatusText rangeOfString:@"✓"].location != NSNotFound;

    _updateBtn.hidden = !u.updateAvailable;
    [_updateBtn setTitle:[NSString stringWithFormat:@"Có bản mới %@ · chạm để cập nhật", u.latestVersion ?: @""] forState:UIControlStateNormal];

    const PAPreset *p = &PA_PRESETS[pa_preset_index(e.presetKey.UTF8String)];
    PAVehicle *veh = [PAVehicles byId:e.vehicleId];
    _carName.text = veh ? [@"VinFast " stringByAppendingString:veh.title] : @"Xe khác";
    _carSub.text = [NSString stringWithFormat:@"Tiếng: %s · %d xi-lanh%@\n%.0f mã lực · 0–100 %.1f s", p->name, p->cyl, p->turbo ? @" turbo" : @"", e.carHP, e.car0to100];
}

@end
