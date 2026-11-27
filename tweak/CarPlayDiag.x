// NDACarPlayDiag – tweak CHAN DOAN CarPlay (CHI DOC, KHONG THAY DOI GI).
// Nap vao cac tien trinh lo am thanh/CarPlay cua iOS (airplayd, carkitd, mediaserverd, audiomxd) va ghi lai:
//   1) Thong diep cau hinh CarPlay (plist) di/den: dinh dang am thanh xe khai bao, luong am thanh,
//      do tre, man hinh, tinh nang... -> biet xe VF7 nhan duoc nhung dinh dang nao.
//   2) Bo chuyen doi am thanh (AudioConverter): iPhone dang nen/giai nen sang dinh dang nao
//      (PCM khong nen, AAC, AAC-ELD, Opus, ALAC...), tan so, so kenh, toc do bit.
// An toan:
//   - Moi ham bi moc deu goi lai ham goc NGUYEN VEN, chi doc tham so de ghi chep.
//   - Xoa thong tin dinh danh (ma thiet bi, dia chi MAC, khoa, ten, so serial...) va KHONG ghi noi dung du lieu nhi phan.
//   - Gioi han dung luong tep, bo dong trung lap. Tat han: tao tep /var/jb/var/mobile/Library/NDADrive/carplay-diag.off
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>
#import <os/log.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <pthread.h>
#import <ctype.h>
#import <notify.h>
#include "NDACarSignal.h"
#import <stdlib.h>
#import <string.h>

#define MAX_FILE (2 * 1024 * 1024)
#define MAX_ENTRY (24 * 1024)

static const char *gProc = "?";
static int gIsAudioDaemon = 0;          // mediaserverd / audiomxd: chi ghi bo ma hoa (it nhieu)
static dispatch_queue_t gQ;
static os_log_t gLog;
static char gPath[512];
static int gFd = -1;
static int gOpenFailed = 0;   // hop cat (sandbox) khong cho ghi tep -> chi dung os_log, khong thu lai
static uint32_t gSeen[512]; static int gSeenI = 0;
static __thread int tGuard = 0;          // chong de quy trong cung luong

// ---------------- ghi tep ----------------
static int tryOpen(const char *dir) {
    mkdir(dir, 0777); chmod(dir, 0777);
    char p[512]; snprintf(p, sizeof p, "%s/%s.log", dir, gProc);
    int fd = open(p, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd >= 0) { fchmod(fd, 0666); strlcpy(gPath, p, sizeof gPath); }
    return fd;
}
static void openLog(void) {
    const char *dirs[] = { "/var/jb/var/mobile/Library/NDADrive/carplay-diag", "/var/mobile/Library/Logs/NDADrive-carplay", "/private/var/tmp/ndadrive-carplay" };
    mkdir("/var/jb/var/mobile/Library/NDADrive", 0777);
    for (int i = 0; i < 3 && gFd < 0; i++) gFd = tryOpen(dirs[i]);
    if (gFd < 0) gOpenFailed = 1;
}
static uint32_t fnv(const char *s, size_t n) { uint32_t h = 2166136261u; for (size_t i = 0; i < n; i++) { h ^= (unsigned char)s[i]; h *= 16777619u; } return h; }

static void emit(const char *tag, const char *text) {
    size_t n = strlen(text);
    uint32_t h = fnv(text, n) ^ fnv(tag, strlen(tag));
    char *copy = strndup(text, MAX_ENTRY);
    char *tg = strdup(tag);
    dispatch_async(gQ, ^{
        for (int i = 0; i < 512; i++) if (gSeen[i] == h) { free(copy); free(tg); return; }   // trung lap
        gSeen[gSeenI] = h; gSeenI = (gSeenI + 1) % 512;
        os_log(gLog, "[%{public}s] %{public}s", tg, copy);
        if (gFd < 0 && !gOpenFailed) openLog();
        if (gFd >= 0) {
            struct stat st;
            if (fstat(gFd, &st) == 0 && st.st_size > MAX_FILE) {   // xoay vong tep
                char old[520]; snprintf(old, sizeof old, "%s.old", gPath);
                close(gFd); rename(gPath, old); gFd = open(gPath, O_WRONLY | O_CREAT | O_APPEND, 0666);
            }
            time_t now = time(NULL); struct tm tmv; localtime_r(&now, &tmv);
            char head[96]; strftime(head, sizeof head, "%Y-%m-%d %H:%M:%S", &tmv);
            dprintf(gFd, "%s [%s] %s\n%s\n\n", head, gProc, tg, copy);
        }
        free(copy); free(tg);
    });
}

