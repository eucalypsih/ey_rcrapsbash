

### Perbaikan Inisialisasi Deteksi Branch Utama
Di bagian atas skrip, logika diperbaiki agar variabel `$current_branch` benar-benar terisi dengan branch aktif setelah repositori berhasil dideteksi atau dikloning.
```bash
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
# =====================================================================
current_branch="main" # Nilai default awal jika .git belum ada
if [ -d "$rp/.git" ]; then
    detected_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
    [ -n "$detected_branch" ] && current_branch="$detected_branch"
fi

```
(Catatan: Logika deteksi ulang branch ini juga disisipkan tepat di dalam blok `if [ ! -d "$rp" ]` setelah perintah `git clone` berhasil dieksekusi).

---

### Perbaikan Blok Loop Konfigurasi Git (Inisialisasi Sparse Awal)
Argumen perintah `git config` dipisahkan secara eksplisit antara *key* dan *value* (tidak digabung dalam satu variabel string `$item`) untuk menghindari kegagalan pembacaan parameter oleh Git.
```bash
    # PERBAIKAN: Menjalankan konfigurasi secara eksplisit (Key dan Value terpisah)
    git -C "$rp" config user.name "eucalypsih"
    git -C "$rp" config user.email "eucalypsih@gmail.com"
    git -C "$rp" config gpg.format "ssh"
    git -C "$rp" config user.signingkey "~/.ssh/id_rsa.pub"
    git -C "$rp" config commit.gpgsign true
    git -C "$rp" config gpg.ssh.allowedSignersFile "~/.ssh/allowed_signers"
    sleep 0.5

```

---

### Dinamisasi Nama Branch pada Blok `else` Fetching Data
Mengubah teks `main` yang sebelumnya diketik manual (*hardcode*) menjadi variabel `"$current_branch"`.
```bash
else
    echo -e "${GREEN}[✓] Repositori terdeteksi sudah terinisialisasi.${NC}"
    echo -e "${YELLOW}[+] Memperbarui informasi struktur folder dari remote...${NC}"
    
    # PERBAIKAN: Menggunakan $current_branch secara dinamis, bukan 'main' secara manual
    if git -C "$rp" fetch -q origin "$current_branch" 2>/dev/null; then
        echo -e "${GREEN}[✓] Sukses menarik data terbaru dari origin/${current_branch}.${NC}"

```
Dan untuk pemetaan target array di bawahnya, diubah juga menjadi:
```bash
# PERBAIKAN: Menggunakan branch dinamis pada ls-tree
mapfile -t targets < <(git -C "$rp" ls-tree -d --name-only "origin/${current_branch}" 2>/dev/null)

```

---

### Sinkronisasi Branch Dinamis pada Opsi `[qQ]` (Keluar & Terapkan Perubahan)
Semua perintah Git yang berhubungan dengan penargetan branch saat proses keluar dipastikan menggunakan variabel `"$current_branch"` dan `"origin/${current_branch}"`.
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

```

