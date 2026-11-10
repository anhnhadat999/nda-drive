#import "PASettingsViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PAUpdater.h"
#import "PATheme.h"
#import "PACalibrationViewController.h"
#import "PALog.h"
#import "PALearnViewController.h"
#import "PATripsViewController.h"
#import "PADiag.h"
#import "PAAcousticViewController.h"
#import "PASyncViewController.h"

typedef NS_ENUM(NSInteger, PASec) { SecCar, SecSound, SecLearn, SecRun, SecTest, SecStatus, SecUpdate, SecCount };

@implementation PASettingsViewController
{ float _sliderMin; }

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
        case SecCar: return 5;
        case SecSound: return 13;
        case SecLearn: return 4;
        case SecRun: return 2;
        case SecTest: return 2;
        case SecStatus: return 4;
        case SecUpdate: return 3;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return @[@"Thông số xe thật", @"Âm thanh", @"Học thích nghi", @"Hoạt động", @"Thử khi đỗ xe", @"Quyền & cảm biến", @"Cập nhật"][s];
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case SecCar: return @"Nhập đúng thông số xe của bạn để app mô phỏng chân thực nhất. \"Mã lực\" và \"0–100 km/h\" lấy theo công bố của hãng; \"Trọng lượng\" ước chừng cũng được. App dùng để tính độ bốc theo tốc độ: đi nhẹ thì tiếng thư giãn, đạp sâu mới gầm hết công suất — như xe xăng thật.";
        case SecSound: return @"Tiếng pô phát chung với nhạc và chỉ đường. \"Tự tăng âm lượng\" làm tiếng to dần theo tốc độ (tối đa +50% ở 120 km/h) để không bị tiếng gió lấn át. Chỉnh vừa phải để vẫn nghe được còi xe và xe ưu tiên.\n\"Hiệu ứng tiếng từ phía sau\" lọc theo các dải tần mà tai người gắn với âm thanh phía sau (tăng ~1 kHz và ~11 kHz, giảm ~4 kHz), thêm tiếng ù qua thân xe và phản xạ khoang xe. Muốn tiếng phát hẳn từ loa sau, chỉnh Fader về phía sau trong cài đặt âm thanh của xe.\n\"Rung sub gầm ghế\" thêm lớp siêu trầm (dưới 90 Hz) theo nhịp nổ máy và cú \"thụp\" khi lên số. Loa sub của xe tự nhận dải này; tăng mức Bass/Sub trong cài đặt âm thanh xe nếu muốn rung mạnh hơn.\n\"Độ gằn\" làm thân tiếng dày và uy lực hơn, gằn sớm ngay cả khi đi nhẹ. \"Độ dòn\" làm mỗi tiếng nổ sắc, đanh và tách bạch hơn.";
        case SecLearn: return @"Ứng dụng tự học độ bốc thật của xe và cách bạn lái qua từng chuyến đi, rồi tự chỉnh độ gằn, độ dòn, điểm sang số cho khớp. Học hoàn toàn trên iPhone.\n\"Thu thập dữ liệu cho Claude\": ghi số liệu cảm biến mỗi chuyến (không có tọa độ, tên hay số điện thoại) để bạn xuất báo cáo gửi Claude, dùng cho việc cải thiện tiếng pô ở các bản sau. Bật liên tục để dữ liệu ngày càng nhiều, tiếng ngày càng đúng xe bạn.\n\"Xe bứt tốc 0–100\": cho app biết xe mạnh cỡ nào. Xe điện mạnh (vd 350 mã lực, ~6 s) thì đi nhẹ tiếng thư giãn, chỉ khi đạp sâu mới gầm hết cỡ — giống xe thật.";
        case SecRun: return @"Bật mục này để xe tự nổ máy mỗi khi iPhone kết nối Apple CarPlay và tắt máy khi ngắt kết nối.";
        case SecTest: return @"Chỉ dùng khi xe đang đỗ. Kéo thanh tốc độ để nghe sang số mà không cần chạy xe.";
        case SecStatus: return @"\"Xuất báo cáo cho Claude\" đóng gói nhật ký, bộ đếm sự kiện, chất lượng cảm biến, lỗi thoát app và chuyến đi gần đây thành 1 tệp. Không chứa tọa độ, tên hay số điện thoại. Gửi tệp vào khung chat với Claude để phân tích.\nGắn iPhone cố định trên giá đỡ. Lần đầu lái, tăng tốc và phanh vài lần để máy tự học hướng xe.";
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
    // _sliderMin dat truoc khi goi de co nguong duoi (vd 0-100 giay 3..12)
    UITableViewCell *c = [self baseCell];
    UILabel *l = [UILabel new]; l.text = title; l.textColor = PA_FG; l.font = [UIFont systemFontOfSize:17];
    UILabel *d = [UILabel new]; d.text = detail; d.textColor = PA_MUTED; d.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightMedium];
    d.textAlignment = NSTextAlignmentRight; d.tag = 900 + tag;
    UISlider *s = [UISlider new];
    s.maximumValue = max; s.minimumValue = _sliderMin; _sliderMin = 0; s.value = v; s.tag = tag; s.enabled = en;
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
        case SecCar:
            if (ip.row == 0) { _sliderMin = 50;  return [self sliderCell:@"Mã lực (HP)" value:e.carHP max:800 tag:20 detail:[NSString stringWithFormat:@"%.0f HP", e.carHP] enabled:YES]; }
            if (ip.row == 1) { _sliderMin = 3;   return [self sliderCell:@"Tăng tốc 0–100 km/h" value:e.car0to100 max:12 tag:8 detail:[NSString stringWithFormat:@"%.1f s", e.car0to100] enabled:YES]; }
            if (ip.row == 2) { _sliderMin = 800; return [self sliderCell:@"Trọng lượng (kg)" value:e.carWeight max:3000 tag:21 detail:[NSString stringWithFormat:@"%.0f kg", e.carWeight] enabled:YES]; }
            if (ip.row == 3) return [self infoCell:@"Độ bốc tính được" detail:[NSString stringWithFormat:@"đỉnh %.1f m/s² · ghìm công suất từ %.0f km/h", e.car0to100 > 1 ? 27.78 / e.car0to100 * 1.4 : 0, e.perfKneeKmh] icon:@"gauge.high" tappable:NO];
            return [self infoCell:@"Góp ý độ chân thực" detail:@"giúp cải thiện" icon:@"hand.thumbsup" tappable:YES];
        case SecSound:
            if (ip.row == 0) return [self sliderCell:@"Âm lượng" value:e.volume max:1 tag:1 detail:[NSString stringWithFormat:@"%.0f%%", e.volume * 100] enabled:YES];
            if (ip.row == 1) return [self sliderCell:@"Độ đanh của pô" value:e.toneAmount max:1 tag:2 detail:toneText(e.toneAmount) enabled:YES];
            if (ip.row == 2) return [self sliderCell:@"Độ gằn (uy lực)" value:e.growl max:1 tag:6 detail:[NSString stringWithFormat:@"%.0f%%", e.growl * 100] enabled:YES];
            if (ip.row == 3) return [self sliderCell:@"Độ dòn (tiếng nổ)" value:e.crispness max:1 tag:7 detail:[NSString stringWithFormat:@"%.0f%%", e.crispness * 100] enabled:YES];
            if (ip.row == 4) return [self switchCell:@"Nổ lụp bụp khi nhả ga" icon:@"flame.fill" on:e.popsEnabled tag:10];
            if (ip.row == 5) return [self switchCell:@"Tiếng \"bụp\" khi lên số" icon:@"arrow.up.circle.fill" on:e.shiftPopEnabled tag:11];
            if (ip.row == 6) return [self switchCell:@"Tự tăng âm lượng theo tốc độ" icon:@"speaker.wave.3.fill" on:e.autoVolume tag:16];
            if (ip.row == 7) return [self switchCell:@"Hiệu ứng tiếng từ phía sau" icon:@"speaker.wave.2.fill" on:e.rearEffect tag:17];
            if (ip.row == 8) return [self sliderCell:@"Cường độ cảm giác phía sau" value:e.rearAmount max:1 tag:4 detail:[NSString stringWithFormat:@"%.0f%%", e.rearAmount * 100] enabled:e.rearEffect];
            if (ip.row == 9) return [self infoCell:@"Đo âm học khoang xe" detail:(e.acousticCorrection ? @"bù: bật" : nil) icon:@"waveform.and.mic" tappable:YES];
            if (ip.row == 11) return [self sliderCell:@"Giống ngồi trong xe" value:e.interior max:1 tag:22 detail:[NSString stringWithFormat:@"%.0f%%", e.interior * 100] enabled:YES];
            if (ip.row == 12) return [self sliderCell:@"Tiếng cơ khí (máy)" value:e.mechanical max:1 tag:23 detail:[NSString stringWithFormat:@"%.0f%%", e.mechanical * 100] enabled:YES];
            return [self sliderCell:@"Rung sub gầm ghế" value:e.subAmount max:1 tag:5 detail:[NSString stringWithFormat:@"%.0f%%", e.subAmount * 100] enabled:YES];
        case SecLearn: {
            if (ip.row == 0) return [self switchCell:@"Tự học theo xe và cách lái" icon:@"brain" on:e.learnEnabled tag:18];
            if (ip.row == 2) return [self switchCell:@"Thu thập dữ liệu cho Claude" icon:@"record.circle" on:e.recordEnabled tag:19];
            if (ip.row == 3) return [self infoCell:@"Lịch sử chuyến đi" detail:nil icon:@"list.bullet.rectangle" tappable:YES];
            PALearn l = ((PAMotion *)e.motion).learned;
            double sp = pal_sport(&l);
            NSString *style = sp < 0.33 ? @"êm" : (sp < 0.66 ? @"vừa" : @"thể thao");
            return [self infoCell:@"Hồ sơ xe đã học" detail:[NSString stringWithFormat:@"%.0f km · lái %@ · 0–100 ~%.1f s · %.0f%%", l.distKm, style, pal_zero_to_100(&l), pal_confidence(&l) * 100] icon:@"chart.line.uptrend.xyaxis" tappable:YES];
        }
        case SecRun:
            if (ip.row == 0) return [self switchCell:@"Bật pô ảo" icon:@"power" on:e.enabled tag:12];
            return [self switchCell:@"Tự nổ máy khi kết nối CarPlay" icon:@"car.fill" on:e.onlyWithCarPlay tag:13];
        case SecTest:
            if (ip.row == 0) return [self switchCell:@"Giả lập tốc độ" icon:@"speedometer" on:e.testMode tag:14];
            return [self sliderCell:@"Tốc độ giả lập" value:e.testSpeedKmh max:220 tag:3 detail:[NSString stringWithFormat:@"%.0f km/h", e.testSpeedKmh] enabled:e.testMode];
        case SecStatus:
            if (ip.row == 0) return [self infoCell:@"Vị trí" detail:e.locationStatusText icon:@"location.fill" tappable:YES];
            if (ip.row == 1) return [self infoCell:@"Căn chỉnh cảm biến" detail:e.sensorStatusText icon:@"gyroscope" tappable:YES];
            if (ip.row == 3) return [self infoCell:@"Phân tích đồng bộ tiếng – xe" detail:nil icon:@"waveform.path.ecg" tappable:YES];
            return [self infoCell:@"Xuất báo cáo cho Claude" detail:@"1 tệp .zip" icon:@"doc.zipper" tappable:YES];
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
    if (ip.section == SecCar && ip.row == 4) { [self askRealism]; return; }
    if (ip.section == SecStatus && ip.row == 3) {
        [self.navigationController pushViewController:[PASyncViewController new] animated:YES];
        return;
    }
    if (ip.section == SecStatus && ip.row == 0) {
        [PAEngine.shared requestLocationPermission];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    } else if (ip.section == SecSound && ip.row == 9) {
        [self.navigationController pushViewController:[PAAcousticViewController new] animated:YES];
    } else if (ip.section == SecLearn && ip.row == 3) {
        [self.navigationController pushViewController:[PATripsViewController new] animated:YES];
    } else if (ip.section == SecLearn && ip.row == 1) {
        [self.navigationController pushViewController:[PALearnViewController new] animated:YES];
    } else if (ip.section == SecStatus && ip.row == 2) {
        UIAlertController *wait = [UIAlertController alertControllerWithTitle:@"Đang đóng gói báo cáo…" message:@"Nhật ký, bộ đếm sự kiện, chất lượng cảm biến, lỗi thoát app, tóm tắt chuyến đi." preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:wait animated:YES completion:^{
            [PADiag.shared buildReport:^(NSURL *zip, NSString *err) {
                [wait dismissViewControllerAnimated:YES completion:^{
                    if (!zip) {
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Không tạo được báo cáo" message:err preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [self presentViewController:a animated:YES completion:nil];
                        return;
                    }
                    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[zip] applicationActivities:nil];
                    av.popoverPresentationController.sourceView = [tv cellForRowAtIndexPath:ip];
                    av.completionWithItemsHandler = ^(UIActivityType t, BOOL ok, NSArray *items, NSError *shareErr) {
                        if (!shareErr) return;
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Chia sẻ bị lỗi"
                            message:[NSString stringWithFormat:@"Tệp báo cáo vẫn đã được lưu. Mở Filza, vào /var/mobile/Documents/NDADrive-bao-cao để gửi tệp .zip.\n(%@)", shareErr.localizedDescription]
                            preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                        [self presentViewController:a animated:YES completion:nil];
                    };
                    [self presentViewController:av animated:YES completion:nil];
                }];
            }];
        }];
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
        case 17:
            e.rearEffect = s.on;
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:8 inSection:SecSound]] withRowAnimation:UITableViewRowAnimationNone];
            break;
        case 18: e.learnEnabled = s.on; break;
        case 19: e.recordEnabled = s.on; break;
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
    else if (s.tag == 5) { e.subAmount = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 6) { e.growl = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 7) { e.crispness = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 8) { e.car0to100 = round(s.value * 2) / 2.0; d.text = [NSString stringWithFormat:@"%.1f s", e.car0to100]; }
    else if (s.tag == 20) { e.carHP = round(s.value); d.text = [NSString stringWithFormat:@"%.0f HP", e.carHP]; }
    else if (s.tag == 21) { e.carWeight = round(s.value / 10) * 10; d.text = [NSString stringWithFormat:@"%.0f kg", e.carWeight]; }
    else if (s.tag == 22) { e.interior = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 23) { e.mechanical = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 4) { e.rearAmount = s.value; d.text = [NSString stringWithFormat:@"%.0f%%", s.value * 100]; }
    else if (s.tag == 3) { e.testSpeedKmh = round(s.value); d.text = [NSString stringWithFormat:@"%.0f km/h", round(s.value)]; }
}


