# Hasil pemeriksaan setup

Tanggal: 9 September 2026.

- Node.js v26.5.1, npm 12.0.1.
- Dependensi backend terpasang dan package-lock.json tersedia.
- npm run check: lulus.
- npm test tanpa MySQL: 10 lulus, 1 integrasi dilewati secara eksplisit.
- npm test dengan MySQL 8.4.3 sementara di port 33317: 11 lulus, 0 dilewati. Instance dihentikan setelah tes.
- Integrasi memvalidasi SQL asli, ketua/anggota lintas event, admin, anggota unik, PIC divisi, batas satu lampiran, progres nol/50 persen, isolasi progres antar event, sesi dan expiry.
- Sintaks PowerShell bootstrap: lulus.
- Flutter SDK/Dart tidak terdeteksi. flutter pub get, flutter analyze, build APK dan pengujian UI belum dijalankan. Folder native Android harus dihasilkan dengan frontend/bootstrap.ps1 setelah SDK tersedia.
- Database aplikasi dan akun administrator belum dibuat; kredensial koneksi harus diisi mengikuti README.
