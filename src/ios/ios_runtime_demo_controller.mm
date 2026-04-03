// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_runtime_demo_controller.h"

#import "ios_setup_objc_bridge.h"
#import "ios_runtime_objc_bridge.h"
#import "ios_runtime_view_model.h"

static NSString* const EdenLastGamePathDefaultsKey = @"EdenLastGamePath";
static NSString* const EdenGraphicsRendererDefaultsKey = @"EdenGraphicsRenderer";
static NSString* const EdenGraphicsResolutionDefaultsKey = @"EdenGraphicsResolution";
static NSString* const EdenGraphicsValidationDefaultsKey = @"EdenGraphicsValidation";

static NSString* const EdenGamesFolderName = @"Games";

typedef NS_ENUM(NSInteger, EdenImportMode) {
    EdenImportModeGame = 0,
    EdenImportModeKeys = 1,
    EdenImportModeFirmware = 2,
};

static NSInteger EdenRendererIndexToValue(NSInteger index) {
    switch (index) {
    case 1:
        return 2; // RendererBackend::Null
    case 0:
    default:
        return 1; // RendererBackend::Vulkan
    }
}

static NSInteger EdenRendererValueToIndex(NSInteger value) {
    return value == 2 ? 1 : 0;
}

static NSInteger EdenResolutionIndexToValue(NSInteger index) {
    switch (index) {
    case 1:
        return 6; // ResolutionSetup::Res2X
    case 2:
        return 7; // ResolutionSetup::Res3X
    case 0:
    default:
        return 3; // ResolutionSetup::Res1X
    }
}

static NSInteger EdenResolutionValueToIndex(NSInteger value) {
    switch (value) {
    case 6:
        return 1;
    case 7:
        return 2;
    default:
        return 0;
    }
}

static NSArray<NSString*>* EdenSupportedGameExtensions(void) {
    static NSArray<NSString*>* extensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = @[@"nsp", @"xci", @"nca", @"nro", @"nso", @"kip", @"zip", @"7z"];
    });
    return extensions;
}

@interface EdenIOSRuntimeDemoController () <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>

@property(nonatomic, strong) EdenIOSRuntimeViewModel* viewModel;
@property(nonatomic, strong) UILabel* statusLabel;
@property(nonatomic, strong) UILabel* setupStatusLabel;
@property(nonatomic, strong) UILabel* selectedGameLabel;
@property(nonatomic, strong) UITextField* logEndpointField;
@property(nonatomic, strong) UISwitch* runThreadSwitch;
@property(nonatomic, strong) UISwitch* validationSwitch;
@property(nonatomic, strong) UISegmentedControl* rendererControl;
@property(nonatomic, strong) UISegmentedControl* resolutionControl;
@property(nonatomic, strong) UITableView* gamesTableView;
@property(nonatomic, strong) UIButton* startButton;
@property(nonatomic, strong) NSArray<NSURL*>* gameFiles;
@property(nonatomic, copy) NSString* selectedGamePath;
@property(nonatomic, assign) EdenImportMode importMode;
@property(nonatomic, assign) BOOL keysInstalled;
@property(nonatomic, assign) BOOL firmwareInstalled;

@end

@implementation EdenIOSRuntimeDemoController