// ---------------- chuyen plist -> chu (co xoa thong tin dinh danh) ----------------
typedef struct { char *b; size_t n, cap; int full; } Buf;
static void put(Buf *o, const char *s) {
    if (o->full) return;
    size_t l = strlen(s);
    if (o->n + l + 1 >= MAX_ENTRY - 32) { o->full = 1; return; }   // de cho cho dau hieu cat bot
    if (o->n + l + 1 > o->cap) { o->cap = (o->n + l + 1) * 2; o->b = realloc(o->b, o->cap); }
    memcpy(o->b + o->n, s, l); o->n += l; o->b[o->n] = 0;
}
static void cfstr(CFStringRef s, char *out, size_t cap) { if (!s || !CFStringGetCString(s, out, cap, kCFStringEncodingUTF8)) strlcpy(out, "?", cap); }

static int sensitiveKey(const char *k) {
    char l[128]; size_t i = 0; for (; k[i] && i < sizeof l - 1; i++) l[i] = (char)tolower((unsigned char)k[i]); l[i] = 0;
    const char *exact[] = { "pk", "pi", "pin", "sid", "mac", "id", "ip", "pd", "ek", "sk", NULL };
    for (int j = 0; exact[j]; j++) if (!strcmp(l, exact[j])) return 1;
    const char *sub[] = { "deviceid", "macaddress", "btaddress", "bluetoothaddress", "serial", "publickey", "pairing", "password", "secret",
                          "token", "uuid", "identifier", "nonce", "salt", "signature", "certificate", "name", "phone", "address", "addr", "mac", "ssid", "psk", "passphrase", NULL };
    for (int j = 0; sub[j]; j++) if (strstr(l, sub[j])) return 1;
    return 0;
}
static int sensitiveValue(const char *v) {
    size_t n = strlen(v); int colons = 0, hexb = 0;
    for (size_t i = 0; i < n; i++) { if (v[i] == ':') colons++; if (isxdigit((unsigned char)v[i]) || v[i] == '-' || v[i] == '+' || v[i] == '/' || v[i] == '=') hexb++; }
    if (colons >= 5 && n <= 24) return 1;                // dia chi MAC
    if (n == 12 && hexb == 12) return 1;                 // MAC khong co dau :
    if (n >= 24 && hexb * 10 >= (int)n * 9) return 1;     // chuoi hex/base64 dai (khoa, ma)
    return 0;
}
static void ser(CFTypeRef v, Buf *o, int depth) {
    char tmp[512];
    if (!v) { put(o, "null"); return; }
    if (depth > 9) { put(o, "…"); return; }
    CFTypeID t = CFGetTypeID(v);
    if (t == CFDictionaryGetTypeID()) {
        CFIndex n = CFDictionaryGetCount(v);
        const void **ks = malloc(sizeof(void *) * (n ? n : 1)), **vs = malloc(sizeof(void *) * (n ? n : 1));
        CFDictionaryGetKeysAndValues(v, ks, vs);
        put(o, "{");
        for (CFIndex i = 0; i < n; i++) {
            if (i) put(o, ", ");
            char k[128] = "?";
            if (CFGetTypeID(ks[i]) == CFStringGetTypeID()) cfstr(ks[i], k, sizeof k);
            put(o, k); put(o, ": ");
            if (sensitiveKey(k)) put(o, "<an>"); else ser(vs[i], o, depth + 1);
        }
        put(o, "}"); free(ks); free(vs);
    } else if (t == CFArrayGetTypeID()) {
        CFIndex n = CFArrayGetCount(v);
        put(o, "[");
        for (CFIndex i = 0; i < n && i < 64; i++) { if (i) put(o, ", "); ser(CFArrayGetValueAtIndex(v, i), o, depth + 1); }
        if (n > 64) put(o, ", …");
        put(o, "]");
    } else if (t == CFStringGetTypeID()) {
        cfstr(v, tmp, sizeof tmp);
        if (sensitiveValue(tmp)) put(o, "\"<an>\""); else { put(o, "\""); put(o, tmp); put(o, "\""); }
    } else if (t == CFNumberGetTypeID()) {
        double d = 0; CFNumberGetValue(v, kCFNumberDoubleType, &d);
        if (d == (long long)d) snprintf(tmp, sizeof tmp, "%lld (0x%llx)", (long long)d, (unsigned long long)(long long)d); else snprintf(tmp, sizeof tmp, "%g", d);
        put(o, tmp);
    } else if (t == CFBooleanGetTypeID()) {
        put(o, CFBooleanGetValue(v) ? "true" : "false");
    } else if (t == CFDataGetTypeID()) {
        snprintf(tmp, sizeof tmp, "<du lieu %ld byte>", (long)CFDataGetLength(v)); put(o, tmp);   // khong ghi noi dung
    } else if (t == CFDateGetTypeID()) {
        put(o, "<ngay>");
    } else put(o, "<?>");
}

