# ey_rcrapsbash

```bash
owner="eucalypsih";repo="ey_rcrapsbash";git clone -q --filter=blob:none --no-checkout git@github.com:${owner}/${repo}.git && sleep 0.5 && cd $repo && sleep 0.5 && un="eucalypsih";ue="eucalypsih@gmail.com";git config user.name "$un" && sleep 0.5 && git config user.email "$ue" && sleep 0.5 && git config gpg.format ssh && sleep 0.5 && git config user.signingkey ~/.ssh/id_rsa.pub && sleep 0.5 && git config commit.gpgsign true && sleep 0.5 && git config gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers

```
`owner="eucalypsih";repo="ey_rcrapsbash";git clone -q --filter=blob:none --no-checkout git@github.com:${owner}/${repo}.git && sleep 0.5 && cd $repo && sleep 0.5 && un="eucalypsih";ue="eucalypsih@gmail.com";git config user.name "$un" && sleep 0.5 && git config user.email "$ue" && sleep 0.5 && git config gpg.format ssh && sleep 0.5 && git config user.signingkey ~/.ssh/id_rsa.pub && sleep 0.5 && git config commit.gpgsign true && sleep 0.5 && git config gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers`

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

<br>

qa: 
Anda sebenarnya **ingin folder-folder tersebut tetap ada di GitHub** dan hanya ingin merapikan riwayat log `README.md` saja?







<br>
