// Kiem thu che do THU THAP IM LANG: bo am thanh van chay, vat ly van buoc, nhung dau ra phai = 0
#include "../app/PASynth.h"
#include <stdio.h>
#include <math.h>
int main(void){
  PASynth s; pa_init(&s); s.presetIndex=pa_preset_index("gt3"); s.volume=1; s.mute=1; s.requestStart=1;
  s.perfCap=6.7; s.perfKnee=62;
  double sr=48000; float buf[256]; double peak=0; int fail=0;
  for(int b=0;b<1900;b++){ double t=b*256/sr;
    s.gpsSpeed = t<8? t*12 : 96; s.gpsAccel = t<8?12:0; s.gpsAge=0;
    pa_render(&s,buf,256,sr);
    for(int i=0;i<256;i++) if(fabs(buf[i])>peak) peak=fabs(buf[i]);
  }
  printf("im lang: dinh am thanh %.6f | toc do %.0f km/h, vong tua %.0f, so %d, trang thai %d\n",peak,s.speed,s.rpm,s.gear+1,s.state);
  if(peak>1e-6){printf("  LOI: van co tieng\n");fail=1;}
  if(s.state!=2 || s.rpm<1000 || s.speed<80){printf("  LOI: vat ly khong chay\n");fail=1;}
  // tat im lang -> co tieng tro lai
  s.mute=0; peak=0; for(int b=0;b<40;b++){ pa_render(&s,buf,256,sr); for(int i=0;i<256;i++) if(fabs(buf[i])>peak) peak=fabs(buf[i]); }
  printf("tat im lang: dinh am thanh %.3f\n",peak);
  if(peak<0.01){printf("  LOI: khong co tieng lai\n");fail=1;}
  printf("  -> %s\n",fail?"KHONG DAT":"DAT"); return fail;
}
