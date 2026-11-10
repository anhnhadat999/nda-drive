#import "PADashboardViewController.h"
#import "PAEngine.h"
#import "PAMotion.h"
#import "PASynth.h"
#import "PAAssess.h"
#import "PATrial.h"
#import "PATheme.h"

// Dong ho toc do + vong tua ve bang CoreGraphics
@interface PADashGauge : UIView
@property (nonatomic) double speed, rpm, redline, load; @property (nonatomic) int gear; @property (nonatomic) BOOL running;
@end
@implementation PADashGauge
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, cx = W/2, cy = H*0.56, rad = fmin(W,H)*0.42;
    CGFloat a0 = M_PI*0.75, a1 = M_PI*2.25;   // 135° -> 405°
    // vanh vong tua
    CGContextSetLineWidth(c, 10); CGContextSetLineCap(c, kCGLineCapRound);
    [PA_LINE setStroke];
    CGContextAddArc(c, cx, cy, rad, a0, a1, 0); CGContextStrokePath(c);
    double rn = self.redline > 0 ? fmin(1, self.rpm/self.redline) : 0;
    UIColor *rc = rn > 0.85 ? PA_RED : PA_AMBER;
    [rc setStroke];
    CGContextAddArc(c, cx, cy, rad, a0, a0 + (a1-a0)*rn, 0); CGContextStrokePath(c);
    // vach
    [PA_MUTED setStroke]; CGContextSetLineWidth(c, 1.5);
    for (int i=0;i<=8;i++){ double a=a0+(a1-a0)*i/8.0; CGContextMoveToPoint(c, cx+cos(a)*(rad-16), cy+sin(a)*(rad-16)); CGContextAddLineToPoint(c, cx+cos(a)*(rad-6), cy+sin(a)*(rad-6)); }
    CGContextStrokePath(c);
    // so lon o giua = toc do
    NSString *sp = [NSString stringWithFormat:@"%.0f", self.speed];
    UIFont *bf = [UIFont monospacedDigitSystemFontOfSize:rad*0.62 weight:UIFontWeightThin];
    NSDictionary *ba = @{ NSFontAttributeName: bf, NSForegroundColorAttributeName: PA_FG };
    CGSize bs = [sp sizeWithAttributes:ba];
    [sp drawAtPoint:CGPointMake(cx-bs.width/2, cy-bs.height*0.6) withAttributes:ba];
    NSDictionary *ua = @{ NSFontAttributeName: PAFont(15, UIFontWeightMedium), NSForegroundColorAttributeName: PA_MUTED };
    [@"km/h" drawAtPoint:CGPointMake(cx-16, cy+bs.height*0.32) withAttributes:ua];
    // vong tua + so o duoi
    NSString *rl = [NSString stringWithFormat:@"%.0f v/p", self.rpm];
    NSDictionary *ra = @{ NSFontAttributeName: PAMono(14, UIFontWeightSemibold), NSForegroundColorAttributeName: rc };
    [rl drawAtPoint:CGPointMake(cx-[rl sizeWithAttributes:ra].width/2, cy+rad*0.5) withAttributes:ra];
    NSString *gs = self.running ? (self.gear <= 0 ? @"N" : [NSString stringWithFormat:@"%d", self.gear]) : @"–";
    NSDictionary *ga = @{ NSFontAttributeName: PAFont(22, UIFontWeightBold), NSForegroundColorAttributeName: PA_AMBER };
    [[@"số " stringByAppendingString:gs] drawAtPoint:CGPointMake(cx-24, cy-rad-6) withAttributes:@{ NSFontAttributeName: PAFont(16, UIFontWeightSemibold), NSForegroundColorAttributeName: PA_AMBER }];
    (void)ga;
}
@end

@interface PADashRing : UIView
@property (nonatomic) double frac; @property (nonatomic, copy) NSString *big, *small;
@end
@implementation PADashRing
- (void)drawRect:(CGRect)r {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W=self.bounds.size.width,H=self.bounds.size.height,cx=W/2,cy=H/2,rad=fmin(W,H)/2-8;
    CGContextSetLineWidth(c,8); CGContextSetLineCap(c,kCGLineCapRound);
    [PA_LINE setStroke]; CGContextAddArc(c,cx,cy,rad,-M_PI_2,-M_PI_2+2*M_PI,0); CGContextStrokePath(c);
    [(self.frac>=1?PA_GREEN:PA_AMBER) setStroke];
    CGContextAddArc(c,cx,cy,rad,-M_PI_2,-M_PI_2+2*M_PI*fmin(1,self.frac),0); CGContextStrokePath(c);
    NSDictionary *ba=@{NSFontAttributeName:PAFont(rad*0.7,UIFontWeightBold),NSForegroundColorAttributeName:PA_FG};
    CGSize bs=[self.big sizeWithAttributes:ba]; [self.big drawAtPoint:CGPointMake(cx-bs.width/2,cy-bs.height*0.62) withAttributes:ba];
    NSDictionary *sa=@{NSFontAttributeName:PAFont(11,UIFontWeightMedium),NSForegroundColorAttributeName:PA_MUTED};
    CGSize ss=[self.small sizeWithAttributes:sa]; [self.small drawAtPoint:CGPointMake(cx-ss.width/2,cy+bs.height*0.18) withAttributes:sa];
}
@end

