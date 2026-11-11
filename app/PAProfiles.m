#import "PAProfiles.h"
#import "PAVehicles.h"
#import "PAEngine.h"
#import "PALog.h"
#import "PADiag.h"

NSString *const PAProfilesDidChangeNotification = @"PAProfilesDidChangeNotification";
static NSString *const kURL = @"https://raw.githubusercontent.com/anhnhadat999/nda-drive/gh-pages/profiles.json";

@implementation PAProfiles { NSDictionary *_data; }

+ (instancetype)shared { static PAProfiles *p; static dispatch_once_t o; dispatch_once(&o, ^{ p = [PAProfiles new]; }); return p; }

- (instancetype)init {
    if ((self = [super init])) {
        NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:@"profiles.json"];
        if (d) _data = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (![_data isKindOfClass:NSDictionary.class]) _data = nil;
        _lastCheck = [NSUserDefaults.standardUserDefaults objectForKey:@"profiles.lastCheck"];
    }
    return self;
}

- (NSInteger)serverRev { return [_data[@"rev"] integerValue]; }

- (void)post { dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:PAProfilesDidChangeNotification object:self]; }); }

- (void)checkNow {
    if (_checking) return;
    _checking = YES; [self post];
    NSURLRequest *rq = [NSURLRequest requestWithURL:[NSURL URLWithString:kURL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    [[NSURLSession.sharedSession dataTaskWithRequest:rq completionHandler:^(NSData *data, NSURLResponse *r, NSError *err) {
        NSDictionary *js = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_checking = NO;
            self->_lastCheck = [NSDate date];
            [NSUserDefaults.standardUserDefaults setObject:self->_lastCheck forKey:@"profiles.lastCheck"];
            if (![js isKindOfClass:NSDictionary.class]) {
                self->_lastError = err.localizedDescription ?: @"không đọc được hồ sơ";
                [PADiag.shared bump:@"profiles_fail"];
            } else {
                self->_lastError = nil;
                self->_data = js;
                [NSUserDefaults.standardUserDefaults setObject:data forKey:@"profiles.json"];
                if ([js[@"vehicles"] isKindOfClass:NSArray.class]) [PAVehicles mergeServerList:js[@"vehicles"]];
                PAEngine *e = PAEngine.shared;
                if (e.autoProfile) [self applyFor:e.vehicleId force:NO];
                PALog(@"Ho so may chu: ban %ld", (long)self.serverRev);
                [PADiag.shared bump:@"profiles_ok"];
            }
            [self post];
        });
    }] resume];
}

- (NSDictionary *)tuningFor:(NSString *)vid {
    NSDictionary *t = _data[@"tuning"];
    if (![t isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *x = t[vid];
    if (![x isKindOfClass:NSDictionary.class]) x = t[@"default"];
    return [x isKindOfClass:NSDictionary.class] ? x : nil;
}

- (NSInteger)appliedRevFor:(NSString *)vid { return [NSUserDefaults.standardUserDefaults integerForKey:[@"profiles.applied." stringByAppendingString:vid]]; }

- (BOOL)applyFor:(NSString *)vid force:(BOOL)force {
    NSDictionary *t = [self tuningFor:vid];
    if (!t) return NO;
    NSInteger rev = [t[@"rev"] integerValue];
    if (!force && rev <= [self appliedRevFor:vid]) return NO;
    PAEngine *e = PAEngine.shared;
    double (^num)(NSString *, double) = ^double(NSString *k, double def) { id v = t[k]; return [v isKindOfClass:NSNumber.class] ? fmin(1, fmax(0, [v doubleValue])) : def; };
    e.growl = num(@"growl", e.growl);
    e.crispness = num(@"crisp", e.crispness);
    e.interior = num(@"interior", e.interior);
    e.mechanical = num(@"mech", e.mechanical);
    e.subAmount = num(@"sub", e.subAmount);
    e.toneAmount = num(@"tone", e.toneAmount);
    if ([t[@"preset"] isKindOfClass:NSString.class] && [t[@"setPreset"] boolValue]) e.presetKey = t[@"preset"];
    [NSUserDefaults.standardUserDefaults setInteger:rev forKey:[@"profiles.applied." stringByAppendingString:vid]];
    PALog(@"Ap dung ho so %@ ban %ld", vid, (long)rev);
    [PADiag.shared bump:@"profile_applied"];
    [self post];
    return YES;
}

- (NSString *)statusText {
    if (_checking) return @"Đang kiểm tra…";
    NSString *vid = PAEngine.shared.vehicleId;
    NSDictionary *t = [self tuningFor:vid];
    if (!_data) return _lastError ? @"Chưa tải được (kiểm tra mạng)" : @"Chưa tải";
    if (!t) return [NSString stringWithFormat:@"Máy chủ bản %ld · chưa có hồ sơ cho xe này", (long)self.serverRev];
    return [NSString stringWithFormat:@"Hồ sơ bản %ld · đã áp dụng %ld", (long)[t[@"rev"] integerValue], (long)[self appliedRevFor:vid]];
}
@end
