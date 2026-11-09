#import "PAAcousticViewController.h"
#import "PAAcousticMeasure.h"
#import "PAEngine.h"
#import "PATheme.h"

// Bieu do dap ung tan so: cot = do lech (dB) tung dai 1/3 quang tam, duong vang = sau khi bu
@interface PAResponseView : UIView
@property (nonatomic) PAAcousticResult r;
@property (nonatomic) BOOL has;
@end
@implementation PAResponseView
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, top = 10, bot = H - 22, mid = (top + bot) / 2, range = 12;
    [PA_LINE setStroke]; CGContextSetLineWidth(c, 0.5);
    for (int db = -12; db <= 12; db += 6) { CGFloat y = mid - db / range * (bot - top) / 2; CGContextMoveToPoint(c, 30, y); CGContextAddLineToPoint(c, W - 4, y); }
    CGContextStrokePath(c);
    NSDictionary *a = @{ NSFontAttributeName: PAMono(9, UIFontWeightRegular), NSForegroundColorAttributeName: PA_MUTED };
    for (int db = -12; db <= 12; db += 6) [[NSString stringWithFormat:@"%+d", db] drawAtPoint:CGPointMake(2, mid - db / range * (bot - top) / 2 - 6) withAttributes:a];
    if (!self.has) { [@"Chưa đo" drawAtPoint:CGPointMake(W / 2 - 20, mid - 6) withAttributes:a]; return; }
    CGFloat bw = (W - 34) / PAA_BANDS;
    for (int b = 0; b < PAA_BANDS; b++) {
        double v = fmax(-range, fmin(range, self.r.respDb[b]));
        CGFloat x = 32 + b * bw, y = mid - v / range * (bot - top) / 2;
        [(fabs(v) > 4 ? PA_RED : PA_MUTED) setFill];
        CGContextFillRect(c, CGRectMake(x + 1, MIN(y, mid), bw - 2, fabs(y - mid)));
        if (b % 3 == 0) {
            double f = PAA_BAND_HZ[b];
            NSString *t = f >= 1000 ? [NSString stringWithFormat:@"%gk", f / 1000] : [NSString stringWithFormat:@"%g", f];
            [t drawAtPoint:CGPointMake(x, bot + 4) withAttributes:a];
        }
    }
    // du doan sau khi bu: cong bu theo quang tam (noi suy tuyen tinh theo log tan so)
    if (PAEngine.shared.acousticCorrection) {
        [PA_AMBER setStroke]; CGContextSetLineWidth(c, 2);
        for (int b = 0; b < PAA_BANDS; b++) {
            double lf = log2(PAA_BAND_HZ[b] / 63.0), corr = 0;
            int o = (int)floor(lf); double w = lf - o;
            if (o < 0) corr = self.r.corrDb[0]; else if (o >= PAA_OCT - 1) corr = self.r.corrDb[PAA_OCT - 1];
            else corr = self.r.corrDb[o] * (1 - w) + self.r.corrDb[o + 1] * w;
            double v = fmax(-range, fmin(range, self.r.respDb[b] + corr));
            CGFloat x = 32 + b * bw + bw / 2, y = mid - v / range * (bot - top) / 2;
            if (b == 0) CGContextMoveToPoint(c, x, y); else CGContextAddLineToPoint(c, x, y);
        }
        CGContextStrokePath(c);
    }
}
@end

@implementation PAAcousticViewController {
    UISegmentedControl *_mic;
    PAResponseView *_graph;
    NSString *_status;
    BOOL _busy;
}

- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Đo âm học khoang xe"; return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = PA_BG;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    _mic = [[UISegmentedControl alloc] initWithItems:@[@"Mic xe (CarPlay)", @"Mic iPhone"]];
    _mic.selectedSegmentIndex = [PAAcousticMeasure carMicAvailable] ? 0 : 1;
    _mic.selectedSegmentTintColor = PA_AMBER;
    [_mic setTitleTextAttributes:@{ NSForegroundColorAttributeName: UIColor.blackColor } forState:UIControlStateSelected];
    _graph = [[PAResponseView alloc] initWithFrame:CGRectMake(0, 0, 300, 170)];
    _graph.backgroundColor = UIColor.clearColor;
    PAAcousticResult r; _graph.has = [PAAcousticMeasure loadSaved:&r]; _graph.r = r;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { static const NSInteger n[4] = {2, 1, 4, 1}; return (s >= 0 && s < 4) ? n[s] : 0; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Đo", @"Đáp ứng tần số loa + khoang xe", @"Kết quả", @""][s]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return @"Đỗ xe, đóng cửa, TẮT NHẠC, tắt hoặc giảm điều hòa, chỉnh âm lượng xe vừa nghe. App phát tiếng quét từ trầm lên cao trong 8 giây qua loa và thu bằng mic đã chọn.\nÂm thanh thu được chỉ được phân tích trên máy rồi xóa ngay, không lưu và không gửi đi.";
        case 1: return @"Cột: độ to của từng dải tần so với mức trung bình (đỏ = lệch nhiều). Đường vàng: dự đoán sau khi bù.";
        case 2: return @"Bù khoang xe giúp tiếng trầm và tiếng gầm của pô đúng như thiết kế trên loa VF7 (bù nhẹ, tối đa ±6 dB mỗi dải).";
    }
    return nil;
}

