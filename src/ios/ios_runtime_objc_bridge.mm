// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_runtime_objc_bridge.h"

#import "ios_runtime_c_api.h"

NSNotificationName const EdenIOSRuntimeEventNotification = @"EdenIOSRuntimeEventNotification";
NSString* const EdenIOSRuntimeEventTypeKey = @"type";
NSString* const EdenIOSRuntimeEventRunningKey = @"running";
NSString* const EdenIOSRuntimeEventLastStartSucceededKey = @"lastStartSucceeded";
NSString* const EdenIOSRuntimeEventRunThreadActiveKey = @"runThreadActive";
NSString* const EdenIOSRuntimeEventSessionIDKey = @"sessionID";
NSString* const EdenIOSRuntimeEventTickCountKey = @"tickCount";
NSString* const EdenIOSRuntimeEventReportKey = @"report";

namespace {

NSString* RuntimeEventTypeToString(const EdenIOSRuntimeEventType event_type) {
    switch (event_type) {
    case EDEN_IOS_RUNTIME_EVENT_START:
        return @"start";
    case EDEN_IOS_RUNTIME_EVENT_STOP:
        return @"stop";
    case EDEN_IOS_RUNTIME_EVENT_TICK:
        return @"tick";
    default:
        return @"unknown";
    }
}

void RuntimeEventNotificationCallback(const EdenIOSRuntimeEventType event_type,
                                      const EdenIOSRuntimeState* state,
                                      const char* report,
                                      void* user_data) {
    (void)user_data;
    @autoreleasepool {
        NSString* report_string = @"";
        if (report) {
            NSString* tmp = [NSString stringWithUTF8String:report];
            if (tmp) {
                report_string = tmp;
            }
        }
        NSDictionary* user_info = @{
            EdenIOSRuntimeEventTypeKey: RuntimeEventTypeToString(event_type),
            EdenIOSRuntimeEventRunningKey: @((state && state->running != 0)),
            EdenIOSRuntimeEventLastStartSucceededKey: @((state && state->last_start_succeeded != 0)),
            EdenIOSRuntimeEventRunThreadActiveKey: @((state && state->run_thread_active != 0)),
            EdenIOSRuntimeEventSessionIDKey: @((state ? state->session_id : 0)),
            EdenIOSRuntimeEventTickCountKey: @((state ? state->tick_count : 0)),
            EdenIOSRuntimeEventReportKey: report_string,
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:EdenIOSRuntimeEventNotification
                                                            object:nil
                                                          userInfo:user_info];
    }
}

} // namespace

@implementation EdenIOSRuntimeBridgeResult

- (instancetype)initWithRunning:(BOOL)running
             lastStartSucceeded:(BOOL)lastStartSucceeded
        runThreadActive:(BOOL)runThreadActive
                      sessionID:(NSUInteger)sessionID
                      tickCount:(NSUInteger)tickCount
                        report:(NSString*)report {
    self = [super init];
    if (self) {
        _running = running;
        _lastStartSucceeded = lastStartSucceeded;
    _runThreadActive = runThreadActive;
        _sessionID = sessionID;
        _tickCount = tickCount;
        _report = [report copy];
    }
    return self;
}

@end

@implementation EdenIOSRuntimeBridge

+ (EdenIOSRuntimeBridgeResult*)startWithRequestJIT:(BOOL)requestJIT
                             enableValidationLayers:(BOOL)enableValidationLayers
                               startExecutionThread:(BOOL)startExecutionThread
                                           gamePath:(nullable NSString*)gamePath {
    EdenIOSRuntimeStartOptions options = {
        .request_jit = requestJIT ? 1 : 0,
        .enable_validation_layers = enableValidationLayers ? 1 : 0,
        .start_execution_thread = startExecutionThread ? 1 : 0,
        .game_path = gamePath != nil ? [gamePath UTF8String] : NULL,
    };

    EdenIOSRuntimeState state = {0};
    char report_buffer[4096] = {0};
    const int ok = EdenIOSRuntimeStart(&options, &state, report_buffer, sizeof(report_buffer));
    NSString* report = ok ? [NSString stringWithUTF8String:report_buffer]
                          : @"runtime-start-failed";

    return [[EdenIOSRuntimeBridgeResult alloc] initWithRunning:(state.running != 0)
                                             lastStartSucceeded:(state.last_start_succeeded != 0)
                               runThreadActive:(state.run_thread_active != 0)
                                                     sessionID:(NSUInteger)state.session_id
                                                     tickCount:(NSUInteger)state.tick_count
                                                        report:report];
}

+ (void)stop {
    EdenIOSRuntimeStop();
}

+ (EdenIOSRuntimeBridgeResult*)tick {
    EdenIOSRuntimeState state = {0};
    char report_buffer[4096] = {0};
    const int ok = EdenIOSRuntimeTick(&state, report_buffer, sizeof(report_buffer));
    NSString* report = ok ? [NSString stringWithUTF8String:report_buffer]
                          : @"runtime-tick-failed";

    return [[EdenIOSRuntimeBridgeResult alloc] initWithRunning:(state.running != 0)
                                             lastStartSucceeded:(state.last_start_succeeded != 0)
                               runThreadActive:(state.run_thread_active != 0)
                                                     sessionID:(NSUInteger)state.session_id
                                                     tickCount:(NSUInteger)state.tick_count
                                                        report:report];
}

+ (EdenIOSRuntimeBridgeResult*)state {
    EdenIOSRuntimeState state = {0};
    char report_buffer[4096] = {0};
    const int ok = EdenIOSRuntimeGetState(&state, report_buffer, sizeof(report_buffer));
    NSString* report = ok ? [NSString stringWithUTF8String:report_buffer]
                          : @"runtime-state-query-failed";

    return [[EdenIOSRuntimeBridgeResult alloc] initWithRunning:(state.running != 0)
                                             lastStartSucceeded:(state.last_start_succeeded != 0)
                               runThreadActive:(state.run_thread_active != 0)
                                                     sessionID:(NSUInteger)state.session_id
                                                     tickCount:(NSUInteger)state.tick_count
                                                        report:report];
}

+ (void)setEventNotificationsEnabled:(BOOL)enabled {
    EdenIOSRuntimeSetEventCallback(enabled ? RuntimeEventNotificationCallback : NULL, NULL);
}

@end
