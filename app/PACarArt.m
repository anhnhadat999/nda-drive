#import "PACarArt.h"

typedef struct { CGFloat x, y; } PAPt;

// Duong vien tren cua than xe, tu mui (trai) toi duoi (phai). y: 0 = noc khung, 1 = mat duong.
// Kinh xe: da giac rieng. Banh xe: tam truoc / sau.
typedef struct {
    int n; PAPt top[12];
    int wn; PAPt win[8];
    CGFloat wheelF, wheelR, wheelRad;
    BOOL wing;
} PABody;

static const PABody BODY_REAR = { 9, {{.03,.70},{.04,.58},{.16,.50},{.32,.47},{.43,.24},{.55,.19},{.66,.25},{.84,.40},{.97,.58}},
    5, {{.35,.46},{.44,.27},{.55,.23},{.65,.28},{.76,.44}}, .21, .79, .115, NO };
static const PABody BODY_MID = { 9, {{.03,.68},{.04,.58},{.18,.50},{.33,.47},{.44,.27},{.58,.24},{.70,.33},{.84,.42},{.97,.50}},
    4, {{.36,.46},{.45,.29},{.58,.27},{.68,.40}}, .20, .79, .115, NO };
static const PABody BODY_HYPER = { 8, {{.02,.68},{.05,.60},{.24,.52},{.40,.42},{.50,.28},{.64,.29},{.82,.38},{.97,.50}},
    4, {{.42,.42},{.51,.30},{.63,.31},{.71,.40}}, .19, .80, .115, NO };
static const PABody BODY_GT = { 8, {{.02,.66},{.04,.57},{.22,.50},{.44,.46},{.55,.26},{.69,.25},{.86,.39},{.97,.52}},
    4, {{.47,.45},{.56,.28},{.68,.27},{.80,.41}}, .20, .80, .115, NO };
static const PABody BODY_SEDAN = { 9, {{.03,.64},{.04,.54},{.20,.47},{.30,.45},{.40,.23},{.66,.21},{.80,.38},{.94,.42},{.97,.56}},
    5, {{.33,.44},{.42,.25},{.54,.24},{.66,.23},{.77,.39}}, .20, .80, .115, NO };
static const PABody BODY_MUSCLE = { 9, {{.02,.62},{.03,.52},{.20,.46},{.40,.43},{.50,.24},{.63,.23},{.82,.38},{.96,.41},{.97,.56}},
    4, {{.43,.42},{.51,.26},{.62,.25},{.76,.38}}, .19, .80, .12, NO };
static const PABody BODY_HATCH = { 8, {{.04,.64},{.05,.54},{.18,.48},{.27,.45},{.39,.21},{.76,.20},{.93,.30},{.96,.56}},
    4, {{.31,.44},{.41,.24},{.74,.23},{.88,.31}}, .22, .79, .115, NO };
static const PABody BODY_ROADSTER = { 8, {{.02,.64},{.03,.55},{.22,.49},{.42,.46},{.50,.32},{.56,.45},{.80,.45},{.97,.52}},
    3, {{.44,.45},{.50,.34},{.53,.45}}, .20, .80, .115, NO };

static PABody bodyFor(NSString *k) {
    PABody b;
    if ([k isEqualToString:@"gt3"]) { b = BODY_REAR; b.wing = YES; }
    else if ([k isEqualToString:@"p911t"] || [k isEqualToString:@"c911s"]) b = BODY_REAR;
    else if ([k isEqualToString:@"gt4rs"]) { b = BODY_MID; b.wing = YES; }
    else if ([k isEqualToString:@"c718s"]) b = BODY_MID;
    else if ([k isEqualToString:@"cgt"] || [k isEqualToString:@"v10"]) b = BODY_HYPER;
    else if ([k isEqualToString:@"v12"] || [k isEqualToString:@"rot"]) b = BODY_GT;
    else if ([k isEqualToString:@"amg"] || [k isEqualToString:@"i6"] || [k isEqualToString:@"i5"]) b = BODY_SEDAN;
    else if ([k isEqualToString:@"v8"]) b = BODY_MUSCLE;
    else if ([k isEqualToString:@"i4t"]) b = BODY_HATCH;
    else if ([k isEqualToString:@"vtec"]) b = BODY_ROADSTER;
    else b = BODY_REAR;
    return b;
}

