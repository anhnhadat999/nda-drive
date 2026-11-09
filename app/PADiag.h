#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Chan doan on dinh: dem su kien, thong ke chat luong cam bien, bat loi thoat app,
// va dong goi "Bao cao cho Claude" (1 tep .zip) de nguoi dung tu gui.
@interface PADiag : NSObject
+ (instancetype)shared;
- (void)installCrashHandlers;                 // goi som nhat khi app khoi dong
- (void)bump:(NSString *)event;               // dem 1 su kien (phien nay + tong cong)
- (void)noteValue:(double)v forKey:(NSString *)key;   // thong ke: trung binh / nho nhat / lon nhat
- (void)buildReport:(void (^)(NSURL *_Nullable zip, NSString *_Nullable error))done;
@end

NS_ASSUME_NONNULL_END
