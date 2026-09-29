# 

aa: 
Untuk menambahkan fitur **manajemen SSH key dinamis** berdasarkan `owner` secara otomatis, cara paling elegan dan aman adalah memanfaatkan variabel `$o` (nama owner) yang sudah berhasil dikunci oleh skrip Anda di menu utama.

Kita bisa memindahkan proses konfigurasi Git dan pengunduhan SSH key ke dalam sebuah fungsi atau blok logika baru yang **menggunakan variabel `$o` sebagai nama file SSH key unik** (misalnya`~/.ssh/id_rsa_$o`). Dengan begitu, key milik `owner1` tidak akan menimpa key milik `owner2`, dan Git akan menggunakan key yang tepat untuk setiap repositori secara otomatis.

Berikut adalah langkah-langkah perbaikan dan potongan kode baru untuk skrip Anda:

---

## 1. Blok Logika SSH & Konfigurasi Git Dinamis (Gantikan Blok Lama)
Cari blok kode **`# SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis`** yang berada di dalam kondisi `if [ -z "$current_sparse" ]`. Ganti seluruh blok tersebut dan blok unduhan SSH di bawahnya dengan kode dinamis berikut:
```bash
  # =====================================================================
  # MANAJEMEN SSH KEY & KONFIGURASI GIT DINAMIS BERDASARKAN OWNER
  # =====================================================================
  _ic "Mengonfigurasi SSH Key dinamis untuk owner: ${o}..."

  # Jalur SSH Key spesifik untuk masing-masing owner
  owner_privkey="${HOME}/.ssh/id_rsa_${o}"
  owner_pubkey="${HOME}/.ssh/id_rsa_${o}.pub"

  # Unduh SSH Key secara otomatis jika belum ada di lokal
  if [ ! -f "$owner_privkey" ]; then
    _ic "Mengunduh SSH Key untuk ${o} dari remote repository..."
    
    # Amankan hak akses folder .ssh terlebih dahulu
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    
    # Menggunakan subshell dengan umask ketat untuk file private key
    (
      umask 077
      # Mengunduh private key berdasarkan variabel nama owner ($o)
      if curl -fsSL "https://github.com{o}/repo1/raw/main/${o}_rsa_privkey" -o "${owner_privkey}.base64"; then
        base64 -d "${owner_privkey}.base64" > "$owner_privkey"
        rm -f "${owner_privkey}.base64"
      else
        log_fatal "Gagal mengunduh Private Key untuk ${o}!"
      fi
    )

    # Menggunakan umask standar untuk public key
    (
      umask 022
      # Mengunduh public key berdasarkan variabel nama owner ($o)
      if curl -fsSL "https://github.com{o}/repo1/raw/main/${o}_rsa_pubkey" -o "${owner_pubkey}.base64"; then
        base64 -d "${owner_pubkey}.base64" > "$owner_pubkey"
        rm -f "${owner_pubkey}.base64"
      else
        log_fatal "Gagal mengunduh Public Key untuk ${o}!"
      fi
    )
  fi

  # Validasi akhir apakah file key berhasil dibuat
  if [ -f "$owner_privkey" ] && [ -f "$owner_pubkey" ]; then
    _o "SSH Key untuk ${o} berhasil diverifikasi."
  else
    log_fatal "Kredensial SSH tidak lengkap. Skrip dihentikan."
    exit 1
  fi

  # Jalankan loop konfigurasi lokal repositori secara otomatis
  _ic "Menerapkan konfigurasi Git lokal..."
  for item in \
    "user.name ${o}" \
    "user.email ${o}@gmail.com" \
    "gpg.format ssh" \
    "user.signingkey ${owner_pubkey}" \
    "commit.gpgsign true" \
    "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers" \
    "core.sshCommand ssh -i ${owner_privkey} -o IdentitiesOnly=yes";
  do
    git -C "$rp" config $item
    sleep 0.1
  done # end for item
  _o "Konfigurasi Git lokal untuk ${o} berhasil diterapkan."

```

---

## 2. Apa Saja yang Berubah & Mengapa Ini Otomatis?
- `core.sshCommand` Lokal: Kunci utamanya ada pada penambahan konfigurasi `core.sshCommand` pada Git lokal Anda. Perintah `ssh -i ${owner_privkey} -o IdentitiesOnly=yes` memaksa Git untuk **hanya menggunakan key spesifik owner tersebut** saat melakukan `git fetch`, `push`, atau `pull` di dalam folder repo ini, mengabaikan SSH agent global lainnya.
- Isolasi Berkas: File SSH key disimpan dengan format nama `id_rsa_owner1`, `id_rsa_owner2`, dst. Mereka hidup berdampingan dengan aman di dalam folder `~/.ssh/` tanpa saling menimpa.
- Fleksibilitas Unduhan URL: Jalur URL `curl` diubah menjadi `https://github.com{o}/...`. Skrip akan otomatis mencari repositori dan file key sesuai dengan nama owner yang sedang aktif dibaca dari `rp.txt`.
- Nama & Email Git Dinamis: Nilai `user.name` dan `user.email` otomatis menyesuaikan dengan variabel `$o` (misal: `owner1` dan `owner1@gmail.com`).

---

## 3. Penyesuaian Tambahan (Opsional tapi Direkomendasikan)
Karena proses kloning awal (`git clone`) pada skrip Anda berjalan sebelum blok konfigurasi di atas dieksekusi, perintah `git clone` standar mungkin akan gagal jika belum ada SSH key global yang terpasang di Termux/Linux Anda.

Untuk memastikan proses `git clone` pertama kali juga langsung menggunakan key dinamis secara otomatis, Anda bisa mengubah baris kode `git clone` yang ada di skrip Anda [1] menjadi seperti ini:
```bash
  # Menggunakan flag -c core.sshCommand secara langsung saat clone agar instan mengenali key owner
  if ! git clone -q --filter=blob:none --no-checkout \
    -c "core.sshCommand=ssh -i ${HOME}/.ssh/id_rsa_${o} -o IdentitiesOnly=yes" \
    git@github.com:${o}/${r}.git "$rp"; then
    log_fatal "Gagal melakukan git clone! Periksa koneksi internet atau SSH Key Anda."
    exit 1
  fi # end if clone success

```


<br>

---

<br>












<br>
