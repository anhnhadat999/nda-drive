// Cau noi WebAssembly: trinh duyet <-> loi C dung chung voi iOS/Android (PASynth, PAFusion, PALearn)
#include <string.h>
#include <math.h>
#include "PASynth.h"
#include "PAFusion.h"
#include "PALearn.h"
#define EXPORT __attribute__((visibility("default")))
static PASynth S; static PAFusion F; static PALearn L;
static int learnEnabled = 1, testMode = 0;
static double speedTrim = 0, learnLastT = 0, testPrev = 0, lastImuT = -100, lastGpsT = -100, lastGpsV = -1;
static float buf[4096];
static double st[32];

static void push_learn(void) {
    for (int i = 0; i < PAL_BINS && i < 5; i++) S.learnCap[i] = fmax(L.accPeak[i], L.accP95[i]);
    S.learnSport = pal_sport(&L);
    S.learnOn = learnEnabled && pal_confidence(&L) > 0.05;
}
EXPORT void nda_init(void) { pa_init(&S); paf_init(&F); pal_init(&L); push_learn(); }
EXPORT int nda_preset_count(void) { return PA_PRESET_COUNT; }
EXPORT const char *nda_preset_key(int i) { return PA_PRESETS[i].key; }
EXPORT const char *nda_preset_name(int i) { return PA_PRESETS[i].name; }
EXPORT const char *nda_preset_car(int i) { return PA_PRESETS[i].car; }
EXPORT double nda_preset_info(int i, int k) {
    const PAPreset *p = &PA_PRESETS[i];
    switch (k) { case 0: return p->cyl; case 1: return p->redline; case 2: return p->turbo; case 3: return p->intake; case 4: return p->vtec; case 5: return p->idle; }
    return 0;
}
EXPORT void nda_set_params(int preset, double vol, double tone, int pops, int shiftPop, int autoVol, int rearFx, double rearAmt, double subAmt,
                           double growl, double crisp, double perfCap, double perfKnee, double interior, double mech, int learn, double trim, double resp) {
    S.presetIndex = preset; S.volume = vol; S.toneAmt = tone; S.pops = pops; S.shiftPop = shiftPop; S.autoVol = autoVol; S.rearFx = rearFx;
    S.rearAmt = rearAmt; S.subAmt = subAmt; S.growl = growl; S.crisp = crisp; S.perfCap = perfCap; S.perfKnee = perfKnee; S.interior = interior; S.mech = mech;
    learnEnabled = learn; speedTrim = trim; F.sigScale = resp; push_learn();
}
EXPORT void nda_set_mute(int m) { S.mute = m; }
EXPORT void nda_set_lead(double s) { S.leadS = s; }
EXPORT void nda_engine_start(void) { S.requestStart = 1; }
EXPORT void nda_engine_stop(void) { S.requestStop = 1; }
EXPORT void nda_set_test(int on, double kmh) {
    testMode = on;
    if (on) { S.gpsAccel = (kmh - testPrev) / 0.1 * 0.3 + S.gpsAccel * 0.7; testPrev = kmh; S.gpsSpeed = kmh; S.gpsAge = 0; }
}
// gia toc tuyen tinh (m/s2), trong luc HUONG XUONG, con quay (rad/s), t (s)
EXPORT void nda_imu(double ax, double ay, double az, double gx, double gy, double gz, double rx, double ry, double rz, double t) {
    double ua[3] = {ax, ay, az}, gr[3] = {gx, gy, gz}, rr[3] = {rx, ry, rz};
    paf_imu(&F, ua, gr, rr, t);
    lastImuT = t;
    double ldt = learnLastT > 0 ? t - learnLastT : 0.01; learnLastT = t;
    if (learnEnabled) pal_update(&L, F.v * 3.6, F.aLongRaw, ldt, F.calibrated && F.gpsOk && !F.stationary);
    static int n = 0; if (++n % 100 == 0) push_learn();
    if (!testMode) {
        double tr = 1.0 + speedTrim;
        S.gpsSpeed = (F.gpsOk || F.calibrated || F.stationary) ? F.v * 3.6 * tr : -1;
        S.gpsAccel = F.a * 3.6 * tr; S.grade = F.grade; S.gpsAge = 0;
    }
}
EXPORT void nda_gps(double speed, double acc, double course, double t) {
    paf_gps(&F, speed, acc, course, t);
    // Trinh duyet khong cho doc cam bien chuyen dong (vd Safari bi tu choi quyen): dua thang GPS vao dong co gia lap
    if (!testMode && t - lastImuT > 1.0 && speed >= 0 && speed < 120) {
        double tr = 1.0 + speedTrim, dt = t - lastGpsT;
        double a = (lastGpsV >= 0 && dt > 0.3 && dt < 5) ? (speed - lastGpsV) / dt : 0;
        S.gpsSpeed = speed * 3.6 * tr; S.gpsAccel = fmax(-30, fmin(30, a * 3.6 * tr)); S.gpsAge = 0;
    }
    lastGpsT = t; lastGpsV = speed;
}
EXPORT int nda_imu_ok(double t) { return t - lastImuT < 1.0; }
EXPORT void nda_step(double dt) { pa_step(&S, dt); }
EXPORT float *nda_render(int n, double sr) { if (n > 4096) n = 4096; pa_render(&S, buf, n, sr); return buf; }
EXPORT double *nda_state(void) {
    double s[24] = { F.v * 3.6, F.calibrated ? F.aLongRaw : F.a, F.calibrated, F.stationary, F.gpsOk, F.calProgress, F.theta * 180 / M_PI,
        F.dlyN > 6 ? F.gpsDelay : 0, F.calByTurn, F.grade * 100, S.speed, S.rpm, S.gear + 1, S.load, (double)S.state, S.leadS,
        pal_sport(&L), pal_confidence(&L), pal_zero_to_100(&L), L.distKm, (double)L.samples, F.quality, F.gpsTotal > 0 ? (double)F.gpsRepTotal / F.gpsTotal : 0, 0 };
    memcpy(st, s, sizeof s); return st;
}
EXPORT void *nda_learn_ptr(void) { return &L; }
EXPORT int nda_learn_size(void) { return sizeof(PALearn); }
EXPORT void nda_learn_loaded(void) { push_learn(); }
EXPORT void nda_learn_reset(void) { pal_init(&L); push_learn(); }
EXPORT double nda_cal(int k) { return k == 0 ? F.calibrated : (k == 1 ? F.theta : F.gCal[k - 2]); }
EXPORT void nda_cal_set(double th, double gx, double gy, double gz) { double g[3] = {gx, gy, gz}; paf_load_calibration(&F, th, g); }
EXPORT void nda_cal_reset(void) { double sv = F.sigScale; paf_init(&F); F.sigScale = sv; }
