// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <cstdint>
#include <string>

namespace IOSFrontend {

struct RuntimeStartRequest {
    bool request_jit = false;
    bool enable_validation_layers = false;
    bool start_execution_thread = true;
    std::string game_path;
    int renderer_backend = -1;
    int resolution_setup = -1;
};

struct RuntimeSessionStatus {
    bool running = false;
    bool last_start_succeeded = false;
    bool run_thread_active = false;
    std::uint64_t session_id = 0;
    std::uint64_t tick_count = 0;
    std::string current_game_path;
    std::string last_report;
};

bool StartRuntimeSession(const RuntimeStartRequest& request, RuntimeSessionStatus* out_status);
void StopRuntimeSession();
RuntimeSessionStatus TickRuntimeSession();
RuntimeSessionStatus QueryRuntimeSessionStatus();

} // namespace IOSFrontend
