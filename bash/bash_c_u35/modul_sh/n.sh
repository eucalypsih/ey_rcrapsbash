#!/bin/bash

# --- IMPORT VISUAL LIBRARY ---
# Mengambil fungsi warna dan log secara otomatis tanpa copas
# =====================================================================
# MODUL EKSTERNAL: BUAT FILE BARU DI FOLDER AKTIF (n.sh)
# =====================================================================

# 1. AMBIL FUNGSI WARNA & LOGGING (utils.sh berada di folder yang sama)
CURRENT_MODUL_DIR="$(dirname "$0")"
if [ -f "${CURRENT_MODUL_DIR}/utils.sh" ]; then
  source "${CURRENT_MODUL_DIR}/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL: File utils.sh tidak ditemukan di folder modul_sh!\033[0m"
  exit 1
fi

#  TANGKAP VARIABEL DAN ARGUMEN PARSED DARI SKRIP UTAMA
rp="$1"
r="$2"
current_branch="$3"

# Menangkap string targets lalu mengubahnya kembali menjadi format Array lokal di n.sh
targets=($4)

# Menangkap data sparse-checkout aktif langsung dari skrip utama
current_sparse="$5"

# --- LANJUTKAN LOGIKA PEMPROSESAN SEPERTI BIASA ---
# Sekarang Anda bisa langsung menggunakan fungsi _cc, _in, _p, _e di sini!
_in "Memetakan seluruh struktur sub-folder secara mendalam..."

# ... [Sisa kode logika buat file di bawahnya] ...

#!/bin/bash

# Menangkap variabel yang dikirim dari skrip utama
rp="$1"
r="$2"
current_branch="$3"


# --- AMBIL DAFTAR TARGET & SPARSE DARI PROYEK AKTIF ---
targets=($(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null))
current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

# =====================================================================
# FITUR: BUAT FILE BARU DI FOLDER AKTIF
# =====================================================================
if ! command -v micro &> /dev/null; then
  _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
  _pp
fi # end if micro installed check


# Kumpulkan folder tingkat pertama yang aktif saat ini
active_folders=()
for folder in "${targets[@]}"; do
  if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
    active_folders+=("$folder")
  fi # end if check active
done # end for targets

_in "Memetakan seluruh struktur sub-folder secara mendalam..."

# Tarik daftar sub-folder dari REMOTE (GitHub)
mapfile -t remote_dirs < <(git -C "$rp" ls-tree -r -d --name-only "origin/${current_branch}" 2>/dev/null)

