// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ios_emu_window_headless.h"

#include "core/frontend/graphics_context.h"

namespace IOSFrontend {

namespace {

class DummyContext final : public Core::Frontend::GraphicsContext {};

} // namespace

EmuWindowIOSHeadless::EmuWindowIOSHeadless() {
    window_info.type = Core::Frontend::WindowSystemType::Headless;
    window_info.display_connection = nullptr;
    window_info.render_surface = nullptr;
    window_info.render_surface_scale = 1.0f;
}

EmuWindowIOSHeadless::~EmuWindowIOSHeadless() = default;

std::unique_ptr<Core::Frontend::GraphicsContext> EmuWindowIOSHeadless::CreateSharedContext() const {
    return std::make_unique<DummyContext>();
}

bool EmuWindowIOSHeadless::IsShown() const {
    return true;
}

} // namespace IOSFrontend