@implementation PADashboardViewController {
    PADashGauge *_gauge; PADashRing *_ring; UIView *_loadBar, *_loadFill; UILabel *_verdict; UIStackView *_assess;
    UISwitch *_collectSw; UILabel *_collectLbl; NSTimer *_t;
}

- (instancetype)init { if ((self=[super init])) { self.title=@"Theo dõi"; self.tabBarItem=[[UITabBarItem alloc] initWithTitle:@"Theo dõi" image:[UIImage systemImageNamed:@"gauge.high"] tag:3]; } return self; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PA_BG;
    UIScrollView *sc=[UIScrollView new]; sc.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:sc];
    UIStackView *st=[UIStackView new]; st.axis=UILayoutConstraintAxisVertical; st.spacing=14; st.translatesAutoresizingMaskIntoConstraints=NO; [sc addSubview:st];
    [NSLayoutConstraint activateConstraints:@[
      [sc.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[sc.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
      [sc.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[sc.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [st.topAnchor constraintEqualToAnchor:sc.contentLayoutGuide.topAnchor constant:12],[st.bottomAnchor constraintEqualToAnchor:sc.contentLayoutGuide.bottomAnchor constant:-24],
      [st.leadingAnchor constraintEqualToAnchor:sc.frameLayoutGuide.leadingAnchor constant:16],[st.trailingAnchor constraintEqualToAnchor:sc.frameLayoutGuide.trailingAnchor constant:-16]]];

    _gauge=[PADashGauge new]; _gauge.backgroundColor=UIColor.clearColor; [_gauge.heightAnchor constraintEqualToConstant:240].active=YES; [st addArrangedSubview:_gauge];

    // thanh ga
    UILabel *lcap=[self cap:@"ĐỘ ĐẠP GA"]; [st addArrangedSubview:lcap];
    _loadBar=[UIView new]; _loadBar.backgroundColor=PA_CARD; _loadBar.layer.cornerRadius=8; [_loadBar.heightAnchor constraintEqualToConstant:16].active=YES;
    _loadFill=[UIView new]; _loadFill.backgroundColor=PA_AMBER; _loadFill.layer.cornerRadius=8; [_loadBar addSubview:_loadFill]; [st addArrangedSubview:_loadBar];

    // thu thap 7 ngay
    [st addArrangedSubview:[self cap:@"THU THẬP DỮ LIỆU (7 NGÀY)"]];
    UIView *cc=[self card]; UIStackView *crow=[[UIStackView alloc] init]; crow.spacing=14; crow.alignment=UIStackViewAlignmentCenter;
    crow.translatesAutoresizingMaskIntoConstraints=NO; [cc addSubview:crow];
    [NSLayoutConstraint activateConstraints:@[[crow.topAnchor constraintEqualToAnchor:cc.topAnchor constant:14],[crow.bottomAnchor constraintEqualToAnchor:cc.bottomAnchor constant:-14],[crow.leadingAnchor constraintEqualToAnchor:cc.leadingAnchor constant:16],[crow.trailingAnchor constraintEqualToAnchor:cc.trailingAnchor constant:-16]]];
    _ring=[PADashRing new]; _ring.backgroundColor=UIColor.clearColor; [_ring.widthAnchor constraintEqualToConstant:84].active=YES; [_ring.heightAnchor constraintEqualToConstant:84].active=YES; [crow addArrangedSubview:_ring];
    _collectLbl=[UILabel new]; _collectLbl.numberOfLines=0; _collectLbl.font=PAMono(14,UIFontWeightMedium); _collectLbl.textColor=PA_FG; [crow addArrangedSubview:_collectLbl];
    [st addArrangedSubview:cc];

    // cong tac thu thap im lang
    UIView *tc=[self card];
    _collectSw=[UISwitch new]; _collectSw.onTintColor=PA_AMBER; _collectSw.on=PAEngine.shared.collectMode; [_collectSw addTarget:self action:@selector(toggleCollect:) forControlEvents:UIControlEventValueChanged];
    UILabel *tl=[UILabel new]; tl.text=@"Thu thập im lặng (không phát tiếng)"; tl.textColor=PA_FG; tl.font=PAFont(16,UIFontWeightRegular); tl.numberOfLines=0;
    UIStackView *trow=[[UIStackView alloc] initWithArrangedSubviews:@[tl,_collectSw]]; trow.alignment=UIStackViewAlignmentCenter; trow.spacing=10;
    trow.translatesAutoresizingMaskIntoConstraints=NO; [tc addSubview:trow];
    [NSLayoutConstraint activateConstraints:@[[trow.topAnchor constraintEqualToAnchor:tc.topAnchor constant:12],[trow.bottomAnchor constraintEqualToAnchor:tc.bottomAnchor constant:-12],[trow.leadingAnchor constraintEqualToAnchor:tc.leadingAnchor constant:16],[trow.trailingAnchor constraintEqualToAnchor:tc.trailingAnchor constant:-16]]];
    [st addArrangedSubview:tc];

    // danh gia he thong
    [st addArrangedSubview:[self cap:@"ĐÁNH GIÁ HỆ THỐNG"]];
    _verdict=[UILabel new]; _verdict.numberOfLines=0; _verdict.font=PAFont(16,UIFontWeightSemibold); _verdict.textColor=PA_AMBER; [st addArrangedSubview:_verdict];
    UIView *ac=[self card]; _assess=[UIStackView new]; _assess.axis=UILayoutConstraintAxisVertical; _assess.spacing=8;
    _assess.translatesAutoresizingMaskIntoConstraints=NO; [ac addSubview:_assess];
    [NSLayoutConstraint activateConstraints:@[[_assess.topAnchor constraintEqualToAnchor:ac.topAnchor constant:12],[_assess.bottomAnchor constraintEqualToAnchor:ac.bottomAnchor constant:-12],[_assess.leadingAnchor constraintEqualToAnchor:ac.leadingAnchor constant:16],[_assess.trailingAnchor constraintEqualToAnchor:ac.trailingAnchor constant:-16]]];
    [st addArrangedSubview:ac];
}

- (UILabel *)cap:(NSString *)t { UILabel *l=[UILabel new]; l.text=t; l.font=PAFont(12,UIFontWeightSemibold); l.textColor=PA_MUTED; return l; }
- (UIView *)card { UIView *v=[UIView new]; v.backgroundColor=PA_CARD; v.layer.cornerRadius=14; return v; }

- (void)toggleCollect:(UISwitch *)s { PAEngine.shared.collectMode=s.on; }

- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; _t=[NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(refresh) userInfo:nil repeats:YES]; [self refresh]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_t invalidate]; _t=nil; }

- (void)refresh {
    PAEngine *e=PAEngine.shared; PASynth *sy=e.synth;
    _gauge.speed=sy->speed; _gauge.rpm=sy->rpm; _gauge.gear=sy->gear+1; _gauge.load=sy->load; _gauge.running=(sy->state!=0);
    _gauge.redline=4422>sy->rpm?7500:7500;  // vanh theo redline chung
    [_gauge setNeedsDisplay];
    CGFloat w=_loadBar.bounds.size.width*fmin(1,sy->load); _loadFill.frame=CGRectMake(0,0,w,16);
    _loadFill.backgroundColor = sy->load>0.85?PA_RED:PA_AMBER;
    NSInteger days=[PATrial daysDone]; _ring.frac=days/7.0; _ring.big=[NSString stringWithFormat:@"%ld/7",(long)days]; _ring.small=@"ngày"; [_ring setNeedsDisplay];
    _collectLbl.text=[NSString stringWithFormat:@"%.0f km đã ghi\n%ld chuyến · %.0f phút\n%@", [PATrial totalKm],(long)[PATrial totalTrips],[PATrial totalMinutes], [PATrial complete]?@"✓ Đủ 7 ngày — xuất báo cáo":@"đang thu thập…"];
    _collectSw.on=e.collectMode;
    _verdict.text=[PAAssess verdictFor:e];
    for (UIView *v in _assess.arrangedSubviews) [v removeFromSuperview];
    for (NSDictionary *it in [PAAssess itemsFor:e]) {
        int lv=[it[@"muc"] intValue]; UIColor *dot=lv==0?PA_GREEN:(lv==1?PA_AMBER:PA_RED);
        UIView *d=[[UIView alloc] initWithFrame:CGRectMake(0,0,10,10)]; d.backgroundColor=dot; d.layer.cornerRadius=5;
        [d.widthAnchor constraintEqualToConstant:10].active=YES; [d.heightAnchor constraintEqualToConstant:10].active=YES;
        UILabel *n=[UILabel new]; n.text=it[@"ten"]; n.font=PAFont(14,UIFontWeightMedium); n.textColor=PA_FG; [n setContentHuggingPriority:240 forAxis:UILayoutConstraintAxisHorizontal];
        UILabel *v=[UILabel new]; v.text=it[@"gia_tri"]; v.font=PAMono(13,UIFontWeightRegular); v.textColor=PA_MUTED; v.textAlignment=NSTextAlignmentRight; v.numberOfLines=0;
        UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[d,n,v]]; row.spacing=10; row.alignment=UIStackViewAlignmentCenter;
        [_assess addArrangedSubview:row];
    }
}
@end
