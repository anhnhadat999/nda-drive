#import <UIKit/UIKit.h>
// Xuat bao cao .zip va mo bang chia se (dung chung cho tab Theo doi, Bao cao he thong, Cai dat)
@interface PAExport : NSObject
+ (void)presentFrom:(UIViewController *)vc full:(BOOL)full source:(UIView *)src;
@end
