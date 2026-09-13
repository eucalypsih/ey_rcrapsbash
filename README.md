# ey_rcrapsbash

```bash
o="eucalypsih";r="ey_rcrapsbash";rp="/data/data/com.termux/files/home/${r}";git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp" && sleep 0.5 && for cfg in "user.name eucalypsih" "user.email eucalypsih@gmail.com" "gpg.format ssh" "user.signingkey ~/.ssh/id_rsa.pub" "commit.gpgsign true" "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers";do git -C "$rp" config $cfg && sleep 0.5;done
```
`o="eucalypsih";r="ey_rcrapsbash";rp="/data/data/com.termux/files/home/${r}";git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp" && sleep 0.5 && for cfg in "user.name eucalypsih" "user.email eucalypsih@gmail.com" "gpg.format ssh" "user.signingkey ~/.ssh/id_rsa.pub" "commit.gpgsign true" "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers";do git -C "$rp" config $cfg && sleep 0.5;done`

- `set --no-cone '!/*' '/README.md' '/git/README.md'`
```bash
o="eucalypsih";r="ey_rcrapsbash";rp="/data/data/com.termux/files/home/${r}";git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' '/git/README.md' && sleep 0.5 && git -C "$rp" checkout -f main
```
`o="eucalypsih";r="ey_rcrapsbash";rp="/data/data/com.termux/files/home/${r}";git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' '/git/README.md' && sleep 0.5 && git -C "$rp" checkout -f main`


<br>

---

<br>

- `'/README.md'`
```bash
git sparse-checkout set --no-cone '/README.md' && sleep 0.5 && git checkout main

```

<br>

---

<br>

### Set Micro sebagai Git Editor Sementara
Jalankan perintah ini di terminal agar Git langsung membuka Micro untuk proses rebase kali ini:
```bash
GIT_EDITOR=micro git rebase -i --root

```

### Mengaktifkan Permanen (Untuk Seterusnya)
```bash
git config --global core.editor "micro"

```

<br>

---

<br>

# Cara Aman Menghapus Log Lama Tanpa Merusak Folder Lain
Jika Anda ingin menghapus log *commit* paling lama tanpa menyentuh atau merusak file-file besar di folder `ftp`, `diff`, dll., cara terbaik adalah menggunakan `git checkout --orphan` untuk membuat riwayat baru yang bersih dari titik tertentu, atau mendownload penuh repositori tersebut di folder terpisah khusus untuk bersih-bersih riwayat.

Jika Anda ingin membersihkannya langsung di folder kerja saat ini tanpa download ulang, Anda bisa membuat cabang baru yang "segar" (tanpa membawa log lama):
1. Buat branch baru yang terputus dari riwayat lama
```bash
git checkout --orphan branch-baru

```

2. Tambahkan file yang ada saat ini:
```bash
git add .

```

3. Buat commit pertama yang baru:
```bash
git commit -m "Initial commit baru dengan README"

```

4. *Force push* ke main (Hati-hati, ini akan mengganti riwayat di remote hanya dengan file yang Anda miliki sekarang):
```bash
git push origin branch-baru:main --force

```
> Perintah di atas artinya: "Ambil isi dari branch lokal bernama `branch-baru`, lalu paksa masukkan ke dalam branch remote bernama `main`."

memeriksa apakah riwayat baru Anda sudah sukses masuk ke GitHub, Anda bisa mengecek log branch main remote dengan perintah:
```bash
git log origin/main --oneline

```

### memunculkan nama `branch-baru` di GitHub
Jika Anda ingin branch tersebut muncul di GitHub dengan nama `branch-baru` (bukan menimpa `main`), Anda harus mem-push namanya secara berpasangan:
```bash
git push origin branch-baru:branch-baru

```

**daftar log di `origin/main` tersebut bisa dihapus total** dan digantikan sepenuhnya oleh riwayat baru Anda yang bersih (`Initial commit` sampai `u1`).
- `origin/main` (di GitHub): Masih menyimpan puluhan log *commit* lama yang ingin Anda buang.
- `branch-baru` (di Termux lokal Anda): Sudah bersih, hanya berisi 4 commit baru yang Anda buat (`Initial commit baru...` sampai `50110dd u1`).

Untuk menghapus seluruh daftar log lama di GitHub dan menggantinya dengan yang baru, Anda tinggal menjalankan perintah **force push** dari branch lokal Anda yang sekarang menuju ke `main` di GitHub.

### Langkah Eksekusi (Hapus Log Lama di GitHub)

Jalankan perintah ini di terminal Termux Anda:
```bash
git push origin branch-baru:main --force

```

Apa yang Terjadi Setelah Perintah Ini Dijalankan?
1. Log Lama Terhapus: GitHub akan membuang seluruh silsilah log lama (dari `4888365 u4` sampai `f93f6c9`) dari branch `main`.
2. Riwayat Diperbarui: Branch `main` di GitHub sekarang akan memiliki riwayat yang persis sama dengan `branch-baru` Anda saat ini.
3. Sinkronisasi Lokal: Setelah *force push* selesai, Anda bisa mengetik perintah berikut untuk memperbarui referensi lokal Anda:
```bash
git fetch origin

```

<br>

qa: 
apakah Anda ingin **menghapus `branch-baru`** di lokal agar Anda bisa kembali bekerja di branch `main` yang sudah bersih?

<br>

qc: 
Saya ingin **menghapus `branch-baru`** di lokal agar Anda bisa kembali bekerja di branch `main` yang sudah bersih?

<br>

aa: 
Berikut adalah langkah-langkah berurutan untuk menghapus `branch-baru` dan kembali bekerja di branch `main` lokal Anda yang sudah bersih:
1. Pindah Kembali ke Branch `main`
Sebelum menghapus `branch-baru`, Anda harus keluar dari branch tersebut terlebih dahulu. Jalankan perintah ini:
```bash
git checkout main

```
2. Atur Branch `main` Lokal Agar Sama dengan GitHub
Karena branch `main` lokal Anda mungkin masih menyimpan riwayat lama atau dalam kondisi kosong, paksa branch `main` lokal Anda agar mengambil riwayat baru yang sudah bersih dari GitHub (`origin/main`):
```bash
git reset --hard origin/main

```
3. Hapus `branch-baru` di Lokal
Sekarang, Anda sudah aman untuk menghapus `branch-baru` karena semua commit bersihnya sudah tersimpan di branch `main`. Jalankan perintah ini:
```bash
git branch -D branch-baru

```
> (Catatan: Kita menggunakan `-D` huruf kapital untuk memaksa penghapusan karena Git terkadang mendeteksi branch ini belum di-merge secara konvensional).

Sekarang Anda sudah berada di branch `main` lokal, dengan riwayat log yang sudah bersih (hanya berisi 4 commit baru Anda), dan aturan *sparse-checkout* (`/README.md`) tetap aktif seperti semula.

<br>

qa: 
Anda sebenarnya **ingin folder-folder tersebut tetap ada di GitHub** dan hanya ingin merapikan riwayat log `README.md` saja?







<br>
