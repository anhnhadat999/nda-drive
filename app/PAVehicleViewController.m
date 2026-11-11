#import "PAVehicleViewController.h"
#import "PAVehicles.h"
#import "PAEngine.h"
#import "PATheme.h"
#import "PASettingsViewController.h"
#import "PAProfiles.h"

// Chon xe dang lai: danh sach VinFast, thong so co dinh theo hang (khong can chinh tay)
@implementation PAVehicleViewController { NSArray<NSString *> *_models; NSDictionary<NSString *, NSArray<PAVehicle *> *> *_byModel; }

- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Xe đang lái"; return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = PA_BG;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self rebuild];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(rebuild) name:PAProfilesDidChangeNotification object:nil];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self.tableView reloadData]; }

- (void)rebuild {
    NSMutableArray *m = [NSMutableArray array]; NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (PAVehicle *v in [PAVehicles all]) {
        if (!d[v.model]) { d[v.model] = [NSMutableArray array]; [m addObject:v.model]; }
        [d[v.model] addObject:v];
    }
    _models = m; _byModel = d;
    [self.tableView reloadData];
}

// 0 = nguoi lai thu, 1.._models.count = cac dong xe, cuoi = xe khac
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return _models.count + 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    if (s == 0 || s == (NSInteger)_models.count + 1) return 1;
    return _byModel[_models[s - 1]].count;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    if (s == 0) return @"Người lái thử";
    if (s == (NSInteger)_models.count + 1) return @"Xe khác";
    return [@"VinFast " stringByAppendingString:_models[s - 1]];
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) return @"Đặt biệt danh khi cho bạn bè chạy thử (vd: tester-01). Biệt danh và dòng xe được ghi vào báo cáo để Claude tách số liệu theo từng người, từng xe. Không ghi tên thật, số điện thoại hay tọa độ.";
    if (s == (NSInteger)_models.count + 1) return @"Thông số lấy theo công bố của VinFast. Mục ghi \"ước tính\" là chưa có số chính thức — sẽ được sửa tự động qua \"Hồ sơ chuẩn theo xe\" khi có dữ liệu thực tế.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    PAEngine *e = PAEngine.shared;
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = PA_CARD; c.textLabel.textColor = PA_FG; c.detailTextLabel.textColor = PA_MUTED; c.tintColor = PA_AMBER;
    if (ip.section == 0) {
        UITextField *f = [UITextField new];
        f.text = e.testerTag; f.placeholder = @"Biệt danh (để trống = chủ xe)"; f.textColor = PA_FG;
        f.autocorrectionType = UITextAutocorrectionTypeNo; f.autocapitalizationType = UITextAutocapitalizationTypeNone; f.returnKeyType = UIReturnKeyDone;
        [f addTarget:self action:@selector(tagChanged:) forControlEvents:UIControlEventEditingChanged];
        [f addTarget:f action:@selector(resignFirstResponder) forControlEvents:UIControlEventEditingDidEndOnExit];
        f.translatesAutoresizingMaskIntoConstraints = NO; [c.contentView addSubview:f];
        UILayoutGuide *m = c.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[[f.leadingAnchor constraintEqualToAnchor:m.leadingAnchor], [f.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
            [f.topAnchor constraintEqualToAnchor:m.topAnchor], [f.bottomAnchor constraintEqualToAnchor:m.bottomAnchor], [f.heightAnchor constraintGreaterThanOrEqualToConstant:30]]];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        return c;
    }
    if (ip.section == (NSInteger)_models.count + 1) {
        BOOL sel = [e.vehicleId isEqualToString:@"custom"];
        c.textLabel.text = @"Xe khác — tự nhập thông số";
        c.detailTextLabel.text = sel ? [NSString stringWithFormat:@"%.0f mã lực · %.0f kg · 0–100 %.1f s", e.carHP, e.carWeight, e.car0to100] : @"Dùng cho xe không có trong danh sách";
        c.textLabel.textColor = sel ? PA_AMBER : PA_FG;
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    PAVehicle *v = _byModel[_models[ip.section - 1]][ip.row];
    BOOL sel = [v.vid isEqualToString:e.vehicleId];
    c.textLabel.text = v.trim; c.textLabel.font = PAFont(17, UIFontWeightSemibold);
    c.textLabel.textColor = sel ? PA_AMBER : PA_FG;
    c.detailTextLabel.text = v.specLine; c.detailTextLabel.numberOfLines = 0; c.detailTextLabel.font = PAFont(13, UIFontWeightRegular);
    c.backgroundColor = sel ? [PA_AMBER colorWithAlphaComponent:0.10] : PA_CARD;
    c.accessoryType = sel ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}

- (void)tagChanged:(UITextField *)f {
    NSString *t = [f.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] ?: @"";
    if (t.length > 24) t = [t substringToIndex:24];
    PAEngine.shared.testerTag = t;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) return;
    if (ip.section == (NSInteger)_models.count + 1) {
        PAEngine.shared.vehicleId = @"custom";
        [self.navigationController pushViewController:[[PASettingsViewController alloc] initWithSections:@[@(SecCar)] title:@"Thông số xe khác"] animated:YES];
        return;
    }
    PAVehicle *v = _byModel[_models[ip.section - 1]][ip.row];
    [PAEngine.shared selectVehicle:v.vid];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [tv reloadData];
}
@end
