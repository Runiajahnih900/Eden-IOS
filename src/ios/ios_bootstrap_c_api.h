// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EdenIOSBootstrapOptions {
    int request_jit;
    int enable_validation_layers;
    const char* game_path;
} EdenIOSBootstrapOptions;

typedef struct EdenIOSBootstrapResult {
    int ready;
    int on_ios;
    int moltenvk_available;
    int game_path_valid;
} EdenIOSBootstrapResult;

int EdenIOSBootstrapAbiVersion(void);

int EdenIOSPrepareBootstrap(const EdenIOSBootstrapOptions* options,
                           EdenIOSBootstrapResult* out_result,
                           char* report_buffer,
                           size_t report_buffer_size);

#ifdef __cplusplus
}
#endif
