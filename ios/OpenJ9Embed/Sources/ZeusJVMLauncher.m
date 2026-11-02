// ZeusJVMLauncher.m — Zeus Manhwa embedded server bootstrap (self-contained)
//
// Mirrors Tachimanga's native layer (tachimanga-recon docs/06) and the official
// OpenJ9Kit bootstrap flow, but loads the VM via dlopen at runtime instead of
// link-time symbols (CocoaPods cannot reliably link vendored xcframeworks from
// pod targets). The OpenJ9-iOS XCFrameworks are embedded by CocoaPods and live
// in Runner.app/Frameworks — dlopen resolves their @rpath siblings normally.
//
//   JVM    : OpenJ9 21 (interpreter mode) from the OpenJ9-iOS SDK
//   Server : Suwayomi-Server v2.4.2366 fat jar bundled as `zeus-server.jar`
//   GraphQL: http://127.0.0.1:4567/api/graphql
//
// The JVM is created on a dedicated 16 MiB-stack pthread (OpenJ9Kit pattern),
// with stdout/stderr captured through the vfprintf hook and logged via os_log.

#import "ZeusJVMLauncher.h"
#import <dlfcn.h>
#import <jni.h>
#import <os/log.h>
#import <pthread.h>
#import <stdarg.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static os_log_t _zeusLog;
static BOOL _zeusStarted = NO;

BOOL ZeusJVMWasStarted(void) { return _zeusStarted; }

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

#pragma mark - stdout/stderr capture (vfprintf hook)

// OpenJ9 calls this hook with its internal FILE* handles; we cannot rely on the
// FILE* identity, so we simply format and forward every line to os_log.
static int ZeusVfprintfHook(FILE *stream, const char *format, va_list args) {
#pragma unused(stream)
    char buffer[2048];
    int written = vsnprintf(buffer, sizeof(buffer), format, args);
    if (written > 0) {
        size_t len = strlen(buffer);
        while (len > 0 && (buffer[len - 1] == '\n' || buffer[len - 1] == '\r')) {
            buffer[--len] = '\0';
        }
        if (len > 0) os_log(_zeusLog, "[java] %{public}s", buffer);
    }
    return written;
}

#pragma mark - JVM bootstrap on a dedicated thread

typedef struct {
    void *vmLibrary;         // dlopen handle of jvm.framework/jvm
    char javaHome[PATH_MAX]; // .../jvm.framework/javahome
    char jarPath[PATH_MAX];  // bundle path of zeus-server.jar
} ZeusJVMBoot;

static void *ZeusJavaThreadMain(void *arg) {
    ZeusJVMBoot *boot = (ZeusJVMBoot *)arg;

    // ---- resolve JNI_CreateJavaVM ----
    jint (*createVM)(JavaVM **, void **, void *) =
        (jint (*)(JavaVM **, void **, void *))dlsym(boot->vmLibrary, "JNI_CreateJavaVM");
    if (!createVM) {
        os_log_error(_zeusLog, "dlsym(JNI_CreateJavaVM) failed: %{public}s", dlerror());
        free(boot);
        return NULL;
    }

    // ---- build JVM options (mirrors OpenJ9Kit) ----
    NSString *tmp = NSTemporaryDirectory();
    NSString *home = NSHomeDirectory();
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
        firstObject] ?: home;
    NSString *jar = @(boot->jarPath);
    NSString *jhome = @(boot->javaHome);

    NSArray<NSString *> *opts = @[
        [@"-Djava.home=" stringByAppendingString:jhome],
        [@"-Djava.class.path=" stringByAppendingString:jar],
        [@"-Djava.io.tmpdir=" stringByAppendingString:tmp],
        [@"-Duser.home=" stringByAppendingString:home],
        @"-Duser.dir=.",
        [@"-Xdump:directory=" stringByAppendingString:tmp],
        @"-Xshareclasses:none",
        @"-Dcom.ibm.tools.attach.enable=no",
        @"-Xint",                       // interpreter mode — iOS forbids JIT
        @"-Djava.awt.headless=true",
        @"-Xmx512m",
        @"-Xss2m",
        // Suwayomi-Server configuration (verified empirically against v2.4.2366)
        @"-Dsuwayomi.tachidesk.config.server.ip=127.0.0.1",
        @"-Dsuwayomi.tachidesk.config.server.port=4567",
        @"-Dsuwayomi.tachidesk.config.server.initialOpenInBrowserEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.systemTrayEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.webUIEnabled=false",
        @"-Dsuwayomi.tachidesk.config.server.debugLogsEnabled=false",
        @"-Dfile.encoding=UTF-8",
    ];
    os_log(_zeusLog, "JVM options: %{public}@", [opts componentsJoinedByString:@" "]);

    JavaVMOption *options = calloc(opts.count + 2, sizeof(JavaVMOption));
    if (!options) { free(boot); return NULL; }
    for (NSUInteger i = 0; i < opts.count; ++i) {
        options[i].optionString = (char *)[opts[i] UTF8String];  // kept alive by opts ARC array
    }
    options[opts.count].optionString = (char *)"vfprintf";
    options[opts.count].extraInfo = (void *)&ZeusVfprintfHook;
    options[opts.count + 1].optionString = (char *)"exit";
    options[opts.count + 1].extraInfo = NULL;

    JavaVMInitArgs args;
    memset(&args, 0, sizeof(args));
    args.version = JNI_VERSION_1_8;
    args.nOptions = (jint)(opts.count + 2);
    args.options = options;
    args.ignoreUnrecognized = JNI_FALSE;

    JavaVM *vm = NULL;
    JNIEnv *env = NULL;
    jint status = createVM(&vm, (void **)&env, &args);
    free(options);
    free(boot);
    if (status != JNI_OK) {
        os_log_error(_zeusLog, "JNI_CreateJavaVM failed: %d", status);
        return NULL;
    }
    os_log(_zeusLog, "JVM created — launching suwayomi.tachidesk.MainKt");

    // ---- invoke suwayomi.tachidesk.MainKt.main(String[]) ----
    jclass mainClass = (*env)->FindClass(env, "suwayomi/tachidesk/MainKt");
    if (!mainClass) {
        os_log_error(_zeusLog, "FindClass(MainKt) failed");
        if ((*env)->ExceptionCheck(env)) (*env)->ExceptionDescribe(env);
        return NULL;
    }
    jmethodID mainMethod = (*env)->GetStaticMethodID(env, mainClass, "main", "([Ljava/lang/String;)V");
    if (!mainMethod) {
        os_log_error(_zeusLog, "GetStaticMethodID(main) failed");
        if ((*env)->ExceptionCheck(env)) (*env)->ExceptionDescribe(env);
        return NULL;
    }
    jclass stringClass = (*env)->FindClass(env, "java/lang/String");
    jobjectArray argsArray = (*env)->NewObjectArray(env, 0, stringClass, NULL);
    (*env)->CallStaticVoidMethod(env, mainClass, mainMethod, argsArray);
    if ((*env)->ExceptionCheck(env)) {
        os_log_error(_zeusLog, "server main threw an exception:");
        (*env)->ExceptionDescribe(env);
    }
    os_log(_zeusLog, "server main returned — JVM remains alive for daemon threads");
    return NULL;
}

