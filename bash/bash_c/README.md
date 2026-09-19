



- `[ -n "$detected_branch" ]`
memeriksa apakah variabel $detected_branch tidak kosong (memiliki isi/teks).

Dalam skrip Bash/Shell,r `-n` adalah sebuah operator kondisi yang berarti *"not empty"* (tidak kosong) atau *"non-zero length"* (panjang string lebih dari nol).

Berikut penjelasan alurnya berdasarkan potongan kode Anda:
1. `detected_branch=$(...)`: Baris pertama mencoba mengambil nama branch Git yang aktif saat ini dari repositori di dalam direktori `$rp`.
2. `[ -n "$detected_branch" ]`: Baris kedua memeriksa hasilnya.
- Jika branch ditemukan (misal berisi `main` atau `develop`), kondisi bernilai **TRUE** (sukses/exit code 0)
- Jika branch tidak ditemukan (misal karena direktori tersebut bukan repositori Git, atau terjadi eror sehingga variabelnya kosong), kondisi bernilai **FALSE** (gagal/exit code 1).

### Contoh Penggunaan Biasanya
Perintah ini hampir selalu diikuti oleh logika pencabangan (`if`) atau operator kondisi untuk menentukan langkah selanjutnya. Contohnya:
```bash
if [ -n "$detected_branch" ]; then
    echo "Branch saat ini adalah: $detected_branch"
else
    echo "Gagal mendeteksi branch atau folder bukan repositori Git."
fi

```
Atau menggunakan operator singkat `&&` (and):
```bash
[ -n "$detected_branch" ] && echo "Lanjut proses untuk branch $detected_branch"

```

---

- `[ -z "$detected_branch" ]`
memeriksa apakah sebuah variabel kosong (*zero length* atau panjang string-nya nol).

Jika `-n` artinya *"apakah ada isinya?"*, maka `-z` artinya *"apakah kosong?"*.

### Contoh Perbandingan dalam Kode
Jika Anda ingin mendeteksi eror ketika branch Git gagal ditemukan, Anda bisa menulisnya dengan dua cara ini (keduanya menghasilkan tujuan yang sama):

Menggunakan `-z` (Memeriksa jika kosong):
```bash
if [ -z "$detected_branch" ]; then
    echo "Eror: Ini bukan repositori Git atau branch tidak ditemukan!"
    exit 1
fi

```
Menggunakan `-n` dengan tanda seru `!` (Negasi/Kebalikan):
```bash
if [ ! -n "$detected_branch" ]; then
    echo "Eror: Ini bukan repositori Git atau branch tidak ditemukan!"
    exit 1
fi

```
### Tips Keamanan (Tanda Kutip)
Sama seperti `-n`, saat menggunakan `-z` selalu bungkus variabel dengan tanda kutip ganda (`"$variabel"`). Jika tidak, Bash akan eror atau salah membaca kondisi jika variabel tersebut benar-benar kosong atau mengandung spasi.











---


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
targets=("bash" "diff" "et_micro" "ftp" "gdb" "gef" "git" "re" "rename" "search" "sed" "tar")

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

- `if [ -z "$current_sparse" ]`: Skrip mengecek apakah keluaran dari `sparse-checkout list` kosong. Jika kosong (berarti jalankan pertama kali), skrip akan menjalankan `git sparse-checkout set` dan konfigurasi Git. Jika sudah ada isinya (berarti skrip dijalankan untuk kedua kalinya atau seterusnya), bagian setup awal ini **dilewati sepenuhnya** sehingga daftar folder lama Anda tidak terhapus.
- Sinkronisasi Regex Terpadu (`^/?${folder}/?$`): Mengganti operator pencocokan string agar status `[ sudah aktif ]` pada menu utama dan logika penolakan folder `already` sinkron secara presisi dengan format teks keluaran bawaan dari Git.
qa: 
Apakah Anda ingin menambahkan fitur **multi-input sekaligus**? Misalnya, Anda bisa mengetik `1 3 5` (dipisah spasi) untuk langsung menambahkan folder 1, 3, dan 5 secara berurutan dalam satu kali tekan enter?

