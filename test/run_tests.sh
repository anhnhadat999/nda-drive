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
rm -rf "$OUT"
if [ $fail = 0 ]; then echo "TAT CA KIEM THU: DAT"; else echo "CO KIEM THU KHONG DAT"; exit 1; fi
