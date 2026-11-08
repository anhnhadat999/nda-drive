#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PAUpdaterDidChangeNotification;

// Kiem tra ban moi tren nguon Sileo cua NDA Drive va mo Sileo de cap nhat.
@interface PAUpdater : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSString *currentVersion;
@property (nonatomic, readonly, nullable) NSString *latestVersion;
@property (nonatomic, readonly) BOOL updateAvailable;
@property (nonatomic, readonly) BOOL checking;
@property (nonatomic, readonly, nullable) NSDate *lastCheck;
- (void)checkNow;
- (void)openUpdateInSileo;
- (void)openAddSourceInSileo;
@end

NS_ASSUME_NONNULL_END
