#import "PASyncViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PASynth.h"
#import "PATheme.h"

#define NBUF 300   // 30 giay x 10 mau/giay

typedef struct { float gps, fus, syn, acc, load, rpm; unsigned char newFix; } PASample;

@interface PAChartView : UIView
@property (nonatomic) PASample *buf; @property (nonatomic) int head, count; @property (nonatomic) int mode; // 0 toc do, 1 ga
@end
@implementation PAChartView
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, L = 34, T = 18, B = H - 6;
    NSDictionary *fa = @{ NSFontAttributeName: PAMono(10, UIFontWeightRegular), NSForegroundColorAttributeName: PA_MUTED };
    if (self.count < 2) { [@"Đang thu dữ liệu…" drawAtPoint:CGPointMake(L, H / 2 - 6) withAttributes:fa]; return; }
    double lo, hi;
    if (self.mode == 0) { lo = 0; hi = 20; for (int i = 0; i < self.count; i++) { PASample s = self.buf[(self.head - i + NBUF) % NBUF]; hi = fmax(hi, fmax(s.gps, fmax(s.fus, s.syn)) + 5); } hi = ceil(hi / 20) * 20; }
    else { lo = -4; hi = 4; }
    CGFloat (^Y)(double) = ^CGFloat(double v) { return B - (v - lo) / (hi - lo) * (B - T); };
    [PA_LINE setStroke]; CGContextSetLineWidth(c, 0.5);
    int steps = 4;
    for (int k = 0; k <= steps; k++) {
        double v = lo + (hi - lo) * k / steps; CGFloat y = Y(v);
        CGContextMoveToPoint(c, L, y); CGContextAddLineToPoint(c, W, y); CGContextStrokePath(c);
        [[NSString stringWithFormat:@"%.0f", v] drawAtPoint:CGPointMake(2, y - 6) withAttributes:fa];
    }
    CGFloat dx = (W - L) / (NBUF - 1);
    void (^line)(UIColor *, CGFloat, float (^)(PASample)) = ^(UIColor *col, CGFloat w, float (^get)(PASample)) {
        [col setStroke]; CGContextSetLineWidth(c, w); CGContextSetLineJoin(c, kCGLineJoinRound);
        for (int i = 0; i < self.count; i++) {
            PASample s = self.buf[(self.head - (self.count - 1 - i) + NBUF) % NBUF];
            double v = get(s); if (isnan(v)) continue;
            CGFloat x = W - (self.count - 1 - i) * dx, y = Y(fmax(lo, fmin(hi, v)));
            if (i == 0) CGContextMoveToPoint(c, x, y); else CGContextAddLineToPoint(c, x, y);
        }
        CGContextStrokePath(c);
    };
    if (self.mode == 0) {
        line([UIColor colorWithRed:1 green:0.55 blue:0.2 alpha:0.9], 1.2, ^float(PASample s) { return s.gps < 0 ? NAN : s.gps; });
        line(PA_FG, 1.5, ^float(PASample s) { return s.fus; });
        line(PA_AMBER, 2.2, ^float(PASample s) { return s.syn; });
        [UIColor.whiteColor setFill];   // cham = ban tin GPS MOI
        for (int i = 0; i < self.count; i++) {
            PASample s = self.buf[(self.head - (self.count - 1 - i) + NBUF) % NBUF];
            if (s.newFix && s.gps >= 0) { CGFloat x = W - (self.count - 1 - i) * dx; CGContextFillEllipseInRect(c, CGRectMake(x - 2.5, Y(s.gps) - 2.5, 5, 5)); }
        }
    } else {
        line([UIColor colorWithRed:0.35 green:0.65 blue:1 alpha:1], 1.5, ^float(PASample s) { return s.acc; });
        line(PA_AMBER, 2.2, ^float(PASample s) { return s.load * 4; });
    }
}
@end

