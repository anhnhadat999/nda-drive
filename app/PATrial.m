#import "PATrial.h"
#define TRIAL_DAYS 7
#define KEY @"trial.v1"

@implementation PATrial

+ (NSMutableDictionary *)st {
    NSDictionary *d = [NSUserDefaults.standardUserDefaults dictionaryForKey:KEY];
    return d ? [d mutableCopy] : [@{ @"days": @[], @"km": @0, @"sec": @0, @"trips": @0 } mutableCopy];
}
+ (void)put:(NSDictionary *)d { [NSUserDefaults.standardUserDefaults setObject:d forKey:KEY]; }

+ (NSString *)today {
    NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = @"yyyy-MM-dd"; f.timeZone = NSTimeZone.localTimeZone;
    return [f stringFromDate:[NSDate date]];
}

+ (void)markToday {
    NSMutableDictionary *d = [self st];
    NSMutableArray *days = [(d[@"days"] ?: @[]) mutableCopy];
    NSString *t = [self today];
    if ([days containsObject:t]) return;
    [days addObject:t]; d[@"days"] = days;
    if (!d[@"start"]) d[@"start"] = @([NSDate date].timeIntervalSince1970);
    [self put:d];
}

+ (void)addDriveKm:(double)km seconds:(double)sec {
    if (sec < 20) return;                       // bo qua chuyen qua ngan
    NSMutableDictionary *d = [self st];
    NSMutableArray *days = [(d[@"days"] ?: @[]) mutableCopy];
    NSString *t = [self today];
    if (![days containsObject:t]) [days addObject:t];
    d[@"days"] = days;
    d[@"km"] = @([d[@"km"] doubleValue] + km);
    d[@"sec"] = @([d[@"sec"] doubleValue] + sec);
    d[@"trips"] = @([d[@"trips"] integerValue] + 1);
    if (!d[@"start"]) d[@"start"] = @([NSDate date].timeIntervalSince1970);
    [self put:d];
}
+ (NSInteger)daysDone { return [(([self st][@"days"]) ?: @[]) count]; }
+ (BOOL)complete { return [self daysDone] >= TRIAL_DAYS; }
+ (double)totalKm { return [[self st][@"km"] doubleValue]; }
+ (double)totalMinutes { return [[self st][@"sec"] doubleValue] / 60.0; }
+ (NSInteger)totalTrips { return [[self st][@"trips"] integerValue]; }
+ (NSDictionary *)summary {
    NSMutableDictionary *d = [self st];
    return @{ @"ngay_da_thu_thap": @([self daysDone]), @"can_du": @(TRIAL_DAYS), @"hoan_thanh": @([self complete]),
              @"tong_km": @(round([self totalKm] * 10) / 10), @"tong_phut": @(round([self totalMinutes])),
              @"so_chuyen": @([self totalTrips]), @"cac_ngay": d[@"days"] ?: @[] };
}
+ (void)reset { [NSUserDefaults.standardUserDefaults removeObjectForKey:KEY]; }
@end
