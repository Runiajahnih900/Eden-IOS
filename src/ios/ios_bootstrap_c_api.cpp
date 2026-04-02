// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_bootstrap_c_api.h"

#include <cstring>
#include <string>

#include "ios_bootstrap.h"

namespace {

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

} // namespace

int EdenIOSBootstrapAbiVersion(void) {
    return 1;
}

int EdenIOSPrepareBootstrap(const EdenIOSBootstrapOptions* options,
                           EdenIOSBootstrapResult* out_result,
                           char* report_buffer,
                           const size_t report_buffer_size) {
    if (!out_result) {
        return 0;
    }

    IOSFrontend::BootstrapConfig config{};
    std::string game_path;

    if (options) {
        config.request_jit = options->request_jit != 0;
        config.enable_validation_layers = options->enable_validation_layers != 0;
        if (options->game_path) {
            game_path = options->game_path;
        }
    }

    const IOSFrontend::BootstrapStatus status = IOSFrontend::PrepareBootstrap(config, game_path);

    out_result->ready = status.ready ? 1 : 0;
    out_result->on_ios = status.on_ios ? 1 : 0;
    out_result->moltenvk_available = status.moltenvk_available ? 1 : 0;
    out_result->game_path_valid = status.game_path_valid ? 1 : 0;

    const std::string report = IOSFrontend::BuildBootstrapReport(status);
    WriteReportToBuffer(report, report_buffer, report_buffer_size);

    return 1;
}
