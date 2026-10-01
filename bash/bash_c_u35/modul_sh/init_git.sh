#!/bin/bash

# =====================================================================
# MODUL EKSTERNAL: INISIALISASI AWAL SPARSE & CONFIG IDENTITAS GIT (init_git.sh)
# =====================================================================

# 1. AMBIL FUNGSI WARNA & LOGGING FROM UTILS
CURRENT_MODUL_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
if [ -f "${CURRENT_MODUL_DIR}/utils.sh" ]; then
  source "${CURRENT_MODUL_DIR}/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL: File utils.sh tidak ditemukan di folder ${CURRENT_MODUL_DIR}!\033[0m"
  exit 1
fi

# 2. TANGKAP VARIABEL DAN ARGUMEN DARI SKRIP UTAMA
rp="$1"
o="$2"
owner_pubkey="$3"
owner_privkey="$4"

# Pengaman awal: Jika parameter krusial kosong, batalkan demi mencegah gagal tulis konfigurasi
if [ -z "$rp" ] || [ -z "$o" ] || [ -z "$owner_pubkey" ] || [ -z "$owner_privkey" ]; then
  _e "Parameter untuk inisialisasi identitas Git tidak lengkap!"
  _pp
  exit 1
fi

# 3. EKSEKUSI INISIALISASI AWAL SPARSE-CHECKOUT
# 3. EKSEKUSI INISIALISASI AWAL SPARSE-CHECKOUT
_ic "Menyiapkan inisialisasi awal sparse-checkout..."
  
# Inisialisasi awal sparse-checkout dengan README.md
git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' && sleep 0.5

# 4. TERAPKAN KONFIGURASI INTERNAL IDENTITAS GIT LOKAL REPOSITORI
# =====================================================================
# KONFIGURASI GIT DINAMIS BERDASARKAN OWNER
# =====================================================================
# Jalankan loop konfigurasi lokal repositori secara otomatis
# SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis  
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
done # end for item
_o "Konfigurasi Git lokal untuk ${o} berhasil diterapkan."
exit 0
