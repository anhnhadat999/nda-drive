#import "PALearnViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PATheme.h"

// Ho so xe da hoc: do boc theo dai toc do, luc phanh, phong cach lai, muc do tin cay
@implementation PALearnViewController { NSTimer *_t; }

- (instancetype)init { if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) self.title = @"Hồ sơ xe đã học"; return self; }
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor = PA_BG; self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; __weak typeof(self) ws = self; _t = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t) { [ws.tableView reloadData]; }]; [self.tableView reloadData]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_t invalidate]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { static const NSInteger n[4] = {4, 5, 2, 1}; return (s >= 0 && s < 4) ? n[s] : 0; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @[@"Tổng quan", @"Độ bốc theo tốc độ", @"Phanh & cách lái", @""][s]; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return @"Ứng dụng tự học từ mỗi chuyến đi: xe của bạn bốc đến đâu ở từng dải tốc độ, phanh mạnh cỡ nào và bạn lái êm hay thể thao. Tiếng pô dùng hồ sơ này để \"đạp hết ga\" trên xe bạn mới gào hết cỡ, còn chạy nhẹ thì tiếng êm. Chỉ học khi đã học hướng xe và GPS tốt. Mọi dữ liệu nằm trên iPhone.";
        case 1: return @"Số đo là gia tốc mạnh nhất thường gặp (m/s²). Lái càng nhiều, số càng sát với xe thật.";
        case 2: return @"Lái thể thao: hộp số ảo giữ số lâu hơn, gào ở vòng tua cao. Lái êm: sang số sớm, tiếng trầm và mượt.";
        case 3: return @"Dùng khi đổi sang xe khác hoặc muốn học lại từ đầu.";
    }
    return nil;
}

- (UITableViewCell *)cell:(NSString *)t detail:(NSString *)d color:(UIColor *)c {
    UITableViewCell *x = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    x.backgroundColor = PA_CARD; x.selectionStyle = UITableViewCellSelectionStyleNone;
    x.textLabel.text = t; x.textLabel.textColor = PA_FG;
    x.detailTextLabel.text = d; x.detailTextLabel.textColor = c ?: PA_MUTED; x.detailTextLabel.font = PAMono(16, UIFontWeightMedium);
    return x;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    PAMotion *m = (PAMotion *)PAEngine.shared.motion;
    PALearn l = m.learned;
    double conf = pal_confidence(&l);
    switch (ip.section) {
        case 0:
            if (ip.row == 0) return [self cell:@"Mức độ đã học" detail:[NSString stringWithFormat:@"%.0f%%", conf * 100] color:conf >= 1 ? PA_GREEN : PA_AMBER];
            if (ip.row == 1) return [self cell:@"Quãng đường đã học" detail:[NSString stringWithFormat:@"%.1f km", l.distKm] color:nil];
            if (ip.row == 2) return [self cell:@"0–100 km/h ước tính" detail:[NSString stringWithFormat:@"%.1f giây", pal_zero_to_100(&l)] color:PA_AMBER];
            return [self cell:@"Đang áp dụng cho tiếng pô" detail:(PAEngine.shared.learnEnabled && conf > 0.05 ? @"Có ✓" : (PAEngine.shared.learnEnabled ? @"Chưa đủ dữ liệu" : @"Tắt")) color:nil];
        case 1: {
            NSArray *names = @[@"0–20 km/h", @"20–50 km/h", @"50–80 km/h", @"80–110 km/h", @"Trên 110 km/h"];
            double v = fmax(l.accPeak[ip.row], l.accP95[ip.row]);
            return [self cell:names[ip.row] detail:[NSString stringWithFormat:@"%.2f m/s²", v] color:nil];
        }
        case 2:
            if (ip.row == 0) {
                double b = 0; for (int i = 0; i < PAL_BINS; i++) b = fmax(b, l.brkP95[i]);
                return [self cell:@"Phanh mạnh nhất thường gặp" detail:[NSString stringWithFormat:@"%.2f m/s²", b] color:nil];
            } else {
                double s = pal_sport(&l);
                NSString *txt = s < 0.33 ? @"Êm ái" : (s < 0.66 ? @"Cân bằng" : @"Thể thao");
                return [self cell:@"Phong cách lái" detail:[NSString stringWithFormat:@"%@ · %.0f%%", txt, s * 100] color:PA_AMBER];
            }
        default: {
            UITableViewCell *c = [self cell:@"Xóa hồ sơ và học lại" detail:nil color:nil];
            c.textLabel.textColor = PA_RED; c.selectionStyle = UITableViewCellSelectionStyleDefault;
            return c;
        }
    }
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 3) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Xóa hồ sơ đã học?" message:@"Ứng dụng sẽ học lại từ đầu trong các chuyến đi tới." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [(PAMotion *)PAEngine.shared.motion resetLearning];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