@implementation PASyncViewController {
    PASample _buf[NBUF]; int _head, _count;
    PAChartView *_speed, *_gas;
    UILabel *_stats;
    NSTimer *_timer;
    NSInteger _lastFixCount;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Phân tích đồng bộ";
    self.view.backgroundColor = PA_BG;
    UIScrollView *sc = [UIScrollView new]; sc.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:sc];
    UIStackView *st = [UIStackView new]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 10; st.translatesAutoresizingMaskIntoConstraints = NO;
    [sc addSubview:st];
    [NSLayoutConstraint activateConstraints:@[
        [sc.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor], [sc.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sc.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor], [sc.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [st.topAnchor constraintEqualToAnchor:sc.contentLayoutGuide.topAnchor constant:12], [st.bottomAnchor constraintEqualToAnchor:sc.contentLayoutGuide.bottomAnchor constant:-20],
        [st.leadingAnchor constraintEqualToAnchor:sc.frameLayoutGuide.leadingAnchor constant:16], [st.trailingAnchor constraintEqualToAnchor:sc.frameLayoutGuide.trailingAnchor constant:-16]]];
    UILabel *(^cap)(NSString *) = ^UILabel *(NSString *t) {
        UILabel *l = [UILabel new]; l.numberOfLines = 0; l.font = PAFont(12, UIFontWeightRegular); l.textColor = PA_MUTED; l.text = t; return l; };
    UIView *(^card)(UIView *, CGFloat) = ^UIView *(UIView *v, CGFloat h) {
        v.backgroundColor = PA_CARD; v.layer.cornerRadius = 12; v.clipsToBounds = YES;
        [v.heightAnchor constraintEqualToConstant:h].active = YES; return v; };
    [st addArrangedSubview:cap(@"TỐC ĐỘ 30 GIÂY GẦN NHẤT (km/h)")];
    _speed = [PAChartView new]; _speed.mode = 0; _speed.buf = _buf; [st addArrangedSubview:card(_speed, 190)];
    [st addArrangedSubview:cap(@"Cam = GPS (chấm trắng: bản tin mới) · Trắng = tốc độ hợp nhất · Vàng = tốc độ tiếng pô đang chạy. Vàng bám sát trắng là đồng bộ.")];
    [st addArrangedSubview:cap(@"GA ↔ TIẾNG")];
    _gas = [PAChartView new]; _gas.mode = 1; _gas.buf = _buf; [st addArrangedSubview:card(_gas, 150)];
    [st addArrangedSubview:cap(@"Xanh = gia tốc thật của xe từ cảm biến (m/s²) · Vàng = độ đạp ga của tiếng pô. Hai đường lên xuống cùng lúc là tiếng khớp chân ga.")];
    _stats = [UILabel new]; _stats.numberOfLines = 0; _stats.font = PAMono(13, UIFontWeightRegular); _stats.textColor = PA_FG;
    UIView *box = [UIView new]; box.backgroundColor = PA_CARD; box.layer.cornerRadius = 12;
    _stats.translatesAutoresizingMaskIntoConstraints = NO; [box addSubview:_stats];
    [NSLayoutConstraint activateConstraints:@[[_stats.topAnchor constraintEqualToAnchor:box.topAnchor constant:12], [_stats.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-12],
        [_stats.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:14], [_stats.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-14]]];
    [st addArrangedSubview:box];
    UISwitch *sw = [UISwitch new]; sw.onTintColor = PA_AMBER; sw.on = PAEngine.shared.latencyComp;
    [sw addTarget:self action:@selector(comp:) forControlEvents:UIControlEventValueChanged];
    UILabel *swl = [UILabel new]; swl.text = @"Bù độ trễ loa (dự đoán trước)"; swl.textColor = PA_FG; swl.font = PAFont(16, UIFontWeightRegular);
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[swl, sw]]; row.alignment = UIStackViewAlignmentCenter;
    UIView *rowBox = [UIView new]; rowBox.backgroundColor = PA_CARD; rowBox.layer.cornerRadius = 12;
    row.translatesAutoresizingMaskIntoConstraints = NO; [rowBox addSubview:row];
    [NSLayoutConstraint activateConstraints:@[[row.topAnchor constraintEqualToAnchor:rowBox.topAnchor constant:10], [row.bottomAnchor constraintEqualToAnchor:rowBox.bottomAnchor constant:-10],
        [row.leadingAnchor constraintEqualToAnchor:rowBox.leadingAnchor constant:14], [row.trailingAnchor constraintEqualToAnchor:rowBox.trailingAnchor constant:-14]]];
    [st addArrangedSubview:rowBox];
    [st addArrangedSubview:cap(@"Màn hình này chỉ để xem khi xe đang đỗ hoặc do người ngồi ghế phụ xem. Mọi số liệu cũng được ghi vào lịch sử chuyến đi và báo cáo cho Claude.")];
}

