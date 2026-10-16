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
  sleep "${SLEEP:-7}"
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" || echo "screenshot failed: $name"
}

# Warm-up launch: the first launch after boot is slow while the simulator finishes migrating data.
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
sleep 15
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

shot tab-edit-dark       -scydeDemo YES -scydeTheme dark  -scydeTab edit
shot tab-edit-light      -scydeDemo YES -scydeTheme light -scydeTab edit
SLEEP=14 shot tab-templates-dark  -scydeTheme dark  -scydeTab templates
SLEEP=12 shot template-sheet  -scydeTheme dark  -scydeTab templates -scydeSheet template:cars-0
SLEEP=14 shot tab-templates-light -scydeTheme light -scydeTab templates -AppleLanguages "(hr)" -AppleLocale hr_HR
shot sheet-stock -scydeDemo YES -scydeTheme dark -scydeScreen editor -scydeSheet stock
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
SLEEP=10 shot sheet-look    -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSheet look
SLEEP=14 shot sheet-cover   -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSheet cover
shot sheet-speed   -scydeDemo YES -scydeTheme dark -scydeScreen editor -scydeSelect 1 -scydeSheet speed
shot sheet-text    -scydeDemo YES -scydeTheme light -scydeScreen editor -scydeSheet text
shot photo-empty   -scydeTheme dark -scydeScreen photo
shot hr-edit     -scydeDemo YES -scydeTheme dark  -scydeTab edit -AppleLanguages "(hr)" -AppleLocale hr_HR
shot hr-editor   -scydeDemo YES -scydeTheme dark  -scydeScreen editor -scydeSelect 1 -AppleLanguages "(hr)" -AppleLocale hr_HR
shot hr-settings -scydeTheme light -scydeScreen settings -AppleLanguages "(hr)" -AppleLocale hr_HR
SLEEP=10 shot sheet-transform  -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSelect 0 -scydeSheet transform
SLEEP=10 shot sheet-transition -scydeSampleMedia YES -scydeTheme light -scydePlayhead 3.2 -scydeSelect 1 -scydeSheet transition
shot sheet-volume  -scydeDemo YES -scydeTheme dark -scydeScreen editor -scydeSelect 1 -scydeSheet volume
shot sheet-chroma  -scydeDemo YES -scydeTheme dark -scydeScreen editor -scydeSelect 1 -scydeSheet chroma
SLEEP=10 shot media-pip -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSelect 0
shot collage-empty -scydeTheme light -scydeScreen collage

# Pro tools: text styles, stickers, effects, masks, crop, canvas, beats.
SLEEP=10 shot media-sticker    -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 2.2
SLEEP=10 shot media-dock-video -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 6.5 -scydeSelect 2
SLEEP=10 shot sheet-effects    -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 6.5 -scydeSelect 2 -scydeSheet effects
SLEEP=10 shot sheet-textstyle  -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSheet textstyle
SLEEP=10 shot sheet-textanim   -scydeSampleMedia YES -scydeTheme light -scydePlayhead 1.0 -scydeSheet textanim
SLEEP=10 shot sheet-mask       -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 4.0 -scydeSelect 1 -scydeSheet mask
SLEEP=10 shot sheet-crop       -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSelect 0 -scydeSheet crop
SLEEP=10 shot sheet-beats      -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.5 -scydeSheet beats
shot sheet-sticker -scydeDemo YES -scydeTheme dark -scydeScreen editor -scydeSheet sticker
shot sheet-canvas  -scydeDemo YES -scydeTheme light -scydeScreen editor -scydeSheet canvas
SLEEP=10 shot media-dissolve   -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 5.2
SLEEP=10 shot sheet-speedcurve -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSelect 0 -scydeSheet speed
SLEEP=10 shot sheet-stabilize  -scydeSampleMedia YES -scydeTheme light -scydePlayhead 6.5 -scydeSelect 2 -scydeSheet stabilize
SLEEP=40 shot selftest         -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSelfTest YES
shot onboarding    -scydeOnboarding YES
shot hr-onboarding -scydeOnboarding YES -AppleLanguages "(hr)" -AppleLocale hr_HR
shot plans-dark  -scydeTheme dark  -scydeTab me -scydeScreen plans
shot hr-plans    -scydeTheme light -scydeTab me -scydeScreen plans -AppleLanguages "(hr)" -AppleLocale hr_HR
SLEEP=14 shot sheet-music   -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSheet music
SLEEP=16 shot sheet-library -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSheet stock
SLEEP=12 shot sheet-animate -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 1.0 -scydeSelect 0 -scydeSheet animate
SLEEP=40 shot templates-real -scydeTheme dark -scydeTab templates
SLEEP=20 shot template-real-sheet -scydeTheme dark -scydeTab templates -scydeSheet template:travel-0
SLEEP=10 shot hr-sheet-effects -scydeSampleMedia YES -scydeTheme dark -scydePlayhead 6.5 -scydeSelect 2 -scydeSheet effects -AppleLanguages "(hr)" -AppleLocale hr_HR

xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
# Keep the repo small: downscale to 900px wide.
for f in "$OUT"/*.png; do sips --resampleWidth 900 "$f" >/dev/null 2>&1 || true; done
ls -la "$OUT"
