#import "PATripsViewController.h"
#import "PAMotion.h"
#import "PATheme.h"

// Lich su chuyen di: moi chuyen la 1 tep CSV (10 mau/giay) + tep JSON tom tat
@implementation PATripsViewController { NSArray<NSDictionary *> *_trips; }

- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Lịch sử chuyến đi"; return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = PA_BG;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareAll:)];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self load]; }

- (void)load {
    NSURL *dir = [PAMotion tripsFolder];
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:dir includingPropertiesForKeys:nil options:0 error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSURL *u in files) {
        if (![u.pathExtension isEqualToString:@"csv"]) continue;
        NSData *d = [NSData dataWithContentsOfURL:[u URLByAppendingPathExtension:@"json"]];
        NSDictionary *j = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
        [out addObject:@{ @"url": u, @"sum": j ?: @{} }];
    }
    _trips = [out sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [[b[@"url"] lastPathComponent] compare:[a[@"url"] lastPathComponent]]; }];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return MAX(1, (NSInteger)_trips.count); }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return @"Mỗi lần nổ máy, app ghi 10 mẫu/giây: tốc độ GPS và tốc độ đã hợp nhất, gia tốc, con quay, độ dốc, vòng tua, số, độ đạp ga. Chạm vào một chuyến để gửi tệp (CSV mở được bằng Excel). Nút chia sẻ góc trên gửi tất cả. Giữ tối đa 40 chuyến gần nhất.";
}

static NSString *dur(double s) { int m = (int)(s / 60), x = (int)s % 60; return m >= 60 ? [NSString stringWithFormat:@"%dh%02d", m / 60, m % 60] : [NSString stringWithFormat:@"%d:%02d", m, x]; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = PA_CARD;
    if (_trips.count == 0) {
        c.textLabel.text = @"Chưa có chuyến nào"; c.textLabel.textColor = PA_MUTED; c.selectionStyle = UITableViewCellSelectionStyleNone;
        c.detailTextLabel.text = @"Bấm NỔ MÁY hoặc kết nối CarPlay rồi lái thử."; c.detailTextLabel.textColor = PA_MUTED;
        return c;
    }
    NSDictionary *t = _trips[ip.row], *s = t[@"sum"];
    NSDate *d = s[@"start"] ? [NSDate dateWithTimeIntervalSince1970:[s[@"start"] doubleValue]] : nil;
    NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = @"dd/MM/yyyy · HH:mm";
    c.textLabel.text = d ? [df stringFromDate:d] : [t[@"url"] lastPathComponent];
    c.textLabel.textColor = PA_FG; c.textLabel.font = PAFont(16, UIFontWeightMedium);
    c.detailTextLabel.text = s.count ? [NSString stringWithFormat:@"%.1f km · %@ · tối đa %.0f km/h · tăng tốc %.1f / phanh %.1f m/s²",
        [s[@"distance_km"] doubleValue], dur([s[@"duration_s"] doubleValue]), [s[@"vmax_kmh"] doubleValue], [s[@"accel_max_ms2"] doubleValue], [s[@"brake_max_ms2"] doubleValue]] : @"Đang ghi…";
    c.detailTextLabel.textColor = PA_MUTED; c.detailTextLabel.numberOfLines = 2; c.detailTextLabel.font = PAMono(12, UIFontWeightRegular);
    c.accessoryView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"]];
    c.accessoryView.tintColor = PA_AMBER;
    return c;
}

- (void)share:(NSArray *)items from:(UIView *)v {
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    av.popoverPresentationController.sourceView = v;
    [self presentViewController:av animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (_trips.count == 0) return;
    NSURL *u = _trips[ip.row][@"url"];
    NSMutableArray *items = [NSMutableArray arrayWithObject:u];
    NSURL *j = [u URLByAppendingPathExtension:@"json"];
    if ([NSFileManager.defaultManager fileExistsAtPath:j.path]) [items addObject:j];
    [self share:items from:[tv cellForRowAtIndexPath:ip]];
}

- (void)shareAll:(id)sender {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *t in _trips) {
        [items addObject:t[@"url"]];
        NSURL *j = [t[@"url"] URLByAppendingPathExtension:@"json"];
        if ([NSFileManager.defaultManager fileExistsAtPath:j.path]) [items addObject:j];
    }
    if (items.count) [self share:items from:self.view];
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return _trips.count > 0; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)st forRowAtIndexPath:(NSIndexPath *)ip {
    if (st != UITableViewCellEditingStyleDelete) return;
    NSURL *u = _trips[ip.row][@"url"];
    [NSFileManager.defaultManager removeItemAtURL:u error:nil];
    [NSFileManager.defaultManager removeItemAtURL:[u URLByAppendingPathExtension:@"json"] error:nil];
    [self load];
}

@end