- (instancetype)initWithRequestJIT:(BOOL)requestJIT
            enableValidationLayers:(BOOL)enableValidationLayers {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _viewModel = [[EdenIOSRuntimeViewModel alloc] initWithRequestJIT:requestJIT
                                                   enableValidationLayers:enableValidationLayers];
#if __has_feature(objc_arc)
        __weak typeof(self) weakSelf = self;
#else
        __unsafe_unretained typeof(self) weakSelf = self;
#endif
        _viewModel.onStateChanged = ^(EdenIOSRuntimeBridgeResult* result, NSString* statusText) {
            (void)result;
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.statusLabel.text = statusText;
            });
        };
        _importMode = EdenImportModeGame;
        _keysInstalled = NO;
        _firmwareInstalled = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Play";
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:1.0];

    UIScrollView* scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:scrollView];
    [scrollView addSubview:contentView];

    UILayoutGuide* guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
    ]];

    UIView* heroCard = [[UIView alloc] init];
    heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    heroCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.16 blue:0.24 alpha:1.0];
    heroCard.layer.cornerRadius = 16.0;

    UILabel* titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Eden Switch Library";
    titleLabel.textColor = [UIColor colorWithRed:0.91 green:0.96 blue:1.0 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"AvenirNext-Bold" size:28.0] ?: [UIFont boldSystemFontOfSize:28.0];

    UILabel* subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.textColor = [UIColor colorWithRed:0.78 green:0.84 blue:0.95 alpha:1.0];
    subtitleLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    subtitleLabel.text = @"Setup awal: import keys, firmware, dan game. Setelah itu atur grafik lalu Start.";

    [heroCard addSubview:titleLabel];
    [heroCard addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:16.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-16.0],
        [titleLabel.topAnchor constraintEqualToAnchor:heroCard.topAnchor constant:16.0],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:heroCard.leadingAnchor constant:16.0],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:heroCard.trailingAnchor constant:-16.0],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:heroCard.bottomAnchor constant:-16.0],
    ]];

    self.setupStatusLabel = [[UILabel alloc] init];
    self.setupStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.setupStatusLabel.numberOfLines = 0;
    self.setupStatusLabel.textColor = [UIColor colorWithRed:0.88 green:0.93 blue:1.0 alpha:1.0];
    self.setupStatusLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.setupStatusLabel.text = @"Setup status: checking...";

    UIButton* importKeysButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importKeysButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importKeysButton setTitle:@"Import Keys" forState:UIControlStateNormal];
    [importKeysButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    importKeysButton.backgroundColor = [UIColor colorWithRed:0.65 green:0.45 blue:0.17 alpha:1.0];
    importKeysButton.layer.cornerRadius = 10.0;
    importKeysButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [importKeysButton addTarget:self action:@selector(onImportKeysTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* importFirmwareButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importFirmwareButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importFirmwareButton setTitle:@"Import Firmware" forState:UIControlStateNormal];
    [importFirmwareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    importFirmwareButton.backgroundColor = [UIColor colorWithRed:0.14 green:0.45 blue:0.63 alpha:1.0];
    importFirmwareButton.layer.cornerRadius = 10.0;
    importFirmwareButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [importFirmwareButton addTarget:self action:@selector(onImportFirmwareTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* importGameButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importGameButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importGameButton setTitle:@"Import Game" forState:UIControlStateNormal];
    [importGameButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    importGameButton.backgroundColor = [UIColor colorWithRed:0.17 green:0.43 blue:0.82 alpha:1.0];
    importGameButton.layer.cornerRadius = 10.0;
    importGameButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [importGameButton addTarget:self action:@selector(onImportGameTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [scanButton setTitle:@"Scan Ulang" forState:UIControlStateNormal];
    [scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanButton.backgroundColor = [UIColor colorWithRed:0.25 green:0.3 blue:0.38 alpha:1.0];
    scanButton.layer.cornerRadius = 10.0;
    scanButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [scanButton addTarget:self action:@selector(onScanTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView* setupRow1 = [[UIStackView alloc] initWithArrangedSubviews:@[importKeysButton, importFirmwareButton]];
    setupRow1.translatesAutoresizingMaskIntoConstraints = NO;
    setupRow1.axis = UILayoutConstraintAxisHorizontal;
    setupRow1.spacing = 10.0;
    setupRow1.distribution = UIStackViewDistributionFillEqually;

    UIStackView* setupRow2 = [[UIStackView alloc] initWithArrangedSubviews:@[importGameButton, scanButton]];
    setupRow2.translatesAutoresizingMaskIntoConstraints = NO;
    setupRow2.axis = UILayoutConstraintAxisHorizontal;
    setupRow2.spacing = 10.0;
    setupRow2.distribution = UIStackViewDistributionFillEqually;

    self.gamesTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.gamesTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.gamesTableView.layer.cornerRadius = 12.0;
    self.gamesTableView.backgroundColor = [UIColor colorWithRed:0.12 green:0.15 blue:0.2 alpha:1.0];
    self.gamesTableView.dataSource = self;
    self.gamesTableView.delegate = self;
    self.gamesTableView.rowHeight = 56.0;

    self.selectedGameLabel = [[UILabel alloc] init];
    self.selectedGameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectedGameLabel.numberOfLines = 2;
    self.selectedGameLabel.textColor = [UIColor colorWithRed:0.83 green:0.89 blue:0.99 alpha:1.0];
    self.selectedGameLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:13.0] ?: [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.selectedGameLabel.text = @"Game terpilih: belum ada";

    UILabel* graphicsTitleLabel = [[UILabel alloc] init];
    graphicsTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    graphicsTitleLabel.textColor = [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0];
    graphicsTitleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    graphicsTitleLabel.text = @"Graphics";

    self.rendererControl = [[UISegmentedControl alloc] initWithItems:@[@"Vulkan", @"Null"]];
    self.rendererControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.rendererControl addTarget:self action:@selector(onRendererChanged) forControlEvents:UIControlEventValueChanged];

    self.resolutionControl = [[UISegmentedControl alloc] initWithItems:@[@"1x", @"2x", @"3x"]];
    self.resolutionControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resolutionControl addTarget:self action:@selector(onResolutionChanged) forControlEvents:UIControlEventValueChanged];

    UILabel* validationLabel = [[UILabel alloc] init];
    validationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    validationLabel.textColor = [UIColor colorWithRed:0.86 green:0.91 blue:0.99 alpha:1.0];
    validationLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    validationLabel.text = @"Validation Layers";

    self.validationSwitch = [[UISwitch alloc] init];
    self.validationSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.validationSwitch addTarget:self action:@selector(onValidationChanged)
                    forControlEvents:UIControlEventValueChanged];

    UIStackView* validationRow = [[UIStackView alloc] initWithArrangedSubviews:@[validationLabel, self.validationSwitch]];
    validationRow.translatesAutoresizingMaskIntoConstraints = NO;
    validationRow.axis = UILayoutConstraintAxisHorizontal;
    validationRow.spacing = 12.0;

    UIView* graphicsCard = [[UIView alloc] init];
    graphicsCard.translatesAutoresizingMaskIntoConstraints = NO;
    graphicsCard.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.2 alpha:1.0];
    graphicsCard.layer.cornerRadius = 12.0;

    UIStackView* graphicsStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        graphicsTitleLabel,
        self.rendererControl,
        self.resolutionControl,
        validationRow,
    ]];
    graphicsStack.translatesAutoresizingMaskIntoConstraints = NO;
    graphicsStack.axis = UILayoutConstraintAxisVertical;
    graphicsStack.spacing = 10.0;

    [graphicsCard addSubview:graphicsStack];
    [NSLayoutConstraint activateConstraints:@[
        [graphicsStack.leadingAnchor constraintEqualToAnchor:graphicsCard.leadingAnchor constant:12.0],
        [graphicsStack.trailingAnchor constraintEqualToAnchor:graphicsCard.trailingAnchor constant:-12.0],
        [graphicsStack.topAnchor constraintEqualToAnchor:graphicsCard.topAnchor constant:12.0],
        [graphicsStack.bottomAnchor constraintEqualToAnchor:graphicsCard.bottomAnchor constant:-12.0],
    ]];

    self.logEndpointField = [[UITextField alloc] init];
    self.logEndpointField.translatesAutoresizingMaskIntoConstraints = NO;
    self.logEndpointField.borderStyle = UITextBorderStyleRoundedRect;
    self.logEndpointField.placeholder = @"Live log endpoint (http://IP-PC:8787/log/)";
    self.logEndpointField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.logEndpointField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.logEndpointField.keyboardType = UIKeyboardTypeURL;

    NSString* saved_endpoint = [EdenIOSRuntimeBridge remoteDebugLogEndpoint];
    if (saved_endpoint.length > 0) {
        self.logEndpointField.text = saved_endpoint;
    }

    UIButton* setLogEndpointButton = [UIButton buttonWithType:UIButtonTypeSystem];
    setLogEndpointButton.translatesAutoresizingMaskIntoConstraints = NO;
    [setLogEndpointButton setTitle:@"Set Live Log" forState:UIControlStateNormal];
    [setLogEndpointButton addTarget:self
                             action:@selector(onSetLogEndpointTapped)
                   forControlEvents:UIControlEventTouchUpInside];

    UIStackView* logEndpointRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.logEndpointField, setLogEndpointButton]];
    logEndpointRow.translatesAutoresizingMaskIntoConstraints = NO;
    logEndpointRow.axis = UILayoutConstraintAxisHorizontal;
    logEndpointRow.spacing = 8.0;
    logEndpointRow.distribution = UIStackViewDistributionFill;

    [setLogEndpointButton setContentHuggingPriority:UILayoutPriorityRequired
                                            forAxis:UILayoutConstraintAxisHorizontal];

    UILabel* runThreadLabel = [[UILabel alloc] init];
    runThreadLabel.translatesAutoresizingMaskIntoConstraints = NO;
    runThreadLabel.textColor = [UIColor colorWithRed:0.86 green:0.91 blue:0.99 alpha:1.0];
    runThreadLabel.font = [UIFont fontWithName:@"AvenirNext-Medium" size:14.0] ?: [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    runThreadLabel.text = @"Jalankan thread eksekusi";

    self.runThreadSwitch = [[UISwitch alloc] init];
    self.runThreadSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.runThreadSwitch.on = [self.viewModel isStartExecutionThreadEnabled];
    [self.runThreadSwitch addTarget:self
                              action:@selector(onRunThreadSwitchChanged)
                    forControlEvents:UIControlEventValueChanged];

    UIStackView* runThreadRow = [[UIStackView alloc] initWithArrangedSubviews:@[runThreadLabel, self.runThreadSwitch]];
    runThreadRow.translatesAutoresizingMaskIntoConstraints = NO;
    runThreadRow.axis = UILayoutConstraintAxisHorizontal;
    runThreadRow.spacing = 12.0;
    runThreadRow.distribution = UIStackViewDistributionFill;

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.56 blue:0.38 alpha:1.0];
    self.startButton.layer.cornerRadius = 10.0;
    [self.startButton addTarget:self action:@selector(onStartTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    stopButton.translatesAutoresizingMaskIntoConstraints = NO;
    [stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    stopButton.backgroundColor = [UIColor colorWithRed:0.64 green:0.2 blue:0.2 alpha:1.0];
    stopButton.layer.cornerRadius = 10.0;
    [stopButton addTarget:self action:@selector(onStopTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshButton setTitle:@"Refresh" forState:UIControlStateNormal];
    [refreshButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refreshButton.backgroundColor = [UIColor colorWithRed:0.27 green:0.33 blue:0.42 alpha:1.0];
    refreshButton.layer.cornerRadius = 10.0;
    [refreshButton addTarget:self action:@selector(onRefreshTapped) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.statusLabel.textColor = [UIColor colorWithRed:0.72 green:0.8 blue:0.92 alpha:1.0];
    self.statusLabel.text = self.viewModel.statusText;

    UIStackView* buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.startButton, stopButton, refreshButton]];
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 10.0;
    buttonRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        heroCard,
        self.setupStatusLabel,
        setupRow1,
        setupRow2,
        self.gamesTableView,
        self.selectedGameLabel,
        graphicsCard,
        logEndpointRow,
        runThreadRow,
        buttonRow,
        self.statusLabel,
    ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;

    [contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:16.0],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-20.0],
        [self.gamesTableView.heightAnchor constraintEqualToConstant:280.0],
        [importKeysButton.heightAnchor constraintEqualToConstant:44.0],
        [importFirmwareButton.heightAnchor constraintEqualToConstant:44.0],
        [importGameButton.heightAnchor constraintEqualToConstant:44.0],
        [scanButton.heightAnchor constraintEqualToConstant:44.0],
        [self.startButton.heightAnchor constraintEqualToConstant:44.0],
        [stopButton.heightAnchor constraintEqualToConstant:44.0],
        [refreshButton.heightAnchor constraintEqualToConstant:44.0],
    ]];

    [self applySavedGraphicsSettings];
    [self refreshSetupState];
    [self reloadGameLibraryAndRestoreSelection];
}

- (void)onStartTapped {
    NSString* path = [self.selectedGamePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!self.keysInstalled) {
        self.statusLabel.text = @"Import keys dulu sebelum start game.";
        return;
    }
    if (!self.firmwareInstalled) {
        self.statusLabel.text = @"Import firmware dulu sebelum start game.";
        return;
    }
    if (path.length == 0) {
        self.statusLabel.text = @"Pilih game terlebih dahulu dari library.";
        return;
    }
    [self.viewModel startWithGamePath:path];
}

- (void)onRunThreadSwitchChanged {
    [self.viewModel setStartExecutionThreadEnabled:self.runThreadSwitch.isOn];
}

- (void)onSetLogEndpointTapped {
    NSString* endpoint = [self.logEndpointField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:endpoint.length > 0 ? endpoint : nil];
    [self.viewModel refreshState];
}

- (void)onStopTapped {
    [self.viewModel stop];
}

- (void)onTickTapped {
    [self.viewModel tick];
}

- (void)onRefreshTapped {
    [self refreshSetupState];
    [self.viewModel refreshState];
}

- (void)onImportKeysTapped {
    [self presentImporterForMode:EdenImportModeKeys allowsMultiple:YES];
}

- (void)onImportFirmwareTapped {
    [self presentImporterForMode:EdenImportModeFirmware allowsMultiple:NO];
}

- (void)onImportGameTapped {
    [self presentImporterForMode:EdenImportModeGame allowsMultiple:NO];
}

- (void)onScanTapped {
    [self reloadGameLibraryAndRestoreSelection];
    [self refreshSetupState];
}

- (void)onRendererChanged {
    NSInteger backend = EdenRendererIndexToValue(self.rendererControl.selectedSegmentIndex);
    [self.viewModel setRendererBackendValue:backend];
    [[NSUserDefaults standardUserDefaults] setInteger:backend forKey:EdenGraphicsRendererDefaultsKey];
}

- (void)onResolutionChanged {
    NSInteger resolution = EdenResolutionIndexToValue(self.resolutionControl.selectedSegmentIndex);
    [self.viewModel setResolutionSetupValue:resolution];
    [[NSUserDefaults standardUserDefaults] setInteger:resolution forKey:EdenGraphicsResolutionDefaultsKey];
}

- (void)onValidationChanged {
    [self.viewModel setValidationLayersEnabled:self.validationSwitch.isOn];
    [[NSUserDefaults standardUserDefaults] setBool:self.validationSwitch.isOn
                                            forKey:EdenGraphicsValidationDefaultsKey];
}

- (void)applySavedGraphicsSettings {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSInteger rendererValue = [defaults integerForKey:EdenGraphicsRendererDefaultsKey];
    if (rendererValue == 0) {
        rendererValue = 1;
    }
    NSInteger resolutionValue = [defaults integerForKey:EdenGraphicsResolutionDefaultsKey];
    if (resolutionValue == 0) {
        resolutionValue = 3;
    }
    BOOL validationEnabled = [defaults boolForKey:EdenGraphicsValidationDefaultsKey];

    self.rendererControl.selectedSegmentIndex = EdenRendererValueToIndex(rendererValue);
    self.resolutionControl.selectedSegmentIndex = EdenResolutionValueToIndex(resolutionValue);
    self.validationSwitch.on = validationEnabled;

    [self.viewModel setRendererBackendValue:rendererValue];
    [self.viewModel setResolutionSetupValue:resolutionValue];
    [self.viewModel setValidationLayersEnabled:validationEnabled];
}

- (void)refreshSetupState {
    EdenIOSSetupBridgeResult* status = [EdenIOSSetupBridge status];
    self.keysInstalled = status.keysInstalled;
    self.firmwareInstalled = status.firmwareInstalled;

    NSString* keysText = self.keysInstalled ? @"ready" : @"missing";
    NSString* firmwareText = self.firmwareInstalled ? @"ready" : @"missing";
    self.setupStatusLabel.text = [NSString stringWithFormat:@"Setup status: keys=%@ | firmware=%@", keysText, firmwareText];

    self.startButton.enabled = self.keysInstalled && self.firmwareInstalled && self.selectedGamePath.length > 0;
    self.startButton.alpha = self.startButton.enabled ? 1.0 : 0.5;
}

- (void)presentImporterForMode:(EdenImportMode)mode allowsMultiple:(BOOL)allowsMultiple {
    self.importMode = mode;

    NSArray<NSString*>* documentTypes =
        mode == EdenImportModeFirmware
            ? @[@"public.folder", @"public.zip-archive", @"public.data", @"public.item"]
            : @[@"public.item"];
    UIDocumentPickerMode pickerMode =
        mode == EdenImportModeFirmware ? UIDocumentPickerModeOpen : UIDocumentPickerModeImport;
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes
                                                                inMode:pickerMode];

    picker.delegate = self;
    picker.allowsMultipleSelection = allowsMultiple;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (NSURL*)gamesDirectoryURL {
    NSURL* documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                   inDomains:NSUserDomainMask] firstObject];
    NSURL* gamesURL = [documentsURL URLByAppendingPathComponent:EdenGamesFolderName isDirectory:YES];
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtURL:gamesURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&error];
    return gamesURL;
}