- (void)comp:(UISwitch *)s { PAEngine.shared.latencyComp = s.on; }

- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(sample) userInfo:nil repeats:YES]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_timer invalidate]; _timer = nil; }

// tuong quan gia toc that vs do dap ga, tim do lech thoi gian (0..1,5 s)
- (void)syncScore:(double *)corrOut lag:(double *)lagOut {
    *corrOut = 0; *lagOut = 0;
    int n = _count - 16; if (n < 50) return;
    double best = -2; int bl = 0;
    for (int L = 0; L <= 15; L++) {
        double sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0;
        for (int i = 0; i < n; i++) {
            PASample a = _buf[(_head - i - L + NBUF * 2) % NBUF], b = _buf[(_head - i + NBUF) % NBUF];
            double x = a.acc, y = b.load; sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y;
        }
        double cv = sxy / n - sx / n * sy / n, vx = sxx / n - sx * sx / n / n, vy = syy / n - sy * sy / n / n;
        double r = (vx > 1e-6 && vy > 1e-6) ? cv / sqrt(vx * vy) : 0;
        if (r > best) { best = r; bl = L; }
    }
    *corrOut = best; *lagOut = bl * 0.1;
}

- (void)sample {
    PAEngine *e = PAEngine.shared; PAMotion *m = (PAMotion *)e.motion; PASynth *sy = e.synth;
    PASample s;
    s.gps = (float)m.gpsRawKmh; s.fus = (float)m.speedKmh; s.syn = (float)sy->speed; s.acc = (float)m.aLongNow; s.load = (float)sy->load; s.rpm = (float)sy->rpm;
    s.newFix = 0;
    if (m.gpsCount != _lastFixCount) { _lastFixCount = m.gpsCount; static float prev = -9; if (s.gps != prev) s.newFix = 1; prev = s.gps; }
    _head = (_head + 1) % NBUF; _buf[_head] = s; if (_count < NBUF) _count++;
    _speed.head = _gas.head = _head; _speed.count = _gas.count = _count;
    [_speed setNeedsDisplay]; [_gas setNeedsDisplay];
    if (_count % 5 != 0) return;
    double err = 0; int ne = 0;
    for (int i = 0; i < _count && i < 100; i++) { PASample q = _buf[(_head - i + NBUF) % NBUF]; err += fabs(q.syn - q.fus); ne++; }
    double corr, lag; [self syncScore:&corr lag:&lag];
    NSString *cal = m.calibrated ? (m.calByTurn ? @"đã học (nhờ vào cua)" : @"đã học (nhờ GPS)") : [NSString stringWithFormat:@"đang học %.0f%% – hãy rẽ vài khúc cua", m.calProgress * 100];
    _stats.text = [NSString stringWithFormat:
        @"Nguồn vị trí      %@\n"
         "GPS mới mỗi       %@\n"
         "GPS trễ (ước)     %@\n"
         "Bản tin lặp số cũ %.0f%%\n"
         "Cảm biến          %.0f lần/giây\n"
         "Hướng xe          %@\n"
         "Trễ ra loa        %.0f ms%@\n"
         "Tiếng lệch tốc độ %.1f km/h (TB 10 s)\n"
         "Ga ↔ tiếng        tương quan %.2f, trễ %.1f s\n"
         "Vòng tua / số     %.0f · số %d",
        m.gpsFromCar ? @"GPS của XE (qua CarPlay)" : @"GPS iPhone",
        m.gpsNewInterval > 0 ? [NSString stringWithFormat:@"%.1f s", m.gpsNewInterval] : @"—",
        m.gpsDelayEst > 0 ? [NSString stringWithFormat:@"%.1f s (đã tự bù)", m.gpsDelayEst] : @"đang ước lượng",
        m.gpsRepeatRatio * 100, m.imuHz, cal,
        e.outputLatencyMs, e.latencyComp ? [NSString stringWithFormat:@" (bù %.0f ms)", fmin(400, e.outputLatencyMs)] : @"",
        ne ? err / ne : 0, corr, lag, sy->rpm, sy->gear + 1];
}
@end
