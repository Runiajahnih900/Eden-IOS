// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "device_power_state.h"

namespace Common {

PowerStatus GetPowerStatus() {
    PowerStatus info;
    info.percentage = -1;
    info.charging = false;
    info.has_battery = false;
    return info;
}

} // namespace Common
