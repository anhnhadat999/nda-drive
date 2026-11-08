#import "PASettingsViewController.h"
#import "PAEngine.h"
#import "PAUpdater.h"
#import "PATheme.h"
#import "PACalibrationViewController.h"

typedef NS_ENUM(NSInteger, PASec) { SecSound, SecRun, SecTest, SecStatus, SecUpdate, SecCount };

@implementation PASettingsViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.title = @"Cài đặt";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Cài đặt" image:[UIImage systemImageNamed:@"gearshape.fill"] tag:2];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.tableView.backgroundColor = PA_BG;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(reloadStatus) name:PAUpdaterDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (void)reloadStatus {
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SecUpdate] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Du lieu

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return SecCount; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case SecSound: return 5;
        case SecRun: return 2;
        case SecTest: return 2;
        case SecStatus: return 2;
        case SecUpdate: return 3;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return @[@"Âm thanh", @"Hoạt động", @"Thử khi đỗ xe", @"Quyền & cảm biến", @"Cập nhật"][s];
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case SecSound: return @"Tiếng pô phát chung với nhạc và chỉ đường. \"Tự tăng âm lượng\" làm tiếng to dần theo tốc độ (tối đa +50% ở 120 km/h) để không bị tiếng gió lấn át. Chỉnh vừa phải để vẫn nghe được còi xe và xe ưu tiên.";
        case SecRun: return @"Bật mục này để xe tự nổ máy mỗi khi iPhone kết nối Apple CarPlay và tắt máy khi ngắt kết nối.";
        case SecTest: return @"Chỉ dùng khi xe đang đỗ. Kéo thanh tốc độ để nghe sang số mà không cần chạy xe.";
        case SecStatus: return @"Gắn iPhone cố định trên giá đỡ. Lần đầu lái, tăng tốc và phanh vài lần để máy tự học hướng xe.";
        case SecUpdate: return @"Thêm nguồn NDA Drive vào Sileo một lần. Các bản sau sẽ tự hiện trong mục cập nhật của Sileo.";
    }
    return nil;
}

#pragma mark - O

- (UITableViewCell *)baseCell {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.backgroundColor = PA_CARD;
    c.textLabel.textColor = PA_FG;
    c.detailTextLabel.textColor = PA_MUTED;
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    return c;
}

- (UITableViewCell *)switchCell:(NSString *)title icon:(NSString *)icon on:(BOOL)on tag:(NSInteger)tag {
    UITableViewCell *c = [self baseCell];
    c.textLabel.text = title;
    c.imageView.image = [UIImage systemImageNamed:icon];
    c.imageView.tintColor = PA_AMBER;
    UISwitch *s = [UISwitch new];
    s.on = on; s.onTintColor = PA_AMBER; s.tag = tag;
    [s addTarget:self action:@selector(switched:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = s;
    return c;
}

- (UITableViewCell *)sliderCell:(NSString *)title value:(float)v max:(float)max tag:(NSInteger)tag detail:(NSString *)detail enabled:(BOOL)en {
    UITableViewCell *c = [self baseCell];
    UILabel *l = [UILabel new]; l.text = title; l.textColor = PA_FG; l.font = [UIFont systemFontOfSize:17];
    UILabel *d = [UILabel new]; d.text = detail; d.textColor = PA_MUTED; d.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    d.textAlignment = NSTextAlignmentRight; d.tag = 900 + tag;
    UISlider *s = [UISlider new];
    s.maximumValue = max; s.value = v; s.tag = tag; s.enabled = en;
    s.minimumTrackTintColor = PA_AMBER;
    [s addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, d]];
    UIStackView *st = [[UIStackView alloc] initWithArrangedSubviews:@[row, s]];
    st.axis = UILayoutConstraintAxisVertical; st.spacing = 6;
    st.translatesAutoresizingMaskIntoConstraints = NO;
    [c.contentView addSubview:st];
    UILayoutGuide *m = c.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [st.topAnchor constraintEqualToAnchor:m.topAnchor constant:4], [st.bottomAnchor constraintEqualToAnchor:m.bottomAnchor constant:-4],
        [st.leadingAnchor constraintEqualToAnchor:m.leadingAnchor], [st.trailingAnchor constraintEqualToAnchor:m.trailingAnchor]]];
    st.alpha = en ? 1 : .45;
    return c;
}

