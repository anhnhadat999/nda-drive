// Cau noi JNI: Kotlin <-> loi C dung chung voi iOS (PASynth, PAFusion, PALearn)
#include <jni.h>
#include <string.h>
#include <math.h>
#include "PASynth.h"
#include "PAFusion.h"
#include "PALearn.h"

static PASynth S;
static PAFusion F;
static PALearn L;
static int learnEnabled = 1, testMode = 0, feed = 1;
static double speedTrim = 0, learnLastT = 0, testV = 0, testPrev = 0;

#define FN(name) Java_com_ndarealty_ndadrive_Core_##name

static void push_learn(void) {
    for (int i = 0; i < PAL_BINS && i < 5; i++) S.learnCap[i] = fmax(L.accPeak[i], L.accP95[i]);
    S.learnSport = pal_sport(&L);
    S.learnOn = learnEnabled && pal_confidence(&L) > 0.05;
}

JNIEXPORT void JNICALL FN(init)(JNIEnv *e, jclass c) {
    pa_init(&S); paf_init(&F); pal_init(&L); push_learn();
}

JNIEXPORT jint JNICALL FN(presetCount)(JNIEnv *e, jclass c) { return PA_PRESET_COUNT; }
JNIEXPORT jstring JNICALL FN(presetKey)(JNIEnv *e, jclass c, jint i) { return (*e)->NewStringUTF(e, PA_PRESETS[i].key); }
JNIEXPORT jstring JNICALL FN(presetName)(JNIEnv *e, jclass c, jint i) { return (*e)->NewStringUTF(e, PA_PRESETS[i].name); }
JNIEXPORT jstring JNICALL FN(presetCar)(JNIEnv *e, jclass c, jint i) { return (*e)->NewStringUTF(e, PA_PRESETS[i].car); }

JNIEXPORT void JNICALL FN(setParams)(JNIEnv *e, jclass c, jint preset, jdouble vol, jdouble tone, jboolean pops, jboolean shiftPop,
        jboolean autoVol, jboolean rearFx, jdouble rearAmt, jdouble subAmt, jdouble growl, jdouble crisp, jdouble perfCap, jdouble perfKnee, jdouble interior, jdouble mech, jboolean learn, jdouble trim, jdouble resp) {
    S.presetIndex = preset; S.volume = vol; S.toneAmt = tone; S.pops = pops; S.shiftPop = shiftPop;
    S.autoVol = autoVol; S.rearFx = rearFx; S.rearAmt = rearAmt; S.subAmt = subAmt; S.growl = growl; S.crisp = crisp; S.perfCap = perfCap; S.perfKnee = perfKnee; S.interior = interior; S.mech = mech;
    learnEnabled = learn; speedTrim = trim; F.sigScale = resp; push_learn();
}
JNIEXPORT void JNICALL FN(setLead)(JNIEnv *e, jclass c, jdouble s) { S.leadS = s; }
JNIEXPORT void JNICALL FN(engineStart)(JNIEnv *e, jclass c) { S.requestStart = 1; }
JNIEXPORT void JNICALL FN(engineStop)(JNIEnv *e, jclass c) { S.requestStop = 1; }
JNIEXPORT void JNICALL FN(setTest)(JNIEnv *e, jclass c, jboolean on, jdouble kmh) {
    testMode = on;
    if (on) { S.gpsAccel = (kmh - testPrev) / 0.1 * 0.3 + S.gpsAccel * 0.7; testPrev = kmh; S.gpsSpeed = kmh; S.gpsAge = 0; }
}

