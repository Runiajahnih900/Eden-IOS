// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import <UIKit/UIKit.h>

#import "ios_runtime_demo_controller.h"

@interface EdenIOSAppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, strong) UIWindow* window;

@end

@implementation EdenIOSAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    EdenIOSRuntimeDemoController* root_view_controller =
        [[EdenIOSRuntimeDemoController alloc] initWithRequestJIT:NO enableValidationLayers:NO];
    UINavigationController* navigation_controller =
        [[UINavigationController alloc] initWithRootViewController:root_view_controller];
    self.window.rootViewController = navigation_controller;
    [self.window makeKeyAndVisible];

    return YES;
}

@end

int main(int argc, char* argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([EdenIOSAppDelegate class]));
    }
}
