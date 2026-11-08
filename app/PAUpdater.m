#import "PAUpdater.h"
#import <UIKit/UIKit.h>

NSString *const PAUpdaterDidChangeNotification = @"PAUpdaterDidChangeNotification";
static NSString *const kRepo = @"https://anhnhadat999.github.io/nda-drive/";
static NSString *const kPackageID = @"com.ndarealty.ndadrive";

@implementation PAUpdater

+ (instancetype)shared {
    static PAUpdater *u; static dispatch_once_t once;
    dispatch_once(&once, ^{ u = [PAUpdater new]; });
    return u;
}

- (NSString *)currentVersion {
    return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0";
}

- (void)checkNow {
    if (_checking) return;
    _checking = YES;
    [NSNotificationCenter.defaultCenter postNotificationName:PAUpdaterDidChangeNotification object:self];
    NSURL *url = [NSURL URLWithString:[kRepo stringByAppendingString:@"Packages"]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSString *latest = nil;
        if (data && !err) {
            NSString *txt = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            // Moi goi la mot khoi cach nhau bang dong trong
            for (NSString *block in [txt componentsSeparatedByString:@"\n\n"]) {
                if ([block rangeOfString:[@"Package: " stringByAppendingString:kPackageID]].location == NSNotFound) continue;
                for (NSString *line in [block componentsSeparatedByString:@"\n"]) {
                    if ([line hasPrefix:@"Version: "]) {
                        NSString *v = [line substringFromIndex:9];
                        if (!latest || [v compare:latest options:NSNumericSearch] == NSOrderedDescending) latest = v;
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_checking = NO;
            self->_lastCheck = [NSDate date];
            if (latest) {
                self->_latestVersion = latest;
                self->_updateAvailable = [latest compare:self.currentVersion options:NSNumericSearch] == NSOrderedDescending;
            }
            [NSNotificationCenter.defaultCenter postNotificationName:PAUpdaterDidChangeNotification object:self];
        });
    }] resume];
}

- (void)open:(NSString *)sileoURL fallback:(NSString *)web {
    UIApplication *app = UIApplication.sharedApplication;
    [app openURL:[NSURL URLWithString:sileoURL] options:@{} completionHandler:^(BOOL ok) {
        if (!ok) [app openURL:[NSURL URLWithString:web] options:@{} completionHandler:nil];
    }];
}

- (void)openUpdateInSileo { [self open:[@"sileo://package/" stringByAppendingString:kPackageID] fallback:kRepo]; }
- (void)openAddSourceInSileo { [self open:[@"sileo://source/" stringByAppendingString:kRepo] fallback:kRepo]; }

@end
