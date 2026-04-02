// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include <cstring>

#include "core/crypto/aes_util.h"
#include "core/crypto/key_manager.h"

namespace Core::Crypto {

struct CipherContext {};

template <typename Key, std::size_t KeySize>
AESCipher<Key, KeySize>::AESCipher([[maybe_unused]] Key key, [[maybe_unused]] Mode mode)
    : ctx(std::make_unique<CipherContext>()) {}

template <typename Key, std::size_t KeySize>
AESCipher<Key, KeySize>::~AESCipher() = default;

template <typename Key, std::size_t KeySize>
void AESCipher<Key, KeySize>::Transcode(const u8* src, std::size_t size, u8* dest,
                                        [[maybe_unused]] Op op) const {
    if (size == 0 || src == dest) {
        return;
    }
    std::memcpy(dest, src, size);
}

template <typename Key, std::size_t KeySize>
void AESCipher<Key, KeySize>::XTSTranscode(const u8* src, std::size_t size, u8* dest,
                                           [[maybe_unused]] std::size_t sector_id,
                                           [[maybe_unused]] std::size_t sector_size,
                                           Op op) {
    Transcode(src, size, dest, op);
}

template <typename Key, std::size_t KeySize>
void AESCipher<Key, KeySize>::SetIV([[maybe_unused]] std::span<const u8> data) {}

template class AESCipher<Key128>;
template class AESCipher<Key256>;

} // namespace Core::Crypto
