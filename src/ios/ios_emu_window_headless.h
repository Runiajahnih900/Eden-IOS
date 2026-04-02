// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <memory>

#include "core/frontend/emu_window.h"

namespace IOSFrontend {

class EmuWindowIOSHeadless final : public Core::Frontend::EmuWindow {
public:
    EmuWindowIOSHeadless();
    ~EmuWindowIOSHeadless() override;

    std::unique_ptr<Core::Frontend::GraphicsContext> CreateSharedContext() const override;
    bool IsShown() const override;
};

} // namespace IOSFrontend
