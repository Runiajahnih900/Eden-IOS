# iOS Porting Change Log

Date: 2026-04-01
Workspace: eden
Target: iPadOS 16 (jailbreak + TrollStore), milestone boot-to-menu

Last Update: 2026-04-02

## Scope Implemented

This log records all source changes made in the current implementation session for the iOS bootstrap track.

## File-by-File Changes

### 1) Root build profile for iOS bootstrap
File: `CMakeLists.txt`

- Added iOS-aware gating for components that are currently desktop/non-priority on the bootstrap path:
  - Disable Qt frontend and Qt translation in iOS profile.
  - Disable update checker, web service, room, and command-line target in iOS profile.
- Added option:
  - `ENABLE_IOS_BOOTSTRAP`
- Added forced iOS profile behavior when `PLATFORM_IOS` is active:
  - `ENABLE_IOS_BOOTSTRAP=ON`
  - compile definition `YUZU_PLATFORM_IOS=1`
- Tightened dependent options to avoid accidental non-iOS-friendly targets in iOS mode:
  - `YUZU_ROOM` disabled for iOS.
  - `YUZU_CMD` disabled for iOS.

### 2) Platform detection
File: `externals/cmake-modules/DetectPlatform.cmake`

- Added explicit iOS platform flag:
  - `PLATFORM_IOS` when `CMAKE_SYSTEM_NAME` is `iOS`.

### 3) Source graph integration
File: `src/CMakeLists.txt`

- Added conditional iOS subtree inclusion:
  - `add_subdirectory(ios)` when `PLATFORM_IOS` and `ENABLE_IOS_BOOTSTRAP` are ON.

### 4) New iOS bootstrap module
File: `src/ios/CMakeLists.txt`

- Added static target:
  - `yuzu-ios-bootstrap` (output name `eden-ios-bootstrap`)
- Linked core bootstrap dependencies:
  - `common`, `core`, `frontend_common`
- Added Apple framework linkage:
  - `Foundation`
- Added iOS-specific MoltenVK linkage logic:
  - Looks up `MoltenVK` from iOS toolchain.
  - Defines `YUZU_IOS_MOLTENVK=1` when found.
  - Emits warning when not found.

### 5) New iOS bootstrap API (header)
File: `src/ios/ios_bootstrap.h`

- Added data structures for bootstrap state:
  - `BootstrapConfig`
  - `BootstrapStatus` with fields:
    - `ready`
    - `on_ios`
    - `moltenvk_available`
    - `game_path_valid`
    - `game_path`
    - `summary`
- Added APIs:
  - `PrepareBootstrap(const BootstrapConfig&)`
  - `PrepareBootstrap(const BootstrapConfig&, const std::string& game_path)`
  - `BuildBootstrapReport(const BootstrapStatus&)`

### 6) New iOS bootstrap API (implementation)
File: `src/ios/ios_bootstrap.cpp`

- Added runtime platform readiness detection for iOS.
- Added supported game extension checks for bootstrap pre-validation:
  - `.nsp`, `.xci`, `.nca`, `.nro`, `.nso`, `.kip`, `.zip`, `.7z`
- Added filesystem-based game path validation:
  - accepts existing directory
  - accepts existing regular file with supported extension
- Added MoltenVK status propagation via `YUZU_IOS_MOLTENVK`.
- Added summary composition for diagnostics:
  - includes game path validity markers
  - includes no-moltenvk marker on iOS when unavailable
- Added `BuildBootstrapReport` formatter for wrapper/frontend logging.

### 7) External dependency resolution behavior
File: `externals/CMakeLists.txt`

- Updated MoltenVK logic for Apple targets:
  - On iOS (`PLATFORM_IOS`): no macOS bundled artifact fallback is used.
  - iOS now expects MoltenVK from iOS toolchain lookup.
  - emits warning if missing.
- Kept existing bundled path behavior for non-iOS Apple targets (macOS path remains unchanged).

### 8) C ABI bridge for Swift/ObjC wrappers
File: `src/ios/CMakeLists.txt`

- Added C bridge sources into the iOS bootstrap target:
  - `ios_bootstrap_c_api.cpp`
  - `ios_bootstrap_c_api.h`

File: `src/ios/ios_bootstrap_c_api.h`

- Added C-compatible API surface for wrapper integration:
  - `EdenIOSBootstrapAbiVersion()`
  - `EdenIOSPrepareBootstrap(...)`
- Added plain C structs:
  - `EdenIOSBootstrapOptions`
  - `EdenIOSBootstrapResult`

File: `src/ios/ios_bootstrap_c_api.cpp`

- Added translation layer from C API inputs to C++ bootstrap config.
- Added marshaling of C++ status back into C structs.
- Added report-buffer writing logic with null-termination guarantees.
- Added ABI version constant return (`1`) for wrapper-side compatibility checks.

### 9) Objective-C++ bridge for iOS app wrappers
File: `src/ios/CMakeLists.txt`

- Added iOS-only bridge sources to bootstrap target when `PLATFORM_IOS` is ON:
  - `ios_bootstrap_objc_bridge.h`
  - `ios_bootstrap_objc_bridge.mm`

File: `src/ios/ios_bootstrap_objc_bridge.h`

- Added Objective-C interfaces intended for Swift/ObjC app-layer integration:
  - `EdenIOSBootstrapBridge`
  - `EdenIOSBootstrapBridgeResult`
- Exposed wrapper-friendly methods:
  - `+abiVersion`
  - `+prepareWithRequestJIT:enableValidationLayers:gamePath:`

File: `src/ios/ios_bootstrap_objc_bridge.mm`

- Implemented Objective-C++ call-through into C ABI bootstrap functions.
- Added conversion/marshaling from `NSString` to UTF-8 C input.
- Added conversion of C bootstrap output into Objective-C result object.
- Added stable report buffer handoff (`char report_buffer[4096]`) for wrapper-side diagnostics.

### 10) Runtime session placeholder (start/stop/state)
File: `src/ios/CMakeLists.txt`

- Added runtime session and bridges into bootstrap target:
  - `ios_runtime_session.cpp`, `ios_runtime_session.h`
  - `ios_runtime_c_api.cpp`, `ios_runtime_c_api.h`
  - `ios_runtime_objc_bridge.h`, `ios_runtime_objc_bridge.mm` (iOS-only sources)

File: `src/ios/ios_runtime_session.h`

- Added C++ runtime placeholder interfaces:
  - `StartRuntimeSession(...)`
  - `StopRuntimeSession()`
  - `QueryRuntimeSessionStatus()`
- Added request/status data models:
  - `RuntimeStartRequest`
  - `RuntimeSessionStatus`

File: `src/ios/ios_runtime_session.cpp`

- Added placeholder runtime state machine with thread-safe state access.
- Added pre-start gate that reuses bootstrap preflight (`PrepareBootstrap`) before allowing runtime start.
- Added monotonic runtime `session_id` assignment for each accepted start.
- Added runtime `tick_count` counter and `TickRuntimeSession()` polling entrypoint.
- Added status/report strings for:
  - start accepted placeholder
  - start rejected
  - stop
  - stop noop
  - tick
  - tick noop

