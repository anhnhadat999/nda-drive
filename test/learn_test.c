// Kiem thu hoc thich nghi: 2 xe khac nhau (boc vua / rat boc) va 2 phong cach lai (em / the thao)
#include "../app/PALearn.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
static double gauss(void){ double u=(rand()+1.0)/(RAND_MAX+2.0), v=(rand()+1.0)/(RAND_MAX+2.0); return sqrt(-2*log(u))*cos(2*M_PI*v); }
// Lai nhieu chuyen: tang toc voi muc dap ga ngau nhien (sport cang cao cang dap sau), chay deu, phanh
static void drive(PALearn *l, double carMax, double sport, int minutes) {
  double v = 0, t = 0, dt = 0.01, target = 0, throttle = 0; int phase = 0; double phaseT = 0;
  while (t < minutes * 60) {
    if (phaseT <= 0) { phase = rand() % 3; phaseT = 3 + rand() % 8;
      target = phase == 0 ? 20 + rand() % 100 : (phase == 2 ? 0 : v);
      double r = rand() / (double)RAND_MAX; throttle = 0.15 + (0.25 + 0.6 * sport) * r; if (r > 0.92 - 0.25 * sport) throttle = 1; }
    double amax = carMax * (1.15 - v / 200.0); if (amax < 0.6) amax = 0.6;   // xe yeu dan khi chay nhanh
    double a = 0;
    if (v < target - 1) a = amax * throttle; else if (v > target + 1) a = -(1.5 + 3 * sport * (rand() % 3 == 0));
    v += a * dt * 3.6; if (v < 0) v = 0;
    pal_update(l, v, a + gauss() * 0.15, dt, 1);
    t += dt; phaseT -= dt;
  }
}
int main(void) {
  srand(7); int fail = 0;
  struct { const char *ten; double carMax, sport; } c[4] = { {"Xe boc vua, lai em", 3.0, 0.1}, {"Xe boc vua, lai the thao", 3.0, 0.9}, {"Xe rat boc, lai em", 6.5, 0.1}, {"Xe rat boc, lai the thao", 6.5, 0.9} };
  double sp[4], amx[4];
  for (int i = 0; i < 4; i++) {
    PALearn l; pal_init(&l); drive(&l, c[i].carMax, c[i].sport, 25);
    sp[i] = pal_sport(&l); amx[i] = pal_acc_max(&l, 35);
    printf("%-26s: do boc hoc duoc @35km/h=%.2f m/s2 (that ~%.2f) | 0-100 uoc tinh %.1f s | phong cach %.2f | %.1f km, tin cay %.0f%%\n",
      c[i].ten, amx[i], c[i].carMax * (1.15 - 35 / 200.0), pal_zero_to_100(&l), sp[i], l.distKm, pal_confidence(&l) * 100);
  }
  // Xe rat boc phai hoc ra do boc lon hon ro rang; lai the thao phai co diem phong cach cao hon lai em
  for (int i = 0; i < 4; i++) { double real = c[i].carMax * (1.15 - 35 / 200.0);
    if (fabs(amx[i] - real) > real * 0.25) { printf("LOI: %s hoc sai do boc (%.2f vs %.2f)\n", c[i].ten, amx[i], real); fail = 1; } }
  if (!(sp[1] > sp[0] + 0.15 && sp[3] > sp[2] + 0.15)) { printf("LOI: khong phan biet duoc phong cach\n"); fail = 1; }
  printf("%s\n", fail ? "  -> KHONG DAT" : "  -> DAT");
  return fail;
}
