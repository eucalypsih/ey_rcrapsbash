#!/bin/bash

# =====================================================================
# MODUL EKSTERNAL: HAPUS REPO DARI DAFTAR rp.txt & PURGE LOKAL (h.sh)
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
repo_file="$1"
valid_repos=($2) # Mengubah string dari skrip utama menjadi format Array lokal kembali

# Pengaman awal: Jika daftar repositori kosong, langsung kembalikan ke menu utama
if [ ${#valid_repos[@]} -eq 0 ]; then
  _e "Tidak ada repositori yang bisa dihapus!"
  _pp
  exit 0
fi

# Fungsi pembantu internal untuk meng-export kembali array ke file rp.txt setelah penghapusan
fungsi_export_repo() {
  local last_owner=""
  > "$repo_file"
  local item
  for item in "${valid_repos[@]}"; do
    local owner="${item%%/*}"
    local repo="${item#*/}"
    if [[ "$owner" != "$last_owner" ]]; then
      [[ -n "$last_owner" ]] && echo "" >> "$repo_file"
      echo "$owner" >> "$repo_file"
      last_owner="$owner"
    fi
    echo "    $repo" >> "$repo_file"
   Papoldone
}

# 3. PROSES INPUT SELEKSI HAPUS
_cr "----------------------------------------"
_p "Pilih nomor repo yang ingin dibuang dari daftar rp.txt"
local hapus_num
read -r hapus_num

if [[ "$hapus_num" =~ ^[0-9]+$ ]] && [ "$hapus_num" -ge 1 ] && [ "$hapus_num" -le "${#valid_repos[@]}" ]; then
  local idx_hapus repo_terhapus owner_name_only repo_name_only target_folder_fisik target_owner_dir konfirmasi_hapus
  
  idx_hapus=$((hapus_num - 1))
  repo_terhapus="${valid_repos[$idx_hapus]}"

  # Memisahkan nama owner dan nama repo secara akurat
  owner_name_only="${repo_terhapus%%/*}"
  repo_name_only="${repo_terhapus#*/}"

  # Jalur fisik riil repositori disesuaikan dengan jalur inisialisasi ($PWD/owner/repo)
  target_folder_fisik="${PWD}/${owner_name_only}/${repo_name_only}"
  target_owner_dir="${PWD}/${owner_name_only}"

  _pd "Anda yakin ingin menghapus '${repo_terhapus}' dari daftar ${repo_file}?"
  read -r konfirmasi_hapus

  if [[ "$konfirmasi_hapus" =~ ^[yY]$ ]]; then
    # Hapus data dari susunan array lokal
    valid_repos=("${valid_repos[@]:0:idx_hapus}" "${valid_repos[@]:idx_hapus+1}")
    
    # Simpan susunan array terbaru kembali ke file rp.txt
    fungsi_export_repo
    _o "'${repo_terhapus}' telah dihapus dari daftar ${repo_file}."

    # 4. SISTEM PURGE FOLDER FISIK LOKAL (JIKA DIREKTORI FISIK TERDETEKSI)
    if [ -d "$target_folder_fisik" ]; then
      local perubahan_repo
      perubahan_repo=$(git -C "$target_folder_fisik" status --porcelain 2>/dev/null)

      if [ -n "$perubahan_repo" ]; then
        log_critical "Terdeteksi berkas UNTRACKED / MODIFIED di dalam /${repo_name_only}!"
        echo -e "${RED}Berkas berikut belum di-commit dan akan HILANG PERMANEN jika dihapus:${NC}"
        echo "$perubahan_repo"
        echo "------------------------------------------------------"
        _pd "Apakah Anda YAKIN ingin MEMUSHNAKAN folder repositori ini beserta seluruh isinya?"
      else
        _pd "Apakah Anda ingin MENGHAPUS FISIK folder repositori ini dari penyimpanan lokal?"
      fi

      local konfirmasi_fisik
      read -r konfirmasi_fisik

      if [[ "$konfirmasi_fisik" =~ ^[yY]$ ]]; then
        _ic "Memusnahkan folder fisik lokal: ${owner_name_only}/${repo_name_only}..."
        rm -rf "$target_folder_fisik"
        _o "Folder fisik repositori berhasil dihapus sepenuhnya."

        # OTOMATISASI BERSIH: Hapus folder induk (owner) jika sudah kosong tidak ada repo lain
        if [ -d "$target_owner_dir" ] && [ -z "$(ls -A "$target_owner_dir")" ]; then
          _ic "Mendeteksi folder owner '${owner_name_only}' kosong. Membersihkan sisa direktori induk..."
          rm -rf "$target_owner_dir"
        fi
      else
        _w "Folder fisik lokal dipertahankan dan tetap aman."
      fi
    fi
  else
    _c "Penghapusan dibatalkan."
  fi
else
  _e "Pilihan nomor tidak valid!"
fi

sleep 1.5
