# 



```bash
  _cc "----------------------------------------"
  echo -e " [e] ${GREEN}Edit File (Jelajahi Folder Aktif)${NC}"
  echo -e " [n] ${GREEN}Buat File Baru di Folder Aktif${NC}"
  echo -e " [d] ${RED}Hapus File atau Sub-Folder (Git RM)${NC}"
  echo -e " [q] ${RED}Keluar & Terapkan Perubahan (Checkout)${NC}"
  echo -e " [b] ${YELLOW}Kembali ke Menu Pilih Repositori Utama${NC}" # <-- TAMBAHKAN BARIS INI
  _cc "========================================"

```

```bash
  case "$pilihan" in
    [bB])
      # =====================================================================
      # OPSI KEMBALI KE MENU UTAMA (Menghentikan loop menu sparse-checkout)
      # =====================================================================
      _r "Meninggalkan repositori. Kembali ke Pemilihan Utama..."
      sleep 1
      break # <-- Break di sini akan memutus loop menu interaktif sparse dan memicu main.sh memuat ulang loop terluarnya
      ;;

    [qQ])
      # =====================================================================
      # MEMANGGIL MODUL EKSTERNAL (Evaluasi Commit, Perbandingan Log, & Auto-Push)
      # =====================================================================

```

---

- `main.sh`
```bash
#!/bin/bash



# =====================================================================
# SISTEM LOGGING & UX TERMINAL KUSTOM (DIAMBIL DARI LIBRARY CONFIG)
# =====================================================================
# Mengunci jalur relatif modul_sh untuk memuat library warna terpusat
if [ -f "./modul_sh/utils.sh" ]; then
  source "./modul_sh/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL ERROR: File './modul_sh/utils.sh' tidak ditemukan!\033[0m"
  exit 1
fi
# =====================================================================



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
    ey_rcraps
    ey_rcrapsc
    ey_rsrapsc
    ey_rcrapsrs
    ey_rsrapsrs
    eucalypsih_rcrapsbash
    ey_tp
    ey_ta
    eucalypsih_rcrapskt
    ey_vsvapsosj

owner_lain
    repo1
    repo2
EOF
  sleep 1
fi # end if [ ! -f "$repo_file" ]


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
  log_section "Daftar Repositori Terpantau (Format: owner/repo):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Cek apakah folder repo lokal fisik sudah ada berdasarkan nama reponya saja
      owner_name="${valid_repos[$i]%%/*}"
      local_repo_name="${valid_repos[$i]#*/}"

      status_str=" %b[ daftar aktif ]%b"
      status_args=("${GREEN}" "${NC}")
      if [ -d "${PWD}/${owner_name}/${local_repo_name}/.git" ]; then
        status_str="${status_str} %b[ lokal aktif ]%b"
        status_args+=("${CYAN}" "${NC}")
      fi
      printf " [%d] %-30s${status_str}\n" $((i+1)) "${valid_repos[$i]}" "${status_args[@]}"
    done
  fi

  _cc "----------------------------------------"
  echo -e " [t] ${GREEN}Tambah Repositori Baru${NC}"
  echo -e " [h] ${RED}Hapus Repo dari Daftar rp.txt${NC}"
  echo -e " [f] ${YELLOW}Hanya Hapus Folder Fisik Lokal${NC}"
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

  # OPSI HAPUS REPO DARI DAFTAR (MODULARISASI)
  if [[ "$repo_pilihan" =~ ^[hH]$ ]]; then
    if [ -f "./modul_sh/h.sh" ]; then
      # Melempar argumen: repo_file (1), valid_repos (2)
      bash ./modul_sh/h.sh "$repo_file" "${valid_repos[*]}"
    else
      _e "File './modul_sh/h.sh' tidak ditemukan!"
      _pp
    fi
    continue
  fi

  # FITUR BARU REKOMENDASI: OPSI [f] HANYA HAPUS FOLDER FISIK (TANPA MENGUBAH rp.txt)
  if [[ "$repo_pilihan" =~ ^[fF]$ ]]; then
    if [ -f "./modul_sh/f.sh" ]; then
      # Melempar argumen: valid_repos (1)
      bash ./modul_sh/f.sh "${valid_repos[*]}"
    else
      _e "File './modul_sh/f.sh' tidak ditemukan!"
      _pp
    fi
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
    # break <-- HAPUS ATAU KOMENTARI BARIS INI AGAR LOOP MENU UTAMA TETAP HIDUP
  else
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], [f], atau [q]."
    sleep 1.5
    continue # <-- KOREKSI: Melompat kembali ke atas jika salah input angka
  fi



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
  # MODULARISASI: MANAJEMEN SSH KEY & PENGAMAN SEBELUM CLONE (ssh_handler.sh)
  # =====================================================================
# _ic "Mengonfigurasi SSH Key dinamis untuk owner: ${o}..." <-- KOREKSI: Hapus/komentari baris ini

  # Jalur SSH Key spesifik untuk masing-masing owner
  owner_privkey="${HOME}/.ssh/id_rsa_${o}"
  owner_pubkey="${HOME}/.ssh/id_rsa_${o}.pub"
  # Periksa koneksi internet hanya jika key belum ada atau folder belum di-clone
  if [ -f "./modul_sh/ssh_handler.sh" ]; then
    # Melempar argumen: owner (1), rp (2), owner_privkey (3), owner_pubkey (4)
    bash ./modul_sh/ssh_handler.sh "$o" "$rp" "$owner_privkey" "$owner_pubkey"
    
    # Jika skrip eksternal melempar error (karena offline atau gagal curl), hentikan alur main.sh
    if [ $? -ne 0 ]; then
      continue
    fi
  else
    _e "File './modul_sh/ssh_handler.sh' tidak ditemukan!"
    _pp
    continue
  fi
  # =====================================================================



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
    if [ -f "./modul_sh/init_git.sh" ]; then
      # Melempar argumen: rp (1), o (2), owner_pubkey (3), owner_privkey (4)
      bash ./modul_sh/init_git.sh "$rp" "$o" "$owner_pubkey" "$owner_privkey"

    else
      _e "File './modul_sh/init_git.sh' tidak ditemukan!"
      _pp
      exit 1
    fi
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
    echo -e " [d] ${RED}Hapus File atau Sub-Folder (Git RM)${NC}"
    echo -e " [q] ${RED}Keluar & Terapkan Perubahan (Checkout)${NC}"
    echo -e " [b] ${YELLOW}Kembali ke Menu Pilih Repositori Utama${NC}"
    _cc "========================================"
    _p "Masukkan pilihan Anda"
    read -r pilihan

    # =====================================================================
    # POTONGAN KODE PERBAIKAN UNTUK LOGIKA KELUAR [q] (KOMPARASI LOG & AUTO-PUSH)
    # =====================================================================
    case "$pilihan" in
      [bB])
        # =====================================================================
        # OPSI KEMBALI KE MENU UTAMA (Menghentikan loop menu sparse-checkout)
        # =====================================================================
        _r "Meninggalkan repositori. Kembali ke Pemilihan Utama..."
        sleep 1
        break # <-- Break di sini akan memutus loop menu interaktif sparse dan memicu main.sh memuat ulang loop terluarnya
        ;;

      [qQ])
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL (Evaluasi Commit, Perbandingan Log, & Auto-Push)
        # =====================================================================
        if [ -f "./modul_sh/q.sh" ]; then
          
          # Eksekusi skrip eksternal q.sh dengan melemparkan parameter lengkap
          bash ./modul_sh/q.sh "$rp" "$r" "$current_branch" "${targets[*]}" "$current_sparse"

          # --- PERBAIKAN UTAMA: Tangkap suksesnya q.sh dan paksa main.sh untuk keluar total ---
          if [ $? -eq 0 ]; then
            exit 0
          fi
        else
          _e "File './modul_sh/q.sh' tidak ditemukan!"
          _pp
        fi
        # break
        ;;


      [dD])
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL (Melempar data langsung sebagai parameter)
        # =====================================================================
        if [ -f "./modul_sh/d.sh" ]; then
          # Mengirim data tambahan: "${targets[*]}" (argumen 4) dan "$current_sparse" (argumen 5)
          bash ./modul_sh/d.sh "$rp" "$r" "$current_branch" "${targets[*]}" "$current_sparse"
        else
          _e "File './modul_sh/d.sh' tidak ditemukan!"
          _pp
        fi
        ;; # Menutup opsi [dD] dengan benar

      [nN])
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL (Melempar data langsung sebagai parameter)
        # =====================================================================
        if [ -f "./modul_sh/n.sh" ]; then
          # Mengirim data tambahan: "${targets[*]}" (argumen 4) dan "$current_sparse" (argumen 5)
          bash ./modul_sh/n.sh "$rp" "$r" "$current_branch" "${targets[*]}" "$current_sparse"
        else
          _e "File './modul_sh/n.sh' tidak ditemukan!"
          _pp
        fi
        ;; # Menutup opsi [nN] dengan benar

      [eE])
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL (Melempar data langsung sebagai parameter)
        # =====================================================================
        if [ -f "./modul_sh/e.sh" ]; then
          # Mengirim data tambahan: "${targets[*]}" (argumen 4) dan "$current_sparse" (argumen 5)
          bash ./modul_sh/e.sh "$rp" "$r" "$current_branch" "${targets[*]}" "$current_sparse"
        else
          _e "File './modul_sh/e.sh' tidak ditemukan!"
          _pp
        fi
        ;;

      [0-9]*)
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL (Melempar data langsung sebagai parameter)
        # MEMANGGIL MODUL EKSTERNAL (Aktivasi / Nonaktifkan Folder Sparse-Checkout)
        # =====================================================================
        if [ -f "./modul_sh/num.sh" ]; then
          # Mengirim data tambahan: "${targets[*]}" (argumen 4) dan "$current_sparse" (argumen 5)

          # Eksekusi modul eksternal angka dengan melemparkan parameter lengkap beserta input pilihan user
          bash ./modul_sh/num.sh "$rp" "$r" "$current_branch" "${targets[*]}" "$current_sparse" "$pilihan"
        else
          _e "File './modul_sh/num.sh' tidak ditemukan!"
          _pp
        fi

        # OPTIMASI KRUSIAL: Lewati fungsi prompt_pause bawaan agar menu utama langsung
        # me-refresh dan memperbarui status visual [ sudah aktif ] secara real-time.
        # Optimasi krusial agar menu langsung refresh status visual secara real-time
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

  done # end while menu interaktif (Penutup Menu Sparse)

done # end while menu utama (PINDAHKAN KE SINI: Penutup Terluar Skrip Utama)

```

- `modul_sh/`
<br>
