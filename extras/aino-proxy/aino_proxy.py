#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Aino Proxy - proxy cho trinh duyet dien thoai cu (Sony Ericsson Aino U10i...)
 - Mo duoc trang https hien nay: dien thoai chi can noi http, proxy tu ket noi https.
 - Rut gon trang: bo JavaScript, CSS, video; giu chu, link, anh (thu nho), form tim kiem.
 - Trang chu rieng: http://aino/  (tim kiem DuckDuckGo ban nhe, link nhanh, che do chu/anh)
 - Ghi lai moi truy van (logs/) de sau nay dung lai cac dich vu cu cua may.
Chi dung thu vien co san cua Python 3.8+. Neu cai them Pillow (pip install pillow) thi anh duoc thu nho va nen.
"""
import gzip, html, io, ipaddress, json, os, re, socket, ssl, sys, threading, time, zlib
import urllib.parse, urllib.request, urllib.error
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("AINO_PORT", "8080"))
MAX_PAGE = 1_500_000        # gioi han tong dung luong 1 trang (byte)
PAGE_SIZE = 60_000          # chia trang dai thanh nhieu trang nho ~60 KB cho may doc nhanh
IMG_W = 220                 # chieu rong anh toi da (man hinh Aino 240 px)
HERE = os.path.dirname(os.path.abspath(__file__))
LOGDIR = os.path.join(HERE, "logs")
os.makedirs(LOGDIR, exist_ok=True)
SETTINGS = {"images": True}
try:
    from PIL import Image  # tuy chon
except Exception:
    Image = None

UA_MODERN = "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
_log_lock = threading.Lock()

def log(kind, obj):
    obj["t"] = time.strftime("%Y-%m-%d %H:%M:%S")
    with _log_lock:
        with open(os.path.join(LOGDIR, f"{kind}-{time.strftime('%Y%m%d')}.log"), "a", encoding="utf-8") as f:
            f.write(json.dumps(obj, ensure_ascii=False) + "\n")

def local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(("8.8.8.8", 80)); ip = s.getsockname()[0]; s.close(); return ip
    except Exception:
        return "127.0.0.1"

# ---------------------------------------------------------------- rut gon HTML
KEEP = {"a", "p", "br", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "b", "strong", "i", "em", "u", "img", "form",
        "input", "select", "option", "textarea", "button", "blockquote", "pre", "code", "hr", "div", "span", "table", "tr",
        "td", "th", "tbody", "thead", "small", "label", "dl", "dt", "dd", "center", "font", "title", "caption"}
DROP_ALL = {"script", "style", "noscript", "svg", "video", "audio", "iframe", "canvas", "template", "object", "embed", "head", "nav", "footer"}
KEEP_ATTR = {"href", "src", "alt", "action", "method", "name", "value", "type", "selected", "checked", "colspan", "rowspan", "size", "maxlength", "for"}
BLOCK_TAGS = {"div", "p", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "table", "ul", "ol", "form", "blockquote", "pre", "dl"}

def to_proxy_url(u, base):
    """link tuyet doi, https -> http (dien thoai tiep tuc di qua proxy)"""
    if not u: return u
    u = u.strip()
    if u.startswith(("javascript:", "data:", "mailto:", "tel:", "#")): return u if u.startswith(("mailto:", "tel:", "#")) else "#"
    u = urllib.parse.urljoin(base, u)
    if u.startswith("https://"): u = "http://" + u[8:]
    return u

class Lite(HTMLParser):
    def __init__(self, base):
        super().__init__(convert_charrefs=True)
        self.base = base; self.out = []; self.skip = 0; self.title = ""; self._in_title = False; self.n = 0
    def handle_starttag(self, tag, attrs):
        if tag == "base":
            for k, v in attrs:
                if k == "href" and v: self.base = urllib.parse.urljoin(self.base, v)
        if tag in DROP_ALL and tag != "head": self.skip += 1; return
        if self.skip: return
        if tag == "title": self._in_title = True; return
        if tag not in KEEP: return
        a = dict(attrs)
        if tag == "img":
            if not SETTINGS["images"]:
                alt = a.get("alt") or ""
                if alt: self.out.append(f"[{html.escape(alt)}]")
                return
            src = a.get("src") or a.get("data-src") or a.get("data-original") or ""
            if not src and a.get("srcset"): src = a["srcset"].split(",")[0].strip().split(" ")[0]
            if not src or src.startswith("data:"): return
            full = urllib.parse.urljoin(self.base, src)
            self.out.append('<img src="http://aino/img?u=%s" alt="%s"/>' % (urllib.parse.quote(full, safe=""), html.escape(a.get("alt") or "")))
            return
        if tag == "input" and (a.get("type") or "").lower() in ("hidden",) and a.get("name") is None: return
        parts = [tag]
        for k, v in attrs:
            if k not in KEEP_ATTR or v is None: continue
            if k in ("href", "action"): v = to_proxy_url(v, self.base)
            parts.append('%s="%s"' % (k, html.escape(v, quote=True)))
        self.out.append("<" + " ".join(parts) + ">")
    def handle_endtag(self, tag):
        if tag in DROP_ALL and tag != "head": self.skip = max(0, self.skip - 1); return
        if self.skip: return
        if tag == "title": self._in_title = False; return
        if tag in KEEP and tag not in ("img", "br", "hr", "input"): self.out.append(f"</{tag}>")
        if tag in BLOCK_TAGS: self.out.append("\n")
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
    def handle_data(self, d):
        if self._in_title: self.title += d; return
        if self.skip: return
        d = re.sub(r"\s+", " ", d)
        if d.strip(): self.out.append(html.escape(d, quote=False))

def lite_page(body_html, base):
    p = Lite(base)
    try: p.feed(body_html); p.close()
    except Exception: pass
    content = "".join(p.out)
    content = re.sub(r"(<(div|span)>\s*</\2>)+", "", content)
    content = re.sub(r"\n{3,}", "\n\n", content)
    title = html.escape(p.title.strip()[:80]) or "Trang"
    if len(content.encode("utf-8")) > MAX_PAGE:
        content = content.encode("utf-8")[:MAX_PAGE].decode("utf-8", "ignore") + "<p>[... trang qua dai, da cat bot]</p>"
    chunks = split_pages(content)
    pages_html = []
    key = "%x" % (abs(hash((base, time.time()))) & 0xffffffff)
    nav = ('<div style="background:#222;color:#fff;font-size:small">'
           '<a href="http://aino/">Trang chu</a> | <a href="%s">Ban goc</a> | %s</div>') % (
        html.escape(to_proxy_url(base, base)), html.escape(urllib.parse.urlsplit(base).netloc))
    for i, c in enumerate(chunks):
        pg = ""
        if len(chunks) > 1:
            pg = '<p style="background:#222;color:#fff">Trang %d/%d ' % (i + 1, len(chunks))
            if i > 0: pg += ' <a href="http://aino/page?k=%s&amp;n=%d">&#171; Truoc</a>' % (key, i - 1)
            if i < len(chunks) - 1: pg += ' <a href="http://aino/page?k=%s&amp;n=%d">Sau &#187;</a>' % (key, i + 1)
            pg += "</p>"
        pages_html.append(('<?xml version="1.0" encoding="utf-8"?>\n<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>'
            '<meta name="viewport" content="width=device-width"/><title>%s</title></head><body>%s%s\n%s\n%s</body></html>') % (title, nav, pg, c, pg))
    if len(pages_html) > 1:
        with _cache_lock:
            PAGES[key] = pages_html
            while len(PAGES) > 30: PAGES.pop(next(iter(PAGES)))
    return pages_html[0]

PAGES = {}
_cache_lock = threading.Lock()

def split_pages(content):
    """Chia o cho xuong dong (sau the khoi) de khong cat ngang the."""
    if len(content.encode("utf-8")) <= PAGE_SIZE: return [content]
    out, cur, size = [], [], 0
    for line in content.split("\n"):
        b = len(line.encode("utf-8")) + 1
        if size + b > PAGE_SIZE and cur:
            out.append("\n".join(cur)); cur, size = [], 0
        cur.append(line); size += b
    if cur: out.append("\n".join(cur))
    return out

def decode_body(raw, ctype):
    m = re.search(r"charset=([\w\-]+)", ctype or "", re.I)
    enc = m.group(1) if m else None
    if not enc:
        m = re.search(rb'<meta[^>]+charset=["\']?([\w\-]+)', raw[:4096], re.I)
        enc = m.group(1).decode() if m else "utf-8"
    try: return raw.decode(enc, "replace")
    except LookupError: return raw.decode("utf-8", "replace")

# ---------------------------------------------------------------- tai trang goc
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
OPENER = urllib.request.build_opener(NoRedirect, urllib.request.HTTPSHandler(context=ssl.create_default_context()))

def fetch(method, url, headers, body):
    """Thu https truoc (web ngay nay), loi thi thu http."""
    tries = [url]
    if url.startswith("http://"): tries = ["https://" + url[7:], url]
    last = None
    for u in tries:
        req = urllib.request.Request(u, data=body, method=method)
        for k, v in headers.items(): req.add_header(k, v)
        try:
            with OPENER.open(req, timeout=25) as r:
                return r.status, dict(r.headers), r.read(8_000_000), u
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers or {}), e.read(2_000_000) if e.fp else b"", u
        except Exception as e:
            last = last or e      # giu loi cua lan thu https (thuong co y nghia hon)
    raise last

def unzip(raw, enc):
    enc = (enc or "").lower()
    try:
        if "gzip" in enc: return gzip.decompress(raw)
        if "deflate" in enc: return zlib.decompress(raw, -zlib.MAX_WBITS) if raw[:1] != b"x" else zlib.decompress(raw)
    except Exception: pass
    return raw

# ---------------------------------------------------------------- trang chu rieng
HOME = """<?xml version="1.0" encoding="utf-8"?>
<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/><title>Aino Proxy</title></head>
<body><h3>Aino Proxy</h3>
<form action="http://aino/search" method="get"><input type="text" name="q" size="16"/><input type="submit" value="Tim"/></form>
<p><b>Lien ket nhanh</b><br/>
<a href="http://lite.duckduckgo.com/lite/">DuckDuckGo</a><br/>
<a href="http://vi.m.wikipedia.org/">Wikipedia tieng Viet</a><br/>
<a href="http://vnexpress.net/">VnExpress</a><br/>
<a href="http://tuoitre.vn/">Tuoi Tre</a><br/>
<a href="http://thanhnien.vn/">Thanh Nien</a><br/>
<a href="http://wttr.in/Hanoi?format=3&amp;lang=vi">Thoi tiet Ha Noi</a><br/>
<a href="http://wttr.in/Saigon?format=3&amp;lang=vi">Thoi tiet TP.HCM</a></p>
<p>Anh: <b>%s</b> - <a href="http://aino/toggle-images">doi</a></p>
<p><small>Go dia chi bat ky (khong can https). Proxy tu rut gon trang cho may.</small></p>
</body></html>"""

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    server_version = "AinoProxy/1.0"

    def log_message(self, *a): pass

    def allowed(self):
        try: return ipaddress.ip_address(self.client_address[0]).is_private or self.client_address[0] == "127.0.0.1"
        except Exception: return False

    def send(self, code, body, ctype="text/html; charset=utf-8", extra=None):
        if isinstance(body, str): body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or []): self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD": self.wfile.write(body)

    def do_CONNECT(self):
        # Dien thoai tu ket noi https: chuyen thang (may cu thuong khong ho tro ma hoa moi -> nen go http://)
        if not self.allowed(): return self.send(403, "Forbidden")
        log("requests", {"ip": self.client_address[0], "m": "CONNECT", "url": self.path, "ua": self.headers.get("User-Agent", "")})
        host, _, port = self.path.partition(":")
        try: up = socket.create_connection((host, int(port or 443)), timeout=20)
        except Exception as e: return self.send(502, f"Khong ket noi duoc: {e}")
        self.send_response(200, "Connection established"); self.end_headers()
        conns = [self.connection, up]
        def pipe(a, b):
            try:
                while True:
                    d = a.recv(65536)
                    if not d: break
                    b.sendall(d)
            except Exception: pass
            finally:
                for c in conns:
                    try: c.close()
                    except Exception: pass
        t = threading.Thread(target=pipe, args=(up, self.connection), daemon=True); t.start()
        pipe(self.connection, up)

    def do_GET(self): self.handle_any()
    def do_POST(self): self.handle_any()
    def do_HEAD(self): self.handle_any()

    def handle_any(self):
        if not self.allowed(): return self.send(403, "Chi cho may trong mang nha")
        url = self.path
        if not url.startswith("http"):   # mo thang http://IP:8080/ tu may tinh
            url = "http://aino" + url
        sp = urllib.parse.urlsplit(url)
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else None
        ua = self.headers.get("User-Agent", "")
        entry = {"ip": self.client_address[0], "m": self.command, "url": url, "ua": ua}
        # Truy van KHONG phai trinh duyet (ung dung Java, dich vu he thong): ghi chi tiet de sau nay dung lai server cu
        is_browser = "Opera" in ua or "Browser" in ua or "NetFront" in ua or "Mozilla" in ua
        if not is_browser or sp.hostname and ("sonyericsson" in sp.hostname or "sony" in sp.hostname):
            log("services", {**entry, "headers": dict(self.headers), "body": (body or b"")[:4096].decode("latin-1")})
        if sp.hostname in ("aino", "aino.proxy"): return self.local(sp)
        try:
            hdr = {"User-Agent": UA_MODERN, "Accept": "text/html,*/*;q=0.8", "Accept-Encoding": "gzip, deflate",
                   "Accept-Language": "vi-VN,vi;q=0.9,en;q=0.6"}
            for k in ("Cookie", "Content-Type", "Referer"):
                if self.headers.get(k): hdr[k] = self.headers[k].replace("http://", "https://") if k == "Referer" else self.headers[k]
            status, h, raw, final = fetch(self.command if self.command != "HEAD" else "GET", url, hdr, body)
        except Exception as e:
            log("requests", {**entry, "status": 502, "err": str(e)})
            return self.send(502, f"<html><body><p>Khong mo duoc trang:<br/>{html.escape(str(e))}</p><a href='http://aino/'>Trang chu</a></body></html>")
        hl = {k.lower(): v for k, v in h.items()}
        extra = []
        for k, v in h.items():
            if k.lower() == "set-cookie":
                v = re.sub(r";\s*(Secure|SameSite=\w+|Partitioned)", "", v, flags=re.I); extra.append(("Set-Cookie", v))
        if 300 <= status < 400 and "location" in hl:
            loc = to_proxy_url(hl["location"], final)
            log("requests", {**entry, "status": status, "to": loc})
            return self.send(302, "", extra=extra + [("Location", loc)])
        raw = unzip(raw, hl.get("content-encoding"))
        ctype = hl.get("content-type", "application/octet-stream")
        if "text/html" in ctype or "xhtml" in ctype:
            out = lite_page(decode_body(raw, ctype), final)
            log("requests", {**entry, "status": status, "in": len(raw), "out": len(out.encode())})
            return self.send(status, out, extra=extra)
        if ctype.startswith("image/"):
            data, ct = shrink_image(raw, ctype)
            log("requests", {**entry, "status": status, "in": len(raw), "out": len(data)})
            return self.send(status, data, ct, extra)
        log("requests", {**entry, "status": status, "in": len(raw), "type": ctype})
        return self.send(status, raw, ctype, extra)

    def local(self, sp):
        q = urllib.parse.parse_qs(sp.query)
        if sp.path in ("", "/"):
            return self.send(200, HOME % ("bat" if SETTINGS["images"] else "tat"))
        if sp.path == "/page":
            k = (q.get("k") or [""])[0]; n = int((q.get("n") or ["0"])[0])
            with _cache_lock: pages = PAGES.get(k)
            if not pages or not (0 <= n < len(pages)): return self.send(404, "<html><body>Trang da het han, mo lai trang goc.<br/><a href='http://aino/'>Trang chu</a></body></html>")
            return self.send(200, pages[n])
        if sp.path == "/toggle-images":
            SETTINGS["images"] = not SETTINGS["images"]
            return self.send(302, "", extra=[("Location", "http://aino/")])
        if sp.path == "/search":
            term = (q.get("q") or [""])[0]
            return self.send(302, "", extra=[("Location", "http://lite.duckduckgo.com/lite/?q=" + urllib.parse.quote(term))])
        if sp.path == "/img":
            u = (q.get("u") or [""])[0]
            try:
                status, h, raw, _ = fetch("GET", u, {"User-Agent": UA_MODERN, "Accept-Encoding": "gzip"}, None)
                raw = unzip(raw, {k.lower(): v for k, v in h.items()}.get("content-encoding"))
                data, ct = shrink_image(raw, {k.lower(): v for k, v in h.items()}.get("content-type", "image/jpeg"))
                return self.send(200, data, ct)
            except Exception:
                return self.send(404, b"", "image/gif")
        return self.send(404, "Khong co")

def shrink_image(raw, ctype):
    """Thu nho anh cho man hinh 240 px va doi sang JPEG/GIF ma may cu doc duoc (can Pillow)."""
    if Image is None:
        if any(x in ctype for x in ("webp", "avif", "svg")): return b"", "image/gif"   # may cu khong doc duoc
        return raw, ctype
    try:
        im = Image.open(io.BytesIO(raw))
        if getattr(im, "is_animated", False): im.seek(0)
        im = im.convert("RGB")
        if im.width > IMG_W: im = im.resize((IMG_W, max(1, int(im.height * IMG_W / im.width))))
        b = io.BytesIO(); im.save(b, "JPEG", quality=60, optimize=True)
        return b.getvalue(), "image/jpeg"
    except Exception:
        return b"", "image/gif"

def main():
    ip = local_ip()
    print("=" * 56)
    print(" AINO PROXY dang chay")
    print(f"  Tren dien thoai: Cai dat Wi-Fi > Proxy")
    print(f"     Dia chi proxy : {ip}")
    print(f"     Cong (port)   : {PORT}")
    print(f"  Trang chu tren dien thoai: http://aino/")
    print(f"  Thu nho anh: {'CO (Pillow)' if Image else 'KHONG (cai: pip install pillow)'}")
    print(f"  Nhat ky truy van: {LOGDIR}")
    print("  Dong cua so nay de tat proxy.")
    print("=" * 56)
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), H)
    srv.daemon_threads = True
    try: srv.serve_forever()
    except KeyboardInterrupt: pass

if __name__ == "__main__":
    main()