@implementation ZeusJVMLauncherPrivate

+ (void)bootServer {
    // ---- locate zeus-server.jar (root or any nested resources dir) ----
    NSString *jar = [NSBundle.mainBundle pathForResource:@"zeus-server" ofType:@"jar"];
    if (jar.length == 0) {
        NSString *root = [NSBundle.mainBundle bundlePath];
        __block NSString *found = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *e = [fm enumeratorAtURL:[NSURL fileURLWithPath:root]
                            includingPropertiesForKeys:@[ NSURLIsRegularFileKey ]
                                               options:0
                                          errorHandler:nil];
        for (NSURL *f in e) {
            if ([f.lastPathComponent isEqualToString:@"zeus-server.jar"]) { found = f.path; break; }
        }
        jar = found ?: @"";
    }
    if (jar.length == 0) {
        os_log_error(_zeusLog, "zeus-server.jar NOT FOUND in bundle — embedded server disabled");
        return;
    }

    // ---- locate jvm.framework (embedded by CocoaPods into Runner.app/Frameworks) ----
    NSURL *jvmLib = nil;
    NSMutableArray<NSURL *> *candidates = [NSMutableArray array];
    for (NSURL *root in @[
             NSBundle.mainBundle.resourceURL,  // Zeus.app/
             [NSURL fileURLWithPath:[NSBundle.mainBundle bundlePath]],
         ]) {
        if (root == nil) continue;
        [candidates addObject:[root URLByAppendingPathComponent:@"Frameworks/jvm.framework/jvm"]];
        [candidates addObject:[root URLByAppendingPathComponent:@"jvm.framework/jvm"]];
    }
    for (NSURL *c in candidates) {
        if ([c checkResourceIsReachableAndReturnError:nil]) { jvmLib = c; break; }
    }
    if (!jvmLib) {
        os_log_error(_zeusLog, "jvm.framework/jvm not found under app bundle — embedded server disabled");
        return;
    }

    NSURL *javaHome = [[jvmLib URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"javahome"];
    if (![javaHome checkResourceIsReachableAndReturnError:nil]) {
        os_log_error(_zeusLog, "javahome missing next to jvm: %{public}@", javaHome.path);
        return;
    }

    ZeusJVMBoot *boot = calloc(1, sizeof(ZeusJVMBoot));
    boot->vmLibrary = dlopen(jvmLib.path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
    if (!boot->vmLibrary) {
        os_log_error(_zeusLog, "dlopen(%{public}@) failed: %{public}s", jvmLib.path, dlerror());
        free(boot);
        return;
    }
    strncpy(boot->javaHome, javaHome.path.fileSystemRepresentation, PATH_MAX - 1);
    strncpy(boot->jarPath, jar.fileSystemRepresentation, PATH_MAX - 1);

    // ---- dedicated 16 MiB-stack pthread (OpenJ9Kit pattern); frees boot when done ----
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setstacksize(&attr, 16 * 1024 * 1024);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_t tid;
    int rc = pthread_create(&tid, &attr, ZeusJavaThreadMain, boot);
    pthread_attr_destroy(&attr);
    if (rc != 0) {
        os_log_error(_zeusLog, "pthread_create failed: %d", rc);
        free(boot);
        return;
    }
    os_log(_zeusLog, "embedded JVM thread started (jvm=%{public}@)", jvmLib.path);
}

@end
