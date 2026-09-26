

aa: 
Untuk menambahkan fitur menonaktifkan (*disable / remove*) folder yang statusnya `[ sudah aktif ]` pada menu **SISTEM SELEKSI SPARSE-CHECKOUT**, Anda perlu memodifikasi logika pilihan angka (`[0-9]*`) pada struktur `case "$pilihan" in`.

Saat ini, jika angka yang dipilih sudah aktif, skrip hanya menampilkan pesan peringatan `_hn "Ops! Folder ... sudah aktif..."`. Kita akan mengubahnya agar skrip memberikan opsi atau langsung menghapus folder tersebut dari daftar *sparse-checkout* menggunakan perintah `git sparse-checkout set` dengan menyaring daftar folder yang ada.

Berikut adalah langkah-langkah perubahan kode beserta potongan kode barunya:

## 🛠️ Bagian Kode yang Harus Diubah
Cari blok kode berikut di bagian paling bawah (`[0-9]*)`) di dalam skrip Anda:
```bash
    [0-9]*)
      # =====================================================================
      # LOGIKA UTAMA: JIKA INPUT ADALAH ANGKA (ADD FOLDER UTAMA)
      # =====================================================================
      if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
        idx=$((pilihan - 1))
        selected_folder="${targets[$idx]}"

        if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
          _hn "Ops! Folder /${selected_folder} sudah aktif ada di dalam daftar sparse-list."
        else
          _n "Menambahkan /${selected_folder} ke sparse-checkout..."
          git -C "$rp" sparse-checkout add "/${selected_folder}"
          sleep 0.5
          _o "Berhasil ditambahkan!"
        fi # end if check sparse list
      else
        _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
      fi # end if target selection check

      echo ""
      _pp
      ;;

```

## 💾 Ganti dengan Kode Baru Ini
Ganti seluruh blok `[0-9]*`) di atas dengan kode di bawah ini:
```bash
    [0-9]*)
      # =====================================================================
      # LOGIKA UTAMA: ADD / REMOVE FOLDER UTAMA (SPARSE-CHECKOUT)
      # =====================================================================
      if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
        idx=$((pilihan - 1))
        selected_folder="${targets[$idx]}"

        # Cek jika folder sudah aktif
        if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
          _w "Folder /${selected_folder} saat ini sedang AKTIF."
          _pd "Apakah Anda ingin MENONAKTIFKAN (menghapus) folder ini dari sparse-list?"
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
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan!"
            else
              _e "Gagal memperbarui sparse-checkout list."
            fi
          else
            _c "Tindakan dibatalkan. Folder tetap aktif."
          fi
        else
          # Jika belum aktif, maka lakukan proses ADD seperti semula
          _n "Menambahkan /${selected_folder} ke sparse-checkout..."
          git -C "$rp" sparse-checkout add "/${selected_folder}"
          sleep 0.5
          _o "Berhasil ditambahkan!"
        fi # end if check sparse list
      else
        _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
      fi # end if target selection check

      echo ""
      _pp
      ;;

```

## 💡 Cara Kerja Fitur Baru Ini:
1. Deteksi Otomatis: Saat Anda memilih angka yang foldernya berstatus `[ sudah aktif ]`, skrip tidak lagi langsung memblokir.
2. Konfirmasi Pengguna: Skrip akan memunculkan prompt interaktif `(y/n)` menanyakan apakah Anda benar-benar ingin menonaktifkannya.
3. Filter Dinamis: Jika dijawab `y`, skrip akan membaca konfigurasi *sparse-list* saat ini, membuang folder yang Anda pilih dari memori, menjaga file wajib seperti `/README.md`, lalu menulis ulang aturan baru menggunakan perintah `git sparse-checkout set`.
4. Sinkronisasi Instan: Folder tersebut akan langsung menghilang dari daftar lokal fisik begitu Anda keluar menggunakan menu `[q]` (proses checkout otomatis dijalankan ulang).

<br>

qa: 
Apakah Anda ingin menambahkan fitur **otomatis menghapus folder fisik lokal** yang dinonaktifkan tersebut saat itu juga, atau cukup konfirmasi **penghapusan dari Git index** saja seperti di atas?

