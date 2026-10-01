#!/bin/bash

# --- IMPORT VISUAL LIBRARY ---
# Mengambil fungsi warna dan log secara otomatis tanpa copas
# =====================================================================
# MODUL EKSTERNAL: HAPUS FILE ATAU SUB-DIREKTORI / GIT RM (d.sh)
# =====================================================================

# 1. AMBIL FUNGSI WARNA & LOGGING (utils.sh berada di folder yang sama)
CURRENT_MODUL_DIR="$(dirname "$0")"
if [ -f "${CURRENT_MODUL_DIR}/utils.sh" ]; then
  source "${CURRENT_MODUL_DIR}/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL: File utils.sh tidak ditemukan di folder modul_sh!\033[0m"
  exit 1
fi

# 2. TANGKAP VARIABEL DAN ARGUMEN DARI SKRIP UTAMA
rp="$1"
r="$2"
current_branch="$3"
targets=($4)         # Mengubah kembali string menjadi format Array lokal
current_sparse="$5"   # Menangkap status sparse-checkout aktif

# Pengaman awal: Jika argumen kosong, hentikan proses demi keamanan Git
if [ -z "$rp" ] || [ -z "$current_branch" ]; then
  _e "Argumen repositori atau branch tidak valid!"
  _pp
  exit 1
fi

active_folders=()
for folder in "${targets[@]}"; do
  if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
    active_folders+=("$folder")
  fi
done

# 4. VALIDASI AWAL REPO AKTIF
if [ ${#active_folders[@]} -eq 0 ]; then
  _hn "Belum ada folder aktif. Silakan add folder terlebih dahulu."
  _pp
else
  log_notify "Memetakan seluruh file dan folder lokal..."
  
  # Mengambil semua file dan direktori di dalam folder aktif lokal (kecuali .git)
  all_local_items=()
  if [ -d "$rp" ]; then
    while IFS= read -r item; do
      [ -z "$item" ] && continue
      for active_dir in "${active_folders[@]}"; do
        if [[ "$item" == "$active_dir"/* || "$item" == "$active_dir" ]]; then
          all_local_items+=("$item")
          break
        fi
      done
    done < <(find "$rp" -mindepth 1 ! -path '*/.*' 2>/dev/null | sed "s|^${rp}/||" | sort)
  fi

  # 5. TAMPILKAN SUB-MENU DAFTAR FILE/FOLDER YANG BISA DIHAPUS
  if [ ${#all_local_items[@]} -eq 0 ]; then
    _rn "Tidak ada file atau sub-folder lokal yang dapat dihapus."
    _pp
  else
    clear
    _cc "========================================"
    _cc "     HAPUS FILE / SUB-DIREKTORI         "
    _cc "========================================"
    echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
    _cc "========================================"
    for i in "${!all_local_items[@]}"; do
      item_path="${all_local_items[$i]}"
      if [ -d "${rp}/${item_path}" ]; then
        printf " [%d] %s/ %b[ Folder ]%b\n" $((i+1)) "$item_path" "${YELLOW}" "${NC}"
      else
        printf " [%d] %s %b[ File ]%b\n" $((i+1)) "$item_path" "${GREEN}" "${NC}"
      fi
    done
    _cc "----------------------------------------"
    _p "Pilih nomor target yang ingin dihapus"
    read -r hapus_idx_num

    if [[ "$hapus_idx_num" =~ ^[0-9]+$ ]] && [ "$hapus_idx_num" -ge 1 ] && [ "$hapus_idx_num" -le "${#all_local_items[@]}" ]; then
      idx=$((hapus_idx_num - 1))
      target_hapus="${all_local_items[$idx]}"
      full_target_path="${rp}/${target_hapus}"

      _pd "Apakah Anda yakin ingin menghapus '${target_hapus}' dari Git & Penyimpanan?"
      read -r konfirmasi_item_hapus

      if [[ "$konfirmasi_item_hapus" =~ ^[yY]$ ]]; then
        _ic "Menghapus target menggunakan git rm..."

        # Logika Git RM: Cek apakah file sudah pernah di-track oleh git sebelumnya
        if git -C "$rp" ls-files --error-unmatch "$target_hapus" &>/dev/null; then
          # Jika sudah di-track, gunakan git rm secara rekursif untuk folder/file
          git -C "$rp" rm -rf "$target_hapus"
          _o "'${target_hapus}' dihapus dan dicatat di staging area Git."
        else
          # Jika file baru (untracked) dan belum di-commit, hapus secara fisik langsung
          rm -rf "$full_target_path"
          _o "Berkas untracked '${target_hapus}' telah dihapus fisik."
        fi
        sleep 1.5
      else
        _c "Penghapusan dibatalkan."
        sleep 1
      fi
    else
      _an "Pilihan tidak valid."
      sleep 1
    fi
  fi
fi
