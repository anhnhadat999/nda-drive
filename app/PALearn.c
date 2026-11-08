#include "PALearn.h"
#include <math.h>
#include <string.h>

static const double BIN_EDGE[PAL_BINS + 1] = {0, 20, 50, 80, 110, 400};
static const double BIN_MID[PAL_BINS] = {10, 35, 65, 95, 130};

int pal_bin(double v) {
    for (int i = 0; i < PAL_BINS; i++) if (v < BIN_EDGE[i + 1]) return i;
    return PAL_BINS - 1;
}

void pal_init(PALearn *l) {
    memset(l, 0, sizeof *l);
    // gia tri ban dau: xe pho thong (se duoc thay bang so lieu that sau vai chuyen)
    const double a0[PAL_BINS] = {2.6, 2.4, 1.9, 1.4, 1.0};
    for (int i = 0; i < PAL_BINS; i++) { l->accP95[i] = a0[i] * 0.6; l->accPeak[i] = a0[i]; l->brkP95[i] = 3.5; }
    l->accMed = 0.8;
}

// Uoc luong phan vi truc tuyen: q += eta * (p - [x < q])
static void quantile(double *q, double x, double p, double eta) {
    *q += eta * (p - (x < *q ? 1.0 : 0.0));
}

void pal_update(PALearn *l, double v, double a, double dt, int valid) {
    if (!valid || v < 5 || dt <= 0 || dt > 0.5 || fabs(a) > 12) return;   // bo du lieu nhieu / phi ly
    l->distKm += v / 3600.0 * dt;
    l->samples++;
    int b = pal_bin(v);
    // toc do hoc lon luc dau, nho dan khi da co nhieu du lieu (van giu muc toi thieu de theo kip)
    double eta = fmax(0.0015, 0.05 / (1.0 + l->samples / 3000.0)) * (dt / 0.01);
    // loc nhieu ~0,4 s: dinh gia toc phai la tang toc that, khong phai rung giat
    l->aLp += (a - l->aLp) * fmin(1, dt / 0.4);
    if (l->aLp > l->accPeak[b]) l->accPeak[b] += (l->aLp - l->accPeak[b]) * 0.02 * (dt / 0.01);
    else l->accPeak[b] -= (l->accPeak[b] - fmax(l->accP95[b], 0.8)) * 2e-6 * (dt / 0.01);   // quen rat cham
    if (a > 0.15) {
        quantile(&l->accP95[b], a, 0.95, eta);
        quantile(&l->accMed, a, 0.5, eta * 0.5);
    } else if (a < -0.15) {
        quantile(&l->brkP95[b], -a, 0.95, eta);
    }
    for (int i = 0; i < PAL_BINS; i++) {
        if (l->accP95[i] < 0.5) l->accP95[i] = 0.5;
        if (l->accP95[i] > 9) l->accP95[i] = 9;
        if (l->brkP95[i] < 1) l->brkP95[i] = 1;
    }
}

static double cap(const PALearn *l, int i) { return fmax(l->accPeak[i], l->accP95[i]); }

double pal_acc_max(const PALearn *l, double v) {
    if (v <= BIN_MID[0]) return cap(l, 0);
    for (int i = 0; i < PAL_BINS - 1; i++)
        if (v <= BIN_MID[i + 1]) {
            double w = (v - BIN_MID[i]) / (BIN_MID[i + 1] - BIN_MID[i]);
            return cap(l, i) * (1 - w) + cap(l, i + 1) * w;
        }
    return cap(l, PAL_BINS - 1);
}

double pal_sport(const PALearn *l) {
    double ref = (cap(l, 0) + cap(l, 1) + cap(l, 2)) / 3.0;
    double r = l->accMed / fmax(0.3, ref);      // lai em: dap ga nhe so voi kha nang xe; lai the thao: gan toi da
    double s = (r - 0.15) / 0.35;
    return s < 0 ? 0 : (s > 1 ? 1 : s);
}

double pal_confidence(const PALearn *l) {
    double c = l->samples / 60000.0;            // ~10 phut lai (100 mau/giay)
    return c > 1 ? 1 : c;
}

double pal_zero_to_100(const PALearn *l) {
    double t = 0;
    for (double v = 0; v < 100; v += 1) t += (1 / 3.6) / fmax(0.3, pal_acc_max(l, v + 0.5));
    return t;
}
