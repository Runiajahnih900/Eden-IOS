// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_runtime_view_model.h"

@interface EdenIOSRuntimeViewModel ()

@property(nonatomic, assign) BOOL requestJIT;
@property(nonatomic, assign) BOOL enableValidationLayers;
@property(nonatomic, assign) BOOL startExecutionThread;
@property(nonatomic, copy, readwrite) NSString* statusText;
@property(nonatomic, strong, readwrite) EdenIOSRuntimeBridgeResult* latestResult;

@end

@implementation EdenIOSRuntimeViewModel

+ (NSString*)makeStatusText:(EdenIOSRuntimeBridgeResult*)result {
    NSString* running = result.running ? @"running" : @"idle";
    NSString* started = result.lastStartSucceeded ? @"start-ok" : @"start-failed";
    NSString* thread = result.runThreadActive ? @"thread=active" : @"thread=inactive";
    return [NSString stringWithFormat:@"%@ | %@ | %@ | session=%lu | tick=%lu | %@",
                                      running,
                                      started,
                                      thread,
                                      (unsigned long)result.sessionID,
                                      (unsigned long)result.tickCount,
                                      result.report ?: @""];
}

- (instancetype)initWithRequestJIT:(BOOL)requestJIT
            enableValidationLayers:(BOOL)enableValidationLayers {
    self = [super init];
    if (self) {
        _requestJIT = requestJIT;
        _enableValidationLayers = enableValidationLayers;
        _startExecutionThread = YES;

        [EdenIOSRuntimeBridge setEventNotificationsEnabled:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRuntimeEvent:)
                                                     name:EdenIOSRuntimeEventNotification
                                                   object:nil];

        _latestResult = [EdenIOSRuntimeBridge state];
        _statusText = [EdenIOSRuntimeViewModel makeStatusText:_latestResult];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)applyResultAndNotify:(EdenIOSRuntimeBridgeResult*)result {
    self.latestResult = result;
    self.statusText = [EdenIOSRuntimeViewModel makeStatusText:result];
    if (self.onStateChanged) {
        self.onStateChanged(result, self.statusText);
    }
}

- (void)handleRuntimeEvent:(NSNotification*)note {
    NSDictionary* userInfo = note.userInfo;
    BOOL running = [userInfo[EdenIOSRuntimeEventRunningKey] boolValue];
    BOOL lastStartSucceeded = [userInfo[EdenIOSRuntimeEventLastStartSucceededKey] boolValue];
    BOOL runThreadActive = [userInfo[EdenIOSRuntimeEventRunThreadActiveKey] boolValue];
    NSUInteger sessionID = [userInfo[EdenIOSRuntimeEventSessionIDKey] unsignedIntegerValue];
    NSUInteger tickCount = [userInfo[EdenIOSRuntimeEventTickCountKey] unsignedIntegerValue];
    NSString* report = userInfo[EdenIOSRuntimeEventReportKey] ?: @"";

    EdenIOSRuntimeBridgeResult* result =
        [[EdenIOSRuntimeBridgeResult alloc] initWithRunning:running
                                         lastStartSucceeded:lastStartSucceeded
                                            runThreadActive:runThreadActive
                                                  sessionID:sessionID
                                                  tickCount:tickCount
                                                    report:report];
    [self applyResultAndNotify:result];
}

- (EdenIOSRuntimeBridgeResult*)startWithGamePath:(nullable NSString*)gamePath {
    EdenIOSRuntimeBridgeResult* result =
        [EdenIOSRuntimeBridge startWithRequestJIT:self.requestJIT
                           enableValidationLayers:self.enableValidationLayers
                            startExecutionThread:self.startExecutionThread
                                         gamePath:gamePath];
    [self applyResultAndNotify:result];
    return result;
}

- (void)stop {
    [EdenIOSRuntimeBridge stop];
    EdenIOSRuntimeBridgeResult* result = [EdenIOSRuntimeBridge state];
    [self applyResultAndNotify:result];
}

- (EdenIOSRuntimeBridgeResult*)tick {
    EdenIOSRuntimeBridgeResult* result = [EdenIOSRuntimeBridge tick];
    [self applyResultAndNotify:result];
    return result;
}

- (EdenIOSRuntimeBridgeResult*)refreshState {
    EdenIOSRuntimeBridgeResult* result = [EdenIOSRuntimeBridge state];
    [self applyResultAndNotify:result];
    return result;
}

- (void)setStartExecutionThreadEnabled:(BOOL)enabled {
    self.startExecutionThread = enabled;
}

- (BOOL)isStartExecutionThreadEnabled {
    return self.startExecutionThread;
}

@end