// plist co lien quan CarPlay/am thanh/man hinh khong?
static int interesting(CFTypeRef v, int depth) {
    if (!v || depth > 6) return 0;
    CFTypeID t = CFGetTypeID(v);
    if (t == CFDictionaryGetTypeID()) {
        CFIndex n = CFDictionaryGetCount(v); if (n > 400) return 0;
        const void **ks = malloc(sizeof(void *) * (n ? n : 1)), **vs = malloc(sizeof(void *) * (n ? n : 1));
        CFDictionaryGetKeysAndValues(v, ks, vs);
        int hit = 0;
        static const char *w[] = { "audio", "stream", "format", "latenc", "codec", "samplerate", "display", "screen", "viewarea", "feature", "vehicle",
                                   "model", "manufacturer", "firmware", "hid", "siri", "nightmode", "limitedui", "oemicon", "righthand", "fps",
                                   "compression", "channel", "bitrate", "carplay", "ducking", "volume", "modes", "resources", NULL };
        for (CFIndex i = 0; i < n && !hit; i++) {
            if (CFGetTypeID(ks[i]) == CFStringGetTypeID()) {
                char k[96]; cfstr(ks[i], k, sizeof k);
                for (char *p = k; *p; p++) *p = (char)tolower((unsigned char)*p);
                for (int j = 0; w[j] && !hit; j++) if (strstr(k, w[j])) hit = 1;
            }
            if (!hit) hit = interesting(vs[i], depth + 1);
        }
        free(ks); free(vs); return hit;
    }
    if (t == CFArrayGetTypeID()) { CFIndex n = CFArrayGetCount(v); for (CFIndex i = 0; i < n && i < 32; i++) if (interesting(CFArrayGetValueAtIndex(v, i), depth + 1)) return 1; }
    return 0;
}
static void scanSignals(CFTypeRef v, int depth);
static void sendRec(unsigned kind, uint64_t payload);
static unsigned fmtCode(UInt32 f);
static void logPlist(const char *tag, CFTypeRef pl) {
    if (!pl) return;
    scanSignals(pl, 0);
    if (!interesting(pl, 0)) return;
    Buf o = {0}; ser(pl, &o, 0);
    if (o.b) { if (o.full) { o.full = 0; put(&o, " …(cat bot)"); } emit(tag, o.b); free(o.b); }
}