- (BOOL)isSupportedGameURL:(NSURL*)url {
    NSString* ext = [[url pathExtension] lowercaseString];
    if (ext.length == 0) {
        return NO;
    }
    return [EdenSupportedGameExtensions() containsObject:ext];
}

- (void)reloadGameLibraryAndRestoreSelection {
    NSURL* gamesURL = [self gamesDirectoryURL];
    NSArray<NSURL*>* entries =
        [[NSFileManager defaultManager] contentsOfDirectoryAtURL:gamesURL
                                      includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                         options:NSDirectoryEnumerationSkipsHiddenFiles
                                                           error:nil];

    NSMutableArray<NSURL*>* files = [NSMutableArray array];
    for (NSURL* entry in entries) {
        NSNumber* isDirectory = nil;
        [entry getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) {
            continue;
        }
        if ([self isSupportedGameURL:entry]) {
            [files addObject:entry];
        }
    }

    [files sortUsingComparator:^NSComparisonResult(NSURL* left, NSURL* right) {
        return [[[left lastPathComponent] lowercaseString] compare:[[right lastPathComponent] lowercaseString]];
    }];

    self.gameFiles = [files copy];
    [self.gamesTableView reloadData];

    NSString* savedPath = [[NSUserDefaults standardUserDefaults] stringForKey:EdenLastGamePathDefaultsKey] ?: @"";
    if (savedPath.length > 0) {
        for (NSUInteger idx = 0; idx < self.gameFiles.count; ++idx) {
            NSURL* fileURL = self.gameFiles[idx];
            if ([[fileURL path] isEqualToString:savedPath]) {
                [self setSelectedGamePath:[fileURL path] tableIndex:idx];
                return;
            }
        }
    }

    if (self.gameFiles.count > 0) {
        [self setSelectedGamePath:[self.gameFiles.firstObject path] tableIndex:0];
    } else {
        self.selectedGamePath = @"";
        self.selectedGameLabel.text = @"Game terpilih: belum ada (gunakan Import Game)";
        self.statusLabel.text = @"Library kosong. Import file .nsp/.xci terlebih dahulu.";
        [self refreshSetupState];
    }
}

