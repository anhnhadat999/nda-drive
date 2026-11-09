#include "PAZip.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

typedef struct { char *name; unsigned long crc, csize, usize, off; int method; } Ent;
struct PAZip { FILE *f; Ent *e; int n, cap; int err; };

static void w16(FILE *f, unsigned v) { fputc(v & 255, f); fputc((v >> 8) & 255, f); }
static void w32(FILE *f, unsigned long v) { w16(f, v & 0xFFFF); w16(f, (v >> 16) & 0xFFFF); }

PAZip *pazip_open(const char *path) {
    FILE *f = fopen(path, "wb");
    if (!f) return NULL;
    PAZip *z = calloc(1, sizeof *z); z->f = f; return z;
}

int pazip_add(PAZip *z, const char *name, const unsigned char *data, unsigned long len) {
    if (!z || z->err) return 0;
    unsigned long bound = compressBound(len) + 64;
    unsigned char *buf = malloc(bound);
    if (!buf) { z->err = 1; return 0; }
    z_stream s; memset(&s, 0, sizeof s);
    unsigned long csize = 0; int method = 8;
    if (deflateInit2(&s, 6, Z_DEFLATED, -15, 8, Z_DEFAULT_STRATEGY) == Z_OK) {
        s.next_in = (Bytef *)data; s.avail_in = (uInt)len; s.next_out = buf; s.avail_out = (uInt)bound;
        if (deflate(&s, Z_FINISH) == Z_STREAM_END) csize = s.total_out; else method = 0;
        deflateEnd(&s);
    } else method = 0;
    if (method == 0 || csize >= len) { method = 0; csize = len; }
    if (z->n == z->cap) { z->cap = z->cap ? z->cap * 2 : 16; z->e = realloc(z->e, z->cap * sizeof(Ent)); }
    Ent *e = &z->e[z->n++];
    e->name = strdup(name); e->crc = crc32(0, data, (uInt)len); e->csize = csize; e->usize = len; e->method = method;
    e->off = (unsigned long)ftell(z->f);
    size_t nl = strlen(name);
    w32(z->f, 0x04034b50); w16(z->f, 20); w16(z->f, 0x0800 /* ten UTF-8 */); w16(z->f, method);
    w16(z->f, 0); w16(z->f, 0x21);   // gio/ngay co dinh (1980-01-01)
    w32(z->f, e->crc); w32(z->f, csize); w32(z->f, len); w16(z->f, (unsigned)nl); w16(z->f, 0);
    fwrite(name, 1, nl, z->f);
    fwrite(method ? buf : data, 1, csize, z->f);
    free(buf);
    if (ferror(z->f)) z->err = 1;
    return !z->err;
}

int pazip_close(PAZip *z) {
    if (!z) return 0;
    unsigned long cd = (unsigned long)ftell(z->f);
    for (int i = 0; i < z->n; i++) {
        Ent *e = &z->e[i]; size_t nl = strlen(e->name);
        w32(z->f, 0x02014b50); w16(z->f, 20); w16(z->f, 20); w16(z->f, 0x0800); w16(z->f, e->method);
        w16(z->f, 0); w16(z->f, 0x21); w32(z->f, e->crc); w32(z->f, e->csize); w32(z->f, e->usize);
        w16(z->f, (unsigned)nl); w16(z->f, 0); w16(z->f, 0); w16(z->f, 0); w16(z->f, 0); w32(z->f, 0); w32(z->f, e->off);
        fwrite(e->name, 1, nl, z->f);
    }
    unsigned long cdLen = (unsigned long)ftell(z->f) - cd;
    w32(z->f, 0x06054b50); w16(z->f, 0); w16(z->f, 0); w16(z->f, z->n); w16(z->f, z->n); w32(z->f, cdLen); w32(z->f, cd); w16(z->f, 0);
    int ok = !z->err && !ferror(z->f);
    if (fclose(z->f) != 0) ok = 0;
    for (int i = 0; i < z->n; i++) free(z->e[i].name);
    free(z->e); free(z);
    return ok;
}
