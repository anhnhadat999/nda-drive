// Gia lap lai CHUYEN DI THAT qua loi C (PASynth) va cham diem do khop tieng <-> xe khi loa tre (CarPlay).
// Dau vao: tep trip_*.csv (app ghi 10 Hz) hoac tep rut gon test/data/*.csv (cot t_s,fused_kmh,a_long_ms2,grade_pct,calibrated).
// Cach dung: replay_trip [-p preset] [-L tre_loa_s] [-j jerkLead] [-g gamma] [-t0100 5.8 -hp 349 -kg 2205] tep.csv ...
// Ket qua (1 dong JSON): sai so toc do nghe thay, sai so/tre do dap ga nghe thay, so lan sang so, dao so.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "../app/PASynth.h"

typedef struct { double t, v, a, g; int cal; } Row;

static int col(char **h, int n, const char *k) { for (int i = 0; i < n; i++) if (!strcmp(h[i], k)) return i; return -1; }
static int split(char *s, char **f, int max) {
    int n = 0; f[n++] = s;
    for (char *p = s; *p && n < max; p++) if (*p == ',') { *p = 0; f[n++] = p + 1; }
    for (char *p = f[n - 1]; *p; p++) if (*p == '\n' || *p == '\r') *p = 0;
    return n;
}

static Row *load(const char *path, int *nOut) {
    FILE *fp = fopen(path, "r"); if (!fp) { perror(path); return NULL; }
    static char line[4096]; char *h[64], *f[64];
    if (!fgets(line, sizeof line, fp)) { fclose(fp); return NULL; }
    char hdr[4096]; strcpy(hdr, line);
    int nh = split(hdr, h, 64);
    int ct = col(h, nh, "t_s"), cv = col(h, nh, "fused_kmh"), ca = col(h, nh, "a_long_ms2"), cg = col(h, nh, "grade_pct"), cc = col(h, nh, "calibrated");
    if (ct < 0 || cv < 0 || ca < 0) { fprintf(stderr, "%s: thieu cot\n", path); fclose(fp); return NULL; }
    int cap = 1 << 16, n = 0; Row *r = malloc(sizeof(Row) * cap);
    while (fgets(line, sizeof line, fp)) {
        int nf = split(line, f, 64); if (nf <= cv || nf <= ca) continue;
        if (n == cap) { cap *= 2; r = realloc(r, sizeof(Row) * cap); }
        r[n].t = atof(f[ct]); r[n].v = atof(f[cv]); r[n].a = atof(f[ca]);
        r[n].g = cg >= 0 && cg < nf ? atof(f[cg]) / 100 : 0; r[n].cal = cc >= 0 && cc < nf ? atoi(f[cc]) : 1;
        if (!isfinite(r[n].v) || !isfinite(r[n].a)) continue;
        if (n > 0 && r[n].t <= r[n - 1].t) continue;
        n++;
    }
    fclose(fp); *nOut = n; return r;
}

// gia tri tai "dung" theo vat ly cua xe that (cung cong thuc loi C, dung gia toc THAT)
static double perfCap, perfKnee, gammaL;
static double loadTrue(double vKmh, double aMs) {
    double v = vKmh / 3.6;
    double aReq = aMs + 0.12 + 0.5 * 1.2 * 0.75 * v * v / 1800.0;
    double aMax = perfCap * (vKmh < perfKnee ? 1.0 : perfKnee / vKmh);
    if (aMs < -0.6 && aReq < 0.05) return 0;
    double r = aReq / aMax; if (r > 0) r = pow(r, gammaL);
    return r < 0.12 ? 0.12 : (r > 1 ? 1 : r);
}