File: `src/ios/ios_runtime_c_api.h`

- Added C ABI for runtime control:
  - `EdenIOSRuntimeStart(...)`
  - `EdenIOSRuntimeStop()`
  - `EdenIOSRuntimeTick(...)`
  - `EdenIOSRuntimeGetState(...)`
- Added C ABI event callback interface:
  - `EdenIOSRuntimeSetEventCallback(...)`
  - `EdenIOSRuntimeEventType` (`START`, `STOP`, `TICK`)
- Extended runtime state payload:
  - `session_id`
  - `tick_count`

File: `src/ios/ios_runtime_c_api.cpp`

- Added C-to-C++ translation layer for runtime start options and status output.
- Added report-buffer output with null-termination guarantees.
- Added callback registration state and dispatch hooks for runtime events.
- Added event dispatch on start, stop, and tick operations.

File: `src/ios/ios_runtime_objc_bridge.h`

- Added Objective-C runtime bridge interfaces:
  - `EdenIOSRuntimeBridge`
  - `EdenIOSRuntimeBridgeResult`

File: `src/ios/ios_runtime_objc_bridge.mm`

- Added Objective-C++ app-facing runtime controls:
  - `+startWithRequestJIT:enableValidationLayers:gamePath:`
  - `+stop`
  - `+tick`
  - `+state`
- Added marshaling between NSString and C ABI structs.
- Extended ObjC result object with polling metadata:
  - `sessionID`
  - `tickCount`
- Added NotificationCenter bridge for reactive runtime events:
  - `EdenIOSRuntimeEventNotification`
  - payload keys for type, running, lastStartSucceeded, sessionID, tickCount, and report
  - bridge method `+setEventNotificationsEnabled:`

### 11) Concrete iOS runtime controller logic (view-model)
File: `src/ios/CMakeLists.txt`

- Added iOS-only runtime view-model sources:
  - `ios_runtime_view_model.h`
  - `ios_runtime_view_model.mm`

File: `src/ios/ios_runtime_view_model.h`

- Added app-facing runtime view-model interface:
  - stores latest runtime result
  - exposes user-readable `statusText`
  - exposes command methods: `startWithGamePath`, `stop`, `tick`, `refreshState`
  - optional callback `onStateChanged` for UI binding

File: `src/ios/ios_runtime_view_model.mm`

- Implemented concrete controller-level logic for iOS app shell:
  - subscribes to runtime NotificationCenter events
  - keeps local state in sync with runtime bridge
  - formats runtime state into display-friendly status text
  - emits callback on each state change
- Added initialization flow that enables event notifications and performs initial state sync.
- Added cleanup flow by unregistering NotificationCenter observer on dealloc.

### 12) UIKit demo app-shell controller
File: `src/ios/CMakeLists.txt`

- Added iOS-only UIKit demo controller sources:
  - `ios_runtime_demo_controller.h`
  - `ios_runtime_demo_controller.mm`

File: `src/ios/ios_runtime_demo_controller.h`

- Added UIKit controller declaration for runtime demo screen:
  - `EdenIOSRuntimeDemoController`
  - designated initializer with `requestJIT` and `enableValidationLayers`

File: `src/ios/ios_runtime_demo_controller.mm`

- Implemented minimal interactive runtime demo screen:
  - game path input field
  - action buttons: Start, Stop, Tick, Refresh
  - status label with monospaced diagnostics output
- Bound all actions to `EdenIOSRuntimeViewModel` command methods.
- Subscribed to view-model `onStateChanged` callback and updated UI state on main thread.

### 13) CI hardening for iOS bootstrap
File: `CMakeLists.txt`

- Strengthened iOS profile for CI by forcing non-essential deps off:
  - `ENABLE_CUBEB=OFF`
  - `ENABLE_LIBUSB=OFF`

File: `externals/CMakeLists.txt`

- Skipped SDL2 external setup and discovery for iOS bootstrap path:
  - SDL2 handling now runs only when `NOT ANDROID AND NOT PLATFORM_IOS`

File: `src/audio_core/CMakeLists.txt`

- Added iOS branch that skips SDL2 sink wiring for bootstrap builds:
  - avoids linking `SDL2::SDL2` in iOS bootstrap mode
  - keeps Android and non-iOS behavior unchanged

### 14) GitHub Actions workflow for iOS bootstrap
File: `.github/workflows/ios-bootstrap.yml`

- Added new GitHub Actions pipeline to build iOS bootstrap target on `macos-14`.
- Triggered on `workflow_dispatch`, relevant `pull_request` paths, and relevant `push` paths.
- Configures CMake for iOS simulator (`iphonesimulator`, `arm64`) and builds:
  - target `yuzu-ios-bootstrap`
- Includes tool version printout for easier CI troubleshooting.

### 15) Runtime loader preflight integration
File: `src/ios/ios_runtime_session.cpp`

- Upgraded runtime start gate from placeholder-only checks to core loader preflight:
  - open game via virtual filesystem (`RealVfsFilesystem` + `Core::GetGameFileFromPath`)
  - detect file type with `Loader::IdentifyFile`
  - verify container bootability with `Loader::IsBootableGameContainer` for NSP/XCI
- Runtime start now rejects with explicit loader preflight reason when any loader gate fails.
- Runtime report now includes loader diagnostics fields:
  - `loader_file_opened`
  - `loader_type`
  - `loader_type_known`
  - `loader_bootable`

### 16) Headless Core::System load path for iOS runtime start
File: `src/ios/CMakeLists.txt`

- Added iOS headless emu window sources to bootstrap target:
  - `ios_emu_window_headless.h`
  - `ios_emu_window_headless.cpp`

File: `src/ios/ios_emu_window_headless.h`

- Added `EmuWindowIOSHeadless` implementation contract for iOS runtime loading.

File: `src/ios/ios_emu_window_headless.cpp`

- Implemented minimal headless emu window with:
  - `WindowSystemType::Headless`
  - dummy graphics context
  - always-shown frontend signal

File: `src/ios/ios_runtime_session.cpp`

- Upgraded runtime start flow to attempt real core load after preflight:
  - create `Core::System`
  - initialize system and apply `RendererBackend::Null`
  - set content provider and real filesystem
  - create factories via filesystem controller
  - call `Core::System::Load` using headless emu window
  - start GPU and notify CPU manager GPU-ready on success
- Added core teardown logic on stop and on load failure.
- Added runtime report fields for core load result:
  - `core_load_result=success`
  - numeric failure code when load fails

### 17) Background run thread integration
File: `src/ios/ios_runtime_session.h`

- Extended runtime start request with execution control:
  - `start_execution_thread` (default ON)
- Extended runtime status with run loop indicator:
  - `run_thread_active`

File: `src/ios/ios_runtime_session.cpp`

- Added managed background run thread for `Core::System::Run`.
- Runtime start now supports two modes:
  - load-only (thread disabled)
  - load + run thread (thread enabled)
- Added proper run thread join during teardown and stop to avoid dangling worker threads.
- Added report tags:
  - `core_run_thread=started`
  - `core_run_thread=disabled`