// ---------------- dinh dang am thanh ----------------
static void fourcc(UInt32 f, char out[8]) {
    char c[4] = { (char)(f >> 24), (char)(f >> 16), (char)(f >> 8), (char)f };
    int pr = 1; for (int i = 0; i < 4; i++) if (c[i] < 32 || c[i] > 126) pr = 0;
    if (pr) snprintf(out, 8, "%c%c%c%c", c[0], c[1], c[2], c[3]); else snprintf(out, 8, "%u", (unsigned)f);
}
static const char *fmtName(UInt32 f) {
    switch (f) {
        case kAudioFormatLinearPCM: return "PCM (khong nen)";
        case kAudioFormatMPEG4AAC: return "AAC-LC";
        case kAudioFormatMPEG4AAC_ELD: return "AAC-ELD";
        case kAudioFormatMPEG4AAC_ELD_SBR: return "AAC-ELD-SBR";
        case kAudioFormatMPEG4AAC_LD: return "AAC-LD";
        case kAudioFormatMPEG4AAC_HE: return "HE-AAC";
        case kAudioFormatAppleLossless: return "ALAC (lossless)";
        case kAudioFormatOpus: return "Opus";
        case kAudioFormatFLAC: return "FLAC";
        case kAudioFormatAppleIMA4: return "IMA4";
        case kAudioFormatULaw: return "uLaw"; case kAudioFormatALaw: return "aLaw";
        case kAudioFormatAC3: return "AC-3"; case kAudioFormatEnhancedAC3: return "E-AC-3 (Dolby)";
    }
    return "khac";
}
static void asbd(const AudioStreamBasicDescription *d, char *out, size_t cap) {
    if (!d) { snprintf(out, cap, "null"); return; }
    char f[8]; fourcc(d->mFormatID, f);
    snprintf(out, cap, "%s '%s' %.0f Hz %u kenh %u bit, %u khung/goi, %u byte/goi, co=0x%x",
             fmtName(d->mFormatID), f, d->mSampleRate, (unsigned)d->mChannelsPerFrame, (unsigned)d->mBitsPerChannel,
             (unsigned)d->mFramesPerPacket, (unsigned)d->mBytesPerPacket, (unsigned)d->mFormatFlags);
}
static void logConverter(const char *kind, const AudioStreamBasicDescription *in, const AudioStreamBasicDescription *out, AudioConverterRef ref, OSStatus st) {
    if (gIsAudioDaemon && in && out && in->mFormatID == kAudioFormatLinearPCM && out->mFormatID == kAudioFormatLinearPCM) return;   // bo doi PCM->PCM o mediaserverd (rat nhieu)
    char a[256], b[256], line[700];
    asbd(in, a, sizeof a); asbd(out, b, sizeof b);
    snprintf(line, sizeof line, "%s ket qua %d\n  vao: %s\n  ra : %s", kind, (int)st, a, b);   // khong ghi con tro -> bo trung lap duoc
    (void)ref;
    emit("AUDIO CONVERTER", line);
    if (in && out) sendRec(NDACS_K_CONVERTER, ndacs_conv(fmtCode(in->mFormatID), fmtCode(out->mFormatID),
                                                         (unsigned)((out->mSampleRate > 0 ? out->mSampleRate : in->mSampleRate) / 1000), out->mChannelsPerFrame));
}

