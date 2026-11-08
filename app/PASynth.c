// PASynth - mo phong dong co: toc do GPS -> hop so ao -> vong tua -> am thanh.
// Am thanh duoc tong hop bang toan hoc (khong dung ban ghi am cua hang xe nao).
#include "PASynth.h"
#include <math.h>
#include <string.h>

const PAPreset PA_PRESETS[] = {
  // ---- Porsche (am thanh mo phong theo chat tieng, khong phai ban ghi am) ----
  { "gt3", "911 GT3", "Porsche · Boxer 6 hút khí tự nhiên · 9.000 v/p", 6, 950, 9000, 1.12,
    {1, .84, 1.04, .86, 1.02, .82}, .32, {{150,5,.6},{620,7,.9},{2150,6,.55}}, .62, .18, 2.5, 1500, 8200, 0, .32, .8, 0, 0 },
  { "gt4rs", "718 Cayman GT4 RS", "Porsche · Boxer 6, hút gió sau lưng · 9.000 v/p", 6, 950, 9000, 1.1,
    {1, .85, 1.03, .87, 1.01, .83}, .28, {{160,5,.55},{680,7,.85},{2300,6,.6}}, .6, .2, 2.6, 1600, 8600, 0, .3, .7, 0, 1.0 },
  { "p911t", "911 Turbo S", "Porsche · Boxer 6 tăng áp kép", 6, 900, 7200, 1.3,
    {1, .86, 1.05, .88, 1.02, .85}, .36, {{105,5,.9},{380,5,.7},{1150,4,.3}}, .38, .3, 2.0, 700, 3800, 1, .45, .6, 0, 0 },
  { "c911s", "911 Carrera S", "Porsche · Boxer 6 tăng áp, ống xả thể thao", 6, 850, 7500, 1.15,
    {1.06, .8, 1.1, .82, 1.04, .8}, .42, {{115,5,.95},{420,5.5,.75},{1350,4.5,.38}}, .44, .28, 2.3, 800, 4600, 1, .5, 1.9, 0, 0 },
  { "c718s", "718 Cayman S", "Porsche · Boxer 4 tăng áp, gừ gừ lệch nhịp", 4, 900, 7500, .95,
    {1.18, .74, 1.12, .78}, .52, {{120,5,.9},{350,4.5,.7},{1050,4,.35}}, .3, .4, 2.3, 750, 4200, 1, .5, 1.5, 0, 0 },
  { "cgt", "Carrera GT", "Porsche · V10 hút khí tự nhiên, kiểu xe đua", 10, 1000, 8400, 1.25,
    {1, .93, 1.07, .9, 1.04, .96, 1.06, .91, 1.02, .97}, .14, {{185,6,.6},{520,7,.95},{1600,5,.6}}, .55, .25, 2.8, 1500, 7800, 0, .3, 1, 0, .4 },
  // ---- Cac hang khac ----
  { "v12", "V12", "kiểu Ferrari 812, Lamborghini Aventador", 12, 900, 8500, 1.15,
    {1, .98, 1.02, .99, 1.01, .98, 1, .99, 1.02, .98, 1.01, .99}, .05, {{150,5,.55},{500,7,.9},{1550,5,.55}}, .58, .14, 2.1, 1600, 7800, 0, .3, 1, 0, 0 },
  { "v10", "V10 siêu xe", "kiểu Lamborghini Huracán, Lexus LFA", 10, 1000, 8700, 1.22,
    {1, .94, 1.08, .9, 1.03, .97, 1.06, .92, 1.01, .98}, .1, {{170,6,.65},{440,6,.85},{1250,4,.45}}, .48, .2, 2.6, 1300, 6500, 0, .34, 1, 0, 0 },
  { "amg", "V8 tăng áp kép", "kiểu Mercedes-AMG", 8, 800, 7000, 1.25,
    {1.12, .76, 1.2, .82, 1.06, .74, 1.16, .86}, .45, {{88,5,1.0},{230,5,.6},{640,4,.3}}, .34, .3, 2.6, 600, 3200, 1, .55, 2.2, 0, 0 },
  { "v8", "V8 Mỹ", "kiểu Ford Mustang GT, Corvette", 8, 750, 6800, 1.0,
    {1.15, .7, 1.25, .8, 1.05, .72, 1.2, .86}, .55, {{78,5,1.0},{190,4.5,.55},{480,3.5,.22}}, .32, .28, 2.4, 520, 2600, 0, .6, 1, 0, 0 },
  { "i6", "6 máy thẳng hàng", "kiểu BMW M3, Toyota Supra", 6, 800, 7200, 1.08,
    {1, .97, 1.02, .98, 1.01, .97}, .08, {{125,5,.7},{430,6,.8},{1350,5,.4}}, .5, .22, 2.1, 1000, 5600, 1, .38, 1, 0, 0 },
  { "i5", "5 máy thẳng hàng", "kiểu Audi RS3", 5, 850, 7000, 1.05,
    {1.15, .78, 1.08, .7, .98}, .5, {{115,5,.85},{330,5,.7},{980,4,.35}}, .4, .3, 2.3, 800, 4600, 1, .48, 1.4, 0, 0 },
  { "vtec", "4 máy VTEC", "kiểu Honda S2000", 4, 900, 9000, .9,
    {1, .95, 1.04, .97}, .12, {{140,5,.75},{420,5,.7},{1300,4,.45}}, .4, .38, 2.0, 1000, 5200, 0, .36, 1, 6000, .3 },
  { "i4t", "4 máy Turbo", "kiểu Honda Civic Type R, VW Golf GTI", 4, 850, 7000, .85,
    {1, .93, 1.06, .97}, .15, {{130,5,.8},{360,4,.65},{1050,3,.3}}, .22, .5, 1.9, 900, 4200, 1, .42, 1, 0, 0 },
  { "rot", "Động cơ xoay (rotary)", "kiểu Mazda RX-7", 4, 1000, 8500, 1.0,
    {1.1, .8, 1.1, .8}, .3, {{200,4,.7},{700,4,.8},{1900,3,.6}}, .3, .7, 2.8, 1400, 6800, 1, .22, 1.6, 0, 0 },
};
const int PA_PRESET_COUNT = (int)(sizeof(PA_PRESETS) / sizeof(PA_PRESETS[0]));

