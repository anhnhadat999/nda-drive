// Bang mau va phong chu dung chung (giao dien toi, kieu bang dong ho xe ban dem)
#import <UIKit/UIKit.h>

#define PA_BG     [UIColor colorWithRed:0.051 green:0.059 blue:0.071 alpha:1]
#define PA_CARD   [UIColor colorWithRed:0.090 green:0.102 blue:0.122 alpha:1]
#define PA_LINE   [UIColor colorWithRed:0.161 green:0.180 blue:0.212 alpha:1]
#define PA_FG     [UIColor colorWithRed:0.925 green:0.914 blue:0.890 alpha:1]
#define PA_MUTED  [UIColor colorWithRed:0.553 green:0.573 blue:0.608 alpha:1]
#define PA_AMBER  [UIColor colorWithRed:1.000 green:0.690 blue:0.125 alpha:1]
#define PA_RED    [UIColor colorWithRed:1.000 green:0.290 blue:0.239 alpha:1]
#define PA_GREEN  [UIColor colorWithRed:0.290 green:0.820 blue:0.470 alpha:1]

static inline UIFont *PAFont(CGFloat size, UIFontWeight w) {
    UIFont *f = [UIFont systemFontOfSize:size weight:w];
    UIFontDescriptor *d = [f.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return d ? [UIFont fontWithDescriptor:d size:size] : f;
}