// ---------------- kenh tin hieu qua Darwin notify (vuot hop cat) ----------------
static unsigned gProcId = NDACS_P_OTHER;
static uint64_t gSentRec[64]; static int gSentI = 0;
static void nsSet(const char *name, uint64_t v) {
    int tok = 0;
    if (notify_register_check(name, &tok) == NOTIFY_STATUS_OK) { notify_set_state(tok, v); notify_cancel(tok); }
    notify_post(name);
}
static uint64_t nsGet(const char *name) {
    int tok = 0; uint64_t v = 0;
    if (notify_register_check(name, &tok) == NOTIFY_STATUS_OK) { notify_get_state(tok, &v); notify_cancel(tok); }
    return v;
}
static void sendRec(unsigned kind, uint64_t payload) {
    uint64_t v = ndacs_pack(kind, gProcId, payload);
    dispatch_async(gQ, ^{
        for (int i = 0; i < 64; i++) if (gSentRec[i] == v) return;   // da gui
        gSentRec[gSentI] = v; gSentI = (gSentI + 1) % 64;
        uint64_t n = nsGet(NDACS_COUNTER);
        char name[96]; snprintf(name, sizeof name, NDACS_PREFIX "r%u", (unsigned)(n % NDACS_SLOTS));
        nsSet(name, v);
        nsSet(NDACS_COUNTER, n + 1);
    });
}
static unsigned fmtCode(UInt32 f) {
    switch (f) {
        case kAudioFormatLinearPCM: return NDACS_F_PCM; case kAudioFormatMPEG4AAC: return NDACS_F_AAC_LC;
        case kAudioFormatMPEG4AAC_ELD: return NDACS_F_AAC_ELD; case kAudioFormatMPEG4AAC_ELD_SBR: return NDACS_F_AAC_ELD_SBR;
        case kAudioFormatMPEG4AAC_LD: return NDACS_F_AAC_LD; case kAudioFormatMPEG4AAC_HE: return NDACS_F_HE_AAC;
        case kAudioFormatAppleLossless: return NDACS_F_ALAC; case kAudioFormatOpus: return NDACS_F_OPUS;
        case kAudioFormatFLAC: return NDACS_F_FLAC; case kAudioFormatAC3: return NDACS_F_AC3; case kAudioFormatEnhancedAC3: return NDACS_F_EAC3;
    }
    return NDACS_F_OTHER;
}
static int dnum(CFDictionaryRef d, const char *k, double *out) {
    CFStringRef ks = CFStringCreateWithCString(NULL, k, kCFStringEncodingUTF8);
    CFTypeRef v = ks ? CFDictionaryGetValue(d, ks) : NULL; if (ks) CFRelease(ks);
    if (v && CFGetTypeID(v) == CFNumberGetTypeID()) { CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, out); return 1; }
    if (v && CFGetTypeID(v) == CFBooleanGetTypeID()) { *out = CFBooleanGetValue((CFBooleanRef)v); return 1; }
    return 0;
}
static unsigned atypeOf(CFDictionaryRef d) {
    CFTypeRef v = CFDictionaryGetValue(d, CFSTR("audioType"));
    if (!v || CFGetTypeID(v) != CFStringGetTypeID()) return NDACS_A_NUM;
    char s[48]; cfstr((CFStringRef)v, s, sizeof s);
    if (!strcasecmp(s, "default")) return NDACS_A_DEFAULT; if (!strcasecmp(s, "media")) return NDACS_A_MEDIA;
    if (!strcasecmp(s, "telephony")) return NDACS_A_TELEPHONY; if (!strcasecmp(s, "speechRecognition")) return NDACS_A_SPEECH;
    if (!strcasecmp(s, "alert")) return NDACS_A_ALERT;
    return NDACS_A_OTHER;
}
// Quet thong diep cai dat CarPlay/AirPlay tim: luong am thanh (ct/sr/spf/latency), do tre xe bao, mat na dinh dang
static void scanSignals(CFTypeRef v, int depth) {
    if (!v || depth > 8) return;
    CFTypeID t = CFGetTypeID(v);
    if (t == CFDictionaryGetTypeID()) {
        CFDictionaryRef d = (CFDictionaryRef)v;
        double type = 0, ct = -1, sr = 0, spf = 0, latMax = 0, latMin = 0, outU = -1, inU = 0, mask = -1;
        dnum(d, "type", &type);
        if (!dnum(d, "ct", &ct)) dnum(d, "compressionType", &ct);
        if (!dnum(d, "sr", &sr)) dnum(d, "sampleRate", &sr);
        if (!dnum(d, "spf", &spf)) dnum(d, "samplesPerFrame", &spf);
        dnum(d, "latencyMax", &latMax); dnum(d, "latencyMin", &latMin);
        if (ct >= 0) {
            double srEff = sr > 0 ? sr : 44100, lat = latMax > 0 ? latMax : latMin;
            unsigned latMs = lat > 0 ? (unsigned)(lat > 5000 ? lat / srEff * 1000 : lat) : 0;   // so mau -> ms (gia tri nho coi la ms)
            sendRec(NDACS_K_STREAM, ndacs_stream((unsigned)type, (unsigned)ct, (unsigned)(sr / 1000), (unsigned)spf, latMs));
        }
        if (dnum(d, "outputLatencyMicros", &outU)) {
            dnum(d, "inputLatencyMicros", &inU);
            sendRec(NDACS_K_LATENCY, ndacs_latency(atypeOf(d), (unsigned)type, (unsigned)(outU / 1000), (unsigned)(inU / 1000)));
        }
        if (dnum(d, "audioOutputFormats", &mask) && mask > 0) sendRec(NDACS_K_FORMATS, ndacs_formats((unsigned)type, (uint64_t)mask));
        CFIndex n = CFDictionaryGetCount(d); if (n > 256) n = 256;
        const void **vs = malloc(sizeof(void *) * (n ? n : 1));
        CFDictionaryGetKeysAndValues(d, NULL, vs);
        for (CFIndex i = 0; i < n; i++) scanSignals(vs[i], depth + 1);
        free(vs);
    } else if (t == CFArrayGetTypeID()) {
        CFIndex n = CFArrayGetCount(v);
        for (CFIndex i = 0; i < n && i < 64; i++) scanSignals(CFArrayGetValueAtIndex(v, i), depth + 1);
    }
}