File: `src/ios/ios_runtime_c_api.h`

- Added C ABI field in start options:
  - `start_execution_thread`
- Added C ABI runtime state field:
  - `run_thread_active`

File: `src/ios/ios_runtime_c_api.cpp`

- Added mapping for `start_execution_thread` from C API into runtime session.
- Added mapping for `run_thread_active` in state and event dispatch payload.

File: `src/ios/ios_runtime_objc_bridge.h`

- Extended ObjC runtime result with:
  - `runThreadActive`
- Extended start API with:
  - `startExecutionThread`
- Added runtime event payload key:
  - `EdenIOSRuntimeEventRunThreadActiveKey`

File: `src/ios/ios_runtime_objc_bridge.mm`

- Added marshaling for `runThreadActive` in start/tick/state responses.
- Added `runThreadActive` in notification payload.

File: `src/ios/ios_runtime_view_model.mm`

- View-model now includes run-thread state in status text.
- View-model start command now requests background execution thread by default.
- Added explicit view-model controls:
  - `setStartExecutionThreadEnabled:`
  - `isStartExecutionThreadEnabled`

File: `src/ios/ios_runtime_demo_controller.mm`

- Added UI switch to toggle runtime start mode:
  - load+run-thread mode
  - load-only mode
- Wired switch state into view-model `startExecutionThread` option.

### 18) Run thread lifecycle hardening
File: `src/ios/ios_runtime_session.cpp`

- Added atomic run-thread liveness tracking (`g_run_thread_alive`).
- Runtime tick now detects completed run thread and updates session state/report:
  - transitions to non-running state
  - report marker `runtime-thread-finished`
- Teardown now explicitly resets run-thread liveness state in all paths.

File: `src/ios/ios_runtime_objc_bridge.mm`

- Cleaned up formatting/readability for extended runtime result marshaling.

File: `src/ios/ios_runtime_view_model.mm`

- Cleaned up event handling formatting for `runThreadActive` propagation.

### 19) CI configure blockers fix (iOS simulator)
File: `externals/cmake-modules/DetectArchitecture.cmake`

- Fixed multi-arch iteration syntax for Apple architectures:
  - changed `foreach(ARCH IN ${CMAKE_OSX_ARCHITECTURES})`
  - to `foreach(ARCH IN LISTS CMAKE_OSX_ARCHITECTURES)`
- This resolves CMake parse failure on iOS configure (`Unknown arguments: arm64`).

File: `CMakeLists.txt`

- Made OpenSSL discovery optional for iOS bootstrap profile only:
  - skip bundled OpenSSL setup and `find_package(OpenSSL 3 REQUIRED)` when `PLATFORM_IOS AND ENABLE_IOS_BOOTSTRAP`.
  - add status message for traceability during configure.

File: `src/core/CMakeLists.txt`

- Removed unconditional OpenSSL dependency for core in iOS bootstrap profile:
  - iOS bootstrap now uses `hle/service/ssl/ssl_backend_none.cpp`.
  - non-iOS-bootstrap builds keep existing OpenSSL backend and compile definitions.
- This prevents missing imported target/link failures when OpenSSL is intentionally skipped in bootstrap CI.

## Current Result

- iOS bootstrap build profile exists.
- iOS bootstrap target exists and is wired into source tree.
- MoltenVK support on iOS path is now toolchain-based instead of macOS artifact-based.
- Bootstrap API now provides preflight checks and machine-readable report strings for frontend bring-up.
- C ABI bridge now exists so Swift/ObjC wrappers can call bootstrap preflight safely.
- Objective-C++ bridge now exists so iOS app code can call bootstrap preflight without touching C++ directly.
- Runtime placeholder controls now exist end-to-end (C++ core, C ABI, Objective-C++ app layer).
- Runtime placeholder now supports pollable ticking and per-session IDs for UI state tracking.
- Runtime now also exposes reactive event callbacks for start, stop, and tick.
- iOS app shell now has concrete controller/view-model logic that can be bound directly by Swift/ObjC UI.
- A concrete UIKit demo screen is now available as a practical integration reference.
- A dedicated GitHub Actions workflow is now available for iOS bootstrap build smoke tests.
- Runtime start validation now includes real core-loader checks, not only path-level checks.
- Runtime start now also attempts headless `Core::System::Load` before marking session as running.
- Runtime now can continue into a managed background `Core::System::Run` thread.
- Runtime now detects background run-thread completion and reflects that in state/report.

## Known Limitations (Expected at This Stage)

- SwiftUI views are not committed yet; UIKit demo controller is now available.
- Runtime start or stop currently uses placeholder session control, not full emulation execution handoff yet.
- No iOS packaging/project generation logic included in this step.
- MoltenVK must be provided by the iOS build environment/toolchain.
- CI workflow validates bootstrap compilation path, not gameplay/runtime correctness yet.
- `Core::System::Load` is now attempted headless; long-running run loop integration is still pending.
- Managed run thread exists, but full lifecycle/perf tuning and gameplay validation are still pending.
- Thread completion is now tracked, but robust pause/resume and crash-recovery behavior are still pending.
- iOS bootstrap CI configure blockers for architecture parsing and OpenSSL requirement are now addressed.

### 20) Live remote logging path (iPad -> Windows terminal)
File: `src/ios/ios_runtime_objc_bridge.h`

- Added Objective-C API to configure remote log endpoint at runtime:
  - `+setRemoteDebugLogEndpoint:`
  - `+remoteDebugLogEndpoint`

File: `src/ios/ios_runtime_objc_bridge.mm`

- Added remote runtime log sender via `NSURLSession` POST JSON.
- Added payload builder with runtime metadata:
  - `timestamp`
  - `event`
  - `running`
  - `lastStartSucceeded`
  - `runThreadActive`
  - `sessionID`
  - `tickCount`
  - `report`
- Runtime event callback now forwards events to NotificationCenter and remote endpoint.
- Runtime direct calls (`start`, `tick`, `state`, `stop`) now also emit remote debug logs.

File: `src/ios/ios_runtime_demo_controller.mm`

- Added demo UI field for live log endpoint input.
- Added `Set Live Log` action button to apply endpoint from UI without recompiling wrapper logic.

File: `tools/windows/ios-live-log-server.ps1`

- Added Windows PowerShell live log receiver server using `HttpListener`.
- Server prints runtime events/report in real-time to terminal for debugging sessions.

File: `docs/IOS_LIVE_DEBUGGING.md`

- Added step-by-step usage guide for live debugging from iPad to VS Code terminal.

### 21) Live log server no-admin mode and multi-source validation
File: `tools/windows/ios-live-log-server.ps1`

- Reworked receiver implementation from `HttpListener` to `TcpListener`.
- Removed dependency on URL ACL reservation and elevated admin startup for standard use.
- Added lightweight HTTP parsing and explicit JSON response writer.
- Fixed POST body parsing to avoid request hangs during `Invoke-RestMethod` tests.
- Confirmed ingest of multiple log payloads in one session (simulated iPad + komputer source).

File: `docs/IOS_LIVE_DEBUGGING.md`

