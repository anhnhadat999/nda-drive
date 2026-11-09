#include "PAAcoustic.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

const double PAA_BAND_HZ[PAA_BANDS] = {40,50,63,80,100,125,160,200,250,315,400,500,630,800,1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000};
const double PAA_OCT_HZ[PAA_OCT] = {63,125,250,500,1000,2000,4000,8000,16000};

int paa_make_sweep(float *out, int maxN, double sr, double f1, double f2, double T, double amp) {
    int n = (int)(T * sr); if (n > maxN) n = maxN;
    double K = T * 2 * M_PI * f1 / log(f2 / f1), L = T / log(f2 / f1);
    int fade = (int)(0.05 * sr);
    for (int i = 0; i < n; i++) {
        double t = i / sr, g = 1;
        if (i < fade) g = 0.5 - 0.5 * cos(M_PI * i / fade);
        if (i > n - fade) g = 0.5 - 0.5 * cos(M_PI * (n - i) / fade);
        out[i] = (float)(amp * g * sin(K * (exp(t / L) - 1)));
    }
    return n;
}

// Tim do tre: (1) tim thoi diem nang luong tang vot so voi on nen (khoi 5 ms) trong 0..3 s
// - CarPlay khong day tre 1-2 s; (2) tuong quan cheo day du quanh do (+-40 ms).
// Neu khong thay diem tang vot thi tuong quan cheo tho trong 0..600 ms nhu cu.
static int find_lag(const float *x, int nS, const float *y, int nY, int playStart, double sr) {
    int B = (int)(0.005 * sr); if (B < 8) B = 8;
    double ne = 0; int nn = playStart - (int)(0.1 * sr);
    for (int i = 0; i < nn; i++) ne += (double)y[i] * y[i];
    double nb = nn > 0 ? ne / nn * B : 1e-12;
    int coarse = -1, maxL = (int)(3.0 * sr);
    for (int L = 0; L + 4 * B < maxL && playStart + L + 4 * B < nY; L += B) {
        double e = 0;   // 4 khoi lien tiep deu vuot on nen 10 dB
        int ok = 1;
        for (int k = 0; k < 4 && ok; k++) {
            e = 0; for (int i = 0; i < B; i++) { double v = y[playStart + L + k * B + i]; e += v * v; }
            if (e < nb * 10) ok = 0;
        }
        if (ok) { coarse = L; break; }
    }
    int len = (int)(1.0 * sr); if (len > nS) len = nS;
    int lo, hi, step;
    if (coarse >= 0) { lo = coarse - (int)(0.04 * sr); hi = coarse + (int)(0.04 * sr); step = 1; }
    else { lo = 0; hi = (int)(0.6 * sr); step = 4; }
    if (lo < 0) lo = 0;
    int best = lo; double bv = -1;
    for (int L = lo; L <= hi; L += step) {
        int base = playStart + L; if (base + len >= nY) break;
        double s = 0; for (int i = 0; i < len; i += 2) s += (double)x[i] * y[base + i];
        if (fabs(s) > bv) { bv = fabs(s); best = L; }
    }
    if (step > 1) {   // tinh chinh
        int c = best; for (int L = c - step; L <= c + step; L++) {
            if (L < 0) continue; int base = playStart + L; if (base + len >= nY) continue;
            double s = 0; for (int i = 0; i < len; i += 2) s += (double)x[i] * y[base + i];
            if (fabs(s) > bv) { bv = fabs(s); best = L; }
        }
    }
    return best;
}

void paa_analyze(const float *x, int nS, const float *y, int nY, int playStart, double sr,
                 double f1, double f2, double T, PAAcousticResult *r) {
    memset(r, 0, sizeof *r);
    int lag = find_lag(x, nS, y, nY, playStart, sr);
    r->latencyMs = lag * 1000.0 / sr;
    // on nen: doan im lang truoc khi phat
    double ne = 0; int nn = playStart > (int)(0.1 * sr) ? playStart - (int)(0.1 * sr) : 0;
    for (int i = 0; i < nn; i++) ne += (double)y[i] * y[i];
    double noiseRms = nn > 0 ? sqrt(ne / nn) : 1e-9;
    r->noiseDbfs = 20 * log10(noiseRms + 1e-12);
    double sigE = 0; int ok[PAA_BANDS];
    double lnr = log(f2 / f1);
    for (int b = 0; b < PAA_BANDS; b++) {
        double lo = PAA_BAND_HZ[b] / pow(2, 1.0 / 6), hi = PAA_BAND_HZ[b] * pow(2, 1.0 / 6);
        ok[b] = lo >= f1 * 0.85 && hi <= f2;   // dai nam tron trong vung quet (vd mic xe 16 kHz chi do toi ~7 kHz)
        if (lo < f1) lo = f1; if (hi > f2) hi = f2;
        if (hi <= lo) { ok[b] = 0; r->respDb[b] = r->absDb[b] = 0; continue; }
        // doan thoi gian ma tieng quet di qua dai nay
        int i0 = (int)(T * log(lo / f1) / lnr * sr), i1 = (int)(T * log(hi / f1) / lnr * sr);
        if (i1 > nS) i1 = nS;
        double ex = 0, ey = 0;
        for (int i = i0; i < i1; i++) {
            int j = playStart + lag + i; if (j >= nY) break;
            ex += (double)x[i] * x[i]; ey += (double)y[j] * y[j];
        }
        // tru nang luong nhieu nen tuong ung
        double nE = noiseRms * noiseRms * (i1 - i0);
        double eyc = ey - nE; if (eyc < ey * 0.01) eyc = ey * 0.01;
        r->absDb[b] = 10 * log10((eyc + 1e-20) / (ex + 1e-20));
        sigE += ey;
    }
    int ns = (int)(T * sr);
    r->snrDb = 10 * log10((sigE / (ns > 0 ? ns : 1) + 1e-20) / (noiseRms * noiseRms + 1e-20));
    // chuan hoa quanh dai giua 200 Hz - 4 kHz
    double ref = 0; int rc = 0;
    for (int b = 0; b < PAA_BANDS; b++) if (ok[b] && PAA_BAND_HZ[b] >= 200 && PAA_BAND_HZ[b] <= 4000) { ref += r->absDb[b]; rc++; }
    ref /= (rc ? rc : 1);
    for (int b = 0; b < PAA_BANDS; b++) r->respDb[b] = ok[b] ? r->absDb[b] - ref : 0;
    // bo bu theo quang tam: trung binh cac dai 1/3 trong +-1/2 quang tam, dao dau, gioi han +-6 dB, giam 30% (bu nhe)
    for (int o = 0; o < PAA_OCT; o++) {
        double lo = PAA_OCT_HZ[o] / sqrt(2), hi = PAA_OCT_HZ[o] * sqrt(2), s = 0; int c = 0;
        for (int b = 0; b < PAA_BANDS; b++) if (ok[b] && PAA_BAND_HZ[b] >= lo && PAA_BAND_HZ[b] < hi) { s += r->respDb[b]; c++; }
        double m = c ? s / c : 0;
        double corr = -m * 0.7;
        if (corr > 6) corr = 6; if (corr < -6) corr = -6;
        if (PAA_OCT_HZ[o] >= 16000) corr = 0;       // tren 10 kHz khong do duoc tin cay
        r->corrDb[o] = corr;
    }
    r->valid = r->snrDb > 10;
}
