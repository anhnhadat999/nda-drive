#import "PACarsViewController.h"
#import "PACarArt.h"
#import "PAEngine.h"
#import "PATheme.h"

// ---------- O hien thi mot xe ----------
@interface PACarCell : UICollectionViewCell
@property (nonatomic, strong) PACarView *car;
@property (nonatomic, strong) UILabel *name, *sub, *spec;
@property (nonatomic, strong) UIImageView *check;
@end

@implementation PACarCell
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentView.backgroundColor = PA_CARD;
        self.contentView.layer.cornerRadius = 16;
        self.contentView.layer.borderWidth = 1.5;
        self.contentView.layer.borderColor = PA_LINE.CGColor;
        _car = [PACarView new];
        _name = [UILabel new]; _name.font = PAFont(16, UIFontWeightBold); _name.textColor = PA_FG; _name.adjustsFontSizeToFitWidth = YES; _name.minimumScaleFactor = .75;
        _sub = [UILabel new]; _sub.font = PAFont(12, UIFontWeightMedium); _sub.textColor = PA_MUTED; _sub.numberOfLines = 2;
        _spec = [UILabel new]; _spec.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold]; _spec.textColor = PA_AMBER;
        _check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
        _check.tintColor = PA_AMBER;
        for (UIView *v in @[_car, _name, _sub, _spec, _check]) { v.translatesAutoresizingMaskIntoConstraints = NO; [self.contentView addSubview:v]; }
        UIView *cv = self.contentView;
        [NSLayoutConstraint activateConstraints:@[
            [_car.topAnchor constraintEqualToAnchor:cv.topAnchor constant:6],
            [_car.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:6],
            [_car.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-6],
            [_car.heightAnchor constraintEqualToAnchor:cv.widthAnchor multiplier:0.48],
            [_name.topAnchor constraintEqualToAnchor:_car.bottomAnchor constant:2],
            [_name.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:12],
            [_name.trailingAnchor constraintEqualToAnchor:_check.leadingAnchor constant:-4],
            [_check.centerYAnchor constraintEqualToAnchor:_name.centerYAnchor],
            [_check.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
            [_check.widthAnchor constraintEqualToConstant:20], [_check.heightAnchor constraintEqualToConstant:20],
            [_sub.topAnchor constraintEqualToAnchor:_name.bottomAnchor constant:2],
            [_sub.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
            [_sub.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
            [_spec.topAnchor constraintEqualToAnchor:_sub.bottomAnchor constant:4],
            [_spec.leadingAnchor constraintEqualToAnchor:_name.leadingAnchor],
            [_spec.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-10],
        ]];
    }
    return self;
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [UIView animateWithDuration:.15 animations:^{ self.transform = h ? CGAffineTransformMakeScale(.97, .97) : CGAffineTransformIdentity; }]; }
@end

// ---------- Tieu de nhom ----------
@interface PAHeader : UICollectionReusableView
@property (nonatomic, strong) UILabel *label;
@end
@implementation PAHeader
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _label = [UILabel new];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]]];
    }
    return self;
}
@end

// ---------- Man hinh ----------
@implementation PACarsViewController {
    NSArray<NSNumber *> *_groups[2];
}

- (instancetype)init {
    UICollectionViewFlowLayout *l = [UICollectionViewFlowLayout new];
    l.sectionInset = UIEdgeInsetsMake(4, 16, 18, 16);
    l.minimumInteritemSpacing = 12;
    l.minimumLineSpacing = 12;
    l.headerReferenceSize = CGSizeMake(100, 38);
    if ((self = [super initWithCollectionViewLayout:l])) {
        self.title = @"Chọn xe";
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Chọn xe" image:[UIImage systemImageNamed:@"car.2.fill"] tag:1];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.collectionView.backgroundColor = PA_BG;
    [self.collectionView registerClass:PACarCell.class forCellWithReuseIdentifier:@"car"];
    [self.collectionView registerClass:PAHeader.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"h"];
    NSMutableArray *p = [NSMutableArray array], *o = [NSMutableArray array];
    for (int i = 0; i < PA_PRESET_COUNT; i++) {
        if ([@(PA_PRESETS[i].car) hasPrefix:@"Porsche"]) [p addObject:@(i)]; else [o addObject:@(i)];
    }
    _groups[0] = p; _groups[1] = o;
    [NSNotificationCenter.defaultCenter addObserver:self.collectionView selector:@selector(reloadData) name:@"PAPresetChanged" object:nil];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)cv { return 2; }
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return _groups[s].count; }

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewLayout *)l sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat w = floor((cv.bounds.size.width - 16 * 2 - 12) / 2);
    return CGSizeMake(w, w * 0.48 + 96);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)cv viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)ip {
    PAHeader *h = [cv dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"h" forIndexPath:ip];
    NSString *t = ip.section == 0 ? @"PORSCHE" : @"CÁC HÃNG KHÁC";
    h.label.attributedText = [[NSAttributedString alloc] initWithString:t attributes:@{ NSFontAttributeName: PAFont(13, UIFontWeightBold), NSForegroundColorAttributeName: PA_MUTED, NSKernAttributeName: @1.5 }];
    return h;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    PACarCell *c = [cv dequeueReusableCellWithReuseIdentifier:@"car" forIndexPath:ip];
    int i = _groups[ip.section][ip.item].intValue;
    const PAPreset *p = &PA_PRESETS[i];
    NSString *key = @(p->key);
    c.car.presetKey = key;
    c.name.text = @(p->name);
    NSString *car = @(p->car);
    NSRange dot = [car rangeOfString:@" · "];
    c.sub.text = dot.location != NSNotFound ? [car substringFromIndex:dot.location + dot.length] : car;
    c.spec.text = [NSString stringWithFormat:@"%d xi-lanh · %.0f v/p%@", p->cyl, p->redline, p->turbo ? @" · turbo" : @""];
    BOOL sel = [key isEqualToString:PAEngine.shared.presetKey];
    c.check.hidden = !sel;
    c.contentView.layer.borderColor = (sel ? PA_AMBER : PA_LINE).CGColor;
    c.contentView.backgroundColor = sel ? [PA_AMBER colorWithAlphaComponent:0.10] : PA_CARD;
    return c;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    int i = _groups[ip.section][ip.item].intValue;
    PAEngine *e = PAEngine.shared;
    e.presetKey = @(PA_PRESETS[i].key);
    if (e.engineOn) e.synth->blip = 0.35;   // ro ga mot nhip de nghe ngay tieng moi
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [NSNotificationCenter.defaultCenter postNotificationName:@"PAPresetChanged" object:nil];
}

@end
