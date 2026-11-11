#import "PAExport.h"
#import "PADiag.h"

@implementation PAExport
+ (void)alert:(UIViewController *)vc title:(NSString *)t msg:(NSString *)m {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:t message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

+ (void)presentFrom:(UIViewController *)vc full:(BOOL)full source:(UIView *)src {
    PADiag.shared.fullExport = full;
    UIAlertController *wait = [UIAlertController alertControllerWithTitle:@"Đang đóng gói báo cáo…"
        message:full ? @"Toàn bộ chuyến đi, nhật ký, đánh giá hệ thống." : @"Nhật ký, đánh giá hệ thống, 3 chuyến gần nhất." preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:wait animated:YES completion:^{
        [PADiag.shared buildReport:^(NSURL *zip, NSString *err) {
            [wait dismissViewControllerAnimated:YES completion:^{
                if (!zip) { [self alert:vc title:@"Không tạo được báo cáo" msg:err]; return; }
                UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[zip] applicationActivities:nil];
                av.popoverPresentationController.sourceView = src ?: vc.view;
                av.completionWithItemsHandler = ^(UIActivityType t, BOOL ok, NSArray *items, NSError *e) {
                    if (e) [self alert:vc title:@"Chia sẻ bị lỗi" msg:[NSString stringWithFormat:@"Tệp báo cáo vẫn đã được lưu. Mở Filza, vào /var/mobile/Documents/NDADrive-bao-cao để gửi tệp .zip.\n(%@)", e.localizedDescription]];
                };
                [vc presentViewController:av animated:YES completion:nil];
            }];
        }];
    }];
}
@end
