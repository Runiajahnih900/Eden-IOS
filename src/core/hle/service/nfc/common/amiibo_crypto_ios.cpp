// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

// SPDX-FileCopyrightText: Copyright 2022 yuzu Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include <array>
#include <cstring>
#include <vector>

#include "common/fs/file.h"
#include "common/fs/fs.h"
#include "common/fs/path_util.h"
#include "common/logging.h"
#include "core/hle/service/nfc/common/amiibo_crypto.h"

namespace Service::NFP::AmiiboCrypto {

bool IsAmiiboValid(const EncryptedNTAG215File& ntag_file) {
    const auto& amiibo_data = ntag_file.user_memory;

    constexpr u8 ct = 0x88;
    if ((ct ^ ntag_file.uuid.part1[0] ^ ntag_file.uuid.part1[1] ^ ntag_file.uuid.part1[2]) !=
        ntag_file.uuid.crc_check1) {
        return false;
    }
    if ((ntag_file.uuid.part2[0] ^ ntag_file.uuid.part2[1] ^ ntag_file.uuid.part2[2] ^
         ntag_file.uuid.nintendo_id) != ntag_file.uuid_crc_check2) {
        return false;
    }

    if (ntag_file.static_lock != 0xE00F) {
        return false;
    }
    if (ntag_file.compatibility_container != 0xEEFF10F1U) {
        return false;
    }
    if (amiibo_data.model_info.tag_type != NFC::PackedTagType::Type2) {
        return false;
    }
    if ((ntag_file.dynamic_lock & 0xFFFFFF) != 0x0F0001U) {
        return false;
    }
    if (ntag_file.CFG0 != 0x04000000U) {
        return false;
    }
    if (ntag_file.CFG1 != 0x5F) {
        return false;
    }
    return true;
}

bool IsAmiiboValid(const NTAG215File& ntag_file) {
    return IsAmiiboValid(EncodedDataToNfcData(ntag_file));
}

NTAG215File NfcDataToEncodedData(const EncryptedNTAG215File& nfc_data) {
    NTAG215File encoded_data{};

    encoded_data.uid = nfc_data.uuid;
    encoded_data.uid_crc_check2 = nfc_data.uuid_crc_check2;
    encoded_data.internal_number = nfc_data.internal_number;
    encoded_data.static_lock = nfc_data.static_lock;
    encoded_data.compatibility_container = nfc_data.compatibility_container;
    encoded_data.hmac_data = nfc_data.user_memory.hmac_data;
    encoded_data.constant_value = nfc_data.user_memory.constant_value;
    encoded_data.write_counter = nfc_data.user_memory.write_counter;
    encoded_data.amiibo_version = nfc_data.user_memory.amiibo_version;
    encoded_data.settings = nfc_data.user_memory.settings;
    encoded_data.owner_mii = nfc_data.user_memory.owner_mii;
    encoded_data.application_id = nfc_data.user_memory.application_id;
    encoded_data.application_write_counter = nfc_data.user_memory.application_write_counter;
    encoded_data.application_area_id = nfc_data.user_memory.application_area_id;
    encoded_data.application_id_byte = nfc_data.user_memory.application_id_byte;
    encoded_data.unknown = nfc_data.user_memory.unknown;
    encoded_data.mii_extension = nfc_data.user_memory.mii_extension;
    encoded_data.unknown2 = nfc_data.user_memory.unknown2;
    encoded_data.register_info_crc = nfc_data.user_memory.register_info_crc;
    encoded_data.application_area = nfc_data.user_memory.application_area;
    encoded_data.hmac_tag = nfc_data.user_memory.hmac_tag;
    encoded_data.model_info = nfc_data.user_memory.model_info;
    encoded_data.keygen_salt = nfc_data.user_memory.keygen_salt;
    encoded_data.dynamic_lock = nfc_data.dynamic_lock;
    encoded_data.CFG0 = nfc_data.CFG0;
    encoded_data.CFG1 = nfc_data.CFG1;
    encoded_data.password = nfc_data.password;

    return encoded_data;
}

EncryptedNTAG215File EncodedDataToNfcData(const NTAG215File& encoded_data) {
    EncryptedNTAG215File nfc_data{};

    nfc_data.uuid = encoded_data.uid;
    nfc_data.uuid_crc_check2 = encoded_data.uid_crc_check2;
    nfc_data.internal_number = encoded_data.internal_number;
    nfc_data.static_lock = encoded_data.static_lock;
    nfc_data.compatibility_container = encoded_data.compatibility_container;
    nfc_data.user_memory.hmac_data = encoded_data.hmac_data;
    nfc_data.user_memory.constant_value = encoded_data.constant_value;
    nfc_data.user_memory.write_counter = encoded_data.write_counter;
    nfc_data.user_memory.amiibo_version = encoded_data.amiibo_version;
    nfc_data.user_memory.settings = encoded_data.settings;
    nfc_data.user_memory.owner_mii = encoded_data.owner_mii;
    nfc_data.user_memory.application_id = encoded_data.application_id;
    nfc_data.user_memory.application_write_counter = encoded_data.application_write_counter;
    nfc_data.user_memory.application_area_id = encoded_data.application_area_id;
    nfc_data.user_memory.application_id_byte = encoded_data.application_id_byte;
    nfc_data.user_memory.unknown = encoded_data.unknown;
    nfc_data.user_memory.mii_extension = encoded_data.mii_extension;
    nfc_data.user_memory.unknown2 = encoded_data.unknown2;
    nfc_data.user_memory.register_info_crc = encoded_data.register_info_crc;
    nfc_data.user_memory.application_area = encoded_data.application_area;
    nfc_data.user_memory.hmac_tag = encoded_data.hmac_tag;
    nfc_data.user_memory.model_info = encoded_data.model_info;
    nfc_data.user_memory.keygen_salt = encoded_data.keygen_salt;
    nfc_data.dynamic_lock = encoded_data.dynamic_lock;
    nfc_data.CFG0 = encoded_data.CFG0;
    nfc_data.CFG1 = encoded_data.CFG1;
    nfc_data.password = encoded_data.password;

    return nfc_data;
}

HashSeed GetSeed(const NTAG215File& data) {
    HashSeed seed{
        .magic = data.write_counter,
        .padding = {},
        .uid_1 = data.uid,
        .uid_2 = data.uid,
        .keygen_salt = data.keygen_salt,
    };
    return seed;
}

std::vector<u8> GenerateInternalKey(const InternalKey& key, const HashSeed& seed) {
    const std::size_t seed_part1_len = sizeof(key.magic_bytes) - key.magic_length;
    const std::size_t string_size = key.type_string.size();

    std::vector<u8> output;
    output.reserve(string_size + seed_part1_len + key.magic_length + 2 * sizeof(NFP::TagUuid) +
                   sizeof(seed.keygen_salt));

    output.insert(output.end(), reinterpret_cast<const u8*>(key.type_string.data()),
                  reinterpret_cast<const u8*>(key.type_string.data()) + string_size);

    const auto* seed_ptr = reinterpret_cast<const u8*>(&seed);
    output.insert(output.end(), seed_ptr, seed_ptr + seed_part1_len);

    output.insert(output.end(), key.magic_bytes.begin(), key.magic_bytes.begin() + key.magic_length);

    std::array<u8, sizeof(NFP::TagUuid)> seed_uuid{};
    std::memcpy(seed_uuid.data(), &seed.uid_1, sizeof(NFP::TagUuid));
    output.insert(output.end(), seed_uuid.begin(), seed_uuid.end());
    std::memcpy(seed_uuid.data(), &seed.uid_2, sizeof(NFP::TagUuid));
    output.insert(output.end(), seed_uuid.begin(), seed_uuid.end());

    for (std::size_t i = 0; i < sizeof(seed.keygen_salt); i++) {
        output.emplace_back(static_cast<u8>(seed.keygen_salt[i] ^ key.xor_pad[i]));
    }

    return output;
}

void CryptoInit(CryptoCtx& ctx, EVP_MAC_CTX* hmac_ctx, const HmacKey& hmac_key,
                std::span<const u8> seed) {
    (void)ctx;
    (void)hmac_ctx;
    (void)hmac_key;
    (void)seed;
}

void CryptoStep(CryptoCtx& ctx, EVP_MAC_CTX* hmac_ctx, DrgbOutput& output) {
    (void)ctx;
    (void)hmac_ctx;
    output.fill(0);
}

DerivedKeys GenerateKey(const InternalKey& key, const NTAG215File& data) {
    (void)key;
    (void)data;
    return {};
}

void Cipher(const DerivedKeys& keys, const NTAG215File& in_data, NTAG215File& out_data) {
    (void)keys;
    out_data = in_data;
}

bool LoadKeys(InternalKey& locked_secret, InternalKey& unfixed_info) {
    const auto yuzu_keys_dir = Common::FS::GetEdenPath(Common::FS::EdenPath::KeysDir);

    const Common::FS::IOFile keys_file{yuzu_keys_dir / "key_retail.bin",
                                       Common::FS::FileAccessMode::Read,
                                       Common::FS::FileType::BinaryFile};

    if (!keys_file.IsOpen()) {
        LOG_ERROR(Service_NFP, "Failed to open key file");
        return false;
    }

    if (keys_file.Read(unfixed_info) != 1) {
        LOG_ERROR(Service_NFP, "Failed to read unfixed_info");
        return false;
    }
    if (keys_file.Read(locked_secret) != 1) {
        LOG_ERROR(Service_NFP, "Failed to read locked-secret");
        return false;
    }

    return true;
}

bool IsKeyAvailable() {
    const auto yuzu_keys_dir = Common::FS::GetEdenPath(Common::FS::EdenPath::KeysDir);
    return Common::FS::Exists(yuzu_keys_dir / "key_retail.bin");
}

bool DecodeAmiibo(const EncryptedNTAG215File& encrypted_tag_data, NTAG215File& tag_data) {
    InternalKey locked_secret{};
    InternalKey unfixed_info{};

    if (!LoadKeys(locked_secret, unfixed_info)) {
        return false;
    }

    (void)locked_secret;
    (void)unfixed_info;
    tag_data = NfcDataToEncodedData(encrypted_tag_data);
    return IsAmiiboValid(tag_data);
}

bool EncodeAmiibo(const NTAG215File& tag_data, EncryptedNTAG215File& encrypted_tag_data) {
    InternalKey locked_secret{};
    InternalKey unfixed_info{};

    if (!LoadKeys(locked_secret, unfixed_info)) {
        return false;
    }

    (void)locked_secret;
    (void)unfixed_info;
    encrypted_tag_data = EncodedDataToNfcData(tag_data);
    return IsAmiiboValid(encrypted_tag_data);
}

} // namespace Service::NFP::AmiiboCrypto