// Mau cam bien: gia toc tuyen tinh (m/s2), trong luc HUONG XUONG (don vi bat ky), con quay (rad/s), thoi gian (s)
JNIEXPORT void JNICALL FN(imu)(JNIEnv *e, jclass c, jdouble ax, jdouble ay, jdouble az, jdouble gx, jdouble gy, jdouble gz,
        jdouble rx, jdouble ry, jdouble rz, jdouble t) {
    double ua[3] = {ax, ay, az}, gr[3] = {gx, gy, gz}, rr[3] = {rx, ry, rz};
    paf_imu(&F, ua, gr, rr, t);
    double ldt = learnLastT > 0 ? t - learnLastT : 0.01; learnLastT = t;
    if (learnEnabled) pal_update(&L, F.v * 3.6, F.aLongRaw, ldt, F.calibrated && F.gpsOk && !F.stationary);
    static int n = 0; if (++n % 100 == 0) push_learn();
    if (!testMode) {
        double trim = 1.0 + speedTrim;
        S.gpsSpeed = (F.gpsOk || F.calibrated || F.stationary) ? F.v * 3.6 * trim : -1;
        S.gpsAccel = F.a * 3.6 * trim;
        S.grade = F.grade;
        S.gpsAge = 0;
    }
}
JNIEXPORT void JNICALL FN(gps)(JNIEnv *e, jclass c, jdouble speed, jdouble acc, jdouble course, jdouble t) {
    paf_gps(&F, speed, acc, course, t);
}
JNIEXPORT void JNICALL FN(baro)(JNIEnv *e, jclass c, jdouble alt, jdouble t) { paf_baro(&F, alt, t); }

JNIEXPORT void JNICALL FN(step)(JNIEnv *e, jclass c, jdouble dt) { pa_step(&S, dt); }
JNIEXPORT void JNICALL FN(render)(JNIEnv *e, jclass c, jfloatArray buf, jint n, jdouble sr) {
    jfloat *p = (*e)->GetPrimitiveArrayCritical(e, buf, NULL);
    pa_render(&S, p, n, sr);
    (*e)->ReleasePrimitiveArrayCritical(e, buf, p, 0);
}

// Trang thai de hien thi / ghi chuyen di
JNIEXPORT void JNICALL FN(state)(JNIEnv *e, jclass c, jdoubleArray out) {
    double s[24] = {
        F.v * 3.6, F.calibrated ? F.aLongRaw : F.a, F.calibrated, F.stationary, F.gpsOk, F.calProgress, F.theta * 180 / M_PI,
        F.dlyN > 6 ? F.gpsDelay : 0, F.calByTurn, F.grade * 100,
        S.speed, S.rpm, S.gear + 1, S.load, (double)S.state, S.leadS,
        pal_sport(&L), pal_confidence(&L), pal_zero_to_100(&L), L.distKm, (double)L.samples,
        F.quality, F.gpsTotal > 0 ? (double)F.gpsRepTotal / F.gpsTotal : 0, 0 };
    (*e)->SetDoubleArrayRegion(e, out, 0, 24, s);
}

// Luu / nap ho so hoc va can chinh
JNIEXPORT jbyteArray JNICALL FN(learnGet)(JNIEnv *e, jclass c) {
    jbyteArray a = (*e)->NewByteArray(e, sizeof(PALearn));
    (*e)->SetByteArrayRegion(e, a, 0, sizeof(PALearn), (const jbyte *)&L); return a;
}
JNIEXPORT void JNICALL FN(learnSet)(JNIEnv *e, jclass c, jbyteArray a) {
    if ((*e)->GetArrayLength(e, a) != sizeof(PALearn)) return;
    (*e)->GetByteArrayRegion(e, a, 0, sizeof(PALearn), (jbyte *)&L); push_learn();
}
JNIEXPORT void JNICALL FN(learnReset)(JNIEnv *e, jclass c) { pal_init(&L); push_learn(); }
JNIEXPORT jdoubleArray JNICALL FN(calGet)(JNIEnv *e, jclass c) {
    if (!F.calibrated) return NULL;
    double v[4] = {F.theta, F.gCal[0], F.gCal[1], F.gCal[2]};
    jdoubleArray a = (*e)->NewDoubleArray(e, 4); (*e)->SetDoubleArrayRegion(e, a, 0, 4, v); return a;
}
JNIEXPORT void JNICALL FN(calSet)(JNIEnv *e, jclass c, jdouble th, jdouble gx, jdouble gy, jdouble gz) {
    double g[3] = {gx, gy, gz}; paf_load_calibration(&F, th, g);
}
JNIEXPORT void JNICALL FN(calReset)(JNIEnv *e, jclass c) { double sv = F.sigScale; paf_init(&F); F.sigScale = sv; }