- (void)setSelectedGamePath:(NSString*)path tableIndex:(NSUInteger)index {
    self.selectedGamePath = path;
    [[NSUserDefaults standardUserDefaults] setObject:path forKey:EdenLastGamePathDefaultsKey];
    NSString* name = [path lastPathComponent];
    self.selectedGameLabel.text = [NSString stringWithFormat:@"Game terpilih: %@", name];

    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:(NSInteger)index inSection:0];
    if ([self.gamesTableView numberOfRowsInSection:0] > (NSInteger)index) {
        [self.gamesTableView selectRowAtIndexPath:indexPath
                                         animated:NO
                                   scrollPosition:UITableViewScrollPositionNone];
    }
    [self refreshSetupState];
}

- (NSURL*)keysImportStagingDirectoryURL {
    NSURL* documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                   inDomains:NSUserDomainMask] firstObject];
    NSURL* staging = [[documentsURL URLByAppendingPathComponent:@"Imports" isDirectory:YES]
        URLByAppendingPathComponent:@"Keys" isDirectory:YES];
    [[NSFileManager defaultManager] removeItemAtURL:staging error:nil];
    [[NSFileManager defaultManager] createDirectoryAtURL:staging
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    return staging;
}

- (BOOL)copyIncomingURL:(NSURL*)sourceURL toDestination:(NSURL*)destinationURL error:(NSError**)error {
    BOOL hasScope = [sourceURL startAccessingSecurityScopedResource];
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    BOOL ok = [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destinationURL error:error];
    if (hasScope) {
        [sourceURL stopAccessingSecurityScopedResource];
    }
    return ok;
}