- Updated instructions for Tailscale-based setup (`komputer-kerja` endpoint for `muhammads-ipad`).
- Clarified that the latest script no longer uses `-HostToken` parameter.

### 22) Extra hardening for iOS CI configure stability
File: `externals/cmake-modules/DetectArchitecture.cmake`

- Simplified Apple architecture iteration to `foreach(ARCH ${CMAKE_OSX_ARCHITECTURES})`.
- Prevents parser-variant issues that can still surface as `Unknown arguments: arm64` in some CI contexts.

File: `CMakeLists.txt`

- OpenSSL discovery is now skipped for all iOS builds (`if (NOT PLATFORM_IOS)`), not only bootstrap-gated branches.
- Reduces dependency on cache-state/order for `ENABLE_IOS_BOOTSTRAP` during configure phase.

File: `src/core/CMakeLists.txt`

- iOS path now always uses `ssl_backend_none.cpp` and never links `OpenSSL::SSL/OpenSSL::Crypto`.
- Non-iOS behavior remains unchanged with OpenSSL backend.

### 23) Fix Apple framework selection for iOS CI
File: `CMakeLists.txt`

- Split APPLE platform framework lookup into macOS and iOS branches.
- iOS branch now searches only iOS-available frameworks:
  - `Metal`
  - `CoreVideo`
  - `CoreMedia`
  - `Foundation`
- macOS branch keeps existing framework list (`Carbon`, `Cocoa`, `IOKit`, etc.).
- This resolves iOS configure failure where CI previously attempted to find `Carbon` on iOS simulator toolchain.

### 24) Fix httplib OpenSSL requirement on iOS CI
File: `CMakeLists.txt`

- In iOS bootstrap profile, force cpp-httplib OpenSSL options OFF:
  - `HTTPLIB_USE_OPENSSL_IF_AVAILABLE=OFF`
  - `HTTPLIB_REQUIRE_OPENSSL=OFF`

File: `externals/CMakeLists.txt`

- Added iOS-specific guard before `AddJsonPackage(httplib)` to force the same options OFF at package injection point.
- Prevents CMake configure failure in CI where httplib attempted `find_package(OpenSSL)` on iOS simulator builds.

### 25) Force package-level override for httplib options
File: `externals/CMakeLists.txt`

- Updated `AddJsonPackage(httplib)` call for iOS to pass explicit `OPTIONS` overrides:
  - `HTTPLIB_REQUIRE_OPENSSL OFF`
  - `HTTPLIB_USE_OPENSSL_IF_AVAILABLE OFF`
- This ensures runtime overrides are appended after `cpmfile.json` defaults, so iOS can override the `HTTPLIB_REQUIRE_OPENSSL ON` entry shipped in package metadata.

### 26) Improve CI diagnostics for iOS bootstrap failures
File: `.github/workflows/ios-bootstrap.yml`

- Enabled verbose configure messages in main configure step:
  - `-DCMAKE_MESSAGE_LOG_LEVEL=VERBOSE`
- Added failure-only diagnostics step that prints:
  - `externals/cpmfile.json` lines related to `httplib/openssl`
  - filtered `build-ios/CMakeCache.txt` values (`OPENSSL`, `HTTPLIB`, iOS flags)
  - tail of `CMakeConfigureLog.yaml`, `CMakeOutput.log`, and `CMakeError.log`
- Added failure replay configure using `--debug-find` into separate directory (`build-ios-debug`) and persisted log file.
- Added artifact upload step (`ios-bootstrap-diagnostics`) with key configure/debug logs for easier root-cause analysis.

### 27) Make CI diagnostic output shorter and focused
File: `.github/workflows/ios-bootstrap.yml`

- Reduced noisy console output in failure diagnostics:
  - removed long tails for `CMakeConfigureLog.yaml` and `CMakeOutput.log` from console.
  - reduced `CMakeError.log` tail from 400 lines to 120 lines.
- Added concise matched-error extraction (`cmake error`, `could not find`, `fatal`, `failed`, `openssl`, `httplib`, `carbon`).
- Added compact failure summary to `GITHUB_STEP_SUMMARY`.
- Kept full `--debug-find` output only in artifact file (no longer spamming main log view).

### 28) Capture real configure errors (not try-compile noise)
File: `.github/workflows/ios-bootstrap.yml`

- Configure step now saves full output to `build-ios/configure.log` using `tee`.
- Failure summary now extracts only hard configure markers from `configure.log`:
  - `CMake Error at`
  - `Could NOT find`
  - `Configuring incomplete, errors occurred`
- Added `Root cause snippet` block in step summary using contextual lines around the first hard error markers.
- Added `build-ios/configure.log` to uploaded diagnostics artifact.

### 29) Fix iOS configure root cause from summary output
File: `externals/CMakeLists.txt`

- Fixed iOS-specific `httplib` package invocation to use keyword form when passing options:
  - from `AddJsonPackage(httplib OPTIONS ...)`
  - to `AddJsonPackage(NAME httplib OPTIONS ...)`
- This resolves fatal configure error from `CPMUtil`: `json package: No name specified`.

File: `CMakeLists.txt`

- Changed optional RenderDoc lookup to quiet mode:
  - `find_package(RenderDoc MODULE QUIET)`
- Prevents optional RenderDoc probe from polluting failure summary with non-blocking `Could NOT find` noise.

### 30) Fix FFmpeg discovery failure in iOS bootstrap CI
File: `CMakeLists.txt`

- iOS profile now forces FFmpeg strategy to bundled mode:
  - `YUZU_USE_BUNDLED_FFMPEG=ON`
  - `YUZU_USE_EXTERNAL_FFMPEG=OFF`
- Avoids system `find_package(FFmpeg REQUIRED)` path that failed on runner with missing `FFMPEG_INCLUDE_DIR`.

File: `.github/workflows/ios-bootstrap.yml`

- Configure and debug-find replay now pass explicit FFmpeg flags:
  - `-DYUZU_USE_BUNDLED_FFMPEG=ON`
  - `-DYUZU_USE_EXTERNAL_FFMPEG=OFF`
- Keeps CI behavior aligned with iOS bootstrap profile regardless of cache or option order.

### 31) Ensure glslangValidator is available in iOS CI runner
File: `.github/workflows/ios-bootstrap.yml`

- Added explicit dependency install step before configure:
  - `brew install glslang` (if not already installed)
  - `glslangValidator --version` for verification
- Resolves configure failure in `src/video_core/host_shaders/CMakeLists.txt` requiring `glslangValidator`.

### 32) Fix SDL2 target error in input_common for iOS bootstrap
File: `src/input_common/CMakeLists.txt`

- Added iOS branch to skip SDL2-based input drivers during iOS bootstrap configure.
- Prevents configure failure:
  - `target_link_libraries(input_common PRIVATE SDL2::SDL2)`
  - when SDL2 target is intentionally not provided on iOS bootstrap path.

### 33) Add build-stage error summary in CI diagnostics
File: `.github/workflows/ios-bootstrap.yml`

- Build step now captures output to `build-ios/build.log`.
- Failure diagnostics now include dedicated build error extraction:
  - `error:`
  - `fatal error:`
  - `undefined reference`
  - `ld: error`
  - `ninja: build stopped`
  - `subcommand failed`
