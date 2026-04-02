// SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: 2022 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

//
// TODO: remove this file when jthread is supported by all compilation targets
//

#pragma once

#include <chrono>
#include <condition_variable>
#include <stop_token>
#include <thread>
#include <utility>

namespace Common {

template <typename ConditionVariable, typename Lock, typename Predicate>
bool WaitWithStopToken(ConditionVariable& cv, Lock& lock, std::stop_token token,
                       Predicate&& pred) {
    if constexpr (requires { cv.wait(lock, token, std::forward<Predicate>(pred)); }) {
        cv.wait(lock, token, std::forward<Predicate>(pred));
        return !token.stop_requested();
    } else {
        while (!pred()) {
            if (token.stop_requested()) {
                return false;
            }
            cv.wait_for(lock, std::chrono::milliseconds{10});
        }
        return true;
    }
}

template <typename Rep, typename Period>
bool StoppableTimedWait(std::stop_token token, const std::chrono::duration<Rep, Period>& rel_time) {
    std::condition_variable_any cv;
    std::mutex m;

    // Perform the timed wait.
    std::unique_lock lk{m};
    return !cv.wait_for(lk, token, rel_time, [&] { return token.stop_requested(); });
}

} // namespace Common
