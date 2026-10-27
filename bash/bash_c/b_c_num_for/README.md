# 

aa: 
Perintah asli Anda:
`git -C "$rp" ls-tree -d --name-only "origin/${current_branch}"`

Flag `-d` secara mutlak memerintahkan Git untuk **hanya mencari folder**, sehingga file-file biasa yang berada di root direktori (seperti `README.md`, `.gitignore`, dll.) akan langsung dibuang dan tidak akan pernah masuk ke dalam array `targets`.

Namun, jika maksud Anda adalah ingin membuat menu seleksi otomatis tersebut **bisa memetakan folder SEKALIGUS file-file biasa di root** agar bisa dipilih/dilihat, jawabannya adalah **BISA, dengan mengubah parameter perintah Git-nya**.

---

## 🛠️ Solusi Perbaikan Kode pada `main.sh`
Buka berkas `main.sh` Anda, cari baris **ke-425** (Bagian 4. OTOMATISASI DAFTAR TARGET), lalu ganti blok kode lama dengan pilihan solusi di bawah ini:

### Pilihan A: Memasukkan Folder dan File Root ke dalam Satu Menu (Sangat Direkomendasikan)
Hapus flag `-d` agar Git membaca semua objek di root, baik berupa folder maupun file biasa:
```bash
# GANTI BARIS 425 DENGAN KODE INI:
# Membaca seluruh isi root (folder & file) tingkat pertama dari remote
mapfile -t targets < <(git -C "$rp" ls-tree --name-only "origin/${current_branch}" 2>/dev/null)

```

### Pilihan B: Memisahkan Deteksi Folder dan File Root (Jika Menu Ingin Tetap Rapi)
Jika Anda hanya ingin array `targets` tersebut tahu mana folder dan mana file saat dicetak pada perulangan loop menu bawahnya (baris 439-447), Anda bisa mengambil tipe datanya menggunakan flag `-r`:
```bash
# Mengambil nama beserta tipe objeknya (tree = folder, blob = file)
mapfile -t targets < <(git -C "$rp" ls-tree "origin/${current_branch}" 2>/dev/null | awk '{print $4}')

```

---

## 🔍 Perubahan Penting pada Tampilan Menu Loop (Baris 439)
Jika Anda merubah perintah `mapfile` di atas menggunakan **Pilihan A**, Anda juga harus menyesuaikan cara skrip mencetak visual menu interaktifnya di bawah. Cari baris loop `for i in "${!targets[@]}"; do` (Sekitar baris 439), lalu sesuaikan kodenya agar tanda garing (`/`) hanya muncul pada folder, bukan pada file:
```bash
# GANTI BLOK LOOP CETAK MENU (SEKITAR BARIS 439-447) DENGAN INI:
for i in "${!targets[@]}"; do
  item="${targets[$i]}"
  
  # Cek status keaktifan di sparse-checkout list
  status_aktif=""
  if echo "$current_sparse" | grep -qE "^/?${item}/?$"; then
    status_aktif="  ${GREEN}[ sudah aktif ]${NC}"
  fi

  # PERBAIKAN VISUAL: Deteksi apakah item ini folder fisik atau file biasa di lokal/remote
  # Kita bisa cek apakah item ini ada di remote sebagai tree/folder menggunakan git cat-file
  tipe_item=$(git -C "$rp" cat-file -t "origin/${current_branch}:${item}" 2>/dev/null)

  if [ "$tipe_item" == "tree" ]; then
    # Jika folder, cetak dengan tanda kurung / di depannya
    printf " [%d] /%-12s%b\n" $((i+1)) "$item" "$status_aktif"
  else
    # Jika file di root, cetak nama filenya saja secara bersih
    printf " [%d]  %-12s%b\n" $((i+1)) "$item" "$status_aktif"
  fi
done

```

---

## 📊 Perbandingan Logika Perintah Git


| Parameter Perintah Git | Output yang Terbaca | Dampak pada Menu Seleksi |
| :--- | :--- | :--- |
| `ls-tree -d` *(Lama)* | Hanya Folder Tingkat 1 | File root diabaikan dari daftar array `targets`. |
| `ls-tree` *(Solusi A)* | Folder + File Tingkat 1 | Semua file root masuk daftar menu dan bisa di-track secara interaktif. |

---

<br>

---

<br>

---

```bash
  # Membaca seluruh isi root (folder & file) tingkat pertama dari remote
  mapfile -t targets < <(git -C "$rp" ls-tree --name-only "origin/${current_branch}" 2>/dev/null)

  if [ ${#targets[@]} -eq 0 ]; then
      # Alih-alih keluar (exit 1), berikan peringatan visual saja dan biarkan skrip berlanjut
      _w "Repositori saat ini tidak memiliki folder (hanya berisi file root)."
      sleep 1.5
  fi # end if target kosong

  # MENU INTERAKTIF SELEKSI FOLDER
  while true; do # Loop Sparse (Tingkat 1 / Posisi saat ini)
    clear
    _cc "========================================"
    _cc "   SISTEM SELEKSI SPARSE-CHECKOUT       "
    _cc "========================================"
    _cc "Daftar folder otomatis dari Remote:"
    echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"

    current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

    # GANTI BLOK LOOP CETAK MENU (SEKITAR BARIS 439-447) DENGAN INI:
    for i in "${!targets[@]}"; do
      item="${targets[$i]}"
      
      # Cek status keaktifan di sparse-checkout list
      status_aktif=""
      if echo "$current_sparse" | grep -qE "^/?${item}/?$"; then
        status_aktif="  ${GREEN}[ sudah aktif ]${NC}"
      fi

      # PERBAIKAN VISUAL: Deteksi apakah item ini folder fisik atau file biasa di lokal/remote
      # Kita bisa cek apakah item ini ada di remote sebagai tree/folder menggunakan git cat-file
      tipe_item=$(git -C "$rp" cat-file -t "origin/${current_branch}:${item}" 2>/dev/null)

      if [ "$tipe_item" == "tree" ]; then
        # Jika folder, cetak dengan tanda kurung / di depannya
        printf " [%d] /%-12s%b\n" $((i+1)) "$item" "$status_aktif"
      else
        # Jika file di root, cetak nama filenya saja secara bersih
        printf " [%d]  %-12s%b\n" $((i+1)) "$item" "$status_aktif"
      fi
    done # end for targets

    _cc "----------------------------------------"
    echo -e " [e] ${GREEN}Edit File (Jelajahi Folder Aktif)${NC}"
    echo -e " [n] ${GREEN}Buat File Baru di Folder Aktif${NC}"

```












<br>
