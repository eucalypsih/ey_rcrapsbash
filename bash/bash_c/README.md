

```bash
# 1. Tentukan daftar folder/file yang ingin dimasukkan
targets=("README.md" "diff" "et_micro" "ftp" "gef" "git" "rename" "search" "sed" "tar")

# 2. Set pola dasar awal (!/*) bersama dengan target pertama (README.md)
git -C "$rp" sparse-checkout set --no-cone '!/*' "/${targets[0]}"
sleep 0.5

# 3. Lakukan perulangan untuk menambahkan (add) target sisanya
for item in "${targets[@]:1}"; do
    git -C "$rp" sparse-checkout add --no-cone "/${item}"
    sleep 0.5
done

```




```bash
o="eucalypsih"; r="ey_rcrapsbash"; rp="/data/data/com.termux/files/home/${r}"

# 1. Clone repositori tanpa checkout (jika belum ada)
if [ ! -d "$rp" ]; then
    git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp" && sleep 0.5
fi

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

# 4. Daftar folder target (Array)
targets=("diff" "et_micro" "ftp" "gef" "git" "rename" "search" "sed" "tar")

# 5. MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  echo "========================================"
  echo "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  echo "========================================"
  echo "Daftar folder yang tersedia:"
  
  # Ambil daftar yang sudah di-add saat ini untuk validasi status
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  # Tampilkan menu dengan nomor urut terurut
  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    # Cek apakah folder sudah terdaftar di sparse-checkout
    if echo "$current_sparse" | grep -q "^/${folder}/$"; then
      printf " [%d] /%-12s  [ sudah aktif ]\n" $((i+1)) "$folder"
    else
      printf " [%d] /%-12s\n" $((i+1)) "$folder"
    fi
  done
  
  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan nomor folder yang ingin ditambahkan: "
  read pilihan

  # Kondisi keluar dari menu
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    echo -e "\n[+] Menerapkan perubahan dan melakukan checkout..."
    git -C "$rp" checkout -f main
    echo "[✓] Selesai!"
    break
  fi

  # Validasi input harus berupa angka dan masuk dalam range array
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
    # Kurangi 1 karena index array Bash dimulai dari angka 0
    idx=$((pilihan-1))
    selected_folder="${targets[$idx]}"

    # Cek apakah sudah pernah ditambahkan sebelumnya
    if echo "$current_sparse" | grep -q "^/${selected_folder}/$"; then
      echo -e "\n[!] Folder /${selected_folder}/ sudah ada di dalam daftar sparse-list!"
    else
      echo -e "\n[+] Menambahkan /${selected_folder}/ ke sparse-checkout..."
      git -C "$rp" sparse-checkout add --no-cone "/${selected_folder}/"
      sleep 0.5
      echo "[✓] Berhasil ditambahkan!"
    fi
  else
    echo -e "\n[X] Pilihan tidak valid. Silakan masukkan nomor yang tertera."
  fi

  # Jeda sejenak sebelum menu me-refresh kembali agar user bisa membaca notifikasi
  echo -n "Tekan [Enter] untuk melanjutkan..."
  read
done

```

---

