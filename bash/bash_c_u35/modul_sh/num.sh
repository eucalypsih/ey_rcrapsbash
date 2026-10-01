#!/bin/bash

# --- IMPORT VISUAL LIBRARY ---
# =====================================================================
# LOGIKA UTAMA: JIKA INPUT ADALAH ANGKA (ADD FOLDER UTAMA)
# MODUL EKSTERNAL: AKTIVASI & PENONAKTIFKAN FOLDER SPARSE-CHECKOUT (num.sh)
# =====================================================================

# 1. AMBIL FUNGSI WARNA & LOGGING (utils.sh berada di folder yang sama)
CURRENT_MODUL_DIR="$(dirname "$0")"
if [ -f "${CURRENT_MODUL_DIR}/utils.sh" ]; then
  source "${CURRENT_MODUL_DIR}/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL: File utils.sh tidak ditemukan di folder ${CURRENT_MODUL_DIR}!\033[0m"
  exit 1
fi

# 2. TANGKAP VARIABEL DAN ARGUMEN DARI SKRIP UTAMA
rp="$1"
r="$2"
current_branch="$3"
targets=($4)         # Mengubah kembali string menjadi format Array lokal
current_sparse="$5"   # Menangkap status sparse-checkout aktif
pilihan="$6"          # Menangkap angka pilihan input dari pengguna

# Pengaman awal: Jika argumen penting kosong, gagalkan proses demi keamanan Git
if [ -z "$rp" ] || [ -z "$current_branch" ] || [ -z "$pilihan" ]; then
  _e "Argumen proses seleksi folder tidak lengkap!"
  _pp
  exit 1
fi

# 3. JALANKAN LOGIKA PROSES SELEKSI FOLDER BERDASARKAN ANGKA INPUT
if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
  idx=$((pilihan - 1))
  selected_folder="${targets[$idx]}"

  # CEK JIKA FOLDER TARGET SUDAH AKTIF (AKAN MELAKUKAN PROSES PENONAKTIFAN)
  if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
    _w "Folder /${selected_folder} saat ini sedang AKTIF."
    # 1. DETEKSI PERUBAHAN LOKAL & FILE UNTRACKED DI FOLDER SPESIFIK INI
    target_folder_fisik="${rp}/${selected_folder}"
    perubahan_folder=$(git -C "$rp" status --porcelain "$selected_folder" 2>/dev/null)

    if [ -n "$perubahan_folder" ]; then
      log_critical "Terdeteksi berkas UNTRACKED / MODIFIED di dalam /${selected_folder}!"
      echo -e "${RED}Berkas berikut belum di-commit dan akan HILANG PERMANEN:${NC}"
      echo "$perubahan_folder"
      echo "------------------------------------------------------"
      _pd "Apakah Anda YAKIN ingin MEMUSHNAKAN folder ini beserta isinya?"
    else
      _pd "Apakah Anda ingin MENONAKTIFKAN & HAPUS FISIK folder ini dari penyimpanan?"
    fi

    read -r konfirmasi_nonaktif
  
    if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
      _ic "Memproses penonaktifkan folder /${selected_folder}..."

      # Membuat daftar baru yang mengecualikan folder terpilih
      # Menyusun daftar sparse checkout baru dengan mengecualikan folder terpilih
      new_sparse_list=()
      # Pastikan README.md atau rules default dasar tetap ada
      new_sparse_list+=("!/*" "/README.md") # Aturan pengaman dasar default

      while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Lewati pattern bawaan dan folder yang mau dinonaktifkan
        if [[ "$line" != "!/*" && "$line" != "/README.md" && "$line" != "$selected_folder" && "$line" != "/${selected_folder}" ]]; then
          # Bersihkan leading slash untuk standardisasi penulisan parameter set
          clean_line=$(echo "$line" | sed 's|^/||')
          new_sparse_list+=("/${clean_line}")
        fi
      done <<< "$current_sparse"

      # Terapkan ulang daftar sparse-checkout yang baru
      if git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}"; then
        _o "Folder /${selected_folder} BERHASIL dinonaktifkan dari Git!"

        # Seketika hapus folder fisik lokal jika ada
        if [ -d "$target_folder_fisik" ]; then
          _ic "Memusnahkan direktori fisik lokal secara otomatis..."
          rm -rf "$target_folder_fisik"
          _o "Folder fisik '${selected_folder}' berhasil dihapus sepenuhnya."
        fi

        # Pemicu regenerasi struktur Git untuk memastikan konsistensi berkas remote
        git -C "$rp" checkout "$current_branch" &>/dev/null
      else
        _e "Gagal memperbarui sparse-checkout list."
        _pp
      fi

    else
      _c "Tindakan dibatalkan. Folder tetap aktif aman."
      sleep 1.1
    fi
  else
    # Jika belum aktif, lakukan proses ADD seperti semula
    # JIKA FOLDER BELUM AKTIF (AKAN MELAKUKAN PROSES AKTIVASI / ADD FOLDER)
    _ic "Menambahkan /${selected_folder} ke sparse-checkout..."
    if git -C "$rp" sparse-checkout add "/${selected_folder}"; then
      # Paksa penarikan fisik berkas baru dari indeks remote Git
      # Paksa Git melakukan checkout fisik berkas baru dari indeks remote database
      git -C "$rp" checkout "$current_branch" &>/dev/null
      sleep 0.5
      _o "Berhasil ditambahkan dan diterapkan ke direktori lokal!"
    else
      _e "Gagal menambahkan folder ke sparse-checkout."
      _pp
    fi
  fi # end if check sparse list
else
  _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
  _pp
fi # end if target selection check