- Added `Build root cause snippet` section in Step Summary for fast triage when configure stage succeeds but build stage fails.
- Added `build-ios/build.log` to uploaded diagnostics artifact.

### 34) Fix Boost.Context x86_64 asm mismatch on iOS arm64 CI
File: `CMakeLists.txt`

- In iOS bootstrap profile, force Boost.Context build tuple to arm64 iOS values:
  - `BOOST_CONTEXT_ARCHITECTURE=arm64`
  - `BOOST_CONTEXT_ABI=aapcs`
  - `BOOST_CONTEXT_BINARY_FORMAT=mach-o`
  - `BOOST_CONTEXT_ASSEMBLER=gas`
  - `BOOST_CONTEXT_ASM_SUFFIX=.S`
- Prevents Boost.Context from selecting `x86_64_sysv_macho_gas.S` sources during iOS arm64 build.

File: `.github/workflows/ios-bootstrap.yml`

- Added `-DCMAKE_SYSTEM_PROCESSOR=arm64` to both configure and debug-find replay commands.
- Improves cross-compile architecture detection consistency on GitHub macOS runners.

### 35) Strengthen Boost.Context options at package call site
File: `CMakeLists.txt`

- Updated iOS path to pass Boost.Context options directly via `AddJsonPackage(NAME boost OPTIONS ...)`.
- Ensures settings are applied at dependency configure time even when upstream package defaults differ.

File: `.github/workflows/ios-bootstrap.yml`

- Added explicit `-DBOOST_CONTEXT_*` flags to configure and debug-find commands.
- Extended cache summary filter to include `BOOST_CONTEXT*` and `CMAKE_SYSTEM_PROCESSOR` for verification in CI summary.

### 36) Fix IOKit header include on iOS simulator build
File: `src/common/device_power_state.cpp`

- Corrected Apple platform guards from `TARGET_OS_MAC` to `TARGET_OS_OSX`.
- `TARGET_OS_MAC` is true on non-macOS Apple targets as well, which caused iOS simulator builds to include macOS-only IOKit power headers.
- `IOKit/ps/IOPSKeys.h` and `IOPowerSources.h` are now included only for macOS builds, avoiding iOS compile failure.

### 37) Add explicit iOS compile-definition guard for power-state code
File: `src/common/device_power_state.cpp`

- Added `!defined(YUZU_PLATFORM_IOS)` guard to Apple IOKit include and macOS runtime branch.
- Ensures iOS bootstrap builds cannot enter macOS-only power source code path even if Apple target macros behave unexpectedly in simulator contexts.

### 38) Make power-state source selection explicit for iOS target
File: `src/common/CMakeLists.txt`

- Removed unconditional `device_power_state.cpp` from common source list.
- Added conditional source selection:
  - iOS uses `device_power_state_ios.cpp`
  - non-iOS uses existing `device_power_state.cpp`
- Prevents any accidental compilation of macOS-only IOKit source on iOS toolchains.

File: `src/common/device_power_state_ios.cpp`

- Added iOS-safe stub implementation of `Common::GetPowerStatus()` for bootstrap builds.

### 39) Add header-availability fallback for Apple IOKit power includes
File: `src/common/device_power_state.cpp`

- Wrapped IOKit includes behind `__has_include` checks and compile-time flag `EDEN_HAS_APPLE_IOKIT_POWER`.
- Apple power-source branch now compiles only when the required headers are actually available.
- Prevents fatal include errors on iOS simulator SDKs even if macOS power-state source is selected unexpectedly.

### 40) Expose first configure/build hard error as CI annotation
File: `.github/workflows/ios-bootstrap.yml`

- In failure diagnostics step, capture the first configure hard error and first build hard error from log files.
- Emit them via GitHub workflow commands:
  - `::error title=Configure failure::...`
  - `::error title=Build failure::...`
- Makes root-cause retrieval possible from public check-run annotations API, enabling autonomous fix loops without manual copy-paste of full logs.

### 41) Guard Apple `sys/random.h` include for iOS simulator SDK
File: `src/common/host_memory.cpp`

- Wrapped `#include <sys/random.h>` in Apple branch with `__has_include(<sys/random.h>)`.
- Fixes iOS simulator build failure where the SDK lacks that header.

### 42) Unblock C++20 `std::stop_token` on iOS bootstrap toolchain
File: `CMakeLists.txt`

- In iOS profile, added `_LIBCPP_DISABLE_AVAILABILITY=1` compile definition.
- Prevents libc++ availability gating from hiding C++20 threading symbols (such as `std::stop_token`) during simulator cross-builds.

### 43) Include `<stop_token>` in thread polyfill header
File: `src/common/polyfill_thread.h`

- Added missing standard include for `std::stop_token`.
- Fixes compile failure where some libc++ configurations do not expose `stop_token` via `<thread>` alone.

### 44) Add portable stop-token wait helper and apply across common sync code
Files:
- `src/common/polyfill_thread.h`
- `src/common/thread.h`
- `src/common/bounded_threadsafe_queue.h`
- `src/common/threadsafe_queue.h`
- `src/common/thread_worker.h`

- Added `Common::WaitWithStopToken(...)` helper that uses native stop-token `wait` overload when available and a timed wait fallback otherwise.
- Replaced direct `cv.wait(lock, stop_token, predicate)` calls in common synchronization utilities with the helper.
- Prevents Apple/iOS libc++ builds from failing when the stop-token `wait` overload is not present.

### 45) Add `std::jthread` compatibility shim when libc++ lacks it
File: `src/common/polyfill_thread.h`

- Added fallback implementation guarded by `__cpp_lib_jthread`.
- Provides minimal `std::jthread` behavior (`request_stop`, `joinable`, `join`, move semantics) using `std::thread` + `std::stop_source`.
- Avoids redefining `std::stop_token`, preventing ambiguity on libc++ variants that expose `stop_token` but not `jthread`.

### 46) Exclude Boost.Process from iOS bootstrap dependency set
Files:
- `CMakeLists.txt`
- `src/core/CMakeLists.txt`

- Removed `process` from `BOOST_INCLUDE_LIBRARIES` when `PLATFORM_IOS` is enabled.
- Skipped linking `Boost::process` in `core` for iOS profile.
- Avoids Boost.Process source build on iOS toolchains, fixing `wordexp is unavailable: not available on iOS` failure.

### 47) Replace remaining stop-token `wait` overloads in `.cpp` workers
Files:
- `src/video_core/cdma_pusher.cpp`
- `src/audio_core/sink/sink_stream.cpp`
- `src/yuzu/bootmanager.cpp`
- `src/video_core/gpu_thread.cpp`
- `src/video_core/renderer_vulkan/vk_turbo_mode.cpp`
- `src/video_core/renderer_vulkan/vk_scheduler.cpp`
- `src/video_core/renderer_vulkan/vk_present_manager.cpp`
- `src/video_core/renderer_vulkan/vk_master_semaphore.cpp`