<br>

---

<br>

```bash
#!/bin/bash

o="eucalypsih"
repo_file="rf.txt"


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
_cc() { echo -e "${CYAN}$1${NC}"; }
_o()       { echo -e "${GREEN}[✓] $1${NC}"; } # log_ok
_on()    { echo -e ""; _o "$1"; } # Memanggil baris baru dulu, baru jalankan log_ok
_ic()     { echo -e "${CYAN}[~] $1${NC}"; } # log_info
log_create()   { echo -e "${CYAN}[~] $1${NC}"; } # Fungsi untuk menampilkan status pembuatan atau inisialisasi file baru
_n()     { echo -e "\n${CYAN}[~] $1${NC}"; } # log_step berfungsi memberikan jarak visual/ruang sebelum menampilkan status proses baru di terminal
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
  echo -e "ey_rcrapsbash\ney_repo2\ney_repo3\ney_repo4" > "$repo_file"
  sleep 1
fi # end if [ ! -f "$repo_file" ]

# =====================================================================
# MENU SELEKSI & MANAJEMEN REPOSITORI UTAMA (BERWARNA)
# =====================================================================
while true; do
  # Membaca daftar repo dari file ke dalam array secara dinamis setiap kali menu diulang
  # Membaca isi repo.txt ke dalam array
  mapfile -t daftar_repo < "$repo_file"

  # Bersihkan elemen array yang kosong
  # Menyaring elemen array dari baris kosong
  valid_repos=()
  for repo in "${daftar_repo[@]}"; do
    [ -n "$repo" ] && valid_repos+=("$repo")
  done # end for repo

  clear
  _cc "========================================"
  _cc "       PILIH REPOSITORI UTAMA           "
  _cc "========================================"
  log_section "Daftar Repositori di GitHub (${o}):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Cek apakah folder repo lokal fisik sudah ada/pernah di-clone sebelumnya
      if [ -d "${PWD}/${valid_repos[$i]}/.git" ]; then
        printf " [%d] %-20s %b[ lokal aktif ]%b\n" $((i+1)) "${valid_repos[$i]}" "${GREEN}" "${NC}"
      else
        printf " [%d] %-20s\n" $((i+1)) "${valid_repos[$i]}"
      fi # end if [ -d ... ]
    done # end for i
  fi # end if [ ${#valid_repos[@]} -eq 0 ]

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
  fi # end if q

  # OPSI TAMBAH REPO BARU
  if [[ "$repo_pilihan" =~ ^[tT]$ ]]; then
    _cc "----------------------------------------"
    _p "Masukkan nama repositori baru (tanpa .git)"
    read -r repo_baru

    # Validasi agar input tidak kosong dan tidak mengandung spasi liar
    repo_bersih=$(echo "$repo_baru" | tr -d '[:space:]')

    if [ -z "$repo_bersih" ]; then
      _e "Nama repositori tidak boleh kosong!"
      sleep 1.5
    else
      # Cek apakah repo sudah ada di dalam daftar untuk mencegah duplikasi
      if [[ " ${valid_repos[*]} " =~ " ${repo_bersih} " ]]; then
        _w "Repositori '${repo_bersih}' sudah ada dalam daftar."
      else
        # Memasukkan nama repo baru ke baris paling bawah file repo.txt
        echo "$repo_bersih" >> "$repo_file"
        _o "'${repo_bersih}' berhasil ditambahkan ke ${repo_file}."
      fi # end if duplikasi
      sleep 1.5
    fi # end if kosong
    continue # Ulangi loop menu untuk memuat ulang daftar repo terbaru
  fi # end if t

  # OPSI HAPUS REPO DARI DAFTAR (Fitur Baru)
  # PROSES SELEKSI REPOSITORI BERDASARKAN ANGKA
  if [[ "$repo_pilihan" =~ ^[hH]$ ]]; then
    if [ ${#valid_repos[@]} -eq 0 ]; then
      _e "Tidak ada repositori yang bisa dihapus!"
      sleep 1.5
      continue
    fi # end if kosong

    _cr "----------------------------------------"
    _p "Pilih nomor repo yang ingin dibuang dari daftar"
    read -r hapus_num

    # Validasi input angka dan jangkauan index array
    if [[ "$hapus_num" =~ ^[0-9]+$ ]] && [ "$hapus_num" -ge 1 ] && [ "$hapus_num" -le "${#valid_repos[@]}" ]; then
      idx_hapus=$((hapus_num - 1))
      repo_terhapus="${valid_repos[$idx_hapus]}"
      target_folder_fisik="${PWD}/${repo_terhapus}"

      # echo -e -n "${RED}[⚠️] Anda yakin ingin menghapus '${repo_terhapus}' dari daftar repo.txt? (y/n): ${NC}"
      _pd "Anda yakin ingin menghapus '${repo_terhapus}' dari daftar repo.txt?"
      read -r konfirmasi_hapus

      if [[ "$konfirmasi_hapus" =~ ^[yY]$ ]]; then
        # Membuat file sementara untuk menulis ulang daftar tanpa item yang dihapus
        tmp_file=$(mktemp)
        for repo in "${valid_repos[@]}"; do
          if [ "$repo" != "$repo_terhapus" ]; then
            echo "$repo" >> "$tmp_file"
          fi # end if repo
        done # end for repo
        mv "$tmp_file" "$repo_file"
        _o "'${repo_terhapus}' telah dihapus dari daftar repo.txt."

        # =============================================================
        # FITUR BARU: SISTEM PURGE FOLDER FISIK LOKAL
        # =============================================================
        if [ -d "$target_folder_fisik" ]; then
          # echo -e "\n${RED}[⚠️] PERINGATAN KRITIS: Folder lokal fisik terdeteksi di:${NC}"
          log_critical "Folder lokal fisik terdeteksi di:"
          # echo -e "${YELLOW}     -> ${target_folder_fisik}${NC}"
          log_detail "$target_folder_fisik"
          _pd "HAPUS PERMANEN folder fisik tersebut beserta seluruh representsi filenya?"
          read -r konfirmasi_fisik

          if [[ "$konfirmasi_fisik" =~ ^[yY]$ ]]; then
            _ic "Memusnahkan folder fisik lokal: ${repo_terhapus}..."
            rm -rf "$target_folder_fisik"
            _o "$Folder fisik berhasil dihapus sepenuhnya dari penyimpanan."
          else
            # echo -e "${YELLOW}[i] Folder fisik lokal dipertahankan dan tetap aman.${NC}"
            _w "Folder fisik lokal dipertahankan dan tetap aman."
          fi # end if konfirmasi_fisik
        fi # end if folder fisik
        # =============================================================
        # Sinkronisasi Instan: Muat ulang array agar loop menu berikutnya langsung bersih
        mapfile -t daftar_repo < "$repo_file"
        valid_repos=()
        for repo in "${daftar_repo[@]}"; do
          [ -n "$repo" ] && valid_repos+=("$repo")
        done

      else
        # echo -e "${YELLOW}[+] Penghapusan dibatalkan.${NC}"
        _c "Penghapusan dibatalkan."
      fi # end if konfirmasi_hapus
    else
      _e "Pilihan nomor tidak valid!"
    fi # end if validasi angka
    sleep 1.5
    continue # Kembali ke awal 'while true' dengan layar yang akan di-clear bersih
  fi # end if h

  # PROSES SELEKSI REPOSITORI BERDASARKAN ANGKA
  if [[ "$repo_pilihan" =~ ^[0-9]+$ ]] && [ "$repo_pilihan" -ge 1 ] && [ "$repo_pilihan" -le "${#valid_repos[@]}" ]; then
    idx=$((repo_pilihan - 1))
    r="${valid_repos[$idx]}"

    _on "Repositori dipilih" "$r"
    _ic "Mengunci jalur kerja lokal proyek..."
    sleep 1
    break # Keluar dari loop seleksi untuk melanjutkan ke alur utama skrip
  else
    # echo -e "${RED}[X] Pilihan tidak valid! Masukkan nomor repo, [t], [h], atau [q].${NC}"
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], atau [q]."
    sleep 1.5
  fi # end if angka seleksi
done # end while menu utama

# Menggunakan direktori aktif saat skrip dijalankan (pwd)
# Menentukan jalur kerja repositori yang dipilih di dalam direktori aktif saat ini
rp="${PWD}/${r}"

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

# Clone repositori tanpa checkout (jika folder belum ada)
if [ ! -d "$rp" ]; then
  _ic "Mengkloning repositori ke ${rp}..."
  if ! git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp"; then
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

  # SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis
  for item in \
    "user.name eucalypsih" \
    "user.email eucalypsih@gmail.com" \
    "gpg.format ssh" \
    "user.signingkey ~/.ssh/id_rsa.pub" \
    "commit.gpgsign true" \
    "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers";
  do
    git -C "$rp" config $item
    sleep 0.2
  done # end for item
    
  # Perbarui variabel setelah inisialisasi pertama selesai
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
else
  _o "Repositori terdeteksi sudah terinisialisasi."
  _ic "Memperbarui informasi struktur folder dari remote..."
    
  # Breakpoint setelah eksekusi fetch
  if git -C "$rp" fetch -q origin "$current_branch" 2>/dev/null; then
    _o "menarik data terbaru dari" "origin/${current_branch}"
    echo "------------------------------------------------"
    sleep 1.5
  else
    _e "Gagal terhubung ke remote repository!"
    _p "Apakah ingin memuat menu dengan cache lokal lama? (y/n)"
    read -r konfirmasi
    if [[ ! "$konfirmasi" =~ ^[yY]$ ]]; then
      _a "Membatalkan proses."
      exit 1
    fi # end if konfirmasi cache
  fi # end if fetch remote
fi # end if current_sparse

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Folder Tingkat Pertama)
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null)

if [ ${#targets[@]} -eq 0 ]; then
    _a "Gagal mengambil daftar folder dari remote atau repositori kosong!"
    exit 1
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
      # LOGIKA KELUAR [q] (KOMPARASI LOG & AUTO-PUSH)
      # =====================================================================
      perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

      # JIKA ADA PERUBAHAN YANG BELUM DI-COMMIT
      if [ -n "$perubahan_lokal" ]; then
        _w "Ada file yang telah Anda ubah/tambahkan secara lokal!"
        echo "$perubahan_lokal"
        echo "----------------------------------------"
        echo "Pilih tindakan Anda:"
        echo -e " [1] ${GREEN}Simpan perubahan (Commit secara lokal)${NC}"
        echo -e " [2] ${RED}Abaikan & Paksa update (Buang hasil editan Anda)${NC}"
        echo -e " [3] ${YELLOW}Abaikan & Batalkan Keluar (Kembali ke menu)${NC}"
        _ic "----------------------------------------"
        _p "Pilihan Anda (1/2/3)"
        read -r aksi_keluar

        if [ "$aksi_keluar" == "1" ]; then
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
      _n "========================================"
      _cc "       PERBANDINGAN STATUS COMMIT       "
      _cc "========================================"

      # Mengambil hash dan subjek commit terakhir dari lokal dan remote
      local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
      remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)
  
      echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
      echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
      _ic "----------------------------------------"

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

        if [ ${#active_folders[@]} -eq 0 ]; then
          _an "Belum ada folder aktif. Silakan add folder terlebih dahulu."
          _pp
        else

          _n "Memetakan seluruh struktur sub-folder secara mendalam..."

          # Tarik daftar sub-folder dari REMOTE (GitHub)
          mapfile -t remote_dirs < <(git -C "$rp" ls-tree -r -d --name-only "origin/${current_branch}" 2>/dev/null)

          # Tarik daftar sub-folder dari LOKAL (Termux) - PERBAIKAN PARAMETER: -type d
          local_dirs=()
          if [ -d "$rp" ]; then
            mapfile -t local_dirs < <(find "$rp" -type d 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git")
          fi # end if rp folder exist

          # Reset array agar tidak menumpuk saat menu diulang
          valid_dirs=()

          # Gabungkan Remote & Lokal ke dalam daftar validasi berdasarkan folder tingkat pertama yang aktif
          for dir in "${active_folders[@]}" "${remote_dirs[@]}" "${local_dirs[@]}"; do
            # Bersihkan dari baris kosong atau root '.' atau nama folder repositori induk
            [ -z "$dir" ] && continue
            [[ "$dir" == "$rp" || "$dir" == "." || "$dir" == "$r" ]] && continue

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

          if [ ${#sorted_dirs[@]} -eq 0 ]; then
            _hn "Tidak ada struktur direktori yang ditemukan."
            _pp
          else

            # Tampilkan daftar semua folder & sub-folder secara instan
            clear
            _cc "========================================"
            _cc "   PILIH STRUKTUR FOLDER TUJUAN         "
            _cc "========================================"
            for i in "${!sorted_dirs[@]}"; do
              printf " [%d] /%s/\n" $((i+1)) "${sorted_dirs[$i]}"
            done # end for display dirs
            _cc "----------------------------------------"
            _p "Pilih nomor folder tempat menaruh file baru"
            read -r folder_num_pilihan

            if [[ "$folder_num_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_num_pilihan" -ge 1 ] && [ "$folder_num_pilihan" -le "${#sorted_dirs[@]}" ]; then
              idx=$((folder_num_pilihan - 1))
              target_folder_path="${sorted_dirs[$idx]}"

              _cc "----------------------------------------"
              echo -e "Folder tujuan terkunci: ${YELLOW}/${target_folder_path}/${NC}"
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

                # Gabungkan jalur lengkap lokal secara presisi
                full_new_file_path="${rp}/${target_folder_path}/${nama_file_bersih}"

                # Mengambil path direktori induk (misal: /bash/bash_c/u3)
                new_parent_dir=$(dirname "$full_new_file_path")

                # Siapkan folder lokal fisik jika belum ada, lalu sentuh file barunya
                # JALUR UTAMA: Membuat semua folder/sub-folder baru secara otomatis jika belum ada
                mkdir -p "$new_parent_dir"

                # Membuat file kosong tiruan agar micro bisa langsung menyimpannya
                touch "$full_new_file_path"

                log_create "\nMembuat dan membuka file baru dengan micro..."
                sleep 1.5
                micro "$full_new_file_path"
              fi # end if nama_file_murni kosong
            else
              _an "Pilihan tidak valid."
              sleep 1
            fi # end if folder_num_pilihan valid
          fi # end if sorted_dirs kosong
        fi # end if active_folders kosong
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

        if [ ${#active_folders[@]} -eq 0 ]; then
          _hn "Belum ada folder aktif. Silakan add folder terlebih dahulu."
          _pp
        else
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

            for active_dir in "${active_folders[@]}"; do
              # Pastikan file berada di dalam salah satu folder induk yang aktif
              if [[ "$file" == "$active_dir"/* ]]; then
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
            _rn "Folder aktif Anda kosong (tidak ada file untuk diedit)."
            _pp
          else
            # Tampilkan sub-menu seluruh file yang tersedia untuk diedit
            clear
            _cc "========================================"
            _cc "   DAFTAR FILE YANG DAPAT DIEDIT        "
            _cc "========================================"
            for i in "${!valid_files[@]}"; do
              printf " [%d] %s\n" $((i+1)) "${valid_files[$i]}"
              sleep 0.03 # Efek transisi cepat
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

              _n "Membuka ${selected_file} dengan micro..."
              sleep 0.5
              micro "$full_file_path"
            else
              _an "Pilihan tidak valid."
              sleep 1
            fi # end if num_pilihan valid
          fi # end if valid_files kosong
        fi # end if active_folders kosong
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
          _pd "Apakah Anda ingin MENONAKTIFKAN (menghapus) folder ini dari sparse-list?"
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
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan!"
            else
              _e "Gagal memperbarui sparse-checkout list."
            fi
          else
            _c "Tindakan dibatalkan. Folder tetap aktif."
          fi
        else
          # Jika belum aktif, maka lakukan proses ADD seperti semula
          _n "Menambahkan /${selected_folder} ke sparse-checkout..."
          git -C "$rp" sparse-checkout add "/${selected_folder}"
          sleep 0.5
          _o "Berhasil ditambahkan!"
        fi # end if check sparse list
      else
        _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
      fi # end if target selection check

      echo ""
      _pp
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
