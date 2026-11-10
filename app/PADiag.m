#import "PADiag.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PALog.h"
#import "PAAcousticMeasure.h"
#import "PAZip.h"
#include <errno.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#include <sys/utsname.h>
#include <signal.h>
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>

static int gCrashFD = -1;

static void PASignalHandler(int sig) {
    if (gCrashFD >= 0) {
        const char *msg = "THOAT DOT NGOT - tin hieu ";
        write(gCrashFD, msg, strlen(msg));
        char num[8]; int n = 0, s = sig; char tmp[8]; do { tmp[n++] = '0' + s % 10; s /= 10; } while (s && n < 7);
        for (int i = 0; i < n; i++) num[i] = tmp[n - 1 - i];
        write(gCrashFD, num, n); write(gCrashFD, "\n", 1);
        void *bt[64]; int c = backtrace(bt, 64);
        backtrace_symbols_fd(bt, c, gCrashFD);
        fsync(gCrashFD);
    }
    signal(sig, SIG_DFL);
    raise(sig);
}

static void PAExceptionHandler(NSException *e) {
    if (gCrashFD >= 0) {
        NSString *s = [NSString stringWithFormat:@"NGOAI LE: %@ - %@\n%@\n", e.name, e.reason, [e.callStackSymbols componentsJoinedByString:@"\n"]];
        NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
        write(gCrashFD, d.bytes, d.length); fsync(gCrashFD);
    }
}

@implementation PADiag {
    NSMutableDictionary<NSString *, NSNumber *> *_session;
    NSMutableDictionary<NSString *, NSMutableArray *> *_stats;   // key -> [sum, count, min, max]
    NSDate *_sessionStart;
    dispatch_queue_t _q;
}

+ (instancetype)shared { static PADiag *d; static dispatch_once_t o; dispatch_once(&o, ^{ d = [PADiag new]; }); return d; }

- (instancetype)init {
    if ((self = [super init])) {
        _session = [NSMutableDictionary dictionary];
        _stats = [NSMutableDictionary dictionary];
        _sessionStart = [NSDate date];
        _q = dispatch_queue_create("com.ndarealty.ndadrive.diag", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSURL *)docs { return PADataDir(); }
- (NSURL *)crashDir { NSURL *u = [[self docs] URLByAppendingPathComponent:@"crashes" isDirectory:YES]; [NSFileManager.defaultManager createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil]; return u; }

- (void)installCrashHandlers {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *marker = [[self docs] URLByAppendingPathComponent:@"crash-current.txt"];
    // Lan chay truoc co ghi loi -> luu lai thanh tep rieng
    NSData *old = [NSData dataWithContentsOfURL:marker];
    if (old.length > 0) {
        NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = @"yyyyMMdd_HHmmss";
        NSURL *dst = [[self crashDir] URLByAppendingPathComponent:[NSString stringWithFormat:@"crash_%@.txt", [df stringFromDate:[NSDate date]]]];
        [old writeToURL:dst atomically:YES];
        [self bumpTotal:@"crash_detected"];
        PALog(@"Phat hien lan chay truoc bi thoat dot ngot -> da luu %@", dst.lastPathComponent);
    }
    // Phien truoc khong ket thuc gon (co the bi he thong dong hoac thoat)
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if ([d boolForKey:@"diag.running"] && old.length == 0) [self bumpTotal:@"unclean_exit"];
    [d setBool:YES forKey:@"diag.running"];
    [@"" writeToURL:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    gCrashFD = open(marker.path.fileSystemRepresentation, O_WRONLY | O_APPEND);
    int sigs[] = { SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE, SIGTRAP };
    for (int i = 0; i < 6; i++) signal(sigs[i], PASignalHandler);
    NSSetUncaughtExceptionHandler(PAExceptionHandler);
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        [d setBool:NO forKey:@"diag.running"];
    }];
    [self bump:@"app_launch"];
}

- (void)bumpTotal:(NSString *)e {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *t = [[d dictionaryForKey:@"diag.total"] mutableCopy] ?: [NSMutableDictionary dictionary];
    t[e] = @([t[e] longLongValue] + 1);
    [d setObject:t forKey:@"diag.total"];
}

- (void)bump:(NSString *)e {
    dispatch_async(_q, ^{
        self->_session[e] = @([self->_session[e] longLongValue] + 1);
        dispatch_async(dispatch_get_main_queue(), ^{ [self bumpTotal:e]; });
    });
}

- (void)noteValue:(double)v forKey:(NSString *)k {
    if (isnan(v) || isinf(v)) return;
    dispatch_async(_q, ^{
        NSMutableArray *s = self->_stats[k];
        if (!s) { s = [@[@0.0, @0, @(v), @(v)] mutableCopy]; self->_stats[k] = s; }
        s[0] = @([s[0] doubleValue] + v); s[1] = @([s[1] longLongValue] + 1);
        if (v < [s[2] doubleValue]) s[2] = @(v);
        if (v > [s[3] doubleValue]) s[3] = @(v);
    });
}

static NSString *deviceModel(void) { struct utsname u; uname(&u); return @(u.machine); }

- (NSArray *)installedPackages {
    // Doc danh sach goi da cai (neu ung dung duoc phep doc); chi lay ten + phien ban
    NSString *s = [NSString stringWithContentsOfFile:@"/var/jb/var/lib/dpkg/status" encoding:NSUTF8StringEncoding error:nil];
    if (!s) return @[@"(không đọc được danh sách gói)"];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *blk in [s componentsSeparatedByString:@"\n\n"]) {
        NSString *pkg = nil, *ver = nil, *st = nil;
        for (NSString *l in [blk componentsSeparatedByString:@"\n"]) {
            if ([l hasPrefix:@"Package: "]) pkg = [l substringFromIndex:9];
            else if ([l hasPrefix:@"Version: "]) ver = [l substringFromIndex:9];
            else if ([l hasPrefix:@"Status: "]) st = l;
        }
        if (pkg && [st containsString:@"installed"] && ![pkg hasPrefix:@"lib"]) [out addObject:[NSString stringWithFormat:@"%@ %@", pkg, ver ?: @""]];
    }
    return out;
}

