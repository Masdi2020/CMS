# Committee Management System (CMS)

Setup awal berdasarkan **CMS_Dokumen_MVP.docx versi 1.1, September 2026**.

```text
CMS/
  frontend/   Flutter / Dart untuk Android
  backend/    REST API Node.js / JavaScript + MySQL stored procedures
```

Alur koneksi: **Flutter -> HTTP(S) /api -> Express -> CALL stored procedure -> MySQL**.
Flutter dapat mengakses backend melalui API. Aplikasi mobile tidak menyimpan kredensial database.

## Cakupan setup

Sudah disiapkan:

- Flutter: login, Event Saya, seluruh event untuk admin, detail event, dashboard, daftar tugas, profil sederhana, logout, loading/error/empty state dan refresh.
- JavaScript: Express, validasi input, autentikasi bearer token yang dapat dicabut, pembatasan percobaan login, middleware akses per event, respons JSON, konfigurasi environment.
- MySQL: delapan tabel untuk seluruh modul MVP, migrasi berversi, 12 stored procedure untuk alur awal, bootstrap administrator.
- Token hanya disimpan dalam memori Flutter; aplikasi yang dibuka ulang meminta login. Database hanya menyimpan SHA-256 token; password menggunakan bcrypt.
- Semua akses data runtime menggunakan procedure dengan parameter terikat. SQL langsung hanya dipakai untuk migrasi dan fixture pengujian.

**Ini fondasi pengembangan, belum implementasi lengkap seluruh fitur MVP.** CRUD pengguna/event/divisi/anggota/tugas, penetapan ketua, perubahan status, upload/download lampiran, dan komentar belum diekspos melalui API/UI. Tabelnya sudah tersedia. Detail endpoint aktif dan pekerjaan berikutnya ada di [backend/README.md](backend/README.md).

## Panduan per sistem operasi

- **Arch Linux:** [README.arch-linux.md](README.arch-linux.md), termasuk MySQL Docker dan bootstrap Bash.
- **Windows:** ikuti langkah PowerShell di bawah.

## Prasyarat

- Node.js 22+ (disarankan versi LTS yang didukung).
- MySQL 8.4 LTS.
- Flutter stable dengan Dart >=3.8, Android SDK, Android Studio/emulator atau perangkat Android.
- Flutter SDK harus tersedia sebagai perintah `flutter`. Panduan resmi: [instalasi Flutter](https://docs.flutter.dev/install/manual) dan [setup Android](https://docs.flutter.dev/platform-integration/android/setup).
- Express dan mysql2 mengikuti [Express 5](https://expressjs.com/en/guide/migrating-5/) dan [mysql2 Promise API](https://sidorares.github.io/node-mysql2/docs/documentation/promise-wrapper).

## 1. Backend dan database

```powershell
cd D:\Dimas\CMS\backend
npm.cmd ci
Copy-Item .env.example .env
```

Buat database kosong menggunakan akun pemilik database melalui MySQL CLI atau GUI:

```sql
CREATE DATABASE cms CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

Isi `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` pada `.env`.
Untuk migrasi dan bootstrap admin, gunakan akun pemilik database yang memiliki hak CREATE/ALTER tabel, CREATE ROUTINE, dan DML. Jangan memakai akun runtime yang hanya memiliki EXECUTE.

```powershell
npm.cmd run db:migrate
$env:CMS_ADMIN_NAME = 'Administrator'
$env:CMS_ADMIN_EMAIL = 'admin@example.com'
$adminPassword = Read-Host 'Password admin (minimal 12 karakter, maksimal 72 byte)' -AsSecureString
$env:CMS_ADMIN_PASSWORD = [System.Net.NetworkCredential]::new('', $adminPassword).Password
npm.cmd run db:admin
Remove-Item Env:CMS_ADMIN_PASSWORD
```

Tidak ada akun/password default. Email yang sudah ada tidak ditimpa. Migrasi tidak mengisi contoh event; Event Saya awalnya kosong.

Setelah migrasi, sesuaikan dan jalankan [runtime-user.sql.example](backend/database/runtime-user.sql.example) sebagai pemilik DB, kemudian ubah `.env` ke akun `cms_app` tersebut. File contoh hanya memberikan EXECUTE pada procedure runtime, bukan akses langsung tabel atau procedure bootstrap admin.

```powershell
npm.cmd run dev
Invoke-RestMethod http://localhost:3000/api/health
```

Health bernilai `ok` hanya jika procedure database dapat diakses. Jalankan MySQL sebelum API digunakan.

## 2. Flutter Android

```powershell
cd D:\Dimas\CMS\frontend
flutter doctor
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Skrip bootstrap menghasilkan folder native Android dari template SDK Flutter lokal, menambahkan izin INTERNET dan HTTP khusus debug, mengambil dependensi, lalu menjalankan analyzer. Sumber Dart yang sudah ada dipertahankan. Skrip tidak mengunduh atau memasang SDK Flutter/Android.

- Android emulator: `10.0.2.2` mengarah ke komputer host.
- HP fisik: gunakan alamat LAN komputer, misalnya `http://192.168.1.20:3000/api`. HP dan komputer harus berada pada jaringan yang sama; izinkan port API pada firewall jaringan lokal bila diperlukan.
- Alternatif USB: `adb reverse tcp:3000 tcp:3000`, lalu gunakan `http://127.0.0.1:3000/api`.
- Release: gunakan alamat **HTTPS**. Pengecualian HTTP hanya dipasang pada manifest debug.
- `API_BASE_URL` bukan kredensial; jangan memasukkan user/password MySQL ke Flutter.
- Target awal Android sesuai dokumen. Scaffold native iOS belum dibuat.

## Pemeriksaan

```powershell
cd D:\Dimas\CMS\backend
npm.cmd run check
npm.cmd test
cd ..\frontend
flutter analyze
```

Tes default memeriksa autentikasi, pencabutan sesi, akses event, validasi, dan pemanggilan procedure terparameterisasi. Tes MySQL riil hanya berjalan jika `TEST_MYSQL_PORT` diisi; gunakan instance disposable karena tes membuat dan menghapus schema unik `cms_test_*` miliknya sendiri.

## Aturan domain yang dipertahankan

- `users.role` hanya `admin/user`; ketua ditentukan oleh `events.ketua_panitia_id`.
- Anggota dapat mengikuti banyak event dan banyak divisi; pasangan `division_id + user_id` unik.
- PIC tugas harus merupakan anggota divisi tugas, dijaga oleh foreign key gabungan.
- Maksimal satu lampiran per tugas, file **atau** URL, dijaga UNIQUE dan CHECK.
- Prioritas awal: `low/medium/high`; status: `to_do/in_progress/done`.
- Total anggota dashboard menghitung orang unik, bukan jumlah penugasan divisi.
- Progres = Done / total tugas x 100%; nol tugas menghasilkan 0%.
- DATETIME disimpan/dibaca dalam UTC; tanggal event adalah tanggal kalender.
- Anggota dapat membaca ringkasan dan tugas pada event yang diikuti. Kebijakan perubahan tugas perlu diterapkan saat endpoint mutasi dibangun.