// ---------------- moc ham (goi lai ham goc nguyen ven) ----------------
static CFPropertyListRef (*o_CreateWithData)(CFAllocatorRef, CFDataRef, CFOptionFlags, CFPropertyListFormat *, CFErrorRef *);
static CFPropertyListRef h_CreateWithData(CFAllocatorRef a, CFDataRef d, CFOptionFlags opt, CFPropertyListFormat *fmt, CFErrorRef *err) {
    CFPropertyListFormat f0 = 0; CFPropertyListFormat *fp = fmt ? fmt : &f0;
    CFPropertyListRef r = o_CreateWithData(a, d, opt, fp, err);
    if (r && !tGuard) { tGuard = 1; @try { logPlist(*fp == kCFPropertyListBinaryFormat_v1_0 ? "PLIST NHAN (nhi phan)" : "PLIST NHAN", r); } @catch (id e) {} tGuard = 0; }
    return r;
}
static CFDataRef (*o_CreateData)(CFAllocatorRef, CFPropertyListRef, CFPropertyListFormat, CFOptionFlags, CFErrorRef *);
static CFDataRef h_CreateData(CFAllocatorRef a, CFPropertyListRef pl, CFPropertyListFormat fmt, CFOptionFlags opt, CFErrorRef *err) {
    if (pl && !tGuard) { tGuard = 1; @try { logPlist("PLIST GUI", pl); } @catch (id e) {} tGuard = 0; }
    return o_CreateData(a, pl, fmt, opt, err);
}
static OSStatus (*o_ACNew)(const AudioStreamBasicDescription *, const AudioStreamBasicDescription *, AudioConverterRef *);
static OSStatus h_ACNew(const AudioStreamBasicDescription *in, const AudioStreamBasicDescription *out, AudioConverterRef *ref) {
    OSStatus st = o_ACNew(in, out, ref);
    if (!tGuard) { tGuard = 1; logConverter("AudioConverterNew", in, out, ref ? *ref : NULL, st); tGuard = 0; }
    return st;
}
static OSStatus (*o_ACNewSpec)(const AudioStreamBasicDescription *, const AudioStreamBasicDescription *, UInt32, const AudioClassDescription *, AudioConverterRef *);
static OSStatus h_ACNewSpec(const AudioStreamBasicDescription *in, const AudioStreamBasicDescription *out, UInt32 n, const AudioClassDescription *cls, AudioConverterRef *ref) {
    OSStatus st = o_ACNewSpec(in, out, n, cls, ref);
    if (!tGuard) {
        tGuard = 1;
        char kind[96]; snprintf(kind, sizeof kind, "AudioConverterNewSpecific (%u bo ma, %s)", (unsigned)n, cls && n && cls[0].mManufacturer == kAppleHardwareAudioCodecManufacturer ? "phan cung" : "phan mem");
        logConverter(kind, in, out, ref ? *ref : NULL, st);
        tGuard = 0;
    }
    return st;
}
static OSStatus (*o_ACSet)(AudioConverterRef, AudioConverterPropertyID, UInt32, const void *);
static OSStatus h_ACSet(AudioConverterRef ref, AudioConverterPropertyID pid, UInt32 size, const void *data) {
    OSStatus st = o_ACSet(ref, pid, size, data);
    if (!tGuard && data && size >= 4 && (pid == kAudioConverterEncodeBitRate || pid == kAudioConverterCodecQuality || pid == kAudioConverterSampleRateConverterQuality)) {
        tGuard = 1;
        char line[160];
        snprintf(line, sizeof line, "%s = %u (ket qua %d)",
                 pid == kAudioConverterEncodeBitRate ? "toc do bit (bit/giay)" : pid == kAudioConverterCodecQuality ? "chat luong ma hoa (0-127)" : "chat luong doi tan so",
                 *(const UInt32 *)data, (int)st);
        emit("AUDIO CONVERTER THUOC TINH", line);
        if (pid == kAudioConverterEncodeBitRate) sendRec(NDACS_K_BITRATE, *(const UInt32 *)data / 1000);
        tGuard = 0;
    }
    return st;
}

