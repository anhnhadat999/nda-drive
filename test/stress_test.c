// Kiem thu suc chiu dung loi C (dung chung iOS / Android / web):
//  - 15 kieu tieng x 11 dong xe VinFast x 4 tan so lay mau x 4 co bo dem (giong cac loai may khac nhau)
//  - chuyen di gia lap day du: GPS 1 lan/giay co mat song, lap so cu, nhieu; cam bien 100 Hz co nhieu va rung
//  - du lieu xau: NaN, vo cuc, so am, so qua lon, thoi gian lui -> loi C phai tu hoi phuc, khong treo, khong NaN
//  - do toc do xu ly (bao nhieu lan nhanh hon thoi gian thuc)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include "../app/PASynth.h"
#include "../app/PAFusion.h"
#include "../app/PALearn.h"

static unsigned rs = 12345;
static double rnd(void) { rs = rs * 1103515245u + 12345u; return ((rs >> 8) & 0xFFFFFF) / 16777216.0; }
static double gauss(void) { double u = rnd() + 1e-12, v = rnd(); return sqrt(-2 * log(u)) * cos(2 * M_PI * v); }

typedef struct { const char *id; double hp, kg, t100; } Car;
static const Car CARS[] = { {"vf3",43,1190,14},{"vf5",134,1360,10.9},{"vfe34",147,1490,9},{"vf6-eco",174,1960,9.5},{"vf6-plus",201,2020,8.9},
    {"vf7-eco",201,2085,9.5},{"vf7-plus",349,2205,5.8},{"vf8-eco",349,2460,5.9},{"vf8-plus",402,2600,5.5},{"vf9-eco",402,2830,6.5},{"vf9-plus",402,2900,6.5} };
#define NCARS (int)(sizeof CARS / sizeof CARS[0])

// toc do muc tieu theo thoi gian (km/h): ket xe, tang toc manh, cao toc, phanh gap, dung
static double profile(double t) {
    double c = fmod(t, 300);
    if (c < 20) return 0;
    if (c < 60) return 25 + 15 * sin(c * 0.3);           // ket xe
    if (c < 70) return fmin(100, (c - 60) * 16);          // dap het ga
    if (c < 160) return 100 + 15 * sin(c * 0.05);         // cao toc
    if (c < 166) return fmax(0, 100 - (c - 160) * 18);   // phanh gap
    if (c < 200) return 0;
    if (c < 260) return 50 + 10 * sin(c * 0.2);
    return fmax(0, 50 - (c - 260) * 2);
}

typedef struct { long nanOut, clipOut, badRpm, badGear, badSpeed; double maxAbs, cpu, audioSec, errSum; long errN; } Res;

static void run(int preset, const Car *car, double sr, int buf, double minutes, int garbage, Res *r) {
    PASynth S; PAFusion F; PALearn L;
    pa_init(&S); paf_init(&F); pal_init(&L);
    S.presetIndex = preset; S.volume = 0.8; S.toneAmt = 0.5; S.pops = 1; S.shiftPop = 1; S.autoVol = 1; S.rearFx = 1; S.rearAmt = 0.7;
    S.subAmt = 0.6; S.growl = 0.6; S.crisp = 0.6; S.interior = 0.4; S.mech = 0.3; S.learnOn = 0;
    double cap = 27.78 / car->t100 * 1.4; S.perfCap = cap;
    S.perfKnee = fmax(25, fmin(160, car->hp * 746 * 0.85 / (car->kg * cap) * 3.6));
    S.requestStart = 1;
    float *out = malloc(sizeof(float) * buf);
    double t = 0, v = 0, nextImu = 0, nextGps = 1, lastGpsV = 0, red = PA_PRESETS[preset].redline;
    double total = minutes * 60;
    clock_t c0 = clock();
    while (t < total) {
        double dt = buf / sr;
        // vat ly xe that
        double tgt = profile(t) / 3.6, a = fmax(-8, fmin(cap, (tgt - v) * 1.2));
        v = fmax(0, v + a * dt);
        // cam bien 100 Hz (may gan doc tren gia, co rung)
        while (nextImu <= t) {
            double ua[3] = { 0.15 * gauss(), a * 0.98 + 0.25 * gauss(), 0.3 * gauss() }, gr[3] = {0, -0.98, -0.17}, rr[3] = {0.02 * gauss(), 0.02 * gauss(), 0.02 * gauss()};
            if (garbage && rnd() < 0.002) { ua[0] = NAN; ua[1] = INFINITY; }
            if (garbage && rnd() < 0.001) { ua[1] = 1e9; rr[2] = -1e9; }
            paf_imu(&F, ua, gr, rr, nextImu);
            pal_update(&L, F.v * 3.6, F.aLongRaw, 0.01, F.calibrated && F.gpsOk && !F.stationary);
            S.gpsSpeed = (F.gpsOk || F.calibrated || F.stationary) ? F.v * 3.6 : -1;
            S.gpsAccel = F.a * 3.6; S.grade = F.grade; S.gpsAge = 0;
            nextImu += 0.01;
        }
        // GPS 1 lan/giay: mat song 5%, lap so cu 10%, nhieu
        while (nextGps <= t) {
            double gv = v + 0.3 * gauss(), tf = nextGps;
            if (rnd() < 0.10) gv = lastGpsV;
            if (garbage && rnd() < 0.02) gv = NAN;
            if (garbage && rnd() < 0.02) gv = -5;
            if (garbage && rnd() < 0.01) gv = 900;
            if (garbage && rnd() < 0.01) tf = nextGps - 30;    // thoi gian lui
            if (rnd() >= 0.05) paf_gps(&F, gv, 0.5, 0, tf);
            lastGpsV = gv; nextGps += 1;
        }
        pa_render(&S, out, buf, sr);
        for (int i = 0; i < buf; i++) {
            float x = out[i];
            if (!isfinite(x)) r->nanOut++;
            else { if (fabsf(x) > 1.0f) r->clipOut++; if (fabsf(x) > r->maxAbs) r->maxAbs = fabsf(x); }
        }
        if (!isfinite(S.rpm) || S.rpm < 0 || S.rpm > red * 1.15) r->badRpm++;
        if (S.gear < 0 || S.gear > 5) r->badGear++;
        if (!isfinite(S.speed) || S.speed < -1 || S.speed > 400) r->badSpeed++;
        if (t > 60) { r->errSum += fabs(S.speed - v * 3.6); r->errN++; }
        t += dt;
    }
    r->cpu += (double)(clock() - c0) / CLOCKS_PER_SEC;
    r->audioSec += total;
    free(out);
}

