// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import <UIKit/UIKit.h>

#if defined(YUZU_IOS_BOOTSTRAP)
#import "ios_bootstrap_objc_bridge.h"
#import "ios_runtime_objc_bridge.h"
#import "ios_runtime_demo_controller.h"
#endif

static NSString* const EdenLiveLogEndpointDefaultsKey = @"EdenLiveLogEndpoint";
static NSString* const EdenLiveUpdateURLDefaultsKey = @"EdenLiveUpdateURL";
static NSString* const EdenLastGamePathDefaultsKey = @"EdenLastGamePath";
static NSString* const EdenGraphicsRendererDefaultsKey = @"EdenGraphicsRenderer";
static NSString* const EdenGraphicsResolutionDefaultsKey = @"EdenGraphicsResolution";
static NSString* const EdenGraphicsValidationDefaultsKey = @"EdenGraphicsValidation";
static NSString* const EdenDefaultLiveUpdateURL = @"https://api.github.com/repos/Runiajahnih900/Eden-IOS/releases/latest";

static NSTimeInterval const EdenHeartbeatIntervalSeconds = 12.0;
static NSTimeInterval const EdenUpdateCheckIntervalSeconds = 90.0;

static NSArray<NSNumber*>* EdenParseVersionComponents(NSString* versionString) {
    if (versionString.length == 0) {
        return @[@0];
    }

    NSCharacterSet* allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
    NSMutableString* sanitized = [NSMutableString stringWithCapacity:versionString.length];
    for (NSUInteger i = 0; i < versionString.length; ++i) {
        const unichar ch = [versionString characterAtIndex:i];
        if ([allowed characterIsMember:ch]) {
            [sanitized appendFormat:@"%C", ch];
        }
    }

    NSArray<NSString*>* parts = [sanitized componentsSeparatedByString:@"."];
    NSMutableArray<NSNumber*>* values = [NSMutableArray arrayWithCapacity:parts.count];
    for (NSString* part in parts) {
        if (part.length == 0) {
            continue;
        }
        [values addObject:@(part.integerValue)];
    }

    return values.count > 0 ? values : @[@0];
}

static BOOL EdenIsVersionNewer(NSString* candidateVersion, NSString* currentVersion) {
    NSArray<NSNumber*>* candidateValues = EdenParseVersionComponents(candidateVersion);
    NSArray<NSNumber*>* currentValues = EdenParseVersionComponents(currentVersion);

    NSUInteger count = MAX(candidateValues.count, currentValues.count);
    for (NSUInteger i = 0; i < count; ++i) {
        NSInteger left = i < candidateValues.count ? candidateValues[i].integerValue : 0;
        NSInteger right = i < currentValues.count ? currentValues[i].integerValue : 0;
        if (left > right) {
            return YES;
        }
        if (left < right) {
            return NO;
        }
    }

    return NO;
}

@interface EdenIOSHomeController : UIViewController

@property(nonatomic, strong) UITextField* liveLogField;
@property(nonatomic, strong) UITextField* liveUpdateField;
@property(nonatomic, strong) UILabel* statusLabel;
@property(nonatomic, strong) NSTimer* heartbeatTimer;
@property(nonatomic, strong) NSTimer* updateTimer;
@property(nonatomic, assign) NSUInteger heartbeatCount;
@property(nonatomic, copy) NSString* lastNotifiedUpdateVersion;

@end

