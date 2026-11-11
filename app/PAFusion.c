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
    f->sigScale = 1;
    f->gpsDelay = 0.5;
}

void paf_load_calibration(PAFusion *f, double theta, const double g[3]) {
    f->savedTheta = theta;
    f->savedG[0] = g[0]; f->savedG[1] = g[1]; f->savedG[2] = g[2];
    unit3(f->savedG);
    f->savedPending = 1;
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
    f->calibrated = 0; f->theta = 0; f->Sx = f->Sy = f->E = 0; f->calProgress = 0;
    f->Lx = f->Ly = f->Lc = 0; f->calByTurn = 0; f->Fvalid = 0; f->recheck = 0;
}

// Loai bo du lieu hong (NaN / vo cuc / qua lon): trinh duyet va mot so may Android co the gui NaN
static int bad3(const double v[3], double lim) { for (int i = 0; i < 3; i++) if (!isfinite(v[i]) || fabs(v[i]) > lim) return 1; return 0; }
// Tu hoi phuc neu trang thai bi hong (giu nguyen can chinh huong may)
static void heal(PAFusion *f) {
    if (isfinite(f->v) && isfinite(f->a) && isfinite(f->P00) && isfinite(f->P01) && isfinite(f->P11) && isfinite(f->b) && isfinite(f->aLp)) return;
    f->v = isfinite(f->lastGpsV) && f->lastGpsV >= 0 ? f->lastGpsV : 0; f->a = 0; f->aLp = 0; f->b = 0; f->aLongRaw = 0; f->aGps = 0;
    f->P00 = 4.0; f->P01 = 0; f->P11 = 0.25;
    if (!isfinite(f->grade)) f->grade = 0;
}