int main(int argc, char **argv) {
    double minutes = argc > 1 ? atof(argv[1]) : 2;
    int quick = argc > 2;
    const double SRS[] = { 22050, 44100, 48000, 96000 };
    const int BUFS[] = { 64, 256, 1024, 4096 };
    int fail = 0;
    // 1) moi kieu tieng x moi dong xe (48 kHz, 1024)
    printf("== 15 kieu tieng x %d dong xe VinFast (%.0f phut/lan, du lieu xau bat)\n", NCARS, minutes);
    for (int p = 0; p < PA_PRESET_COUNT; p++) {
        Res r = {0};
        for (int c = 0; c < NCARS; c++) run(p, &CARS[c], 48000, 1024, minutes, 1, &r);
        int bad = r.nanOut || r.clipOut || r.badRpm || r.badGear || r.badSpeed;
        double me = r.errSum / fmax(1, r.errN); bad |= me > 6;
        printf("%-6s NaN %ld | vuot +-1 %ld | rpm sai %ld | so sai %ld | toc do sai %ld | dinh %.2f | lech toc do TB %.1f km/h | nhanh hon thuc %.0fx %s\n",
               PA_PRESETS[p].key, r.nanOut, r.clipOut, r.badRpm, r.badGear, r.badSpeed, r.maxAbs, me, r.audioSec / fmax(1e-9, r.cpu), bad ? "LOI" : "OK");
        fail |= bad;
    }
    if (quick) { printf(fail ? "-> CO LOI\n" : "-> DAT\n"); return fail; }
    // 2) cac loai may: tan so lay mau + co bo dem
    printf("== Tan so lay mau x co bo dem (giong iPhone/Android/trinh duyet khac nhau), VF 7 Plus, tieng V8 tang ap\n");
    int amg = pa_preset_index("amg");
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) {
        Res r = {0};
        run(amg, &CARS[6], SRS[i], BUFS[j], minutes, 1, &r);
        int bad = r.nanOut || r.clipOut || r.badRpm || r.badGear || r.badSpeed;
        printf("%5.0f Hz / %4d mau: NaN %ld | vuot %ld | rpm sai %ld | nhanh hon thuc %.0fx %s\n", SRS[i], BUFS[j], r.nanOut, r.clipOut, r.badRpm,
               r.audioSec / fmax(1e-9, r.cpu), bad ? "LOI" : "OK");
        fail |= bad;
    }
    // 3) chay dai: 2 gio lien tuc
    printf("== Chay lien tuc 120 phut (VF 7 Plus, du lieu xau)\n");
    { Res r = {0}; run(amg, &CARS[6], 48000, 512, 120, 1, &r);
      int bad = r.nanOut || r.clipOut || r.badRpm || r.badGear || r.badSpeed;
      double me = r.errSum / fmax(1, r.errN); bad |= me > 6;
      printf("120 phut: NaN %ld | vuot %ld | rpm sai %ld | so sai %ld | lech toc do TB %.1f km/h | nhanh hon thuc %.0fx %s\n", r.nanOut, r.clipOut, r.badRpm, r.badGear, me, r.audioSec / fmax(1e-9, r.cpu), bad ? "LOI" : "OK");
      fail |= bad; }
    printf(fail ? "-> CO LOI\n" : "-> DAT\n");
    return fail;
}