@implementation EdenIOSHomeController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Eden iOS";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* savedLog = [defaults stringForKey:EdenLiveLogEndpointDefaultsKey] ?: @"";
    NSString* savedUpdate = [defaults stringForKey:EdenLiveUpdateURLDefaultsKey] ?: EdenDefaultLiveUpdateURL;

    UILabel* introLabel = [[UILabel alloc] init];
    introLabel.translatesAutoresizingMaskIntoConstraints = NO;
    introLabel.numberOfLines = 0;
    introLabel.textAlignment = NSTextAlignmentCenter;
    introLabel.text = @"Live logging aktif untuk komunikasi 2 perangkat.\nLive update akan cek perbaikan otomatis.";

    self.liveLogField = [[UITextField alloc] init];
    self.liveLogField.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveLogField.borderStyle = UITextBorderStyleRoundedRect;
    self.liveLogField.placeholder = @"Live log endpoint (http://IP-PC:8787/log/)";
    self.liveLogField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.liveLogField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.liveLogField.keyboardType = UIKeyboardTypeURL;
    self.liveLogField.text = savedLog;

    UIButton* saveLogButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveLogButton.translatesAutoresizingMaskIntoConstraints = NO;
    [saveLogButton setTitle:@"Aktifkan Live Logging" forState:UIControlStateNormal];
    [saveLogButton addTarget:self action:@selector(onSaveLiveLogEndpoint) forControlEvents:UIControlEventTouchUpInside];

    UIButton* pingButton = [UIButton buttonWithType:UIButtonTypeSystem];
    pingButton.translatesAutoresizingMaskIntoConstraints = NO;
    [pingButton setTitle:@"Kirim Ping" forState:UIControlStateNormal];
    [pingButton addTarget:self action:@selector(onPingNow) forControlEvents:UIControlEventTouchUpInside];

    UIButton* startRuntimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startRuntimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [startRuntimeButton setTitle:@"Mulai Runtime" forState:UIControlStateNormal];
    [startRuntimeButton addTarget:self action:@selector(onStartRuntimeNow) forControlEvents:UIControlEventTouchUpInside];

    UIButton* stopRuntimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    stopRuntimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [stopRuntimeButton setTitle:@"Hentikan Runtime" forState:UIControlStateNormal];
    [stopRuntimeButton addTarget:self action:@selector(onStopRuntimeNow) forControlEvents:UIControlEventTouchUpInside];

    UIButton* refreshRuntimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshRuntimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshRuntimeButton setTitle:@"Status Runtime" forState:UIControlStateNormal];
    [refreshRuntimeButton addTarget:self action:@selector(onRefreshRuntimeNow) forControlEvents:UIControlEventTouchUpInside];

    self.liveUpdateField = [[UITextField alloc] init];
    self.liveUpdateField.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveUpdateField.borderStyle = UITextBorderStyleRoundedRect;
    self.liveUpdateField.placeholder = @"URL update feed (default GitHub Releases)";
    self.liveUpdateField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.liveUpdateField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.liveUpdateField.keyboardType = UIKeyboardTypeURL;
    self.liveUpdateField.text = savedUpdate;

    UIButton* saveUpdateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveUpdateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [saveUpdateButton setTitle:@"Simpan URL Update" forState:UIControlStateNormal];
    [saveUpdateButton addTarget:self action:@selector(onSaveLiveUpdateURL) forControlEvents:UIControlEventTouchUpInside];

    UIButton* checkUpdateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    checkUpdateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [checkUpdateButton setTitle:@"Cek Update Sekarang" forState:UIControlStateNormal];
    [checkUpdateButton addTarget:self action:@selector(onCheckUpdateNow) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentLeft;
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.statusLabel.text = @"Status: inisialisasi layanan live...";

    UIStackView* logButtons = [[UIStackView alloc] initWithArrangedSubviews:@[saveLogButton, pingButton]];
    logButtons.translatesAutoresizingMaskIntoConstraints = NO;
    logButtons.axis = UILayoutConstraintAxisHorizontal;
    logButtons.spacing = 10.0;
    logButtons.distribution = UIStackViewDistributionFillEqually;

    UIStackView* runtimeButtons = [[UIStackView alloc] initWithArrangedSubviews:@[startRuntimeButton, stopRuntimeButton, refreshRuntimeButton]];
    runtimeButtons.translatesAutoresizingMaskIntoConstraints = NO;
    runtimeButtons.axis = UILayoutConstraintAxisHorizontal;
    runtimeButtons.spacing = 8.0;
    runtimeButtons.distribution = UIStackViewDistributionFillEqually;

    UIStackView* updateButtons = [[UIStackView alloc] initWithArrangedSubviews:@[saveUpdateButton, checkUpdateButton]];
    updateButtons.translatesAutoresizingMaskIntoConstraints = NO;
    updateButtons.axis = UILayoutConstraintAxisHorizontal;
    updateButtons.spacing = 10.0;
    updateButtons.distribution = UIStackViewDistributionFillEqually;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        introLabel,
        self.liveLogField,
        logButtons,
        runtimeButtons,
        self.liveUpdateField,
        updateButtons,
        self.statusLabel,
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;

    [self.view addSubview:stack];
    UILayoutGuide* guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:guide.topAnchor constant:16.0],
    ]];

    [self startLiveServices];
}

