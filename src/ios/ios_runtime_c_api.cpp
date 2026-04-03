// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_runtime_c_api.h"

#include <cstring>
#include <mutex>
#include <string>

#include "ios_runtime_session.h"

namespace {

std::mutex g_callback_mutex;
EdenIOSRuntimeEventCallback g_runtime_event_callback = nullptr;
void* g_runtime_event_user_data = nullptr;

void WriteReportToBuffer(const std::string& report, char* report_buffer, const size_t report_buffer_size) {
    if (!report_buffer || report_buffer_size == 0) {
        return;
    }

    const size_t bytes_to_copy = report.size() < (report_buffer_size - 1)
                                     ? report.size()
                                     : (report_buffer_size - 1);
    if (bytes_to_copy > 0) {
        std::memcpy(report_buffer, report.data(), bytes_to_copy);
    }
    report_buffer[bytes_to_copy] = '\0';
}

void DispatchRuntimeEvent(const EdenIOSRuntimeEventType event_type,
                          const IOSFrontend::RuntimeSessionStatus& status) {
    EdenIOSRuntimeEventCallback callback = nullptr;
    void* user_data = nullptr;
    {
        std::scoped_lock lock(g_callback_mutex);
        callback = g_runtime_event_callback;
        user_data = g_runtime_event_user_data;
    }
    if (!callback) {
        return;
    }

    EdenIOSRuntimeState state{};
    state.running = status.running ? 1 : 0;
    state.last_start_succeeded = status.last_start_succeeded ? 1 : 0;
    state.run_thread_active = status.run_thread_active ? 1 : 0;
    state.session_id = static_cast<unsigned long long>(status.session_id);
    state.tick_count = static_cast<unsigned long long>(status.tick_count);

    callback(event_type, &state, status.last_report.c_str(), user_data);
}

} // namespace

void EdenIOSRuntimeSetEventCallback(EdenIOSRuntimeEventCallback callback, void* user_data) {
    std::scoped_lock lock(g_callback_mutex);
    g_runtime_event_callback = callback;
    g_runtime_event_user_data = user_data;
}

int EdenIOSRuntimeStart(const EdenIOSRuntimeStartOptions* options,
                       EdenIOSRuntimeState* out_state,
                       char* report_buffer,
                       const size_t report_buffer_size) {
    if (!out_state) {
        return 0;
    }

    IOSFrontend::RuntimeStartRequest request{};
    if (options) {
        request.request_jit = options->request_jit != 0;
        request.enable_validation_layers = options->enable_validation_layers != 0;
        request.start_execution_thread = options->start_execution_thread != 0;
        if (options->game_path) {
            request.game_path = options->game_path;
        }
        request.renderer_backend = options->renderer_backend;
        request.resolution_setup = options->resolution_setup;
    }

    IOSFrontend::RuntimeSessionStatus status{};
    const bool ok = IOSFrontend::StartRuntimeSession(request, &status);

    out_state->running = status.running ? 1 : 0;
    out_state->last_start_succeeded = status.last_start_succeeded ? 1 : 0;
    out_state->run_thread_active = status.run_thread_active ? 1 : 0;
    out_state->session_id = static_cast<unsigned long long>(status.session_id);
    out_state->tick_count = static_cast<unsigned long long>(status.tick_count);
    WriteReportToBuffer(status.last_report, report_buffer, report_buffer_size);
    DispatchRuntimeEvent(EDEN_IOS_RUNTIME_EVENT_START, status);

    return ok ? 1 : 0;
}

void EdenIOSRuntimeStop(void) {
    IOSFrontend::StopRuntimeSession();
    const IOSFrontend::RuntimeSessionStatus status = IOSFrontend::QueryRuntimeSessionStatus();
    DispatchRuntimeEvent(EDEN_IOS_RUNTIME_EVENT_STOP, status);
}

int EdenIOSRuntimeTick(EdenIOSRuntimeState* out_state,
                      char* report_buffer,
                      const size_t report_buffer_size) {
    if (!out_state) {
        return 0;
    }

    const IOSFrontend::RuntimeSessionStatus status = IOSFrontend::TickRuntimeSession();
    out_state->running = status.running ? 1 : 0;
    out_state->last_start_succeeded = status.last_start_succeeded ? 1 : 0;
    out_state->run_thread_active = status.run_thread_active ? 1 : 0;
    out_state->session_id = static_cast<unsigned long long>(status.session_id);
    out_state->tick_count = static_cast<unsigned long long>(status.tick_count);
    WriteReportToBuffer(status.last_report, report_buffer, report_buffer_size);
    DispatchRuntimeEvent(EDEN_IOS_RUNTIME_EVENT_TICK, status);
    return 1;
}

int EdenIOSRuntimeGetState(EdenIOSRuntimeState* out_state,
                          char* report_buffer,
                          const size_t report_buffer_size) {
    if (!out_state) {
        return 0;
    }

    const IOSFrontend::RuntimeSessionStatus status = IOSFrontend::QueryRuntimeSessionStatus();
    out_state->running = status.running ? 1 : 0;
    out_state->last_start_succeeded = status.last_start_succeeded ? 1 : 0;
    out_state->run_thread_active = status.run_thread_active ? 1 : 0;
    out_state->session_id = static_cast<unsigned long long>(status.session_id);
    out_state->tick_count = static_cast<unsigned long long>(status.tick_count);
    WriteReportToBuffer(status.last_report, report_buffer, report_buffer_size);
    return 1;
}
