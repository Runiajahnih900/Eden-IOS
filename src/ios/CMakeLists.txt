# SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

add_library(yuzu-ios-bootstrap STATIC
    ios_bootstrap.cpp
    ios_bootstrap.h
    ios_bootstrap_c_api.cpp
    ios_bootstrap_c_api.h
    ios_emu_window_headless.cpp
    ios_emu_window_headless.h
    ios_runtime_session.cpp
    ios_runtime_session.h
    ios_runtime_c_api.cpp
    ios_runtime_c_api.h)

if (PLATFORM_IOS)
    target_sources(yuzu-ios-bootstrap PRIVATE
        ios_bootstrap_objc_bridge.h
        ios_bootstrap_objc_bridge.mm
        ios_runtime_objc_bridge.h
    ios_runtime_objc_bridge.mm
    ios_runtime_view_model.h
    ios_runtime_view_model.mm
    ios_runtime_demo_controller.h
    ios_runtime_demo_controller.mm)
endif()

target_link_libraries(yuzu-ios-bootstrap PRIVATE common core frontend_common)

if (APPLE)
    target_link_libraries(yuzu-ios-bootstrap PRIVATE "-framework Foundation")

    if (PLATFORM_IOS)
        if (NOT MOLTENVK_LIBRARY)
            find_library(MOLTENVK_LIBRARY MoltenVK)
        endif()

        if (MOLTENVK_LIBRARY)
            message(STATUS "Using iOS MoltenVK at ${MOLTENVK_LIBRARY}.")
            target_link_libraries(yuzu-ios-bootstrap PRIVATE ${MOLTENVK_LIBRARY})
            target_compile_definitions(yuzu-ios-bootstrap PUBLIC YUZU_IOS_MOLTENVK=1)
        else()
            message(WARNING "iOS bootstrap will build without MoltenVK linkage.")
        endif()
    endif()
endif()

set_target_properties(yuzu-ios-bootstrap PROPERTIES OUTPUT_NAME "eden-ios-bootstrap")
target_compile_definitions(yuzu-ios-bootstrap PUBLIC YUZU_IOS_BOOTSTRAP=1)