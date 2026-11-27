


Penting: Posisi direktori aktif di terminal Anda saat ini (Prived Working Directory) tidak akan berubah setelah seluruh rangkaian perintah ini selesai dieksekusi.

Flag `--no-cone` hanya digunakan di awal saat Anda menjalankan perintah `set` untuk menentukan mode repositori Anda. Sekali repositori Anda sudah diatur ke mode non-cone (seperti yang Anda lakukan di perintah sebelumnya), Git akan **otomatis mengingat mode tersebut**.

Jadi, untuk menambahkan folder `rust-lang`, Anda cukup menjalankan perintah berikut:
```bash
git sparse-checkout add 'rust-lang/'

```

Perintah `git checkout main` di akhir baris Anda dijalankan saat Git belum **memiliki data objek file (blobs)** yang diunduh secara lokal akibat efek dari kombinasi *partial clone* (`--filter=blob:none`) dan penundaan ekstraksi awal (`--no-checkout`). Ketika Anda langsung berpindah ke branch main, Git mendeteksi indeks kerja Anda sudah "berada di `main`" namun tidak memicu proses penarikan ulang (*checkout*) ulang untuk memunculkan file secara fisik.

Berikut adalah dua cara mudah untuk memunculkannya:

## Cara 1: Menggunakan Perintah `git checkout` Tambahan
Cara termudah setelah menjalankan kode Anda adalah dengan memaksa Git untuk melakukan *checkout* ulang pada direktori saat ini agar file yang masuk dalam aturan *sparse-checkout* (`README.md`) segera diekstraksi ke penyimpanan internal Termux:
```bash
git -C "$repo_path" checkout main --
# ATAU jika masih kosong, paksa baca pohon repositori:
git -C "$repo_path" read-tree -mu HEAD

```

## Cara 2: Memperbaiki Rangkaian Kode Anda (Sangat Disarankan)
Agar file langsung muncul secara otomatis dalam satu kali jalan tanpa perlu perintah tambahan, hapus flag `--no-checkout`. Anda tidak memerlukan flag tersebut karena `sparse-checkout set` sudah membatasi file mana saja yang diunduh.

```bash
owner="eucalypsih"; repo="ey_rcrapsbash"; repo_path="/data/data/com.termux/files/home/${repo}"

# 1. Clone dengan filter tanpa mematikan checkout otomatis
git clone -q --filter=blob:none git@github.com:${owner}/${repo}.git "$repo_path" && sleep 0.5

# 2. Atur batasan file spesifik (Gunakan penulisan tanpa garis miring jika di root)
git -C "$repo_path" sparse-checkout set --no-cone "README.md" && sleep 0.5

# 3. Terapkan pembaruan working tree
git -C "$repo_path" checkout main

```

<br>

---

<br>

Berikut adalah versi yang disederhanakan dengan tetap mempertahankan penggunaan flag `-C` dan jeda `sleep`.

Untuk menghilangkan pengulangan kata `git -C` berkali-kali, kita menggunakan struktur perulangan `for` dalam Bash. Cara ini membuat kode jauh lebih pendek dan rapi:
```bash
owner="eucalypsih"; repo="ey_rcrapsbash"; repo_path="/data/data/com.termux/files/home/${repo}"
git clone -q --filter=blob:none --no-checkout git@github.com:${owner}/${repo}.git "$repo_path" && sleep 0.5
for cfg in \
  "user.name eucalypsih" \
  "user.email eucalypsih@gmail.com" \
  "gpg.format ssh" \
  "user.signingkey ~/.ssh/id_rsa.pub" \
  "commit.gpgsign true" \
  "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers"; \
do git -C "$repo_path" config $cfg && sleep 0.5; done

```

Jika Anda membutuhkan versi **satu baris horizontal penuh** agar mudah disalin ke Termux, gunakan kode di bawah ini:
```bash
owner="eucalypsih"; repo="ey_rcrapsbash"; repo_path="/data/data/com.termux/files/home/${repo}"; git clone -q --filter=blob:none --no-checkout git@github.com:${owner}/${repo}.git "$repo_path" && sleep 0.5 && for cfg in "user.name eucalypsih" "user.email eucalypsih@gmail.com" "gpg.format ssh" "user.signingkey ~/.ssh/id_rsa.pub" "commit.gpgsign true" "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers"; do git -C "$repo_path" config $cfg && sleep 0.5; done

```

<br>

---

<br>

## Apa Bedanya Tanpa Flag `--local`?

