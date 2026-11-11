#import <Foundation/Foundation.h>
// Theo doi giai doan thu nghiem 7 ngay: so ngay co lai xe, tong km, tong thoi gian, so chuyen.
@interface PATrial : NSObject
+ (void)addDriveKm:(double)km seconds:(double)sec;   // goi khi ket thuc moi chuyen
+ (void)markToday;           // goi khi dang lai (>= 1 phut du lieu): tinh ngay ngay ca khi app bi tat giua chung
+ (NSInteger)daysDone;        // so ngay (lich) khac nhau da thu thap
+ (BOOL)complete;             // da du 7 ngay
+ (double)totalKm;
+ (double)totalMinutes;
+ (NSInteger)totalTrips;
+ (NSDictionary *)summary;    // de dua vao bao cao / man hinh
+ (void)reset;
@end
