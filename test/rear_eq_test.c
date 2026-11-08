// Kiem thu dap ung tan so cua bo loc "phia sau": tang ~1 kHz va ~11 kHz, giam ~4 kHz, tang tram 50 Hz
#include "../app/PASynth.h"
#include <stdio.h>
#include <math.h>
int main(void) {
  int fail = 0; double sr[2] = {44100, 48000};
  for (int k = 0; k < 2; k++) {
    double eq[4][5]; pa_rear_eq_design(eq, sr[k], 0.7);
    double f[] = {50, 250, 1000, 2000, 4000, 7000, 11000};
    printf("sr=%.0f:", sr[k]);
    for (int i = 0; i < 7; i++) printf("  %gHz %+.1fdB", f[i], pa_rear_eq_gain_db(eq, sr[k], f[i]));
    printf("\n");
    double g1k = pa_rear_eq_gain_db(eq, sr[k], 1000), g4k = pa_rear_eq_gain_db(eq, sr[k], 4000), g11 = pa_rear_eq_gain_db(eq, sr[k], 11000), g50 = pa_rear_eq_gain_db(eq, sr[k], 50);
    if (!(g1k > 2 && g4k < -3 && g11 > 1.5 && g50 > 1.5)) fail = 1;
    double z[4][5]; pa_rear_eq_design(z, sr[k], 0);
    for (int i = 0; i < 7; i++) if (fabs(pa_rear_eq_gain_db(z, sr[k], f[i])) > 0.01) fail = 1;   // cuong do 0 = khong doi
  }
  printf("  -> %s\n", fail ? "KHONG DAT" : "DAT");
  return fail;
}