int main(int argc, char **argv) {
    const char *preset = "i4t"; double leadOv = -1, L = 1.04, jl = -1, gm = 0, t100 = 5.8, hp = 349, kg = 2205;
    int nfiles = 0; const char *files[512];
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-p") && i + 1 < argc) preset = argv[++i];
        else if (!strcmp(argv[i], "-L") && i + 1 < argc) L = atof(argv[++i]);
        else if (!strcmp(argv[i], "-j") && i + 1 < argc) jl = atof(argv[++i]);
        else if (!strcmp(argv[i], "-lead") && i + 1 < argc) leadOv = atof(argv[++i]);
        else if (!strcmp(argv[i], "-g") && i + 1 < argc) gm = atof(argv[++i]);
        else if (!strcmp(argv[i], "-t0100") && i + 1 < argc) t100 = atof(argv[++i]);
        else if (!strcmp(argv[i], "-hp") && i + 1 < argc) hp = atof(argv[++i]);
        else if (!strcmp(argv[i], "-kg") && i + 1 < argc) kg = atof(argv[++i]);
        else if (nfiles < 512) files[nfiles++] = argv[i];
    }
    perfCap = 27.78 / t100 * 1.4;
    perfKnee = fmax(25, fmin(160, hp * 746.0 * 0.85 / (kg * perfCap) * 3.6));
    double sumSpd2 = 0, sumLd2 = 0, overshoot = 0, minutes = 0; long nS = 0;
    long shifts = 0, hunts = 0;
    // tuong quan cheo tai nghe thay vs tai that de tim do tre con lai
    enum { LAGS = 61, MID = 30 }; double xc[LAGS] = {0}, sx = 0, sy = 0, sxx = 0, syy = 0; long nxc = 0;
    double onsetSum = 0; long onsetN = 0;
    for (int fi = 0; fi < nfiles; fi++) {
        int n = 0; Row *r = load(files[fi], &n); if (!r || n < 100) { free(r); continue; }
        PASynth S; pa_init(&S);
        S.presetIndex = pa_preset_index(preset); if (S.presetIndex < 0) S.presetIndex = 0;
        S.perfCap = perfCap; S.perfKnee = perfKnee; S.mute = 1; S.leadS = leadOv >= 0 ? leadOv : L;
        if (jl >= 0) S.jerkLead = jl;
        if (gm > 0) S.loadGamma = gm;
        gammaL = gm > 0 ? gm : 0.65;
        S.requestStart = 1;
        double *ld = malloc(sizeof(double) * n), *sp = malloc(sizeof(double) * n), *lt = malloc(sizeof(double) * n), *at = malloc(sizeof(double) * n);
        int *gr = malloc(sizeof(int) * n);
        double aF = 0;
        for (int i = 0; i < n; i++) {
            double dt = i ? r[i].t - r[i - 1].t : 0.1; if (dt > 1) dt = 0.1;
            // gia toc dua vao loi C ~ gia toc Kalman cua app: loc nhe gia toc doc truc (da can chinh) hoac dao ham toc do
            double aIn = r[i].a;
            if (!r[i].cal && i) aIn = (r[i].v - r[i - 1].v) / 3.6 / dt;
            aF += (aIn - aF) * fmin(1, dt / 0.3);
            int sub = (int)fmax(1, round(dt / 0.01));
            for (int k = 0; k < sub; k++) {
                double f = (k + 1.0) / sub;
                S.gpsSpeed = (i ? r[i - 1].v + (r[i].v - r[i - 1].v) * f : r[i].v);
                S.gpsAccel = aF * 3.6; S.grade = r[i].g; S.gpsAge = 0;
                pa_step(&S, dt / sub);
            }
            ld[i] = S.load; sp[i] = S.speed; gr[i] = S.gear;
        }
        // gia toc that (trung tam +-0.5 s) va tai that
        for (int i = 0; i < n; i++) {
            int a = i, b = i;
            while (a > 0 && r[i].t - r[a].t < 0.5) a--;
            while (b < n - 1 && r[b].t - r[i].t < 0.5) b++;
            at[i] = b > a ? (r[b].v - r[a].v) / 3.6 / (r[b].t - r[a].t) : 0;
            lt[i] = loadTrue(r[i].v, at[i]);
        }
        // so tieng NGHE THAY o thoi diem t (= tinh toan luc t-L) voi xe that luc t
        int j = 0;
        for (int i = 0; i < n; i++) {
            double th = r[i].t + L;
            while (j < n - 1 && r[j].t < th) j++;
            if (j >= n - 1) break;
            if (r[j].v < 2 && sp[i] < 2) continue;
            double e = sp[i] - r[j].v; sumSpd2 += e * e;
            double d = ld[i] - lt[j]; sumLd2 += d * d; nS++;
            if (d > 0.15) overshoot += d - 0.15;
        }
        // tuong quan cheo (buoc 0.1 s, +-1.5 s) giua tai nghe thay va tai that
        for (int i = 0; i + 40 < n; i++) {
            int jj = i + (int)round(L / 0.1); if (jj + MID >= n || jj - MID < 0) continue;
            if (r[i].v < 2) continue;
            for (int k = 0; k < LAGS; k++) xc[k] += ld[i] * lt[jj + k - MID];
            sx += ld[i]; sy += lt[jj]; sxx += ld[i] * ld[i]; syy += lt[jj] * lt[jj]; nxc++;
        }
        // khoi dong dap ga: tai that vuot 0.35 sau >=2 s duoi 0.2 -> bao lau tieng nghe thay vuot 0.3
        for (int i = 20; i < n; i++) {
            if (lt[i] > 0.35 && lt[i - 1] <= 0.35) {
                int quiet = 1; for (int k = i - 20; k < i; k++) if (lt[k] > 0.2) { quiet = 0; break; }
                if (!quiet) continue;
                for (int k = (i - 25 > 0 ? i - 25 : 0); k < n && k < i + 30; k++) {
                    double heard = r[k].t + L;
                    if (ld[k] > 0.3) { double dl = heard - r[i].t; if (dl > -1.5) { onsetSum += dl; onsetN++; } break; }
                }
            }
        }
        int lastDir = 0; double lastT = -9;
        for (int i = 1; i < n; i++) if (gr[i] != gr[i - 1]) {
            int dir = gr[i] > gr[i - 1] ? 1 : -1; shifts++;
            if (dir == -lastDir && r[i].t - lastT < 3) hunts++;
            lastDir = dir; lastT = r[i].t;
        }
        minutes += (r[n - 1].t - r[0].t) / 60;
        free(r); free(ld); free(sp); free(lt); free(at); free(gr);
    }
    int best = MID; double bestC = -9;
    double mx = nxc ? sx / nxc : 0, my = nxc ? sy / nxc : 0, vx = nxc ? sxx / nxc - mx * mx : 1, vy = nxc ? syy / nxc - my * my : 1;
    for (int k = 0; k < LAGS; k++) { double c = nxc ? (xc[k] / nxc - mx * my) / sqrt(fmax(1e-9, vx * vy)) : 0; if (c > bestC) { bestC = c; best = k; } }
    printf("{\"phut\":%.1f,\"toc_do_rms_kmh\":%.2f,\"tai_rms\":%.3f,\"tai_vuot\":%.4f,\"tai_tre_con_lai_s\":%.1f,\"tuong_quan\":%.3f,"
           "\"dap_ga_tre_s\":%.2f,\"so_lan_dap\":%ld,\"sang_so_phut\":%.2f,\"dao_so_phut\":%.3f}\n",
           minutes, nS ? sqrt(sumSpd2 / nS) : 0, nS ? sqrt(sumLd2 / nS) : 0, nS ? overshoot / nS : 0, (MID - best) * 0.1, bestC,
           onsetN ? onsetSum / onsetN : 0, onsetN, minutes > 0 ? shifts / minutes : 0, minutes > 0 ? hunts / minutes : 0);
    return 0;
}
