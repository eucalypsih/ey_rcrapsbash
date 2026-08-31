# ey_rcrapsbash_rename

q:
```bash
$ ls -al
total 104
drwx------.  8 u0_a301 u0_a301 3452 Aug 27 00:54 .
drwx------. 15 u0_a301 u0_a301 3452 Aug 30 00:13 ..
-rw-------.  1 u0_a301 u0_a301 7160 Aug 25 19:22 .clang-format
-rw-------.  1 u0_a301 u0_a301 6239 Aug 25 19:22 .clang-tidy
-rw-------.  1 u0_a301 u0_a301   47 Aug 25 19:22 .clangd
-rw-------.  1 u0_a301 u0_a301  156 Aug 25 19:22 .codespellrc
drwx------.  6 u0_a301 u0_a301 3452 Aug 26 04:28 .git
drwx------.  4 u0_a301 u0_a301 3452 Aug 25 19:22 .github
-rw-------.  1 u0_a301 u0_a301  161 Aug 25 19:22 .gitignore
-rw-------.  1 u0_a301 u0_a301 1819 Aug 25 19:22 BUILDING.md
-rw-------.  1 u0_a301 u0_a301 1406 Aug 25 22:31 CMakeLists.txt
-rw-------.  1 u0_a301 u0_a301 6079 Aug 25 19:22 CMakePresets.json
-rw-------.  1 u0_a301 u0_a301 1606 Aug 25 19:22 CMakeUserPresets.json
-rw-------.  1 u0_a301 u0_a301  131 Aug 25 19:22 CODE_OF_CONDUCT.md
-rw-------.  1 u0_a301 u0_a301  485 Aug 25 19:22 CONTRIBUTING.md
-rw-------.  1 u0_a301 u0_a301 5682 Aug 25 19:22 HACKING.md
-rw-------.  1 u0_a301 u0_a301  355 Aug 25 19:22 README.md
drwx------.  2 u0_a301 u0_a301 3452 Aug 25 19:22 cmake
-rw-------.  1 u0_a301 u0_a301  381 Aug 25 19:22 conanfile.py
drwx------.  3 u0_a301 u0_a301 3452 Aug 25 19:22 docs
-rw-------.  1 u0_a301 u0_a301 1406 Aug 27 00:54 myp_u1
drwx------.  2 u0_a301 u0_a301 3452 Aug 25 19:22 source
drwx------.  3 u0_a301 u0_a301 3452 Aug 25 19:22 test

```

cara ubah menggunakan mv .* menjadi _.*

<br>

a-ai:
Anda tidak bisa langsung menggunakan perintah `mv .* _.*` karena Linux akan membaca tanda bintang * secara harfiah untuk targetnya, sehingga menyebabkan galat atau salah pindah folder.

Cara paling aman dan benar adalah menggunakan **perulangan (loop)** atau perintah `rename`. Berikut adalah beberapa cara yang bisa Anda gunakan langsung di terminal:

Cara 1: Menggunakan For Loop (Paling Aman & Universal)
Cara ini bekerja di semua jenis terminal (sh, bash, zsh) tanpa perlu menginstal aplikasi tambahan.
```bash
for file in .*; do [ -f "$file" ] && mv "$file" "_$file"; done

```
- `for file in .*`: Mencari semua file/folder yang berawalan titik.
- `[ -f "$file" ]`: Memastikan yang diubah **hanya file**, bukan folder khusus seperti `.` (direktori saat ini) atau `..` (direktori atas).
- `mv "$file" "_$file"`: Mengubah nama file dengan menambahkan underscore `_` di depannya.

Cara 2: Menggunakan Perintah `rename` (Jika Tersedia)
Jika sistem Anda memiliki utilitas `rename` berbasis Perl, Anda bisa menggunakan perintah singkat ini:
```bash
rename 's/^\./_./' .*

```
- **Peringatan**: Sebelum mengeksekusi cara 2, pastikan untuk memeriksa apakah perintah tersebut mengecualikan `.` dan `..` secara otomatis agar struktur direktori Anda tidak rusak. Cara 1 jauh lebih direkomendasikan untuk pemula.

