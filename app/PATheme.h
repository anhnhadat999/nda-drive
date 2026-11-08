// Bang mau va phong chu dung chung: den sau + vang champagne, phong cach bang dong ho xe cao cap
#import <UIKit/UIKit.h>

#define PA_BG     [UIColor colorWithRed:0.035 green:0.035 blue:0.043 alpha:1]
#define PA_CARD   [UIColor colorWithRed:0.078 green:0.078 blue:0.090 alpha:1]
#define PA_LINE   [UIColor colorWithRed:0.165 green:0.165 blue:0.184 alpha:1]
#define PA_FG     [UIColor colorWithRed:0.949 green:0.937 blue:0.910 alpha:1]
#define PA_MUTED  [UIColor colorWithRed:0.557 green:0.557 blue:0.576 alpha:1]
#define PA_AMBER  [UIColor colorWithRed:0.831 green:0.698 blue:0.416 alpha:1]   /* vang champagne */
#define PA_RED    [UIColor colorWithRed:0.898 green:0.282 blue:0.302 alpha:1]
#define PA_GREEN  [UIColor colorWithRed:0.239 green:0.839 blue:0.549 alpha:1]

static inline UIFont *PAFont(CGFloat size, UIFontWeight w) { return [UIFont systemFontOfSize:size weight:w]; }
static inline UIFont *PAMono(CGFloat size, UIFontWeight w) { return [UIFont monospacedDigitSystemFontOfSize:size weight:w]; }
