# 

qc: 
menambahkan fitur **otomatis menghapus folder fisik lokal** yang dinonaktifkan tersebut saat itu juga

---

aa: 
Untuk menambahkan fitur **otomatis menghapus folder fisik lokal** tepat setelah folder tersebut dinonaktifkan dari daftar *sparse-checkout*, kita perlu menyisipkan perintah penghapusan direktori (`rm -rf`) di dalam blok logika sukses penonaktifan Git.

Berikut adalah perubahan spesifik yang perlu Anda lakukan pada skrip Anda:

## 🛠️ Bagian Kode yang Harus Diubah
Cari blok `[0-9]*)` pada skrip Anda saat ini, lalu perhatikan bagian penerapan aturan baru yang memiliki kode:
```bash
            # Terapkan ulang daftar sparse-checkout yang baru
            if git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}"; then
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan!"
            else
              _e "Gagal memperbarui sparse-checkout list."
            fi

```

## 💾 Ganti dengan Blok Kode Baru Ini
Ganti seluruh bagian `[0-9]*)` tersebut dengan kode di bawah ini:
```bash
    [0-9]*)
      # =====================================================================
      # LOGIKA UTAMA: ADD / REMOVE FOLDER UTAMA & PURGE FISIK SEKETIKA
      # =====================================================================
      if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
        idx=$((pilihan - 1))
        selected_folder="${targets[$idx]}"

        # Cek jika folder sudah aktif
        if echo "$current_sparse" | grep -qE "^/?${selected_folder}/?$"; then
          _w "Folder /${selected_folder} saat ini sedang AKTIF."
          _pd "Apakah Anda ingin MENONAKTIFKAN & HAPUS FISIK folder ini dari penyimpanan?"
          read -r konfirmasi_nonaktif

          if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
            _ic "Memproses penonaktifkan folder /${selected_folder}..."

            # Membuat daftar baru yang mengecualikan folder terpilih
            new_sparse_list=()
            new_sparse_list+=("!/*" "/README.md")

            while IFS= read -r line; do
              [ -z "$line" ] && continue
              if [[ "$line" != "!/*" && "$line" != "/README.md" && "$line" != "$selected_folder" && "$line" != "/${selected_folder}" ]]; then
                clean_line=$(echo "$line" | sed 's|^/||')
                new_sparse_list+=("/${clean_line}")
              fi
            done <<< "$current_sparse"

            # Terapkan ulang daftar sparse-checkout yang baru
            if git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}"; then
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan dari Git!"
              
              # =============================================================
              # SEKETIKA PURGE FOLDER FISIK LOKAL
              # =============================================================
              target_folder_fisik="${rp}/${selected_folder}"
              if [ -d "$target_folder_fisik" ]; then
                _ic "Memusnahkan direktori fisik lokal secara otomatis..."
                rm -rf "$target_folder_fisik"
                _o "Folder fisik '${selected_folder}' berhasil dihapus dari penyimpanan."
              fi
              # =============================================================
              
            else
              _e "Gagal memperbarui sparse-checkout list."
            fi
          else
            _c "Tindakan dibatalkan. Folder tetap aktif."
          fi
        else
          # Jika belum aktif, lakukan proses ADD seperti semula
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

## 💡 Keunggulan Alur Baru Ini:
1. Keamanan Eksekusi: Perintah penghapusan folder fisik (`rm -rf`) hanya akan dieksekusi jika perintah penonaktifan Git (`git sparse-checkout set`) mengembalikan status sukses. Hal ini mencegah terhapusnya file lokal berharga secara tidak sengaja jika terjadi eror pada sistem Git Anda.
2. Pembersihan Bersih: Direktori kerja lokal Anda akan langsung bersih seketika tanpa perlu menunggu siklus penutupan skrip atau pemicu `checkout` manual berikutnya.

qa: 
Apakah Anda ingin mengintegrasikan fitur ini dengan **sistem deteksi berkas untracked** (file baru buatan lokal yang belum di-commit) agar skrip memberikan peringatan khusus sebelum folder fisik tersebut dimusnahkan secara permanen?

<br>

---

<br>




<br>
