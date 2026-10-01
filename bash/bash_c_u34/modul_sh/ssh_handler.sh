#!/bin/bash

# =====================================================================
# MODUL EKSTERNAL: MANAJEMEN & PENGUNDUHAN SSH KEY OTOMATIS (ssh_handler.sh)
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
o="$1"
rp="$2"
owner_privkey="$3"
owner_pubkey="$4"

# Pengaman awal: Batalkan proses jika parameter krusial tidak lengkap
if [ -z "$o" ] || [ -z "$rp" ] || [ -z "$owner_privkey" ] || [ -z "$owner_pubkey" ]; then
  _e "Parameter untuk manajemen SSH Key tidak lengkap!"
  _pp
  exit 1
fi

_ic "Mengonfigurasi SSH Key dinamis untuk owner: ${o}..."

# 3. VERIFIKASI JARRINGAN JIKA KEY BELUM ADA ATAU FOLDER LOKAL BELUM TERSEDIA
if [ ! -f "$owner_privkey" ] || [ ! -d "$rp" ]; then
  _ic "Memeriksa jaringan untuk verifikasi kredensial dan repositori..."
  if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    log_fatal "Anda sedang OFFLINE! Proses ini memerlukan koneksi internet."
    _pp
    exit 1
  fi
fi

# Unduh SSH Key secara otomatis jika belum ada di lokal
# Jalankan unduhan otomatis jika berkas key belum tersedia di penyimpanan lokal
if [ ! -f "$owner_privkey" ]; then
  _ic "Mengunduh SSH Key untuk ${o} dari remote repository... atau Mengunduh SSH Key dinamis untuk owner: ${o}..."

  # Amankan hak akses folder .ssh terlebih dahulu
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

  # Menggunakan subshell dengan umask ketat untuk file private key
  # Subshell umask ketat khusus untuk berkas Private Key (chmod 600)
  (
    umask 077
    # Mengunduh private key berdasarkan variabel nama owner ($o)
    if curl -fsSL "https://github.com/${o}/eucalypsih_rcrapsbash/raw/main/${o}_rsa_privkey" -o "${owner_privkey}.base64"; then
      base64 -d "${owner_privkey}.base64" > "$owner_privkey"
      rm -f "${owner_privkey}.base64"
    else
      log_fatal "Gagal mengunduh Private Key untuk ${o}!"
      exit 1
    fi
  )

  # Pastikan jika subshell private key gagal, hentikan skrip
  [ $? -ne 0 ] && exit 1
  # Menggunakan umask standar untuk public key
  # Subshell umask standar untuk berkas Public Key (chmod 644)
  (
    umask 022
    # Mengunduh public key berdasarkan variabel nama owner ($o)
    if curl -fsSL "https://github.com/${o}/eucalypsih_rcrapsbash/raw/main/${o}_rsa_pubkey" -o "${owner_pubkey}.base64"; then
      base64 -d "${owner_pubkey}.base64" > "$owner_pubkey"
      rm -f "${owner_pubkey}.base64"
    else
      log_fatal "Gagal mengunduh Public Key untuk ${o}!"
      exit 1
    fi
  )

  # Pastikan jika subshell public key gagal, hentikan skrip
  [ $? -ne 0 ] && exit 1
  _o "Kredensial SSH untuk ${o} berhasil disiapkan."
fi

# Validasi akhir apakah file key berhasil dibuat
# 5. VALIDASI AKHIR KETERSEDIAAN BERKAS KEY
if [ -f "$owner_privkey" ] && [ -f "$owner_pubkey" ]; then
  _o "SSH Key untuk ${o} berhasil diverifikasi."
  exit 0
else
  log_fatal "Kredensial SSH tidak lengkap. Skrip dihentikan."
  _pp
  exit 1
fi