- (void)handleGameImportWithURL:(NSURL*)pickedURL {
    if (![self isSupportedGameURL:pickedURL]) {
        self.statusLabel.text = @"Format file tidak didukung. Gunakan .nsp/.xci/.nca/.nro.";
        return;
    }

    NSURL* destinationURL = [[self gamesDirectoryURL] URLByAppendingPathComponent:[pickedURL lastPathComponent]];
    NSError* copyError = nil;
    if (![self copyIncomingURL:pickedURL toDestination:destinationURL error:&copyError]) {
        NSString* detail = copyError.localizedDescription ?: @"unknown";
        self.statusLabel.text = [NSString stringWithFormat:@"Import game gagal: %@", detail];
        return;
    }

    NSString* pickedPath = [destinationURL path];
    self.statusLabel.text = [NSString stringWithFormat:@"Game di-import: %@", [destinationURL lastPathComponent]];

    [self reloadGameLibraryAndRestoreSelection];
    for (NSUInteger idx = 0; idx < self.gameFiles.count; ++idx) {
        if ([[self.gameFiles[idx] path] isEqualToString:pickedPath]) {
            [self setSelectedGamePath:pickedPath tableIndex:idx];
            break;
        }
    }
}

- (void)handleKeysImportWithURLs:(NSArray<NSURL*>*)urls {
    NSURL* stagingURL = [self keysImportStagingDirectoryURL];
    NSString* prodPath = @"";

    for (NSURL* sourceURL in urls) {
        NSNumber* isDirectory = nil;
        [sourceURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) {
            continue;
        }

        NSURL* destinationURL = [stagingURL URLByAppendingPathComponent:[sourceURL lastPathComponent]];
        NSError* copyError = nil;
        if (![self copyIncomingURL:sourceURL toDestination:destinationURL error:&copyError]) {
            NSString* detail = copyError.localizedDescription ?: @"unknown";
            self.statusLabel.text = [NSString stringWithFormat:@"Import keys gagal: %@", detail];
            return;
        }

        NSString* lowerName = [[destinationURL lastPathComponent] lowercaseString];
        if ([lowerName isEqualToString:@"prod.keys"]) {
            prodPath = [destinationURL path];
        }
    }

    if (prodPath.length == 0) {
        self.statusLabel.text = @"prod.keys belum ditemukan. Pilih file prod.keys saat import keys.";
        return;
    }

    EdenIOSSetupBridgeResult* result = [EdenIOSSetupBridge installKeysFromProdKeysPath:prodPath];
    self.statusLabel.text = [NSString stringWithFormat:@"Import keys: %@", result.report];
    [self refreshSetupState];
}

