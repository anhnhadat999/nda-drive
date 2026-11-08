// PASynth - bo tao am thanh dong co (thuan C, chay tren luong audio)
#ifndef PASYNTH_H
#define PASYNTH_H

#ifdef __cplusplus
extern "C" {
#endif

#define PA_MAX_CYL 12

typedef struct {
    const char *key;
    const char *name;   // ten kieu dong co (UTF-8)
    const char *car;    // goi y xe (UTF-8)
    int cyl;
    double idle, redline, power;
    double uneven[PA_MAX_CYL];
    double half;
    double res[3][3];   // {tan so, Q, he so}
    double tone, noise, drive, lp0, lp1;
    int turbo;
    double decay, popK, vtec;
    double intake;      // tieng hut gio (0 = khong co)
} PAPreset;

extern const PAPreset PA_PRESETS[];
extern const int PA_PRESET_COUNT;
int pa_preset_index(const char *key);

typedef enum { PA_OFF = 0, PA_STARTING, PA_RUNNING, PA_STOPPING } PAState;

typedef struct {
    // ---- dieu khien (ghi tu luong chinh) ----
    volatile int presetIndex;
    volatile double volume;       // 0..1
    volatile double toneAmt;      // 0..1
    volatile int pops, shiftPop;
    volatile double gpsSpeed;     // km/h, -1 = chua co
    volatile double gpsAccel;     // km/h/s
    volatile double gpsAge;       // giay ke tu ban tin GPS cuoi (luong audio tu cong them)
    volatile int requestStart, requestStop;

    // ---- trang thai (chi luong audio ghi; luong chinh chi doc de hien thi) ----
    volatile PAState state;
    volatile double speed, rpm;
    volatile int gear;
    volatile double load, boost;

    // noi bo
    double stateT, accel, cut, master;
    double ph, phHalf, env, rpmA, loadA, lpY, lpPop, popEnv, popAmp;
    double whPh, bov, bovLp, noiseLp;
    double svfLow[3], svfBand[3], intLow, intBand;
    int cylIdx, popReq, bovPending;
    unsigned int rng;
} PASynth;

void pa_init(PASynth *s);
// Tao n mau mono vao out (ghi de). sr = tan so lay mau.
void pa_render(PASynth *s, float *out, int n, double sr);

#ifdef __cplusplus
}
#endif
#endif