static UIColor *RGB(int r, int g, int b) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1]; }

UIColor *PACarPaint(NSString *k) {
    NSDictionary<NSString *, UIColor *> *m = @{
        @"gt3": RGB(226, 228, 230), @"gt4rs": RGB(64, 160, 96), @"p911t": RGB(120, 126, 136),
        @"c911s": RGB(52, 104, 196), @"c718s": RGB(236, 196, 40), @"cgt": RGB(180, 186, 194),
        @"v12": RGB(206, 36, 36), @"v10": RGB(232, 120, 24), @"amg": RGB(86, 92, 100),
        @"v8": RGB(36, 80, 170), @"i6": RGB(30, 110, 200), @"i5": RGB(96, 120, 104),
        @"vtec": RGB(200, 28, 40), @"i4t": RGB(240, 240, 240), @"rot": RGB(240, 200, 30) };
    return m[k] ?: RGB(200, 200, 200);
}

@implementation PACarView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) { self.backgroundColor = UIColor.clearColor; self.contentMode = UIViewContentModeRedraw; self.opaque = NO; }
    return self;
}

- (void)setPresetKey:(NSString *)k { _presetKey = [k copy]; [self setNeedsDisplay]; }

static UIBezierPath *smoothPath(const PAPt *p, int n, CGRect box, BOOL closeToGround) {
    UIBezierPath *bp = [UIBezierPath bezierPath];
    CGPoint (^P)(PAPt) = ^CGPoint(PAPt q) { return CGPointMake(box.origin.x + q.x * box.size.width, box.origin.y + q.y * box.size.height); };
    if (closeToGround) { [bp moveToPoint:P((PAPt){p[0].x, .65})]; [bp addLineToPoint:P(p[0])]; }
    else [bp moveToPoint:P(p[0])];
    // lam min duong vien: noi trung diem bang duong cong bac hai
    for (int i = 1; i < n - 1; i++) {
        CGPoint a = P(p[i]), b = P(p[i + 1]);
        [bp addQuadCurveToPoint:CGPointMake((a.x + b.x) / 2, (a.y + b.y) / 2) controlPoint:a];
    }
    [bp addLineToPoint:P(p[n - 1])];
    if (closeToGround) { [bp addLineToPoint:P((PAPt){p[n - 1].x, .65})]; [bp closePath]; }
    return bp;
}

