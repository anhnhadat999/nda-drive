#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, PASec) { SecCar, SecSound, SecLearn, SecRun, SecTest, SecStatus, SecUpdate, SecCount };

// Bang cai dat; co the hien mot nhom muc (dung cho cac trang con trong tab Cai dat)
@interface PASettingsViewController : UITableViewController
- (instancetype)initWithSections:(NSArray<NSNumber *> *)secs title:(NSString *)title;
@end
