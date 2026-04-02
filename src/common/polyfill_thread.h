// SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: 2022 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

//
// TODO: remove this file when jthread is supported by all compilation targets
//

#pragma once

#include <algorithm>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <stop_token>
#include <thread>
#include <type_traits>
#include <utility>

#if !defined(__cpp_lib_jthread) || (__cpp_lib_jthread < 201911L)
namespace std {

class jthread {
public:
    jthread() noexcept = default;

    template <typename F, typename... Args>
    explicit jthread(F&& f, Args&&... args) {
        if constexpr (std::is_invocable_v<F, stop_token, Args...>) {
            thread = std::thread(std::forward<F>(f), stop_source.get_token(),
                                 std::forward<Args>(args)...);
        } else {
            thread = std::thread(std::forward<F>(f), std::forward<Args>(args)...);
        }
    }

    ~jthread() {
        request_stop();
        if (joinable()) {
            join();
        }
    }

    jthread(const jthread&) = delete;
    jthread& operator=(const jthread&) = delete;

    jthread(jthread&& other) noexcept = default;
    jthread& operator=(jthread&& other) noexcept {
        if (this != &other) {
            request_stop();
            if (joinable()) {
                join();
            }
            thread = std::move(other.thread);
            stop_source = std::move(other.stop_source);
        }
        return *this;
    }

    [[nodiscard]] bool joinable() const noexcept {
        return thread.joinable();
    }

    void join() {
        thread.join();
    }

    void detach() {
        thread.detach();
    }

    void request_stop() noexcept {
        (void)stop_source.request_stop();
    }

    [[nodiscard]] stop_token get_stop_token() const noexcept {
        return stop_source.get_token();
    }

private:
    std::thread thread;
    std::stop_source stop_source;
};

} // namespace std
#endif

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
    if constexpr (requires { cv.wait_for(lk, token, rel_time, [&] { return token.stop_requested(); }); }) {
        return !cv.wait_for(lk, token, rel_time, [&] { return token.stop_requested(); });
    } else {
        const auto deadline = std::chrono::steady_clock::now() + rel_time;
        while (!token.stop_requested()) {
            const auto now = std::chrono::steady_clock::now();
            if (now >= deadline) {
                return true;
            }
            const auto remaining = deadline - now;
            const auto sleep_slice = (std::min)(remaining, std::chrono::milliseconds{10});
            cv.wait_for(lk, sleep_slice);
        }
        return false;
    }
}

} // namespace Common
