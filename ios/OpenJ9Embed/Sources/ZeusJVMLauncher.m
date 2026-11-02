// ZeusJVMLauncher.m — Zeus Manhwa embedded server bootstrap
//
// Mirrors Tachimanga's native layer (see tachimanga-recon docs/06):
//   * JVM  : OpenJ9 21 (interpreter mode) from the OpenJ9-iOS SDK
//   * Server: Suwayomi-Server v2.4.2366 fat jar bundled as `zeus-server.jar`
//   * Endpoint: GraphQL at http://127.0.0.1:4567/api/graphql
//
// Server configuration is passed as JVM system properties
// (verified empirically against v2.4.2366):
//   -Dsuwayomi.tachidesk.config.server.ip=127.0.0.1
//   -Dsuwayomi.tachidesk.config.server.port=4567
// Data root is derived by the server from user.home (set by OpenJ9Kit),
// landing in <sandbox>/Library/Application Support/Tachidesk — exactly
// where Tachimanga keeps its data.

#import "ZeusJVMLauncher.h"
#import <OpenJ9Kit/OpenJ9Kit.h>
#import <os/log.h>

static os_log_t _zeusLog;
static BOOL _zeusStarted = NO;

BOOL ZeusJVMWasStarted(void) { return _zeusStarted; }

// Small helper class so the boot logic can use methods comfortably.
@interface ZeusJVMLauncherPrivate : NSObject
+ (void)bootServer;
@end

void ZeusJVMStartServer(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _zeusLog = os_log_create("app.zeusmanhwa", "jvm");
        _zeusStarted = YES;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [ZeusJVMLauncherPrivate bootServer];
        });
    });
}

@implementation ZeusJVMLauncherPrivate

+ (void)bootServer {
    NSString *jar = [NSBundle.mainBundle pathForResource:@"zeus-server" ofType:@"jar"];
    if (jar.length == 0) {
        os_log_error(_zeusLog, "zeus-server.jar NOT FOUND in bundle — embedded server disabled");
        return;
    }

    OJ9JavaVMConfiguration *config = [OJ9JavaVMConfiguration new];
    config.classPath = @[ jar ];
    config.maxHeap = @"512m";          // conservative — iOS owns memory pressure
    config.threadStackSize = @"2m";
    config.options = @[
        // --- Suwayomi-Server configuration (system properties) ---
        @"-Dsuwayomi.tachidesk.config.server.ip=127.0.0.1",
        @"-Dsuwayomi.tachidesk.config.server.port=4567",
        @"-Dsuwayomi.tachidesk.config.server.initialOpenInBrowserEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.systemTrayEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.webUIEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.debugLogsEnabled=false",
        // --- JVM behavior guards ---
        @"-Dfile.encoding=UTF-8",
    ];
    config.outputHandler = ^(NSString *line, BOOL standardError) {
        os_log(_zeusLog, "[java%@] %{public}@", standardError ? @"!" : @"", line);
    };
    config.exitHandler = ^(int status) {
        os_log_fault(_zeusLog, "JVM requested process exit (status %d) — OpenJ9Kit hook", status);
    };

    NSError *error = nil;
    OJ9JavaVM *vm = [OJ9JavaVM startWithConfiguration:config error:&error];
    if (!vm) {
        os_log_error(_zeusLog, "JVM startup failed: %{public}@", error.localizedDescription);
        return;
    }
    os_log(_zeusLog, "JVM started — launching suwayomi.tachidesk.MainKt");

    // Async variant: MainKt blocks forever (server loop); completion fires on failure/return.
    [vm runMainClass:@"suwayomi.tachidesk.MainKt"
           arguments:@[]
     completionQueue:dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
          completion:^(int status, NSError * _Nullable err) {
        if (err != nil) {
            os_log_error(_zeusLog, "server main exited (status %d): %{public}@",
                         status, err.localizedDescription);
        } else {
            os_log(_zeusLog, "server main returned status %d", status);
        }
    }];
}

@end
