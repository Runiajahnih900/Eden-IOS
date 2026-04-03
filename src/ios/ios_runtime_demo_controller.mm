// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#import "ios_runtime_demo_controller.h"

#import "ios_runtime_objc_bridge.h"
#import "ios_runtime_view_model.h"

static NSString* const EdenLastGamePathDefaultsKey = @"EdenLastGamePath";

static NSString* const EdenGamesFolderName = @"Games";

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
@property(nonatomic, strong) UILabel* selectedGameLabel;
@property(nonatomic, strong) UITextField* logEndpointField;
@property(nonatomic, strong) UISwitch* runThreadSwitch;
@property(nonatomic, strong) UITableView* gamesTableView;
@property(nonatomic, strong) NSArray<NSURL*>* gameFiles;
@property(nonatomic, copy) NSString* selectedGamePath;

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
    subtitleLabel.text = @"Import file .nsp/.xci, pilih game dari library, lalu tekan Start untuk menjalankan runtime.";

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

    UIButton* importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importButton.translatesAutoresizingMaskIntoConstraints = NO;
    [importButton setTitle:@"Import Game" forState:UIControlStateNormal];
    [importButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    importButton.backgroundColor = [UIColor colorWithRed:0.17 green:0.43 blue:0.82 alpha:1.0];
    importButton.layer.cornerRadius = 10.0;
    importButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [importButton addTarget:self action:@selector(onImportTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton* scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    scanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [scanButton setTitle:@"Scan Ulang" forState:UIControlStateNormal];
    [scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanButton.backgroundColor = [UIColor colorWithRed:0.25 green:0.3 blue:0.38 alpha:1.0];
    scanButton.layer.cornerRadius = 10.0;
    scanButton.titleLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:15.0] ?: [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    [scanButton addTarget:self action:@selector(onScanTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView* importRow = [[UIStackView alloc] initWithArrangedSubviews:@[importButton, scanButton]];
    importRow.translatesAutoresizingMaskIntoConstraints = NO;
    importRow.axis = UILayoutConstraintAxisHorizontal;
    importRow.spacing = 10.0;
    importRow.distribution = UIStackViewDistributionFillEqually;

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

    UIButton* startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [startButton setTitle:@"Start" forState:UIControlStateNormal];
    [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.56 blue:0.38 alpha:1.0];
    startButton.layer.cornerRadius = 10.0;
    [startButton addTarget:self action:@selector(onStartTapped) forControlEvents:UIControlEventTouchUpInside];

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

    UIStackView* buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[startButton, stopButton, refreshButton]];
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.spacing = 10.0;
    buttonRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        heroCard,
        importRow,
        self.gamesTableView,
        self.selectedGameLabel,
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
        [importButton.heightAnchor constraintEqualToConstant:44.0],
        [scanButton.heightAnchor constraintEqualToConstant:44.0],
        [startButton.heightAnchor constraintEqualToConstant:44.0],
        [stopButton.heightAnchor constraintEqualToConstant:44.0],
        [refreshButton.heightAnchor constraintEqualToConstant:44.0],
    ]];

    [self reloadGameLibraryAndRestoreSelection];
}

- (void)onStartTapped {
    NSString* path = [self.selectedGamePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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
    [self.viewModel refreshState];
}

- (void)onImportTapped {
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)onScanTapped {
    [self reloadGameLibraryAndRestoreSelection];
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
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    (void)controller;
    if (urls.count == 0) {
        return;
    }

    NSURL* pickedURL = urls.firstObject;
    if (![self isSupportedGameURL:pickedURL]) {
        self.statusLabel.text = @"Format file tidak didukung. Gunakan .nsp/.xci/.nca/.nro.";
        return;
    }

    NSURL* destinationURL = [[self gamesDirectoryURL] URLByAppendingPathComponent:[pickedURL lastPathComponent]];
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    NSError* copyError = nil;
    if (![[NSFileManager defaultManager] copyItemAtURL:pickedURL toURL:destinationURL error:&copyError]) {
        NSString* detail = copyError.localizedDescription ?: @"unknown";
        self.statusLabel.text = [NSString stringWithFormat:@"Import gagal: %@", detail];
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
