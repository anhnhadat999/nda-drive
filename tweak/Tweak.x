// NDADriveLauncher - tweak nho trong SpringBoard:
//  1) Mo ngam app Po Ao sau khi SpringBoard khoi dong (sau khi bam jailbreak / respring)
//  2) Theo doi CarPlay; khi ket noi -> dam bao app dang chay va bao cho app biet
// Tweak KHONG phat am thanh, khong dung GPS -> rat nhe, it rui ro treo SpringBoard.

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>

#define APP_ID @"com.ndarealty.ndadrive"
#define NOTIFY_ON  CFSTR("com.ndarealty.ndadrive.carplay.on")
#define NOTIFY_OFF CFSTR("com.ndarealty.ndadrive.carplay.off")

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)openApplication:(NSString *)bundleID options:(NSDictionary *)options withResult:(void (^)(NSError *error))result;
@end

@interface SBApplication : NSObject
- (id)processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleID;
@end

@interface SpringBoard : UIApplication
@end

@interface CARSessionStatus : NSObject
- (id)currentSession;
@end

static dispatch_queue_t gQueue;
static dispatch_source_t gTimer;
static BOOL gCarPlay = NO;
static CARSessionStatus *gCarStatus = nil;
static NSUInteger gTicks = 0;

static BOOL PAAppRunning(void) {
    SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:APP_ID];
    if (!app || ![app respondsToSelector:@selector(processState)]) return NO;
    id ps = [app processState];
    if (!ps) return NO;
    @try { return [[ps valueForKey:@"running"] boolValue]; } @catch (NSException *e) { return NO; }
}

static void PALaunchApp(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PAAppRunning()) return;
        Class svc = NSClassFromString(@"FBSSystemService");
        if (!svc) return;
        NSString *keySuspended = @"__ActivateSuspended";
        NSString **sym = (NSString **)dlsym(RTLD_DEFAULT, "FBSOpenApplicationOptionKeyActivateSuspended");
        if (sym && *sym) keySuspended = *sym;
        [[svc sharedService] openApplication:APP_ID options:@{ keySuspended: @YES } withResult:^(NSError *error) {
            if (error) NSLog(@"[NDADriveLauncher] Khong mo duoc app: %@", error);
        }];
    });
}

static void PAPost(BOOL on) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), on ? NOTIFY_ON : NOTIFY_OFF, NULL, NULL, true);
}

static BOOL PADetectCarPlay(void) {
    // Cach 1: CarKit (khung rieng cua Apple quan ly phien CarPlay)
    if (!gCarStatus) {
        Class cls = NSClassFromString(@"CARSessionStatus");
        if (cls) gCarStatus = (CARSessionStatus *)[cls new];
    }
    if (gCarStatus && [gCarStatus respondsToSelector:@selector(currentSession)]) {
        id session = [gCarStatus currentSession];
        if (session) return YES;
    }
    // Cach 2: duong ra am thanh dang la loa xe (CarPlay)
    for (AVAudioSessionPortDescription *o in AVAudioSession.sharedInstance.currentRoute.outputs)
        if ([o.portType isEqualToString:AVAudioSessionPortCarAudio]) return YES;
    return NO;
}

static void PAPoll(void) {
    gTicks++;
    BOOL now = PADetectCarPlay();
    if (now != gCarPlay) {
        gCarPlay = now;
        NSLog(@"[NDADriveLauncher] CarPlay %@", now ? @"KET NOI" : @"NGAT");
        if (now) PALaunchApp();
        PAPost(now);
        // nhac lai sau 2 giay de app vua mo kip nhan
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), gQueue, ^{ PAPost(gCarPlay); });
    } else if (gCarPlay && gTicks % 5 == 0) {
        // dang CarPlay: kiem tra app con song moi 15 giay
        PALaunchApp();
        PAPost(YES);
    }
}

static void PAStart(void) {
    dlopen("/System/Library/PrivateFrameworks/CarKit.framework/CarKit", RTLD_LAZY);
    gQueue = dispatch_queue_create("com.ndarealty.ndadrive.launcher", DISPATCH_QUEUE_SERIAL);
    PALaunchApp();
    gTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gQueue);
    dispatch_source_set_timer(gTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 3 * NSEC_PER_SEC, NSEC_PER_SEC / 2);
    dispatch_source_set_event_handler(gTimer, ^{ @autoreleasepool { PAPoll(); } });
    dispatch_resume(gTimer);
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    // doi SpringBoard on dinh roi moi lam viec
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ PAStart(); });
}
%end
