// PAZip - ghi tep .zip toi gian (nen deflate bang zlib), khong phu thuoc dich vu he thong
#pragma once
#ifdef __cplusplus
extern "C" {
#endif
typedef struct PAZip PAZip;
PAZip *pazip_open(const char *path);
// name: duong dan trong zip (vd "chuyen-di/a.csv"); tra ve 0 neu loi
int pazip_add(PAZip *z, const char *name, const unsigned char *data, unsigned long len);
int pazip_close(PAZip *z);   // ghi muc luc; tra ve 0 neu loi
#ifdef __cplusplus
}
#endif
