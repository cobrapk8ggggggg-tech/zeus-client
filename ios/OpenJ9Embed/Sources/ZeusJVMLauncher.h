// ZeusJVMLauncher.h — Zeus Manhwa embedded server bootstrap
//
// Starts the bundled Suwayomi-Server (zeus-server.jar) inside an interpreter-mode
// OpenJ9 JVM on 127.0.0.1:4567 — the same architecture as Tachimanga.
// Safe to call multiple times; only the first call starts the JVM.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Launches the embedded JVM + Suwayomi-Server on a background thread.
/// Non-blocking; returns immediately after enqueueing startup.
FOUNDATION_EXPORT void ZeusJVMStartServer(void);

/// YES once a startup attempt has been made (successful or not).
FOUNDATION_EXPORT BOOL ZeusJVMWasStarted(void);

NS_ASSUME_NONNULL_END
