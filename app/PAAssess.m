#import "PAAssess.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PATrial.h"
#import "PALearn.h"

@implementation PAAssess

+ (NSArray<NSDictionary *> *)itemsFor:(PAEngine *)e {
    PAMotion *m = (PAMotion *)e.motion;
    NSMutableArray *a = [NSMutableArray array];
    void (^add)(NSString *, NSString *, int) = ^(NSString *n, NSString *v, int lv) { [a addObject:@{ @"ten": n, @"gia_tri": v, @"muc": @(lv) }]; };

    // Che do + dang ghi
    NSString *mode = e.collectMode ? @"im lặng" : @"có tiếng";
    if (!e.engineOn) add(@"Thu thập dữ liệu", [NSString stringWithFormat:@"chờ xe chạy (%@)", mode], 1);
    else if (m.recording) add(@"Thu thập dữ liệu", [NSString stringWithFormat:@"ĐANG GHI · %@ · %.0f phút", mode, m.tripRows / 600.0], 0);
    else add(@"Thu thập dữ liệu", @"máy nổ nhưng KHÔNG ghi — bật \"Ghi dữ liệu chuyến đi\"", 2);

    // Huong xe
    if (m.calibrated) add(@"Hướng đặt máy", m.calByTurn ? @"đã học (vào cua)" : @"đã học", 0);
    else add(@"Hướng đặt máy", [NSString stringWithFormat:@"đang học %.0f%% — rẽ vài khúc cua", m.calProgress * 100], 1);

    // Cam bien
    if (m.imuHz > 50) add(@"Cảm biến", [NSString stringWithFormat:@"%.0f lần/giây", m.imuHz], 0);
    else if (m.imuHz > 5) add(@"Cảm biến", [NSString stringWithFormat:@"chậm (%.0f/giây)", m.imuHz], 1);
    else add(@"Cảm biến", @"chưa có dữ liệu", 2);

    // GPS
    double acc = m.gpsHAcc;   // do chinh xac vi tri (m)
    if (m.gpsHz >= 0.8 && acc > 0 && acc < 15) add(@"GPS", [NSString stringWithFormat:@"tốt (±%.0f m)", acc], 0);
    else if (m.gpsHz >= 0.5 && acc > 0 && acc < 35) add(@"GPS", [NSString stringWithFormat:@"trung bình (±%.0f m)", acc], 1);
    else add(@"GPS", @"yếu / chưa bắt được", 2);

    // GPS lap (xe gui qua CarPlay)
    double rep = m.gpsRepeatRatio;
    if (rep > 0.5) add(@"Tín hiệu GPS", [NSString stringWithFormat:@"lặp %.0f%% (xe gửi chậm)", rep * 100], 1);

    // Tre loa
    if (e.latencyComp && e.outputLatencyMs > 0)
        add(@"Trễ ra loa", [NSString stringWithFormat:@"%.0f ms (đã bù)", e.outputLatencyMs], e.outputLatencyMs > 700 ? 1 : 0);

    // Ho so da hoc
    PALearn l = m.learned;
    double conf = pal_confidence(&l);
    if (conf > 0.5) add(@"Hồ sơ xe", [NSString stringWithFormat:@"%.0f km đã học", l.distKm], 0);
    else add(@"Hồ sơ xe", [NSString stringWithFormat:@"đang học (%.0f%%)", conf * 100], 1);

    // Thu thap 7 ngay
    NSInteger days = [PATrial daysDone];
    if ([PATrial complete]) add(@"Thu thập 7 ngày", @"ĐỦ — hãy xuất báo cáo", 0);
    else add(@"Thu thập 7 ngày", [NSString stringWithFormat:@"ngày %ld/7 · %.0f km · %ld chuyến", (long)days, [PATrial totalKm], (long)[PATrial totalTrips]], 1);

    return a;
}

+ (NSString *)verdictFor:(PAEngine *)e {
    int worst = 0;
    for (NSDictionary *it in [self itemsFor:e]) worst = MAX(worst, [it[@"muc"] intValue]);
    if (worst == 0) return @"Hệ thống tốt — dữ liệu đang thu thập chuẩn";
    if (worst == 1) return @"Hoạt động — còn vài mục cần hoàn thiện";
    return @"Có vấn đề — xem chi tiết bên dưới";
}

+ (NSArray<NSDictionary *> *)reportItemsFor:(PAEngine *)e {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *it in [self itemsFor:e])
        [a addObject:@{ @"muc": it[@"ten"], @"danh_gia": it[@"gia_tri"], @"trang_thai": @[@"tốt", @"cảnh báo", @"lỗi"][[it[@"muc"] intValue]] }];
    [a addObject:@{ @"tong_ket": [self verdictFor:e] }];
    return a;
}
@end