**Secara fungsional, tidak ada bedanya**. Menulis `git config user.name "eucalypsih"` memiliki efek yang sama persis dengan `git config --local user.name "eucalypsih"`.

Berikut adalah perbedaan karakteristik tingkat konfigurasi di Git untuk memberikan gambaran yang lebih jelas:
- Tanpa Flag (Otomatis `--local`):
Konfigurasi hanya disimpan di dalam file `.git/config` pada repositori tempat Anda berada saat itu. Konfigurasi ini **tidak akan memengaruhi** repositori lain yang ada di perangkat Termux Anda.
- Menggunakan `--global`:
Jika Anda menambahkan flag `--global`, konfigurasi akan disimpan di folder home pengguna (`~/.gitconfig`). Pengaturan ini akan berlaku untuk **semua repositori** yang Anda kelola di Termux, kecuali jika repositori tersebut memiliki konfigurasi lokal tersendiri yang menimpanya.
- Menggunakan `--system`:
Konfigurasi berlaku untuk **seluruh pengguna sistem** pada perangkat tersebut (disimpan di tingkat root instalasi Git). Fitur ini sangat jarang digunakan di lingkungan Termux.

Menambahkan flag `--local` secara eksplisit biasanya hanya digunakan untuk **menegaskan kode (keterbacaan)** agar orang lain yang membaca script Anda tahu pasti bahwa konfigurasi tersebut hanya ditujukan khusus untuk repositori itu saja dan tidak merusak pengaturan global.



qs: 
 membandingkan perubahan antar commit di github
 
 ---

aa: 
Untuk membandingkan perubahan antar commit di GitHub, Anda bisa melakukannya langsung melalui antarmuka web GitHub atau menggunakan perintah terminal (git diff).

## 1. Melalui Web GitHub (Cara Termudah)
Anda bisa menggunakan fitur Compare milik GitHub dengan memodifikasi URL repositori Anda:
- Menggunakan Halaman Compare:
  1. Buka repositori Anda di GitHub.
  2. Klik tab Pull requests, lalu klik New pull request.
  3. Klik tautan compare across forks (jika perlu) atau langsung pilih branch / tag yang ingin dibandingkan pada menu dropdown base dan compare.
  4. Tips: Anda bisa langsung mengetik atau menempelkan hash commit (7 karakter pertama) ke dalam kotak pencarian dropdown tersebut untuk membandingkan dua commit spesifik.

- Menggunakan URL Langsung (Cara Tercepat):
  Tambahkan /compare/COMMIT_LAMA..COMMIT_BARU di akhir URL repositori Anda.
    - Format: https://github.com
    - Contoh: https://github.com/eucalypsih/ey_rcrapsbash/compare/a9e1c3886f001bfbbdfa8bb4f8cbde593f829e8d..b225ba6687c65b84442b2ec1459a69fb3f352997
    - (Gunakan dua titik .. untuk membandingkan perbedaan langsung antara dua commit).

## 2. Melalui Terminal (Git CLI)
Jika repositori sudah ada di komputer lokal Anda, gunakan perintah berikut di terminal:
- Melihat semua perubahan kode baris per baris:
```bash
git diff <hash_commit_lama> <hash_commit_baru>

```
- Melihat daftar file yang berubah saja (lebih ringkas):
```bash
git diff --name-status <hash_commit_lama> <hash_commit_baru>

```
- Membandingkan commit tertentu dengan kondisi kode saat ini (HEAD):
```bash
git diff <hash_commit_lama> HEAD

```

---

aa: 
Penyebab hanya ada 2 folder (go_r dan rs_r) adalah karena penghapusan folder-folder lainnya (bash, diff, et_micro, ftp, gdb, gef, git, re, rename, rs, rs_c, search, sed, tar) ternyata tidak terjadi di commit u323 (18be80e3), melainkan terjadi di salah satu commit setelahnya (u324, u325, u326, atau u327).

Perintah diff a9e1c38 18be80e3 hanya memeriksa file yang dihapus khusus pada transisi dari u322 ke u323 saja.

