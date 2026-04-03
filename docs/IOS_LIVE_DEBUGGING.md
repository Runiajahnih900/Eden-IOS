# iOS Live Debugging (iPad + Komputer Kerja -> VS Code Terminal)

Date: 2026-04-02

Dokumen ini untuk menampilkan log runtime dari iPad dan komputer kerja secara live ke terminal workspace ini.

## 1) Jalankan server log di Windows

Dari root repo jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File tools/windows/ios-live-log-server.ps1 -Port 8787 -Path /log/
```

Catatan:
- Script terbaru tidak memakai parameter `-HostToken`.
- Script terbaru tidak butuh URL ACL admin untuk start.

## 2) Pastikan iPad dan komputer kerja terhubung Tailscale

- Pastikan perangkat `komputer-kerja` dan `muhammads-ipad` statusnya `Connected` di Tailscale.
- Gunakan IP Tailscale komputer kerja sebagai endpoint log.
- Contoh dari daftar perangkat saat ini: `100.104.116.72` (komputer-kerja).

## 3) Set endpoint log dari sisi iOS

Endpoint contoh untuk iPad:

```text
http://100.104.116.72:8787/log/
```

Pilihan cara set endpoint dari app iOS:

- Via IPA shell UI: isi field `Live log endpoint` lalu tekan `Aktifkan Live Logging`.
- Tombol `Kirim Ping` mengirim event uji langsung ke server.
- Via kode wrapper:

```objc
[EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:@"http://192.168.1.10:8787/log/"];
[EdenIOSRuntimeBridge setEventNotificationsEnabled:YES];
```

## 4) Log dari iPad dan komputer kerja dalam satu terminal

Saat `Start`, `Tick`, `Stop`, atau event runtime lain terjadi, terminal Windows akan menampilkan baris log real-time beserta report.
Server menerima banyak source sekaligus, jadi log iPad dan komputer kerja bisa tampil bersamaan.

Pada IPA shell terbaru, event berikut juga otomatis terkirim:
- `app_open`
- `heartbeat` periodik (default 12 detik)
- `set_log_endpoint`
- `manual_ping`
- `update_available` saat feed update mendeteksi versi lebih baru

## 4b) Live update notifier (notifikasi update otomatis)

Di UI app, field `URL update feed` bisa diisi endpoint JSON update.
Default saat ini: GitHub Releases repo ini.

Perilaku:
- App cek update otomatis (default 90 detik) + bisa manual via `Cek Update Sekarang`.
- Jika versi feed lebih baru dari versi app, app tampilkan popup notifikasi update.
- Jika feed menyediakan `html_url`, tombol `Buka Link Update` akan membuka halaman update.

## 5) Uji cepat koneksi (opsional)

Sebelum tes dari iPad, kirim payload contoh dari komputer kerja:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8787/log/ -ContentType "application/json" -Body '{"event":"ping","sessionID":1,"tickCount":0,"running":false,"report":"hello"}'
```

Kalau server menerima, terminal akan menampilkan log `event=ping`.

## Catatan

- Chat ini tidak bisa auto-stream log perangkat secara langsung tanpa perantara; mekanisme ini membuat log tampil live di terminal workspace sehingga bisa dipakai untuk live debugging.
- Untuk kestabilan, gunakan jaringan lokal yang stabil dan hindari VPN saat sesi debug.