- (void)dealloc {
    [self.heartbeatTimer invalidate];
    [self.updateTimer invalidate];
#if defined(YUZU_IOS_BOOTSTRAP)
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:EdenIOSRuntimeEventNotification
                                                  object:nil];
    [EdenIOSRuntimeBridge setEventNotificationsEnabled:NO];
#endif
}

- (NSString*)currentShortVersion {
    NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
    NSString* value = info[@"CFBundleShortVersionString"];
    return value.length > 0 ? value : @"0.0.0";
}

- (NSString*)currentBuildVersion {
    NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
    NSString* value = info[@"CFBundleVersion"];
    return value.length > 0 ? value : @"0";
}

- (NSString*)savedLiveLogEndpoint {
    NSString* endpoint = [self.liveLogField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return endpoint.length > 0 ? endpoint : @"";
}

- (NSString*)savedUpdateURL {
    NSString* updateURL = [self.liveUpdateField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return updateURL.length > 0 ? updateURL : EdenDefaultLiveUpdateURL;
}

- (void)onSaveLiveLogEndpoint {
    NSString* endpoint = [self savedLiveLogEndpoint];
    [[NSUserDefaults standardUserDefaults] setObject:endpoint forKey:EdenLiveLogEndpointDefaultsKey];
#if defined(YUZU_IOS_BOOTSTRAP)
    [EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:endpoint];
#endif
    [self sendLiveLogEvent:@"set_log_endpoint" report:@"endpoint-updated" extra:nil];
    self.statusLabel.text = [NSString stringWithFormat:@"Status: live logging endpoint aktif -> %@", endpoint.length > 0 ? endpoint : @"(kosong)"];
}

- (void)onSaveLiveUpdateURL {
    NSString* updateURL = [self savedUpdateURL];
    [[NSUserDefaults standardUserDefaults] setObject:updateURL forKey:EdenLiveUpdateURLDefaultsKey];
    self.statusLabel.text = [NSString stringWithFormat:@"Status: update feed disimpan -> %@", updateURL];
}

- (void)onPingNow {
    [self sendLiveLogEvent:@"manual_ping" report:@"ping-button-tapped" extra:nil];
    self.statusLabel.text = @"Status: ping terkirim.";
}

- (void)onCheckUpdateNow {
    [self checkForUpdatesNow:YES];
}

- (void)onStartRuntimeNow {
#if defined(YUZU_IOS_BOOTSTRAP)
    NSString* selectedGamePath = [[NSUserDefaults standardUserDefaults] stringForKey:EdenLastGamePathDefaultsKey] ?: @"";
    selectedGamePath = [selectedGamePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (selectedGamePath.length == 0) {
        self.statusLabel.text = @"Status runtime: belum ada game dipilih. Buka tab Play lalu pilih game.";
        [self sendLiveLogEvent:@"runtime_start_missing_game" report:@"no-game-selected" extra:nil];
        return;
    }

    [EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:[self savedLiveLogEndpoint]];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSInteger rendererBackend = [defaults integerForKey:EdenGraphicsRendererDefaultsKey];
    if (rendererBackend == 0) {
        rendererBackend = 1;
    }
    NSInteger resolutionSetup = [defaults integerForKey:EdenGraphicsResolutionDefaultsKey];
    if (resolutionSetup == 0) {
        resolutionSetup = 3;
    }
    BOOL enableValidationLayers = [defaults boolForKey:EdenGraphicsValidationDefaultsKey];

    EdenIOSRuntimeBridgeResult* result = [EdenIOSRuntimeBridge startWithRequestJIT:NO
                                                           enableValidationLayers:enableValidationLayers
                                                             startExecutionThread:YES
                                                                         gamePath:selectedGamePath
                                                                  rendererBackend:rendererBackend
                                                                   resolutionSetup:resolutionSetup];
    self.statusLabel.text = [NSString stringWithFormat:@"Status runtime: %@ (running=%@)", result.report, result.running ? @"yes" : @"no"];
    NSDictionary* extra = @{
        @"running": @(result.running),
        @"sessionID": @(result.sessionID),
        @"tickCount": @(result.tickCount),
        @"gamePath": selectedGamePath,
    };
    [self sendLiveLogEvent:@"runtime_start" report:result.report extra:extra];
#else
    self.statusLabel.text = @"Status: runtime emulator belum ditautkan di build ini.";
#endif
}

- (void)onStopRuntimeNow {
#if defined(YUZU_IOS_BOOTSTRAP)
    [EdenIOSRuntimeBridge stop];
    EdenIOSRuntimeBridgeResult* state = [EdenIOSRuntimeBridge state];
    self.statusLabel.text = [NSString stringWithFormat:@"Status runtime: stop -> %@", state.report];
    [self sendLiveLogEvent:@"runtime_stop" report:state.report extra:nil];
#else
    self.statusLabel.text = @"Status: runtime emulator belum ditautkan di build ini.";
#endif
}

- (void)onRefreshRuntimeNow {
#if defined(YUZU_IOS_BOOTSTRAP)
    EdenIOSRuntimeBridgeResult* state = [EdenIOSRuntimeBridge state];
    self.statusLabel.text = [NSString stringWithFormat:@"Runtime running=%@ session=%lu tick=%lu", state.running ? @"yes" : @"no", (unsigned long)state.sessionID, (unsigned long)state.tickCount];
#else
    self.statusLabel.text = @"Status: runtime emulator belum ditautkan di build ini.";
#endif
}

- (void)startLiveServices {
    [self sendLiveLogEvent:@"app_open" report:@"live-services-started" extra:nil];

#if defined(YUZU_IOS_BOOTSTRAP)
    [EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:[self savedLiveLogEndpoint]];
    [EdenIOSRuntimeBridge setEventNotificationsEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onRuntimeEvent:)
                                                 name:EdenIOSRuntimeEventNotification
                                               object:nil];

    NSString* selectedGamePath = [[NSUserDefaults standardUserDefaults] stringForKey:EdenLastGamePathDefaultsKey] ?: @"";
    selectedGamePath = [selectedGamePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    EdenIOSBootstrapBridgeResult* preflight = [EdenIOSBootstrapBridge prepareWithRequestJIT:NO
                                                                     enableValidationLayers:NO
                                                                                   gamePath:selectedGamePath.length > 0 ? selectedGamePath : nil];
    NSDictionary* extra = @{
        @"ready": @(preflight.ready),
        @"onIOS": @(preflight.onIOS),
        @"moltenVKAvailable": @(preflight.moltenVKAvailable),
        @"gamePathValid": @(preflight.gamePathValid),
    };
    [self sendLiveLogEvent:@"runtime_preflight" report:preflight.report extra:extra];
    self.statusLabel.text = [NSString stringWithFormat:@"Status preflight: %@", preflight.report];
#endif

    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:EdenHeartbeatIntervalSeconds
                                                            target:self
                                                          selector:@selector(onHeartbeatTick)
                                                          userInfo:nil
                                                           repeats:YES];

    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:EdenUpdateCheckIntervalSeconds
                                                         target:self
                                                       selector:@selector(onAutoUpdateCheck)
                                                       userInfo:nil
                                                        repeats:YES];

    [self checkForUpdatesNow:NO];
}

- (void)onRuntimeEvent:(NSNotification*)notification {
#if defined(YUZU_IOS_BOOTSTRAP)
    NSDictionary* userInfo = notification.userInfo;
    NSString* report = [userInfo[EdenIOSRuntimeEventReportKey] isKindOfClass:[NSString class]]
                           ? userInfo[EdenIOSRuntimeEventReportKey]
                           : @"";
    NSString* type = [userInfo[EdenIOSRuntimeEventTypeKey] isKindOfClass:[NSString class]]
                         ? userInfo[EdenIOSRuntimeEventTypeKey]
                         : @"unknown";
    NSNumber* running = [userInfo[EdenIOSRuntimeEventRunningKey] isKindOfClass:[NSNumber class]]
                            ? userInfo[EdenIOSRuntimeEventRunningKey]
                            : @NO;
    NSNumber* sessionID = [userInfo[EdenIOSRuntimeEventSessionIDKey] isKindOfClass:[NSNumber class]]
                              ? userInfo[EdenIOSRuntimeEventSessionIDKey]
                              : @0;
    NSNumber* tickCount = [userInfo[EdenIOSRuntimeEventTickCountKey] isKindOfClass:[NSNumber class]]
                              ? userInfo[EdenIOSRuntimeEventTickCountKey]
                              : @0;
    self.statusLabel.text = [NSString stringWithFormat:@"Runtime[%@] running=%@ sid=%@ tick=%@", type, running.boolValue ? @"yes" : @"no", sessionID, tickCount];
    if (report.length > 0) {
        [self sendLiveLogEvent:@"runtime_event" report:report extra:@{ @"type": type }];
    }
#else
    (void)notification;
#endif
}

- (void)onHeartbeatTick {
    self.heartbeatCount += 1;
    NSDictionary* extra = @{
        @"heartbeat": @(self.heartbeatCount),
        @"device": [UIDevice currentDevice].name ?: @"unknown",
        @"appVersion": [self currentShortVersion],
    };
    [self sendLiveLogEvent:@"heartbeat" report:@"live-heartbeat" extra:extra];
}

- (void)onAutoUpdateCheck {
    [self checkForUpdatesNow:NO];
}

- (void)sendLiveLogEvent:(NSString*)event report:(NSString*)report extra:(NSDictionary* _Nullable)extra {
    NSString* endpoint = [[NSUserDefaults standardUserDefaults] stringForKey:EdenLiveLogEndpointDefaultsKey];
    if (endpoint.length == 0) {
        return;
    }

    NSURL* url = [NSURL URLWithString:endpoint];
    if (url == nil) {
        return;
    }

    NSMutableDictionary* payload = [NSMutableDictionary dictionaryWithDictionary:@{
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"event": event ?: @"unknown",
        @"running": @NO,
        @"lastStartSucceeded": @NO,
        @"runThreadActive": @NO,
        @"sessionID": @0,
        @"tickCount": @(self.heartbeatCount),
        @"report": report ?: @"",
        @"device": [UIDevice currentDevice].name ?: @"unknown",
        @"appVersion": [NSString stringWithFormat:@"%@ (%@)", [self currentShortVersion], [self currentBuildVersion]],
    }];

    if (extra != nil) {
        [payload addEntriesFromDictionary:extra];
    }

    NSError* error = nil;
    NSData* body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (body == nil || error != nil) {
        return;
    }

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)checkForUpdatesNow:(BOOL)manual {
    NSString* updateURL = [[NSUserDefaults standardUserDefaults] stringForKey:EdenLiveUpdateURLDefaultsKey];
    if (updateURL.length == 0) {
        updateURL = EdenDefaultLiveUpdateURL;
    }

    NSURL* url = [NSURL URLWithString:updateURL];
    if (url == nil) {
        if (manual) {
            self.statusLabel.text = @"Status: URL update tidak valid.";
        }
        return;
    }

#if __has_feature(objc_arc)
    __weak typeof(self) weakSelf = self;
#else
    __unsafe_unretained typeof(self) weakSelf = self;
#endif
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                  completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        (void)response;
        if (error != nil || data == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (manual) {
                    weakSelf.statusLabel.text = [NSString stringWithFormat:@"Status: cek update gagal (%@)", error.localizedDescription ?: @"unknown"];
                }
            });
            return;
        }

        NSError* parseError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
        if (parseError != nil || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (manual) {
                    weakSelf.statusLabel.text = @"Status: format feed update tidak dikenali.";
                }
            });
            return;
        }

        NSDictionary* dict = (NSDictionary*)json;
        NSString* availableVersion = @"";
        NSString* updateNotes = @"";
        NSString* updateLink = @"";

        if ([dict[@"tag_name"] isKindOfClass:[NSString class]]) {
            availableVersion = dict[@"tag_name"];
        } else if ([dict[@"version"] isKindOfClass:[NSString class]]) {
            availableVersion = dict[@"version"];
        } else if ([dict[@"latest_version"] isKindOfClass:[NSString class]]) {
            availableVersion = dict[@"latest_version"];
        }

        if ([dict[@"body"] isKindOfClass:[NSString class]]) {
            updateNotes = dict[@"body"];
        } else if ([dict[@"notes"] isKindOfClass:[NSString class]]) {
            updateNotes = dict[@"notes"];
        }

        if ([dict[@"html_url"] isKindOfClass:[NSString class]]) {
            updateLink = dict[@"html_url"];
        } else if ([dict[@"download_url"] isKindOfClass:[NSString class]]) {
            updateLink = dict[@"download_url"];
        }

        NSString* currentVersion = [weakSelf currentShortVersion];
        BOOL hasUpdate = availableVersion.length > 0 && EdenIsVersionNewer(availableVersion, currentVersion);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!hasUpdate) {
                if (manual) {
                    weakSelf.statusLabel.text = [NSString stringWithFormat:@"Status: app sudah terbaru (%@)", currentVersion];
                }
                return;
            }

            if ([weakSelf.lastNotifiedUpdateVersion isEqualToString:availableVersion]) {
                return;
            }

            weakSelf.lastNotifiedUpdateVersion = availableVersion;
            weakSelf.statusLabel.text = [NSString stringWithFormat:@"Status: update tersedia %@ (versi sekarang %@)", availableVersion, currentVersion];

            NSDictionary* extra = @{
                @"availableVersion": availableVersion,
                @"currentVersion": currentVersion,
            };
            [weakSelf sendLiveLogEvent:@"update_available" report:@"update-notification-shown" extra:extra];

            NSString* message = updateNotes.length > 0 ? updateNotes : @"Ada pembaruan aplikasi yang tersedia.";
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Update Tersedia (%@)", availableVersion]
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            if (updateLink.length > 0) {
                [alert addAction:[UIAlertAction actionWithTitle:@"Buka Link Update"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(__unused UIAlertAction* action) {
                    NSURL* linkURL = [NSURL URLWithString:updateLink];
                    if (linkURL != nil) {
                        [[UIApplication sharedApplication] openURL:linkURL options:@{} completionHandler:nil];
                    }
                }]];
            }

            [alert addAction:[UIAlertAction actionWithTitle:@"Nanti"
                                                      style:UIAlertActionStyleCancel
                                                    handler:nil]];
            [weakSelf presentViewController:alert animated:YES completion:nil];
        });
    }] resume];
}

