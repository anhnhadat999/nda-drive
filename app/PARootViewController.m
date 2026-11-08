#import "PARootViewController.h"
#import "PAEngine.h"

@implementation PARootViewController {
    UIStackView *_stack;
    UILabel *_carplayLbl, *_gpsLbl, *_engineLbl, *_locLbl;
    UISwitch *_enabledSw, *_onlyCarSw, *_popsSw, *_shiftSw, *_testSw;
    UISlider *_volSl, *_toneSl, *_testSl;
    UILabel *_testVal;
    UIButton *_presetBtn, *_startBtn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"NDA Drive";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.view.tintColor = [UIColor colorWithRed:1.0 green:0.69 blue:0.13 alpha:1];

    UIScrollView *sv = [UIScrollView new];
    sv.translatesAutoresizingMaskIntoConstraints = NO;
    sv.alwaysBounceVertical = YES;
    [self.view addSubview:sv];
    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = 14;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [sv addSubview:_stack];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [sv.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_stack.topAnchor constraintEqualToAnchor:sv.contentLayoutGuide.topAnchor constant:8],
        [_stack.bottomAnchor constraintEqualToAnchor:sv.contentLayoutGuide.bottomAnchor constant:-30],
        [_stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [_stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
    ]];

    PAEngine *e = PAEngine.shared;

    // --- Trang thai ---
    UIStackView *st = [self card:@"TRẠNG THÁI"];
    _carplayLbl = [self valueRow:@"CarPlay" in:st];
    _gpsLbl = [self valueRow:@"Tốc độ GPS" in:st];
    _engineLbl = [self valueRow:@"Động cơ" in:st];
    _locLbl = [self valueRow:@"Quyền vị trí" in:st];
    UIButton *perm = [self button:@"Cấp quyền vị trí (chọn \"Luôn luôn\")" action:@selector(askPermission)];
    [st addArrangedSubview:perm];

    // --- Bat tat ---
    UIStackView *on = [self card:@"HOẠT ĐỘNG"];
    _enabledSw = [self switchRow:@"Bật pô ảo" in:on action:@selector(changed:)];
    _onlyCarSw = [self switchRow:@"Chỉ chạy khi kết nối CarPlay" in:on action:@selector(changed:)];
    [on addArrangedSubview:[self note:@"Cắm CarPlay → tiếng đề máy và nổ máy. Xe chạy → tiếng pô theo tốc độ GPS. Rút CarPlay → tắt máy."]];

    // --- Dong co ---
    UIStackView *en = [self card:@"KIỂU ĐỘNG CƠ"];
    _presetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _presetBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    _presetBtn.titleLabel.numberOfLines = 0;
    _presetBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _presetBtn.showsMenuAsPrimaryAction = YES;
    [self rebuildPresetMenu];
    [en addArrangedSubview:_presetBtn];

    // --- Tinh chinh ---
    UIStackView *tn = [self card:@"TINH CHỈNH"];
    _volSl = [self sliderRow:@"Âm lượng" in:tn action:@selector(changed:)];
    _toneSl = [self sliderRow:@"Độ đanh của pô" in:tn action:@selector(changed:)];
    _popsSw = [self switchRow:@"Nổ lụp bụp khi nhả ga" in:tn action:@selector(changed:)];
    _shiftSw = [self switchRow:@"Tiếng \"bụp\" khi lên số" in:tn action:@selector(changed:)];

    // --- Thu khi dung yen ---
    UIStackView *ts = [self card:@"THỬ KHI ĐỖ XE"];
    _startBtn = [self button:@"Nổ máy thử" action:@selector(toggleTest)];
    [ts addArrangedSubview:_startBtn];
    _testSw = [self switchRow:@"Giả lập tốc độ (không dùng GPS)" in:ts action:@selector(changed:)];
    _testSl = [self sliderRow:@"Tốc độ giả lập" in:ts action:@selector(changed:)];
    _testSl.maximumValue = 220;
    _testVal = [self valueRow:@"Đang đặt" in:ts];
    [ts addArrangedSubview:[self note:@"Kéo thanh tốc độ để nghe sang số. Chỉ dùng khi xe đang đỗ."]];

    _enabledSw.on = e.enabled; _onlyCarSw.on = e.onlyWithCarPlay;
    _volSl.value = e.volume; _toneSl.value = e.toneAmount;
    _popsSw.on = e.popsEnabled; _shiftSw.on = e.shiftPopEnabled;
    _testSw.on = e.testMode; _testSl.value = e.testSpeedKmh;

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refresh) name:PAEngineDidUpdateNotification object:nil];
    [self refresh];
}

#pragma mark - Dung giao dien

- (UIStackView *)card:(NSString *)title {
    UILabel *h = [UILabel new];
    h.text = title;
    h.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    h.textColor = UIColor.secondaryLabelColor;
    UIStackView *inner = [UIStackView new];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 10;
    inner.layoutMarginsRelativeArrangement = YES;
    inner.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(14, 14, 14, 14);
    UIView *bg = [UIView new];
    bg.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    bg.layer.cornerRadius = 12;
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    [inner insertSubview:bg atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [bg.topAnchor constraintEqualToAnchor:inner.topAnchor], [bg.bottomAnchor constraintEqualToAnchor:inner.bottomAnchor],
        [bg.leadingAnchor constraintEqualToAnchor:inner.leadingAnchor], [bg.trailingAnchor constraintEqualToAnchor:inner.trailingAnchor]]];
    [_stack addArrangedSubview:h];
    [_stack setCustomSpacing:6 afterView:h];
    [_stack addArrangedSubview:inner];
    return inner;
}