- Replaced direct `condition_variable_any.wait(lock, stop_token, predicate)` calls with `Common::WaitWithStopToken(...)`.
- Prevents further libc++ API-availability/overload mismatches across runtime worker loops in iOS bootstrap builds.

### 48) Fix Vulkan `Offset3D` aggregate initialization in texture copy path
File: `src/video_core/renderer_vulkan/vk_texture_cache.cpp`

- Replaced `VideoCommon::Offset3D(0, 0, 0)` with brace initialization `VideoCommon::Offset3D{0, 0, 0}`.
- Resolves compiler error on iOS toolchain that rejects parenthesized initialization for this aggregate type.

### 49) Skip dynarmic backend for iOS bootstrap compile profile
Files:
- `src/core/CMakeLists.txt`
- `src/core/arm/exclusive_monitor.cpp`

- Disabled dynarmic source/link block for `PLATFORM_IOS` in `core` target.
- Guarded dynarmic exclusive monitor include/use in `exclusive_monitor.cpp` out of iOS builds.
- Prevents bootstrap build failures from missing `dynarmic/interface/*` headers in iOS CI profile.

### 50) Split AES utility source for iOS bootstrap (no OpenSSL)
Files:
- `src/core/CMakeLists.txt`
- `src/core/crypto/aes_util_ios.cpp`

- Removed unconditional `crypto/aes_util.cpp` from `core` source list.
- Added platform source selection:
  - iOS uses `crypto/aes_util_ios.cpp`
  - non-iOS keeps `crypto/aes_util.cpp` (OpenSSL path)
- Added a minimal iOS bootstrap AES implementation to avoid OpenSSL header dependency (`openssl/err.h`) in CI compile profile.

### 51) Make key manager OpenSSL usage optional for iOS bootstrap
File:
- `src/core/crypto/key_manager.cpp`

- Wrapped OpenSSL headers (`evp.h`, `bn.h`) behind non-iOS compilation guard.
- Added iOS fallback path in `ParseTicketTitleKey(...)` for personalized ticket decryption:
  - logs warning and returns `std::nullopt` in bootstrap profile.
- Added iOS fallback stubs in OpenSSL-dependent helpers:
  - `MGF1(...)` returns zeroed buffer
  - `CalculateCMAC(...)` returns zeroed key
- Keeps full existing OpenSSL-based behavior on non-iOS builds while unblocking iOS CI compile where OpenSSL headers are unavailable.

### 52) Split debugger backend source for iOS bootstrap (no Boost.Process)
Files:
- `src/core/CMakeLists.txt`
- `src/core/debugger/debugger_ios.cpp`

- Removed unconditional debugger backend `.cpp` sources from `core` source list.
- Added platform source selection:
  - iOS uses `debugger/debugger_ios.cpp` (no-op debugger backend)
  - non-iOS keeps full debugger stack (`debugger.cpp`, `gdbstub.cpp`, `gdbstub_arch.cpp`)
- Avoids iOS build failure from missing Boost.Process headers (`boost/process/v1/async_pipe.hpp`) while preserving full debugger behavior on non-iOS targets.

### 53) Add iOS SHA256 fallback stubs in registered cache (no OpenSSL headers)
File:
- `src/core/file_sys/registered_cache.cpp`

- Wrapped OpenSSL include behind non-iOS guard.
- Added iOS-local fallback stubs for:
  - `EVP_sha256()`
  - `EVP_Digest(...)`
- Fallback returns deterministic zeroed SHA256 output for bootstrap profile, unblocking compile when OpenSSL headers are unavailable on iOS CI.

### 54) Add iOS OpenSSL-free fallbacks in XTS archive path
File:
- `src/core/file_sys/xts_archive.cpp`

- Wrapped OpenSSL includes behind non-iOS guard.
- Added iOS-local SHA256 fallback stubs:
  - `EVP_sha256()`
  - `EVP_Digest(...)`
- Added iOS fallback for `CalculateHMAC256(...)` to return deterministic zeroed output for bootstrap compile profile.
- Keeps existing OpenSSL-based HMAC/SHA256 behavior on non-iOS builds.

### 55) Guard process dynarmic wiring out of iOS bootstrap profile
File:
- `src/core/hle/kernel/k_process.cpp`

- Wrapped dynarmic header includes in non-iOS guards.
- Added early iOS path in `KProcess::InitializeInterfaces()`:
  - initializes exclusive monitor pointer as before
  - skips dynarmic backend construction
  - resets CPU interface slots to null in bootstrap compile profile
- Prevents iOS build from pulling dynarmic headers like `dynarmic/interface/halt_reason.h` that are absent in CI profile.

### 56) Fix missing exclusive monitor declaration after dynarmic include guards
File:
- `src/core/hle/kernel/k_process.cpp`

- Added explicit include for `core/arm/exclusive_monitor.h`.
- Restores visibility of `Core::MakeExclusiveMonitor(...)` after dynarmic include guards were introduced for iOS bootstrap profile.

### 57) Exclude dynarmic backend construction from iOS compile path
File:
- `src/core/hle/kernel/k_process.cpp`

- Wrapped dynarmic/NCE CPU interface construction block in non-iOS preprocessor guard.
- Prevents iOS compilation from resolving symbols like `Core::ArmDynarmic64` and `Core::ArmDynarmic32` when dynarmic headers are intentionally excluded.

### 58) Remove OpenSSL dependency from BCAT delivery digest on iOS bootstrap
File:
- `src/core/hle/service/bcat/delivery_cache_directory_service.cpp`

- Wrapped OpenSSL includes with non-iOS guard.
- Added iOS fallback digest implementation in `DigestFile(...)` using deterministic rolling hash expansion into `BcatDigest`.
- Keeps OpenSSL MD5 digest path for non-iOS targets.

### 59) Fix BCAT news unused constant warning under non-OpenSSL HTTP path
File:
- `src/core/hle/service/bcat/news/builtin_news.cpp`

- Wrapped `GitHubAPI_EdenReleases` constant with `CPPHTTPLIB_OPENSSL_SUPPORT` guard.
- Prevents `-Wunused-const-variable` from failing iOS bootstrap builds when HTTPS fetch path is compiled out.

### 60) Split Amiibo crypto source for iOS bootstrap (no OpenSSL)
Files:
- `src/core/CMakeLists.txt`
- `src/core/hle/service/nfc/common/amiibo_crypto.h`
- `src/core/hle/service/nfc/common/amiibo_crypto_ios.cpp`

- Removed unconditional `amiibo_crypto.cpp` from base `core` source list.
- Added platform source selection:
  - iOS uses `amiibo_crypto_ios.cpp`
  - non-iOS keeps `amiibo_crypto.cpp` (OpenSSL path)
- Removed direct OpenSSL header dependency from `amiibo_crypto.h` so it can be included in iOS builds.
- Added compile-safe iOS fallback implementation for Amiibo crypto entrypoints to unblock iOS bootstrap profile compilation.

### 61) Guard RO service SHA256 hash path from OpenSSL headers on iOS
File:
- `src/core/hle/service/ro/ro.cpp`

