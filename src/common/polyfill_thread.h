// SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: 2022 yuzu Emulator Project
// SPDX-License-Identifier: GPL-2.0-or-later

//
// TODO: remove this file when jthread is supported by all compilation targets
//

#pragma once

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <stop_token>
#include <memory>
#include <thread>
#include <type_traits>
#include <utility>

#if !defined(__cpp_lib_jthread) || (__cpp_lib_jthread < 201911L)
namespace std {

#if !defined(__cpp_lib_stop_token) || (__cpp_lib_stop_token < 201907L)
class stop_token {
public:
    stop_token() = default;

    [[nodiscard]] bool stop_requested() const noexcept {
        return state && state->load(std::memory_order_acquire);
    }

private:
    explicit stop_token(std::shared_ptr<std::atomic_bool> state_) : state(std::move(state_)) {}

    std::shared_ptr<std::atomic_bool> state;

    friend class jthread;
};

template <typename Callback>
class stop_callback {
public:
    stop_callback(stop_token token, Callback cb) : callback(std::move(cb)) {
        if (token.stop_requested()) {
            callback();
        }
    }

private:
    Callback callback;
};
#endif

class jthread {
public:
    jthread() noexcept = default;

    template <typename F, typename... Args>
    explicit jthread(F&& f, Args&&... args) : stop_state(std::make_shared<std::atomic_bool>(false)) {
        if constexpr (std::is_invocable_v<F, stop_token, Args...>) {
            thread = std::thread(std::forward<F>(f), stop_token{stop_state},
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
            stop_state = std::move(other.stop_state);
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
        if (stop_state) {
            stop_state->store(true, std::memory_order_release);
        }
    }

    [[nodiscard]] stop_token get_stop_token() const noexcept {
        return stop_token{stop_state};
    }

private:
    std::thread thread;
    std::shared_ptr<std::atomic_bool> stop_state;
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
    return !cv.wait_for(lk, token, rel_time, [&] { return token.stop_requested(); });
}

} // namespace Common
