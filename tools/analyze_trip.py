#!/usr/bin/env python3
"""Phan tich tep chuyen di NDA Drive (trip_*.csv) va de xuat tinh chinh cho xe dien.
Cach dung: python3 tools/analyze_trip.py trip_20261109_081500.csv [trip2.csv ...]"""
import csv, sys, math, statistics as st

def load(p):
    rows = []
    with open(p, newline='') as f:
        for r in csv.DictReader(f):
            try: rows.append({k: float(v) for k, v in r.items()})
            except ValueError: pass
    return rows

def pct(a, q):
    if not a: return float('nan')
    a = sorted(a); i = min(len(a) - 1, max(0, int(round(q * (len(a) - 1))))); return a[i]

def lag_seconds(gps, fused, dt):
    # do tre cua GPS so voi toc do hop nhat (duong = GPS cham hon), tim cuc dai tuong quan trong +-3 s
    n = len(gps); best, bl = -1e9, 0
    mg, mf = st.mean(gps), st.mean(fused)
    for L in range(-int(3 / dt), int(3 / dt) + 1):
        s = 0.0; c = 0
        for i in range(max(0, -L), min(n, n - L)):
            s += (gps[i + L] - mg) * (fused[i] - mf); c += 1
        if c and s / c > best: best, bl = s / c, L
    return bl * dt

def analyze(p):
    R = load(p)
    if len(R) < 50: print(f"{p}: qua it du lieu ({len(R)} dong)"); return {}
    t = [r['t_s'] for r in R]; dur = t[-1] - t[0]
    gaps = [b - a for a, b in zip(t, t[1:])]
    big = [g for g in gaps if g > 0.5]
    dt = st.median(gaps)
    out = {}
    print(f"\n=== {p}")
    print(f"Thoi luong {dur/60:.1f} phut, {len(R)} dong, chu ky ~{dt*1000:.0f} ms, khoang trong >0.5s: {len(big)} (dai nhat {max(gaps):.1f} s)")
    cal = sum(r['calibrated'] for r in R) / len(R); gok = sum(r['gps_ok'] for r in R) / len(R)
    raw = sum(r['src'] == 2 for r in R) / len(R)
    print(f"Da hoc huong xe {cal*100:.0f}% thoi gian | GPS tot {gok*100:.0f}% | dung gia toc ke tho {raw*100:.0f}%")
    acc = [r['gps_acc_ms'] for r in R if r['gps_acc_ms'] > 0]
    if acc: print(f"Do chinh xac toc do GPS: trung vi +-{st.median(acc):.2f} m/s, 95% +-{pct(acc,.95):.2f} m/s")
    # sai lech toc do hop nhat vs GPS (khi GPS tot va dang chay)
    G = [(r['gps_kmh'], r['fused_kmh']) for r in R if r['gps_ok'] and r['gps_kmh'] >= 0]
    if len(G) > 50:
        lag = lag_seconds([g for g, _ in G], [f for _, f in G], dt)
        d = [f - g for g, f in G if g > 5]
        if d:
            out['bias'] = st.mean(d)
            print(f"Toc do hop nhat - GPS: lech TB {st.mean(d):+.2f} km/h, RMS {math.sqrt(st.mean([x*x for x in d])):.2f} km/h | GPS tre hon {lag:.2f} s")
        out['lag'] = lag
    # dung yen
    stopped = [r for r in R if 0 <= r['gps_kmh'] < 0.5]
    if stopped:
        s_ok = sum(r['fused_kmh'] < 1 for r in stopped) / len(stopped)
        print(f"Khi xe dung (GPS<0.5): toc do hop nhat <1 km/h {s_ok*100:.0f}% thoi gian | nhan la 'dung yen' {sum(r['stationary'] for r in stopped)/len(stopped)*100:.0f}%")
        out['stop_ok'] = s_ok
    # gia toc theo dai toc do
    bins = [(0,20),(20,50),(50,80),(80,110),(110,400)]
    A = [r for r in R if r['calibrated'] and r['fused_kmh'] > 5]
    print("Do boc (phan vi 98%) theo dai toc do:", " | ".join(f"{a}-{b if b<400 else '+'}: {pct([r['a_long_ms2'] for r in A if a<=r['fused_kmh']<b and r['a_long_ms2']>0], .98):.2f}" for a, b in bins))
    dec = [-r['a_long_ms2'] for r in A if r['a_long_ms2'] < -0.15]
    if dec:
        regen = [x for x in dec if 0.4 <= x <= 1.8]
        print(f"Giam toc: trung vi {st.median(dec):.2f} m/s2, 95% {pct(dec,.95):.2f} | vung phanh tai sinh (0.4-1.8) chiem {len(regen)/len(dec)*100:.0f}% so lan giam toc")
        out['regen_med'] = st.median(regen) if regen else None
    # am thanh
    run = [r for r in R if r['state'] == 2]
    if run:
        over = sum(r['load'] < 0.06 for r in run) / len(run)
        gears = {}
        for r in run: gears[int(r['gear'])] = gears.get(int(r['gear']), 0) + 1
        shifts = sum(1 for a, b in zip(run, run[1:]) if a['gear'] != b['gear'])
        print(f"Am thanh: vong tua TB {st.mean([r['rpm'] for r in run]):.0f}, cao nhat {max(r['rpm'] for r in run):.0f} | che do ghim may (nha ga) {over*100:.0f}% thoi gian | sang so {shifts/(dur/60):.1f} lan/phut")
        print("  Ty le dung tung so:", ", ".join(f"S{g}: {c/len(run)*100:.0f}%" for g, c in sorted(gears.items())))
        out['overrun'] = over; out['shifts_pm'] = shifts / (dur / 60)
    return out

def recommend(all_):
    print("\n=== DE XUAT TINH CHINH")
    if not all_: print("Chua du du lieu."); return
    def avg(k):
        v = [a[k] for a in all_ if a.get(k) is not None]; return st.mean(v) if v else None
    b, lag, ov, sp, rg = avg('bias'), avg('lag'), avg('overrun'), avg('shifts_pm'), avg('regen_med')
    if b is not None and abs(b) > 0.8: print(f"- Toc do hop nhat lech {b:+.1f} km/h so voi GPS: kiem tra Hieu chinh toc do / sai lech gia toc ke.")
    if lag is not None: print(f"- GPS tre {lag:.2f} s so voi cam bien: {'binh thuong' if 0.2 <= lag <= 1.5 else 'bat thuong, can xem lai dong ho thoi gian'}.")
    if ov is not None and ov > 0.35: print(f"- Ghim may (nha ga) chiem {ov*100:.0f}% thoi gian: xe dien phanh tai sinh manh -> nen giam tan suat no pop khi nha ga lau.")
    if sp is not None and sp > 8: print(f"- Sang so {sp:.0f} lan/phut la nhieu: tang khoang nghi giua 2 lan sang so.")
    if rg is not None: print(f"- Phanh tai sinh dien hinh ~{rg:.2f} m/s2: dung lam nguong 'nha ga' cho xe nay.")
    print("- Cac so lieu tren se duoc dua vao ban cap nhat tiep theo.")

if __name__ == '__main__':
    res = [analyze(p) for p in sys.argv[1:]]
    recommend([r for r in res if r])