<br>

---

<br>

cara terbaik agar skrip Anda bersifat dinamis. Anda tidak perlu lagi menulis daftar folder secara manual (*hardcode*) di dalam kode skrip.

Kita bisa memanfaatkan perintah `git ls-tree` untuk membaca daftar folder yang ada di repositori GitHub secara *real-time* setelah proses *clone* berhasil.

Berikut adalah pembaruan kode di mana variabel `targets` akan **terisi otomatis** berdasarkan folder asli yang ada di repositori remote Anda:
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
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi.${NC}"
    # Melakukan fetch remote agar daftar folder selalu sinkron dengan GitHub terbaru
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    git -C "$rp" fetch -q origin main 2>/dev/null
    sleep 0.5
fi

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY
# Mengambil hanya objek bertipe 'tree' (direktori/folder) dari branch main
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only origin/main 2>/dev/null)

# Validasi jika gagal mengambil data dari remote atau repositori kosong
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

  # Selalu ambil status real-time terupdate di setiap awal loop menu
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  # Tampilkan menu dengan nomor urut terurut
  for i in "${!targets[@]}"; do
    folder="${targets[$i]}"
    # Cocokkan secara fleksibel dengan regex
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

  # Validasi input harus berupa angka dan masuk dalam range array otomatis
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
    idx=$((pilihan-1))
    selected_folder="${targets[$idx]}"

    # Validasi ALREADY
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

  echo ""
  echo -n "Tekan [Enter] untuk melanjutkan..."
  read
done

```
- `git -C "$rp" ls-tree -d --name-only origin/main`: Perintah ini menyuruh Git melihat ke server GitHub (`origin/main`), lalu hanya menyaring objek yang berbentuk direktori/folder (`-d`) dan hanya menampilkan namanya saja (`--name-only`). File mentah seperti `.gitignore` atau `LICENSE` otomatis dilewati.
- `mapfile -t targets < <(...)`: Mengubah keluaran teks dari perintah Git tadi menjadi sebuah Array Bash bernama `targets` secara otomatis.
- `git -C "$rp" fetch -q origin main`: Ditambahkan pada kondisi ketika skrip dijalankan ulang. Ini memastikan jika Anda baru saja menambah folder baru di GitHub, skrip akan langsung mengetahuinya tanpa perlu *clone* ulang.

qa: 
Apakah Anda ingin menambahkan opsi **"Pilih Semua Folder"** (misalnya dengan mengetik huruf `a`) agar tidak perlu menekan nomor satu per satu jika ingin mengunduh semua folder sekaligus?

<br>

---

<br>

aa: 
**Anda bisa menambahkan breakpoint berupa konfirmasi interaktif segera setelah perintah** `git fetch`. Fungsi breakpoint ini sangat berguna untuk memastikan bahwa koneksi ke remote GitHub berhasil dan daftar folder terbaru sudah ditarik sebelum skrip masuk ke menu utama.

Jika perintah `fetch` gagal (misalnya karena masalah jaringan), skrip akan berhenti dan memberikan peringatan.

Berikut adalah modifikasi pada bagian **PENGAMAN UTAMA** skrip Anda untuk menyisipkan breakpoint tersebut:
```bash
# ... [Bagian atas skrip tetap sama] ...

