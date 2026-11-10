#import <Foundation/Foundation.h>
@class PAEngine;
// Danh gia he thong truc tiep: dua ra danh sach nhan xet co trang thai (tot/canh bao/loi)
// Dung chung cho man hinh Theo doi (trong app) va CarPlay.
@interface PAAssess : NSObject
+ (NSArray<NSDictionary *> *)itemsFor:(PAEngine *)e;   // moi muc: @{ @"ten", @"gia_tri", @"muc": @(0 tot/1 canh bao/2 loi) }
+ (NSString *)verdictFor:(PAEngine *)e;                // mot dong tong ket
+ (NSArray<NSDictionary *> *)reportItemsFor:(PAEngine *)e;  // ban rut gon cho bao cao (text thuan)
@end
