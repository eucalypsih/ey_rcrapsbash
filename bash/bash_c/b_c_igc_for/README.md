# 

qs: 
```bash
[✓] Kloning berhasil dilakukan.[~] Menyiapkan inisialisasi awal sparse-checkout...[✓] Sukses mengonfigurasi akses file root direktori.[~] Mengunci konfigurasi identitas Git lokal...error: no action specified[✓] Konfigurasi Git lokal untuk eucalypsih berhasil diterapkan.ini pesan error apa ?

```

---

aa: 
Pesan `error: no action specified` berasal dari perintah `git config`. Pesan ini muncul karena Git mendeteksi ada argumen yang salah format atau **mengandung spasi ekstra** saat skrip mencoba memasukkan nilai konfigurasi.

Pada skrip `init_git.sh`, perintah dijalankan di dalam loop seperti ini: `git -C "$rp" config $item`. Ketika variabel `$item` dibaca (misalnya `"gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers"`), Git mendeteksi teks tersebut sebagai satu kesatuan yang aneh atau salah urutan tindakan (apakah mau *get*, *set*, atau *unset*), sehingga Git mengeluarkan komplain *"tidak ada tindakan yang ditentukan"*.

---

## 🛠️ Solusi Cara Memperbaikinya
Untuk menghilangkan error tersebut, perintah `git config` di dalam loop harus dipecah secara tegas menjadi dua bagian: **Nama Konfigurasi (Key)** dan **Nilainya (Value)**.

Silakan buka kembali berkas `./modul_sh/init_git.sh` Anda, lalu cari bagian **Bagian 4 (TERAPKAN KONFIGURASI INTERNAL...)**. Gantilah blok loop `for` yang lama dengan kode perbaikan di bawah ini:
```bash
# =====================================================================
# GANTI BLOK LOOP FOR PADA BAGIAN 4 DENGAN KODE DI BAWAH INI:
# =====================================================================

# 4. TERAPKAN KONFIGURASI INTERNAL IDENTITAS GIT LOKAL REPOSITORI
_ic "Mengunci konfigurasi identitas Git lokal..."

# PERBAIKAN: Menggunakan tanda pemisah khusus (semicolon ';') untuk memisahkan KEY dan VALUE secara aman
for item in \
  "user.name;${o}" \
  "user.email;${o}@gmail.com" \
  "gpg.format;ssh" \
  "user.signingkey;${owner_pubkey}" \
  "commit.gpgsign;true" \
  "gpg.ssh.allowedSignersFile;~/.ssh/allowed_signers" \
  "core.sshCommand;ssh -i ${owner_privkey} -o IdentitiesOnly=yes";
do
  # Memecah parameter menjadi KEY dan VALUE berdasarkan tanda pemisah ';'
  key="${item%%;*}"
  val="${item#*;}"
  
  # Eksekusi git config dengan membungkus nilai ($val) di dalam kutip double agar aman dari spasi
  git -C "$rp" config "$key" "$val"
  sleep 0.2
done # end for item

```

---

## 🔍 Mengapa Perubahan Ini Diperlukan?


| Detail Teknis | Logika Lama (Bermasalah) | Logika Baru (Solusi Berhasil) |
| :--- | :--- | :--- |
| **Bentuk Variabel** | `"core.sshCommand ssh -i ..."` | `"core.sshCommand;ssh -i ..."` |
| **Eksekusi Perintah** | `git config core.sshCommand ssh -i ...` (Spasi hancur berantakan) | `git config "core.sshCommand" "ssh -i ..."` (Parameter terkunci rapi) |
| **Respon Git Engine** | Gagal membaca maksud perintah $\rightarrow$ `error: no action specified` | Sukses **100%** mengunci data ke dalam berkas konfigurasi lokal `.git/config` |

Setelah Anda mengganti bagian loop tersebut, jalankan kembali skrip utama Anda. Pesan error merah tersebut dipastikan akan hilang sepenuhnya dan konfigurasi SSH Key per akun akan terkunci dengan sempurna di sistem Git lokal Anda.






















<br>
