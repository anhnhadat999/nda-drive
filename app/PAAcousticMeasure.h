#import <Foundation/Foundation.h>
#import "PAAcoustic.h"

NS_ASSUME_NONNULL_BEGIN

// Do am hoc khoang xe: phat tieng quet tan so qua loa, thu bang mic (xe qua CarPlay hoac iPhone),
// phan tich ngay tren may. KHONG luu am thanh.
@interface PAAcousticMeasure : NSObject
+ (BOOL)carMicAvailable;
+ (void)runUsingCarMic:(BOOL)carMic progress:(void (^)(NSString *step))progress
                  done:(void (^)(PAAcousticResult r, NSString *_Nullable error))done;
+ (BOOL)loadSaved:(PAAcousticResult *)r;
+ (void)save:(PAAcousticResult)r;
@end

NS_ASSUME_NONNULL_END
