#!/bin/bash

# --- IMPORT VISUAL LIBRARY ---
# Mengambil fungsi warna dan log secara otomatis tanpa copas

# =====================================================================
# MODUL EKSTERNAL: JELAJAHI DAN EDIT SELURUH FILE (e.sh)
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
current_sparse="$5"   # Menangkap status sparsecheckout aktif

# Pengaman awal: Jika argumen kosong, hentikan proses demi keamanan Git
if [ -z "$rp" ] || [ -z "$current_branch" ]; then
  _e "Argumen repositori atau branch tidak valid!"
  _pp
  exit 1
fi

if ! command -v micro &> /dev/null; then
  _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
  _pp
  exit 1
fi
# Kumpulkan folder tingkat pertama yang aktif saat ini
active_folders=()
for folder in "${targets[@]}"; do
  if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
    active_folders+=("$folder")
  fi
done

log_notify "Memetakan seluruh file lokal dan remote secara rekursif..."

# Tarik daftar file dari REMOTE (GitHub)
mapfile -t remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

# Tarik daftar file dari LOKAL (Termux) - PERBAIKAN PARAMETER: -type f
local_files=()
if [ -d "$rp" ]; then
  mapfile -t local_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git")
fi # end if rp dir check

# Gabungkan Remote & Lokal ke dalam daftar validasi berdasarkan folder tingkat pertama yang aktif
all_combined_files=()
for file in "${remote_files[@]}" "${local_files[@]}"; do
  [ -z "$file" ] && continue

  # Jika target kosong (tidak ada folder remote), izinkan edit semua file di root (seperti README.md)
  if [ ${#targets[@]} -eq 0 ]; then
    if [[ ! " ${all_combined_files[*]} " =~ " ${file} " ]]; then
      all_combined_files+=("$file")
    fi
    continue
  fi

  # Logika bawaan jika repositori memiliki folder sparse
  for active_dir in "${active_folders[@]}"; do
    # Pastikan file berada di dalam salah satu folder induk yang aktif
    if [[ "$file" == "$active_dir"/* || "$file" == "$active_dir" ]]; then
      # Masukkan ke daftar gabungan (pastikan tidak duplikat)
      if [[ ! " ${all_combined_files[*]} " =~ " ${file} " ]]; then
        all_combined_files+=("$file")
      fi # end if duplicate check
      break
    fi # end if match check
  done # end for active_dir
done # end for file

# Urutkan secara alfabetis dan unik agar rapi
# Untuk Blok [eE]
mapfile -t valid_files < <(printf '%s\n' "${all_combined_files[@]}" | sort -u)

# 6. TAMPILKAN SUB-MENU DAFTAR FILE YANG DAPAT DIEDIT
if [ ${#valid_files[@]} -eq 0 ]; then
  _rn "Folder aktif Anda kosong (tidak ada file untuk diedit / Tidak ada file yang dapat diedit)."
  _pp
else
  # Tampilkan sub-menu seluruh file yang tersedia untuk diedit
  clear
  _cc "========================================"
  _cc "   DAFTAR FILE YANG DAPAT DIEDIT        "
  _cc "========================================"
  echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
  _cc "========================================"
  for i in "${!valid_files[@]}"; do
    printf " [%d] %s\n" $((i+1)) "${valid_files[$i]}"
    sleep 0.01 # Efek transisi cepat
  done # end for display files
  _cc "----------------------------------------"
  _p "Pilih nomor file yang ingin diedit dengan micro"
  read -r num_pilihan

  if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
    idx=$((num_pilihan - 1))
    selected_file="${valid_files[$idx]}"
    full_file_path="${rp}/${selected_file}"

    # Jaga-jaga buat folder induk lokal fisik jika membuka file remote yang belum ter-checkout lokal
    parent_dir=$(dirname "$full_file_path")
    mkdir -p "$parent_dir"
    touch "$full_file_path"

    _in "Membuka ${selected_file} dengan micro..."
    sleep 0.5
    micro "$full_file_path"
  else
    _an "Pilihan tidak valid."
    sleep 1
  fi # end if num_pilihan valid
fi # end if valid_files kosong
fi # end if micro check
