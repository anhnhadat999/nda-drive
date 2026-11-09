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

// FFT phuc radix-2 tai cho (n la luy thua cua 2)
static void fft(double *re, double *im, int n, int inv) {
    for (int i = 1, j = 0; i < n; i++) {
        int bit = n >> 1; for (; j & bit; bit >>= 1) j ^= bit; j ^= bit;
        if (i < j) { double t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
    }
    for (int len = 2; len <= n; len <<= 1) {
        double ang = 2 * M_PI / len * (inv ? 1 : -1), wr = cos(ang), wi = sin(ang);
        for (int i = 0; i < n; i += len) {
            double cr = 1, ci = 0;
            for (int k = 0; k < len / 2; k++) {
                int a = i + k, b = a + len / 2;
                double xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
                re[b] = re[a] - xr; im[b] = im[a] - xi; re[a] += xr; im[a] += xi;
                double t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
            }
        }
    }
}

// Tim do tre 0..3 s (CarPlay khong day tre 1-2 s) bang tuong quan cheo qua FFT ("loc phoi hop"):
// tieng quet dai 8 s cho do loi xu ly rat lon -> van tim dung khi on khoang xe to hon tieng quet.
// Ca hai tin hieu duoc loc bo phan duoi ~150 Hz (noi tap trung tieng u dieu hoa / gio).
static int find_lag(const float *x, int nS, const float *y, int nY, int playStart, double sr) {
    int maxLag = (int)(3.0 * sr);
    int ny = nY - playStart; if (ny <= 0) return 0;
    if (ny > nS + maxLag) ny = nS + maxLag;
    int n = 1; while (n < ny + nS) n <<= 1;
    double *ar = calloc(n, sizeof(double)), *ai = calloc(n, sizeof(double));
    double *br = calloc(n, sizeof(double)), *bi = calloc(n, sizeof(double));
    if (!ar || !ai || !br || !bi) { free(ar); free(ai); free(br); free(bi); return 0; }
    double c = exp(-2 * M_PI * 150 / sr), px = 0, py = 0, hx = 0, hy = 0, hx2 = 0, hy2 = 0, px2 = 0, py2 = 0;
    for (int i = 0; i < nS; i++) {      // 2 tang thong cao bac 1
        double v = x[i]; hx = c * (hx + v - px); px = v; hx2 = c * (hx2 + hx - px2); px2 = hx; ar[i] = hx2;
    }
    for (int i = 0; i < ny; i++) {
        double v = y[playStart + i]; hy = c * (hy + v - py); py = v; hy2 = c * (hy2 + hy - py2); py2 = hy; br[i] = hy2;
    }
    fft(ar, ai, n, 0); fft(br, bi, n, 0);
    for (int k = 0; k < n; k++) {       // Y * conj(X)
        double r = br[k] * ar[k] + bi[k] * ai[k], im = bi[k] * ar[k] - br[k] * ai[k];
        // lam trang pho (PHAT) mot phan: giam anh huong cua dai tan to nhat
        double m = sqrt(r * r + im * im); double w = 1.0 / pow(m + 1e-12, 0.5);
        br[k] = r * w; bi[k] = im * w;
    }
    fft(br, bi, n, 1);
    int best = 0; double bv = -1;
    for (int L = 0; L <= maxLag && L < n; L++) if (fabs(br[L]) > bv) { bv = fabs(br[L]); best = L; }
    free(ar); free(ai); free(br); free(bi);
    return best;
}

void paa_analyze(const float *x, int nS, const float *y, int nY, int playStart, double sr,
                 double f1, double f2, double T, PAAcousticResult *r) {
    memset(r, 0, sizeof *r);
    int lag = find_lag(x, nS, y, nY, playStart, sr);
    r->latencyMs = lag * 1000.0 / sr;
    // on nen: doan im lang truoc khi phat (bo 0,25 s dau: tieng "bup" khi bat mic)
    int n0 = (int)(0.25 * sr), n1 = playStart - (int)(0.1 * sr);
    if (n1 - n0 < (int)(0.2 * sr)) n0 = 0;
    if (n1 < 1) n1 = 1;
    double ne = 0; for (int i = n0; i < n1; i++) ne += (double)y[i] * y[i];
    double noiseRms = sqrt(ne / (n1 - n0 > 0 ? n1 - n0 : 1)) + 1e-12;
    r->noiseDbfs = 20 * log10(noiseRms);
    int ok[PAA_BANDS]; double bsnr[PAA_BANDS];
    double lnr = log(f2 / f1);
    for (int b = 0; b < PAA_BANDS; b++) {
        double fc = PAA_BAND_HZ[b];
        double lo = fc / pow(2, 1.0 / 6), hi = fc * pow(2, 1.0 / 6);
        ok[b] = lo >= f1 * 0.85 && hi <= f2 && fc < sr * 0.45;
        bsnr[b] = -99; r->respDb[b] = r->absDb[b] = 0;
        if (!ok[b]) continue;
        if (lo < f1) lo = f1;
        // Loc thong dai 1/3 quang tam: chi so nang luong TRONG dai nay -> tieng on o dai khac (gio, dieu hoa) khong anh huong
        double k[5]; { double w = 2 * M_PI * fc / sr, al = sin(w) / (2 * 4.32), a0 = 1 + al;
            k[0] = al / a0; k[1] = 0; k[2] = -al / a0; k[3] = -2 * cos(w) / a0; k[4] = (1 - al) / a0; }
        int i0 = (int)(T * log(lo / f1) / lnr * sr), i1 = (int)(T * log(hi / f1) / lnr * sr);
        if (i1 > nS) i1 = nS;
        int warm = (int)(0.06 * sr);
        double zx[2] = {0, 0}, zy[2] = {0, 0}, ex = 0, ey = 0;
        for (int i = i0 - warm; i < i1; i++) {
            double xv = (i >= 0 && i < nS) ? x[i] : 0;
            int j = playStart + lag + i; double yv = (j >= 0 && j < nY) ? y[j] : 0;
            double ox = k[0] * xv + zx[0]; zx[0] = k[1] * xv - k[3] * ox + zx[1]; zx[1] = k[2] * xv - k[4] * ox;
            double oy = k[0] * yv + zy[0]; zy[0] = k[1] * yv - k[3] * oy + zy[1]; zy[1] = k[2] * yv - k[4] * oy;
            if (i >= i0) { ex += ox * ox; ey += oy * oy; }
        }
        double zn[2] = {0, 0}, en = 0; int cn = 0;
        for (int i = n0; i < n1; i++) {
            double yv = y[i], o = k[0] * yv + zn[0]; zn[0] = k[1] * yv - k[3] * o + zn[1]; zn[1] = k[2] * yv - k[4] * o;
            if (i - n0 > warm) { en += o * o; cn++; }
        }
        int len = i1 - i0 > 0 ? i1 - i0 : 1;
        double pn = cn > 0 ? en / cn : 1e-20, py = ey / len;
        bsnr[b] = 10 * log10((py + 1e-20) / (pn + 1e-20));
        double eyc = ey - pn * len; if (eyc < ey * 0.01) eyc = ey * 0.01;
        r->absDb[b] = 10 * log10((eyc + 1e-20) / (ex + 1e-20));
        if (bsnr[b] < 3) ok[b] = 0;              // dai nay chim trong on: khong dung de bu
    }
    // SNR tong: trung vi SNR cac dai do duoc
    double v[PAA_BANDS]; int nv = 0;
    for (int b = 0; b < PAA_BANDS; b++) if (bsnr[b] > -98) v[nv++] = bsnr[b];
    for (int i = 1; i < nv; i++) { double t = v[i]; int j = i - 1; while (j >= 0 && v[j] > t) { v[j + 1] = v[j]; j--; } v[j + 1] = t; }
    r->snrDb = nv ? v[nv / 2] : 0;
    int good = 0; for (int b = 0; b < PAA_BANDS; b++) good += ok[b];
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
    r->valid = r->snrDb > 10 && good >= 8;
}
