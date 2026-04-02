// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import <UIKit/UIKit.h>

@interface EdenIOSHomeController : UIViewController
@end

@implementation EdenIOSHomeController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Eden iOS";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel* label = [[UILabel alloc] initWithFrame:[UIScreen mainScreen].bounds];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"IPA bootstrap berhasil.\nAktifkan IOS_APP_LINK_BOOTSTRAP untuk runtime terintegrasi.";

    [self.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [label.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0],
    ]];
}

@end

@interface EdenIOSAppDelegate : UIResponder <UIApplicationDelegate>

@property(nonatomic, strong) UIWindow* window;

@end

@implementation EdenIOSAppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    (void)application;
    (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    EdenIOSHomeController* root_view_controller = [[EdenIOSHomeController alloc] init];
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
