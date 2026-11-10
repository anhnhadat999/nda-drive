#import "PAAppDelegate.h"
#import "PARootViewController.h"
#import "PACarsViewController.h"
#import "PADashboardViewController.h"
#import "PASettingsViewController.h"
#import "PAEngine.h"
#import "PAUpdater.h"
#import "PATheme.h"
#import "PADiag.h"

@implementation PAAppDelegate

static UINavigationController *nav(UIViewController *vc) {
    UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:vc];
    n.navigationBar.prefersLargeTitles = YES;
    n.tabBarItem = vc.tabBarItem;
    return n;
}

- (void)applyAppearance {
    UINavigationBarAppearance *na = [UINavigationBarAppearance new];
    [na configureWithOpaqueBackground];
    na.backgroundColor = PA_BG;
    na.shadowColor = UIColor.clearColor;
    na.titleTextAttributes = @{ NSForegroundColorAttributeName: PA_FG };
    na.largeTitleTextAttributes = @{ NSForegroundColorAttributeName: PA_FG, NSFontAttributeName: PAFont(34, UIFontWeightHeavy) };
    UINavigationBar.appearance.standardAppearance = na;
    UINavigationBar.appearance.scrollEdgeAppearance = na;
    UINavigationBar.appearance.compactAppearance = na;
    UINavigationBar.appearance.tintColor = PA_AMBER;

    UITabBarAppearance *ta = [UITabBarAppearance new];
    [ta configureWithOpaqueBackground];
    ta.backgroundColor = PA_CARD;
    ta.shadowColor = PA_LINE;
    UITabBar.appearance.standardAppearance = ta;
    UITabBar.appearance.scrollEdgeAppearance = ta;
    UITabBar.appearance.tintColor = PA_AMBER;
    UITabBar.appearance.unselectedItemTintColor = PA_MUTED;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [PADiag.shared installCrashHandlers];   // bat loi thoat app + dem su kien (bao cao cho Claude)
    // Khoi dong bo may ngay ca khi app duoc mo ngam (tu tweak hoac tu GPS)
    [PAEngine.shared boot];
    [self applyAppearance];
    UITabBarController *tb = [UITabBarController new];
    tb.viewControllers = @[ nav([PARootViewController new]), nav([PADashboardViewController new]), nav([PACarsViewController new]), nav([PASettingsViewController new]) ];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.window.tintColor = PA_AMBER;
    self.window.rootViewController = tb;
    [self.window makeKeyAndVisible];
    [PAUpdater.shared checkNow];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Mo lai app: kiem tra ban moi neu lan kiem tra truoc da hon 1 gio
    NSDate *last = PAUpdater.shared.lastCheck;
    if (!last || -last.timeIntervalSinceNow > 3600) [PAUpdater.shared checkNow];
}

@end
