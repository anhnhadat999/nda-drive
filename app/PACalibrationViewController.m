#import "PACalibrationViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PATheme.h"

typedef NS_ENUM(NSInteger, CalSec) { CSGuide, CSState, CSLive, CSTune, CSReset, CSCount };

@implementation PACalibrationViewController {
    NSTimer *_timer;
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Căn chỉnh cảm biến";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.backgroundColor = PA_BG;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak typeof(self) ws = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) { [ws tick]; }];
    [self.tableView reloadData];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_timer invalidate]; _timer = nil; }

- (void)tick {
    NSMutableArray *ips = [NSMutableArray array];
    for (NSInteger r = 0; r < 4; r++) [ips addObject:[NSIndexPath indexPathForRow:r inSection:CSState]];
    for (NSInteger r = 0; r < 4; r++) [ips addObject:[NSIndexPath indexPathForRow:r inSection:CSLive]];
    [self.tableView reloadRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationNone];
}

- (PAMotion *)mo { return (PAMotion *)PAEngine.shared.motion; }

#pragma mark - Bang

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return CSCount; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) { case CSGuide: return 0; case CSState: return 4; case CSLive: return 4; case CSTune: return 2; case CSReset: return 1; }
    return 0;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return @[@"Cách căn chỉnh", @"Trạng thái", @"Số đo trực tiếp", @"Tùy chỉnh", @""][s];
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case CSGuide: return @"1. Gắn iPhone cố định trên giá đỡ, màn hình hướng về người lái.\n"
                              "2. Bấm NỔ MÁY (hoặc kết nối CarPlay).\n"
                              "3. Lái ở nơi thoáng, tăng tốc rồi phanh 2–3 lần trên đường thẳng.\n"
                              "4. Khi \"Hướng xe\" báo \"Đã học ✓\" là xong. Kết quả được lưu, lần sau không cần làm lại nếu không đổi góc gắn máy.";
        case CSState: return self.mo.running ? nil : @"Cảm biến đang tắt. Bấm NỔ MÁY ở tab Lái xe để xem số đo.";
        case CSTune: return @"Hiệu chỉnh tốc độ: đồng hồ xe thường báo cao hơn tốc độ thật 3–5%. Tăng mục này để số trong app khớp đồng hồ xe.\n"
                             "Phản hồi: \"Nhanh\" tin cảm biến nhiều hơn (tiếng pô phản ứng tức thì), \"Ổn định\" tin GPS nhiều hơn (mượt, ít giật).";
        case CSReset: return @"Dùng khi bạn đổi vị trí hoặc góc gắn iPhone trên xe.";
    }
    return nil;
}

