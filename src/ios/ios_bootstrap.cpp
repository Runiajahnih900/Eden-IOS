// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_bootstrap.h"

#include <array>
#include <filesystem>
#include <string_view>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

namespace IOSFrontend {

namespace {

constexpr std::array<std::string_view, 8> kSupportedGameExtensions = {
    ".nsp", ".xci", ".nca", ".nro", ".nso", ".kip", ".zip", ".7z",
};

bool HasSupportedGameExtension(const std::filesystem::path& game_path) {
    if (!game_path.has_extension()) {
        return false;
    }

    const std::string ext = game_path.extension().string();
    for (const auto candidate : kSupportedGameExtensions) {
        if (ext == candidate) {
            return true;
        }
    }
    return false;
}

bool IsValidGamePath(const std::string& game_path) {
    if (game_path.empty()) {
        return false;
    }

    const std::filesystem::path path{game_path};
    std::error_code ec;
    const bool exists = std::filesystem::exists(path, ec);
    if (ec || !exists) {
        return false;
    }

    if (std::filesystem::is_directory(path, ec)) {
        return !ec;
    }

    if (ec || !std::filesystem::is_regular_file(path, ec)) {
        return false;
    }

    return HasSupportedGameExtension(path);
}

} // namespace

BootstrapStatus PrepareBootstrap(const BootstrapConfig& config) {
    return PrepareBootstrap(config, {});
}

BootstrapStatus PrepareBootstrap(const BootstrapConfig& config, const std::string& game_path) {
    BootstrapStatus status{};

#if defined(__APPLE__) && defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
    status.on_ios = true;
    status.ready = true;
    status.summary = config.request_jit ? "ios-bootstrap-ready-jit-requested"
                                        : "ios-bootstrap-ready";
#else
    status.ready = false;
    status.summary = "ios-bootstrap-target-not-active";
#endif

#ifdef YUZU_IOS_MOLTENVK
    status.moltenvk_available = true;
#endif

    if (!game_path.empty()) {
        status.game_path = game_path;
        status.game_path_valid = IsValidGamePath(game_path);
        status.summary += status.game_path_valid ? "-gamepath-ok" : "-gamepath-invalid";
    }

    if (status.on_ios && !status.moltenvk_available) {
        status.summary += "-no-moltenvk";
    }

    if (config.enable_validation_layers && status.ready) {
        status.summary += "-validation-requested";
    }

    return status;
}

std::string BuildBootstrapReport(const BootstrapStatus& status) {
    std::string report = "ready=";
    report += status.ready ? "true" : "false";
    report += ";on_ios=";
    report += status.on_ios ? "true" : "false";
    report += ";moltenvk=";
    report += status.moltenvk_available ? "linked" : "missing";
    report += ";game_path=";
    report += status.game_path.empty() ? "<unset>" : status.game_path;
    report += ";game_path_valid=";
    report += status.game_path_valid ? "true" : "false";
    report += ";summary=";
    report += status.summary;
    return report;
}

} // namespace IOSFrontend