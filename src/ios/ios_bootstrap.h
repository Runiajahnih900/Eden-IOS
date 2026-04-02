// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <string>

namespace IOSFrontend {

struct BootstrapConfig {
    bool request_jit = false;
    bool enable_validation_layers = false;
};

struct BootstrapStatus {
    bool ready = false;
    bool on_ios = false;
    bool moltenvk_available = false;
    bool game_path_valid = false;
    std::string game_path;
    std::string summary;
};

BootstrapStatus PrepareBootstrap(const BootstrapConfig& config);
BootstrapStatus PrepareBootstrap(const BootstrapConfig& config, const std::string& game_path);
std::string BuildBootstrapReport(const BootstrapStatus& status);

} // namespace IOSFrontend