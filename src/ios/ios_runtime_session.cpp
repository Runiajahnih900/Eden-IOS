// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_runtime_session.h"

#include <mutex>
#include <string>
#include <thread>
#include <atomic>

#include "common/settings.h"
#include "ios_bootstrap.h"
#include "ios_emu_window_headless.h"
#include "core/core.h"
#include "core/file_sys/registered_cache.h"
#include "core/file_sys/vfs/vfs_real.h"
#include "core/hle/service/am/applet_manager.h"
#include "core/hle/service/filesystem/filesystem.h"
#include "core/loader/loader.h"

namespace IOSFrontend {

namespace {

std::mutex g_runtime_mutex;
bool g_running = false;
bool g_last_start_succeeded = false;
std::uint64_t g_session_id = 0;
std::uint64_t g_tick_count = 0;
std::uint64_t g_next_session_id = 1;
std::string g_current_game_path;
std::string g_last_report = "runtime-idle";
std::unique_ptr<Core::System> g_system;
std::unique_ptr<EmuWindowIOSHeadless> g_emu_window;
std::thread g_run_thread;
bool g_run_thread_active = false;
std::atomic<bool> g_run_thread_alive{false};

struct LoaderPreflightResult {
    bool file_opened = false;
    bool type_known = false;
    bool bootable = false;
    Loader::FileType file_type = Loader::FileType::Unknown;
};

LoaderPreflightResult RunLoaderPreflight(const std::string& game_path) {
    LoaderPreflightResult result{};

    const auto vfs = std::make_shared<FileSys::RealVfsFilesystem>();
    const auto file = Core::GetGameFileFromPath(vfs, game_path);
    if (!file) {
        return result;
    }

    result.file_opened = true;
    result.file_type = Loader::IdentifyFile(file);
    result.type_known = result.file_type != Loader::FileType::Unknown &&
                        result.file_type != Loader::FileType::Error;
    if (!result.type_known) {
        return result;
    }

    if (Loader::IsContainerType(result.file_type)) {
        result.bootable = Loader::IsBootableGameContainer(file, result.file_type);
    } else {
        result.bootable = true;
    }

    return result;
}

void TearDownSystemLocked() {
    if (!g_system) {
        if (g_run_thread.joinable()) {
            g_run_thread.join();
        }
        g_run_thread_active = false;
        g_run_thread_alive.store(false, std::memory_order_release);
        return;
    }

    g_system->SetExitRequested(true);
    g_system->ShutdownMainProcess();

    if (g_run_thread.joinable()) {
        g_run_thread.join();
    }
    g_run_thread_active = false;
    g_run_thread_alive.store(false, std::memory_order_release);

    g_emu_window.reset();
    g_system.reset();
}

bool StartCoreLoadPath(const RuntimeStartRequest& request, std::string* out_report) {
    TearDownSystemLocked();

    g_system = std::make_unique<Core::System>();
    g_system->Initialize();

    Settings::values.renderer_backend = Settings::RendererBackend::Null;
    g_system->ApplySettings();

    g_system->SetContentProvider(std::make_unique<FileSys::ContentProviderUnion>());
    g_system->SetFilesystem(std::make_shared<FileSys::RealVfsFilesystem>());
    g_system->GetFileSystemController().CreateFactories(*g_system->GetFilesystem());
    g_system->GetUserChannel().clear();

    g_emu_window = std::make_unique<EmuWindowIOSHeadless>();

    Service::AM::FrontendAppletParameters load_parameters{
        .applet_id = Service::AM::AppletId::Application,
    };
    const auto load_result = g_system->Load(*g_emu_window, request.game_path, load_parameters);
    if (load_result != Core::SystemResultStatus::Success) {
        if (out_report) {
            *out_report += ";core_load_result=" + std::to_string(static_cast<u32>(load_result));
        }
        TearDownSystemLocked();
        return false;
    }

    g_system->GPU().Start();
    g_system->GetCpuManager().OnGpuReady();

    if (request.start_execution_thread) {
        Core::System* const system = g_system.get();
        g_run_thread = std::thread([system] {
            g_run_thread_alive.store(true, std::memory_order_release);
            if (system) {
                void(system->Run());
            }
            g_run_thread_alive.store(false, std::memory_order_release);
        });
        g_run_thread_active = true;
    } else {
        g_run_thread_active = false;
        g_run_thread_alive.store(false, std::memory_order_release);
    }

    if (out_report) {
        *out_report += ";core_load_result=success";
        *out_report += request.start_execution_thread ? ";core_run_thread=started"
                                                      : ";core_run_thread=disabled";
    }
    return true;
}

RuntimeSessionStatus BuildSnapshot() {
    RuntimeSessionStatus status{};
    status.running = g_running;
    status.last_start_succeeded = g_last_start_succeeded;
    const bool thread_alive = g_run_thread_alive.load(std::memory_order_acquire);
    status.run_thread_active = g_run_thread_active && thread_alive;
    status.session_id = g_session_id;
    status.tick_count = g_tick_count;
    status.current_game_path = g_current_game_path;
    status.last_report = g_last_report;
    return status;
}

} // namespace

bool StartRuntimeSession(const RuntimeStartRequest& request, RuntimeSessionStatus* out_status) {
    BootstrapConfig config{};
    config.request_jit = request.request_jit;
    config.enable_validation_layers = request.enable_validation_layers;

    const BootstrapStatus bootstrap_status = PrepareBootstrap(config, request.game_path);
    std::string bootstrap_report = BuildBootstrapReport(bootstrap_status);

    LoaderPreflightResult loader_preflight{};
    if (bootstrap_status.ready && bootstrap_status.game_path_valid) {
        loader_preflight = RunLoaderPreflight(request.game_path);
        bootstrap_report += ";loader_file_opened=";
        bootstrap_report += loader_preflight.file_opened ? "true" : "false";
        bootstrap_report += ";loader_type=";
        bootstrap_report += Loader::GetFileTypeString(loader_preflight.file_type);
        bootstrap_report += ";loader_type_known=";
        bootstrap_report += loader_preflight.type_known ? "true" : "false";
        bootstrap_report += ";loader_bootable=";
        bootstrap_report += loader_preflight.bootable ? "true" : "false";
    }

    RuntimeSessionStatus status{};
    {
        std::scoped_lock lock(g_runtime_mutex);
        if (!bootstrap_status.ready || !bootstrap_status.game_path_valid ||
            !loader_preflight.file_opened || !loader_preflight.type_known ||
            !loader_preflight.bootable) {
            TearDownSystemLocked();
            g_running = false;
            g_last_start_succeeded = false;
            g_session_id = 0;
            g_tick_count = 0;
            g_current_game_path.clear();
            g_last_report = bootstrap_report + ";runtime=start-rejected-loader-preflight";
        } else {
            if (StartCoreLoadPath(request, &bootstrap_report)) {
                g_running = true;
                g_last_start_succeeded = true;
                g_session_id = g_next_session_id++;
                g_tick_count = 0;
                g_current_game_path = request.game_path;
                g_last_report = bootstrap_report + ";runtime=start-core-load";
            } else {
                g_running = false;
                g_last_start_succeeded = false;
                g_run_thread_active = false;
                g_session_id = 0;
                g_tick_count = 0;
                g_current_game_path.clear();
                g_last_report = bootstrap_report + ";runtime=start-rejected-core-load";
            }
        }
        status = BuildSnapshot();
    }

    if (out_status) {
        *out_status = status;
    }
    return status.last_start_succeeded;
}

void StopRuntimeSession() {
    std::scoped_lock lock(g_runtime_mutex);
    if (g_running) {
        g_running = false;
        g_session_id = 0;
        g_tick_count = 0;
        g_current_game_path.clear();
        TearDownSystemLocked();
        g_last_report = "runtime-stopped";
    } else {
        TearDownSystemLocked();
        g_last_report = "runtime-stop-noop";
    }
}

RuntimeSessionStatus TickRuntimeSession() {
    std::scoped_lock lock(g_runtime_mutex);
    const bool thread_alive = g_run_thread_alive.load(std::memory_order_acquire);

    if (g_running && g_run_thread_active && !thread_alive) {
        g_running = false;
        g_run_thread_active = false;
        g_last_report = "runtime-thread-finished";
        return BuildSnapshot();
    }

    if (g_running) {
        ++g_tick_count;
        g_last_report = "runtime-tick";
    } else {
        g_last_report = "runtime-tick-noop";
    }
    return BuildSnapshot();
}

RuntimeSessionStatus QueryRuntimeSessionStatus() {
    std::scoped_lock lock(g_runtime_mutex);
    return BuildSnapshot();
}

} // namespace IOSFrontend
