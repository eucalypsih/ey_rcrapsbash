

```bash
  echo -n "Masukkan pilihan Anda: "
  read -r pilihan

  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    # ... Logika Keluar ...
    break
  fi

  if [[ "$pilihan" == "n" || "$pilihan" == "N" ]]; then
    # ... Logika Buat File ...
    continue # <-- Mengandalkan continue agar tidak jeblos ke bawah
  fi

  if [[ "$pilihan" == "e" || "$pilihan" == "E" ]]; then
    # ... Logika Edit File ...
    continue # <-- Mengandalkan continue agar tidak jeblos ke bawah
  fi

  # Logika angka langsung dieksekusi di bawah jika tidak ada 'continue' di atas
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && ...

```

<br>

---

<br>

```bash
o="eucalypsih"; r="ey_rcrapsbash";

# Menggunakan direktori aktif saat skrip dijalankan (pwd)
rp="${PWD}/${r}"

# =====================================================================
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
# =====================================================================
if [ -d "$rp/.git" ]; then
    current_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
fi
[ -z "$current_branch" ] && current_branch="main" 
# =====================================================================

# Kode warna untuk notifikasi terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color (Reset)

# =====================================================================
# PENGAMAN: DETEKSI JIKA RP ADALAH FILE BIASA (BUKAN FOLDER)
# =====================================================================
# PENANGANAN ERROR: Cek apakah jalur rp terhalang oleh file biasa
if [ -e "$rp" ] && [ -f "$rp" ] && [ ! -d "$rp" ]; then
    echo -e "${RED}[!] CRITICAL ERROR: Jalur '${rp}' sudah ada, terdeteksi sebagai FILE BIASA!, bukan FOLDER!${NC}"
    echo -e "${RED}Hal ini menghalangi skrip untuk membuat folder repositori.${NC}"
    echo -n "Apakah Anda ingin menghapus file tersebut agar bisa melanjutkan? (y/n): "
    read -r hapus_file
    
    if [[ "$hapus_file" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}[+] Menghapus file penghalang: ${rp}...${NC}"
        rm -f "$rp"
    else
        echo -e "${RED}[X] Proses dibatalkan. Silakan pindahkan atau hapus file tersebut secara manual.${NC}"
        exit 1
    fi
fi

# Clone repositori tanpa checkout (jika folder belum ada)
if [ ! -d "$rp" ]; then
    echo -e "${YELLOW}[+] Mengkloning repositori ke ${rp}...${NC}"
    if ! git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp"; then
        echo -e "${RED}[X] FATAL ERROR: Gagal melakukan git clone! Periksa koneksi internet atau SSH Key Anda.${NC}"
        exit 1
    fi
    sleep 0.5
fi

# Mengambil daftar sparse saat ini di awal untuk pengecekan inisialisasi
current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

# PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
if [ -z "$current_sparse" ]; then
    echo -e "${YELLOW}[+] Menyiapkan inisialisasi awal sparse-checkout...${NC}"
    
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
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi.${NC}"
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    
    # Breakpoint setelah eksekusi fetch
    if git -C "$rp" fetch -q origin main 2>/dev/null; then
        echo -e "${GREEN}[✓] Sukses menarik data terbaru dari origin/main.${NC}"
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

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Folder Tingkat Pertama)
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only origin/main 2>/dev/null)

if [ ${#targets[@]} -eq 0 ]; then
    echo -e "${RED}[X] Gagal mengambil daftar folder dari remote atau repositori kosong!${NC}"
    exit 1
fi

# 5. MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  echo "========================================"
  echo "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  echo "========================================"
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
          git -C "$rp" checkout -f main 2>/dev/null
        else
          echo -e "${YELLOW}[+] Kembali ke menu utama...${NC}"
          sleep 1; continue
        fi
      else
        # Jika tidak ada uncommitted changes, langsung jalankan checkout sparse
        git -C "$rp" checkout main 2>/dev/null
      fi

      # 2. KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE
      echo -e "\n========================================"
      echo -e "       PERBANDINGAN STATUS COMMIT       "
      echo -e "========================================"

      # Mengambil hash dan subjek commit terakhir dari lokal dan remote
      local_log=$(git -C "$rp" log -1 --format="%h - %s" main 2>/dev/null)
      remote_log=$(git -C "$rp" log -1 --format="%h - %s" origin/main 2>/dev/null)
  
      echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
      echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
      echo -e "----------------------------------------"

      # Cek apakah lokal berada di depan remote (butuh push)
      ahead_commits=$(git -C "$rp" rev-list --count origin/main..main 2>/dev/null)

      if [ "${ahead_commits:-0}" -gt 0 ]; then
        echo -e "${YELLOW}[!] Status: Local Anda lebih maju ${ahead_commits} commit dari Remote.${NC}"
        echo -n "Apakah Anda yakin ingin melakukan PUSH ke GitHub sekarang? (y/n): "
        read -r konfirmasi_push
      
        if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
          echo -e "${YELLOW}[+] Melakukan git push origin main...${NC}"
          if git -C "$rp" push origin main; then
            echo -e "${GREEN}[✓] Push berhasil! Repositori GitHub telah diperbarui.${NC}"
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
      ;;


    [nN])
      # =====================================================================
      # FITUR: BUAT FILE BARU DI FOLDER AKTIF
      # =====================================================================
      if ! command -v micro &> /dev/null; then
        echo -e "\n${RED}[X] Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu.${NC}"
        echo -n "Tekan [Enter] untuk kembali..."
        read -r
      else

        # Kumpulkan folder tingkat pertama yang aktif saat ini
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
        else

          echo -e "\n${YELLOW}[+] Memetakan seluruh struktur sub-folder secara mendalam...${NC}"
    

          # Tarik daftar sub-folder dari REMOTE (GitHub)
          mapfile -t remote_dirs < <(git -C "$rp" ls-tree -r -d --name-only "origin/${current_branch}" 2>/dev/null)

          # Tarik daftar sub-folder dari LOKAL (Termux) - PERBAIKAN PARAMETER: -type d
          local_dirs=()
          if [ -d "$rp" ]; then
            mapfile -t local_dirs < <(find "$rp" -type d 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git")
          fi

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
                fi
              fi
            done
          done

          # Urutkan secara alfabetis agar berurutan rapi dari folder induk ke sub-sub folder terujung
          IFS=$'\n' sorted_dirs=($(sort -u <<<"${valid_dirs[*]}")); unset IFS

          if [ ${#sorted_dirs[@]} -eq 0 ]; then
            echo -e "\n${RED}[!] Tidak ada struktur direktori yang ditemukan.${NC}"
            echo -n "Tekan [Enter] untuk kembali..."
            read -r
          else

            # Tampilkan daftar semua folder & sub-folder secara instan
            clear
            echo "========================================"
            echo "   PILIH STRUKTUR FOLDER TUJUAN         "
            echo "========================================"
            for i in "${!sorted_dirs[@]}"; do
              printf " [%d] /%s/\n" $((i+1)) "${sorted_dirs[$i]}"
            done
            echo "----------------------------------------"
            echo -n "Pilih nomor folder tempat menaruh file baru: "
            read -r folder_num_pilihan

            if [[ "$folder_num_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_num_pilihan" -ge 1 ] && [ "$folder_num_pilihan" -le "${#sorted_dirs[@]}" ]; then
              idx=$((folder_num_pilihan - 1))
              target_folder_path="${sorted_dirs[$idx]}"

              echo "----------------------------------------"
              echo -e "Folder tujuan terkunci: ${YELLOW}/${target_folder_path}/${NC}"
              # REKOMENDASI TERBAIK: Informatif dengan visual warna hijau pada contoh input
              echo -e -n "Masukkan NAMA FILE BARU (Bisa + sub-folder baru, contoh: ${GREEN}script.py${NC} atau ${GREEN}u3/README.md${NC}): "
              read -r nama_file_murni

              if [ -z "$nama_file_murni" ]; then
                echo -e "${RED}[X] Nama file tidak boleh kosong!${NC}"
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

                echo -e "\n${YELLOW}[+] Membuat dan membuka file baru dengan micro...${NC}"
                sleep 2.5
                micro "$full_new_file_path"
              fi
            else
              echo -e "\n${RED}[X] Pilihan tidak valid.${NC}"
              sleep 1
            fi
          fi
        fi
      fi
      ;; # Menutup opsi [nN] dengan benar

    [eE])
      # =====================================================================
      # FITUR: JELAJAHI DAN EDIT SELURUH FILE
      # =====================================================================
      if ! command -v micro &> /dev/null; then
        echo -e "\n${RED}[X] Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu.${NC}"
        echo -n "Tekan [Enter] untuk kembali..."
        read -r
      else
        # Kumpulkan folder tingkat pertama yang aktif saat ini
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
        else
          echo -e "\n${YELLOW}[+] Memetakan seluruh file lokal dan remote secara rekursif...${NC}"

          # Tarik daftar file dari REMOTE (GitHub)
          mapfile -t remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

          # Tarik daftar file dari LOKAL (Termux) - PERBAIKAN PARAMETER: -type f
          local_files=()
          if [ -d "$rp" ]; then
            mapfile -t local_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git")
          fi

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
                fi
                break
              fi
            done
          done

          # Urutkan secara alfabetis dan unik agar rapi
          IFS=$'\n' valid_files=($(sort -u <<<"${all_combined_files[*]}")); unset IFS

          if [ ${#valid_files[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}[!] Folder aktif Anda kosong (tidak ada file untuk diedit).${NC}"
            echo -n "Tekan [Enter] untuk kembali..."
            read -r
          else
            # Tampilkan sub-menu seluruh file yang tersedia untuk diedit
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
              idx=$((num_pilihan - 1))
              selected_file="${valid_files[$idx]}"
              full_file_path="${rp}/${selected_file}"

              # Jaga-jaga buat folder induk lokal fisik jika membuka file remote yang belum ter-checkout lokal
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
          fi
        fi
      fi
      ;;

    [0-9]*)
      # =====================================================================
      # LOGIKA UTAMA: JIKA INPUT ADALAH ANGKA (ADD FOLDER UTAMA)
      # =====================================================================
      if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
        idx=$((pilihan - 1))
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
      ;;

    *)
      # =====================================================================
      # JIKA INPUT TIDAK COCOK DENGAN OPSI APAPUN
      # =====================================================================
      echo -e "\n${RED}[X] Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera.${NC}"
      echo ""
      echo -n "Tekan [Enter] untuk melanjutkan..."
      read -r
      ;;
  esac

done

```




























<br>