static const double KMH_PER_1000[6] = {7.6, 12.8, 18.5, 24.8, 31.5, 39.5};
static const double GEAR_ACC[6] = {15, 11.5, 8.2, 6, 4.4, 3.3};

int pa_preset_index(const char *key) {
    for (int i = 0; i < PA_PRESET_COUNT; i++) if (strcmp(PA_PRESETS[i].key, key) == 0) return i;
    return 0;
}

static inline double clampd(double v, double a, double b) { return v < a ? a : (v > b ? b : v); }
static inline double frand(PASynth *s) { // 0..1
    s->rng ^= s->rng << 13; s->rng ^= s->rng >> 17; s->rng ^= s->rng << 5;
    return (s->rng & 0xFFFFFF) / 16777216.0;
}

void pa_init(PASynth *s) {
    memset(s, 0, sizeof(*s));
    s->volume = 0.7; s->toneAmt = 0.5; s->pops = 1; s->shiftPop = 1;
    s->gpsSpeed = -1; s->gpsAge = 99; s->loadA = 0.2; s->load = 0.2;
    s->rng = 0x9E3779B9u;
}

static double learned_cap(PASynth *s, double v) {
    static const double MID[5] = {10, 35, 65, 95, 130};
    if (v <= MID[0]) return s->learnCap[0];
    for (int i = 0; i < 4; i++) if (v <= MID[i + 1]) { double w = (v - MID[i]) / (MID[i + 1] - MID[i]); return s->learnCap[i] * (1 - w) + s->learnCap[i + 1] * w; }
    return s->learnCap[4];
}

static double rpm_at(double speed, int g) { return speed / KMH_PER_1000[g] * 1000.0; }

