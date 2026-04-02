// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const EdenIOSRuntimeEventNotification;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventTypeKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventRunningKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventLastStartSucceededKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventRunThreadActiveKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventSessionIDKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventTickCountKey;
FOUNDATION_EXPORT NSString* const EdenIOSRuntimeEventReportKey;

@interface EdenIOSRuntimeBridgeResult : NSObject

@property(nonatomic, assign, readonly) BOOL running;
@property(nonatomic, assign, readonly) BOOL lastStartSucceeded;
@property(nonatomic, assign, readonly) BOOL runThreadActive;
@property(nonatomic, assign, readonly) NSUInteger sessionID;
@property(nonatomic, assign, readonly) NSUInteger tickCount;
@property(nonatomic, copy, readonly) NSString* report;

- (instancetype)initWithRunning:(BOOL)running
             lastStartSucceeded:(BOOL)lastStartSucceeded
                runThreadActive:(BOOL)runThreadActive
                      sessionID:(NSUInteger)sessionID
                      tickCount:(NSUInteger)tickCount
                        report:(NSString*)report NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface EdenIOSRuntimeBridge : NSObject

+ (EdenIOSRuntimeBridgeResult*)startWithRequestJIT:(BOOL)requestJIT
                             enableValidationLayers:(BOOL)enableValidationLayers
                               startExecutionThread:(BOOL)startExecutionThread
                                           gamePath:(nullable NSString*)gamePath;

+ (void)stop;

+ (EdenIOSRuntimeBridgeResult*)tick;

+ (EdenIOSRuntimeBridgeResult*)state;

+ (void)setEventNotificationsEnabled:(BOOL)enabled;

+ (void)setRemoteDebugLogEndpoint:(nullable NSString*)endpoint;

+ (nullable NSString*)remoteDebugLogEndpoint;

@end

NS_ASSUME_NONNULL_END

#endif
