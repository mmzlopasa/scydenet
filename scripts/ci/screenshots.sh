#!/usr/bin/env bash
# Boot an iPhone simulator, launch the Debug build with fixture flags and capture screenshots.
# Usage: screenshots.sh <path/to/SCYDE.app> <output-dir>
set -uo pipefail
APP="$1"; OUT="$2"; BUNDLE="dev.scyde.editor"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
c=[]
for rt,devs in d.items():
    if 'iOS' not in rt: continue
    for x in devs:
        n=x['name']
        if n.startswith('iPhone') and 'Max' not in n and 'Plus' not in n and 'Pro' in n:
            c.append((rt,n,x['udid']))
c.sort(reverse=True)
print(c[0][2] if c else '')
")
if [ -z "$UDID" ]; then echo "No iPhone simulator found" | tee "$OUT/NO_SIMULATOR.txt"; exit 0; fi
echo "Using simulator $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b || true
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

shot() {
  local name="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" >/dev/null
  sleep "${SLEEP:-5}"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" || echo "screenshot failed: $name"
}

shot tab-edit-dark       -scydeDemo YES -scydeTheme dark  -scydeTab edit
shot tab-edit-light      -scydeDemo YES -scydeTheme light -scydeTab edit
shot tab-templates-dark  -scydeTheme dark  -scydeTab templates
shot tab-ai-light        -scydeTheme light -scydeTab ai
shot tab-projects-dark   -scydeDemo YES -scydeTheme dark  -scydeTab projects
shot tab-projects-empty  -scydeTheme light -scydeTab projects
shot tab-me-dark         -scydeDemo YES -scydeTheme dark  -scydeTab me
shot settings-light      -scydeTheme light -scydeScreen settings
shot editor-dark  -scydeDemo YES -scydeTheme dark  -scydeScreen editor -scydePlayhead 4.1 -scydeSelect 1
shot editor-light -scydeDemo YES -scydeTheme light -scydeScreen editor -scydePlayhead 4.1 -scydeSelect 1
shot editor-empty-dark -scydeTheme dark -scydeScreen editor
shot export-dark  -scydeDemo YES -scydeTheme dark  -scydeScreen export
shot export-light -scydeDemo YES -scydeTheme light -scydeScreen export

# Real media: generated video + photo exercise the composition, compositor and player.
SLEEP=9 shot media-portrait  -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5
SLEEP=9 shot media-photo     -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 4.0
SLEEP=9 shot media-landscape -scydeSampleMedia YES -scydeTheme light -scydePlayhead 6.5 -scydeSelect 2
SLEEP=8 shot media-playing   -scydeSampleMedia YES -scydeTheme dark -scydeAutoplay YES
SLEEP=25 shot media-export  -scydeSampleMedia YES -scydeTheme dark -scydeScreen export -scydeAutoExport YES

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
# Keep the repo small: downscale to 900px wide.
for f in "$OUT"/*.png; do sips --resampleWidth 900 "$f" >/dev/null 2>&1 || true; done
ls -la "$OUT"
