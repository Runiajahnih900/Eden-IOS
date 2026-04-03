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

target_link_libraries(yuzu-ios-bootstrap PUBLIC common core frontend_common)

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

if (PLATFORM_IOS)
    enable_language(OBJC)
    enable_language(OBJCXX)

    set(IOS_APP_EXECUTABLE_NAME "EdenIOS" CACHE STRING "Executable name for iOS app bundle")
    set(IOS_APP_BUNDLE_IDENTIFIER "com.edenemu.ios" CACHE STRING "Bundle identifier for iOS app bundle")
    set(IOS_APP_VERSION "0.1.0" CACHE STRING "Short version for iOS app bundle")
    set(IOS_APP_BUILD_NUMBER "1" CACHE STRING "Build number for iOS app bundle")
    option(IOS_APP_LINK_BOOTSTRAP "Link eden-ios-app with yuzu-ios-bootstrap runtime" OFF)

    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/Info-iOS.plist.in
                   ${CMAKE_CURRENT_BINARY_DIR}/Info-iOS.plist @ONLY)

    add_executable(eden-ios-app MACOSX_BUNDLE
        ios_app_main.m)

    target_link_libraries(eden-ios-app PRIVATE
        "-framework Foundation"
        "-framework CoreGraphics"
        "-framework UIKit")

    if (IOS_APP_LINK_BOOTSTRAP)
        target_link_libraries(eden-ios-app PRIVATE yuzu-ios-bootstrap)
        target_link_libraries(eden-ios-app PRIVATE c++)
        target_compile_definitions(eden-ios-app PRIVATE YUZU_IOS_BOOTSTRAP=1)
        set(_EDEN_IOS_APP_LINKER_LANGUAGE OBJCXX)
    else()
        set(_EDEN_IOS_APP_LINKER_LANGUAGE OBJC)
    endif()

    set_target_properties(eden-ios-app PROPERTIES
        OUTPUT_NAME ${IOS_APP_EXECUTABLE_NAME}
        MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_BINARY_DIR}/Info-iOS.plist
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
        LINKER_LANGUAGE ${_EDEN_IOS_APP_LINKER_LANGUAGE}
        XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)
endif()