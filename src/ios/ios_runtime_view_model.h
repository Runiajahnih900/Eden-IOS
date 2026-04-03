// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>

#import "ios_runtime_objc_bridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface EdenIOSRuntimeViewModel : NSObject

@property(nonatomic, copy, readonly) NSString* statusText;
@property(nonatomic, strong, readonly) EdenIOSRuntimeBridgeResult* latestResult;
@property(nonatomic, copy, nullable) void (^onStateChanged)(EdenIOSRuntimeBridgeResult* result,
                                                           NSString* statusText);

- (instancetype)initWithRequestJIT:(BOOL)requestJIT
            enableValidationLayers:(BOOL)enableValidationLayers NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (EdenIOSRuntimeBridgeResult*)startWithGamePath:(nullable NSString*)gamePath;
- (void)stop;
- (EdenIOSRuntimeBridgeResult*)tick;
- (EdenIOSRuntimeBridgeResult*)refreshState;

- (void)setStartExecutionThreadEnabled:(BOOL)enabled;
- (BOOL)isStartExecutionThreadEnabled;

- (void)setValidationLayersEnabled:(BOOL)enabled;
- (BOOL)isValidationLayersEnabled;

- (void)setRendererBackendValue:(NSInteger)value;
- (NSInteger)rendererBackendValue;

- (void)setResolutionSetupValue:(NSInteger)value;
- (NSInteger)resolutionSetupValue;

@end

NS_ASSUME_NONNULL_END

#endif