- (void)handleFirmwareImportWithURL:(NSURL*)sourceURL {
    BOOL hasScope = [sourceURL startAccessingSecurityScopedResource];
    NSString* sourcePath = [sourceURL path];
    if (hasScope) {
        [sourceURL stopAccessingSecurityScopedResource];
    }

    if (sourcePath.length == 0) {
        self.statusLabel.text = @"Import firmware gagal: path kosong.";
        return;
    }

    EdenIOSSetupBridgeResult* result = [EdenIOSSetupBridge installFirmwareFromPath:sourcePath
                                                                          recursive:YES];
    if (!result.success && [[[sourceURL pathExtension] lowercaseString] isEqualToString:@"nca"]) {
        NSString* parentPath = [[sourceURL URLByDeletingLastPathComponent] path];
        result = [EdenIOSSetupBridge installFirmwareFromPath:parentPath recursive:YES];
    }

    self.statusLabel.text = [NSString stringWithFormat:@"Import firmware: %@", result.report];
    if (!result.success) {
        self.statusLabel.text = [self.statusLabel.text stringByAppendingString:@" (gunakan folder firmware berisi file .nca)"];
    }
    [self refreshSetupState];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    (void)controller;
    if (urls.count == 0) {
        return;
    }

    switch (self.importMode) {
    case EdenImportModeKeys:
        [self handleKeysImportWithURLs:urls];
        break;
    case EdenImportModeFirmware:
        [self handleFirmwareImportWithURL:urls.firstObject];
        break;
    case EdenImportModeGame:
    default:
        [self handleGameImportWithURL:urls.firstObject];
        break;
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    (void)controller;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return (NSInteger)self.gameFiles.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString* const CellID = @"GameCell";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellID];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.15 blue:0.2 alpha:1.0];
        cell.textLabel.textColor = [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.62 green:0.71 blue:0.86 alpha:1.0];
        cell.textLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        cell.detailTextLabel.font = [UIFont fontWithName:@"AvenirNext-Regular" size:12.0] ?: [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
    }

    NSURL* fileURL = self.gameFiles[(NSUInteger)indexPath.row];
    cell.textLabel.text = [fileURL lastPathComponent];
    cell.detailTextLabel.text = [NSString stringWithFormat:@".%@", [[fileURL pathExtension] lowercaseString]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    (void)tableView;
    NSURL* fileURL = self.gameFiles[(NSUInteger)indexPath.row];
    [self setSelectedGamePath:[fileURL path] tableIndex:(NSUInteger)indexPath.row];
}

@end
