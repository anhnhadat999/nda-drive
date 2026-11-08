#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Hinh xe nhin ngang, ve bang vec-to: dang than xe CHUNG (khong phai thiet ke, logo hay
// chi tiet nhan dien cua hang nao), mau son rieng cho tung kieu tieng.
@interface PACarView : UIView
@property (nonatomic, copy) NSString *presetKey;
@end

UIColor *PACarPaint(NSString *presetKey);

NS_ASSUME_NONNULL_END
