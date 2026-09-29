

```bash
  # OPSI HAPUS REPO DARI DAFTAR
  if [[ "$repo_pilihan" =~ ^[hH]$ ]]; then
    if [ ${#valid_repos[@]} -eq 0 ]; then
      _e "Tidak ada repositori yang bisa dihapus!"
      sleep 1.5
      continue
    fi

    _cr "----------------------------------------"
    _p "Pilih nomor repo yang ingin dibuang dari daftar"
    read -r hapus_num

    if [[ "$hapus_num" =~ ^[0-9]+$ ]] && [ "$hapus_num" -ge 1 ] && [ "$hapus_num" -le "${#valid_repos[@]}" ]; then
      idx_hapus=$((hapus_num - 1))
      repo_terhapus="${valid_repos[$idx_hapus]}"
      
      # PERBAIKAN UTAMA: Memisahkan nama owner dan nama repo secara akurat
      owner_name_only="${repo_terhapus%%/*}"
      repo_name_only="${repo_terhapus#*/}"
      
      # Jalur fisik riil repositori disesuaikan dengan jalur inisialisasi ($PWD/owner/repo)
      target_folder_fisik="${PWD}/${owner_name_only}/${repo_name_only}"
      target_owner_dir="${PWD}/${owner_name_only}"

      _pd "Anda yakin ingin menghapus '${repo_terhapus}' dari daftar ${repo_file}?"
      read -r konfirmasi_hapus

      if [[ "$konfirmasi_hapus" =~ ^[yY]$ ]]; then
        # Hapus dari array valid_repos
        valid_repos=("${valid_repos[@]:0:idx_hapus}" "${valid_repos[@]:idx_hapus+1}")
        fungsi_export_repo
        _o "'${repo_terhapus}' telah dihapus dari daftar ${repo_file}."

        # SISTEM PURGE FOLDER FISIK LOKAL (Jalur Riil Terperbaiki)
        if [ -d "$target_folder_fisik" ]; then
          # 1. DETEKSI BERKAS MODIFIED / UNTRACKED DI REPO YANG AKAN DIHAPUS
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
    continue
  fi

```

<br>

---

<br>

---

<br>