%group NSPL
%hook NSPropertyListSerialization
+ (id)propertyListWithData:(NSData *)data options:(NSPropertyListReadOptions)opt format:(NSPropertyListFormat *)fmt error:(NSError **)err {
    id r = %orig;
    if (r && !tGuard) { tGuard = 1; @try { logPlist("PLIST NHAN (Foundation)", (__bridge CFTypeRef)r); } @catch (id e) {} tGuard = 0; }
    return r;
}
+ (NSData *)dataWithPropertyList:(id)pl format:(NSPropertyListFormat)fmt options:(NSPropertyListWriteOptions)opt error:(NSError **)err {
    if (pl && !tGuard) { tGuard = 1; @try { logPlist("PLIST GUI (Foundation)", (__bridge CFTypeRef)pl); } @catch (id e) {} tGuard = 0; }
    return %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        // AN TOAN (1.8.7): mac dinh TAT – chi chay khi nguoi dung bat trong app (tep carplay-diag.on).
        // Khong bao gio nap vao mediaserverd/audiomxd (tien trinh am thanh can de khoi dong may: 1.8.6 lam treo tao).
        struct stat s;
        if (stat("/var/jb/var/mobile/Library/NDADrive/carplay-diag.off", &s) == 0) return;
        if (stat("/var/jb/var/mobile/Library/NDADrive/carplay-diag.on", &s) != 0) return;
        gProc = getprogname() ?: "?";
        if (strcmp(gProc, "airplayd") && strcmp(gProc, "carkitd")) return;
        // Chong van lap: tien trinh khoi dong >=3 lan trong 3 phut -> khong moc gi nua (den lan khoi dong may sau)
        {
            char bn[96]; snprintf(bn, sizeof bn, NDACS_PREFIX "boot.%s", gProc);
            int tok = 0; uint64_t v = 0, now = (uint64_t)time(NULL);
            if (notify_register_check(bn, &tok) == NOTIFY_STATUS_OK) {
                notify_get_state(tok, &v);
                uint64_t t0 = v >> 8, cnt = v & 0xFF;
                if (t0 == 0 || now - t0 > 180) { t0 = now; cnt = 0; }
                cnt++;
                notify_set_state(tok, (t0 << 8) | (cnt > 255 ? 255 : cnt));
                notify_cancel(tok);
                if (cnt >= 3) return;
            }
        }
        gIsAudioDaemon = !strcmp(gProc, "mediaserverd") || !strcmp(gProc, "audiomxd");
        gQ = dispatch_queue_create("com.ndarealty.carplaydiag", DISPATCH_QUEUE_SERIAL);
        gLog = os_log_create("com.ndarealty.carplaydiag", "diag");
        char ver[64] = "?"; NSString *v = NSProcessInfo.processInfo.operatingSystemVersionString; if (v) strlcpy(ver, v.UTF8String, sizeof ver);
        char line[160]; snprintf(line, sizeof line, "nap vao %s (pid %d), %s", gProc, getpid(), ver);
        emit("KHOI DONG", line);
        gProcId = !strcmp(gProc, "airplayd") ? NDACS_P_AIRPLAYD : !strcmp(gProc, "carkitd") ? NDACS_P_CARKITD :
                  !strcmp(gProc, "mediaserverd") ? NDACS_P_MEDIASERVERD : !strcmp(gProc, "audiomxd") ? NDACS_P_AUDIOMXD : NDACS_P_OTHER;
        { char an[96]; snprintf(an, sizeof an, NDACS_ALIVE "%s", gProc); char *anc = strdup(an); uint64_t now = (uint64_t)time(NULL); dispatch_async(gQ, ^{ nsSet(anc, now); free(anc); }); }
        if (!gIsAudioDaemon) {   // thong diep CarPlay chi o airplayd / carkitd
            %init(NSPL);
            MSHookFunction((void *)CFPropertyListCreateWithData, (void *)h_CreateWithData, (void **)&o_CreateWithData);
            MSHookFunction((void *)CFPropertyListCreateData, (void *)h_CreateData, (void **)&o_CreateData);
        }
        MSHookFunction((void *)AudioConverterNew, (void *)h_ACNew, (void **)&o_ACNew);
        MSHookFunction((void *)AudioConverterNewSpecific, (void *)h_ACNewSpec, (void **)&o_ACNewSpec);
        MSHookFunction((void *)AudioConverterSetProperty, (void *)h_ACSet, (void **)&o_ACSet);
    }
}
