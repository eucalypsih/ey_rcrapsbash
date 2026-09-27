# 

aa: 
Berikut adalah bagian-bagian dari skrip `main.sh` yang perlu diubah agar mendukung format fleksibel `owner/repo` dari berkas konfigurasi, lengkap dengan proses **Import** yang kompatibel dengan struktur indentasi `rp.txt` dan perubahan variabel `$rp` agar fleksibel.

Anda hanya perlu mengganti **3 blok bagian utama** di dalam skrip `main.sh` lama Anda dengan potongan kode di bawah ini:

## 1. Ubah Blok Pengaman Awal & Inisialisasi File (Baris ~61)
Cari blok pengecekan file `$repo_file` (di skrip lama Anda tertulis `rf.txt`, silakan sesuaikan variabelnya menjadi `rp.txt` agar sesuai dengan kebutuhan baru). Ganti blok inisialisasi default-nya dengan kode ini:
```bash
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
    ey_repo2

owner_lain
    repo1
    repo2
EOF
  sleep 1
fi # end if [ ! -f "$repo_file" ]

```

---

## 2. Ubah Blok Loop Menu Utama (Baris ~73 s.d Baris ~196)
Ganti seluruh blok **while true; do ... done** bagian **Menu Utama Seleksi Repositori** (sebelum deklarasi variabel jalur kerja `rp="${PWD}/${r}"`). Blok ini sudah dimodifikasi menggunakan teknik **Import Loop terstruktur** serta penyesuaian fungsi **Tambah [t]** dan **Hapus [h]** agar otomatis melakukan **Export** kembali ke `rp.txt` sesuai format aslinya.
```bash
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
  log_section "Daftar Repositori Aktif (Format: owner/repo):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Cek apakah folder repo lokal fisik sudah ada berdasarkan nama reponya saja
      local_repo_name="${valid_repos[$i]#*/}"
      if [ -d "${PWD}/${local_repo_name}/.git" ]; then
        printf " [%d] %-30s %b[ lokal aktif ]%b\n" $((i+1)) "${valid_repos[$i]}" "${GREEN}" "${NC}"
      else
        printf " [%d] %-30s\n" $((i+1)) "${valid_repos[$i]}"
      fi
    done
  fi

  _cc "----------------------------------------"
  echo -e " [t] ${GREEN}Tambah Repositori Baru${NC}"
  echo -e " [h] ${RED}Hapus Repo dari Daftar${NC}"
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

  # OPSI HAPUS REPO DARI DAFTAR
  if [[ "$repo_pilihan" =~ ^[hH]$ ]]; then
    if [ ${#valid_repos[@]} -eq 0 ]; then
      _e "Tidak ada repositori yang bisa dihapus!"
      sleep 1.5
      continue
    fi

    _cr "----------------------------------------"
    _p "Pilih nomor repo yang ingin dibuang dari daftar"
    read -r hapus_num

    if [[ "$hapus_num" =~ ^[0-9]+$ ]] && [ "$hapus_num" -ge 1 ] && [ "$hapus_num" -le "${#valid_repos[@]}" ]; then
      idx_hapus=$((hapus_num - 1))
      repo_terhapus="${valid_repos[$idx_hapus]}"
      repo_name_only="${repo_terhapus#*/}"
      target_folder_fisik="${PWD}/${repo_name_only}"

      _pd "Anda yakin ingin menghapus '${repo_terhapus}' dari daftar ${repo_file}?"
      read -r konfirmasi_hapus

      if [[ "$konfirmasi_hapus" =~ ^[yY]$ ]]; then
        # Hapus dari array
        valid_repos=("${valid_repos[@]:0:idx_hapus}" "${valid_repos[@]:idx_hapus+1}")
        fungsi_export_repo
        _o "'${repo_terhapus}' telah dihapus dari daftar ${repo_file}."

        # SISTEM PURGE FOLDER FISIK LOKAL
        if [ -d "$target_folder_fisik" ]; then
          log_critical "Folder lokal fisik terdeteksi di:"
          log_detail "$target_folder_fisik"
          _pd "HAPUS PERMANEN folder fisik tersebut beserta seluruh representasi filenya?"
          read -r konfirmasi_fisik

          if [[ "$konfirmasi_fisik" =~ ^[yY]$ ]]; then
            _ic "Memusnahkan folder fisik lokal: ${repo_name_only}..."
            rm -rf "$target_folder_fisik"
            _o "Folder fisik berhasil dihapus sepenuhnya dari penyimpanan."
          else
            _w "Folder fisik lokal dipertahankan dan tetap aman."
          fi
        fi
      else
        _c "Penghapusan dibatalkan."
      fi
    else
      _e "Pilihan nomor tidak valid!"
    fi
    sleep 1.5
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
    break
  else
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], atau [q]."
    sleep 1.5
  fi
done # end while menu utama

```

---

## 3. Ubah Pemetaan Jalur $rp dan Alur URL Git Clone (Baris ~199 & ~249)
Karena `$r` sekarang murni hanya berisi nama repositorinya saja, variabel `$rp` akan menunjuk tepat ke direktori lokal proyek Anda secara rapi. Namun, alamat *remote target* pada perintah `git clone` harus diubah agar menggunakan variabel `$o` yang telah ter-parsing secara dinamis sebelumnya.

Cari bagian deklarasi `$rp` dan sesuaikan nilainya menjadi seperti ini:

```bash
# Menggunakan direktori aktif saat skrip dijalankan (pwd) + nama repo murni
rp="${PWD}/${r}"

```
Kemudian gulir sedikit ke bawah pada perintah `git clone`, ganti baris kode clone-nya menjadi:

```bash
  _ic "Koneksi terverifikasi. Mengkloning repositori ke ${rp}..."
  # Variabel ${o} dan ${r} sekarang fleksibel mengikuti pemilik aslinya dari berkas rp.txt
  if ! git clone -q --filter=blob:none --no-checkout git@github.com:${o}/${r}.git "$rp"; then
    log_fatal "Gagal melakukan git clone! Periksa koneksi internet atau SSH Key Anda."
    exit 1
  fi # end if clone success

```

<br>

---

<br>





<br>
