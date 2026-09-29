# 


```bash
# =====================================================================
# PENGAMAN SEBELUM CLONE: UNDUH SSH KEY DINAMIS BERDASARKAN OWNER
# =====================================================================
owner_privkey="${HOME}/.ssh/id_rsa_${o}"
owner_pubkey="${HOME}/.ssh/id_rsa_${o}.pub"

# Periksa koneksi internet hanya jika key belum ada atau folder belum di-clone
if [ ! -f "$owner_privkey" ] || [ ! -d "$rp" ]; then
  _ic "Memeriksa jaringan untuk verifikasi kredensial dan repositori..."
  if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    log_fatal "Anda sedang OFFLINE! Proses ini memerlukan koneksi internet."
    exit 1
  fi
fi

# Jalankan unduhan otomatis jika berkas key belum tersedia di penyimpanan lokal
if [ ! -f "$owner_privkey" ]; then
  _ic "Mengunduh SSH Key dinamis untuk owner: ${o}..."
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  
  (
    umask 077
    if curl -fsSL "https://github.com{o}/repo1/raw/main/${o}_rsa_privkey" -o "${owner_privkey}.base64"; then
      base64 -d "${owner_privkey}.base64" > "$owner_privkey" && rm -f "${owner_privkey}.base64"
    else
      log_fatal "Gagal mengunduh Private Key untuk ${o}!"
      exit 1
    fi
  )
  (
    umask 022
    if curl -fsSL "https://github.com{o}/repo1/raw/main/${o}_rsa_pubkey" -o "${owner_pubkey}.base64"; then
      base64 -d "${owner_pubkey}.base64" > "$owner_pubkey" && rm -f "${owner_pubkey}.base64"
    else
      log_fatal "Gagal mengunduh Public Key untuk ${o}!"
      exit 1
    fi
  )
  _o "Kredensial SSH untuk ${o} berhasil disiapkan."
fi

```

---

```bash
# Clone repositori tanpa checkout (jika folder belum ada)
if [ ! -d "$rp" ]; then
  _ic "Mengkloning repositori ke ${rp} menggunakan key ${o}..."
  mkdir -p "$(dirname "$rp")"
  
  if ! git clone -q --filter=blob:none --no-checkout \
    -c "core.sshCommand=ssh -i ${owner_privkey} -o IdentitiesOnly=yes" \
    git@github.com:${o}/${r}.git "$rp"; then
    log_fatal "Gagal melakukan git clone! Periksa hak akses SSH Key Anda."
    exit 1
  fi
  _o "Kloning berhasil dilakukan."
  sleep 0.5
fi

```

---

```bash
if [ -z "$current_sparse" ]; then
  _ic "Menyiapkan inisialisasi awal sparse-checkout..."
  git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' && sleep 0.5

  # Terapkan konfigurasi internal Git secara otomatis
  _ic "Mengunci konfigurasi identitas Git lokal..."
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
    sleep 0.2
  done
  
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
else
  _o "Repositori terdeteksi sudah terinisialisasi."
  # ... (Sisa kode penanganan online/offline fetch Anda tetap di sini)

```















<br>

