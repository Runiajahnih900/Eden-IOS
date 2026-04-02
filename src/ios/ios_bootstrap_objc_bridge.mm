// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_bootstrap_objc_bridge.h"

#import "ios_bootstrap_c_api.h"

@implementation EdenIOSBootstrapBridgeResult

- (instancetype)initWithReady:(BOOL)ready
                        onIOS:(BOOL)onIOS
            moltenVKAvailable:(BOOL)moltenVKAvailable
                gamePathValid:(BOOL)gamePathValid
                       report:(NSString*)report {
    self = [super init];
    if (self) {
        _ready = ready;
        _onIOS = onIOS;
        _moltenVKAvailable = moltenVKAvailable;
        _gamePathValid = gamePathValid;
        _report = [report copy];
    }
    return self;
}

@end

@implementation EdenIOSBootstrapBridge

+ (NSInteger)abiVersion {
    return (NSInteger)EdenIOSBootstrapAbiVersion();
}

+ (EdenIOSBootstrapBridgeResult*)prepareWithRequestJIT:(BOOL)requestJIT
                                 enableValidationLayers:(BOOL)enableValidationLayers
                                               gamePath:(nullable NSString*)gamePath {
    EdenIOSBootstrapOptions options = {
        .request_jit = requestJIT ? 1 : 0,
        .enable_validation_layers = enableValidationLayers ? 1 : 0,
        .game_path = gamePath != nil ? [gamePath UTF8String] : NULL,
    };

    EdenIOSBootstrapResult result = {0};

    char report_buffer[4096] = {0};
    const int ok = EdenIOSPrepareBootstrap(&options, &result, report_buffer, sizeof(report_buffer));
    NSString* report = ok ? [NSString stringWithUTF8String:report_buffer]
                          : @"bootstrap-call-failed";

    return [[EdenIOSBootstrapBridgeResult alloc] initWithReady:(result.ready != 0)
                                                         onIOS:(result.on_ios != 0)
                                             moltenVKAvailable:(result.moltenvk_available != 0)
                                                 gamePathValid:(result.game_path_valid != 0)
                                                        report:report];
}

@end
