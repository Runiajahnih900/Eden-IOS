// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EdenIOSBootstrapBridgeResult : NSObject

@property(nonatomic, assign, readonly) BOOL ready;
@property(nonatomic, assign, readonly) BOOL onIOS;
@property(nonatomic, assign, readonly) BOOL moltenVKAvailable;
@property(nonatomic, assign, readonly) BOOL gamePathValid;
@property(nonatomic, copy, readonly) NSString* report;

- (instancetype)initWithReady:(BOOL)ready
                        onIOS:(BOOL)onIOS
            moltenVKAvailable:(BOOL)moltenVKAvailable
                gamePathValid:(BOOL)gamePathValid
                       report:(NSString*)report NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface EdenIOSBootstrapBridge : NSObject

+ (NSInteger)abiVersion;

+ (EdenIOSBootstrapBridgeResult*)prepareWithRequestJIT:(BOOL)requestJIT
                                 enableValidationLayers:(BOOL)enableValidationLayers
                                               gamePath:(nullable NSString*)gamePath;

@end

NS_ASSUME_NONNULL_END

#endif
