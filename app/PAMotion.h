#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "PAFusion.h"
#import "PASynth.h"

NS_ASSUME_NONNULL_BEGIN

// Bao boc CoreMotion (gia toc ke, con quay, ap ke) + GPS vao bo loc PAFusion,
// roi day toc do / gia toc / do doc vao bo tao am PASynth 100 lan moi giay.
@interface PAMotion : NSObject
- (instancetype)initWithSynth:(PASynth *)synth;
- (void)start;
- (void)stop;
- (void)addLocation:(CLLocation *)loc;
@property (nonatomic, readonly) BOOL running;
@property (atomic) BOOL feedSynth;            // NO khi dang o che do thu (toc do gia lap)
// Doc de hien thi (cap nhat tren luong chinh ~5 lan/giay)
@property (nonatomic, readonly) double speedKmh, accelMs2, gradePct, quality;
@property (nonatomic, readonly) BOOL calibrated, stationary, gpsOk;
@property (nonatomic, readonly) double calProgress, mountAngleDeg, gpsAccuracy, gpsRawKmh;
@property (atomic) double speedTrim;          // hieu chinh toc do: -0.10..+0.10 (khop dong ho xe)
@property (atomic) double responseScale;      // 0.6 on dinh, 1 can bang, 1.6 nhanh
- (void)resetCalibration;                     // xoa can chinh da luu, hoc lai tu dau
@end

NS_ASSUME_NONNULL_END
