#!/usr/bin/env bash
# PICO8_BIN may point to a launcher for an alternate runtime.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
pico8_bin="${PICO8_BIN:-/opt/pico8/pico8}"
export SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy
fishing_tmp=$(mktemp -d /tmp/fishing-test-XXXXXX)
trap 'rm -rf -- "$fishing_tmp"' EXIT
python3 - "$fishing_tmp/checks.p8" <<'PY'
from pathlib import Path
import sys
source = Path('carts/simple_fishing.p8').read_text()
lua, assets = source.split('__gfx__', 1)
harness = Path('tests/fishing_checks.lua').read_text()
Path(sys.argv[1]).write_text(lua + '\n' + harness + '\n__gfx__' + assets)
PY
run_pico8() {
    if ! timeout 30 "$pico8_bin" "$@" > "$fishing_tmp/output.log" 2>&1; then
        cat "$fishing_tmp/output.log"
        return 1
    fi
    cat "$fishing_tmp/output.log"
    if rg -qi "error|couldn't|fail:|syntax" "$fishing_tmp/output.log"; then
        return 1
    fi
}
run_pico8 -x "$fishing_tmp/checks.p8"
rg -q '^PASS: [0-9]+ fishing checks' "$fishing_tmp/output.log"
mkdir -p exports
cp carts/simple_fishing.p8 "$fishing_tmp/simple_fishing.p8"
for name in simple_fishing.p8.png simple_fishing.html; do
    # PICO-8 exports use paths relative to the working directory.
    (cd "$fishing_tmp" && run_pico8 simple_fishing.p8 -export "$name")
    test -s "$fishing_tmp/$name"
done
test -s "$fishing_tmp/simple_fishing.js"
cp "$fishing_tmp/simple_fishing.p8.png" "$fishing_tmp/simple_fishing.html" "$fishing_tmp/simple_fishing.js" exports/
printf 'PASS: fresh PNG and HTML/JS exports in exports/\n'
