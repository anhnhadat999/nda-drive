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
@property (nonatomic, readonly) double outputLatencyMs;   // do tre tu app toi loa (iOS bao)
@property (nonatomic) BOOL latencyComp;                 // bu do tre loa bang du doan

// Cai dat (luu lai tu dong)
@property (nonatomic) BOOL enabled;              // bat/tat Po Ao
@property (nonatomic) BOOL onlyWithCarPlay;      // chi chay khi ket noi CarPlay
@property (nonatomic, copy) NSString *presetKey;
@property (nonatomic) double volume;             // 0..1
@property (nonatomic) double toneAmount;         // 0..1
@property (nonatomic) BOOL popsEnabled;
@property (nonatomic) BOOL shiftPopEnabled;
@property (nonatomic) BOOL autoVolume;           // tu tang am luong theo toc do
@property (nonatomic) BOOL rearEffect;
@property (nonatomic) double rearAmount;
@property (nonatomic) double subAmount;           // muc rung sub gam ghe 0..1
@property (nonatomic) double growl;               // do gan / uy luc 0..1
@property (nonatomic) double crispness;           // do don 0..1
@property (nonatomic) double car0to100;           // thoi gian 0-100 km/h cua xe that (giay)
@property (nonatomic) double carHP;               // ma luc xe that
@property (nonatomic) double carWeight;           // trong luong xe (kg)
@property (nonatomic) double interior;            // 0..1 giong ngoi trong xe
@property (nonatomic) double mechanical;          // 0..1 tieng co khi
@property (nonatomic) BOOL collectMode;           // thu thap du lieu IM LANG (khong phat tieng po)
@property (nonatomic, readonly) double perfKneeKmh; // nguong gioi han cong suat (hien thi)
@property (nonatomic) BOOL acousticCorrection;   // ap dung bu khoang xe tu ket qua do
- (void)pauseForMeasurement;
- (void)resumeAfterMeasurement;
- (void)reloadAcoustic;         // cuong do cam giac phia sau 0..1
@property (nonatomic) BOOL learnEnabled;
@property (nonatomic) BOOL recordEnabled;        // ghi lich su chuyen di (CSV)         // hoc thich nghi theo xe va cach lai           // hieu ung tieng vong tu phia sau xe
@property (nonatomic) double speedTrim;          // -0.10..+0.10
@property (nonatomic) NSInteger responseMode;    // 0 on dinh, 1 can bang, 2 nhanh
@property (nonatomic, readonly) id motion;       // PAMotion (so lieu can chinh)

// Thu khi dung yen
@property (nonatomic) BOOL testMode;             // dung toc do gia lap thay cho GPS
@property (nonatomic) double testSpeedKmh;

- (void)requestLocationPermission;
- (void)manualStart;
- (void)manualStop;
@end

NS_ASSUME_NONNULL_END
