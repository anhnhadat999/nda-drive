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

// Tim do tre bang tuong quan cheo tren tin hieu da giam mau (x4), trong cua so 0..600 ms
static int find_lag(const float *x, int nS, const float *y, int nY, int playStart, double sr) {
    int D = 4, maxLag = (int)(0.6 * sr / D), len = (int)(2.0 * sr / D);
    if (len * D > nS) len = nS / D;
    int best = 0; double bv = -1;
    for (int L = 0; L < maxLag; L++) {
        double s = 0; int base = playStart + L * D;
        if (base + len * D >= nY) break;
        for (int i = 0; i < len; i++) s += (double)x[i * D] * y[base + i * D];
        if (fabs(s) > bv) { bv = fabs(s); best = L; }
    }
    // tinh chinh o do phan giai day du quanh ket qua
    int c = best * D, bestF = c; double bvF = -1;
    for (int L = c - D; L <= c + D; L++) {
        if (L < 0) continue;
        double s = 0; int base = playStart + L, n2 = len * D;
        if (base + n2 >= nY) continue;
        for (int i = 0; i < n2; i += 2) s += (double)x[i] * y[base + i];
        if (fabs(s) > bvF) { bvF = fabs(s); bestF = L; }
    }
    return bestF;
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
    double sigE = 0;
    double lnr = log(f2 / f1);
    for (int b = 0; b < PAA_BANDS; b++) {
        double lo = PAA_BAND_HZ[b] / pow(2, 1.0 / 6), hi = PAA_BAND_HZ[b] * pow(2, 1.0 / 6);
        if (lo < f1) lo = f1; if (hi > f2) hi = f2;
        if (hi <= lo) { r->respDb[b] = r->absDb[b] = 0; continue; }
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
    for (int b = 0; b < PAA_BANDS; b++) if (PAA_BAND_HZ[b] >= 200 && PAA_BAND_HZ[b] <= 4000) { ref += r->absDb[b]; rc++; }
    ref /= rc;
    for (int b = 0; b < PAA_BANDS; b++) r->respDb[b] = r->absDb[b] - ref;
    // bo bu theo quang tam: trung binh cac dai 1/3 trong +-1/2 quang tam, dao dau, gioi han +-6 dB, giam 30% (bu nhe)
    for (int o = 0; o < PAA_OCT; o++) {
        double lo = PAA_OCT_HZ[o] / sqrt(2), hi = PAA_OCT_HZ[o] * sqrt(2), s = 0; int c = 0;
        for (int b = 0; b < PAA_BANDS; b++) if (PAA_BAND_HZ[b] >= lo && PAA_BAND_HZ[b] < hi) { s += r->respDb[b]; c++; }
        double m = c ? s / c : 0;
        double corr = -m * 0.7;
        if (corr > 6) corr = 6; if (corr < -6) corr = -6;
        if (PAA_OCT_HZ[o] >= 16000) corr = 0;       // tren 10 kHz khong do duoc tin cay
        r->corrDb[o] = corr;
    }
    r->valid = r->snrDb > 10;
}