## Solusi: Pulihkan Semua File yang Terhapus dari u322 hingga HEAD (u327)
Ubah rentang pengecekan menjadi a9e1c38 HEAD agar mencakup seluruh file yang terhapus sejak u322 hingga commit terbaru (u327), sambil tetap mempertahankan penambahan baru (seperti folder go_r dan tambahan teks di rs_r/README.md):
```bash
# 1. Cek dan ambil kembali SEMUA file yang terhapus antara u322 (a9e1c38) hingga HEAD (u327)
git -C $HOME/ey_rcrapsbash diff --name-only --diff-filter=D a9e1c38 HEAD | \
  xargs -r git -C $HOME/ey_rcrapsbash checkout a9e1c38 --

# 2. Pastikan semua folder sudah kembali muncul
ls $HOME/ey_rcrapsbash

# 3. Simpan hasilnya sebagai commit baru (u328)
git -C $HOME/ey_rcrapsbash commit -m "u328: pulihkan semua folder dan file yang terhapus sejak u322"

```

## Apa yang Akan Terjadi Setelah Perintah Ini?
- Seluruh folder lama kembali utuh: README.md, bash, diff, et_micro, ftp, gdb, gef, git, re, rename, rs, rs_c, rs_r, search, sed, tar.
- Seluruh pekerjaan baru Anda tetap aman: Folder baru go_r beserta seluruh tambahan teks pada rs_r/README.md di u323–u327 tidak akan terhapus maupun tertimpa.

Jika ada file yang namanya mengandung spasi, beri tahu saya agar saya berikan opsi -z pada git diff dan xargs supaya tidak gagal diproses oleh terminal.

---

qs: 
setelah https://github.com/eucalypsih/ey_rcrapsbash/compare/a9e1c3886f001bfbbdfa8bb4f8cbde593f829e8d..b225ba6687c65b84442b2ec1459a69fb3f352997 ternyata berhasil

---

aa: 
Selamat! Pemulihan file berhasil dan perbandingan antara u322 (a9e1c388) hingga commit terbaru (b225ba66) kini sudah bersih.

Karena halaman web GitHub terkadang memuat terlalu lama untuk menampilkan diff berukuran besar secara langsung di browser, Anda dapat mengecek ringkasan hasil akhir secara cepat lewat terminal lokal:
```bash
git -C $HOME/ey_rcrapsbash diff --stat a9e1c3886f001bfbbdfa8bb4f8cbde593f829e8d..b225ba6687c65b84442b2ec1459a69fb3f352997

```

```bash
git -C $HOME/ey_rcrapsbash log --oneline --stat a9e1c38..HEAD

```

## Jika ingin isi folder sama persis dengan u322 tanpa merusak riwayat GitHub (revert)
Gunakan ini jika repo Anda sudah dipublikasikan/dipakai orang lain dan Anda tidak ingin melakukan force push:
```bash
# 1. Batalkan seluruh rentang commit u323 sampai u327 sekaligus menjadi satu commit baru
git -C $HOME/ey_rcrapsbash revert --no-commit 18be80e30b1ed25b5532882738133e940b5ffe08^..HEAD

# 2. Simpan sebagai commit baru (u328)
git -C $HOME/ey_rcrapsbash commit -m "u328: kembalikan seluruh struktur ke kondisi u322"

# 3. Push normal tanpa --force
git -C $HOME/ey_rcrapsbash push origin main

```

## Mengapa Tidak Menggunakan git checkout a9e1c388?
Perintah git checkout a9e1c388 hanya membawa Anda "jalan-jalan melihat masa lalu" (Detached HEAD). Branch main sendiri tetap tertinggal di u327, sehingga jika nanti Anda melakukan perubahan baru dan git commit, commit tersebut tidak akan masuk ke branch main.

---


aa: 
Untuk mempertahankan pesan commit asli dari u322 (a9e1c38) tanpa mengubahnya menjadi u328: pulihkan..., gunakan opsi -C (--reuse-message) pada git commit.

Opsi -C a9e1c38 menyalin seluruh pesan commit (beserta isi komentar lengkap jika ada) persis seperti milik commit a9e1c38 tanpa membuka editor dan tanpa mengetik ulang.

## Jika Belum di-Commit (Saat Pertama Kali Menjalankan Pemulihan)
```bash
# 1. Ambil kembali semua file yang terhapus sejak u322
git -C $HOME/ey_rcrapsbash diff --name-only --diff-filter=D a9e1c38 HEAD | \
  xargs -r git -C $HOME/ey_rcrapsbash checkout a9e1c38 --

# 2. Simpan commit dengan menyalin pesan asli milik u322 (a9e1c38) persis sama
git -C $HOME/ey_rcrapsbash commit -C a9e1c3886f001bfbbdfa8bb4f8cbde593f829e8d

```







<br>

