#include "../app/PASynth.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stdint.h>
static void wr32(FILE*f,uint32_t v){fwrite(&v,4,1,f);} static void wr16(FILE*f,uint16_t v){fwrite(&v,2,1,f);}
// toc do thuc te theo thoi gian (km/h)
static double drive(double t){
  if(t<4) return 0;                 // no may, dung
  if(t<16) return (t-4)*9.0;        // tang toc 0->108
  if(t<20) return 108;              // giu
  if(t<26) return 108-(t-20)*6;     // nha ga -> 72
  if(t<30) return 72+(t-26)*7;      // tang toc nhe
  if(t<38) return fmax(0,100-(t-30)*12.5); // phanh ve 0
  return 0;
}
int main(int argc,char**argv){
  const char*key=argc>1?argv[1]:"gt3"; double sr=48000; int N=512; double T=42;
  PASynth s; pa_init(&s); s.presetIndex=pa_preset_index(key); s.requestStart=1; s.rearFx=getenv("REARFX")?1:0;
  char fn[256]; snprintf(fn,256,"%s/%s.wav",getenv("TMPDIR")?getenv("TMPDIR"):"/tmp",key); FILE*f=fopen(fn,"wb");
  int total=(int)(T*sr/N)*N; fwrite("RIFF",1,4,f);wr32(f,36+total*2);fwrite("WAVEfmt ",1,8,f);wr32(f,16);wr16(f,1);wr16(f,1);wr32(f,48000);wr32(f,96000);wr16(f,2);wr16(f,16);fwrite("data",1,4,f);wr32(f,total*2);
  float buf[512]; double t=0, nextFix=0, prevV=0; double peak=0, sum=0; long cnt=0; int nans=0; int maxGear=0; double maxRpm=0;
  for(int b=0;b<total/N;b++){
    { double v=drive(t+0.05)+((rand()%100)/100.0-0.5)*1.2; if(v<0)v=0; s.gpsAccel=(drive(t+0.1)-drive(t))/0.1; s.gpsSpeed=v; s.gpsAge=0; (void)nextFix; (void)prevV; }
    if(t>39.5 && t<39.6) s.requestStop=1;
    pa_render(&s,buf,N,sr);
    for(int i=0;i<N;i++){ float x=buf[i]; if(isnan(x)){nans++;x=0;} if(fabs(x)>peak)peak=fabs(x); sum+=x*x; cnt++; int16_t q=(int16_t)(x*32000); fwrite(&q,2,1,f);}
    if(s.gear>maxGear)maxGear=s.gear; if(s.rpm>maxRpm)maxRpm=s.rpm;
    if(b%(int)(sr/N*2)==0)
      printf("t=%5.1f gps=%6.1f speed=%6.1f gear=%d rpm=%5.0f load=%.2f state=%d\n",t,s.gpsSpeed,s.speed,s.gear+1,s.rpm,s.load,s.state);
    t+=N/sr;
  }
  fclose(f); printf("%s: peak=%.3f rms=%.3f nans=%d maxGear=%d maxRpm=%.0f\n",key,peak,sqrt(sum/cnt),nans,maxGear+1,maxRpm);
  int ok = nans==0 && peak<1.0 && sqrt(sum/cnt)>0.05 && maxGear>=4 && s.state==PA_OFF;
  printf("  -> %s\n", ok?"DAT":"KHONG DAT");
  return ok?0:1;
}
