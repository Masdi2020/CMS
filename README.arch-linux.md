# Setup CMS pada Arch Linux

Panduan untuk **host Arch Linux x86_64**, frontend Flutter Android, backend Node.js JavaScript, dan **MySQL 8.4 dalam Docker**. Backend dan Flutter dijalankan langsung pada host. Struktur proyek tetap `frontend/` dan `backend/`.

Arch menyediakan MariaDB sebagai implementasi MySQL default. Proyek ini memakai MySQL 8.4 dan collation `utf8mb4_0900_ai_ci`; panduan ini menggunakan image resmi `mysql:8.4` agar sesuai dengan schema yang telah diuji. [ArchWiki MariaDB](https://wiki.archlinux.org/title/MariaDB), [MySQL Official Image](https://hub.docker.com/_/mysql).

Contoh mengasumsikan proyek berada di `~/Projects/CMS`. Ganti dengan lokasi Anda. Jalankan perintah dengan **Bash** (`bash` jika shell utama Anda fish/zsh). Jangan menyalin `node_modules`, `.dart_tool`, `build`, atau `android/local.properties` dari Windows; dependensi dan path SDK perlu dibuat pada host Linux.

## 1. Paket dasar

```bash
sudo pacman -Syu --needed base-devel git curl unzip zip xz python nodejs npm docker docker-compose
sudo systemctl enable --now docker
node --version
npm --version
sudo docker compose version
```

Backend memerlukan Node.js >=22. Perintah Docker dalam panduan menggunakan `sudo`; Flutter dan npm dijalankan sebagai pengguna biasa. [Paket Docker Compose Arch](https://archlinux.org/packages/extra/x86_64/docker-compose/).

## 2. Flutter SDK

Unduh arsip **Flutter stable untuk Linux** dari [halaman instalasi resmi](https://docs.flutter.dev/install/manual), lalu ekstrak ke folder milik pengguna. Ganti nama file pada contoh sesuai arsip yang diunduh:

```bash
mkdir -p "$HOME/develop"
tar -xf "$HOME/Downloads/flutter_linux_VERSI-stable.tar.xz" -C "$HOME/develop"
export PATH="$HOME/develop/flutter/bin:$PATH"
flutter --version
```

Tambahkan baris berikut satu kali ke `~/.bashrc` agar tersedia di terminal baru:

```bash
export PATH="$HOME/develop/flutter/bin:$PATH"
```

Jangan memasang Dart secara terpisah; Flutter menyertakan Dart SDK. Proyek membutuhkan Dart >=3.8. Jika Flutter sudah terpasang, cukup pastikan `command -v flutter` menunjuk instalasi yang benar.

## 3. Android Studio dan SDK

Unduh Android Studio Linux dari [Android Developers](https://developer.android.com/studio/install#linux). Ekstrak arsipnya ke `~/develop`, lalu jalankan:

```bash
"$HOME/develop/android-studio/bin/studio.sh"
```

Selesaikan Setup Wizard. Di SDK Manager, pasang:

- Android SDK Platform yang direkomendasikan Flutter stable.
- Android SDK Build-Tools.
- Android SDK Command-line Tools (latest).
- Android SDK Platform-Tools.
- Android Emulator dan system image jika menggunakan emulator.
- NDK (Side by side) dan CMake sesuai petunjuk setup Flutter.

Gunakan JDK bawaan Android Studio. Contoh berikut memakai lokasi SDK default Linux; sesuaikan dengan lokasi yang ditampilkan SDK Manager:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
flutter config --android-sdk "$ANDROID_HOME"
flutter config --jdk-dir "$HOME/develop/android-studio/jbr"
flutter doctor --android-licenses
flutter doctor -v
```

Tambahkan kedua baris `export` Android ke `~/.bashrc`. Jika menggunakan lokasi Android Studio lain, sesuaikan path `jbr`. Ikuti diagnostik `flutter doctor` sampai Android toolchain siap; kebutuhan target Linux desktop bukan syarat untuk membangun aplikasi Android. [Setup Android Flutter](https://docs.flutter.dev/platform-integration/android/setup).

Untuk emulator, buat perangkat di Android Studio Device Manager dan jalankan. Virtualisasi CPU/KVM harus tersedia untuk akselerasi emulator; lihat [akselerasi emulator Linux](https://developer.android.com/studio/run/emulator-acceleration#vm-linux).

## 4. MySQL 8.4

```bash
cd "$HOME/Projects/CMS/backend"
cp -n .env.mysql.example .env.mysql
chmod 600 .env.mysql
```

Edit `.env.mysql` dengan editor Anda. Ganti `MYSQL_ROOT_PASSWORD` dan `MYSQL_PASSWORD` dengan dua password berbeda. Untuk membuat nilai acak yang mudah dipakai pada environment:

```bash
node -e "console.log(require('node:crypto').randomBytes(24).toString('hex'))"
```

Jalankan dua kali untuk dua password. Lalu:

```bash
sudo docker compose --env-file .env.mysql up -d --wait
sudo docker compose --env-file .env.mysql ps
```

Compose membuat database `cms` dan akun pemilik `cms_owner` pada volume kosong. MySQL hanya dipublikasikan ke loopback host, `127.0.0.1:3306`. Jika port sudah terpakai, ubah `MYSQL_PORT` (misalnya `3307`) dan gunakan nilai yang sama pada `DB_PORT` backend.

Inisialisasi `MYSQL_*` hanya berlaku saat volume database masih kosong. Mengubah file environment setelah inisialisasi tidak mengganti password akun yang sudah ada. Data disimpan pada named volume `cms_mysql_data`. [Perilaku inisialisasi image MySQL](https://hub.docker.com/_/mysql).

## 5. Backend, migrasi, dan administrator

Masih dari direktori `backend`:

```bash
npm ci
cp -n .env.example .env
chmod 600 .env
```

Edit `.env` untuk migrasi awal:

```dotenv
NODE_ENV=development
HOST=0.0.0.0
PORT=3000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=cms
DB_USER=cms_owner
DB_PASSWORD=isi_sama_dengan_MYSQL_PASSWORD
DB_POOL_SIZE=10
SESSION_HOURS=24
```

Gunakan password pemilik dari `.env.mysql` dan port host Compose. Kemudian:

```bash
npm run db:migrate
export CMS_ADMIN_NAME='Administrator'
export CMS_ADMIN_EMAIL='admin@example.com'
read -rsp 'Password admin (minimal 12 karakter, maksimal 72 byte): ' CMS_ADMIN_PASSWORD
printf '\n'
export CMS_ADMIN_PASSWORD
npm run db:admin
unset CMS_ADMIN_PASSWORD
```

Tidak ada password admin default. Database baru belum berisi event; halaman Event Saya akan kosong. Migrasi yang berhasil dicatat di `schema_migrations`.

## 6. Akun runtime dengan hak EXECUTE

Gunakan akun pemilik hanya untuk migrasi dan bootstrap admin. Untuk API, buat `cms_app` menggunakan contoh khusus Docker:

```bash
mkdir -p .local
cp -n database/runtime-user.docker.sql.example .local/runtime-user.sql
chmod 600 .local/runtime-user.sql
```

Edit `.local/runtime-user.sql` dan ganti placeholder password dengan password runtime baru. File ini diabaikan Git. Salin ke container dan buka MySQL memakai password root dari `.env.mysql`:

```bash
sudo docker compose --env-file .env.mysql cp .local/runtime-user.sql mysql:/tmp/cms-runtime-user.sql
sudo docker compose --env-file .env.mysql exec mysql mysql -uroot -p
```

Di prompt MySQL:

```sql
SOURCE /tmp/cms-runtime-user.sql;
SHOW GRANTS FOR 'cms_app'@'%';
exit
```

Contoh Docker menggunakan host `%` karena koneksi dari backend di host melewati jaringan bridge container. Port publik database tetap dibatasi ke loopback. Contoh `runtime-user.sql.example` lama memakai host `127.0.0.1` untuk MySQL native.

Setelah berhasil, ubah `.env`:

```dotenv
DB_USER=cms_app
DB_PASSWORD=isi_password_runtime_baru
```

Akun runtime hanya mendapat EXECUTE pada 11 procedure runtime. Procedure bootstrap `sp_user_create` tidak diberikan. Jangan menghapus akun `cms_owner`: procedure berjalan dengan SQL SECURITY DEFINER milik akun pembuatnya. Saat migrasi berikutnya, gunakan kembali kredensial pemilik lalu kembalikan kredensial runtime.

## 7. Jalankan API

```bash
npm run dev
```

Di terminal lain:

```bash
curl --fail http://127.0.0.1:3000/api/health
```

Hasil yang diharapkan: `{"data":{"status":"ok"}}`. Jika 503, periksa kredensial, port, migrasi, dan hak EXECUTE. Detail startup MySQL:

```bash
cd "$HOME/Projects/CMS/backend"
sudo docker compose --env-file .env.mysql logs --tail=80 mysql
```

## 8. Bootstrap dan jalankan Flutter

```bash
cd "$HOME/Projects/CMS/frontend"
bash bootstrap.sh
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Skrip menghasilkan scaffold Android jika belum ada, mempertahankan sumber Dart, memasang izin INTERNET, mengaktifkan HTTP hanya untuk build debug, lalu menjalankan `flutter pub get` dan `flutter analyze`. Skrip memerlukan `flutter` dan `python3` di PATH; tidak memasang SDK atau mengubah paket OS. Jalankan ulang bila perlu mengambil dependensi atau memperbarui konfigurasi manifest.

Jika memindahkan proyek dari Windows dengan scaffold Android yang sudah ada, gunakan file SDK lokal Linux yang dihasilkan Flutter dan pastikan wrapper Gradle dapat dieksekusi:

```bash
chmod +x android/gradlew
```

### HP fisik melalui USB

Aktifkan Developer options dan USB debugging, hubungkan perangkat, lalu setujui dialog otorisasi pada HP.

```bash
adb devices
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

Jika USB tidak terdeteksi, periksa aturan udev dan akses perangkat mengikuti [Android Developers: menjalankan aplikasi pada perangkat](https://developer.android.com/studio/run/device). Jangan menjalankan Flutter sebagai root.

### HP melalui Wi-Fi

Gunakan alamat LAN komputer pada jaringan yang sama:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api
```

Ganti alamat IP sesuai komputer. Backend menggunakan `HOST=0.0.0.0`. Jika firewall aktif, izinkan TCP 3000 untuk jaringan lokal. Database tetap diakses oleh backend melalui loopback.

### Build APK

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Hasil: `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Alamat `10.0.2.2` khusus emulator; ganti alamat sebelum membuat APK debug untuk HP. Build release memerlukan URL HTTPS serta konfigurasi signing sebelum distribusi.

## 9. Pemeriksaan dan penggunaan berikutnya

```bash
cd "$HOME/Projects/CMS/backend"
npm run check
npm test
cd ../frontend
flutter analyze
```

Tes MySQL opsional sengaja dilewati tanpa `TEST_MYSQL_PORT`. Gunakan instance database disposable terpisah untuk tes integrasi, bukan volume aplikasi.

Untuk sesi kerja berikutnya, jalankan MySQL lalu API dan Flutter seperti langkah di atas. Menghentikan MySQL tanpa menghapus data:

```bash
cd "$HOME/Projects/CMS/backend"
sudo docker compose --env-file .env.mysql stop
```

Menjalankan kembali:

```bash
sudo docker compose --env-file .env.mysql up -d --wait
```

Panduan dan skrip ditulis dari workspace Windows. Validasi sintaks tersedia, tetapi instalasi paket Arch, Docker Compose, dan build Android belum diuji langsung pada host Arch Linux.
