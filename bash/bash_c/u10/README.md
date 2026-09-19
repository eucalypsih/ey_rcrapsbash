# 

Anda ingin potongan kode perubahannya ditulis dalam format **blok utuh yang kontekstual** (lengkap dengan kode sekitarnya agar mudah dicari saat proses *copy-paste*), seperti contoh deteksi branch yang Anda berikan.

Berikut adalah **4 bagian kode spesifik** yang berubah, disajikan lengkap dengan kode pembungkus di sekelilingnya:

### 1. Blok Loop Konfigurasi Git (Inisialisasi Sparse Awal)
- Lokasi: Di dalam blok kondisi `if [ -z "$current_sparse" ]; then` (sekitar baris 50-70).
- Perubahan: Mengganti loop `for item in ...` yang rawan eror karena menggabungkan string, menjadi perintah deklarasi `git config` yang terpisah secara eksplisit antara *key* dan *value*.
```bash
# PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
if [ -z "$current_sparse" ]; then
    echo -e "${YELLOW}[+] Menyiapkan inisialisasi awal sparse-checkout...${NC}"
    
    # 2. Inisialisasi awal sparse-checkout dengan README.md
    git -C "$rp" sparse-checkout set --no-cone '!/*' '/README.md' && sleep 0.5

    # =====================================================================
    # PERBAIKAN: Menjalankan konfigurasi secara eksplisit (Key & Value Terpisah)
    # =====================================================================
    git -C "$rp" config user.name "eucalypsih"
    git -C "$rp" config user.email "eucalypsih@gmail.com"
    git -C "$rp" config gpg.format "ssh"
    git -C "$rp" config user.signingkey "~/.ssh/id_rsa.pub"
    git -C "$rp" config commit.gpgsign true
    git -C "$rp" config gpg.ssh.allowedSignersFile "~/.ssh/allowed_signers"
    sleep 0.5
    
    # Perbarui variabel setelah inisialisasi pertama selesai
    current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
else

```

---

### 2. Blok `else` Fetching Data & Pemetaan Target Array
- Perubahan: Mengubah teks kata kunci `main` dan `origin/main` menjadi variabel `"$current_branch"` dan `"origin/${current_branch}"` agar mendukung repositori non-main (misal: `master` atau `dev`).
```bash
else
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi.${NC}"
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    
    # PERBAIKAN: Menggunakan $current_branch secara dinamis, bukan 'main' secara manual
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

# PERBAIKAN: Menggunakan branch dinamis pada ls-tree
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null)

if [ ${#targets[@]} -eq 0 ]; then

```

---

### 3. Logika Keluar `[qQ]` (Komparasi Log & Auto-Push)
- Lokasi: Di bawah pilihan *case* `[qQ]`) pada menu interaktif (sekitar baris 130-200).
- Perubahan: Mengubah seluruh penargetan branch lokal dan remote menjadi dinamis menggunakan variabel `$current_branch`.
```bash
        elif [ "$aksi_keluar" == "2" ]; then
          echo -e "${RED}[!] Membuang perubahan lokal dan melakukan paksa checkout...${NC}"
          # PERBAIKAN: Menggunakan branch dinamis
          git -C "$rp" checkout -f "$current_branch" 2>/dev/null
        else
          echo -e "${YELLOW}[+] Kembali ke menu utama...${NC}"
          sleep 1; continue
        fi
      else
        # PERBAIKAN: Menggunakan branch dinamis
        git -C "$rp" checkout "$current_branch" 2>/dev/null
      fi

      # 2. KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE
      echo -e "\n========================================"
      echo -e "       PERBANDINGAN STATUS COMMIT       "
      echo -e "========================================"

      # PERBAIKAN: Menggunakan branch dinamis untuk log komparasi
      local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
      remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)
  
      echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
      echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
      echo -e "----------------------------------------"

      # PERBAIKAN: Menggunakan branch dinamis untuk menghitung selisih commit
      ahead_commits=$(git -C "$rp" rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null)

      if [ "${ahead_commits:-0}" -gt 0 ]; then
        echo -e "${YELLOW}[!] Status: Local Anda lebih maju ${ahead_commits} commit dari Remote.${NC}"
        echo -n "Apakah Anda yakin ingin melakukan PUSH ke GitHub sekarang? (y/n): "
        read -r konfirmasi_push
      
        if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
          echo -e "${YELLOW}[+] Melakukan git push origin ${current_branch}...${NC}"
          # PERBAIKAN: Menggunakan branch dinamis pada push
          if git -C "$rp" push origin "$current_branch"; then
            echo -e "${GREEN}[✓] Push berhasil! Repositori GitHub telah diperbarui.${NC}"
          else
            echo -e "${RED}[X] Gagal melakukan push! Periksa koneksi atau kredensial SSH Anda.${NC}"
          fi
        else

```

---

### 4. Pengurutan Array di Menu `[eE]` (Jelajahi File)
- Lokasi: Di dalam pilihan case [eE]) setelah proses penggabungan array all_combined_files selesai (sekitar baris 330-345).
- Perubahan: Mengganti cara urut array dari yang sebelumnya `valid_files=($(sort -u <<<...))` menjadi menggunakan printf dengan modifikasi IFS. Ini penting agar nama folder atau file yang mengandung spasi tidak patah/rusak di menu terminal.
```bash
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

          # =====================================================================
          # PERBAIKAN UTAMA DI OPSI [E]: Urutkan dengan aman memakai IFS (Spasi Aman)
          # =====================================================================
          IFS=$'\n' valid_files=($(printf '%s\n' "${all_combined_files[@]}" | sort -u)); unset IFS

          if [ ${#valid_files[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}[!] Folder aktif Anda kosong (tidak ada file untuk diedit).${NC}"

```


<br>

