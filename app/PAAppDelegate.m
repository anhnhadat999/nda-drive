#import "PAAppDelegate.h"
#import "PARootViewController.h"
#import "PAEngine.h"

@implementation PAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Khoi dong bo may ngay ca khi app duoc mo ngam (tu tweak hoac tu GPS)
    [PAEngine.shared boot];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[PARootViewController new]];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
