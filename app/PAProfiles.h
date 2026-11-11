// Ho so chuan theo tung dong xe, dang tren GitHub Pages (profiles.json).
// App tu tai, cap nhat danh sach xe va ap dung bo tinh chinh tieng cho dung xe dang chon.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
extern NSString *const PAProfilesDidChangeNotification;

@interface PAProfiles : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) BOOL checking;
@property (nonatomic, readonly, nullable) NSDate *lastCheck;
@property (nonatomic, readonly) NSInteger serverRev;          // so hieu ban ho so tren may chu
@property (nonatomic, readonly, nullable) NSString *lastError;
- (void)checkNow;
- (nullable NSDictionary *)tuningFor:(NSString *)vid;         // bo tinh chinh cho xe (hoac "default")
- (NSInteger)appliedRevFor:(NSString *)vid;
- (BOOL)applyFor:(NSString *)vid force:(BOOL)force;            // ap dung vao PAEngine; YES neu co thay doi
- (NSString *)statusText;
@end
NS_ASSUME_NONNULL_END