- `awk 'BEGIN{ORS="\n"} {sub(/\r$/, ""); if(NR>=1) print; if(NR==96) exit}' ${PWD}/main.sh`
```bash
o="eucalypsih"; r="ey_rcrapsbash";

# Menggunakan direktori aktif saat skrip dijalankan (pwd)
rp="${PWD}/${r}"

# Kode warna untuk notifikasi terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color (Reset)

# 1. Clone repositori tanpa checkout (jika belum ada)
if [ ! -d "$rp" ]; then
    echo -e "${YELLOW}[+] Mengkloning repositori ke ${rp}...${NC}"
    git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp" && sleep 0.5
fi

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

# 4. Daftar folder target (Array)
targets=("diff" "et_micro" "ftp" "gef" "git" "rename" "search" "sed" "tar")

# 5. MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  echo "========================================"
  echo "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  echo "========================================"
  echo "Daftar folder yang tersedia:"

  # Ambil daftar yang sudah di-add saat ini untuk validasi status
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  # Tampilkan menu dengan nomor urut terurut
  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    # Cek apakah folder sudah terdaftar di sparse-checkout
    if echo "$current_sparse" | grep -q "^/${folder}"; then
      printf " [%d] /%-12s  %b[ sudah aktif ]%b\n" $((i+1)) "$folder" "${GREEN}" "${NC}"
    else
      printf " [%d] /%-12s\n" $((i+1)) "$folder"
    fi
  done

  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan nomor folder yang ingin ditambahkan: "
  read pilihan

  # Kondisi keluar dari menu
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    echo -e "\n${YELLOW}[+] Menerapkan perubahan dan melakukan checkout...${NC}"
    git -C "$rp" checkout -f main
    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
    break
  fi

  # Validasi input harus berupa angka dan masuk dalam range array (1 sampai 9)
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
    # Kurangi 1 karena index array Bash dimulai dari angka 0
    idx=$((pilihan-1))
    selected_folder="${targets[$idx]}"

    # Cek apakah sudah pernah ditambahkan sebelumnya
    if echo "$current_sparse" | grep -q "^/${selected_folder}$"; then
      echo -e "\n${RED}[!] Ops! Folder /${selected_folder} sudah ada di dalam daftar sparse-list.${NC}"
    else
      echo -e "\n${YELLOW}[+] Menambahkan /${selected_folder} ke sparse-checkout...${NC}"
      git -C "$rp" sparse-checkout add "/${selected_folder}"
      sleep 0.5
      echo -e "${GREEN}[✓] Berhasil ditambahkan!${NC}"
    fi
  else
    echo -e "\n${RED}[X] Pilihan tidak valid. Silakan masukkan nomor yang tertera.${NC}"
  fi

  # Jeda sejenak sebelum menu me-refresh kembali agar user bisa membaca notifikasi
  echo ""
  echo -n "Tekan [Enter] untuk melanjutkan..."
  read
done

```

---

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
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi. Melanjutkan ke menu...${NC}"
    sleep 1
fi

# 4. Daftar folder target (Array)
targets=("diff" "et_micro" "ftp" "gef" "git" "rename" "search" "sed" "tar" "bash")

# 5. MENU INTERAKTIF SELEKSI FOLDER
while true; do
  clear
  echo "========================================"
  echo "   SISTEM SELEKSI SPARSE-CHECKOUT       "
  echo "========================================"
  echo "Daftar folder yang tersedia:"

  # Selalu ambil status real-time terupdate di setiap awal loop menu
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  # Tampilkan menu dengan nomor urut terurut
  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    # PERBAIKAN PENCATATAN STATUS: Menggunakan regex yang lebih ketat agar akurat
    if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
      printf " [%d] /%-12s  %b[ sudah aktif ]%b\n" $((i+1)) "$folder" "${GREEN}" "${NC}"
    else
      printf " [%d] /%-12s\n" $((i+1)) "$folder"
    fi
  done

  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan nomor folder yang ingin ditambahkan: "
  read pilihan

  # Kondisi keluar dari menu
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    echo -e "\n${YELLOW}[+] Menerapkan perubahan dan melakukan checkout...${NC}"
    git -C "$rp" checkout -f main
    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
    break
  fi

  # Validasi input harus berupa angka dan masuk dalam range array (1 sampai 9)
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
    idx=$((pilihan-1))
    selected_folder="${targets[$idx]}"

    # PERBAIKAN VALIDASI ALREADY: Cocokkan secara fleksibel dengan regex
    if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
      echo -e "\n${RED}[!] Ops! Folder /${selected_folder} sudah ada di dalam daftar sparse-list.${NC}"
    else
      echo -e "\n${YELLOW}[+] Menambahkan /${selected_folder} ke sparse-checkout...${NC}"
      git -C "$rp" sparse-checkout add "/${selected_folder}"
      sleep 0.5
      echo -e "${GREEN}[✓] Berhasil ditambahkan!${NC}"
    fi
  else
    echo -e "\n${RED}[X] Pilihan tidak valid. Silakan masukkan nomor yang tertera.${NC}"
  fi

  # Jeda sejenak sebelum menu me-refresh kembali agar user bisa membaca notifikasi
  echo ""
  echo -n "Tekan [Enter] untuk melanjutkan..."
  read
done

```








<br>
