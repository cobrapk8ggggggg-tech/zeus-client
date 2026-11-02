# OpenJ9Embed — Zeus Manhwa embedded server (iOS)

This local CocoaPod embeds the **Suwayomi-Server inside the app** — the exact
architecture of Tachimanga: an interpreter-mode **OpenJ9 Java 21 JVM** runs the
server on `127.0.0.1:4567` in-process, and the Flutter client auto-connects to
it with zero configuration.

## Layout (CI-populated, not committed)

```
OpenJ9Embed/
├── openj9_embed.podspec
├── Sources/
│   ├── ZeusJVMLauncher.h        # committed
│   └── ZeusJVMLauncher.m        # committed — starts JVM + suwayomi.tachidesk.MainKt
├── OpenJ9/                      # ← extracted OpenJ9-iOS-headless SDK zip (CI)
│   ├── Artifacts/XCFrameworks/  #    41 xcframeworks incl. jvm.xcframework (javahome inside)
│   └── Sources/OpenJ9Kit/       #    official ObjC launcher, compiled into this pod
└── Resources/
    └── zeus-server.jar          # ← Suwayomi-Server v2.4.2366 (CI) → app bundle root
```

## Sources of the two binaries

| Component | Origin |
|---|---|
| OpenJ9 JVM | `stardewjames/openj9-ios` release `v21.0.13` — `OpenJ9-iOS-headless.zip` (interpreter-only, iOS 15+, includes Java2D/fonts for Suwayomi's AndroidCompat) |
| Suwayomi-Server | Official `Suwayomi-Server-v2.4.2366.jar` (GraphQL API matches this client) |

Both are mirrored in the **`embedded-deps`** release of this repository so CI
can fetch them with `GITHUB_TOKEN`.

## Runtime behavior

- `AppDelegate` calls `ZeusJVMStartServer()` at launch (background thread).
- JVM options: `-Xint` (interpreter — set by OpenJ9Kit), `-Xmx512m`, headless AWT.
- Server config via system properties: ip `127.0.0.1`, port `4567`, webUI off.
- Data root: `<sandbox>/Library/Application Support/Tachidesk` (same as Tachimanga).
- The Flutter client defaults to `http://127.0.0.1:4567` → connects automatically.
- DB: H2 (pure Java — no native libs needed); webp decode via twelvemonkeys
  (pure Java) — same degradation profile as Tachimanga v5.3.
