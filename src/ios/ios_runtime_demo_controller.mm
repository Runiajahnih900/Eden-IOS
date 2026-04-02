// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_runtime_demo_controller.h"

#import "ios_runtime_view_model.h"

@interface EdenIOSRuntimeDemoController ()

@property(nonatomic, strong) EdenIOSRuntimeViewModel* viewModel;
@property(nonatomic, strong) UILabel* statusLabel;
@property(nonatomic, strong) UITextField* gamePathField;

@end

@implementation EdenIOSRuntimeDemoController

- (instancetype)initWithRequestJIT:(BOOL)requestJIT
            enableValidationLayers:(BOOL)enableValidationLayers {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[EdenIOSRuntimeViewModel alloc] initWithRequestJIT:requestJIT
                                                   enableValidationLayers:enableValidationLayers];
        __weak typeof(self) weakSelf = self;
        _viewModel.onStateChanged = ^(EdenIOSRuntimeBridgeResult* result, NSString* statusText) {
            (void)result;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.statusLabel.text = statusText;
            });
        };
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Eden iOS Runtime Demo";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.gamePathField = [[UITextField alloc] init];
    self.gamePathField.translatesAutoresizingMaskIntoConstraints = NO;
    self.gamePathField.borderStyle = UITextBorderStyleRoundedRect;
    self.gamePathField.placeholder = @"Masukkan path game (.nsp/.xci, dll)";
    self.gamePathField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.gamePathField.autocorrectionType = UITextAutocorrectionTypeNo;

    UIButton* startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [startButton setTitle:@"Start" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(onStartTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    stopButton.translatesAutoresizingMaskIntoConstraints = NO;
    [stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [stopButton addTarget:self action:@selector(onStopTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* tickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    tickButton.translatesAutoresizingMaskIntoConstraints = NO;
    [tickButton setTitle:@"Tick" forState:UIControlStateNormal];
    [tickButton addTarget:self action:@selector(onTickTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshButton setTitle:@"Refresh" forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(onRefreshTapped) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.statusLabel.text = self.viewModel.statusText;

    UIStackView* buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[startButton, stopButton, tickButton, refreshButton]];
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 12.0;
    buttonRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.gamePathField, buttonRow, self.statusLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    [self.view addSubview:stack];

    UILayoutGuide* guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:guide.topAnchor constant:16.0],
    ]];
}

- (void)onStartTapped {
    NSString* gamePath = self.gamePathField.text;
    [self.viewModel startWithGamePath:gamePath.length > 0 ? gamePath : nil];
}

- (void)onStopTapped {
    [self.viewModel stop];
}

- (void)onTickTapped {
    [self.viewModel tick];
}

- (void)onRefreshTapped {
    [self.viewModel refreshState];
}

@end