- (UILabel *)valueRow:(NSString *)name in:(UIStackView *)parent {
    UILabel *l = [UILabel new]; l.text = name;
    UILabel *v = [UILabel new]; v.textColor = UIColor.secondaryLabelColor; v.textAlignment = NSTextAlignmentRight;
    v.numberOfLines = 0;
    v.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightRegular];
    [l setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, v]];
    row.spacing = 12;
    [parent addArrangedSubview:row];
    return v;
}

- (UISwitch *)switchRow:(NSString *)name in:(UIStackView *)parent action:(SEL)sel {
    UILabel *l = [UILabel new]; l.text = name; l.numberOfLines = 0;
    UISwitch *s = [UISwitch new];
    [s addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [s setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[l, s]];
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    [parent addArrangedSubview:row];
    return s;
}

- (UISlider *)sliderRow:(NSString *)name in:(UIStackView *)parent action:(SEL)sel {
    UILabel *l = [UILabel new]; l.text = name;
    l.font = [UIFont systemFontOfSize:15]; l.textColor = UIColor.secondaryLabelColor;
    UISlider *s = [UISlider new];
    [s addTarget:self action:sel forControlEvents:UIControlEventValueChanged];
    [parent addArrangedSubview:l];
    [parent setCustomSpacing:2 afterView:l];
    [parent addArrangedSubview:s];
    return s;
}

- (UIButton *)button:(NSString *)title action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (UILabel *)note:(NSString *)text {
    UILabel *l = [UILabel new];
    l.text = text; l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:13]; l.textColor = UIColor.secondaryLabelColor;
    return l;
}

- (void)rebuildPresetMenu {
    PAEngine *e = PAEngine.shared;
    NSMutableArray *items = [NSMutableArray array];
    NSString *current = @"";
    for (int i = 0; i < PA_PRESET_COUNT; i++) {
        const PAPreset *p = &PA_PRESETS[i];
        NSString *key = @(p->key);
        NSString *name = @(p->name);
        NSString *car = @(p->car);
        BOOL sel = [key isEqualToString:e.presetKey];
        if (sel) current = [NSString stringWithFormat:@"%@\n%@", name, car];
        __weak typeof(self) ws = self;
        UIAction *a = [UIAction actionWithTitle:name image:nil identifier:nil handler:^(__kindof UIAction *act) {
            PAEngine.shared.presetKey = key;
            [ws rebuildPresetMenu];
        }];
        a.subtitle = car;
        a.state = sel ? UIMenuElementStateOn : UIMenuElementStateOff;
        [items addObject:a];
    }
    _presetBtn.menu = [UIMenu menuWithTitle:@"Chọn kiểu động cơ" children:items];
    [_presetBtn setTitle:[current stringByAppendingString:@"  ›"] forState:UIControlStateNormal];
}

#pragma mark - Su kien

- (void)changed:(id)sender {
    PAEngine *e = PAEngine.shared;
    if (sender == _enabledSw) e.enabled = _enabledSw.on;
    else if (sender == _onlyCarSw) e.onlyWithCarPlay = _onlyCarSw.on;
    else if (sender == _volSl) e.volume = _volSl.value;
    else if (sender == _toneSl) e.toneAmount = _toneSl.value;
    else if (sender == _popsSw) e.popsEnabled = _popsSw.on;
    else if (sender == _shiftSw) e.shiftPopEnabled = _shiftSw.on;
    else if (sender == _testSw) e.testMode = _testSw.on;
    else if (sender == _testSl) e.testSpeedKmh = round(_testSl.value);
    [self refresh];
}

- (void)toggleTest {
    PAEngine *e = PAEngine.shared;
    if (e.engineOn) [e manualStop]; else [e manualStart];
    [self refresh];
}

- (void)askPermission { [PAEngine.shared requestLocationPermission]; }

- (void)refresh {
    PAEngine *e = PAEngine.shared;
    PASynth *s = e.synth;
    _carplayLbl.text = e.carPlayConnected ? @"Đã kết nối ✓" : @"Chưa kết nối";
    _gpsLbl.text = e.gpsSpeedKmh < 0 ? @"—" : [NSString stringWithFormat:@"%.0f km/h", e.gpsSpeedKmh];
    NSString *st = @"Tắt";
    if (s->state == PA_STARTING) st = @"Đang đề máy…";
    else if (s->state == PA_RUNNING) st = [NSString stringWithFormat:@"%.0f v/p · số %d · %.0f km/h", s->rpm, s->gear + 1, s->speed];
    else if (s->state == PA_STOPPING) st = @"Đang tắt máy…";
    _engineLbl.text = st;
    _locLbl.text = e.locationStatusText;
    _testVal.text = [NSString stringWithFormat:@"%.0f km/h", e.testSpeedKmh];
    [_startBtn setTitle:(e.engineOn ? @"Tắt máy" : @"Nổ máy thử") forState:UIControlStateNormal];
}

@end