```bash
#!/bin/bash

# =====================================================================
# AMAN & DINAMIS: MEMBACA DAN MEMILIH REPOSITORI DARI FILE EKSTERNAL
# =====================================================================
repo_file="rp.txt" # Mengubah nama file target sesuai kebutuhan baru

# Pengaman awal: Membuat file rp.txt jika belum ada
if [ ! -f "$repo_file" ]; then
  _e "File eksternal '${repo_file}' tidak ditemukan!"
  _ic "Membuat file '${repo_file}' dengan struktur default otomatis..."
  cat << EOF > "$repo_file"
eucalypsih
    ey_rcrapsbash
    ey_rcrapsc
    eucalypsih_rcrapsbash
    ey_tp
    eucalypsih_rcrapskt

owner_lain
    repo1
    repo2
EOF
  sleep 1
fi # end if [ ! -f "$repo_file" ]


# Kode warna untuk notifikasi terminal (Standardisasi UX)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\e[36m' # warna CYAN untuk indikasi proses berjalan
NC='\033[0m' # No Color (Reset)

# =====================================================================
# SISTEM LOGGING & UX TERMINAL KUSTOM
# =====================================================================
_cr() { echo -e "${RED}$1${NC}"; }
_cc() { echo -e "${CYAN}$1${NC}"; } # _color_cyan() { ... }
_o()       { echo -e "${GREEN}[✓] $1${NC}"; } # log_ok
_on()    { echo -e ""; _o "$1"; } # Memanggil baris baru dulu, baru jalankan log_ok
_ic()     { echo -e "${CYAN}[~] $1${NC}"; } # log_info
# log_create()   { echo -e "${CYAN}[~] $1${NC}"; } # Fungsi untuk menampilkan status pembuatan atau inisialisasi file baru
_nc()     { echo -e "\n${CYAN}$1${NC}"; } # _color_cyan_end() { ... }
_in()     { echo -e "\n${CYAN}[~] $1${NC}"; } # _info_color_cyan_end() { ... } log_step berfungsi memberikan jarak visual/ruang sebelum menampilkan status proses baru di terminal
log_section()  { echo -e "${YELLOW}$1${NC}"; } # Fungsi untuk menampilkan judul section atau label daftar data di dalam menu

_c()   { echo -e "${YELLOW}[+] $1${NC}"; }
log_notify()   { echo -e "\n${YELLOW}[+] $1${NC}"; }
_r() { echo -e "${YELLOW}[!] $1${NC}"; } # log_redirect() { ... } Fungsi untuk menampilkan status navigasi atau pengalihan menu
_rn() { echo -e "\n${YELLOW}[!] $1${NC}"; } # Fungsi untuk menampilkan status navigasi atau pengalihan menu
_w()     { echo -e "${YELLOW}[ ⚠️ ] Peringatan: $1${NC}"; } # log_warn
_hn()  { echo -e "\n${RED}[!] $1${NC}"; } # lo_halt
_e()      { echo -e "${RED}[X] ERROR: $1${NC}"; } # log_err
log_fatal()    { echo -e "${RED}[X] FATAL ERROR: $1${NC}"; } # Fungsi untuk menampilkan kesalahan fatal (Fatal Error) sebelum skrip berhenti
log_detail()  { echo -e "${YELLOW}     -> $1${NC}"; }
# log_success() { echo -e "${GREEN}[✓] Sukses: $1${NC}"; }
_ls() { # log_success
  if [ -n "$2" ]; then
    # log_success "Branch saat ini terdeteksi" "$current_branch"
    echo -e "${GREEN}[✓] $1: ${YELLOW}$2${NC}"; # echo -e "${GREEN}[✓] Branch saat ini terdeteksi: ${YELLOW}${current_branch}${NC}"
  else
    echo -e "${GREEN}[✓] Sukses: $1${NC}";
  fi
}
_p() {
  if [ -n "$3" ]; then
    # Jika ada argumen kedua, kita cetak teks kustom dengan warna dinamis
    echo -e -n "${YELLOW}[~] $1${GREEN}$2${YELLOW}$3${NC}"
  else
    # Jika hanya satu argumen, cetak prompt standar kuning
    echo -e -n "${YELLOW}[~] $1: ${NC}" # prompt() { ... } Fungsi untuk mencetak teks tanpa baris baru (biasanya untuk menunggu input 'read')
  fi
}

_a()      { echo -e "${RED}[X] $1${NC}"; }
_an()   { echo -e "\n${RED}[X] $1${NC}"; } # Fungsi untuk pembatalan / keluar dari skrip (menyertakan baris baru di awal)

# Fungsi untuk meminta konfirmasi tindakan berbahaya (menunggu input 'read')
_pd() { # prompt_danger
  echo -e -n "${RED}[⚠️] $1 (y/n): ${NC}";
}
# Fungsi untuk menampilkan peringatan kritis/bahaya (dengan baris baru di awal)
log_critical() {
  # echo -e "\n${RED}[⚠️] PERINGATAN KRITIS: Folder lokal fisik terdeteksi di:${NC}"
  echo -e "\n${RED}[⚠️] PERINGATAN KRITIS: $1${NC}";
}

# Fungsi untuk menahan layar dan meminta konfirmasi kembali (menunggu input 'read')
_pp() { # prompt_pause
  echo -e -n "${YELLOW}Tekan [Enter] untuk kembali...${NC}"
  read -r
}



# =====================================================================
# AMAN & DINAMIS: MEMBACA DAN MEMILIH REPOSITORI DARI FILE EKSTERNAL
# =====================================================================
# Pengaman awal: Membuat file repo.txt jika belum ada
if [ ! -f "$repo_file" ]; then
  _e "File eksternal '${repo_file}' tidak ditemukan!"
  _ic "Membuat file '${repo_file}' default otomatis..."
  # echo -e "eucalypsih\ney_rcrapsbash\ney_repo2\ney_repo3\ney_repo4" > "$repo_file"
  cat << 'EOF' > "$repo_file"
eucalypsih
  ey_rcrapsbash
EOF
  sleep 1
fi # end if [ ! -f "$repo_file" ]
# =====================================================================
# MENU SELEKSI & MANAJEMEN REPOSITORI UTAMA (BERWARNA & FLEKSIBEL)
# =====================================================================
# =====================================================================
# MENU SELEKSI & MANAJEMEN REPOSITORI UTAMA (BERWARNA & FLEKSIBEL)
# =====================================================================
while true; do
  # --- PROSES IMPORT: Membaca berkas terstruktur rp.txt ke format fleksibel owner/repo ---
  valid_repos=()
  current_owner=""
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[:space:]/}" ]] && continue
    if [[ "$line" =~ ^[[:space:]]+ ]]; then
      repo=$(echo "$line" | xargs)
      if [ -n "$current_owner" ]; then
        valid_repos+=("$current_owner/$repo")
      fi
    else
      current_owner=$(echo "$line" | xargs)
    fi
  done < "$repo_file"

  # Fungsi pembantu internal untuk meng-export kembali array ke file rp.txt
  fungsi_export_repo() {
    local last_owner=""
    > "$repo_file"
    for item in "${valid_repos[@]}"; do
      local owner="${item%%/*}"
      local repo="${item#*/}"
      if [[ "$owner" != "$last_owner" ]]; then
        [[ -n "$last_owner" ]] && echo "" >> "$repo_file"
        echo "$owner" >> "$repo_file"
        last_owner="$owner"
      fi
      echo "    $repo" >> "$repo_file"
    done
  }

  clear
  _cc "========================================"
  _cc "       PILIH REPOSITORI UTAMA           "
  _cc "========================================"
  log_section "Daftar Repositori Aktif (Format: owner/repo):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Cek apakah folder repo lokal fisik sudah ada berdasarkan nama reponya saja
      local_repo_name="${valid_repos[$i]#*/}"
      if [ -d "${PWD}/${local_repo_name}/.git" ]; then
        printf " [%d] %-30s %b[ lokal aktif ]%b\n" $((i+1)) "${valid_repos[$i]}" "${GREEN}" "${NC}"
      else
        printf " [%d] %-30s\n" $((i+1)) "${valid_repos[$i]}"
      fi
    done
  fi

  _cc "----------------------------------------"
  echo -e " [t] ${GREEN}Tambah Repositori Baru${NC}"
  echo -e " [h] ${RED}Hapus Repo dari Daftar${NC}"
  echo -e " [q] ${RED}Keluar dari Skrip${NC}"
  _cc "========================================"
  _p "Masukkan pilihan Anda"
  read -r repo_pilihan

  # OPSI KELUAR
  if [[ "$repo_pilihan" =~ ^[qQ]$ ]]; then
    _an "Proses dibatalkan. Keluar dari skrip."
    exit 0
  fi

  # OPSI TAMBAH REPO BARU (Mendukung input owner/repo secara fleksibel)
  if [[ "$repo_pilihan" =~ ^[tT]$ ]]; then
    _cc "----------------------------------------"
    _p "Masukkan repositori baru (Format: owner/repo atau cuma nama_repo)"
    read -r repo_baru
    repo_bersih=$(echo "$repo_baru" | tr -d '[:space:]')

    if [ -z "$repo_bersih" ]; then
      _e "Input tidak boleh kosong!"
      sleep 1.5
    else
      # Jika user tidak memasukkan owner, gunakan default 'eucalypsih'
      if [[ "$repo_bersih" != */* ]]; then
        repo_bersih="eucalypsih/$repo_bersih"
      fi

      if [[ " ${valid_repos[*]} " =~ " ${repo_bersih} " ]]; then
        _w "Repositori '${repo_bersih}' sudah ada dalam daftar."
      else
        valid_repos+=("$repo_bersih")
        fungsi_export_repo
        _o "'${repo_bersih}' berhasil ditambahkan ke ${repo_file}."
      fi
      sleep 1.5
    fi
    continue
  fi

  # OPSI HAPUS REPO DARI DAFTAR
  if [[ "$repo_pilihan" =~ ^[hH]$ ]]; then
    if [ ${#valid_repos[@]} -eq 0 ]; then
      _e "Tidak ada repositori yang bisa dihapus!"
      sleep 1.5
      continue
    fi

    _cr "----------------------------------------"
    _p "Pilih nomor repo yang ingin dibuang dari daftar"
    read -r hapus_num

    if [[ "$hapus_num" =~ ^[0-9]+$ ]] && [ "$hapus_num" -ge 1 ] && [ "$hapus_num" -le "${#valid_repos[@]}" ]; then
      idx_hapus=$((hapus_num - 1))
      repo_terhapus="${valid_repos[$idx_hapus]}"

      # PERBAIKAN UTAMA: Memisahkan nama owner dan nama repo secara akurat
      owner_name_only="${repo_terhapus%%/*}"
      repo_name_only="${repo_terhapus#*/}"

      # Jalur fisik riil repositori disesuaikan dengan jalur inisialisasi ($PWD/owner/repo)
      target_folder_fisik="${PWD}/${owner_name_only}/${repo_name_only}"
      target_owner_dir="${PWD}/${owner_name_only}"

      _pd "Anda yakin ingin menghapus '${repo_terhapus}' dari daftar ${repo_file}?"
      read -r konfirmasi_hapus

      if [[ "$konfirmasi_hapus" =~ ^[yY]$ ]]; then
        # Hapus dari array
        valid_repos=("${valid_repos[@]:0:idx_hapus}" "${valid_repos[@]:idx_hapus+1}")
        fungsi_export_repo
        _o "'${repo_terhapus}' telah dihapus dari daftar ${repo_file}."

        # SISTEM PURGE FOLDER FISIK LOKAL
        if [ -d "$target_folder_fisik" ]; then
          # 1. DETEKSI BERKAS MODIFIED / UNTRACKED DI REPO YANG AKAN DIHAPUS
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
    continue
  fi

  # PROSES SELEKSI REPOSITORI BERDASARKAN ANGKA
  if [[ "$repo_pilihan" =~ ^[0-9]+$ ]] && [ "$repo_pilihan" -ge 1 ] && [ "$repo_pilihan" -le "${#valid_repos[@]}" ]; then
    idx=$((repo_pilihan - 1))
    
    # Memisahkan owner dan nama repo menggunakan String Manipulation Bash (Rekomendasi Utama)
    string_gabung="${valid_repos[$idx]}"
    o="${string_gabung%%/*}"  # Mengunci nama owner secara dinamis
    r="${string_gabung#*/}"   # Mengunci nama repo saja

    _on "Repositori dipilih" "$string_gabung"
    _ic "Mengunci jalur kerja lokal proyek..."
    sleep 1
    break
  else
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], atau [q]."
    sleep 1.5
  fi
done # end while menu utama


# Menentukan jalur kerja repositori yang dipilih di dalam direktori aktif saat ini
# Menggunakan direktori aktif saat skrip dijalankan (pwd) + nama_owner + nama_repo
rp="${PWD}/${o}/${r}"


# =====================================================================
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
# =====================================================================
current_branch="main" # Nilai default awal

if [ -d "$rp/.git" ]; then
  # Mengambil nama branch saat ini
  detected_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
  
  # PERBAIKAN: Memeriksa apakah $detected_branch tidak kosong
  if [ -n "$detected_branch" ]; then
    current_branch="$detected_branch"
    _o "Sukses Branch saat ini terdeteksi" "$current_branch"
  else
    _e "Branch tidak ditemukan!"
    exit 1
  fi # end if detected_branch
else
  # PERBAIKAN: Menangani kondisi jika direktori .git tidak ada
  # Pengecekan awal dilewati jika folder belum di-clone
  _ic "Menyiapkan alur kloning untuk direktori baru..."
  # exit 1  <-- HAPUS ATAU KOMENTARI BARIS INI
fi # end if git dir check

sleep 2.5

# =====================================================================


# =====================================================================
# PENGAMAN: DETEKSI JIKA RP ADALAH FILE BIASA (BUKAN FOLDER)
# =====================================================================
# PENANGANAN ERROR: Cek apakah jalur rp terhalang oleh file biasa
if [ -e "$rp" ] && [ -f "$rp" ] && [ ! -d "$rp" ]; then
  echo -e "${RED}[!] CRITICAL ERROR: Jalur '${rp}' sudah ada, terdeteksi sebagai FILE BIASA!, bukan FOLDER!${NC}"
  echo -e "${RED}[X] CRITICAL ERROR: Jalur '${rp}' terhalang FILE BIASA!${NC}"
  _cr "Hal ini menghalangi skrip untuk membuat folder repositori."
  _pd "Apakah Anda ingin menghapus file tersebut agar bisa melanjutkan?"
  read -r hapus_file

  if [[ "$hapus_file" =~ ^[yY]$ ]]; then
    _ic "Menghapus file penghalang..."
    rm -f "$rp"
  else
    _a "Proses dibatalkan. Silakan pindahkan atau hapus file tersebut secara manual."
    exit 1
  fi # end if hapus_file
fi # end if file biasa check

# =====================================================================
# MANAJEMEN SSH KEY & PENGAMAN SEBELUM CLONE: UNDUH SSH KEY DINAMIS BERDASARKAN OWNER
# =====================================================================
_ic "Mengonfigurasi SSH Key dinamis untuk owner: ${o}..."

# Jalur SSH Key spesifik untuk masing-masing owner
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

# Unduh SSH Key secara otomatis jika belum ada di lokal
# Jalankan unduhan otomatis jika berkas key belum tersedia di penyimpanan lokal
if [ ! -f "$owner_privkey" ]; then
  _ic "Mengunduh SSH Key untuk ${o} dari remote repository... / Mengunduh SSH Key dinamis untuk owner: ${o}..."

  # Amankan hak akses folder .ssh terlebih dahulu
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

  # Menggunakan subshell dengan umask ketat untuk file private key
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

  # Menggunakan umask standar untuk public key
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
  _o "Kredensial SSH untuk ${o} berhasil disiapkan."
fi

  # Validasi akhir apakah file key berhasil dibuat
  if [ -f "$owner_privkey" ] && [ -f "$owner_pubkey" ]; then
    _o "SSH Key untuk ${o} berhasil diverifikasi."
  else
    log_fatal "Kredensial SSH tidak lengkap. Skrip dihentikan."
    exit 1
  fi



# Clone repositori tanpa checkout (jika folder belum ada)
if [ ! -d "$rp" ]; then
  # =====================================================================
  # VALIDASI INTERNET UNTUK PROSES KLONING AWAL
  # =====================================================================
  _ic "Memeriksa jaringan sebelum melakukan kloning repositori..."

  if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    log_fatal "Anda sedang OFFLINE! Kloning awal repositori baru memerlukan koneksi internet."
    _a "Skrip dihentikan. Silakan aktifkan koneksi internet Anda terlebih dahulu."
    exit 1
  fi
  # =====================================================================
  
  _ic "Koneksi terverifikasi. Mengkloning repositori ke ${rp}..."

  # MEMBUAT FOLDER INDUK (OWNER) DENGAN AMAN SEBELUM CLONE
  mkdir -p "$(dirname "$rp")"

  _ic "Mengkloning repositori ke ${rp} menggunakan key ${o}..."
  # Variabel ${o} dan ${r} sekarang fleksibel mengikuti pemilik aslinya dari berkas rp.txt
  if ! git clone -q --filter=blob:none --no-checkout \
    -c "core.sshCommand=ssh -i ${owner_privkey} -o IdentitiesOnly=yes" \
    git@github.com:${o}/${r}.git "$rp"; then
    log_fatal "Gagal melakukan git clone! Periksa koneksi internet atau SSH Key Anda."
    exit 1
  fi # end if clone success
  _o "Kloning berhasil dilakukan."
  sleep 0.5
fi # end if rp terdeteksi

# Mengambil daftar sparse saat ini di awal untuk pengecekan inisialisasi
current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

# PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
if [ -z "$current_sparse" ]; then
  _ic "Menyiapkan inisialisasi awal sparse-checkout..."
    
  # Inisialisasi awal sparse-checkout dengan README.md
  git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' && sleep 0.5

  # =====================================================================
  # KONFIGURASI GIT DINAMIS BERDASARKAN OWNER
  # =====================================================================

  # Jalankan loop konfigurasi lokal repositori secara otomatis
  # SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis  # Terapkan konfigurasi internal Git secara otomatis
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
  # Perbarui variabel setelah inisialisasi pertama selesai
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
else
  _o "Repositori terdeteksi sudah terinisialisasi."

  # =====================================================================
  # MODUL VALIDASI KONEKSI JARINGAN (PENCEGAHAN OFFLINE CRASH)
  # =====================================================================
  _ic "Memperbarui informasi struktur folder dari remote..."

  # Ping ke Google DNS dengan timeout 2 detik untuk validasi status online
  if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    _ic "Koneksi online terverifikasi. Memperbarui struktur remote..."

    # Eksekusi fetch jika jaringan aman
    if git -C "$rp" fetch -q origin "$current_branch" 2>/dev/null; then
      _o "menarik data terbaru dari origin/${current_branch}"
      echo "------------------------------------------------"
      sleep 1.2
    else
      _e "Gagal terhubung ke remote server GitHub!"
      _p "Apakah ingin memuat menu dengan cache lokal lama? (y/n)"
      read -r konfirmasi
      if [[ ! "$konfirmasi" =~ ^[yY]$ ]]; then
        _a "Membatalkan proses. Keluar dari skrip."
        exit 1
      fi
    fi # end if fetch remote
  else
    # Proteksi jika terdeteksi jaringan offline/tanpa internet
    _w "Anda sedang OFFLINE! Tidak dapat memvalidasi data remote terbaru."
    _p "Apakah Anda ingin tetap masuk menggunakan cache lokal lama? (y/n)"
    read -r konfirmasi_offline

    if [[ "$konfirmasi_offline" =~ ^[yY]$ ]]; then
      _o "Mengaktifkan mode cache lokal. Struktur remote tidak diperbarui."
      echo "------------------------------------------------"
      sleep 1.5
    else
      _a "Proses dibatalkan oleh pengguna akibat kendala jaringan."
      exit 1
    fi # end if konfirmasi cache
  fi
fi # end if current_sparse

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Folder Tingkat Pertama)
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null)

if [ ${#targets[@]} -eq 0 ]; then
    # Alih-alih keluar (exit 1), berikan peringatan visual saja dan biarkan skrip berlanjut
    _w "Repositori saat ini tidak memiliki folder (hanya berisi file root)."
    sleep 1.5
fi # end if target kosong

# MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  _cc "========================================"
  _cc "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  _cc "========================================"
  log_section "Daftar folder otomatis dari Remote:"

  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
      printf " [%d] /%-12s  %b[ sudah aktif ]%b\n" $((i+1)) "$folder" "${GREEN}" "${NC}"
    else
      printf " [%d] /%-12s\n" $((i+1)) "$folder"
    fi # end if folder check
  done # end for targets

  _cc "----------------------------------------"
  echo -e " [e] ${GREEN}Edit File (Jelajahi Folder Aktif)${NC}"
  echo -e " [n] ${GREEN}Buat File Baru di Folder Aktif${NC}"
  echo -e " [d] ${RED}Hapus File atau Sub-Folder (Git RM)${NC}" # <-- TAMBAHKAN BARIS INI
  echo -e " [q] ${RED}Keluar & Terapkan Perubahan (Checkout)${NC}"
  _cc "========================================"
  _p "Masukkan pilihan Anda"
  read -r pilihan

  # =====================================================================
  # POTONGAN KODE PERBAIKAN UNTUK LOGIKA KELUAR [q] (KOMPARASI LOG & AUTO-PUSH)
  # =====================================================================
  case "$pilihan" in
    [qQ])
      # =====================================================================
      # SOLUSI AMAN: Menyaring git status agar mengabaikan efek sparse-checkout
      # Hanya mendeteksi berkas baru (??), modifikasi (M), atau hapus riil (ditrack lalu di-rm)
      # =====================================================================
      perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null | grep -E '^([ MAU?][M?]|[^D] )')

      # JIKA ADA PERUBAHAN YANG BELUM DI-COMMIT
      if [ -n "$perubahan_lokal" ]; then
        _w "Ada file yang telah Anda ubah/tambahkan secara lokal!"
        echo "$perubahan_lokal"
        echo "----------------------------------------"
        echo "Pilih tindakan Anda:"
        echo -e " [1] ${GREEN}Simpan perubahan (Commit secara lokal)${NC}"
        echo -e " [2] ${RED}Abaikan & Paksa update (Buang hasil editan Anda)${NC}"
        echo -e " [3] ${YELLOW}Abaikan & Batalkan Keluar (Kembali ke menu)${NC}"
        _cc "----------------------------------------"
        _p "Pilihan Anda (1/2/3)"
        read -r aksi_keluar

        if [ "$aksi_keluar" == "1" ]; then
          # LAPIS PENGAMAN KRITIS MENCEGAH HUMAN ERROR
          log_critical "Tindakan ini akan merekam perubahan (termasuk penghapusan) ke Git!"
          _p "Ketik 'COMMIT' (huruf besar) untuk melanjutkan konfirmasi"
          read -r verifikasi_aman

          if [ "$verifikasi_aman" != "COMMIT" ]; then
            _an "Verifikasi gagal! Tindakan dibatalkan demi keamanan repositori Anda."
            sleep 2
            continue # Kembali ke menu seleksi folder sparse, tidak jadi keluar
          fi


          # Generator Auto-Increment Pesan Commit
          last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
          if [[ "$last_num" =~ ^[0-9]+$ ]]; then
            next_num=$((last_num + 1))
            auto_msg="u${next_num}"
          else
            auto_msg="u1"
          fi # end if last_num

          echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
          _p "Tekan [Enter] untuk auto-msg, atau ketik pesan manual"
          read -r pesan_commit
          [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"
        
          git -C "$rp" add .
          git -C "$rp" commit -m "$pesan_commit"
          _o "Perubahan berhasil disimpan ke commit lokal!"
        elif [ "$aksi_keluar" == "2" ]; then
          _w "Membuang perubahan lokal dan melakukan paksa checkout..."
          git -C "$rp" checkout -f "$current_branch" 2>/dev/null
        else
          _r "Kembali ke menu utama..."
          sleep 1
          continue
        fi # end if aksi_keluar pilihan
      else
        # Jika tidak ada uncommitted changes, langsung jalankan checkout sparse
        git -C "$rp" checkout "$current_branch" 2>/dev/null
      fi # end if perubahan_lokal

      # KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE
      _nc "========================================"
      _cc "       PERBANDINGAN STATUS COMMIT       "
      _cc "========================================"

      # Mengambil hash dan subjek commit terakhir dari lokal dan remote
      local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
      remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)
  
      echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
      echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
      _cc "----------------------------------------"

      # Cek apakah lokal berada di depan remote (butuh push)
      ahead_commits=$(git -C "$rp" rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null)

      if [ "${ahead_commits:-0}" -gt 0 ]; then
        _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
        _p "Apakah Anda yakin ingin melakukan PUSH ke GitHub sekarang? (y/n)"
        read -r konfirmasi_push
      
        if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
          _ic "Melakukan git push origin ${current_branch}..."
          if git -C "$rp" push origin "${current_branch}"; then
            _o "Push berhasil! Repositori GitHub telah diperbarui."
          else
            _a "Gagal melakukan push! Periksa koneksi atau kredensial SSH Anda."
          fi # end if push success
        else
          _r "Push dibatalkan. Perubahan Anda tetap tersimpan di lokal."
        fi # end if konfirmasi_push
      else
        _o "Status: Sinkron! Log Local sama dengan Remote."
      fi # end if ahead_commits

      _on "Selesai dengan sukses! Keluar dari skrip."
      break
      ;;


    [dD])
      # =====================================================================
      # FITUR BARU: HAPUS FILE ATAU SUB-DIREKTORI (DENGAN OTOMATISASI GIT RM)
      # =====================================================================
      active_folders=()
      for folder in "${targets[@]}"; do
        if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
          active_folders+=("$folder")
        fi
      done

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

        if [ ${#all_local_items[@]} -eq 0 ]; then
          _rn "Tidak ada file atau sub-folder lokal yang dapat dihapus."
          _pp
        else
          clear
          _cc "========================================"
          _cc "     HAPUS FILE / SUB-DIREKTORI         "
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
      ;;

    [nN])
      # =====================================================================
      # FITUR: BUAT FILE BARU DI FOLDER AKTIF
      # =====================================================================
      if ! command -v micro &> /dev/null; then
        _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
        _pp
      else

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
      fi # end if micro installed check
      ;; # Menutup opsi [nN] dengan benar

    [eE])
      # =====================================================================
      # FITUR: JELAJAHI DAN EDIT SELURUH FILE
      # =====================================================================
      if ! command -v micro &> /dev/null; then
        _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
        _pp
      else
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

          # PERBAIKAN: Jika target kosong (tidak ada folder remote), izinkan edit semua file di root (seperti README.md)
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

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Folder aktif Anda kosong (tidak ada file untuk diedit / Tidak ada file yang dapat diedit)."
          _pp
        else
          # Tampilkan sub-menu seluruh file yang tersedia untuk diedit
          clear
          _cc "========================================"
          _cc "   DAFTAR FILE YANG DAPAT DIEDIT        "
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
      ;;

    [0-9]*)
      # =====================================================================
      # LOGIKA UTAMA: JIKA INPUT ADALAH ANGKA (ADD FOLDER UTAMA)
      # =====================================================================
      if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
        idx=$((pilihan - 1))
        selected_folder="${targets[$idx]}"

        # Cek jika folder sudah aktif
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
            new_sparse_list=()
            # Pastikan README.md atau rules default dasar tetap ada
            new_sparse_list+=("!/*" "/README.md")

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
          _ic "Menambahkan /${selected_folder} ke sparse-checkout..."
          if git -C "$rp" sparse-checkout add "/${selected_folder}"; then
            # Paksa penarikan fisik berkas baru dari indeks remote Git
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

      # OPTIMASI KRUSIAL: Lewati fungsi prompt_pause bawaan agar menu utama langsung
      # me-refresh dan memperbarui status visual [ sudah aktif ] secara real-time.
      continue
      ;;

    *)
      # =====================================================================
      # JIKA INPUT TIDAK COCOK DENGAN OPSI APAPUN
      # =====================================================================
      _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
      echo ""
      _pp
      ;;
  esac # end case pilihan

done # end while menu interaktif

```




<br>
