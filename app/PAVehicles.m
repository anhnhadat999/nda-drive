#import "PAVehicles.h"

@implementation PAVehicle
- (NSString *)title { return [NSString stringWithFormat:@"%@ %@", self.model, [self.trim componentsSeparatedByString:@" ("].firstObject]; }
- (NSString *)specLine {
    return [NSString stringWithFormat:@"%.0f mã lực (%.0f kW) · %.0f Nm · %@ · %.0f kg · 0–100 %.1f s%@",
            self.hp, self.kw, self.torqueNm, self.drive, self.weightKg, self.zeroTo100, self.estimated ? @" (ước tính)" : @""];
}
@end

@implementation PAVehicles
static NSMutableArray<PAVehicle *> *gList;

static PAVehicle *V(NSString *vid, NSString *model, NSString *trim, double hp, double kw, double nm, NSString *drv, double kg, double t100, BOOL est, NSString *preset) {
    PAVehicle *v = [PAVehicle new];
    v.vid = vid; v.model = model; v.trim = trim; v.hp = hp; v.kw = kw; v.torqueNm = nm; v.drive = drv; v.weightKg = kg; v.zeroTo100 = t100; v.estimated = est; v.preset = preset;
    return v;
}

// Nguon: cong bo VinFast + trang tong hop thong so (2025-2026). Trong luong / 0-100 danh dau "uoc tinh" khi chua co so chinh thuc.
// Sai so se duoc sua dan qua profiles.json tren may chu ma khong can cap nhat app.
+ (void)load0 {
    gList = [@[
        V(@"vf3",       @"VF 3",  @"Tiêu chuẩn (1 mô-tơ, RWD)",   43, 32, 110, @"RWD", 1190, 14.0, YES, @"i4t"),
        V(@"vf5",       @"VF 5",  @"Plus (1 mô-tơ, FWD)",        134, 100, 135, @"FWD", 1360, 10.9, YES, @"i4t"),
        V(@"vfe34",     @"VF e34",@"Tiêu chuẩn (1 mô-tơ, FWD)",  147, 110, 242, @"FWD", 1490, 9.0, YES, @"i5"),
        V(@"vf6-eco",   @"VF 6",  @"Eco (1 mô-tơ, FWD)",         174, 130, 250, @"FWD", 1960, 9.5, YES, @"i5"),
        V(@"vf6-plus",  @"VF 6",  @"Plus (1 mô-tơ, FWD)",        201, 150, 310, @"FWD", 2020, 8.9, YES, @"i6"),
        V(@"vf7-eco",   @"VF 7",  @"Eco (1 mô-tơ, FWD)",         201, 150, 310, @"FWD", 2085, 9.5, NO,  @"i6"),
        V(@"vf7-plus",  @"VF 7",  @"Plus (2 mô-tơ, AWD)",        349, 260, 500, @"AWD", 2205, 5.8, NO,  @"amg"),
        V(@"vf8-eco",   @"VF 8",  @"Eco (2 mô-tơ, AWD)",         349, 260, 500, @"AWD", 2460, 5.9, YES, @"amg"),
        V(@"vf8-plus",  @"VF 8",  @"Plus (2 mô-tơ, AWD)",        402, 300, 620, @"AWD", 2600, 5.5, NO,  @"v8"),
        V(@"vf9-eco",   @"VF 9",  @"Eco (2 mô-tơ, AWD)",         402, 300, 620, @"AWD", 2830, 6.5, NO,  @"v8"),
        V(@"vf9-plus",  @"VF 9",  @"Plus (2 mô-tơ, AWD)",        402, 300, 620, @"AWD", 2900, 6.5, YES, @"v12"),
    ] mutableCopy];
    NSArray *cached = [NSUserDefaults.standardUserDefaults arrayForKey:@"vehicles.server"];
    if (cached) [self applyServer:cached];
}

+ (NSArray<PAVehicle *> *)all {
    static dispatch_once_t once; dispatch_once(&once, ^{ [self load0]; });
    return gList;
}

+ (PAVehicle *)byId:(NSString *)vid {
    for (PAVehicle *v in [self all]) if ([v.vid isEqualToString:vid]) return v;
    return nil;
}

+ (void)applyServer:(NSArray *)list {
    for (NSDictionary *d in list) {
        if (![d isKindOfClass:NSDictionary.class] || ![d[@"id"] isKindOfClass:NSString.class]) continue;
        PAVehicle *v = nil;
        for (PAVehicle *x in gList) if ([x.vid isEqualToString:d[@"id"]]) v = x;
        if (!v) { v = V(d[@"id"], d[@"model"] ?: d[@"id"], d[@"trim"] ?: @"", 0, 0, 0, @"", 0, 0, YES, @"amg"); [gList addObject:v]; }
        if ([d[@"model"] isKindOfClass:NSString.class]) v.model = d[@"model"];
        if ([d[@"trim"] isKindOfClass:NSString.class]) v.trim = d[@"trim"];
        if ([d[@"hp"] isKindOfClass:NSNumber.class]) v.hp = [d[@"hp"] doubleValue];
        if ([d[@"kw"] isKindOfClass:NSNumber.class]) v.kw = [d[@"kw"] doubleValue];
        if ([d[@"nm"] isKindOfClass:NSNumber.class]) v.torqueNm = [d[@"nm"] doubleValue];
        if ([d[@"kg"] isKindOfClass:NSNumber.class]) v.weightKg = [d[@"kg"] doubleValue];
        if ([d[@"t100"] isKindOfClass:NSNumber.class]) v.zeroTo100 = [d[@"t100"] doubleValue];
        if ([d[@"drive"] isKindOfClass:NSString.class]) v.drive = d[@"drive"];
        if ([d[@"est"] isKindOfClass:NSNumber.class]) v.estimated = [d[@"est"] boolValue];
        if ([d[@"preset"] isKindOfClass:NSString.class]) v.preset = d[@"preset"];
    }
}

+ (void)mergeServerList:(NSArray *)list {
    [self all];
    [self applyServer:list];
    [NSUserDefaults.standardUserDefaults setObject:list forKey:@"vehicles.server"];
}
@end
