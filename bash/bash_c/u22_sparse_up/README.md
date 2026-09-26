

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