---

qa:
Jika Anda ingin melanjutkan pengelolaan berkas ini, beri tahu saya jika Anda ingin:
- Mengubah nama **folder tersembunyi** juga (seperti `.git` atau `.github`)
- Membuat **skrip otomatis** untuk merapikan proyek CMake ini
- Memulihkan nama file kembali ke **format semula**

<br>

qc:
Mengubah nama **folder tersembunyi** juga (seperti `.git` atau `.github`)

<br>

aa:
Untuk mengubah nama file sekaligus **folder tersembunyi** (seperti `.git`, `.github`, dan `cmake`), kita harus sangat berhati-hati. Kita wajib mengecualikan folder `.` (direktori saat ini) dan `..` (direktori induk) agar sistem tidak rusak atau memindahkan seluruh isi direktori Anda.

Berikut adalah cara paling aman menggunakan perulangan (*looping*) di terminal:

Perintah Eksekusi
```bash
for item in .*; do [ "$item" != "." ] && [ "$item" != ".." ] && mv "$item" "_$item"; done

```
Cara Kerja Perintah Ini:
- `for item in .*`: Membaca semua file dan folder yang diawali dengan titik.
- `[ "$item" != "." ] && [ "$item" != ".." ]`: Memastikan folder saat ini (`.`) dan folder di atasnya (`..`) **diabaikan**.
- `mv "$item" "_$item"`: Mengubah nama file atau folder tersebut dengan menambahkan underscore (`_`) di depannya (contoh: `.git` menjadi `_.git`).

Catatan Penting untuk Proyek Anda:
Karena ini adalah proyek C++/CMake (terlihat dari adanya `CMakeLists.txt` dan `.clang-format`), mengubah nama `.git` atau `.github` akan membuat Git **berhenti melacak perubahan kode** untuk sementara waktu. Jika Anda ingin mengembalikannya normal nanti, Anda cukup mengubah namanya kembali.

---

qa:
Jika Anda tertarik, saya bisa membantu untuk:
- Membuat perintah untuk **mengembalikan semua nama** ke format titik semula (`_.*` menjadi `.*`).
- Menghapus file/folder tertentu yang sudah tidak digunakan di proyek ini.
- Mengetahui cara menyembunyikan kembali folder berawalan `_` agar tidak memenuhi tampilan editor kode Anda.

<br>

qc:
```bash
for item in .*; do [ "$item" != "." ] && [ "$item" != ".." ] && mv "$item" "_$item"; done

```
Membuat perintah untuk **mengembalikan semua nama** ke format titik semula (`_.*` menjadi `.*`).

<br>

aa:
Untuk mengembalikan semua file dan folder yang sudah terlanjur diubah namanya menjadi `_*` kembali ke format titik (`.*`), Anda bisa menggunakan perulangan (*loop*) yang serupa.

Berikut adalah perintah aman untuk mengembalikannya di terminal:
```bash
for item in _.*; do [ -e "$item" ] && mv "$item" "${item#_}"; done

```

Cara Kerja Perintah Ini:
- `for item in _.*`: Mencari semua file dan folder yang namanya diawali dengan `_.` (seperti `_.git`, `_.clang-format`).
- `[ -e "$item" ]`: Memastikan target tersebut benar-benar ada sebelum diproses.
- `${item#_}`: Ini adalah fitur *string manipulation* di Linux untuk **menghapus satu karakter underscore** (`_`) di bagian paling depan nama file, sehingga namanya kembali diawali dengan titik saja.
Setelah Anda menjalankan perintah di atas, Anda bisa mengetik `ls -al` untuk memastikan semua file konfigurasi C++/CMake dan folder Git Anda sudah kembali normal.

---

qa:
Jika Anda tertarik untuk mengelola proyek ini lebih lanjut, saya bisa membantu untuk:
- Membuat **skrip Bash (`.sh`)** agar Anda tidak perlu mengetik perintah panjang ini berulang kali.
- Mengonfigurasi file `.gitignore` agar file-file tertentu tidak ikut masuk ke Git.





















<br>
