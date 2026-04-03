// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EdenIOSSetupStatus {
    int keys_installed;
    int firmware_installed;
} EdenIOSSetupStatus;

int EdenIOSSetupGetStatus(EdenIOSSetupStatus* out_status,
                          char* report_buffer,
                          size_t report_buffer_size);

int EdenIOSInstallKeys(const char* prod_keys_path,
                       EdenIOSSetupStatus* out_status,
                       char* report_buffer,
                       size_t report_buffer_size);

int EdenIOSInstallFirmware(const char* source_path,
                           int recursive,
                           EdenIOSSetupStatus* out_status,
                           char* report_buffer,
                           size_t report_buffer_size);

#ifdef __cplusplus
}
#endif
