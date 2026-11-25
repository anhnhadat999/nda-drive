// Kenh bao tin hieu CarPlay tu tweak (chay trong tien trinh he thong bi hop cat) sang app NDA Drive.
// Hop cat cua airplayd/mediaserverd thuong CHAN ghi tep -> dung trang thai Darwin notify (64 bit, duoc phep gan nhu moi noi).
// Dung chung cho tweak/CarPlayDiag.x (ghi) va app/PACarSignal.m (doc). CHI chua so lieu ky thuat, khong co dinh danh.
#pragma once
#include <stdint.h>

#define NDACS_PREFIX   "com.ndarealty.ndadrive.cpd."
#define NDACS_SLOTS    24                       // so o ban ghi xoay vong: NDACS_PREFIX "r0".."r23"
#define NDACS_COUNTER  NDACS_PREFIX "n"         // tong so ban ghi da ghi (chon o tiep theo)
#define NDACS_ALIVE    NDACS_PREFIX "alive."    // + ten tien trinh: thoi diem nap tweak (giay unix)

// Tien trinh (4 bit)
enum { NDACS_P_OTHER = 0, NDACS_P_AIRPLAYD = 1, NDACS_P_CARKITD = 2, NDACS_P_MEDIASERVERD = 3, NDACS_P_AUDIOMXD = 4 };
// Loai ban ghi (8 bit cao)
enum {
    NDACS_K_STREAM = 1,     // luong am thanh trong thong diep cai dat: type, ct (kieu nen), tan so kHz, mau/khung, do tre toi da ms
    NDACS_K_LATENCY = 2,    // xe tu bao do tre (audioLatencies): kieu am thanh, ra ms, vao ms
    NDACS_K_CONVERTER = 3,  // bo ma hoa iPhone dung: dinh dang vao/ra, tan so kHz, so kenh
    NDACS_K_BITRATE = 4,    // toc do bit dat cho bo ma hoa (kbit/s)
    NDACS_K_FORMATS = 5,    // mat na dinh dang xe ho tro (audioOutputFormats) theo type
};
// Dinh dang (6 bit)
enum { NDACS_F_OTHER = 0, NDACS_F_PCM, NDACS_F_AAC_LC, NDACS_F_AAC_ELD, NDACS_F_AAC_ELD_SBR, NDACS_F_AAC_LD, NDACS_F_HE_AAC,
       NDACS_F_ALAC, NDACS_F_OPUS, NDACS_F_FLAC, NDACS_F_AC3, NDACS_F_EAC3 };
// Kieu am thanh CarPlay (4 bit)
enum { NDACS_A_NUM = 0, NDACS_A_DEFAULT = 1, NDACS_A_MEDIA = 2, NDACS_A_TELEPHONY = 3, NDACS_A_SPEECH = 4, NDACS_A_ALERT = 5, NDACS_A_OTHER = 15 };

static inline uint64_t ndacs_pack(unsigned kind, unsigned proc, uint64_t payload) {
    return ((uint64_t)(kind & 0xFF) << 56) | ((uint64_t)(proc & 0xF) << 52) | (payload & 0xFFFFFFFFFFFFFull);
}
// STREAM:  type 8 | ct 8 | srKHz 8 | spf 12 | latMs 16
static inline uint64_t ndacs_stream(unsigned type, unsigned ct, unsigned srK, unsigned spf, unsigned latMs) {
    return ((uint64_t)(type & 0xFF) << 44) | ((uint64_t)(ct & 0xFF) << 36) | ((uint64_t)(srK & 0xFF) << 28) |
           ((uint64_t)(spf > 4095 ? 4095 : spf) << 16) | (latMs > 65535 ? 65535 : latMs);
}
// LATENCY: atype 4 | typeNum 8 | outMs 16 | inMs 16
static inline uint64_t ndacs_latency(unsigned atype, unsigned typeNum, unsigned outMs, unsigned inMs) {
    return ((uint64_t)(atype & 0xF) << 40) | ((uint64_t)(typeNum & 0xFF) << 32) | ((uint64_t)(outMs > 65535 ? 65535 : outMs) << 16) | (inMs > 65535 ? 65535 : inMs);
}
// CONVERTER: fin 6 | fout 6 | srK 8 | ch 4
static inline uint64_t ndacs_conv(unsigned fin, unsigned fout, unsigned srK, unsigned ch) {
    return ((uint64_t)(fin & 0x3F) << 18) | ((uint64_t)(fout & 0x3F) << 12) | ((uint64_t)(srK & 0xFF) << 4) | (ch & 0xF);
}
// FORMATS: type 8 | mask 40
static inline uint64_t ndacs_formats(unsigned type, uint64_t mask) { return ((uint64_t)(type & 0xFF) << 40) | (mask & 0xFFFFFFFFFFull); }