- (UITableViewCell *)cell:(NSString *)t detail:(NSString *)d {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.backgroundColor = PA_CARD; c.selectionStyle = UITableViewCellSelectionStyleNone;
    c.textLabel.text = t; c.textLabel.textColor = PA_FG;
    c.detailTextLabel.text = d; c.detailTextLabel.textColor = PA_MUTED; c.detailTextLabel.font = PAMono(15, UIFontWeightMedium);
    return c;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    PAAcousticResult r; BOOL has = [PAAcousticMeasure loadSaved:&r];
    if (ip.section == 0 && ip.row == 0) {
        UITableViewCell *c = [self cell:@"" detail:nil];
        _mic.translatesAutoresizingMaskIntoConstraints = NO; [c.contentView addSubview:_mic];
        UILayoutGuide *g = c.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[[_mic.topAnchor constraintEqualToAnchor:g.topAnchor], [_mic.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
            [_mic.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [_mic.trailingAnchor constraintEqualToAnchor:g.trailingAnchor]]];
        return c;
    }
    if (ip.section == 0) {
        UITableViewCell *c = [self cell:(_busy ? (_status ?: @"Đang đo…") : @"Bắt đầu đo (khoảng 12 giây)") detail:nil];
        c.textLabel.textColor = _busy ? PA_MUTED : PA_AMBER; c.textLabel.font = PAFont(17, UIFontWeightSemibold);
        c.selectionStyle = _busy ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        return c;
    }
    if (ip.section == 1) {
        UITableViewCell *c = [self cell:@"" detail:nil];
        _graph.translatesAutoresizingMaskIntoConstraints = NO; [c.contentView addSubview:_graph];
        UILayoutGuide *g = c.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[[_graph.topAnchor constraintEqualToAnchor:g.topAnchor], [_graph.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
            [_graph.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [_graph.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
            [_graph.heightAnchor constraintEqualToConstant:170]]];
        [_graph setNeedsDisplay];
        return c;
    }
    if (ip.section == 2) {
        if (ip.row == 0) return [self cell:@"Độ trễ loa" detail:has ? [NSString stringWithFormat:@"%.0f ms", r.latencyMs] : @"—"];
        if (ip.row == 1) return [self cell:@"Tín hiệu / tiếng ồn" detail:has ? [NSString stringWithFormat:@"%.0f dB", r.snrDb] : @"—"];
        if (ip.row == 2) return [self cell:@"Tiếng ồn nền" detail:has ? [NSString stringWithFormat:@"%.0f dBFS", r.noiseDbfs] : @"—"];
        UITableViewCell *c = [self cell:@"Áp dụng bù khoang xe" detail:nil];
        UISwitch *sw = [UISwitch new]; sw.onTintColor = PA_AMBER; sw.on = PAEngine.shared.acousticCorrection; sw.enabled = has;
        [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        return c;
    }
    UITableViewCell *c = [self cell:@"Xóa kết quả đo" detail:nil];
    c.textLabel.textColor = PA_RED; c.selectionStyle = UITableViewCellSelectionStyleDefault;
    return c;
}

- (void)toggle:(UISwitch *)s { PAEngine.shared.acousticCorrection = s.on; [_graph setNeedsDisplay]; }

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 3) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"acoustic.v1"];
        [PAEngine.shared reloadAcoustic];
        _graph.has = NO; [tv reloadData];
        return;
    }
    if (ip.section != 0 || ip.row != 1 || _busy) return;
    _busy = YES; _status = @"Chuẩn bị…"; [tv reloadData];
    __weak typeof(self) ws = self;
    [PAAcousticMeasure runUsingCarMic:_mic.selectedSegmentIndex == 0 progress:^(NSString *step) {
        typeof(self) ss = ws; if (!ss) return;
        ss->_status = step; [ss.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    } done:^(PAAcousticResult r, NSString *err) {
        typeof(self) ss = ws; if (!ss) return;
        ss->_busy = NO;
        if (!err) { ss->_graph.r = r; ss->_graph.has = YES; [PAEngine.shared reloadAcoustic]; }
        [ss.tableView reloadData];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:err ? @"Chưa đo được" : @"Đo xong"
            message:err ?: [NSString stringWithFormat:@"Độ trễ %.0f ms, tín hiệu/ồn %.0f dB. Đã lưu kết quả và bật bù khoang xe.", r.latencyMs, r.snrDb]
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [ss presentViewController:a animated:YES completion:nil];
    }];
}

@end
