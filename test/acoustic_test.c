// Kiem thu do am hoc: gia lap khoang xe (tre 37 ms, +6 dB @125 Hz, -6 dB @4 kHz, nhieu nen) roi do lai
#include "../app/PAAcoustic.h"
#include "../app/PASynth.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
static double gauss(void){ double u=(rand()+1.0)/(RAND_MAX+2.0), v=(rand()+1.0)/(RAND_MAX+2.0); return sqrt(-2*log(u))*cos(2*M_PI*v); }
// biquad peaking RBJ
static void peak(double *k,double sr,double f,double q,double db){double A=pow(10,db/40),w=2*M_PI*f/sr,al=sin(w)/(2*q),cw=cos(w),a0=1+al/A;
 k[0]=(1+al*A)/a0;k[1]=-2*cw/a0;k[2]=(1-al*A)/a0;k[3]=-2*cw/a0;k[4]=(1-al/A)/a0;}
static void filt(float *x,int n,double *k){double z1=0,z2=0;for(int i=0;i<n;i++){double y=k[0]*x[i]+z1;z1=k[1]*x[i]-k[3]*y+z2;z2=k[2]*x[i]-k[4]*y;x[i]=(float)y;}}
int main(void){
  int fail=0; double srs[5]={44100,48000,48000,16000,48000}, lags[5]={37,37,1450,320,900}, posts[5]={1,1,3.5,3.5,3.5};
  for(int s=0;s<5;s++){
    double sr=srs[s], T=8, f1=40, f2=fmin(16000,0.45*sr), lagMs=lags[s];
    int nS=(int)(T*sr); float *sw=malloc(sizeof(float)*nS); paa_make_sweep(sw,nS,sr,f1,f2,T,0.5);
    int pre=(int)(1.0*sr), lag=(int)(lagMs/1000*sr), nY=pre+nS+(int)(posts[s]*sr);
    float *y=calloc(nY,sizeof(float));
    for(int i=0;i<nS;i++) y[pre+lag+i]=sw[i]*0.3f;              // loa + khoang xe: suy hao chung
    double k1[5],k2[5]; peak(k1,sr,125,1.2,6); peak(k2,sr,4000,1.2,-6);
    filt(y,nY,k1); filt(y,nY,k2);
    for(int i=0;i<nY;i++) y[i]+=(float)(gauss()*0.002);          // nhieu nen (~-54 dBFS)
    if(s==4){ // khoang xe on: tieng u tram (dieu hoa, gio) TO HON tieng quet ~6 dB
      double br=0; for(int i=0;i<nY;i++){ br=br*0.995+gauss()*0.02; y[i]+=(float)br; } }
    PAAcousticResult r; paa_analyze(sw,nS,y,nY,pre,sr,f1,f2,T,&r);
    printf("sr=%.0f: tre %.1f ms (that %.1f) | nhieu %.1f dBFS | SNR %.0f dB\n  dap ung:",sr,r.latencyMs,lagMs,r.noiseDbfs,r.snrDb);
    for(int b=0;b<PAA_BANDS;b+=2) printf(" %g:%+.1f",PAA_BAND_HZ[b],r.respDb[b]); printf("\n  bo bu:");
    for(int o=0;o<PAA_OCT;o++) printf(" %g:%+.1f",PAA_OCT_HZ[o],r.corrDb[o]); printf("\n");
    // kiem tra: tre dung, 125 Hz cao ~+6, 4 kHz thap ~-6, bo bu dao dau dung chieu
    double r125=r.respDb[5], r4k=r.respDb[20];
    if(fabs(r.latencyMs-lagMs)>1.0) {printf("  LOI tre\n");fail=1;}
    if(fabs(r125-6)>2 || fabs(r4k+6)>2) {printf("  LOI dap ung\n");fail=1;}
    if(!(r.corrDb[1]<-2 && r.corrDb[6]>2)) {printf("  LOI bo bu\n");fail=1;}
    if(!r.valid) {printf("  LOI SNR\n");fail=1;}
    free(sw); free(y);
  }
  printf("  -> %s\n",fail?"KHONG DAT":"DAT"); return fail;
}
