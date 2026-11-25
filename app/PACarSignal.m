#import "PACarSignal.h"
#import <notify.h>
#include "../tweak/NDACarSignal.h"

// Doc tin hieu CarPlay do tweak NDACarPlayDiag gui qua trang thai Darwin notify (xem tweak/NDACarSignal.h)
static uint64_t nsGet(const char *name) {
    int tok = 0; uint64_t v = 0;
    if (notify_register_check(name, &tok) == NOTIFY_STATUS_OK) { notify_get_state(tok, &v); notify_cancel(tok); }
    return v;
}
static NSString *fmtName(unsigned f) {
    NSArray *n = @[@"khác", @"PCM (không nén)", @"AAC-LC", @"AAC-ELD", @"AAC-ELD-SBR", @"AAC-LD", @"HE-AAC", @"ALAC (lossless)", @"Opus", @"FLAC", @"AC-3", @"E-AC-3"];
    return f < n.count ? n[f] : @"khác";
}
static NSString *procName(unsigned p) { return @[@"khác", @"airplayd", @"carkitd", @"mediaserverd", @"audiomxd"][p < 5 ? p : 0]; }
static NSString *atypeName(unsigned a) {
    switch (a) { case NDACS_A_DEFAULT: return @"mặc định"; case NDACS_A_MEDIA: return @"nhạc/media"; case NDACS_A_TELEPHONY: return @"gọi điện";
                 case NDACS_A_SPEECH: return @"giọng nói"; case NDACS_A_ALERT: return @"cảnh báo"; case NDACS_A_NUM: return @"(số)"; }
    return @"khác";
}
// Kieu nen AirPlay/CarPlay (ct, mat na bit): 1 PCM, 2 ALAC, 4 AAC-LC, 8 AAC-ELD, 32 Opus
static NSString *ctName(unsigned ct) {
    NSMutableArray *a = [NSMutableArray array];
    if (ct & 1) [a addObject:@"PCM"]; if (ct & 2) [a addObject:@"ALAC"]; if (ct & 4) [a addObject:@"AAC-LC"];
    if (ct & 8) [a addObject:@"AAC-ELD"]; if (ct & 32) [a addObject:@"Opus"]; if (ct & ~47u) [a addObject:[NSString stringWithFormat:@"0x%x", ct & ~47u]];
    return a.count ? [a componentsJoinedByString:@"+"] : @"?";
}
// Loai luong AirPlay: 96 thoi gian thuc (tre thap), 103 dem (media), 100 man hinh, 110 man hinh
static NSString *streamType(unsigned t) {
    if (t == 96) return @"âm thanh thời gian thực (96)";
    if (t == 103) return @"âm thanh đệm / media (103)";
    if (t == 100 || t == 110 || t == 111) return [NSString stringWithFormat:@"màn hình (%u)", t];
    return [NSString stringWithFormat:@"loại %u", t];
}

@implementation PACarSignal

+ (NSDictionary *)read {
    NSMutableDictionary *alive = [NSMutableDictionary dictionary];
    double now = NSDate.date.timeIntervalSince1970;
    for (NSString *p in @[@"airplayd", @"carkitd", @"mediaserverd", @"audiomxd"]) {
        uint64_t t = nsGet([NSString stringWithFormat:@NDACS_ALIVE "%@", p].UTF8String);
        alive[p] = t > 0 ? [NSString stringWithFormat:@"đã nạp (%.0f phút trước)", (now - (double)t) / 60] : @"CHƯA nạp";
    }
    uint64_t n = nsGet(NDACS_COUNTER);
    NSMutableArray *recs = [NSMutableArray array];
    NSMutableArray *lines = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (unsigned i = 0; i < NDACS_SLOTS && i < n; i++) {
        uint64_t v = nsGet([NSString stringWithFormat:@NDACS_PREFIX "r%u", i].UTF8String);
        if (!v || [seen containsObject:@(v)]) continue;
        [seen addObject:@(v)];
        unsigned kind = (unsigned)(v >> 56) & 0xFF, proc = (unsigned)(v >> 52) & 0xF;
        uint64_t p = v & 0xFFFFFFFFFFFFFull;
        NSMutableDictionary *r = [@{ @"tien_trinh": procName(proc), @"raw": [NSString stringWithFormat:@"0x%016llx", v] } mutableCopy];
        NSString *line = nil;
        if (kind == NDACS_K_STREAM) {
            unsigned type = (p >> 44) & 0xFF, ct = (p >> 36) & 0xFF, srK = (p >> 28) & 0xFF, spf = (p >> 16) & 0xFFF, lat = p & 0xFFFF;
            [r addEntriesFromDictionary:@{ @"loai": @"luong", @"type": @(type), @"ct": @(ct), @"tan_so_khz": @(srK), @"mau_khung": @(spf), @"tre_toi_da_ms": @(lat) }];
            line = [NSString stringWithFormat:@"Luồng %@: %@, %u kHz, %u mẫu/khung%@", streamType(type), ctName(ct), srK, spf, lat ? [NSString stringWithFormat:@", trễ tối đa %u ms", lat] : @""];
        } else if (kind == NDACS_K_LATENCY) {
            unsigned at = (p >> 40) & 0xF, type = (p >> 32) & 0xFF, outMs = (p >> 16) & 0xFFFF, inMs = p & 0xFFFF;
            [r addEntriesFromDictionary:@{ @"loai": @"xe_bao_tre", @"kieu": atypeName(at), @"type": @(type), @"ra_ms": @(outMs), @"vao_ms": @(inMs) }];
            line = [NSString stringWithFormat:@"Xe báo trễ (%@%@): ra loa %u ms, micro %u ms", atypeName(at), type ? [NSString stringWithFormat:@" type %u", type] : @"", outMs, inMs];
        } else if (kind == NDACS_K_CONVERTER) {
            unsigned fin = (p >> 18) & 0x3F, fout = (p >> 12) & 0x3F, srK = (p >> 4) & 0xFF, ch = p & 0xF;
            [r addEntriesFromDictionary:@{ @"loai": @"bo_ma_hoa", @"vao": fmtName(fin), @"ra": fmtName(fout), @"tan_so_khz": @(srK), @"kenh": @(ch) }];
            line = [NSString stringWithFormat:@"Bộ mã hoá (%@): %@ → %@, %u kHz, %u kênh", procName(proc), fmtName(fin), fmtName(fout), srK, ch];
        } else if (kind == NDACS_K_BITRATE) {
            [r addEntriesFromDictionary:@{ @"loai": @"toc_do_bit", @"kbps": @(p & 0xFFFFF) }];
            line = [NSString stringWithFormat:@"Tốc độ bit mã hoá: %llu kbit/s", p & 0xFFFFF];
        } else if (kind == NDACS_K_FORMATS) {
            unsigned type = (p >> 40) & 0xFF; uint64_t mask = p & 0xFFFFFFFFFFull;
            [r addEntriesFromDictionary:@{ @"loai": @"dinh_dang_xe", @"type": @(type), @"mat_na": [NSString stringWithFormat:@"0x%llx", mask] }];
            line = [NSString stringWithFormat:@"Xe hỗ trợ định dạng (type %u): mặt nạ 0x%llx", type, mask];
        } else continue;
        [recs addObject:r];
        if (line) [lines addObject:line];
    }
    return @{ @"tweak": alive, @"so_ban_ghi": @(n), @"ban_ghi": recs, @"tom_tat": lines };
}

@end
