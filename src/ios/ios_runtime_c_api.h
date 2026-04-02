// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EdenIOSRuntimeStartOptions {
    int request_jit;
    int enable_validation_layers;
    const char* game_path;
} EdenIOSRuntimeStartOptions;

typedef struct EdenIOSRuntimeState {
    int running;
    int last_start_succeeded;
    unsigned long long session_id;
    unsigned long long tick_count;
} EdenIOSRuntimeState;

typedef enum EdenIOSRuntimeEventType {
    EDEN_IOS_RUNTIME_EVENT_START = 1,
    EDEN_IOS_RUNTIME_EVENT_STOP = 2,
    EDEN_IOS_RUNTIME_EVENT_TICK = 3,
} EdenIOSRuntimeEventType;

typedef void (*EdenIOSRuntimeEventCallback)(
    EdenIOSRuntimeEventType event_type,
    const EdenIOSRuntimeState* state,
    const char* report,
    void* user_data);

void EdenIOSRuntimeSetEventCallback(EdenIOSRuntimeEventCallback callback, void* user_data);

int EdenIOSRuntimeStart(const EdenIOSRuntimeStartOptions* options,
                       EdenIOSRuntimeState* out_state,
                       char* report_buffer,
                       size_t report_buffer_size);

void EdenIOSRuntimeStop(void);

int EdenIOSRuntimeTick(EdenIOSRuntimeState* out_state,
                      char* report_buffer,
                      size_t report_buffer_size);

int EdenIOSRuntimeGetState(EdenIOSRuntimeState* out_state,
                          char* report_buffer,
                          size_t report_buffer_size);

#ifdef __cplusplus
}
#endif
