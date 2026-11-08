#import "PACarsViewController.h"
#import "PAEngine.h"
#import "PATheme.h"

// Danh sach chon xe: chi ten xe + thong so, kieu bang nhom chuan iOS
@implementation PACarsViewController {
    NSArray<NSNumber *> *_groups[2];
}

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.title = @"Chọn xe";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Chọn xe" image:[UIImage systemImageNamed:@"car.fill"] tag:1];
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
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Porsche" : @"Các hãng khác"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return s == 1 ? @"Âm thanh được tổng hợp mô phỏng theo chất tiếng của từng kiểu động cơ, không phải bản ghi âm từ xe thật." : nil;
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
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%d xi-lanh · %.0f v/p%@", subtitleOf(p), p->cyl, p->redline, p->turbo ? @" · turbo" : @""];
    c.detailTextLabel.numberOfLines = 2;
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