- (void)drawRect:(CGRect)rect {
    if (!self.presetKey) return;
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    // khung ve giu ty le ~ 2.4 : 1
    CGFloat bw = MIN(W, H * 2.4) * 0.96, bh = bw / 2.4;
    CGRect box = CGRectMake((W - bw) / 2, (H - bh) / 2 + bh * 0.08, bw, bh);
    PABody b = bodyFor(self.presetKey);
    UIColor *paint = PACarPaint(self.presetKey);
    CGFloat groundY = box.origin.y + 0.74 * bh;

    // bong do duoi xe
    CGContextSaveGState(c);
    [[UIColor colorWithWhite:0 alpha:0.45] setFill];
    CGContextFillEllipseInRect(c, CGRectMake(box.origin.x + bw * 0.06, groundY + bh * 0.06, bw * 0.88, bh * 0.10));
    CGContextRestoreGState(c);

    // than xe: chuyen sac tu sang (tren) xuong toi (duoi)
    UIBezierPath *body = smoothPath(b.top, b.n, box, YES);
    CGContextSaveGState(c);
    [body addClip];
    CGFloat r, g, bl, a;
    [paint getRed:&r green:&g blue:&bl alpha:&a];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat comps[12] = { fmin(1, r * 1.15 + .08), fmin(1, g * 1.15 + .08), fmin(1, bl * 1.15 + .08), 1,
                          r, g, bl, 1,
                          r * .45, g * .45, bl * .45, 1 };
    CGFloat locs[3] = { 0, .55, 1 };
    CGGradientRef grad = CGGradientCreateWithColorComponents(cs, comps, locs, 3);
    CGContextDrawLinearGradient(c, grad, CGPointMake(0, box.origin.y + .15 * bh), CGPointMake(0, groundY), 0);
    CGGradientRelease(grad); CGColorSpaceRelease(cs);
    // duong gan hong xe
    [[UIColor colorWithWhite:0 alpha:0.22] setStroke];
    UIBezierPath *crease = [UIBezierPath bezierPath];
    [crease moveToPoint:CGPointMake(box.origin.x + bw * .06, box.origin.y + bh * .60)];
    [crease addLineToPoint:CGPointMake(box.origin.x + bw * .95, box.origin.y + bh * .56)];
    crease.lineWidth = MAX(1, bw * 0.004);
    [crease stroke];
    CGContextRestoreGState(c);

    // kinh
    if (b.wn >= 3) {
        UIBezierPath *w = smoothPath(b.win, b.wn, box, NO);
        [w closePath];
        [[UIColor colorWithRed:.07 green:.09 blue:.12 alpha:.92] setFill];
        [w fill];
        [[UIColor colorWithWhite:1 alpha:.08] setStroke];
        w.lineWidth = 1; [w stroke];
    }

    // canh gio sau
    if (b.wing) {
        CGFloat wx = box.origin.x + bw * .80, wy = box.origin.y + bh * .26;
        UIBezierPath *wing = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(wx, wy, bw * .16, bh * .035) cornerRadius:bh * .015];
        [[UIColor colorWithWhite:.08 alpha:1] setFill]; [wing fill];
        UIBezierPath *strut = [UIBezierPath bezierPathWithRect:CGRectMake(wx + bw * .07, wy, bw * .012, bh * .14)];
        [strut fill];
    }

    // den truoc / den sau
    [[UIColor colorWithRed:1 green:.95 blue:.8 alpha:1] setFill];
    UIRectFill(CGRectMake(box.origin.x + bw * (b.top[1].x + .01), box.origin.y + bh * (b.top[1].y + .02), bw * .035, bh * .025));
    [[UIColor colorWithRed:1 green:.18 blue:.15 alpha:1] setFill];
    PAPt rear = b.top[b.n - 1];
    UIRectFill(CGRectMake(box.origin.x + bw * (rear.x - .035), box.origin.y + bh * (rear.y + .03), bw * .03, bh * .03));

    // banh xe
    for (int i = 0; i < 2; i++) {
        CGFloat cx = box.origin.x + bw * (i == 0 ? b.wheelF : b.wheelR);
        CGFloat rad = bh * b.wheelRad * 1.15;
        // hoc banh xe
        [[UIColor colorWithWhite:.03 alpha:1] setFill];
        CGContextFillEllipseInRect(c, CGRectMake(cx - rad * 1.12, groundY - rad * 1.12 - rad * .25, rad * 2.24, rad * 2.24));
        // lop
        [[UIColor colorWithWhite:.10 alpha:1] setFill];
        CGContextFillEllipseInRect(c, CGRectMake(cx - rad, groundY - rad * 2 + rad * .02, rad * 2, rad * 2));
        // mam
        CGFloat rr = rad * .66, cy = groundY - rad + rad * .02;
        [[UIColor colorWithWhite:.62 alpha:1] setFill];
        CGContextFillEllipseInRect(c, CGRectMake(cx - rr, cy - rr, rr * 2, rr * 2));
        [[UIColor colorWithWhite:.25 alpha:1] setStroke];
        CGContextSetLineWidth(c, MAX(1, rad * .10));
        for (int s = 0; s < 5; s++) {
            CGFloat an = s * 2 * M_PI / 5;
            CGContextMoveToPoint(c, cx + cos(an) * rr * .25, cy + sin(an) * rr * .25);
            CGContextAddLineToPoint(c, cx + cos(an) * rr * .95, cy + sin(an) * rr * .95);
        }
        CGContextStrokePath(c);
        [[UIColor colorWithWhite:.15 alpha:1] setFill];
        CGContextFillEllipseInRect(c, CGRectMake(cx - rr * .2, cy - rr * .2, rr * .4, rr * .4));
    }
}

@end