else
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi.${NC}"
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    
    # Eksekusi fetch dan masukkan ke dalam pengkondisian (Breakpoint)
    if git -C "$rp" fetch -q origin main 2>/dev/null; then
        echo -e "${GREEN}[✓] Sukses menarik data terbaru dari origin/main.${NC}"
        echo "------------------------------------------------"
        echo -e "${YELLOW}[BREAKPOINT] Tekan [Enter] untuk memuat menu seleksi folder...${NC}"
        read -r
    else
        echo -e "${RED}[X] BREAKPOINT ERROR: Gagal terhubung ke remote repository!${NC}"
        echo -e "${RED}Periksa koneksi internet atau ketersediaan SSH Key Anda.${NC}"
        echo -n "Apakah Anda ingin tetap memuat menu dengan cache lokal lama? (y/n): "
        read -r konfirmasi
        if [[ ! "$konfirmasi" =~ ^[yY]$ ]]; then
            echo -e "${RED}[+] Membatalkan proses.${NC}"
            exit 1
        fi
    fi
fi

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY
# ... [Sisa skrip menu di bawahnya tetap sama] ...

```
- Validasi Status Eksekusi (`if/else`): Menguji langsung apakah perintah `git fetch` mengembalikan status sukses (`exit 0`).
- Interopsi Manual (`read -r`): Skrip benar-benar berhenti (menjadi *breakpoint*) dan menunggu Anda menekan tombol **Enter** sebelum membersihkan layar untuk menu utama.
- Penanganan Kegagalan Jaringan: Jika Anda sedang *offline* di Termux, skrip tidak akan langsung *crash* atau menampilkan menu kosong. Skrip akan memberikan pilihan apakah Anda ingin melanjutkan menggunakan struktur daftar folder yang lama (*offline cache*) atau keluar dari skrip.

qa: 
Apakah Anda ingin memasang **kondisi timeout** pada breakpoint tersebut (misalnya otomatis lanjut ke menu jika dalam 5 detik tidak ada tombol yang ditekan), atau mekanismenya sudah **cukup aman** untuk kebutuhan pengujian Anda?

<br>

---

<br>

Kita bisa menambahkan **opsi khusus (misalnya huruf `e`)** di dalam menu utama.

Ketika opsi `e` dipilih, skrip akan memeriksa folder mana saja yang `[ sudah aktif ]` di dalam sistem *sparse-checkout*, menampilkan daftarnya, lalu membuka file `README.md` di dalam folder pilihan Anda menggunakan teks editor `micro`.

Berikut adalah kode lengkap dengan penambahan fitur edit `README.md` menggunakan `micro`:
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

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY
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
  echo " [e] Edit README.md di folder aktif"
  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan pilihan Anda: "
  read pilihan

  # Kondisi keluar dari menu
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    echo -e "\n${YELLOW}[+] Menerapkan perubahan dan melakukan checkout...${NC}"
    git -C "$rp" checkout -f main
    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
    break
  fi

  # FITUR BARU: EDIT README.MD DENGAN MICRO
  if [[ "$pilihan" == "e" || "$pilihan" == "E" ]]; then
    # Cek apakah text editor 'micro' sudah terinstall di Termux
    if ! command -v micro &> /dev/null; then
      echo -e "\n${RED}[X] Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    # Kumpulkan folder yang berstatus aktif ke dalam array baru
    active_folders=()
    for folder in "${targets[@]}"; do
      if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
        active_folders+=("$folder")
      fi
    done

    # Jika belum ada folder yang di-add/diaktifkan
    if [ ${#active_folders[@]} -eq 0 ]; then
      echo -e "\n${RED}[!] Belum ada folder aktif yang bisa diedit. Silakan add folder terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    # Sub-menu untuk memilih folder aktif yang akan diedit
    clear
    echo "========================================"
    echo "   PILIH FOLDER UNTUK EDIT README.MD   "
    echo "========================================"
    for i in "${!active_folders[@]}"; do
      printf " [%d] /%s/README.md\n" $((i+1)) "${active_folders[$i]}"
    done
    echo "----------------------------------------"
    echo -n "Pilih nomor file yang ingin diedit: "
    read num_pilihan

    if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#active_folders[@]}" ]; then
      idx=$((num_pilihan-1))
      target_folder="${active_folders[$idx]}"
      target_file="${rp}/${target_folder}/README.md"

      # Buat folder & file tiruan secara lokal jika belum ter-checkout fisik agar micro tidak error
      mkdir -p "${rp}/${target_folder}"
      touch "$target_file"

      # Buka file menggunakan micro
      echo -e "\n${YELLOW}[+] Membuka ${target_folder}/README.md dengan micro...${NC}"
      sleep 0.5
      micro "$target_file"
    else
      echo -e "\n${RED}[X] Pilihan file tidak valid.${NC}"
      sleep 1
    fi
    continue
  fi

  # Validasi input angka biasa untuk menambahkan folder
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

💡 Kelebihan Fitur Baru Ini:
- Validasi Editor `micro`: Skrip otomatis mendeteksi apakah micro sudah terinstall di Termux Anda. Jika belum, skrip akan memberikan instruksi instalasi (`pkg install micro`) alih-alih mengalami *crash*.
- Hanya Menampilkan Folder Aktif: Sub-menu edit (`[e]`) secara cerdas menyaring folder-folder yang **memang sudah di-add** ke dalam `sparse-checkout`, sehingga Anda tidak akan mengedit file di folder yang belum diunduh.
- Penciptaan Jalur Aman (mkdir -p & touch): Jika folder baru saja di-add dan belum sempat melewati proses `git checkout -f main` di akhir skrip, struktur foldernya akan disiapkan secara instan agar editor `micro` bisa langsung membuat atau membuka file `README.md` tersebut tanpa kendala *directory not found*.

<br>

qa: 
Apakah Anda ingin skrip ini langsung melakukan `git commit` dan `git push` otomatis ke GitHub setiap kali Anda selesai menutup/menyimpan perubahan file `README.md` di dalam editor `micro`?

<br>

---

<br>

aa: 
Kita bisa menukar perintah `git ls-tree -d` (yang hanya membaca folder tingkat pertama) dengan perintah `git ls-tree -r --name-only`, di mana opsi **`-r` (recursive)** akan membongkar seluruh struktur repositori dari folder utama, sub-folder, hingga semua file di dalamnya secara *real-time*.

Dengan metode ini, menu seleksi edit (`[e]`) tidak lagi terbatas pada `README.md`, melainkan akan **menampilkan seluruh file yang ada di dalam folder-folder aktif Anda**.

Berikut adalah pembaruan kode lengkapnya:
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

# 4. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Hanya Folder Tingkat Pertama untuk Menu Utama)
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
  echo " [q] Keluar & Terapkan Perubahan (Checkout)"
  echo "========================================"
  echo -n "Masukkan pilihan Anda: "
  read pilihan

  # Kondisi keluar dari menu
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    echo -e "\n${YELLOW}[+] Menerapkan perubahan dan melakukan checkout...${NC}"
    git -C "$rp" checkout -f main
    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
    break
  fi

  # FITUR BARU: JELAJAHI DAN EDIT SELURUH FILE DI FOLDER AKTIF
  if [[ "$pilihan" == "e" || "$pilihan" == "E" ]]; then
    if ! command -v micro &> /dev/null; then
      echo -e "\n${RED}[X] Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    # 1. Kumpulkan dulu folder tingkat pertama mana saja yang sedang aktif
    active_folders=()
    for folder in "${targets[@]}"; do
      if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
        active_folders+=("$folder")
      fi
    done

    if [ ${#active_folders[@]} -eq 0 ]; then
      echo -e "\n${RED}[!] Belum ada folder aktif. Silakan add folder terlebih dahulu sebelum mengedit file.${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    # 2. Ambil SELURUH file & sub-file secara rekursif dari remote GitHub
    echo -e "\n${YELLOW}[+] Memetakan seluruh file dan sub-folder secara rekursif...${NC}"
    mapfile -t all_remote_files < <(git -C "$rp" ls-tree -r --name-only origin/main 2>/dev/null)

    # 3. Filter file: Hanya tampilkan file yang berada di dalam folder yang sudah aktif
    valid_files=()
    for file in "${all_remote_files[@]}"; do
      for active_dir in "${active_folders[@]}"; do
        # Jika jalur file diawali dengan nama folder aktif (misal: diff/sub/file.txt)
        if [[ "$file" == "$active_dir"/* ]]; then
          valid_files+=("$file")
          break
        fi
      done
    done

    if [ ${#valid_files[@]} -eq 0 ]; then
      echo -e "\n${YELLOW}[!] Folder aktif Anda kosong (tidak ada file di dalamnya).${NC}"
      echo -n "Tekan [Enter] untuk kembali..."
      read -r; continue
    fi

    # 4. Tampilkan sub-menu seluruh file yang tersedia untuk diedit
    clear
    echo "========================================"
    echo "   DAFTAR FILE YANG DAPAT DIEDIT        "
    echo "========================================"
    for i in "${!valid_files[@]}"; do
      printf " [%d] %s\n" $((i+1)) "${valid_files[$i]}"
    done
    echo "----------------------------------------"
    echo -n "Pilih nomor file yang ingin diedit dengan micro: "
    read num_pilihan

    if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
      idx=$((num_pilihan-1))
      selected_file="${valid_files[$idx]}"
      full_file_path="${rp}/${selected_file}"

      # Ambil direktori induk dari file tersebut untuk mkdir agar tidak crash jika ada sub-folder baru
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

  # Validasi input angka biasa untuk menambahkan folder utama
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

🛠️ Poin Perubahan Cerdas:
- `git ls-tree -r --name-only origin/main`: Digunakan saat Anda masuk ke tombol `e`. Perintah ini memetakan seluruh isi repositori secara mendalam (termasuk folder di dalam folder, dan file di ujungnya) langsung dari GitHub.
- Filter Pengaman Jalur Terbuka (`[[ "$file" == "$active_dir"/* ]]`): Skrip akan mencocokkan bagan struktur pohon file. Skrip **hanya akan meloloskan file** yang berada di bawah naungan folder-folder utama yang statusnya sudah `[ sudah aktif ]`. Anda terhindar dari ketidaksengajaan mengedit file di folder tersembunyi yang belum diaktifkan.
- `dirname` dan Dinamisasi Struktur: Jika Anda memilih file di dalam sub-folder dalam (misal: `diff/fitur/baru/script.py`), perintah dirname akan mendeteksi folder pembungkusnya dan mengeksekusi `mkdir -p` secara otomatis, menjamin `micro` terbuka mulus tanpa pesan error *Directory nonexistent*.

<br>

qa: 
Apakah Anda ingin ditambahkan opsi untuk **membuat file baru** secara manual di dalam sub-folder pilihan Anda langsung lewat menu ini, atau ingin **menampilkan ekstensi file tertentu saja** (misalnya hanya memunculkan file `.sh` atau `.md`) di daftar edit agar menu terlihat lebih rapi?

<br>

---

<br>

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
  read pilihan

  # PERBAIKAN LOGIKA KELUAR [q] (Mencegah Kehilangan Hasil Edit)
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    # Cek status perubahan file lokal menggunakan git status
    perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

    if [ -n "$perubahan_lokal" ]; then
      echo -e "\n${YELLOW}[!] PERINGATAN: Ada file yang telah Anda ubah/tambahkan secara lokal!${NC}"
      echo "$perubahan_lokal"
      echo "----------------------------------------"
      echo "Pilih tindakan Anda:"
      echo " [1] Simpan perubahan (Commit secara lokal)"
      echo " [2] Abaikan & Paksa update (Buang hasil editan Anda)"
      echo " [3] Batalkan Keluar (Kembali ke menu)"
      echo "----------------------------------------"
      echo -n "Pilihan Anda (1/2/3): "
      read aksi_keluar

      if [ "$aksi_keluar" == "1" ]; then
        echo -n "Masukkan pesan commit: "
        read pesan_commit
        [ -z "$pesan_commit" ] && pesan_commit="Update file via termux automation script"
        
        git -C "$rp" add .
        git -C "$rp" commit -m "$pesan_commit"
        echo -e "${GREEN}[✓] Perubahan berhasil disimpan ke commit lokal!${NC}"
      elif [ "$aksi_keluar" == "2" ]; then
        echo -e "${RED}[!] Membuang perubahan lokal dan melakukan paksa checkout...${NC}"
        git -C "$rp" checkout -f main
      else
        echo -e "${YELLOW}[+] Kembali ke menu utama...${NC}"
        sleep 1; continue
      fi
    else
      # Jika tidak ada perubahan file sama sekali, aman melakukan re-checkout biasa
      echo -e "\n${YELLOW}[+] Menerapkan perubahan struktur sparse-checkout...${NC}"
      git -C "$rp" checkout main
    fi

    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
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
    read folder_pilihan

    if [[ "$folder_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_pilihan" -ge 1 ] && [ "$folder_pilihan" -le "${#active_folders[@]}" ]; then
      idx=$((folder_pilihan-1))
      parent_folder="${active_folders[$idx]}"

      echo "----------------------------------------"
      echo -e "Folder terpilih: ${YELLOW}/${parent_folder}/${NC}"
      echo "Masukkan nama file baru (Bisa pakai sub-folder, misal: sub/file.sh atau langsung: script.py)"
      echo -n "Nama file: "
      read nama_file_baru

      if [ -z "$nama_file_baru" ]; then
        echo -e "${RED}[X] Nama file tidak boleh kosong!${NC}"
        sleep 1; continue
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

    echo -e "\n${YELLOW}[+] Memetakan seluruh file dan sub-folder secara rekursif...${NC}"
    mapfile -t all_remote_files < <(git -C "$rp" ls-tree -r --name-only origin/main 2>/dev/null)

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
      read -r; continue
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
    read num_pilihan

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

  # Validasi input angka biasa untuk menambahkan folder utama
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

  # PERBAIKAN LOGIKA KELUAR [q] (Dengan Auto-Increment Commit Message)
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
        # GENERATOR AUTO-INCREMENT PESAN COMMIT
        # Mencari angka commit terakhir yang berformat "u<angka>" dari log Git
        last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
        
        if [[ "$last_num" =~ ^[0-9]+$ ]]; then
          # Jika ditemukan, angka ditambahkan 1
          next_num=$((last_num + 1))
          auto_msg="u${next_num}"
        else
          # Jika tidak ditemukan riwayat commit berformat u<angka>, mulai dari u1
          auto_msg="u1"
        fi

        echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
        echo -n "Tekan [Enter] untuk menggunakan nama di atas, atau ketik pesan manual: "
        read -r pesan_commit
        
        # Jika user langsung menekan enter, gunakan pesan otomatis
        [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"
        
        git -C "$rp" add .
        git -C "$rp" commit -m "$pesan_commit"
        echo -e "${GREEN}[✓] Perubahan berhasil disimpan dengan pesan commit: '$pesan_commit'${NC}"
      elif [ "$aksi_keluar" == "2" ]; then
        echo -e "${RED}[!] Membuang perubahan lokal dan melakukan paksa checkout...${NC}"
        git -C "$rp" checkout -f main
      else
        echo -e "${YELLOW}[+] Kembali ke menu utama...${NC}"
        sleep 1; continue
      fi
    else
      echo -e "\n${YELLOW}[+] Menerapkan perubahan struktur sparse-checkout...${NC}"
      git -C "$rp" checkout main 2>/dev/null
    fi

    echo -e "${GREEN}[✓] Selesai dengan sukses!${NC}"
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
        sleep 1; continue
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

    echo -e "\n${YELLOW}[+] Memetakan seluruh file dan sub-folder secara rekursif...${NC}"
    mapfile -t all_remote_files < <(git -C "$rp" ls-tree -r --name-only origin/main 2>/dev/null)

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
      echo -n "Tekan [Enter]のために kembali..."
      read -r; continue
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

    # =====================================================================
    # POTONGAN KODE PERBAIKAN UNTUK PILIHAN MENU NOMOR FILE (MENU EDIT)
    # =====================================================================
    if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
      idx=$((num_pilihan - 1))
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

  # =====================================================================
  # POTONGAN KODE PERBAIKAN UNTUK VALIDASI PROSES UTAMA (ADD FOLDER UTAMA)
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
done

```




<br>

aa: 
Untuk menambahkan perbandingan log antara repositori **Local** dan **Remote**, kita bisa memanfaatkan perintah `git log` dengan membandingkan commit terakhir (*HEAD*) dari lokal (`main`) dan remote (`origin/main`).

Dengan menampilkan SHA hash short (7 karakter) dan pesan commit dari kedua sisi secara berdampingan, Anda bisa langsung tahu apakah statusnya sudah sama atau masih ada commit lokal yang belum di-push.

Berikut adalah potongan kode perbaikan khusus untuk **Logika Keluar `[q]`** yang sudah ditambahkan fitur komparasi log real-time beserta konfirmasi `git push`:

### 🛠️ Potongan Kode Perbaikan Khusus (Logika Keluar `[q]`)
Gantikan blok logika `if [[ "$pilihan" == "q" ... fi` yang lama dengan kode di bawah ini:
```bash
  # =====================================================================
  # POTONGAN KODE PERBAIKAN UNTUK LOGIKA KELUAR [q] (KOMPARASI LOG & AUTO-PUSH)
  # =====================================================================
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

    # 1. JIKA ADA PERUBAHAN YANG BELUM DI-COMMIT
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
  fi

```

### 🔍 Fitur Utama yang Ditambahkan:
- `git log -1 --format="%h - %s"`: Mengambil 1 baris commit terakhir yang berisi singkatan hash SHA (`%h`) dan pesan commit (`%s`) dari masing-masing branch (`main` vs `origin/main`).
- Visual Pembeda: Menampilkan label `[Local]` dan `[Remote]` secara vertikal agar mata Anda bisa langsung mencocokkan teks hash dan pesan dengan mudah sebelum mengambil keputusan.
- Deteksi `rev-list --count`: Skrip secara cerdas menghitung jumlah commit yang ada di lokal tetapi belum ada di remote server (`origin/main..main`). Jika nilainya di atas `0`, tombol konfirmasi push baru akan dipicu.
- Keamanan Eksekusi: Perintah `git push` tidak akan berjalan secara otomatis, melainkan menunggu konfirmasi ketukan huruf `y` dari Anda setelah Anda melihat komparasi lognya secara visual.

<br>

qa: 
Apakah Anda ingin menambahkan **mekanisme deteksi branch otomatis** (misalnya mengambil nama branch aktif saat ini melalui `git branch --show-current`) agar tidak terpaku pada hardcode branch `main`, atau logika di atas sudah **cukup presisi** untuk alur kerja Anda?

<br>

---

<br>

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
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

    # 1. JIKA ADA PERUBAHAN YANG BELUM DI-COMMIT
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
        sleep 1; continue
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

    echo -e "\n${YELLOW}[+] Memetakan seluruh file dan sub-folder secara rekursif...${NC}"
    mapfile -t all_remote_files < <(git -C "$rp" ls-tree -r --name-only origin/main 2>/dev/null)

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
      echo -n "Tekan [Enter]のために kembali..."
      read -r; continue
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

    # =====================================================================
    # POTONGAN KODE PERBAIKAN UNTUK PILIHAN MENU NOMOR FILE (MENU EDIT)
    # =====================================================================
    if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
      idx=$((num_pilihan - 1))
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

  # =====================================================================
  # POTONGAN KODE PERBAIKAN UNTUK VALIDASI PROSES UTAMA (ADD FOLDER UTAMA)
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
done

```


<br>