# Tarik daftar sub-folder dari LOKAL (Termux) - PERBAIKAN PARAMETER: -type d
local_dirs=()
if [ -d "$rp" ]; then
  mapfile -t local_dirs < <(find "$rp" -type d 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git")
fi # end if rp folder exist

# Reset array agar tidak menumpuk saat menu diulang
valid_dirs=()

# PERBAIKAN: Selalu masukkan pilihan "." (Root Utama) ke dalam daftar tujuan
valid_dirs+=(".")

# Gabungkan Remote & Lokal ke dalam daftar validasi berdasarkan folder tingkat pertama yang aktif
for dir in "${active_folders[@]}" "${remote_dirs[@]}" "${local_dirs[@]}"; do
  # Bersihkan dari baris kosong atau root '.' atau nama folder repositori induk
  [ -z "$dir" ] && continue
  [[ "$dir" == "$rp" || "$dir" == "." || "$dir" == "$r" ]] && continue

  # Jika repositori masih kosong folder, masukkan saja semua struktur lokal terdeteksi
  if [ ${#targets[@]} -eq 0 ]; then
    if [[ ! " ${valid_dirs[*]} " =~ " ${dir} " ]]; then
      valid_dirs+=("$dir")
    fi
    continue
  fi

  for active_dir in "${active_folders[@]}"; do
    # Pastikan folder/sub-folder diawali atau cocok dengan folder induk yang aktif
    if [[ "$dir" == "$active_dir"/* || "$dir" == "$active_dir" ]]; then
      # Mencegah duplikasi data agar daftar tetap bersih
      if [[ ! " ${valid_dirs[*]} " =~ " ${dir} " ]]; then
        valid_dirs+=("$dir")
      fi # end if duplicate check
    fi # end if check match active
  done # end for active_dir
done # end for dir

# Urutkan secara alfabetis agar berurutan rapi dari folder induk ke sub-sub folder terujung
# PERBAIKAN: Menggunakan printf '%s\n' agar pengurutan array dengan sort -u 
# tetap akurat dan aman meskipun ada folder yang memiliki spasi
# Untuk Blok [nN]
mapfile -t sorted_dirs < <(printf '%s\n' "${valid_dirs[@]}" | sort -u)

# Tampilkan daftar semua folder & sub-folder secara instan
clear
_cc "========================================"
_cc "   PILIH STRUKTUR FOLDER TUJUAN         "
_cc "========================================"
echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
_cc "========================================"
for i in "${!sorted_dirs[@]}"; do
  if [ "${sorted_dirs[$i]}" == "." ]; then
    printf " [%d] / (Direktori Utama / Root)\n" $((i+1))
  else
    printf " [%d] /%s/\n" $((i+1)) "${sorted_dirs[$i]}"
  fi
done # end for display dirs
_cc "----------------------------------------"
_p "Pilih nomor folder tempat menaruh file baru"
read -r folder_num_pilihan

if [[ "$folder_num_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_num_pilihan" -ge 1 ] && [ "$folder_num_pilihan" -le "${#sorted_dirs[@]}" ]; then
  idx=$((folder_num_pilihan - 1))
  target_folder_path="${sorted_dirs[$idx]}"

  _cc "----------------------------------------"
  if [ "$target_folder_path" == "." ]; then
    echo -e "Folder tujuan terkunci: ${YELLOW}/ (Root)${NC}"
  else
    echo -e "Folder tujuan terkunci: ${YELLOW}/${target_folder_path}/${NC}"
  fi

  # REKOMENDASI TERBAIK: Informatif dengan visual warna hijau pada contoh input
  _p "Masukkan NAMA FILE BARU (Contoh: " "script.py" ")"
  read -r nama_file_murni

  if [ -z "$nama_file_murni" ]; then
    _e "Nama file tidak boleh kosong!"
    sleep 1
  else
    # AMAN & OTOMATIS: Hapus tanda garis miring di awal input jika user mengetik "/u3/README.md"
    # Ini mengubah "/u3/README.md" menjadi "u3/README.md" agar penggabungan path tidak rusak
    nama_file_bersih=$(echo "$nama_file_murni" | sed 's|^/||')
    # Tentukan path lengkap berdasarkan apakah user memilih root atau subfolder
    if [ "$target_folder_path" == "." ]; then
      full_new_file_path="${rp}/${nama_file_bersih}"
    else
      # Gabungkan jalur lengkap lokal secara presisi
      full_new_file_path="${rp}/${target_folder_path}/${nama_file_bersih}"
    fi

    # Mengambil path direktori induk (misal: /bash/bash_c/u3)
    new_parent_dir=$(dirname "$full_new_file_path")

    # Siapkan folder lokal fisik jika belum ada, lalu sentuh file barunya
    # JALUR UTAMA: Membuat semua folder/sub-folder baru secara otomatis jika belum ada
    mkdir -p "$new_parent_dir"

        # Membuat file kosong tiruan agar micro bisa langsung menyimpannya
    touch "$full_new_file_path"

    _in "Membuat dan membuka file baru dengan micro..."
    sleep 1.5
    micro "$full_new_file_path"
  fi # end if nama_file_murni kosong
else
  _an "Pilihan tidak valid."
  sleep 1
fi # end if folder_num_pilihan valid

