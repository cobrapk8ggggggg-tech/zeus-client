#!/usr/bin/env bash
# ============================================================
# make-embedded-deps.sh — produce the SLIM embedded-JVM assets
# for the Tachimanga-style embedded architecture.
#
#   1) slim server jar   : strips GraalJS+Truffle, ICU4J, NotoSans
#                          fonts, bundled WebUI, postgres driver and
#                          Android-only resources  (175 MB -> ~87 MB)
#   2) device-only runtime: drops the ios-arm64-simulator slices
#                          from the OpenJ9 XCFramework bundle (96 MB -> 48 MB)
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

cp "$JAR_IN" "$JAR_OUT"
# NOTE: keep these in sync with docs — each entry is payload the
# embedded app never executes (zeus client talks GraphQL only).
zip -q -d "$JAR_OUT" \
  'org/graalvm/*' 'com/oracle/*' 'com/ibm/*' 'font/*' \
  'WebUI.zip' 'org/postgresql/*' 'res/*' 'resources.arsc' || true

cp "$OJ9_IN" "$OJ9_OUT"
zip -q -d "$OJ9_OUT" \
  'OpenJ9/Artifacts/XCFrameworks/*/ios-arm64-simulator/*' \
  'OpenJ9/Artifacts/XCFrameworks/*/ios-arm64-simulator/' || true

ls -lh "$JAR_OUT" "$OJ9_OUT"
