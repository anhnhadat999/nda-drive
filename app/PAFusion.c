// PAFusion - xem mo ta trong PAFusion.h
#include "PAFusion.h"
#include <math.h>
#include <string.h>

// ---- Thong so bo loc ----
#define SIG_A_CAL     0.35   // nhieu gia toc ke khi da hoc truc (m/s^2)
#define SIG_A_UNCAL   1.50   // chua hoc truc: chi tin GPS (mo hinh van toc khong doi)
#define SIG_BIAS_RW   0.004  // troi sai lech gia toc ke (m/s^2 / sqrt(s))
#define R_ZUPT        0.03   // do tin cay khi biet chac xe dung yen (m/s)
#define CAL_ENERGY    1.2    // luong "tang/giam toc" can tich luy de hoc xong truc tien
#define CAL_FORGET    0.97
#define GPS_LOST_S    3.0

static double dot3(const double a[3], const double b[3]) { return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]; }
static double norm3(const double a[3]) { return sqrt(dot3(a, a)); }
static void cross3(const double a[3], const double b[3], double o[3]) {
    o[0] = a[1]*b[2] - a[2]*b[1]; o[1] = a[2]*b[0] - a[0]*b[2]; o[2] = a[0]*b[1] - a[1]*b[0];
}
static void unit3(double a[3]) { double n = norm3(a); if (n > 1e-9) { a[0] /= n; a[1] /= n; a[2] /= n; } }
static double clampd(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

void paf_init(PAFusion *f) {
    memset(f, 0, sizeof(*f));
    f->P00 = 4.0; f->P11 = 0.25;
    f->g[1] = -1;                 // tam: dien thoai dung doc
    f->lastGpsCourse = -1;
    f->quality = 0;
}

// Co so 2 truc nam ngang (e1: huong tien mac dinh, e2 vuong goc) tu huong trong luc
static void basis(const double g[3], double e1[3], double e2[3]) {
    // Mac dinh: man hinh huong ve nguoi lai -> mat lung dien thoai (-Z) huong ve phia truoc xe.
    // Neu dien thoai nam ngua (trong luc doc theo Z) thi lay dinh dien thoai (+Y) lam huong truoc.
    double d[3] = {0, 0, -1};
    if (fabs(g[2]) > 0.8) { d[0] = 0; d[1] = 1; d[2] = 0; }
    double k = dot3(d, g);
    e1[0] = d[0] - k*g[0]; e1[1] = d[1] - k*g[1]; e1[2] = d[2] - k*g[2];
    unit3(e1);
    cross3(g, e1, e2);
    unit3(e2);
}

static void kf_update(PAFusion *f, double z, double R, double vRef) {
    double y = z - vRef;
    double S = f->P00 + R;
    double K0 = f->P00 / S, K1 = f->P01 / S;
    f->v += K0 * y;
    f->b += K1 * y;
    double P00 = f->P00, P01 = f->P01, P11 = f->P11;
    f->P00 = (1 - K0) * P00;
    f->P01 = (1 - K0) * P01;
    f->P11 = P11 - K1 * P01;
    if (f->v < 0) f->v = 0;
}

static void reset_cal(PAFusion *f) {
    f->calibrated = 0; f->theta = 0; f->Sx = f->Sy = f->E = 0;
}

void paf_imu(PAFusion *f, const double userAcc[3], const double gravity[3], const double rot[3], double t) {
    int first = f->t == 0;
    double dt = first ? 0.01 : t - f->t;
    if (dt <= 0 || dt > 0.2) dt = 0.01;
    f->t = t;

    // huong trong luc (loc nhe)
    double gu[3] = {gravity[0], gravity[1], gravity[2]};
    unit3(gu);
    if (first || norm3(f->g) < 0.5) { memcpy(f->g, gu, sizeof gu); }
    else {
        for (int i = 0; i < 3; i++) f->g[i] = f->g[i] * 0.97 + gu[i] * 0.03;
        unit3(f->g);
    }

    // dien thoai bi xoay/thao khoi gia do -> hoc lai truc tien
    double gm = norm3(rot);
    if (gm > 0.8) f->moveT += dt; else f->moveT = fmax(0, f->moveT - dt);
    if (f->calibrated && (f->moveT > 0.5 || dot3(f->g, f->gCal) < cos(20 * M_PI / 180))) reset_cal(f);

    double e1[3], e2[3];
    basis(f->g, e1, e2);
    double hx = dot3(userAcc, e1), hy = dot3(userAcc, e2);
    f->hxSum += hx; f->hySum += hy; f->hN++;

    double aLong = hx * cos(f->theta) + hy * sin(f->theta);

    // nhan biet dung yen: rung nho, khong xoay
    double k = fmin(1, dt / 0.6);
    double am = norm3(userAcc);
    f->accMean += (am - f->accMean) * k;
    f->accVar += ((am - f->accMean) * (am - f->accMean) - f->accVar) * k;
    f->gyrMean += (gm - f->gyrMean) * k;
    int stillSensor = sqrt(f->accVar) < 0.08 && f->accMean < 0.18 && f->gyrMean < 0.05;

    f->gpsOk = f->hasGps && (t - f->lastFixWall) < GPS_LOST_S;

    // ---- Kalman: du doan ----
    double aUse = f->calibrated ? (aLong - f->b) : f->aGps * 0.8; // chua hoc truc: ngoai suy theo gia toc GPS
    double sigA = f->calibrated ? SIG_A_CAL : SIG_A_UNCAL;
    if (!f->gpsOk && f->calibrated && (t - f->lastFixWall) > 25) aUse *= 0.5; // mat GPS lau: han che troi
    f->v += aUse * dt;
    if (f->v < 0) f->v = 0;
    double P00 = f->P00, P01 = f->P01, P11 = f->P11;
    f->P00 = P00 - 2 * dt * P01 + dt * dt * P11 + sigA * sigA * dt;
    f->P01 = P01 - dt * P11;
    f->P11 = P11 + SIG_BIAS_RW * SIG_BIAS_RW * dt;
    if (f->P00 > 100) f->P00 = 100;

    // ---- Dung yen: ep toc do ve 0 ----
    f->stationary = stillSensor && (!f->gpsOk || f->lastGpsV < 1.0) && f->v < 3.0;
    if (f->stationary) kf_update(f, 0, R_ZUPT * R_ZUPT, f->v);

    // lich su toc do (de xu ly do tre GPS)
    f->histI = (f->histI + 1) % PAF_HIST;
    f->histT[f->histI] = t; f->histV[f->histI] = f->v;

    // ---- Dau ra ----
    double aOut = f->calibrated ? (aLong - f->b) : f->aGps;
    if (f->stationary) aOut = 0;
    f->aLp += (aOut - f->aLp) * fmin(1, dt / 0.12);
    f->a = f->aLp;
    f->dist += f->v * dt;
    f->quality = (f->calibrated ? 0.6 : 0.3) + (f->gpsOk ? 0.4 : 0.1);
}

// toc do uoc luong tai thoi diem t (noi suy trong lich su)
static double hist_at(const PAFusion *f, double t, int *found) {
    *found = 0;
    for (int n = 0; n < PAF_HIST - 1; n++) {
        int i = (f->histI - n + PAF_HIST) % PAF_HIST, j = (i - 1 + PAF_HIST) % PAF_HIST;
        if (f->histT[i] == 0 || f->histT[j] == 0) break;
        if (f->histT[j] <= t && t <= f->histT[i]) {
            double w = (t - f->histT[j]) / fmax(1e-6, f->histT[i] - f->histT[j]);
            *found = 1;
            return f->histV[j] + (f->histV[i] - f->histV[j]) * w;
        }
    }
    return f->v;
}

void paf_gps(PAFusion *f, double speed, double speedAcc, double course, double tFix) {
    if (speed < 0) return;
    double now = f->t > 0 ? f->t : tFix;

    // ---- Kalman: cap nhat bang GPS (bu do tre) ----
    double sa = speedAcc > 0 ? fmax(speedAcc, 0.2) : 0.8;
    double R = sa * sa * 1.3;
    int found;
    double vRef = hist_at(f, tFix, &found);
    double before = f->v;
    kf_update(f, speed, R, found ? vRef : f->v);
    double corr = f->v - before;
    if (found) for (int n = 0; n < PAF_HIST; n++) if (f->histT[n] >= tFix) f->histV[n] += corr;

    // ---- Hoc truc tien cua xe ----
    if (f->hasGps) {
        double dtg = tFix - f->lastGpsT;
        if (dtg > 0.3 && dtg < 3.0) {
            double aG = (speed - f->lastGpsV) / dtg;
            f->aGps = aG;
            double turn = 0;
            if (course >= 0 && f->lastGpsCourse >= 0) {
                double d = fabs(course - f->lastGpsCourse); if (d > 180) d = 360 - d;
                turn = d / dtg;
            }
            if (f->hN > 10 && turn < 8 && speed > 2 && fabs(aG) > 0.25) {
                double hxA = f->hxSum / f->hN, hyA = f->hySum / f->hN;
                f->Sx = f->Sx * CAL_FORGET + hxA * aG;
                f->Sy = f->Sy * CAL_FORGET + hyA * aG;
                f->E  = f->E  * CAL_FORGET + aG * aG;
                double corrMag = sqrt(f->Sx * f->Sx + f->Sy * f->Sy) / fmax(1e-6, f->E);
                if (f->E > CAL_ENERGY && corrMag > 0.4) {
                    double th = atan2(f->Sy, f->Sx);
                    if (!f->calibrated) { f->theta = th; f->calibrated = 1; memcpy(f->gCal, f->g, sizeof f->g); }
                    else {
                        double d = atan2(sin(th - f->theta), cos(th - f->theta));
                        f->theta += d * 0.3;
                    }
                }
            }
        } else {
            f->aGps = 0;
        }
    }
    f->hxSum = f->hySum = 0; f->hN = 0;
    f->lastGpsV = speed; f->lastGpsT = tFix; f->lastGpsCourse = course;
    f->hasGps = 1; f->lastFixWall = now;
}

void paf_baro(PAFusion *f, double relAltitude, double t) {
    if (!f->hasBaro) { f->baroAlt = relAltitude; f->baroDist = f->dist; f->baroT = t; f->hasBaro = 1; return; }
    double dd = f->dist - f->baroDist;
    if (dd > 30) {
        double g = clampd((relAltitude - f->baroAlt) / dd, -0.2, 0.2);
        f->grade += (g - f->grade) * 0.35;
        f->baroAlt = relAltitude; f->baroDist = f->dist; f->baroT = t;
    } else if (t - f->baroT > 20) {
        f->baroAlt = relAltitude; f->baroDist = f->dist; f->baroT = t;  // dung lau: lam moi moc
        f->grade *= 0.5;
    }
}