- (UITableViewCell *)infoCell:(NSString *)title detail:(NSString *)detail icon:(NSString *)icon tappable:(BOOL)tap {
    UITableViewCell *c = [self baseCell];
    c.textLabel.text = title;
    c.detailTextLabel.text = detail;
    c.detailTextLabel.numberOfLines = 2;
    c.imageView.image = [UIImage systemImageNamed:icon];
    c.imageView.tintColor = PA_AMBER;
    if (tap) { c.selectionStyle = UITableViewCellSelectionStyleDefault; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
    return c;
}

static NSString *toneText(double t) { return t < 0.34 ? @"Êm" : (t < 0.67 ? @"Vừa" : @"Đanh"); }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    PAEngine *e = PAEngine.shared;
    PAUpdater *u = PAUpdater.shared;
    switch (ip.section) {
        case SecSound:
            if (ip.row == 0) return [self sliderCell:@"Âm lượng" value:e.volume max:1 tag:1 detail:[NSString stringWithFormat:@"%.0f%%", e.volume * 100] enabled:YES];
            if (ip.row == 1) return [self sliderCell:@"Độ đanh của pô" value:e.toneAmount max:1 tag:2 detail:toneText(e.toneAmount) enabled:YES];
            if (ip.row == 2) return [self switchCell:@"Nổ lụp bụp khi nhả ga" icon:@"flame.fill" on:e.popsEnabled tag:10];
            if (ip.row == 3) return [self switchCell:@"Tiếng \"bụp\" khi lên số" icon:@"arrow.up.circle.fill" on:e.shiftPopEnabled tag:11];
            return [self switchCell:@"Tự tăng âm lượng theo tốc độ" icon:@"speaker.wave.3.fill" on:e.autoVolume tag:16];
        case SecRun:
            if (ip.row == 0) return [self switchCell:@"Bật pô ảo" icon:@"power" on:e.enabled tag:12];
            return [self switchCell:@"Tự nổ máy khi kết nối CarPlay" icon:@"car.fill" on:e.onlyWithCarPlay tag:13];
        case SecTest:
            if (ip.row == 0) return [self switchCell:@"Giả lập tốc độ" icon:@"speedometer" on:e.testMode tag:14];
            return [self sliderCell:@"Tốc độ giả lập" value:e.testSpeedKmh max:220 tag:3 detail:[NSString stringWithFormat:@"%.0f km/h", e.testSpeedKmh] enabled:e.testMode];
        case SecStatus:
            if (ip.row == 0) return [self infoCell:@"Vị trí" detail:e.locationStatusText icon:@"location.fill" tappable:YES];
            return [self infoCell:@"Căn chỉnh cảm biến" detail:e.sensorStatusText icon:@"gyroscope" tappable:YES];
        case SecUpdate:
            if (ip.row == 0) {
                NSString *d = u.checking ? @"Đang kiểm tra…" :
                    (u.updateAvailable ? [NSString stringWithFormat:@"Có bản %@", u.latestVersion] :
                     (u.latestVersion ? @"Đã là bản mới nhất" : [NSString stringWithFormat:@"Bản %@", u.currentVersion]));
                UITableViewCell *c = [self infoCell:@"Kiểm tra cập nhật" detail:d icon:@"arrow.triangle.2.circlepath" tappable:YES];
                if (u.updateAvailable) c.detailTextLabel.textColor = PA_AMBER;
                return c;
            }
            if (ip.row == 1) return [self infoCell:@"Thêm nguồn vào Sileo" detail:nil icon:@"plus.app.fill" tappable:YES];
            return [self infoCell:@"Phiên bản" detail:u.currentVersion icon:@"info.circle.fill" tappable:NO];
    }
    return [self baseCell];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SecStatus && ip.row == 0) {
        [PAEngine.shared requestLocationPermission];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    } else if (ip.section == SecStatus && ip.row == 1) {
        [self.navigationController pushViewController:[PACalibrationViewController new] animated:YES];
    } else if (ip.section == SecUpdate && ip.row == 0) {
        PAUpdater *u = PAUpdater.shared;
        if (u.updateAvailable) [u openUpdateInSileo]; else [u checkNow];
    } else if (ip.section == SecUpdate && ip.row == 1) {
        [PAUpdater.shared openAddSourceInSileo];
    }
}

#pragma mark - Su kien

- (void)switched:(UISwitch *)s {
    PAEngine *e = PAEngine.shared;
    switch (s.tag) {
        case 10: e.popsEnabled = s.on; break;
        case 11: e.shiftPopEnabled = s.on; break;
        case 12: e.enabled = s.on; break;
        case 13: e.onlyWithCarPlay = s.on; break;
        case 16: e.autoVolume = s.on; break;
        case 14:
            e.testMode = s.on;
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:SecTest]] withRowAnimation:UITableViewRowAnimationNone];
            break;
    }
}

- (void)slid:(UISlider *)s {
    PAEngine *e = PAEngine.shared;
    UILabel *d = [s.superview viewWithTag:900 + s.tag];
    if (s.tag == 1) { e.volume = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 2) { e.toneAmount = s.value; d.text = toneText(s.value); }
    else if (s.tag == 3) { e.testSpeedKmh = round(s.value); d.text = [NSString stringWithFormat:@"%.0f km/h", round(s.value)]; }
}

@end
