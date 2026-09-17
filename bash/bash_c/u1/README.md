

```bash
o="eucalypsih"; r="ey_rcrapsbash";

# Menggunakan direktori aktif saat skrip dijalankan (pwd)
rp="${PWD}/${r}"

# Kode warna untuk notifikasi terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color (Reset)

# 1. Clone repositori tanpa checkout (jika folder belum ada)
if [ ! -d "$rp" ]; then
    echo -e "${YELLOW}[+] Mengkloning repositori ke ${rp}...${NC}"
    git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp" && sleep 0.5
fi

# =====================================================================
# DETEKSI BRANCH OTOMATIS
# =====================================================================
# Mengambil nama branch aktif saat ini (default biasanya main/master)
current_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
# Jika kosong (karena belum checkout fisik), ambil branch default dari remote HEAD
if [ -z "$current_branch" ]; then
    current_branch=$(git -C "$rp" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's/origin\///')
    # Jika masih kosong, berikan fallback aman ke 'main'
    [ -z "$current_branch" ] && current_branch="main"
fi

# Mengambil daftar sparse saat ini di awal untuk pengecekan inisialisasi
current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

# PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
if [ -z "$current_sparse" ]; then
    echo -e "${YELLOW}[+] Menyiapkan inisialisasi awal sparse-checkout pada branch [${current_branch}]...${NC}"
    
    # 2. Inisialisasi awal sparse-checkout dengan README.md
    git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' && sleep 0.5

    # 3. SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis
    for item in \
      "user.name eucalypsih" \
      "user.email eucalypsih@gmail.com" \
      "gpg.format ssh" \
      "user.signingkey ~/.ssh/id_rsa.pub" \
      "commit.gpgsign true" \
      "gpg.ssh.allowedSignersFile ~/.ssh/allowed_signers";
    do
      git -C "$rp" config $item
      sleep 0.5
    done
    
    # Perbarui variabel setelah inisialisasi pertama selesai
    current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
else
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi pada branch [${current_branch}].${NC}"
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    
    # Breakpoint setelah eksekusi fetch secara dinamis
    if git -C "$rp" fetch -q origin "$current_branch" 2>/dev/null; then
        echo -e "${GREEN}[✓] Sukses menarik data terbaru dari origin/${current_branch}.${NC}"
        echo "------------------------------------------------"
        echo -e "${YELLOW}[BREAKPOINT] Tekan [Enter] untuk memuat menu seleksi folder...${NC}"
        read -r
    else
        echo -e "${RED}[X] BREAKPOINT ERROR: Gagal terhubung ke remote repository!${NC}"
        echo -n "Apakah Anda ingin tetap memuat menu dengan cache lokal lama? (y/n): "
        read -r konfirmasi
        if [[ ! "$konfirmasi" =~ ^[yY]$ ]]; then
            echo -e "${RED}[+] Membatalkan proses.${NC}"
            exit 1
        fi
    fi
fi

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Dinamis sesuai Branch Aktif)
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null)

if [ ${#targets[@]} -eq 0 ]; then
    echo -e "${RED}[X] Gagal mengambil daftar folder dari remote atau repositori kosong pada branch ${current_branch}!${NC}"
    exit 1
fi

# 5. MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  echo "========================================"
  echo "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  echo "========================================"
  echo "Branch Aktif : ${YELLOW}${current_branch}${NC}"
  echo "Daftar folder otomatis dari Remote:"

  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
      printf " [%d] /%-12s  %b[ sudah aktif ]%b\n" $((i+1)) "$folder" "${GREEN}" "${NC}"
    else
      printf " [%d] /%-12s\n" $((i+1)) "$folder"
    fi
  done

  echo "----------------------------------------"
  echo " [e] Edit File (Jelajahi Folder Aktif)"
  echo " [n] Buat File Baru di Folder Aktif"
  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan pilihan Anda: "
  read -r pilihan

  # LOGIKA KELUAR [q] (Dengan Auto-Increment Commit Message & Dinamis Branch Auto-Push)
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

    if [ -n "$perubahan_lokal" ]; then
      echo -e "\n${RED}[!] PERINGATAN: Ada file yang telah Anda ubah/tambahkan secara lokal!${NC}"
      echo "$perubahan_lokal"
      echo "----------------------------------------"
      echo "Pilih tindakan Anda:"
      echo " [1] Simpan perubahan (Commit secara lokal)"
      echo " [2] Abaikan & Paksa update (Buang hasil editan Anda)"
      echo " [3] Batalkan Keluar (Kembali ke menu)"
      echo "----------------------------------------"
      echo -n "Pilihan Anda (1/2/3): "
      read -r aksi_keluar

      if [ "$aksi_keluar" == "1" ]; then
        # Generator Auto-Increment Pesan Commit
        last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
        if [[ "$last_num" =~ ^[0-9]+$ ]]; then
          next_num=$((last_num + 1))
          auto_msg="u${next_num}"
        else
          auto_msg="u1"
        fi

        echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
        echo -n "Tekan [Enter] untuk menggunakan nama di atas, atau ketik pesan manual: "
        read -r pesan_commit
        [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"
        
        git -C "$rp" add .
        git -C "$rp" commit -m "$pesan_commit"
        echo -e "${GREEN}[✓] Perubahan berhasil disimpan ke commit lokal!${NC}"
      elif [ "$aksi_keluar" == "2" ]; then
        echo -e "${RED}[!] Membuang perubahan lokal dan melakukan paksa checkout...${NC}"
        git -C "$rp" checkout -f "$current_branch" 2>/dev/null
      else
        echo -e "${YELLOW}[+] Kembali ke menu utama...${NC}"
        sleep 1; continue
      fi
    else
      # Jika tidak ada uncommitted changes, jalankan checkout sparse biasa
      git -C "$rp" checkout "$current_branch" 2>/dev/null
    fi

    # KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE (Dinamis Branch)
    echo -e "\n========================================"
    echo -e "       PERBANDINGAN STATUS COMMIT       "
    echo -e "========================================"
    
    local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
    remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)
    
    echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
    echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
    echo -e "----------------------------------------"

    # Cek apakah lokal berada di depan remote branch aktif
    ahead_commits=$(git -C "$rp" rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null)

    if [ "${ahead_commits:-0}" -gt 0 ]; then
      echo -e "${YELLOW}[!] Status: Local Anda lebih maju ${ahead_commits} commit dari Remote [origin/${current_branch}].${NC}"
      echo -n "Apakah Anda yakin ingin melakukan PUSH ke GitHub sekarang? (y/n): "
      read -r konfirmasi_push
      
      if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}[+] Melakukan git push origin ${current_branch}...${NC}"
        if git -C "$rp" push origin "$current_branch"; then
          echo -e "${GREEN}[✓] Push berhasil! Repositori GitHub branch [${current_branch}] telah diperbarui.${NC}"
        else
          echo -e "${RED}[X] Gagal melakukan push! Periksa koneksi atau kredensial SSH Anda.${NC}"
        fi
      else
        echo -e "${YELLOW}[!] Push dibatalkan. Perubahan Anda tetap tersimpan di lokal.${NC}"
      fi
    else
      echo -e "${GREEN}[✓] Status: Sinkron! Log Local sama dengan Remote.${NC}"
    fi

    echo -e "\n${GREEN}[✓] Selesai dengan sukses! Keluar dari skrip.${NC}"
    break
  fi

  # FITUR: BUAT FILE BARU MANUAL ([n])
  if [[ "$pilihan" == "n" || "$pilihan" == "N" ]]; then
    if ! command -v micro &> /dev/null; then
      echo -e "\n${RED}[X] Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    active_folders=()
    for folder in "${targets[@]}"; do
      if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
        active_folders+=("$folder")
      fi
    done

    if [ ${#active_folders[@]} -eq 0 ]; then
      echo -e "\n${RED}[!] Belum ada folder aktif. Silakan add folder terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    clear
    echo "========================================"
    echo "       PILIH FOLDER INDUK UTAMA         "
    echo "========================================"
    for i in "${!active_folders[@]}"; do
      printf " [%d] /%s/\n" $((i+1)) "${active_folders[$i]}"
    done
    echo "----------------------------------------"
    echo -n "Pilih nomor folder tujuan: "
    read -r folder_pilihan

    if [[ "$folder_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_pilihan" -ge 1 ] && [ "$folder_pilihan" -le "${#active_folders[@]}" ]; then
      idx=$((folder_pilihan-1))
      parent_folder="${active_folders[$idx]}"

      echo "----------------------------------------"
      echo -e "Folder terpilih: ${YELLOW}/${parent_folder}/${NC}"
      echo "Masukkan nama file baru (Bisa pakai sub-folder, misal: sub/file.sh)"
      echo -n "Nama file: "
      read -r nama_file_baru

      if [ -z "$nama_file_baru" ]; then
        echo -e "${RED}[X] Nama file tidak boleh kosong!${NC}"
        sleep 1
        continue
      fi

      full_new_file_path="${rp}/${parent_folder}/${nama_file_baru}"
      new_parent_dir=$(dirname "$full_new_file_path")
      
      mkdir -p "$new_parent_dir"
      touch "$full_new_file_path"
      
      echo -e "\n${YELLOW}[+] Membuat dan membuka file dengan micro...${NC}"
      sleep 0.5
      micro "$full_new_file_path"
    else
      echo -e "\n${RED}[X] Pilihan folder tidak valid.${NC}"
      sleep 1
    fi
    continue
  fi

  # FITUR: JELAJAHI DAN EDIT SELURUH FILE DI FOLDER AKTIF ([e])
  if [[ "$pilihan" == "e" || "$pilihan" == "E" ]]; then
    if ! command -v micro &> /dev/null; then
      echo -e "\n${RED}[X] Editor 'micro' belum terinstall!${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r
      continue
    fi

    active_folders=()
    for folder in "${targets[@]}"; do
      if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
        active_folders+=("$folder")
      fi
    done

    if [ ${#active_folders[@]} -eq 0 ]; then
      echo -e "\n${RED}[!] Belum ada folder aktif. Silakan add folder terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r
      continue
    fi

    echo -e "\n${YELLOW}[+] Memetakan seluruh file dan sub-folder secara rekursif...${NC}"
    mapfile -t all_remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)
    
    valid_files=()
    for file in "${all_remote_files[@]}"; do
      for active_dir in "${active_folders[@]}"; do
        if [[ "$file" == "$active_dir"/* ]]; then
          valid_files+=("$file")
          break
        fi
      done
    done

    if [ ${#valid_files[@]} -eq 0 ]; then
      echo -e "\n${YELLOW}[!] Folder aktif Anda kosong secara remote (belum ada file).${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r
      continue
    fi

    clear
    echo "========================================"
    echo "   DAFTAR FILE YANG DAPAT DIEDIT        "
    echo "========================================"
    for i in "${!valid_files[@]}"; do
      printf " [%d] %s\n" $((i+1)) "${valid_files[$i]}"
    done
    echo "----------------------------------------"
    echo -n "Pilih nomor file yang ingin diedit dengan micro: "
    read -r num_pilihan

    if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
      idx=$((num_pilihan-1))
      selected_file="${valid_files[$idx]}"
      full_file_path="${rp}/${selected_file}"
      parent_dir=$(dirname "$full_file_path")
      
      mkdir -p "$parent_dir"
      touch "$full_file_path"
      
      echo -e "\n${YELLOW}[+] Membuka ${selected_file} dengan micro...${NC}"
      sleep 0.5
      micro "$full_file_path"
    else
      echo -e "\n${RED}[X] Pilihan tidak valid.${NC}"
      sleep 1
    fi
    continue
  fi

  # VALIDASI PROSES UTAMA (ADD FOLDER UTAMA)
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
    idx=$((pilihan-1))
    selected_folder="${targets[$idx]}"
    
    if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
      echo -e "\n${RED}[!] Ops! Folder /${selected_folder} sudah ada di dalam daftar sparse-list.${NC}"
    else
      echo -e "\n${YELLOW}[+] Menambahkan /${selected_folder} ke sparse-checkout...${NC}"
      git -C "$rp" sparse-checkout add "/${selected_folder}"
      sleep 0.5
      echo -e "${GREEN}[✓] Berhasil ditambahkan!${NC}"
    fi
  else
    echo -e "\n${RED}[X] Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera.${NC}"
  fi

  echo ""
  echo -n "Tekan [Enter] untuk melanjutkan..."
  read -r
done

```

qa: 
Apakah Anda membutuhkan bantuan untuk menguji atau menambahkan **fitur penanganan error** lainnya pada skrip ini sebelum dijalankan?