- (void)askRealism {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Tiếng pô vừa rồi thế nào?"
        message:@"Góp ý được lưu vào báo cáo (không kèm tọa độ) để Claude chỉnh cho đúng xe bạn." preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *opts = @[@"Rất giống xe thật", @"Khá giống", @"Chưa giống lắm", @"Tiếng quá yếu/nhỏ", @"Tiếng quá gào/ồn", @"Lệch chân ga (trễ)"];
    for (NSString *o in opts) {
        [a addAction:[UIAlertAction actionWithTitle:o style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
            NSMutableArray *arr = [([d arrayForKey:@"realismFeedback"] ?: @[]) mutableCopy];
            NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = @"yyyy-MM-dd HH:mm";
            [arr addObject:@{ @"luc": [df stringFromDate:[NSDate date]], @"y_kien": o,
                @"preset": PAEngine.shared.presetKey ?: @"", @"growl": @(PAEngine.shared.growl), @"crisp": @(PAEngine.shared.crispness),
                @"interior": @(PAEngine.shared.interior), @"0_100": @(PAEngine.shared.car0to100) }];
            while (arr.count > 40) [arr removeObjectAtIndex:0];
            [d setObject:arr forKey:@"realismFeedback"];
            [PADiag.shared bump:@"gop_y_chan_thuc"];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView = self.view;
    a.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    [self presentViewController:a animated:YES completion:nil];
}

@end
