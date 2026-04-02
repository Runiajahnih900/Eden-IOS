// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: Copyright 2022 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

#include "core/debugger/debugger.h"

namespace Core {

// Keep a concrete impl type so unique_ptr<DebuggerImpl> can be destroyed on iOS.
class DebuggerImpl {};

Debugger::Debugger(Core::System& system, u16 server_port) {
    (void)system;
    (void)server_port;
}

Debugger::~Debugger() = default;

bool Debugger::NotifyThreadStopped(Kernel::KThread* thread) {
    (void)thread;
    return false;
}

void Debugger::NotifyShutdown() {}

bool Debugger::NotifyThreadWatchpoint(Kernel::KThread* thread, const Kernel::DebugWatchpoint& watch) {
    (void)thread;
    (void)watch;
    return false;
}

} // namespace Core
