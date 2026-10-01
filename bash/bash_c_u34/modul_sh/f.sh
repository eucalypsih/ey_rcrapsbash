#!/bin/bash

# =====================================================================
# MODUL EKSTERNAL: HANYA HAPUS FOLDER FISIK LOKAL / PURGE CACHE (f.sh)
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
valid_repos=($1) # Mengubah string dari skrip utama menjadi format Array lokal kembali

# Pengaman awal: Jika daftar repositori terpantau kosong, langsung kembali
if [ ${#valid_repos[@]} -eq 0 ]; then
  _e "Daftar repositori kosong!"
  sleep 1.5
  exit 0
fi

_cc "----------------------------------------"
_p "Pilih nomor repo yang ingin di-PURGE/HAPUS folder fisik lokalnya saja"
read -r fisik_num
if [[ "$fisik_num" =~ ^[0-9]+$ ]] && [ "$fisik_num" -ge 1 ] && [ "$fisik_num" -le "${#valid_repos[@]}" ]; then
  idx_fisik=$((fisik_num - 1))
  repo_target="${valid_repos[$idx_fisik]}"
  owner_name_only="${repo_target%%/*}"
  repo_name_only="${repo_target#*/}"
  target_folder_fisik="${PWD}/${owner_name_only}/${repo_name_only}"
  target_owner_dir="${PWD}/${owner_name_only}"

  # Validasi apakah folder fisik lokal memang ada
  if [ ! -d "$target_folder_fisik" ]; then
    _w "Folder fisik untuk '${repo_target}' memang tidak ada di lokal (Sudah Bersih)."
    sleep 1.5
    exit 0
  fi
  _rn "PERINGATAN: Tindakan ini HANYA menghapus folder fisik di penyimpanan lokal."
  _c "Pilihan ini TETAP MEMPERTAHANKAN '${repo_target}' di dalam daftar rp.txt."

  # Deteksi status berkas lokal (uncommitted changes) sebelum penghapusan berbahaya
  perubahan_repo=$(git -C "$target_folder_fisik" status --porcelain 2>/dev/null)
  if [ -n "$perubahan_repo" ]; then
    log_critical "Terdeteksi berkas UNTRACKED / MODIFIED di dalam /${repo_name_only}!"
    echo "$perubahan_repo"
    echo "------------------------------------------------------"
    _pd "Berkas belum di-commit! Yakin tetap ingin MEMUSHNAKAN folder fisik ini?"
  else
    _pd "Apakah Anda yakin ingin menghapus folder fisik lokal '${owner_name_only}/${repo_name_only}'?"
  fi
  read -r konfirmasi_fisik_only
  if [[ "$konfirmasi_fisik_only" =~ ^[yY]$ ]]; then
    _ic "Menghapus folder fisik lokal secara permanen..."
    rm -rf "$target_folder_fisik"
    _o "Folder fisik lokal berhasil dihapus. Konfigurasi di rp.txt tetap aman."

    # Bersihkan folder owner jika kosong
    # Otomatisasi Bersih: Hapus direktori induk owner jika sudah kosong tak bersisa
    if [ -d "$target_owner_dir" ] && [ -z "$(ls -A "$target_owner_dir")" ]; then
      _ic "Mendapati direktori owner '${owner_name_only}' kosong, membersihkan folder induk..."
      rm -rf "$target_owner_dir"
    fi
  else
    _c "Penghapusan fisik dibatalkan."
  fi
else
  _e "Pilihan nomor tidak valid!"
fi
sleep 1.5
