# iOS Live Debugging (iPad -> VS Code Terminal)

Date: 2026-04-02

Dokumen ini untuk menampilkan log runtime dari iPad secara live ke terminal workspace ini.

## 1) Jalankan server log di Windows

Dari root repo jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File tools/windows/ios-live-log-server.ps1 -Port 8787 -Path /log/
```

Jika muncul error "Access is denied", jalankan PowerShell as Administrator lalu:

```powershell
netsh http add urlacl url=http://+:8787/log/ user=$env:USERNAME
```

Setelah itu jalankan ulang server.

## 2) Pastikan iPad dan laptop satu jaringan

- iPad dan laptop harus berada pada LAN/Wi-Fi yang sama.
- Ambil IP laptop (contoh `192.168.1.10`).

## 3) Set endpoint log dari sisi iOS

Endpoint contoh:

```text
http://192.168.1.10:8787/log/
```

Pilihan cara set endpoint:

- Via demo UI: isi field `Live log endpoint` lalu tekan `Set Live Log`.
- Via kode wrapper:

```objc
[EdenIOSRuntimeBridge setRemoteDebugLogEndpoint:@"http://192.168.1.10:8787/log/"];
[EdenIOSRuntimeBridge setEventNotificationsEnabled:YES];
```

## 4) Mulai runtime dan lihat log live

Saat `Start`, `Tick`, `Stop`, atau event runtime lain terjadi, terminal Windows akan menampilkan baris log real-time beserta report.

## 5) Uji cepat koneksi (opsional)

Sebelum tes dari iPad, kirim payload contoh dari laptop:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8787/log/ -ContentType "application/json" -Body '{"event":"ping","sessionID":1,"tickCount":0,"running":false,"report":"hello"}'
```

Kalau server menerima, terminal akan menampilkan log `event=ping`.

## Catatan

- Chat ini tidak bisa auto-stream log perangkat secara langsung tanpa perantara; mekanisme ini membuat log tampil live di terminal workspace sehingga bisa dipakai untuk live debugging.
- Untuk kestabilan, gunakan jaringan lokal yang stabil dan hindari VPN saat sesi debug.
