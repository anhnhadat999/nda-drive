#!/bin/sh
# Kiem thu tu dong phan loi: bo tao am (15 kieu dong co) + bo hop nhat cam bien (nhieu cach gan may, nhieu nhieu)
set -e
cd "$(dirname "$0")/.."
CC=${CC:-cc}
OUT=$(mktemp -d)
export TMPDIR=$OUT
$CC -O2 -Wall -o "$OUT/sim" test/sim.c app/PASynth.c -lm
$CC -O2 -Wall -o "$OUT/fusion" test/fusion_sim.c app/PAFusion.c -lm
fail=0
echo "== Bo tao am: chuyen di gia lap (de may, tang toc 0-108, nha ga, phanh, tat may)"
for k in gt3 gt4rs p911t c911s c718s cgt v12 v10 amg v8 i6 i5 vtec i4t rot; do
  "$OUT/sim" $k | tail -2 | tr '\n' ' '; echo; "$OUT/sim" $k > /dev/null || fail=1
done
echo "== Bo do toc do: GPS + cam bien (may gan doc/ngang, 4 bo nhieu ngau nhien)"
for m in 0 1; do for seed in 1 2 3 4; do
  "$OUT/fusion" $m $seed | tail -2 | tr '\n' ' '; echo; "$OUT/fusion" $m $seed > /dev/null || fail=1
done; done
echo "== Tu sua khi nap can chinh cu sai 40 do (may bi xoay tren gia)"
for m in 0 1; do
  "$OUT/fusion" $m 1 1 | tail -3 | tr '\n' ' '; echo; "$OUT/fusion" $m 1 1 > /dev/null || fail=1
done
echo "== GPS cua xe bi giu so cu 1-4 giay (nhu VF7 qua CarPlay)"
for m in 0 1; do for seed in 1 3 7; do
  "$OUT/fusion" $m $seed 2 | tail -2 | tr '\n' ' '; echo; "$OUT/fusion" $m $seed 2 > /dev/null || fail=1
done; done
echo "== GPS cua xe: 2 s/lan, tre 1,2 s, moc thoi gian luc nhan (tu uoc luong do tre)"
for m in 0 1; do for seed in 1 3 7; do
  "$OUT/fusion" $m $seed 3 | grep -E "KET QUA|tre GPS|->" | tr '\n' ' '; echo; "$OUT/fusion" $m $seed 3 > /dev/null || fail=1
done; done
echo "== May bi xoay tren gia khi dang chay (bam man hinh lam khop bi xoay)"
for m in 0 1; do for seed in 1 3; do
  "$OUT/fusion" $m $seed 4 | grep -E "KET QUA|bi xoay|->" | tr '\n' ' ' | cut -c1-260; echo; "$OUT/fusion" $m $seed 4 > /dev/null || fail=1
done; done
echo "== Bo loc tieng tu phia sau (dap ung tan so)"
$CC -O2 -Wall -o "$OUT/eq" test/rear_eq_test.c app/PASynth.c -lm
"$OUT/eq" || fail=1
echo "== Che do thu thap im lang (khong tieng, vat ly van chay)"
$CC -O2 -Wall -Wno-misleading-indentation -o "$OUT/mute" test/mute_test.c app/PASynth.c -lm
"$OUT/mute" || fail=1
echo "== Nen .zip bao cao"
$CC -O2 -Wall -o "$OUT/zt" test/zip_test.c app/PAZip.c -lz
"$OUT/zt" "$OUT/t.zip" && python3 -c "import zipfile,sys;z=zipfile.ZipFile(sys.argv[1]);assert z.testzip() is None and len(z.namelist())==3;print('zip OK',z.namelist())" "$OUT/t.zip" || fail=1
echo "== Do am hoc khoang xe (gia lap khoang xe da biet dac tinh)"
$CC -O2 -Wall -Wno-misleading-indentation -o "$OUT/ac" test/acoustic_test.c app/PAAcoustic.c -lm
"$OUT/ac" || fail=1
echo "== Hoc thich nghi: 2 xe x 2 phong cach lai"
$CC -O2 -Wall -o "$OUT/learn" test/learn_test.c app/PALearn.c -lm
"$OUT/learn" || fail=1
echo "== Suc chiu dung: 15 tieng x 11 xe VinFast, du lieu GPS/cam bien hong (NaN, vo cuc, qua lon, thoi gian lui)"
$CC -O2 -Wno-misleading-indentation -o "$OUT/stress" test/stress_test.c app/PASynth.c app/PAFusion.c app/PALearn.c -lm
"$OUT/stress" 1.5 q > "$OUT/stress.txt" || fail=1
tail -4 "$OUT/stress.txt"
echo "== Gia lap lai CHUYEN DI THAT (3 x 10 phut VF 7 Plus, test/data): tieng nghe thay so voi xe that"
$CC -O2 -Wall -Wno-misleading-indentation -o "$OUT/replay" tools/replay_trip.c app/PASynth.c -lm
"$OUT/replay" -L 0 test/data/*.csv > "$OUT/r0.txt"
"$OUT/replay" -L 1.04 -lead 0 test/data/*.csv > "$OUT/r1.txt"
"$OUT/replay" -L 1.04 -lead 0.42 test/data/*.csv > "$OUT/r2.txt"
python3 - "$OUT/r0.txt" "$OUT/r1.txt" "$OUT/r2.txt" <<'PY' || fail=1
import json,sys
r0,r1,r2=[json.load(open(p)) for p in sys.argv[1:4]]
print("  loa day / iPhone  :", r0)
print("  CarPlay 1,04 s, bu 0,42 s:", r2)
ok=True
def chk(c,m):
    global ok
    print("   ", "OK " if c else "LOI", m); ok&=c
chk(r0["toc_do_rms_kmh"]<1.5, "toc do tieng khop xe (loa khong tre) < 1.5 km/h")
chk(r0["dap_ga_tre_s"]<0.8, "dap ga -> tieng gam (loa khong tre) < 0.8 s")
chk(r0["tai_vuot"]<0.02 and r2["tai_vuot"]<0.03, "khong gam sai luc (vuot tai)")
chk(r0["dao_so_phut"]<0.3 and r2["dao_so_phut"]<0.3, "khong dao so (<0.3 lan/phut)")
chk(r2["toc_do_rms_kmh"]<=r1["toc_do_rms_kmh"]+0.02, "bu tre 0,42 s khong lam xau toc do")
print("  -> DAT" if ok else "  -> KHONG DAT"); sys.exit(0 if ok else 1)
PY
rm -rf "$OUT"
if [ $fail = 0 ]; then echo "TAT CA KIEM THU: DAT"; else echo "CO KIEM THU KHONG DAT"; exit 1; fi
