// PAFusion - hop nhat cam bien de uoc luong toc do xe chinh xac va phan hoi tuc thi.
//
//  GPS (1 lan/giay, chinh xac nhung tre ~0,5-1 s)  ─┐
//  Gia toc ke + con quay (100 lan/giay, tuc thi)  ──┼─► Bo loc Kalman ─► toc do, gia toc doc xe
//  Ap ke / do cao (do doc duong)                   ─┘
//
// Dien thoai gan tren gia do o bat ky huong nao: bo loc tu "hoc" truc tien cua xe
// trong he toa do dien thoai bang cach so gia toc cam bien voi gia toc suy ra tu GPS.
// Thuan C (khong phu thuoc iOS) de chay thu tren may tinh.
#ifndef PAFUSION_H
#define PAFUSION_H

#ifdef __cplusplus
extern "C" {
#endif

#define PAF_HIST 512
#define PAF_NDLY 11

typedef struct {
    // ---------- Ket qua ----------
    double v;            // toc do uoc luong (m/s)
    double a;            // gia toc doc xe da loc (m/s^2), + la tang toc
    double grade;        // do doc (sin goc), + la len doc
    int calibrated;      // da hoc xong truc tien cua xe
    int stationary;      // xe dang dung yen
    int gpsOk;           // GPS con tin hieu (< 3 s)
    double quality;      // 0..1 do tin cay

    // ---------- Noi bo ----------
    double t;                       // thoi diem mau cam bien cuoi (s)
    double P00, P01, P11, b;        // Kalman: hiep phuong sai + sai lech gia toc ke
    double g[3];                    // huong trong luc (don vi, he dien thoai)
    double gCal[3];                 // trong luc luc hoc xong (phat hien thao/xoay dien thoai)
    double theta;                   // goc truc tien so voi huong mac dinh
    double Sx, Sy, E;               // tich luy hoi quy de hoc truc tien
    double hxSum, hySum; int hN;    // trung binh gia toc ngang giua 2 lan GPS
    double lastGpsV, lastGpsT, lastGpsCourse, lastFixWall;
    int gpsRep; long gpsRepTotal, gpsTotal;   // ban tin GPS lap lai (xe gui vi tri qua CarPlay hay giu so cu)
    int hasGps;
    double aLp;                     // loc thong thap cho gia toc dau ra
    double accVar, gyrMean, accMean;// thong ke de nhan biet dung yen
    double moveT;                   // thoi gian xoay dien thoai bat thuong
    double baroAlt, baroDist, baroT; int hasBaro;
    double dist;                    // quang duong da di (m), de tinh do doc
    double aGps;                    // gia toc suy tu GPS (dung khi chua hoc xong)
    double histT[PAF_HIST], histV[PAF_HIST]; int histI;
    double sigScale;                // he so phan hoi: <1 on dinh hon, >1 nhanh hon (mac dinh 1)
    double calProgress;             // 0..1 tien do hoc huong xe
    double aLongRaw;                // gia toc doc xe tuc thoi (chua loc), de hien thi
    int savedPending; long nImu;
    double savedTheta, savedG[3];
    // hoc huong xe bang LUC VAO CUA (khong can GPS chinh xac): gia toc ngang = toc do x toc do quay
    double Lx, Ly, Lc;
    int calByTurn;                  // lan hoc gan nhat la nho vao cua
    // tu uoc luong do tre GPS (GPS cua xe qua CarPlay tre 1-2 s, cap nhat ~2 s/lan)
    double dlyErr[PAF_NDLY]; double gpsDelay; long dlyN;
    double lastFixT;                // thoi diem cam bien luc nhan ban tin GPS moi
} PAFusion;

void paf_init(PAFusion *f);

// Nap ket qua can chinh da luu (goc truc tien + huong trong luc luc hoc).
// Neu dien thoai van gan dung goc cu (lech < 15 do) thi dung ngay, khong can hoc lai.
void paf_load_calibration(PAFusion *f, double theta, const double g[3]);

// Mau cam bien chuyen dong (CoreMotion deviceMotion), he toa do dien thoai:
//  userAcc: gia toc do nguoi dung/xe gay ra (m/s^2, da tru trong luc)
//  gravity: vec-to trong luc (m/s^2 hoac don vi g, chi lay huong)
//  rot: toc do xoay (rad/s); t: thoi diem (s)
void paf_imu(PAFusion *f, const double userAcc[3], const double gravity[3], const double rot[3], double t);

// Ban tin GPS: speed (m/s, <0 neu khong co), speedAcc (m/s, <0 neu khong ro),
// course (do, <0 neu khong co), tFix: thoi diem do (s, cung dong ho voi paf_imu)
void paf_gps(PAFusion *f, double speed, double speedAcc, double course, double tFix);

// Do cao tuong doi tu ap ke (m)
void paf_baro(PAFusion *f, double relAltitude, double t);

#ifdef __cplusplus
}
#endif
#endif
