// Mo phong chuyen di de kiem chung PAFusion so voi cach chi dung GPS.
#include "../app/PAFusion.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
static double gauss(void){ double u=(rand()+1.0)/(RAND_MAX+2.0), v=(rand()+1.0)/(RAND_MAX+2.0); return sqrt(-2*log(u))*cos(2*M_PI*v); }
// toc do that (m/s) va toc do goc khi vao cua (rad/s) theo thoi gian
static void truth(double t, double *v, double *a, double *w, int *tunnel){
  double kmh, akmh; *w=0; *tunnel=0;
  if(t<8){kmh=0;akmh=0;}
  else if(t<20){kmh=(t-8)*5;akmh=5;}              // 0->60
  else if(t<40){kmh=60;akmh=0; if(t>28&&t<34)*w=0.25;} // giu 60, vao cua
  else if(t<48){kmh=60-(t-40)*7.5;akmh=-7.5;}     // phanh ve 0
  else if(t<58){kmh=0;akmh=0;}                    // den do
  else if(t<70){kmh=(t-58)*9;akmh=9;}             // tang toc manh 0->108
  else if(t<100){kmh=108;akmh=0; if(t>78&&t<98)*tunnel=1;} // ham chui
  else if(t<110){kmh=108-(t-100)*4;akmh=-4;}      // nha ga -> 68
  else if(t<114){kmh=68+(t-110)*6;akmh=6;}        // vuot xe
  else if(t<126){kmh=92-(t-114)*92.0/12;akmh=-92.0/12;}
  else {kmh=0;akmh=0;}
  *v=kmh/3.6; *a=akmh/3.6;
}
static void mul(double R[3][3], const double x[3], double o[3]){ for(int i=0;i<3;i++) o[i]=R[i][0]*x[0]+R[i][1]*x[1]+R[i][2]*x[2]; }
static void rotx(double a,double R[3][3]){double c=cos(a),s=sin(a);double M[3][3]={{1,0,0},{0,c,-s},{0,s,c}};for(int i=0;i<9;i++)R[i/3][i%3]=M[i/3][i%3];}
static void rotz(double a,double R[3][3]){double c=cos(a),s=sin(a);double M[3][3]={{c,-s,0},{s,c,0},{0,0,1}};for(int i=0;i<9;i++)R[i/3][i%3]=M[i/3][i%3];}
static void mm(double A[3][3],double B[3][3],double C[3][3]){for(int i=0;i<3;i++)for(int j=0;j<3;j++){C[i][j]=0;for(int k=0;k<3;k++)C[i][j]+=A[i][k]*B[k][j];}}
int main(int argc,char**argv){
  int mount=argc>1?atoi(argv[1]):0; srand(argc>2?atoi(argv[2]):1);
  // Ma tran xe->dien thoai. Xe: x truoc, y trai, z len.
  // Dien thoai doc, man hinh huong nguoi lai: Xdt=-y, Ydt=z, Zdt=-x  => hang la truc dt bieu dien trong he xe
  double B0[3][3]={{0,-1,0},{0,0,1},{-1,0,0}};
  double B1[3][3]={{0,0,1},{0,1,0},{-1,0,0}}; // dien thoai NGANG: Xdt=z(len), Ydt=y, Zdt=-x
  double Rt[3][3],Rz[3][3],T[3][3],Rvd[3][3];
  rotx((mount?10:22)*M_PI/180,Rt); rotz((mount?-35:28)*M_PI/180,Rz); // nghieng + xoay lech ve phia nguoi lai
  mm(mount?B1:B0,Rz,T); mm(Rt,T,Rvd);
  double bias[3]={0.06,-0.04,0.05};
  PAFusion f; paf_init(&f);
  int wrongcal = argc>3 && atoi(argv[3])==1;   // nap san can chinh SAI 40 do (may bi xoay ngang tren gia)
  double trueTheta = mount ? 24.8*M_PI/180 : -28.1*M_PI/180;
  if (wrongcal) { double gv[3]={0,0,-9.81}, gd[3]; mul(Rvd,gv,gd); paf_load_calibration(&f, trueTheta + 40*M_PI/180, gd); }
  double dt=0.01, nextGps=0.3; double gpsDelay=0.6;
  // GPS-only (cach cu): giu ban tin cuoi + ngoai suy theo gia toc GPS
  double gV=-1,gPrevV=0,gPrevT=0,gA=0,gT=0;
  double eF=0,eG=0; long n=0; double calT=-1;
  double maxErrF=0,maxErrG=0, tunErrF=0; long tunN=0;
  for(double t=0;t<135;t+=dt){
    double v,a,w; int tun; truth(t,&v,&a,&w,&tun);
    double vib = v>0.5?0.18:0.03;
    double accV[3]={a, v*w, 0}, gV3[3]={0,0,-9.81}, rotV[3]={0,0,w};
    double ad[3],gd[3],rd[3]; mul(Rvd,accV,ad); mul(Rvd,gV3,gd); mul(Rvd,rotV,rd);
    for(int i=0;i<3;i++){ ad[i]+=bias[i]+gauss()*(0.05+vib); rd[i]+=gauss()*0.01; }
    paf_imu(&f,ad,gd,rd,t+1);
    if(t>=nextGps){ nextGps+=1.0;
      if(!tun){ double tFix=t-gpsDelay; double tv,ta,tw; int tt; truth(tFix,&tv,&ta,&tw,&tt);
        double meas=fmax(0,tv+gauss()*0.25); if(tv<0.3) meas=fabs(gauss()*0.3);
        paf_gps(&f,meas,0.4,90,tFix+1);
        if(gV>=0){ gA=(meas-gPrevV)/fmax(0.3,(tFix-gPrevT)); } gPrevV=meas; gPrevT=tFix; gV=meas; gT=tFix;
      }
    }
    double vF=f.v, vG = gV<0?0: fmax(0, gV + gA*fmin(t-gT,1.0)*0.6);
    if(f.calibrated && calT<0) calT=t;
    double ef=fabs(vF-v)*3.6, eg=fabs(vG-v)*3.6;
    if(t>2){ eF+=ef*ef; eG+=eg*eg; n++; if(ef>maxErrF)maxErrF=ef; if(eg>maxErrG)maxErrG=eg; }
    if(tun){ tunErrF+=ef*ef; tunN++; }
    if(fmod(t,5)<dt && t>0.5) printf("t=%5.0fs that=%6.1f | ket hop=%6.1f | chi GPS=%6.1f km/h  hoc_truc=%d dung=%d ham=%d\n",t,v*3.6,vF*3.6,vG*3.6,f.calibrated,f.stationary,tun);
  }
  printf("\nKET QUA (mount=%s): sai so trung binh (RMS) KET HOP=%.2f km/h, CHI GPS=%.2f km/h | lon nhat: %.1f vs %.1f km/h | trong ham (ket hop)=%.2f km/h | hoc xong truc tien sau %.0f s, goc=%.1f do\n",
    mount?"ngang":"doc",sqrt(eF/n),sqrt(eG/n),maxErrF,maxErrG,sqrt(tunErrF/fmax(1,tunN)),calT,f.theta*180/M_PI);
  // Kiem tra ghi nho can chinh: cung goc gan -> dung ngay; doi goc gan -> phai hoc lai
  int reuseOk, rejectOk;
  { PAFusion f2; paf_init(&f2); paf_load_calibration(&f2, f.theta, f.gCal);
    double gv[3]={0,0,-9.81}, gd[3], z[3]={0,0,0}; mul(Rvd,gv,gd);
    for(int i=0;i<120;i++) paf_imu(&f2,z,gd,z,500+i*0.01);
    reuseOk = f2.calibrated && fabs(f2.theta - f.theta) < 1e-9; }
  { PAFusion f3; paf_init(&f3); paf_load_calibration(&f3, f.theta, f.gCal);
    double Rz2[3][3], R2[3][3]; rotz(40*M_PI/180,Rz2); mm(Rz2,Rvd,R2);   // nghieng may 40 do trong mat phang man hinh
    double gv[3]={0,0,-9.81}, gd[3], z[3]={0,0,0}; mul(R2,gv,gd);
    for(int i=0;i<120;i++) paf_imu(&f3,z,gd,z,500+i*0.01);
    rejectOk = !f3.calibrated; }
  printf("  ghi nho can chinh: dung lai=%s, doi goc gan -> hoc lai=%s\n", reuseOk?"OK":"LOI", rejectOk?"OK":"LOI");
  double thErr = fabs(atan2(sin(f.theta-trueTheta),cos(f.theta-trueTheta)))*180/M_PI;
  if (wrongcal) printf("  nap can chinh sai 40 do -> sau chuyen di lech con %.1f do\n", thErr);
  int ok = (!wrongcal || thErr < 8) && reuseOk && rejectOk && sqrt(eF/n) < (wrongcal ? 3.0 : 1.8) && sqrt(eF/n) < sqrt(eG/n) && sqrt(tunErrF/fmax(1,tunN)) < 3.5 && calT > 0 && calT < 20;
  printf("  -> %s\n", ok?"DAT":"KHONG DAT");
  return ok?0:1;
}