@end

@interface EdenIOSAppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, strong) UIWindow* window;

@end

@implementation EdenIOSAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    EdenIOSHomeController* toolsController = [[EdenIOSHomeController alloc] init];
    UINavigationController* toolsNav = [[UINavigationController alloc] initWithRootViewController:toolsController];
    toolsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Tools"
                                                        image:[UIImage systemImageNamed:@"wrench.and.screwdriver"]
                                                          tag:1];

#if defined(YUZU_IOS_BOOTSTRAP)
    EdenIOSRuntimeDemoController* playController =
        [[EdenIOSRuntimeDemoController alloc] initWithRequestJIT:NO enableValidationLayers:NO];
    UINavigationController* playNav = [[UINavigationController alloc] initWithRootViewController:playController];
    playNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Play"
                                                        image:[UIImage systemImageNamed:@"gamecontroller.fill"]
                                                          tag:0];

    UITabBarController* tabBar = [[UITabBarController alloc] init];
    tabBar.viewControllers = @[playNav, toolsNav];
    tabBar.selectedIndex = 0;
    self.window.rootViewController = tabBar;
#else
    self.window.rootViewController = toolsNav;
#endif

    [self.window makeKeyAndVisible];

    return YES;
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([EdenIOSAppDelegate class]));
    }
}