- (void)buildReport:(void (^)(NSURL *, NSString *))done {
    // Lay so lieu tren luong chinh (trang thai UI/engine), dong goi tren luong nen
    PAEngine *e = PAEngine.shared;
    PAMotion *m = (PAMotion *)e.motion;
    PALearn l = m.learned;
    NSMutableArray *learnBins = [NSMutableArray array];
    for (int i = 0; i < PAL_BINS; i++) [learnBins addObject:@{ @"acc_p95": @(l.accP95[i]), @"acc_peak": @(l.accPeak[i]), @"brake_p95": @(l.brkP95[i]) }];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSDictionary *mainInfo = @{
        @"generated_at": [NSISO8601DateFormatter new] ? [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]] : @"",
        @"app_version": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
        @"app_build": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"",
        @"device": deviceModel(), @"ios": UIDevice.currentDevice.systemVersion,
        @"rootless_jb": @([NSFileManager.defaultManager fileExistsAtPath:@"/var/jb"]),
        @"session_minutes": @(round(-[_sessionStart timeIntervalSinceNow] / 6) / 10),
        @"settings": @{ @"enabled": @(e.enabled), @"auto_carplay": @(e.onlyWithCarPlay), @"preset": e.presetKey ?: @"",
                        @"volume": @(e.volume), @"tone": @(e.toneAmount), @"pops": @(e.popsEnabled), @"shift_pop": @(e.shiftPopEnabled),
                        @"auto_volume": @(e.autoVolume), @"rear_fx": @(e.rearEffect), @"rear_amount": @(e.rearAmount),
                        @"growl": @(e.growl), @"crisp": @(e.crispness), @"sub": @(e.subAmount), @"latency_comp": @(e.latencyComp),
                        @"learn": @(e.learnEnabled), @"record": @(e.recordEnabled), @"speed_trim": @(e.speedTrim), @"response": @(e.responseMode), @"test_mode": @(e.testMode) },
        @"permissions": @{ @"location": e.locationStatusText ?: @"" },
        @"state_now": @{ @"engine_on": @(e.engineOn), @"carplay": @(e.carPlayConnected), @"sensor_source": m.sourceName ?: @"", @"imu_hz": @(m.imuHz), @"gps_hz": @(m.gpsHz),
                         @"imu_age_s": @(m.imuAge), @"gps_age_s": @(m.gpsAge), @"gps_acc": @(m.gpsAccuracy), @"calibrated": @(m.calibrated),
                         @"mount_angle_deg": @(m.mountAngleDeg), @"fallback_gps_only": @(m.gpsOnlyFallback), @"last_error": m.lastError ?: @"" },
        @"learned": @{ @"bins": learnBins, @"acc_median": @(l.accMed), @"distance_km": @(l.distKm), @"samples": @(l.samples),
                       @"sport": @(pal_sport(&l)), @"confidence": @(pal_confidence(&l)), @"zero_to_100_s": @(pal_zero_to_100(&l)) },
        @"calibration_saved": @{ @"theta": [d objectForKey:@"cal.theta"] ?: [NSNull null] },
        @"events_total": [d dictionaryForKey:@"diag.total"] ?: @{},
        @"acoustic": ^NSDictionary *{
            NSMutableDictionary *last = [([NSUserDefaults.standardUserDefaults dictionaryForKey:@"acoustic.last"] ?: @{}) mutableCopy];
            last[@"routes_tried"] = [NSUserDefaults.standardUserDefaults arrayForKey:@"acoustic.routes"] ?: @[];
            PAAcousticResult ar; if (![PAAcousticMeasure loadSaved:&ar]) return @{ @"measured": @NO, @"last_attempt": last };
            NSMutableArray *bands = [NSMutableArray array], *corr = [NSMutableArray array];
            for (int b = 0; b < PAA_BANDS; b++) [bands addObject:@{ @"hz": @(PAA_BAND_HZ[b]), @"db": @(round(ar.respDb[b] * 10) / 10), @"abs_db": @(round(ar.absDb[b] * 10) / 10) }];
            for (int o = 0; o < PAA_OCT; o++) [corr addObject:@{ @"hz": @(PAA_OCT_HZ[o]), @"db": @(round(ar.corrDb[o] * 10) / 10) }];
            return @{ @"measured": @YES, @"latency_ms": @(ar.latencyMs), @"snr_db": @(ar.snrDb), @"noise_dbfs": @(ar.noiseDbfs), @"bands": bands, @"correction": corr, @"correction_on": @(e.acousticCorrection), @"last_attempt": last };
        }(),
    };
    dispatch_async(_q, ^{
        NSMutableDictionary *rep = [mainInfo mutableCopy];
        rep[@"events_session"] = [self->_session copy];
        NSMutableDictionary *st = [NSMutableDictionary dictionary];
        [self->_stats enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSMutableArray *s, BOOL *stop) {
            long long c = [s[1] longLongValue];
            st[k] = @{ @"avg": @(c ? [s[0] doubleValue] / c : 0), @"min": s[2], @"max": s[3], @"count": @(c) };
        }];
        rep[@"stats_session"] = st;
        rep[@"packages"] = [self installedPackages];
        rep[@"storage_dir"] = PADataDir().path ?: @"";

        NSFileManager *fm = NSFileManager.defaultManager;
        NSDateFormatter *df = [NSDateFormatter new]; df.dateFormat = @"yyyyMMdd_HHmmss";
        NSString *name = [NSString stringWithFormat:@"NDADrive-bao-cao-%@", [df stringFromDate:[NSDate date]]];
        NSURL *dir = [PATempDir() URLByAppendingPathComponent:name isDirectory:YES];
        [fm removeItemAtURL:dir error:nil];
        [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *js = [NSJSONSerialization dataWithJSONObject:rep options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
        [js writeToURL:[dir URLByAppendingPathComponent:@"bao-cao.json"] atomically:YES];
        NSURL *log = PALogFileURL();
        if ([fm fileExistsAtPath:log.path]) [fm copyItemAtURL:log toURL:[dir URLByAppendingPathComponent:@"nhat-ky.txt"] error:nil];
        // loi thoat app
        NSURL *cd = [dir URLByAppendingPathComponent:@"loi-thoat-app" isDirectory:YES];
        [fm createDirectoryAtURL:cd withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSURL *u in [fm contentsOfDirectoryAtURL:[self crashDir] includingPropertiesForKeys:nil options:0 error:nil]) [fm copyItemAtURL:u toURL:[cd URLByAppendingPathComponent:u.lastPathComponent] error:nil];
        // chuyen di: moi tom tat + 3 tep CSV gan nhat
        NSURL *td = [dir URLByAppendingPathComponent:@"chuyen-di" isDirectory:YES];
        [fm createDirectoryAtURL:td withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray *trips = [[fm contentsOfDirectoryAtURL:[PAMotion tripsFolder] includingPropertiesForKeys:nil options:0 error:nil]
                          sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) { return [b.lastPathComponent compare:a.lastPathComponent]; }];
        int csvN = 0;
        for (NSURL *u in trips) {
            if ([u.pathExtension isEqualToString:@"json"]) [fm copyItemAtURL:u toURL:[td URLByAppendingPathComponent:u.lastPathComponent] error:nil];
            else if ([u.pathExtension isEqualToString:@"csv"] && csvN < 3) { [fm copyItemAtURL:u toURL:[td URLByAppendingPathComponent:u.lastPathComponent] error:nil]; csvN++; }
        }
        [@"Gửi tệp .zip này cho Claude trong khung chat để phân tích và cải thiện NDA Drive.\nKhông chứa tọa độ GPS, tên hay số điện thoại.\n" writeToURL:[dir URLByAppendingPathComponent:@"DOC-TOI.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];

        // Nen thanh .zip bang bo nen rieng (PAZip + zlib). Co che "ForUploading" cua iOS
        // khong hoat dong voi app cai qua jailbreak (bao "Khong the mo tep").
        __block NSURL *zipOut = nil; __block NSString *errStr = nil;
        NSMutableArray<NSURL *> *outDirs = [NSMutableArray array];
        NSURL *dd = [self docs]; if (dd) [outDirs addObject:[dd URLByAppendingPathComponent:@"bao-cao" isDirectory:YES]];
        [outDirs addObject:[NSURL fileURLWithPath:@"/var/mobile/Documents/NDADrive-bao-cao" isDirectory:YES]];
        [outDirs addObject:[PATempDir() URLByAppendingPathComponent:@"bao-cao-xuat" isDirectory:YES]];
        for (NSURL *exp in outDirs) {
            [fm createDirectoryAtURL:exp withIntermediateDirectories:YES attributes:nil error:nil];
            for (NSURL *oldz in [fm contentsOfDirectoryAtURL:exp includingPropertiesForKeys:nil options:0 error:nil]) [fm removeItemAtURL:oldz error:nil];
            NSURL *dst = [exp URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"zip"]];
            PAZip *z = pazip_open(dst.fileSystemRepresentation);
            if (!z) { errStr = [NSString stringWithFormat:@"Không ghi được vào %@ (lỗi %d)", exp.path, errno]; continue; }
            int ok = 1, nFiles = 0;
            NSDirectoryEnumerator *en = [fm enumeratorAtURL:dir includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 errorHandler:nil];
            NSString *base = dir.URLByStandardizingPath.path;
            for (NSURL *u in en) {
                NSNumber *isDir = nil; [u getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
                if (isDir.boolValue) continue;
                NSString *full = u.URLByStandardizingPath.path;
                NSString *rel = [full hasPrefix:base] ? [full substringFromIndex:base.length + 1] : u.lastPathComponent;
                NSData *data = [NSData dataWithContentsOfURL:u] ?: [NSData data];
                if (!pazip_add(z, [name stringByAppendingPathComponent:rel].UTF8String, data.bytes, data.length)) { ok = 0; break; }
                nFiles++;
            }
            if (!pazip_close(z)) ok = 0;
            if (ok && nFiles > 0) { zipOut = dst; errStr = nil; break; }
            errStr = [NSString stringWithFormat:@"Lỗi ghi tệp nén (%d tệp, lỗi %d)", nFiles, errno];
            [fm removeItemAtURL:dst error:nil];
        }
        [fm removeItemAtURL:dir error:nil];
        if (zipOut) {   // ban sao du phong mo duoc bang Filza neu bang chia se loi
            NSURL *pub = [NSURL fileURLWithPath:@"/var/mobile/Documents/NDADrive-bao-cao" isDirectory:YES];
            if (![zipOut.path hasPrefix:pub.path]) {
                [fm createDirectoryAtURL:pub withIntermediateDirectories:YES attributes:nil error:nil];
                for (NSURL *oldz in [fm contentsOfDirectoryAtURL:pub includingPropertiesForKeys:nil options:0 error:nil]) [fm removeItemAtURL:oldz error:nil];
                [fm copyItemAtURL:zipOut toURL:[pub URLByAppendingPathComponent:zipOut.lastPathComponent] error:nil];
            }
        }
        PALog(@"Xuat bao cao: %@ (thu muc du lieu %@)", zipOut ? zipOut.path : errStr, PADataDir().path);
        dispatch_async(dispatch_get_main_queue(), ^{ done(zipOut, zipOut ? nil : (errStr ?: @"Không tạo được tệp")); });
    });
}

@end
