#import "PASettingsMenuViewController.h"
#import "PASettingsViewController.h"
#import "PACarsViewController.h"
#import "PAVehicleViewController.h"
#import "PAReportViewController.h"
#import "PAEngine.h"
#import "PAVehicles.h"
#import "PAProfiles.h"
#import "PAUpdater.h"
#import "PAMotion.h"
#import "PATheme.h"

// Tab Cai dat: menu cac muc lon
@implementation PASettingsMenuViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.title = @"Cài đặt";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Cài đặt" image:[UIImage systemImageNamed:@"gearshape.fill"] tag:2];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = PA_BG;
    for (NSString *n in @[PAUpdaterDidChangeNotification, PAProfilesDidChangeNotification, PAEngineDidUpdateNotification])
        [NSNotificationCenter.defaultCenter addObserver:self.tableView selector:@selector(reloadData) name:n object:nil];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; self.navigationController.navigationBar.prefersLargeTitles = YES; [self.tableView reloadData]; }

// {tieu de, icon, mo ta}
- (NSArray<NSArray<NSArray *> *> *)rows {
    PAEngine *e = PAEngine.shared;
    PAVehicle *v = [PAVehicles byId:e.vehicleId];
    const PAPreset *p = &PA_PRESETS[pa_preset_index(e.presetKey.UTF8String)];
    PALearn l = ((PAMotion *)e.motion).learned;
    PAUpdater *u = PAUpdater.shared;
    return @[
        @[ @[@"Lựa chọn âm thanh", @"music.note", [NSString stringWithFormat:@"%s", p->name]],
           @[@"Xe đang lái", @"car.fill", v ? [@"VinFast " stringByAppendingString:v.title] : @"Xe khác (tự nhập)"],
           @[@"Tinh chỉnh âm thanh", @"slider.horizontal.3", [NSString stringWithFormat:@"âm lượng %.0f%% · gằn %.0f%% · dòn %.0f%%", e.volume * 100, e.growl * 100, e.crispness * 100]] ],
        @[ @[@"Tự động hoá (AI trên máy)", @"brain", e.learnEnabled ? [NSString stringWithFormat:@"đang học · %.0f km · tin cậy %.0f%%", l.distKm, pal_confidence(&l) * 100] : @"tắt"],
           @[@"Báo cáo hệ thống", @"doc.text.magnifyingglass", @"kiểm tra & xuất báo cáo"],
           @[@"Cập nhật hệ thống", @"arrow.triangle.2.circlepath", u.updateAvailable ? [NSString stringWithFormat:@"có bản %@", u.latestVersion] : [PAProfiles.shared statusText]] ],
        @[ @[@"Nổ máy tự động & thử khi đỗ", @"bolt.car", e.onlyWithCarPlay ? @"tự nổ máy: bật" : @"tự nổ máy: tắt"],
           @[@"Quyền & cảm biến", @"location.fill", e.locationStatusText ?: @""] ],
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [self rows][s].count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Xe & âm thanh", @"Thông minh", @"Khác"][s]; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSArray *r = [self rows][ip.section][ip.row];
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = PA_CARD;
    c.textLabel.text = r[0]; c.textLabel.textColor = PA_FG; c.textLabel.font = PAFont(17, UIFontWeightSemibold);
    c.detailTextLabel.text = r[2]; c.detailTextLabel.textColor = PA_MUTED;
    c.imageView.image = [UIImage systemImageNamed:r[1]]; c.imageView.tintColor = PA_AMBER;
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (ip.section == 1 && ip.row == 2 && PAUpdater.shared.updateAvailable) c.detailTextLabel.textColor = PA_AMBER;
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    UIViewController *vc = nil;
    switch (ip.section * 10 + ip.row) {
        case 0:  vc = [PACarsViewController new]; break;
        case 1:  vc = [PAVehicleViewController new]; break;
        case 2:  vc = [[PASettingsViewController alloc] initWithSections:@[@(SecSound)] title:@"Tinh chỉnh âm thanh"]; break;
        case 10: vc = [[PASettingsViewController alloc] initWithSections:@[@(SecLearn)] title:@"Tự động hoá"]; break;
        case 11: vc = [PAReportViewController new]; break;
        case 12: vc = [[PASettingsViewController alloc] initWithSections:@[@(SecUpdate)] title:@"Cập nhật hệ thống"]; [PAProfiles.shared checkNow]; [PAUpdater.shared checkNow]; break;
        case 20: vc = [[PASettingsViewController alloc] initWithSections:@[@(SecRun), @(SecTest)] title:@"Nổ máy tự động"]; break;
        case 21: vc = [[PASettingsViewController alloc] initWithSections:@[@(SecStatus)] title:@"Quyền & cảm biến"]; break;
    }
    if (vc) { vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever; [self.navigationController pushViewController:vc animated:YES]; }
}
@end