// ---------- vat ly (moi buffer) ----------
static void physics(PASynth *s, const PAPreset *p, double dt) {
    if (s->requestStart) {
        s->requestStart = 0;
        if (s->state == PA_OFF || s->state == PA_STOPPING) { s->state = PA_STARTING; s->stateT = 0; }
    }
    if (s->requestStop) {
        s->requestStop = 0;
        if (s->state != PA_OFF) { s->state = PA_STOPPING; s->stateT = 0; }
    }
    s->stateT += dt;
    s->gpsAge += dt;

    // toc do muc tieu: GPS + du doan theo gia toc (GPS tre ~1 giay)
    double target = 0, accIn = 0;
    if (s->gpsSpeed >= 0 && s->gpsAge < 4) {
        double ahead = s->gpsAge < 0.5 ? s->gpsAge : 0.5;
        target = s->gpsSpeed + s->gpsAccel * ahead;
        accIn = s->gpsAccel;
        if (target < 0) target = 0;
    } else if (s->gpsSpeed >= 0) {
        target = s->speed * 0.98; // mat tin hieu: giu toc do, giam dan
    }
    // bam sat toc do da hop nhat (gioi han de khong giat khi du lieu nhay)
    double dv = clampd((target - s->speed) * fmin(1, dt * 12), -45 * dt, 35 * dt);
    s->speed = fmax(0, s->speed + dv);
    s->accel += (accIn - s->accel) * fmin(1, dt * 8);

    // ---- Do dap ga theo vat ly: luc can dat duoc gia toc hien tai ----
    double v = s->speed / 3.6, aMs = s->accel / 3.6;
    double aReq = aMs + 0.12 /*ma sat lan*/ + 0.5 * 1.2 * 0.75 * v * v / 1800.0 /*gio*/ + 9.81 * s->grade /*doc*/;
    double rpmN0 = fmin(1, s->rpm / p->redline);
    double tq = 0.72 + 0.28 * sin(M_PI * rpmN0);                       // duong cong momen xoan
    double aMax = GEAR_ACC[s->gear] / 3.6 * p->power * tq * 1.8;       // gia toc toi da o so hien tai (xe the thao)
    if (s->learnOn && s->learnCap[1] > 0.3)                             // da hoc: dung do boc THAT cua xe
        aMax = learned_cap(s, s->speed) * (0.85 + 0.15 * tq / 0.86) * 1.05;
    double load;
    if (s->speed < 1) load = aMs > 0.3 ? clampd(aReq / aMax, 0.3, 1) : 0.1;   // dung yen / bat dau lan banh
    else if (aMs < -0.6 && aReq < 0.05) load = 0;                              // nha ga, phanh: dong co ghim
    else load = clampd(aReq / aMax, 0.12, 1);
    if (s->load > 0.6 && load < 0.1 && s->boost > 0.45) s->bovPending = 1;
    s->load += (load - s->load) * fmin(1, dt * (load > s->load ? 6 : 5));
    if (s->blip > 0) { s->blip -= dt; if (s->load < 0.7) s->load = 0.7; }      // ro ga khi ve so
    if (p->turbo) {
        double b = s->load * fmin(1, s->rpm / (p->redline * .55));
        s->boost += (b - s->boost) * fmin(1, dt * (b > s->boost ? 1.8 : 4));
    } else s->boost = 0;

    // hop so
    s->shiftT += dt;
    if (s->speed < 3) s->gear = 0;
    double shiftK = 0.42 + 0.58 * s->load;
    if (s->learnOn) shiftK *= 0.88 + 0.24 * s->learnSport;              // lai the thao: giu so lau hon
    if (shiftK > 1) shiftK = 1;
    double up = p->idle + (p->redline * 0.96 - p->idle) * shiftK;
    if (s->gear < 5 && rpm_at(s->speed, s->gear) > up && s->shiftT > 0.6) {
        s->gear++; s->shiftT = 0;
        s->cut = 0.11;
        if (s->shiftPop && s->load > 0.55) s->popReq = 1;
    } else if (s->gear > 0 && rpm_at(s->speed, s->gear) < fmax(p->idle * 1.35, up * 0.42) && s->shiftT > 0.6) {
        s->gear--; s->shiftT = 0;
        if (s->load < 0.15 && s->speed > 15) s->blip = 0.16;          // ve so co ro ga (rev-match)
    } else if (s->gear > 0 && s->load > 0.88 && s->shiftT > 0.5 &&
               rpm_at(s->speed, s->gear - 1) < p->redline * 0.86 && rpm_at(s->speed, s->gear) < p->redline * 0.55) {
        s->gear--; s->shiftT = 0;                                       // kickdown: dap sau -> tut so
    }
    if (s->cut > 0) s->cut = fmax(0, s->cut - dt);

    // vong tua
    double rt = 0, k = 7;
    switch (s->state) {
        case PA_OFF: rt = 0; k = 5; break;
        case PA_STOPPING: rt = 0; k = 2.5; if (s->rpm < 30) { s->state = PA_OFF; s->rpm = 0; } break;
        case PA_STARTING: {
            double t = s->stateT;
            if (t < 0.8) rt = 260 + 60 * sin(t * 40);                         // de may
            else rt = p->idle * (1 + 1.4 * fmax(0, sin((t - 0.8) / 0.4 * M_PI))); // rit ga khi no
            k = 6;
            if (t > 1.6) s->state = PA_RUNNING;
            break;
        }
        case PA_RUNNING: {
            double wheel = rpm_at(s->speed, s->gear);
            double slip = s->gear == 0 ? p->idle + fmax(0, s->load - 0.2) * 2400 * (1 - fmin(1, s->speed / 15)) : 0;
            rt = fmax(fmax(p->idle + (frand(s) - .5) * 18, wheel), slip);
            if (s->blip > 0) rt *= 1.08;
            rt = fmin(rt, p->redline * 1.01);
            k = (rt < s->rpm - 400 && s->cut > 0) ? 18 : 7;
            break;
        }
    }
    s->rpm += (rt - s->rpm) * fmin(1, dt * k);
    if (s->state == PA_OFF && s->rpm < 30) s->rpm = 0;
}

