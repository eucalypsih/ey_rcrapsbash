# 



Memindahkan **PERBANDINGAN STATUS COMMIT** ke bagian paling atas adalah alur yang jauh lebih logis dan direkomendasikan. Dengan begitu, Anda bisa melihat perbedaan status commit antara `[Local]` dan `[Remote]` terlebih dahulu sebagai bahan pertimbangan sebelum menentukan pesan commit.

Berikut adalah potongan kode perbaikan total untuk blok logika keluar `[q]`.

### 🛠️ Potongan Kode Perbaikan (Gantikan blok `if [[ "$pilihan" == "q" ... fi` pada skrip Anda)
```bash
  # =====================================================================
  # LOGIKA KELUAR [q] (KOMPARASI COMMIT DULU BARU COMMIT/PUSH)
  # =====================================================================
  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    # 1. TAMPILKAN KOMPARASI STATUS COMMIT TERLEBIH DAHULU
    echo -e "\n========================================"
    echo -e "       PERBANDINGAN STATUS COMMIT       "
    echo -e "========================================"
    
    local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
    remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)
    
    echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
    echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
    echo -e "----------------------------------------"

    # 2. CEK UNCOMMITTED CHANGES (FILE YANG DIUBAH LOKAL)
    perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null)

    if [ -n "$perubahan_lokal" ]; then
      echo -e "${RED}[!] PERINGATAN: Ada file yang telah Anda ubah/tambahkan secara lokal!${NC}"
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

        echo -e "\nPesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
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

    # 3. PROSES VALIDASI AUTO-PUSH PASCA-COMMIT
    # Hitung ulang status setelah kemungkinan adanya commit baru di atas
    ahead_commits=$(git -C "$rp" rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null)

    if [ "${ahead_commits:-0}" -gt 0 ]; then
      # Perbarui log local untuk tampilan push yang akurat
      local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
      echo -e "\n========================================"
      echo -e "          KONFIRMASI UPLOAD (PUSH)      "
      echo -e "========================================"
      echo -e "[Local Terbaru]: ${YELLOW}${local_log}${NC}"
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

```

### 🔍 Apa Saja Perubahan Alurnya?
1. Visual Log Duluan: Begitu Anda menekan `q`, papan **PERBANDINGAN STATUS COMMIT** langsung tercetak paling atas. Anda bisa melihat status sinkronisasi terakhir sebelum menentukan langkah berikutnya.
2. Papan Konfirmasi Push Dinamis: Jika Anda memilih opsi `1` untuk melakukan commit baru (misal `u28`), skrip secara cerdas akan memunculkan papan konfirmasi kedua bernama **KONFIRMASI UPLOAD (PUSH)** yang memperlihatkan commit lokal terbaru Anda, lalu menawarkan pilihan untuk langsung mengunggahnya ke GitHub.















<br>
