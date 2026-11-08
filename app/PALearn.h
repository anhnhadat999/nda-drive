// PALearn - hoc thich nghi tren may: tu hoc do boc, luc phanh va phong cach lai cua CHINH chiec xe
// tu toc do + gia toc (GPS + cam bien). Khong can mang, khong gui du lieu di dau.
// Cach hoc: uoc luong phan vi (quantile) truc tuyen cho tung dai toc do, co "quen dan" de bat kip thay doi.
#ifndef PALEARN_H
#define PALEARN_H
#ifdef __cplusplus
extern "C" {
#endif

#define PAL_BINS 5   // dai toc do: 0-20, 20-50, 50-80, 80-110, >110 km/h

typedef struct {
    double accP95[PAL_BINS];   // gia toc manh nhat thuong gap (phan vi 95%) - "dap het ga" (m/s^2)
    double brkP95[PAL_BINS];   // luc phanh manh nhat thuong gap (m/s^2, so duong)
    double accPeak[PAL_BINS];  // dinh gia toc (da loc nhieu, nho lau) -> kha nang that cua xe
    double accMed;             // gia toc trung vi khi tang toc -> thoi quen dap ga
    double aLp;                // gia toc da loc (noi bo)
    double distKm;             // quang duong da hoc
    long   samples;            // so mau da hoc
} PALearn;

void   pal_init(PALearn *l);
// v: km/h, a: m/s^2 (doc xe, + la tang toc), dt: giay. Chi hoc khi du lieu tin cay (valid=1).
void   pal_update(PALearn *l, double v, double a, double dt, int valid);
double pal_acc_max(const PALearn *l, double v);   // do boc toi da da hoc tai toc do v (m/s^2)
double pal_sport(const PALearn *l);               // 0 = lai em .. 1 = lai the thao
double pal_confidence(const PALearn *l);          // 0..1 muc do da hoc du
double pal_zero_to_100(const PALearn *l);         // uoc tinh 0-100 km/h (giay)
int    pal_bin(double v);

#ifdef __cplusplus
}
#endif
#endif