- Wrapped OpenSSL includes behind non-iOS preprocessor guard.
- Added iOS fallback stubs for `EVP_sha256()` and `EVP_Digest(...)` returning deterministic zeroed SHA256 output.
- Keeps original OpenSSL-backed digest behavior on non-iOS builds.

### 62) Guard NCA loader integrity hashing path from OpenSSL headers on iOS
File:
- `src/core/loader/nca.cpp`

- Wrapped OpenSSL includes behind non-iOS preprocessor guard.
- Added iOS fallback stubs for EVP digest context APIs used by `VerifyIntegrity(...)`:
  - `EVP_MD_CTX_new/free`
  - `EVP_DigestInit_ex`
  - `EVP_DigestUpdate`
  - `EVP_DigestFinal_ex`
  - `EVP_sha256`
- Keeps original OpenSSL-backed NCA integrity hashing behavior on non-iOS builds.

### 63) Fix iOS Debugger unique_ptr incomplete-type build failure
File:
- `src/core/debugger/debugger_ios.cpp`

- Added concrete iOS stub definition for `Core::DebuggerImpl` in the iOS debugger translation unit.
- Ensures `std::unique_ptr<DebuggerImpl>` in `Debugger` has a complete pointee type at destructor instantiation time.
- Resolves iOS CI failure from libc++ `unique_ptr` static assertion on incomplete type.

### 64) Add libc++ fallback for stop-token timed wait helper
File:
- `src/common/polyfill_thread.h`

- Added a compile-time fallback in `StoppableTimedWait(...)` for toolchains lacking
  `condition_variable_any::wait_for(lock, stop_token, duration, predicate)`.
- Fallback uses short-slice `wait_for(lock, duration)` polling until timeout or stop request.
- Keeps existing native stop-token timed-wait path when available.

### 65) Fix duration-type mismatch in fallback timed wait slice logic
File:
- `src/common/polyfill_thread.h`

- Replaced `std::min(remaining, 10ms)` in fallback path with explicit
  `duration_cast` and manual comparison.
- Avoids libc++ template deduction failure (`no matching function for call to 'min'`) when
  `remaining` and `milliseconds` have different duration types.

### 66) Fix Objective-C dealloc warning promoted to error in iOS CI
File:
- `src/ios/ios_runtime_view_model.mm`

- Added non-ARC guarded `[super dealloc]` call in `-dealloc`:
  - `#if !__has_feature(objc_arc)`
  - `[super dealloc];`
  - `#endif`
- Resolves `-Wobjc-missing-super-calls` failure in strict warning-as-error iOS bootstrap builds.

### 67) Make runtime demo block capture compatible with MRC builds
File:
- `src/ios/ios_runtime_demo_controller.mm`

- Replaced unconditional `__weak` self capture with ARC/MRC split:
  - ARC: `__weak typeof(self) weakSelf = self;`
  - non-ARC (MRC): `__unsafe_unretained typeof(self) weakSelf = self;`
- Resolves iOS CI failure: `cannot create __weak reference in file using manual reference counting`.

### 68) Fix designated-initializer contract warning in iOS demo controller
File:
- `src/ios/ios_runtime_demo_controller.h`

- Kept custom initializer as `NS_DESIGNATED_INITIALIZER`.
- Marked inherited `UIViewController` initializers as unavailable in subclass interface:
  - `initWithNibName:bundle:`
  - `initWithCoder:`
- Resolves strict warning-as-error failure for missing override of superclass designated initializer.

### 69) Fix incomplete FileSystemController type in iOS runtime session
File:
- `src/ios/ios_runtime_session.cpp`

- Added missing include for full filesystem controller definition:
  - `core/hle/service/filesystem/filesystem.h`
- Resolves compile error when calling
  `g_system->GetFileSystemController().CreateFactories(...)` from iOS runtime load path.

### 70) Fix incomplete GPU/CpuManager types in iOS runtime load path
File:
- `src/ios/ios_runtime_session.cpp`

- Added missing concrete type includes required by direct method calls:
  - `core/cpu_manager.h` for `GetCpuManager().OnGpuReady()`
  - `video_core/gpu.h` for `GPU().Start()`
- Resolves incomplete-type compile failures after the runtime path progressed past filesystem setup.

### 71) Add concrete iOS app bundle target for installation builds
Files:
- `src/ios/CMakeLists.txt`
- `src/ios/ios_app_main.mm`
- `src/ios/Info-iOS.plist.in`

- Added new iOS executable bundle target: `eden-ios-app` (`MACOSX_BUNDLE`) linked with
  `yuzu-ios-bootstrap` and UIKit/Foundation.
- Added UIKit app entrypoint (`UIApplicationMain`) with app delegate that launches
  `EdenIOSRuntimeDemoController` as root UI.
- Added dedicated iOS Info.plist template and CMake cache variables for:
  - executable name (`IOS_APP_EXECUTABLE_NAME`)
  - bundle identifier (`IOS_APP_BUNDLE_IDENTIFIER`)
  - version/build number (`IOS_APP_VERSION`, `IOS_APP_BUILD_NUMBER`)

### 72) Produce downloadable IPA artifact from CI
File:
- `.github/workflows/ios-bootstrap.yml`

- Switched iOS configure sysroot from simulator to device (`iphoneos`) for installable package output.
- Updated build target from `yuzu-ios-bootstrap` to `eden-ios-app`.
- Added IPA packaging step:
  - locate `EdenIOS.app`
  - create `Payload/`
  - zip as `build-ios/eden-ios-unsigned.ipa`
- Added artifact upload step `eden-ios-ipa` on successful workflow runs.
- Kept diagnostics artifact upload and extended it to include generated IPA when present.

### 73) Fix app link stage by exporting bootstrap static-library dependencies
File:
- `src/ios/CMakeLists.txt`

- Changed `yuzu-ios-bootstrap` link visibility from `PRIVATE` to `PUBLIC` for
  `common`, `core`, and `frontend_common`.
- Ensures `eden-ios-app` receives transitive libraries required to resolve symbols
  when linking against the bootstrap static library.

### 74) Stabilize IPA generation with shell app target and optional runtime linkage
Files:
- `src/ios/CMakeLists.txt`
- `src/ios/ios_app_main.mm`
- `.github/workflows/ios-bootstrap.yml`

- Added `IOS_APP_LINK_BOOTSTRAP` option (default `OFF`) so IPA generation path can avoid
  unresolved device-link issues while keeping a compile-safe installable app bundle.
- Updated iOS app entrypoint to a minimal UIKit home controller shell for deterministic link output.
- Workflow build now compiles both targets:
  - `yuzu-ios-bootstrap` (core/bootstrap compile validation)
  - `eden-ios-app` (IPA packaging source)

### 75) Prioritize IPA artifact success path in CI
File:
- `.github/workflows/ios-bootstrap.yml`

- Set `-DIOS_APP_LINK_BOOTSTRAP=OFF` explicitly in configure and debug-replay commands.
- Reduced build target set to `eden-ios-app` only for the IPA workflow path.
- Purpose: ensure deterministic `.ipa` artifact production for iPad installation flow
  while runtime-heavy linkage is reintroduced later behind explicit enable flag.

