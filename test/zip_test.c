#include "../app/PAZip.h"
#include <stdio.h>
#include <string.h>
int main(int c, char **v) {
    PAZip *z = pazip_open(v[1]); if (!z) return 1;
    const char *a = "{\"ok\":true}\n"; char big[20000]; for (int i = 0; i < 20000; i++) big[i] = "t,v,a\n0,1,2\n"[i % 12];
    if (!pazip_add(z, "bao-cao.json", (const unsigned char *)a, strlen(a))) return 1;
    if (!pazip_add(z, "chuyen-di/thu ử.csv", (const unsigned char *)big, sizeof big)) return 1;
    if (!pazip_add(z, "rong.txt", (const unsigned char *)"", 0)) return 1;
    return pazip_close(z) ? 0 : 1;
}
