#import "PAReportViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PAAssess.h"
#import "PATrial.h"
#import "PADiag.h"
#import "PAExport.h"
#import "PAVehicles.h"
#import "PAProfiles.h"
#import "PAUpdater.h"
#import "PATheme.h"
#import <UIKit/UIKit.h>

// Bao cao he thong: tu kiem tra toan bo app + du lieu, va xuat bao cao cho ban sau
@implementation PAReportViewController { NSArray *_assess; NSArray<NSArray *> *_sys; NSTimer *_t; }

- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Báo cáo hệ thống"; return self; }

- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor = PA_BG; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self refresh]; _t = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(refresh) userInfo:nil repeats:YES]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_t invalidate]; _t = nil; }

static NSString *fmtBytes(double b) { return b > 1e9 ? [NSString stringWithFormat:@"%.1f GB", b / 1e9] : [NSString stringWithFormat:@"%.0f MB", b / 1e6]; }

- (void)refresh {
    PAEngine *e = PAEngine.shared; PAMotion *m = (PAMotion *)e.motion;
    _assess = [PAAssess itemsFor:e];
    // kiem tra he thong: {ten, gia tri, muc 0/1/2}
    NSMutableArray *s = [NSMutableArray array];
    PAVehicle *v = [PAVehicles byId:e.vehicleId];
    [s addObject:@[@"Phiên bản app", PAUpdater.shared.updateAvailable ? [NSString stringWithFormat:@"%@ → có bản %@", PAUpdater.shared.currentVersion, PAUpdater.shared.latestVersion] : PAUpdater.shared.currentVersion, @(PAUpdater.shared.updateAvailable ? 1 : 0)]];
    [s addObject:@[@"Xe đang lái", v ? v.title : @"Xe khác (tự nhập)", @0]];
    [s addObject:@[@"Người lái thử", e.testerTag.length ? e.testerTag : @"chủ xe", @0]];
    [s addObject:@[@"Hồ sơ chuẩn theo xe", [PAProfiles.shared statusText], @([PAProfiles.shared tuningFor:e.vehicleId] ? 0 : 1)]];
    NSString *mode = e.collectMode ? @"Theo dõi im lặng" : (e.enabled ? @"Pô ảo" : @"Tắt");
    [s addObject:@[@"Chế độ", e.engineOn ? [mode stringByAppendingString:@" · đang chạy"] : mode, @(e.pipelineOn ? 0 : 2)]];
    [s addObject:@[@"Vị trí", e.locationStatusText, @([e.locationStatusText containsString:@"✓"] ? 0 : 2)]];
    [s addObject:@[@"Cảm biến", m.running ? [NSString stringWithFormat:@"IMU %.0f Hz · GPS %.1f Hz", m.imuHz, m.gpsHz] : @"chưa chạy", @(m.running && m.imuHz > 20 ? 0 : (m.running ? 1 : 2))]];
    UIDevice *d = UIDevice.currentDevice; d.batteryMonitoringEnabled = YES;
    NSString *bat = d.batteryLevel >= 0 ? [NSString stringWithFormat:@"%.0f%%%@", d.batteryLevel * 100, d.batteryState == UIDeviceBatteryStateCharging || d.batteryState == UIDeviceBatteryStateFull ? @" · đang sạc" : @""] : @"—";
    [s addObject:@[@"Pin", bat, @(d.batteryLevel >= 0 && d.batteryLevel < 0.2 && d.batteryState == UIDeviceBatteryStateUnplugged ? 1 : 0)]];
    NSProcessInfoThermalState th = NSProcessInfo.processInfo.thermalState;
    [s addObject:@[@"Nhiệt độ máy", @[@"bình thường", @"hơi ấm", @"nóng", @"rất nóng"][th], @(th >= NSProcessInfoThermalStateSerious ? 2 : (th == NSProcessInfoThermalStateFair ? 1 : 0))]];
    NSDictionary *fs = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    double freeB = [fs[NSFileSystemFreeSize] doubleValue];
    [s addObject:@[@"Bộ nhớ trống", fmtBytes(freeB), @(freeB < 1e9 ? 1 : 0)]];
    [s addObject:@[@"Dữ liệu 7 ngày", [NSString stringWithFormat:@"%ld/7 ngày · %.0f km · %ld chuyến", (long)[PATrial daysDone], [PATrial totalKm], (long)[PATrial totalTrips]], @([PATrial complete] ? 0 : 1)]];
    NSInteger crashes = [PADiag.shared crashCount];
    [s addObject:@[@"Lỗi thoát app", crashes ? [NSString stringWithFormat:@"%ld lần (gửi báo cáo để sửa)", (long)crashes] : @"không có", @(crashes ? 2 : 0)]];
    _sys = s;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : (s == 1 ? _sys.count : _assess.count); }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Xuất báo cáo", @"Kiểm tra hệ thống", @"Đánh giá khi chạy"][s]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 0) return @"Báo cáo gồm: thông số xe, người lái thử, kết quả kiểm tra hệ thống, nhật ký, bộ đếm sự kiện, thống kê từng chuyến (tốc độ, gia tốc, số, vòng tua, chất lượng GPS/cảm biến, pin, nhiệt độ máy). Không chứa tọa độ, tên thật hay số điện thoại. Gửi tệp .zip cho Claude để làm bản cập nhật tiếp theo.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.backgroundColor = PA_CARD; c.textLabel.textColor = PA_FG; c.detailTextLabel.textColor = PA_MUTED;
    c.detailTextLabel.numberOfLines = 2; c.detailTextLabel.adjustsFontSizeToFitWidth = YES; c.detailTextLabel.minimumScaleFactor = 0.7;
    if (ip.section == 0) {
        c.textLabel.text = ip.row == 0 ? @"Xuất báo cáo gọn" : @"Xuất TOÀN BỘ dữ liệu";
        c.detailTextLabel.text = ip.row == 0 ? @"3 chuyến gần nhất" : [NSString stringWithFormat:@"%ld chuyến", (long)[PATrial totalTrips]];
        c.imageView.image = [UIImage systemImageNamed:ip.row == 0 ? @"doc.zipper" : @"externaldrive.fill"]; c.imageView.tintColor = PA_AMBER;
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    NSString *name, *val; int lv;
    if (ip.section == 1) { NSArray *r = _sys[ip.row]; name = r[0]; val = r[1]; lv = [r[2] intValue]; }
    else { NSDictionary *it = _assess[ip.row]; name = it[@"ten"]; val = it[@"gia_tri"]; lv = [it[@"muc"] intValue]; }
    c.textLabel.text = name; c.detailTextLabel.text = val;
    c.imageView.image = [UIImage systemImageNamed:lv == 0 ? @"checkmark.circle.fill" : (lv == 1 ? @"exclamationmark.circle.fill" : @"xmark.octagon.fill")];
    c.imageView.tintColor = lv == 0 ? PA_GREEN : (lv == 1 ? PA_AMBER : PA_RED);
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == 0) [PAExport presentFrom:self full:ip.row == 1 source:[tv cellForRowAtIndexPath:ip]];
}
@end