- (UITableViewCell *)cell:(NSString *)t detail:(NSString *)d color:(UIColor *)col {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.backgroundColor = PA_CARD; c.selectionStyle = UITableViewCellSelectionStyleNone;
    c.textLabel.text = t; c.textLabel.textColor = PA_FG;
    c.detailTextLabel.text = d; c.detailTextLabel.textColor = col ?: PA_MUTED;
    c.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    return c;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    PAMotion *m = self.mo;
    PAEngine *e = PAEngine.shared;
    BOOL on = m.running;
    switch (ip.section) {
        case CSState:
            if (ip.row == 0) {
                if (!on) return [self cell:@"Hướng xe" detail:@"—" color:nil];
                if (m.calibrated) return [self cell:@"Hướng xe" detail:@"Đã học ✓" color:PA_GREEN];
                return [self cell:@"Hướng xe" detail:[NSString stringWithFormat:@"Đang học %.0f%%", m.calProgress * 100] color:PA_AMBER];
            }
            if (ip.row == 1) return [self cell:@"Góc lệch giá đỡ" detail:(on && m.calibrated ? [NSString stringWithFormat:@"%.0f°", fabs(m.mountAngleDeg)] : @"—") color:nil];
            if (ip.row == 2) {
                NSString *g; UIColor *col = nil;
                if (!on || m.gpsRawKmh < 0) g = @"—";
                else if (!m.gpsOk) { g = @"Mất tín hiệu"; col = PA_RED; }
                else if (m.gpsAccuracy > 0 && m.gpsAccuracy <= 0.6) { g = [NSString stringWithFormat:@"Tốt (±%.1f m/s)", m.gpsAccuracy]; col = PA_GREEN; }
                else if (m.gpsAccuracy > 0) { g = [NSString stringWithFormat:@"Yếu (±%.1f m/s)", m.gpsAccuracy]; col = PA_AMBER; }
                else g = @"Đang dò";
                return [self cell:@"Tín hiệu GPS" detail:g color:col];
            }
            return [self cell:@"Xe đang dừng" detail:(on ? (m.stationary ? @"Có ✓" : @"Không") : @"—") color:nil];
        case CSLive:
            if (ip.row == 0) return [self cell:@"Tốc độ GPS" detail:(on && m.gpsRawKmh >= 0 ? [NSString stringWithFormat:@"%.1f km/h", m.gpsRawKmh] : @"—") color:nil];
            if (ip.row == 1) return [self cell:@"Tốc độ dùng cho tiếng pô" detail:(on ? [NSString stringWithFormat:@"%.1f km/h", m.speedKmh] : @"—") color:PA_AMBER];
            if (ip.row == 2) return [self cell:@"Gia tốc dọc xe" detail:(on ? [NSString stringWithFormat:@"%+.2f m/s²", m.accelMs2] : @"—") color:nil];
            return [self cell:@"Độ dốc đường" detail:(on ? [NSString stringWithFormat:@"%+.1f%%", m.gradePct] : @"—") color:nil];
        case CSTune:
            if (ip.row == 0) {
                UITableViewCell *c = [self cell:@"" detail:nil color:nil];
                UILabel *l = [UILabel new]; l.text = @"Hiệu chỉnh tốc độ"; l.textColor = PA_FG;
                UILabel *d = [UILabel new]; d.tag = 77; d.textColor = PA_MUTED; d.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
                d.text = [NSString stringWithFormat:@"%+.0f%%", e.speedTrim * 100]; d.textAlignment = NSTextAlignmentRight;
                UISlider *s = [UISlider new]; s.minimumValue = -10; s.maximumValue = 10; s.value = e.speedTrim * 100; s.minimumTrackTintColor = PA_AMBER;
                [s addTarget:self action:@selector(trim:) forControlEvents:UIControlEventValueChanged];
                UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, d]];
                UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[row, s]]; st.axis = UILayoutConstraintAxisVertical; st.spacing = 6;
                st.translatesAutoresizingMaskIntoConstraints = NO; [c.contentView addSubview:st];
                UILayoutGuide *g = c.contentView.layoutMarginsGuide;
                [NSLayoutConstraint activateConstraints:@[[st.topAnchor constraintEqualToAnchor:g.topAnchor constant:4], [st.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-4],
                    [st.leadingAnchor constraintEqualToAnchor:g.leadingAnchor], [st.trailingAnchor constraintEqualToAnchor:g.trailingAnchor]]];
                return c;
            } else {
                UITableViewCell *c = [self cell:@"Phản hồi" detail:nil color:nil];
                UISegmentedControl *sc = [[UISegmentedControl alloc] initWithItems:@[@"Ổn định", @"Cân bằng", @"Nhanh"]];
                sc.selectedSegmentIndex = e.responseMode;
                sc.selectedSegmentTintColor = PA_AMBER;
                [sc setTitleTextAttributes:@{ NSForegroundColorAttributeName: UIColor.blackColor } forState:UIControlStateSelected];
                [sc addTarget:self action:@selector(resp:) forControlEvents:UIControlEventValueChanged];
                c.accessoryView = sc; [sc sizeToFit];
                return c;
            }
        case CSReset: {
            UITableViewCell *c = [self cell:@"Xóa căn chỉnh và học lại" detail:nil color:nil];
            c.textLabel.textColor = PA_RED; c.selectionStyle = UITableViewCellSelectionStyleDefault;
            return c;
        }
    }
    return [self cell:@"" detail:nil color:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != CSReset) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Học lại hướng xe?"
        message:@"Căn chỉnh đã lưu sẽ bị xóa. Khi lái, tăng tốc và phanh vài lần để máy học lại." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Xóa và học lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [self.mo resetCalibration];
        [[[UINotificationFeedbackGenerator alloc] init] notificationOccurred:UINotificationFeedbackTypeSuccess];
        [self.tableView reloadData];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)trim:(UISlider *)s {
    double v = round(s.value);
    PAEngine.shared.speedTrim = v / 100.0;
    UILabel *d = [s.superview viewWithTag:77];
    d.text = [NSString stringWithFormat:@"%+.0f%%", v];
}
- (void)resp:(UISegmentedControl *)sc { PAEngine.shared.responseMode = sc.selectedSegmentIndex; }

@end
