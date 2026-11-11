#import "PACarsViewController.h"
#import "PAEngine.h"
#import "PATheme.h"
#import "PAVehicles.h"

// Danh sach chon xe: chi ten xe + thong so, kieu bang nhom chuan iOS
@implementation PACarsViewController {
    NSArray<NSNumber *> *_groups[2];
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.title = @"Lựa chọn âm thanh";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.tableView.backgroundColor = PA_BG;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 68;
    NSMutableArray *p = [NSMutableArray array], *o = [NSMutableArray array];
    for (int i = 0; i < PA_PRESET_COUNT; i++) {
        if ([@(PA_PRESETS[i].car) hasPrefix:@"Porsche"]) [p addObject:@(i)]; else [o addObject:@(i)];
    }
    _groups[0] = p; _groups[1] = o;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return _groups[s].count; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Phong cách boxer (kiểu Porsche)" : @"Các kiểu động cơ khác"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == 1 ? @"Mọi tiếng pô được TỔNG HỢP bằng thuật toán theo vật lý của từng kiểu động cơ (số xi-lanh, thứ tự nổ, cộng hưởng ống xả), không dùng bản ghi âm có bản quyền.\nMỗi tiếng được tách thành nhiều lớp riêng: nổ xi-lanh, cộng hưởng ống xả 3 dải, hút gió, turbo/xả van, nổ lụp bụp, tiếng cơ khí và lớp siêu trầm cho sub. Chế độ Tự động hoá dùng số liệu bạn lái để tự chỉnh từng lớp cho khớp xe.\n★ = gợi ý cho xe bạn đang chọn." : nil;
}

static NSString *subtitleOf(const PAPreset *p) {
    NSString *car = @(p->car);
    NSRange dot = [car rangeOfString:@" · "];
    NSString *desc = dot.location != NSNotFound ? [car substringFromIndex:dot.location + dot.length] : car;
    return desc;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"car"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"car"];
    int i = _groups[ip.section][ip.row].intValue;
    const PAPreset *p = &PA_PRESETS[i];
    BOOL sel = [@(p->key) isEqualToString:PAEngine.shared.presetKey];
    c.backgroundColor = sel ? [PA_AMBER colorWithAlphaComponent:0.10] : PA_CARD;
    c.textLabel.text = @(p->name);
    c.textLabel.font = PAFont(18, UIFontWeightBold);
    c.textLabel.textColor = sel ? PA_AMBER : PA_FG;
    NSMutableArray *ly = [NSMutableArray arrayWithObjects:@"nổ", @"ống xả", nil];
    if (p->intake > 0) [ly addObject:@"hút gió"];
    if (p->turbo) [ly addObject:@"turbo"];
    if (p->vtec > 0) [ly addObject:@"VTEC"];
    [ly addObjectsFromArray:@[@"lụp bụp", @"cơ khí", @"sub"]];
    PAVehicle *veh = [PAVehicles byId:PAEngine.shared.vehicleId];
    if (veh && [veh.preset isEqualToString:@(p->key)]) c.textLabel.text = [@"★ " stringByAppendingString:@(p->name)];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%d xi-lanh · %.0f v/p%@\nLớp: %@", subtitleOf(p), p->cyl, p->redline, p->turbo ? @" · turbo" : @"", [ly componentsJoinedByString:@" · "]];
    c.detailTextLabel.numberOfLines = 3;
    c.detailTextLabel.font = PAFont(13, UIFontWeightMedium);
    c.detailTextLabel.textColor = PA_MUTED;
    c.accessoryType = sel ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    c.tintColor = PA_AMBER;
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    int i = _groups[ip.section][ip.row].intValue;
    PAEngine *e = PAEngine.shared;
    e.presetKey = @(PA_PRESETS[i].key);
    if (e.engineOn) e.synth->blip = 0.35;   // ro ga mot nhip de nghe ngay tieng moi
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [tv reloadData];
    [NSNotificationCenter.defaultCenter postNotificationName:@"PAPresetChanged" object:nil];
}

@end
