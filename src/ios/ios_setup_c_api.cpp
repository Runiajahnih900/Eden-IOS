// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_setup_c_api.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <filesystem>
#include <string>
#include <vector>

#include "common/fs/path_util.h"
#include "frontend_common/content_manager.h"
#include "frontend_common/firmware_manager.h"

namespace {

void WriteReportToBuffer(const std::string& report, char* report_buffer,
                         const size_t report_buffer_size) {
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

std::string ToLower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

bool HasInstalledFirmware() {
    Common::FS::CreateEdenPaths();
    const std::filesystem::path firmware_dir =
        Common::FS::GetEdenPath(Common::FS::EdenPath::NANDDir) / "system/Contents/registered";

    std::error_code ec;
    if (!std::filesystem::exists(firmware_dir, ec) || ec) {
        return false;
    }

    for (const auto& entry :
         std::filesystem::recursive_directory_iterator(firmware_dir, ec)) {
        if (ec) {
            break;
        }

        if (!entry.is_regular_file()) {
            continue;
        }

        if (ToLower(entry.path().extension().string()) == ".nca") {
            return true;
        }
    }
    return false;
}

EdenIOSSetupStatus BuildStatus() {
    EdenIOSSetupStatus status{};
    status.keys_installed = ContentManager::AreKeysPresent() ? 1 : 0;
    status.firmware_installed = HasInstalledFirmware() ? 1 : 0;
    return status;
}

std::string BuildStatusReport(const EdenIOSSetupStatus& status,
                              const std::string& prefix) {
    std::string report = prefix;
    report += ";keys_installed=";
    report += status.keys_installed != 0 ? "true" : "false";
    report += ";firmware_installed=";
    report += status.firmware_installed != 0 ? "true" : "false";
    return report;
}

std::string KeyInstallResultToString(const FirmwareManager::KeyInstallResult result) {
    switch (result) {
    case FirmwareManager::Success:
        return "success";
    case FirmwareManager::InvalidDir:
        return "invalid-dir";
    case FirmwareManager::ErrorFailedCopy:
        return "failed-copy";
    case FirmwareManager::ErrorWrongFilename:
        return "wrong-filename";
    case FirmwareManager::ErrorFailedInit:
        return "failed-init";
    default:
        return "unknown";
    }
}

std::vector<std::filesystem::path> CollectNcaFiles(const std::filesystem::path& source,
                                                   const bool recursive) {
    std::vector<std::filesystem::path> out;
    std::error_code ec;

    if (recursive) {
        for (const auto& entry : std::filesystem::recursive_directory_iterator(source, ec)) {
            if (ec) {
                break;
            }
            if (entry.is_regular_file() && ToLower(entry.path().extension().string()) == ".nca") {
                out.emplace_back(entry.path());
            }
        }
    } else {
        for (const auto& entry : std::filesystem::directory_iterator(source, ec)) {
            if (ec) {
                break;
            }
            if (entry.is_regular_file() && ToLower(entry.path().extension().string()) == ".nca") {
                out.emplace_back(entry.path());
            }
        }
    }

    return out;
}

} // namespace

int EdenIOSSetupGetStatus(EdenIOSSetupStatus* out_status,
                          char* report_buffer,
                          const size_t report_buffer_size) {
    if (!out_status) {
        return 0;
    }

    const EdenIOSSetupStatus status = BuildStatus();
    *out_status = status;
    WriteReportToBuffer(BuildStatusReport(status, "setup-status"), report_buffer,
                        report_buffer_size);
    return 1;
}

int EdenIOSInstallKeys(const char* prod_keys_path,
                       EdenIOSSetupStatus* out_status,
                       char* report_buffer,
                       const size_t report_buffer_size) {
    if (!out_status) {
        return 0;
    }

    if (!prod_keys_path || std::string(prod_keys_path).empty()) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        WriteReportToBuffer(BuildStatusReport(status, "install-keys-empty-path"), report_buffer,
                            report_buffer_size);
        return 0;
    }

    const auto result = FirmwareManager::InstallKeys(prod_keys_path, ".keys");
    const EdenIOSSetupStatus status = BuildStatus();
    *out_status = status;

    std::string report = "install-keys";
    report += ";result=" + KeyInstallResultToString(result);
    report += ";path=" + std::string(prod_keys_path);
    report += ";keys_installed=";
    report += status.keys_installed != 0 ? "true" : "false";
    WriteReportToBuffer(report, report_buffer, report_buffer_size);
    return result == FirmwareManager::Success ? 1 : 0;
}

int EdenIOSInstallFirmware(const char* source_path,
                           const int recursive,
                           EdenIOSSetupStatus* out_status,
                           char* report_buffer,
                           const size_t report_buffer_size) {
    if (!out_status) {
        return 0;
    }

    if (!source_path || std::string(source_path).empty()) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        WriteReportToBuffer(BuildStatusReport(status, "install-firmware-empty-path"), report_buffer,
                            report_buffer_size);
        return 0;
    }

    const std::filesystem::path source{source_path};
    std::error_code ec;
    if (!std::filesystem::exists(source, ec) || ec) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        WriteReportToBuffer(BuildStatusReport(status, "install-firmware-source-missing"),
                            report_buffer, report_buffer_size);
        return 0;
    }

    if (!std::filesystem::is_directory(source, ec) || ec) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        std::string report = BuildStatusReport(status, "install-firmware-source-not-directory");
        report += ";path=" + source.string();
        WriteReportToBuffer(report, report_buffer, report_buffer_size);
        return 0;
    }

    const std::vector<std::filesystem::path> nca_files = CollectNcaFiles(source, recursive != 0);
    if (nca_files.empty()) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        std::string report = BuildStatusReport(status, "install-firmware-no-nca-found");
        report += ";path=" + source.string();
        WriteReportToBuffer(report, report_buffer, report_buffer_size);
        return 0;
    }

    Common::FS::CreateEdenPaths();
    const std::filesystem::path destination =
        Common::FS::GetEdenPath(Common::FS::EdenPath::NANDDir) / "system/Contents/registered";

    std::filesystem::create_directories(destination, ec);
    if (ec) {
        const EdenIOSSetupStatus status = BuildStatus();
        *out_status = status;
        WriteReportToBuffer(BuildStatusReport(status, "install-firmware-create-destination-failed"),
                            report_buffer, report_buffer_size);
        return 0;
    }

    for (const auto& entry : std::filesystem::directory_iterator(destination, ec)) {
        if (ec) {
            break;
        }
        if (entry.is_regular_file() && ToLower(entry.path().extension().string()) == ".nca") {
            std::filesystem::remove(entry.path(), ec);
            ec.clear();
        }
    }

    std::size_t copied_count = 0;
    for (const auto& nca : nca_files) {
        std::filesystem::path target = destination / nca.filename();
        std::filesystem::copy_file(nca, target,
                                   std::filesystem::copy_options::overwrite_existing, ec);
        if (ec) {
            const EdenIOSSetupStatus status = BuildStatus();
            *out_status = status;
            std::string report = BuildStatusReport(status, "install-firmware-copy-failed");
            report += ";failed_file=" + nca.string();
            WriteReportToBuffer(report, report_buffer, report_buffer_size);
            return 0;
        }
        ++copied_count;
    }

    const EdenIOSSetupStatus status = BuildStatus();
    *out_status = status;
    std::string report = BuildStatusReport(status, "install-firmware-success");
    report += ";copied_nca_count=" + std::to_string(copied_count);
    WriteReportToBuffer(report, report_buffer, report_buffer_size);
    return status.firmware_installed != 0 ? 1 : 0;
}
