


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




<br>

