// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#ifdef __OBJC__

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EdenIOSSetupBridgeResult : NSObject

@property(nonatomic, assign, readonly) BOOL success;
@property(nonatomic, assign, readonly) BOOL keysInstalled;
@property(nonatomic, assign, readonly) BOOL firmwareInstalled;
@property(nonatomic, copy, readonly) NSString* report;

- (instancetype)initWithSuccess:(BOOL)success
                  keysInstalled:(BOOL)keysInstalled
              firmwareInstalled:(BOOL)firmwareInstalled
                         report:(NSString*)report NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface EdenIOSSetupBridge : NSObject

+ (EdenIOSSetupBridgeResult*)status;

+ (EdenIOSSetupBridgeResult*)installKeysFromProdKeysPath:(NSString*)prodKeysPath;

+ (EdenIOSSetupBridgeResult*)installFirmwareFromPath:(NSString*)sourcePath
                                           recursive:(BOOL)recursive;

@end

NS_ASSUME_NONNULL_END

#endif
