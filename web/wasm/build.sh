#!/bin/sh
# Bien dich loi C (giong het app iOS/Android) sang WebAssembly. Can clang + lld (khong can emscripten).
set -e
D=$(cd "$(dirname "$0")" && pwd); A="$D/../../app"
${CC:-clang} --target=wasm32 -O2 -nostdlib -nostdinc -isystem "$D/inc" -I"$A" -fvisibility=hidden \
  -Wl,--no-entry -Wl,--export-dynamic -Wl,--allow-undefined -Wl,--stack-first -Wl,-z,stack-size=1048576 -fuse-ld=lld \
  -o "$D/core.wasm" "$D/nda_wasm.c" "$A/PASynth.c" "$A/PAFusion.c" "$A/PALearn.c" "$D/rt.c"
ls -l "$D/core.wasm"
