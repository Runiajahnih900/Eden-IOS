// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_setup_objc_bridge.h"

#import "ios_setup_c_api.h"

namespace {

NSString* SafeNSString(const char* text) {
    if (!text) {
        return @"";
    }
    NSString* value = [NSString stringWithUTF8String:text];
    return value ? value : @"";
}

EdenIOSSetupBridgeResult* BuildResult(const BOOL success,
                                      const EdenIOSSetupStatus& status,
                                      const char* report) {
    return [[EdenIOSSetupBridgeResult alloc] initWithSuccess:success
                                               keysInstalled:(status.keys_installed != 0)
                                           firmwareInstalled:(status.firmware_installed != 0)
                                                      report:SafeNSString(report)];
}

} // namespace

@implementation EdenIOSSetupBridgeResult

- (instancetype)initWithSuccess:(BOOL)success
                  keysInstalled:(BOOL)keysInstalled
              firmwareInstalled:(BOOL)firmwareInstalled
                         report:(NSString*)report {
    self = [super init];
    if (self) {
        _success = success;
        _keysInstalled = keysInstalled;
        _firmwareInstalled = firmwareInstalled;
        _report = [report copy];
    }
    return self;
}

@end

@implementation EdenIOSSetupBridge

+ (EdenIOSSetupBridgeResult*)status {
    EdenIOSSetupStatus status = {0};
    char report_buffer[4096] = {0};
    const int ok = EdenIOSSetupGetStatus(&status, report_buffer, sizeof(report_buffer));
    return BuildResult(ok != 0, status, report_buffer);
}

+ (EdenIOSSetupBridgeResult*)installKeysFromProdKeysPath:(NSString*)prodKeysPath {
    EdenIOSSetupStatus status = {0};
    char report_buffer[4096] = {0};

    const int ok = EdenIOSInstallKeys(prodKeysPath != nil ? [prodKeysPath UTF8String] : NULL,
                                      &status, report_buffer, sizeof(report_buffer));
    return BuildResult(ok != 0, status, report_buffer);
}

+ (EdenIOSSetupBridgeResult*)installFirmwareFromPath:(NSString*)sourcePath
                                           recursive:(BOOL)recursive {
    EdenIOSSetupStatus status = {0};
    char report_buffer[4096] = {0};

    const int ok = EdenIOSInstallFirmware(sourcePath != nil ? [sourcePath UTF8String] : NULL,
                                          recursive ? 1 : 0,
                                          &status,
                                          report_buffer,
                                          sizeof(report_buffer));
    return BuildResult(ok != 0, status, report_buffer);
}

@end
