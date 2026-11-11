// Danh sach xe dien VinFast voi thong so co dinh theo nha san xuat.
// Ban dung san trong app; co the duoc cap nhat tu may chu (profiles.json) qua PAProfiles.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PAVehicle : NSObject
@property (nonatomic, copy) NSString *vid;        // vd "vf7-plus"
@property (nonatomic, copy) NSString *model;      // "VF 7"
@property (nonatomic, copy) NSString *trim;       // "Plus (2 mô-tơ, AWD)"
@property (nonatomic) double hp, kw, weightKg, zeroTo100, torqueNm;
@property (nonatomic, copy) NSString *drive;      // FWD / RWD / AWD
@property (nonatomic) BOOL estimated;             // co so lieu uoc tinh (chua co cong bo chinh thuc)
@property (nonatomic, copy) NSString *preset;     // tieng po goi y
@property (nonatomic, readonly) NSString *title;  // "VF 7 Plus"
@property (nonatomic, readonly) NSString *specLine;
@end

@interface PAVehicles : NSObject
+ (NSArray<PAVehicle *> *)all;                    // ban dung san, ghi de bang du lieu may chu neu co
+ (nullable PAVehicle *)byId:(NSString *)vid;
+ (void)mergeServerList:(NSArray<NSDictionary *> *)list;
@end

NS_ASSUME_NONNULL_END
