#import <Foundation/Foundation.h>
#import "PASynth.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PAEngineDidUpdateNotification;

// Bo dieu khien chinh: am thanh + GPS + phat hien CarPlay. Chay suot khi app con song (ke ca chay ngam).
@interface PAEngine : NSObject
+ (instancetype)shared;

- (void)boot;                       // goi 1 lan khi app khoi dong (ke ca khoi dong ngam)

@property (nonatomic, readonly) BOOL carPlayConnected;
@property (nonatomic, readonly) BOOL engineOn;
@property (nonatomic, readonly) double gpsSpeedKmh;   // -1 neu chua co
@property (nonatomic, readonly) NSString *locationStatusText;
@property (nonatomic, readonly) NSString *sensorStatusText;   // trang thai bo hop nhat cam bien
@property (nonatomic, readonly) PASynth *synth;

// Cai dat (luu lai tu dong)
@property (nonatomic) BOOL enabled;              // bat/tat Po Ao
@property (nonatomic) BOOL onlyWithCarPlay;      // chi chay khi ket noi CarPlay
@property (nonatomic, copy) NSString *presetKey;
@property (nonatomic) double volume;             // 0..1
@property (nonatomic) double toneAmount;         // 0..1
@property (nonatomic) BOOL popsEnabled;
@property (nonatomic) BOOL shiftPopEnabled;

// Thu khi dung yen
@property (nonatomic) BOOL testMode;             // dung toc do gia lap thay cho GPS
@property (nonatomic) double testSpeedKmh;

- (void)requestLocationPermission;
- (void)manualStart;
- (void)manualStop;
@end

NS_ASSUME_NONNULL_END
