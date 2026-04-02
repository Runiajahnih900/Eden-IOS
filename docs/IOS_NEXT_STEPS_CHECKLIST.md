# iOS Porting Next Steps Checklist

Date: 2026-04-02
Project: Eden iOS bootstrap track

Checklist ini berisi langkah berikutnya. Item yang sudah dikerjakan diberi ceklis.

## A. Fondasi yang sudah selesai

- [x] Perbaikan blocker configure CI iOS (`arm64` parsing di DetectArchitecture + dependency OpenSSL bootstrap) sudah dilakukan.
- [x] Profil build iOS di `CMakeLists.txt` sudah dibuat dan diaktifkan otomatis pada `PLATFORM_IOS`.
- [x] Deteksi platform iOS (`PLATFORM_IOS`) sudah ditambahkan.
- [x] Submodule `src/ios` sudah terhubung ke graph build.
- [x] Target `yuzu-ios-bootstrap` (`eden-ios-bootstrap`) sudah dibuat.
- [x] Bootstrap preflight API (`ios_bootstrap`) sudah tersedia.
- [x] Bridge C ABI (`ios_bootstrap_c_api`) sudah tersedia.
- [x] Bridge Objective-C++ (`ios_bootstrap_objc_bridge`) sudah tersedia.
- [x] Runtime session dasar (`start/stop/tick/state`) sudah tersedia.
- [x] Runtime C ABI + callback event sudah tersedia.
- [x] Runtime ObjC bridge + NotificationCenter event sudah tersedia.
- [x] View-model runtime untuk UI binding sudah tersedia.
- [x] UIKit demo controller untuk uji interaksi sudah tersedia.
- [x] Loader preflight game container (identify + bootable check) sudah terintegrasi.
- [x] Headless `Core::System::Load` path sudah dicoba di alur start runtime.
- [x] Managed background run thread + lifecycle hardening sudah ditambahkan.
- [x] CI GitHub Actions untuk iOS bootstrap smoke build sudah ditambahkan.
- [x] Log perubahan teknis sudah dicatat di `docs/IOS_PORTING_LOG.md`.

## B. Langkah berikutnya (prioritas)

- [ ] Build end-to-end di macOS/Xcode toolchain iOS sampai target bootstrap lulus tanpa warning kritis.
- [ ] Integrasikan project app iOS nyata (wrapper) untuk menjalankan bridge runtime dari aplikasi.
- [ ] Sambungkan rendering path nyata (MoltenVK/surface) dari headless ke output layar.
- [ ] Validasi jalur load game di device iPadOS (jailbreak + TrollStore) dengan 1 game uji.
- [ ] Tambahkan logging runtime yang lebih detail untuk titik gagal (load, run, stop, thread exit).
- [ ] Stabilkan lifecycle app (pause/resume/background/foreground) agar sesi emulasi tidak rusak.

## C. Fitur agar bisa dipakai lebih jauh

- [ ] Integrasi input iOS (touch/controller mapping).
- [ ] Integrasi audio backend iOS yang stabil.
- [ ] Tambahkan manajemen storage/config/shader cache untuk iOS.
- [ ] Tambahkan alur recovery jika run thread crash atau berhenti mendadak.
- [ ] Lakukan baseline profiling performa (CPU/GPU/frame pacing) di device target.

## D. Definisi siap uji "buka game"

- [ ] Aplikasi terpasang di iPad dan bisa start tanpa crash.
- [ ] Pilih path game valid lalu `Start` mengembalikan status sukses.
- [ ] Runtime state menunjukkan sesi aktif konsisten selama beberapa tick.
- [ ] Tidak ada error fatal di report runtime ketika game dibuka.

## E. Definisi siap uji "main game"

- [ ] Render frame tampil stabil di layar (bukan headless-only).
- [ ] Input merespons di in-game.
- [ ] Audio keluar normal tanpa glitch berat.
- [ ] Sesi bertahan >= 10 menit tanpa crash.
- [ ] Minimal 1 judul game bisa masuk gameplay dasar.

---

Catatan update:
- Setelah 1 langkah selesai, ubah `[ ]` menjadi `[x]`.
- Simpan detail teknis tetap di `docs/IOS_PORTING_LOG.md`.