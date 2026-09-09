# CMS Backend

JavaScript ESM, Express 5, mysql2, MySQL 8.4 stored procedures.

## Struktur

- `src/config`: konfigurasi tervalidasi.
- `src/database`: connection pool dan allowlist pemanggilan procedure.
- `src/services`: autentikasi dan manajemen sesi.
- `src/middleware`: autentikasi dan otorisasi kontekstual event.
- `src/routes`: kontrak HTTP alur awal.
- `database/migrations`: schema dan procedure berversi.
- `scripts`: migrasi, bootstrap admin, pemeriksaan sintaks.
- `test`: tes API dan integrasi MySQL opsional.
- `storage`: tempat yang disiapkan untuk file privat; belum ada endpoint upload.

## Endpoint yang aktif

Semua endpoint diawali `/api`. Selain health/login, kirim `Authorization: Bearer <token>`.

| Method | Path | Perilaku |
| --- | --- | --- |
| GET | /health | Memeriksa koneksi dan procedure MySQL |
| POST | /login | Body JSON email/password, menghasilkan token + user |
| POST | /logout | Mencabut token saat ini, 204 |
| GET | /me | Profil sesi aktif |
| GET | /events | Semua event bagi admin; event yang diikuti untuk user |
| GET | /users/:id/events | Event Saya milik sendiri; admin dapat melihat milik user lain |
| GET | /events/:id | Detail event yang dapat diakses |
| GET | /events/:id/dashboard | Total divisi, anggota unik, tugas dan progres |
| GET | /events/:id/divisions | Daftar divisi event |
| GET | /events/:id/members | Daftar penugasan anggota event |
| GET | /events/:id/tasks | Daftar tugas event |

Daftar divisi/anggota/tugas menggunakan route bersarang agar konteks event eksplisit. Dokumen mengusulkan `/divisions`, `/members`, `/tasks`; alias query parameter untuk bentuk tersebut belum dibuat.

Respons sukses: `{ "data": ... }`. Error: `{ "message": "...", "errors": [...] }` (errors hanya untuk validasi).
ID BIGINT dikirim sebagai string supaya tidak kehilangan presisi di JavaScript. Nilai COUNT/DECIMAL dapat berupa angka atau string dari driver; model Flutter menormalisasinya.

Login:
```http
POST /api/login
Content-Type: application/json

{"email":"admin@example.com","password":"password-yang-Anda-buat"}
```

Token acak 256 bit, hash SHA-256 di tabel sessions, kedaluwarsa 24 jam secara default. Logout menghapus sesi dari DB. Header bearer dan password tidak dicatat ke log. Rate limit berbasis memori cocok untuk setup satu proses; multi-instance memerlukan store bersama dan konfigurasi proxy yang sesuai.

## Migrasi

Jalankan dari direktori backend. `npm run db:migrate` mengambil berkas SQL secara berurutan dan mencatatnya pada `schema_migrations`. Tidak membuat database atau akun MySQL secara otomatis. DDL MySQL tidak transaksional; jika migrasi gagal sebagian, periksa objek yang sudah tercipta sebelum menjalankan ulang. Jangan mengubah migrasi yang sudah diterapkan; tambahkan file berikutnya.

Gunakan pemilik DB saat migrasi dan bootstrap admin. Runtime hanya perlu hak EXECUTE sesuai file contoh. Procedure memakai SQL SECURITY DEFINER; akun pembuat procedure harus tetap ada dan memiliki akses yang diperlukan.

## Tahap implementasi setelah setup

1. CRUD pengguna khusus admin; nama, email, nomor HP, password hash.
2. CRUD event dan penetapan/penggantian ketua khusus admin; ketua hanya mengelola event yang dipimpin.
3. CRUD divisi dan keanggotaan oleh admin/ketua event. Hapus/pindah anggota yang masih menjadi PIC harus ditolak sampai tugas dialihkan.
4. CRUD tugas oleh pengelola event; perubahan status oleh PIC tugas atau pengelola. Semua referensi divisi/PIC harus divalidasi dalam konteks event.
5. Lampiran tunggal: validasi isi JPG/PNG/PDF, batas ukuran, penyimpanan privat, download terautentikasi; URL hanya HTTP(S). Penggantian bukti perlu mengganti record dan membersihkan file lama.
6. Komentar dan detail tugas, dengan pemeriksaan akses event dan author.
7. Form Flutter untuk setiap mutasi di atas, lalu pengujian UI Android.

Penghapusan event/divisi harus memakai procedure transaksi yang menghapus tugas sebelum keanggotaan/divisi; foreign key PIC menggunakan RESTRICT. Tidak ada endpoint penghapusan pada setup ini.

Chat, push notification, kalender, absensi QR, keuangan, sponsorship, inventory dan ekspor tetap di luar cakupan MVP sesuai dokumen.

Setup Arch Linux dan MySQL 8.4 melalui Docker tersedia pada [panduan Arch Linux](../README.arch-linux.md). Konfigurasi Compose berada di `compose.yaml`, dengan environment terpisah `.env.mysql`.
