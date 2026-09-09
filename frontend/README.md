# CMS Mobile

Flutter / Dart, Material 3. Sumber aplikasi berada di `lib/`; baca [panduan utama](../README.md) untuk setup backend dan Android.

Folder native Android belum dihasilkan karena Flutter SDK belum tersedia pada PATH saat setup. Jalankan `bootstrap.ps1` setelah menginstal SDK. Flutter memerlukan Dart: ketentuan JavaScript diterapkan pada backend.

Struktur:
- `lib/core`: HTTP client dengan bearer token dan timeout.
- `lib/models`: model user, event, dashboard, tugas.
- `lib/services`: repository API.
- `lib/features/auth`: login.
- `lib/features/events`: Event Saya, detail/dashboard dan daftar tugas.
- `lib/main.dart`: tema, sesi dan navigasi.

Tidak ada data demo atau tombol mutasi semu. Halaman membaca API nyata. Sesi disimpan dalam memori dan dibersihkan saat logout/401. Penyimpanan login lintas restart dapat ditambahkan nanti menggunakan secure storage OS.

Untuk mengambil perubahan server, tarik halaman ke bawah. Pembaruan realtime bukan bagian dari setup ini.

Setup Arch Linux: ikuti [panduan Arch Linux](../README.arch-linux.md), lalu jalankan `bash bootstrap.sh`. Windows tetap menggunakan `bootstrap.ps1`.