### 76) Expose linker root-cause lines directly in public CI annotations
File:
- `.github/workflows/ios-bootstrap.yml`

- Enabled verbose build output (`cmake --build ... --verbose`) for IPA job.
- Expanded build error extraction patterns to prioritize linker root causes:
  - `Undefined symbols for architecture`
  - `symbol(s) not found`
  - `framework not found`
  - `library not found`
  - `duplicate symbol`
- Increased root-cause snippet window to improve first-failure visibility from annotations.

### 77) Migrate IPA app entrypoint from Objective-C++ to Objective-C
Files:
- `src/ios/CMakeLists.txt`
- `src/ios/ios_app_main.m`

- Replaced `.mm` entrypoint source with `.m` Objective-C source for the standalone IPA shell app.
- Keeps identical UIKit bootstrap behavior while removing ObjC++ link/runtime surface from
  IPA packaging path.

### 78) Force Objective-C toolchain path for iOS app linking
File:
- `src/ios/CMakeLists.txt`

- Enabled `OBJC` language explicitly for iOS subtree.
- Set `eden-ios-app` target properties:
  - `LINKER_LANGUAGE OBJC`
  - `XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES`
- Purpose: resolve unresolved ObjC runtime/link symbols by using Objective-C link path deterministically.

### 79) Fix missing CoreGraphics symbol in IPA app link stage
File:
- `src/ios/CMakeLists.txt`

- Added `-framework CoreGraphics` to `eden-ios-app` link libraries.
- Resolves linker error for `_CGRectZero` referenced from `ios_app_main.m`.

### 80) Activate live logging and live update notifier in IPA shell UI
File:
- `src/ios/ios_app_main.m`

- Replaced static placeholder UI with operational live-communication screen:
  - configurable live log endpoint field + save action
  - manual ping button
  - configurable live update feed URL + save action
  - manual update check button
  - runtime status label
- Added periodic live logging heartbeat (default every 12s) to existing TCP log receiver format.
- Added live update polling (default every 90s) with support for GitHub Releases JSON:
  - reads `tag_name` / `body` / `html_url`
  - compares against local app version
  - shows update alert popup when newer version is detected
  - emits `update_available` event to live log endpoint for cross-device coordination.

### 81) Fix MRC compatibility for async update-check callback capture
File:
- `src/ios/ios_app_main.m`

- Replaced unconditional `__weak` capture with ARC/MRC guard:
  - ARC: `__weak typeof(self) weakSelf = self;`
  - non-ARC: `__unsafe_unretained typeof(self) weakSelf = self;`
- Resolves CI compile error on manual reference counting builds.

### 82) Re-enable runtime-linked IPA path and exercise bootstrap bridge in app UI
Files:
- `.github/workflows/ios-bootstrap.yml`
- `src/ios/ios_app_main.m`

- Switched IPA CI configure mode from shell-only to runtime-linked app:
  - `-DIOS_APP_LINK_BOOTSTRAP=ON` (main configure + debug-find replay).
- Updated iOS app shell to call bootstrap/runtime Objective-C bridges when linked:
  - import `ios_bootstrap_objc_bridge.h` and `ios_runtime_objc_bridge.h` under `YUZU_IOS_BOOTSTRAP`.
  - add runtime controls in UI (`Mulai Runtime`, `Hentikan Runtime`, `Status Runtime`).
  - run bootstrap preflight on app startup and report results to live log endpoint.
  - subscribe to runtime event notifications and reflect state in status label.
  - keep no-op fallback messaging when runtime linkage is disabled.

### 83) Improve runtime-linker compatibility and accelerate CI rebuilds
Files:
- `src/ios/CMakeLists.txt`
- `.github/workflows/ios-bootstrap.yml`

- iOS app linker mode now switches based on runtime-link option:
  - `IOS_APP_LINK_BOOTSTRAP=ON` -> `LINKER_LANGUAGE OBJCXX`
  - `IOS_APP_LINK_BOOTSTRAP=OFF` -> `LINKER_LANGUAGE OBJC`
- Enabled `OBJCXX` language in iOS subtree and added explicit `c++` linkage when runtime bootstrap is linked.
- Added `ccache` to iOS workflow for faster incremental CI runs:
  - install + restore cache + stats reporting
  - configure uses compiler launchers for C/C++/ObjC/ObjC++
  - warm-cache reruns are expected to be significantly faster than cold builds.

### 84) Add public linker-context annotation for failed iOS CI builds
File:
- `.github/workflows/ios-bootstrap.yml`

- Extended failure diagnostics to emit a generic linker-context annotation even when
  `Undefined symbols for architecture` is not matched.
- New extraction scans for:
  - `Undefined symbols for architecture`
  - `symbol(s) not found`
  - `ld: error`
  - `clang: error: linker command failed`
- Adds a contextual log window around the first linker marker to:
  - `::error title=Linker context::...` (public annotation)
  - `GITHUB_STEP_SUMMARY` (human-readable snippet)
- Purpose: unblock autonomous fix loops when artifact/log download requires authentication.

### 85) Filter linker annotations to actionable lines (avoid compile-command noise)
File:
- `.github/workflows/ios-bootstrap.yml`

- Refined first-error extraction to prioritize real linker signatures before generic compiler errors.
- Added linker-context extraction based on focused key lines instead of wide raw log windows:
  - `Undefined symbols for architecture`
  - `symbol(s) not found`
  - `ld:` lines
  - `clang: error: linker command failed`
  - `collect2: error: ld returned`
  - `ninja: build stopped` / `ninja: error:`
- Added explicit `First undefined symbol` annotation from the undefined-symbol block when available.
- Purpose: ensure public annotations expose root-cause linker data directly (not long ccache compile command lines), enabling faster autonomous fix loops.

### 86) Expand iOS bootstrap link dependency closure to match runtime frontend needs
File:
- `src/ios/CMakeLists.txt`

- Extended `yuzu-ios-bootstrap` link set beyond `common/core/frontend_common` to include:
  - `input_common`
  - `video_core`
  - `Threads::Threads`
- Added iOS platform library propagation for bootstrap runtime target:
  - `target_link_libraries(yuzu-ios-bootstrap PRIVATE ${PLATFORM_LIBRARIES})`
- Purpose: reduce runtime-linked app linker failures caused by unresolved symbols that are provided by frontend/runtime support libraries but were not previously in the iOS bootstrap target link closure.

### 87) Fix SPIRV tools linkage fallback that emitted missing `-lSPIRV-Tools-opt`
File:
- `externals/CMakeLists.txt`

- Updated `SPIRV-Tools-static` post-link wiring to only add opt/link components when corresponding targets actually exist.
- Added guarded target resolution for both plain and namespaced target names:
  - `SPIRV-Tools-opt` / `SPIRV-Tools::SPIRV-Tools-opt`
  - `SPIRV-Tools-link` / `SPIRV-Tools::SPIRV-Tools-link`
- Added status messages when optional targets are not present, instead of implicitly passing raw library names to linker.
- Purpose: resolve iOS CI linker failure observed in run #74:
  - `ld: library 'SPIRV-Tools-opt' not found`.

