#

Untuk mengekstrak file arsip yang berada di direktori `$HOME` saat posisi terminal Anda sedang membuka direktori (folder) lain, Anda bisa memanfaatkan parameter `-C` (huruf C besar) pada perintah `tar`. Parameter ini berfungsi untuk menentukan target folder tujuan ekstraksi secara spesifik.

Berikut adalah beberapa pilihan cara mengeksekusinya tanpa perlu berpindah direktori:

Pilihan 1: Ekstrak ke Folder Tempat Anda Berada Sekarang

Jika Anda ingin mengekstrak file arsip yang ada di folder home (`$HOME/gawk-4.2.1.tar.xz`), tetapi hasilnya ingin ditaruh di folder aktif Anda saat ini, jalankan perintah berikut:
```bash
tar -xf $HOME/gawk-4.2.1.tar.xz

```

<br>

---

<br>

Pilihan 2: Ekstrak Tetap ke Dalam Folder Home (`$HOME`)

Jika posisi terminal Anda sedang berada di direktori lain (misal: di `/sdcard` atau `/tmp`), tetapi Anda ingin hasil ekstraksinya tetap keluar di dalam folder home ($HOME), gunakan parameter `-C $HOME`:
```bash
tar -xf $HOME/gawk-4.2.1.tar.xz -C $HOME
```
`tar -xf $HOME/gawk-4.2.1.tar.xz -C $HOME`

<br>

---

<br>

Pilihan 3: Ekstrak ke Direktori Spesifik Lainnya

Jika Anda ingin mengekstrak arsip tersebut ke folder tertentu yang sudah Anda siapkan sebelumnya, cukup ganti jalur folder setelah parameter `-C`:
```bash
# Contoh jika ingin diekstrak ke dalam folder bernama 'proyek-lama' di home
mkdir -p $HOME/proyek-lama
tar -xf $HOME/gawk-4.2.1.tar.xz -C $HOME/proyek-lama

```












<br>
