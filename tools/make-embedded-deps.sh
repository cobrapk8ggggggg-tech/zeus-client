#!/usr/bin/env bash
# ============================================================
# make-embedded-deps.sh — produce the SLIM embedded-JVM assets
# for the Tachimanga-style embedded architecture.
#
#   1) slim server jar   : strips GraalJS+Truffle, ICU4J, NotoSans
#                          fonts, bundled WebUI, postgres driver and
#                          Android-only resources  (175 MB -> ~87 MB)
#   2) device-only runtime: drops the ios-arm64-simulator slices from
#                          the OpenJ9 XCFramework bundle (96 -> 48 MB)
#                          AND patches every XCFramework Info.plist to
#                          remove the simulator entries — CocoaPods
#                          rejects XCFrameworks whose plist references
#                          a missing slice ("static and dynamic frameworks").
#
# Proven safe by the 15/15 gold-path live test (keiyoushi store,
# catalog 1448, MangaDex install, POPULAR feed, chapter pages).
# Re-run if the server version is ever bumped.
#
# Usage: bash make-embedded-deps.sh <full.jar> <slim.jar> <full-oj9.zip> <device-oj9.zip>
# ============================================================
set -euo pipefail
JAR_IN="${1:?full Suwayomi-Server.jar}"; JAR_OUT="${2:?output slim jar path}"
OJ9_IN="${3:?full OpenJ9-iOS-headless.zip}"; OJ9_OUT="${4:?output device zip path}"

# --- 1) slim server jar (zip -d = byte-copy of kept entries, ~0.5s) ---
cp "$JAR_IN" "$JAR_OUT"
# NOTE: keep in sync with docs/14 — each entry is payload the embedded
# app never executes (zeus client talks GraphQL only).
zip -q -d "$JAR_OUT" \
  'org/graalvm/*' 'com/oracle/*' 'com/ibm/*' 'font/*' \
  'WebUI.zip' 'org/postgresql/*' 'res/*' 'resources.arsc' || true

# --- 2) device-only OpenJ9 runtime ---
WORK="$(mktemp -d)"
unzip -q "$OJ9_IN" -d "$WORK"

# patch every XCFramework Info.plist: drop the ios-arm64-simulator <dict> entries
python3 - "$WORK" <<'PYEOF'
import glob, re, sys
n = 0
for p in glob.glob(sys.argv[1] + '/OpenJ9/Artifacts/XCFrameworks/*.xcframework/Info.plist'):
    s = open(p).read()
    s2 = re.sub(r'\s*<dict>\s*<key>BinaryPath</key>(?:(?!</dict>).)*?<string>ios-arm64-simulator</string>(?:(?!</dict>).)*?</dict>',
                '', s, flags=re.S)
    if s2 != s:
        open(p, 'w').write(s2); n += 1
print(f'patched {n} XCFramework Info.plists')
PYEOF

# remove simulator slices physically
find "$WORK" -type d -name 'ios-arm64-simulator' -prune -exec rm -rf {} +

rm -f "$OJ9_OUT"
(cd "$WORK" && zip -q -r -9 "$OJ9_OUT" OpenJ9)
rm -rf "$WORK"

ls -lh "$JAR_OUT" "$OJ9_OUT"
