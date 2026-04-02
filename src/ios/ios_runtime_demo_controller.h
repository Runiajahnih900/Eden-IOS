// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#ifdef __OBJC__

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EdenIOSRuntimeDemoController : UIViewController

- (instancetype)initWithRequestJIT:(BOOL)requestJIT
            enableValidationLayers:(BOOL)enableValidationLayers NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString*)nibNameOrNil
                         bundle:(nullable NSBundle*)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
