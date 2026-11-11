#!/bin/sh
# Dong goi ban web: bien dich loi C -> WebAssembly, nhung vao app.html -> repo-static/drive.html (dang len GitHub Pages)
set -e
D=$(cd "$(dirname "$0")" && pwd)
"$D/wasm/build.sh" >/dev/null
python3 - "$D" <<'P'
import base64,sys
d=sys.argv[1]
b=base64.b64encode(open(d+'/wasm/core.wasm','rb').read()).decode()
h=open(d+'/app.html',encoding='utf-8').read().replace('__WASM_B64__',b)
open(d+'/../repo-static/drive.html','w',encoding='utf-8').write(h)
print('drive.html', len(h), 'bytes')
P
