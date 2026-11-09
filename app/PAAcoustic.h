// PAAcoustic - do am hoc khoang xe bang tieng quet tan so (sine sweep).
// Chi xu ly so lieu tren may; KHONG luu am thanh thu duoc.
#ifndef PAACOUSTIC_H
#define PAACOUSTIC_H
#ifdef __cplusplus
extern "C" {
#endif

#define PAA_BANDS 25     // 1/3 quang tam: 40 Hz .. 10 kHz (+ 12.5k, 16k)
#define PAA_OCT 9        // bo bu: 63 Hz .. 16 kHz (moi quang tam 1 dai)

extern const double PAA_BAND_HZ[PAA_BANDS];
extern const double PAA_OCT_HZ[PAA_OCT];

typedef struct {
    double latencyMs;            // do tre phat -> thu
    double respDb[PAA_BANDS];    // dap ung tung dai (dB, chuan hoa quanh 0 o 200 Hz - 4 kHz)
    double absDb[PAA_BANDS];     // dap ung tuyet doi (thu/phat, dB) - dung cho do on sau nay
    double noiseDbfs;            // muc on nen khi im lang (dBFS)
    double snrDb;                // tin hieu / nhieu
    double corrDb[PAA_OCT];      // bo bu de xuat (+-6 dB)
    int valid;
} PAAcousticResult;

// Tao tieng quet mu (exponential sweep) f1..f2 trong 'seconds' giay, bien do 'amp'. Tra ve so mau.
int paa_make_sweep(float *out, int maxN, double sr, double f1, double f2, double seconds, double amp);
// Phan tich: x = tieng da phat (sweep, bat dau tai mau 'playStart' cua ban thu), y = ban thu (nY mau)
void paa_analyze(const float *sweep, int nS, const float *rec, int nY, int playStart, double sr,
                 double f1, double f2, double seconds, PAAcousticResult *r);

#ifdef __cplusplus
}
#endif
#endif