void paf_imu(PAFusion *f, const double userAcc[3], const double gravity[3], const double rot[3], double t) {
    if (!isfinite(t) || bad3(userAcc, 200) || bad3(gravity, 200) || bad3(rot, 100)) return;
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
    // May bi xoay tren gia (bam man hinh lam khop bi xoay, chinh lai goc...):
    // KHONG xoa huong da hoc, ma xoay truc tien theo con quay: dF/dt = -w x F.
    // Chi khi xoay manh lien tuc > 4 s (thao may khoi gia, cam tren tay) moi hoc lai tu dau.
    if (gm > 0.35) f->handleT += dt; else if (gm < 0.15) f->handleT = fmax(0, f->handleT - dt * 0.5);
    if (f->calibrated && f->handleT > 4.0) { reset_cal(f); f->handleT = 0; }
    if (f->calibrated && f->Fvalid && gm > 0.35) {
        double wf[3]; cross3(rot, f->F, wf);
        for (int i = 0; i < 3; i++) f->F[i] -= wf[i] * dt;
        if (!f->recheck) { f->recheck = 1; f->Lx = f->Ly = f->Lc = 0; f->Sx = f->Sy = f->E = 0; }
    }

    double e1[3], e2[3];
    basis(f->g, e1, e2);
    if (f->calibrated && f->Fvalid && (gm > 0.35 || dot3(f->g, f->gF) < cos(0.3 * M_PI / 180))) {   // goc tien theo co so moi
        memcpy(f->gF, f->g, sizeof f->g);
        double fx = dot3(f->F, e1), fy = dot3(f->F, e2);
        if (fx * fx + fy * fy > 0.04) f->theta = atan2(fy, fx);
        if (dot3(f->g, f->gCal) < cos(10 * M_PI / 180)) memcpy(f->gCal, f->g, sizeof f->g);
    }
    // dung lai can chinh da luu khi trong luc da on dinh (~0,5 s)
    f->nImu++;
    if (f->savedPending && f->nImu > 50) {
        f->savedPending = 0;
        if (dot3(f->g, f->savedG) > cos(45 * M_PI / 180)) {
            double s1[3], s2[3], Fs[3]; basis(f->savedG, s1, s2);
            for (int i = 0; i < 3; i++) Fs[i] = cos(f->savedTheta) * s1[i] + sin(f->savedTheta) * s2[i];
            double fx = dot3(Fs, e1), fy = dot3(Fs, e2);
            f->theta = atan2(fy, fx); f->calibrated = 1; f->calProgress = 1;
            if (dot3(f->g, f->savedG) < cos(12 * M_PI / 180)) f->recheck = 1;   // goc gan da doi: kiem tra lai khi vao cua
            memcpy(f->gCal, f->g, sizeof f->g);
            f->E = CAL_ENERGY;
            f->Sx = cos(f->theta) * CAL_ENERGY; f->Sy = sin(f->theta) * CAL_ENERGY;
        }
    }
    double hx = dot3(userAcc, e1), hy = dot3(userAcc, e2);
    f->hxSum += hx; f->hySum += hy; f->hN++;

    // ---- Hoc huong xe bang luc vao cua ----
    // Gia toc huong tam = v * (toc do quay quanh truc thang dung) va vuong goc voi huong tien.
    // Tuong quan gia toc ngang voi v*w cho truc NGANG xe; truc tien = truc ngang x truc len
    // (dau tu dong dung du cam bien bao gia toc theo quy uoc nao). Khong can GPS chinh xac.
    {
        double wu = -dot3(rot, f->g);                 // quay quanh truc len (+ = re trai)
        double vv = f->gpsOk ? fmax(f->v, f->lastGpsV) : f->v;
        double c = vv * wu;
        double kf = exp(-dt / 180.0);                 // quen dan sau ~3 phut
        f->Lx = f->Lx * kf; f->Ly = f->Ly * kf; f->Lc = f->Lc * kf;
        if (vv > 3 && fabs(wu) > 0.04 && fabs(wu) < 1.2 && f->moveT < 0.2) {
            f->Lx += hx * c * dt; f->Ly += hy * c * dt; f->Lc += c * c * dt;
        }
        double Lm = sqrt(f->Lx * f->Lx + f->Ly * f->Ly);
        if (!f->calibrated) f->calProgress = fmax(f->calProgress, fmin(0.95, f->Lc / 12.0));
        if (f->Lc > 12 && Lm > 0.5 * f->Lc) {
            double th = atan2(f->Lx, -f->Ly);         // e = L x len
            // GPS (neu co bang chung manh) duoc quyen dao chieu
            double sd = f->Sx * cos(th) + f->Sy * sin(th);
            if (f->E > 2 && sd < -0.5 * f->E) th += M_PI;
            if (!f->calibrated) {
                f->theta = th; f->calibrated = 1; f->calProgress = 1; f->calByTurn = 1;
                memcpy(f->gCal, f->g, sizeof f->g);
            } else {
                double d = atan2(sin(th - f->theta), cos(th - f->theta));
                if (f->recheck) { f->theta = th; f->recheck = 0; f->calByTurn = 1; }
                else if (fabs(d) < 0.6) f->theta += d * fmin(1, dt * 0.5);
            }
        }
    }

    double aLong = hx * cos(f->theta) + hy * sin(f->theta);
    f->aLongRaw = f->calibrated ? aLong - f->b : 0;

    // nhan biet dung yen: rung nho, khong xoay
    double k = fmin(1, dt / 0.6);
    double am = norm3(userAcc);
    f->accMean += (am - f->accMean) * k;
    f->accVar += ((am - f->accMean) * (am - f->accMean) - f->accVar) * k;
    f->gyrMean += (gm - f->gyrMean) * k;
    int gpsZero = f->hasGps && f->lastGpsV < 0.3 && (t - f->lastFixWall) < GPS_LOST_S;
    int stillSensor = sqrt(f->accVar) < 0.08 && f->gyrMean < 0.05 && f->accMean < (gpsZero ? 0.6 : 0.18);

    f->gpsOk = f->hasGps && (t - f->lastFixWall) < GPS_LOST_S;

    // ---- Kalman: du doan ----
    double aUse = f->calibrated ? (aLong - f->b) : f->aGps * 0.8 * exp(-fmax(0, t - f->lastFixT) / 1.2); // chua hoc truc: ngoai suy GPS, giam dan
    double sigA = (f->calibrated ? SIG_A_CAL : SIG_A_UNCAL) * (f->sigScale > 0 ? f->sigScale : 1);
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
    double aOut = f->calibrated ? (aLong - f->b) : f->aGps * exp(-fmax(0, t - f->lastFixT) / 1.2);
    if (f->stationary) aOut = 0;
    f->aLp += (aOut - f->aLp) * fmin(1, dt / 0.12);
    f->a = f->aLp;
    f->dist += f->v * dt;
    f->quality = (f->calibrated ? 0.6 : 0.3) + (f->gpsOk ? 0.4 : 0.1);
    if (f->calibrated) { for (int i = 0; i < 3; i++) f->F[i] = cos(f->theta) * e1[i] + sin(f->theta) * e2[i]; if (!f->Fvalid) memcpy(f->gF, f->g, sizeof f->g); f->Fvalid = 1; }
    else f->Fvalid = 0;
    heal(f);
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
    if (!isfinite(speed) || speed < 0 || speed > 120 || !isfinite(tFix)) return;   // >432 km/h = hong
    if (!isfinite(speedAcc)) speedAcc = -1;
    if (!isfinite(course)) course = -1;
    double now = f->t > 0 ? f->t : tFix;
    f->gpsTotal++;
    // Ban tin lap lai y het ban truoc (toc do + huong) khi xe dang chay: so cu bi giu lai, KHONG phai do moi.
    // (VF7 gui vi tri cua xe qua CarPlay, co luc giu nguyen 1-5 giay.) Bo qua de khong keo toc do ve so cu.
    if (f->hasGps && speed == f->lastGpsV && course == f->lastGpsCourse && speed > 0.3) {
        f->gpsRep++; f->gpsRepTotal++;
        if (f->gpsRep <= 6) f->lastFixWall = now;   // so cu nhung van con song GPS: khong coi la mat tin hieu (khong cap nhat toc do)
        return;
    }
    f->gpsRep = 0;

    // ---- Kalman: cap nhat bang GPS (bu do tre) ----
    double sa = speedAcc > 0 ? fmax(speedAcc, 0.5) : 0.8;   // xe gui "0,2 m/s" co dinh: khong dang tin
    double R = sa * sa * 1.3;
    f->lastFixT = f->t;
    // Tu uoc luong do tre that cua GPS: thu cac do tre 0..2 s, giu cai khop lich su cam bien nhat
    if (f->calibrated && speed > 2) {
        for (int k = 0; k < PAF_NDLY; k++) {
            int fd; double vh = hist_at(f, tFix - k * 0.2, &fd);
            if (!fd) continue;
            double e = speed - vh; f->dlyErr[k] += (e * e - f->dlyErr[k]) * 0.15;
        }
        if (++f->dlyN > 6) {
            int bk = 0; for (int k = 1; k < PAF_NDLY; k++) if (f->dlyErr[k] < f->dlyErr[bk]) bk = k;
            f->gpsDelay += (bk * 0.2 - f->gpsDelay) * 0.3;
        }
    }
    double tEff = tFix - (f->dlyN > 6 ? f->gpsDelay : 0);
    int found;
    double vRef = hist_at(f, tEff, &found);
    double before = f->v;
    kf_update(f, speed, R, found ? vRef : f->v);
    double corr = f->v - before;
    if (found) for (int n = 0; n < PAF_HIST; n++) if (f->histT[n] >= tEff) f->histV[n] += corr;

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
                if (!f->calibrated) f->calProgress = fmin(0.95, f->E / CAL_ENERGY);
                if (f->E > CAL_ENERGY && corrMag > 0.4) {
                    double th = atan2(f->Sy, f->Sx);
                    if (!f->calibrated) { f->theta = th; f->calibrated = 1; f->calProgress = 1; memcpy(f->gCal, f->g, sizeof f->g); }
                    else {
                        double d = atan2(sin(th - f->theta), cos(th - f->theta));
                        if (f->recheck) { f->theta = th; f->recheck = 0; } else f->theta += d * 0.3;
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
    heal(f);
}

void paf_baro(PAFusion *f, double relAltitude, double t) {
    if (!isfinite(relAltitude) || !isfinite(t)) return;
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