// ---------- tong hop am thanh ----------
void pa_render(PASynth *s, float *out, int n, double sr) {
    int pi = s->presetIndex; if (pi < 0 || pi >= PA_PRESET_COUNT) pi = 0;
    const PAPreset *p = &PA_PRESETS[pi];
    double dt = n / sr;
    physics(s, p, dt);

    double targetMaster = s->volume * 0.9 * (s->autoVol ? 1.0 + 0.5 * fmin(s->speed, 120) / 120.0 : 1.0);
    double rpmT = s->rpm, loadT = (s->state == PA_RUNNING) ? s->load : 0.15;
    if (s->state == PA_STARTING && s->stateT > 0.8) loadT = 0.6;
    double rpm0 = s->rpmA, load0 = s->loadA;
    double toneK = 0.6 + s->toneAmt * 0.9;
    double tone = s->toneAmt;
    if (s->bovPending && p->turbo) { s->bov = 1; s->bovPending = 0; }
    if (s->popReq) { s->popEnv = 1; s->popAmp = 0.9 + 0.8 * frand(s); s->popReq = 0; }

    if (s->state == PA_OFF && s->rpmA < 30 && s->popEnv < 0.001 && s->bov < 0.001) {
        memset(out, 0, sizeof(float) * n);
        s->rpmA = 0; s->env = 0;
        return;
    }
    const double TWO_PI = 6.283185307179586;
    for (int i = 0; i < n; i++) {
        double kk = (i + 1.0) / n;
        double rpmA = rpm0 + (rpmT - rpm0) * kk;
        double loadA = load0 + (loadT - load0) * kk;
        s->master += (targetMaster - s->master) * 0.0005;
        double rpmN = fmin(1, rpmA / p->redline);
        double vt = p->vtec > 0 ? clampd((rpmA - p->vtec + 250) / 450, 0, 1) : 0;
        double f = rpmA / 60.0 * p->cyl / 2.0;
        int cutting = s->cut > 0;

        s->ph += f / sr;
        if (s->ph >= 1) {
            s->ph -= 1;
            s->cylIdx = (s->cylIdx + 1) % p->cyl;
            int over = loadA < 0.06;
            double a = p->uneven[s->cylIdx] * (over ? 0.22 : 0.32 + 0.68 * loadA);
            if (cutting) a *= 0.05;
            if (a > s->env) s->env = a;
            if (over && s->pops && rpmA > 2300 && frand(s) < 0.035 * p->popK * (1 + rpmN)) {
                s->popEnv = 1;
                s->popAmp = 0.5 + frand(s) * (frand(s) < .15 ? 1.6 : .7);
            }
        }
        if (f > 0) s->env *= exp(-f / (sr * p->decay));
        double nz = frand(s) * 2 - 1;
        s->noiseLp += 0.25 * (nz - s->noiseLp);
        double exc = s->env * (0.7 + p->noise * toneK * s->noiseLp * 2.2);

        double y = 0;
        for (int r = 0; r < 3; r++) {
            double fc = p->res[r][0] * (1 + 0.18 * rpmN) * (1 + 0.28 * vt);
            if (fc > sr / 7) fc = sr / 7;
            double F = 2 * sin(M_PI * fc / sr);
            double q = 1.0 / p->res[r][1];
            s->svfLow[r] += F * s->svfBand[r];
            double high = exc - s->svfLow[r] - q * s->svfBand[r];
            s->svfBand[r] += F * high;
            y += s->svfBand[r] * p->res[r][2] * (r == 0 ? 1 : toneK * (1 + 0.7 * vt));
        }
        if (p->intake > 0) {
            // tieng hut gio: nhieu loc thong dai quanh boi so cua tan so no, manh khi dap ga
            double fi = f * 3.0; if (fi < 280) fi = 280; if (fi > 2600) fi = 2600;
            double Fi = 2 * sin(M_PI * fi / sr);
            s->intLow += Fi * s->intBand;
            double hi = nz * (0.35 + s->env) - s->intLow - 0.3 * s->intBand;
            s->intBand += Fi * hi;
            y += s->intBand * p->intake * 0.5 * loadA * loadA * toneK;
        }
        s->phHalf += f / (2 * sr); if (s->phHalf >= 1) s->phHalf -= 1;
        double saw = s->ph * 2 - 1;
        y += (saw * p->tone * 0.12 * toneK + sin(s->phHalf * TWO_PI) * p->half * 0.18) * (0.35 + 0.65 * loadA) * (cutting ? .2 : 1);

        double lpF = p->lp0 + (p->lp1 - p->lp0) * (0.35 * rpmN + 0.65 * loadA) * (0.7 + 0.5 * tone) * (1 + 0.6 * vt);
        double a1 = 1 - exp(-TWO_PI * lpF / sr);
        s->lpY += a1 * (y - s->lpY);
        double dr = p->drive * (0.55 + 0.9 * loadA) * (0.8 + 0.4 * tone) * (1 + 0.3 * vt);
        double o = tanh(s->lpY * dr * 3) / tanh(dr) * 0.55;

        if (s->popEnv > 0.001) {
            s->popEnv *= exp(-1 / (sr * 0.028));
            s->lpPop += 0.18 * (nz - s->lpPop);
            o += tanh(s->lpPop * s->popEnv * s->popAmp * 4) * 0.5;
        }
        if (p->turbo) {
            double wf = 1800 + 5200 * s->boost;
            s->whPh += wf / sr; if (s->whPh >= 1) s->whPh -= 1;
            o += sin(s->whPh * TWO_PI) * 0.018 * s->boost * s->boost;
            if (s->bov > 0.001) {
                s->bov *= exp(-1 / (sr * 0.32));
                s->bovLp += 0.5 * (nz - s->bovLp);
                o += (nz - s->bovLp) * s->bov * 0.22;
            }
        }
        if (s->rearFx) {
            // Tieng tu ong xa phia sau: cat bot tieng rit cao (than xe chan), them vang ngan cua khoang xe
            // (2 duong tre 7 ms va 13 ms), giam hoi tieng trau phia truoc -> nghe "o sau lung".
            s->rLp += (o - s->rLp) * 0.22;                     // ~2 kHz
            s->rLp2 += (s->rLp - s->rLp2) * 0.5;
            int n7 = (int)(0.007 * sr), n13 = (int)(0.013 * sr);
            if (n13 > 2000) n13 = 2000;
            double d7 = s->dly[(s->dIdx - n7 + 2048) & 2047], d13 = s->dly[(s->dIdx - n13 + 2048) & 2047];
            double wet = s->rLp2 * 0.78 + d7 * 0.28 + d13 * 0.20;
            s->dly[s->dIdx] = (float)(s->rLp2 + d13 * 0.25);
            s->dIdx = (s->dIdx + 1) & 2047;
            o = wet * 1.15;
        }
        o *= s->master;
        out[i] = (float)tanh(o * 1.2); // gioi han an toan
        s->rpmA = rpmA; s->loadA = loadA;
    }
}
