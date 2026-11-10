#import "PACarPlay.h"
#import <CarPlay/CarPlay.h>
#import "PAEngine.h"
#import "PAMotion.h"
#import "PASynth.h"
#import "PAAssess.h"
#import "PATrial.h"

@interface PACarPlaySceneDelegate () <CPTemplateApplicationSceneDelegate>
@property (nonatomic, strong) CPInterfaceController *ic;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation PACarPlaySceneDelegate

- (void)templateApplicationScene:(CPTemplateApplicationScene *)scene didConnectInterfaceController:(CPInterfaceController *)ic {
    self.ic = ic;
    [ic setRootTemplate:[self buildTemplate] animated:NO completion:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(update) userInfo:nil repeats:YES];
}
- (void)templateApplicationScene:(CPTemplateApplicationScene *)scene didDisconnectInterfaceController:(CPInterfaceController *)ic {
    [self.timer invalidate]; self.timer = nil; self.ic = nil;
}

- (CPInformationTemplate *)buildTemplate {
    PAEngine *e = PAEngine.shared; PASynth *sy = e.synth; PAMotion *m = (PAMotion *)e.motion;
    NSMutableArray<CPInformationItem *> *items = [NSMutableArray array];
    [items addObject:[[CPInformationItem alloc] initWithTitle:@"Tốc độ" detail:[NSString stringWithFormat:@"%.0f km/h", sy->speed]]];
    [items addObject:[[CPInformationItem alloc] initWithTitle:@"Vòng tua · số" detail:[NSString stringWithFormat:@"%.0f v/p · số %d", sy->rpm, sy->gear + 1]]];
    [items addObject:[[CPInformationItem alloc] initWithTitle:@"Độ đạp ga" detail:[NSString stringWithFormat:@"%.0f%%", sy->load * 100]]];
    [items addObject:[[CPInformationItem alloc] initWithTitle:@"Thu thập 7 ngày" detail:[NSString stringWithFormat:@"ngày %ld/7 · %.0f km", (long)[PATrial daysDone], [PATrial totalKm]]]];
    [items addObject:[[CPInformationItem alloc] initWithTitle:@"Cảm biến · GPS" detail:[NSString stringWithFormat:@"%.0f/giây · %@", m.imuHz, m.calibrated ? @"đã học hướng" : @"đang học"]]];
    for (NSDictionary *it in [PAAssess itemsFor:e]) {
        int lv = [it[@"muc"] intValue]; if (lv == 0) continue;   // chi hien muc can chu y
        NSString *mark = lv == 2 ? @"⚠︎ " : @"• ";
        [items addObject:[[CPInformationItem alloc] initWithTitle:[mark stringByAppendingString:it[@"ten"]] detail:it[@"gia_tri"]]];
    }
    CPInformationTemplate *t = [[CPInformationTemplate alloc] initWithTitle:@"NDA Drive" layout:CPInformationTemplateLayoutLeading items:items actions:@[]];
    return t;
}

- (void)update {
    if (!self.ic) return;
    // Cap nhat bang cach dat lai root (CPInformationTemplate khong cho sua item truc tiep o iOS 15)
    CPInformationTemplate *cur = (CPInformationTemplate *)self.ic.rootTemplate;
    CPInformationTemplate *neo = [self buildTemplate];
    if ([cur isKindOfClass:CPInformationTemplate.class]) { @try { cur.items = neo.items; } @catch (__unused NSException *x) { [self.ic setRootTemplate:neo animated:NO completion:nil]; } }
    else [self.ic setRootTemplate:neo animated:NO completion:nil];
}
@end
