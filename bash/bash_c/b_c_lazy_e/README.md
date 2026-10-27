# 


qs: 
saat memilih dimenu sparse ` [2] /bash [ sudah aktif ]` apakah bisa menampilkan seluruh sub folder dan file tanpa harus download file fisiknya misalnya pemetaan itu dilakukan seperti saat menggunakan `mapfile -t targets < <(git -C "$rp" ls-tree --name-only "origin/${current_branch}" 2>/dev/null)`, jadi hanya didownload file fisiknya hanya ketika mau membuka mengunakan micro lewat opsi `[e] edit` apakah bisa ?

---

aa: 
**Ya, hal tersebut sangat bisa dilakukan dan merupakan strategi terbaik (Lazy Loading)** untuk menghemat ruang penyimpanan dan kuota internet di lingkungan Termux.

Untuk mewujudkannya secara penuh, struktur menu sparse-checkout Anda harus diubah dari yang sebelumnya berbasis tingkat folder (cone/top-level) menjadi berbasis berkas virtual rekursif (`ls-tree -r`). Berkas fisik **benar-benar 0 bytes** di memori lokal dan baru di-download secara *on-demand* saat nomor pilihan pada opsi `[e] edit` dieksekusi.

Berikut adalah perubahan logika dan perbaikan kode langsung pada skrip utama Anda agar fitur ini aktif:

## 1. Ubah Pemetaan Struktur Menjadi Rekursif Virtual
Cari baris kode berikut di bagian atas menu sparse Anda (Sekitar baris 420-430):
```bash
# UBAH BARIS KODE INI:
mapfile -t targets < <(git -C "$rp" ls-tree --name-only "origin/${current_branch}" 2>/dev/null)

```
**Ganti dengan kode di bawah ini** agar Git membaca seluruh sub-folder dan berkas secara mendalam (rekursif) tanpa men-download seisi folder:
```bash
# MENJADI SEPERTI INI:
mapfile -t targets < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

```

## 2. Ubah Logika Deteksi Status `[ sudah aktif ]`
Karena berkas tidak di-download di awal, status aktif tidak lagi dibaca dari array aturan `sparse-checkout list`, melainkan langsung diperiksa berdasarkan **kehadiran fisik berkas tersebut di penyimpanan lokal**.

Ubah blok loop cetak menu Anda (Sekitar baris 440-465) menjadi seperti ini:
```bash
    for i in "${!targets[@]}"; do
      item="${targets[$i]}"
      
      # BARU: Cek status keaktifan berdasarkan kehadiran fisik file di lokal
      status_aktif=""
      if [ -f "${rp}/${item}" ]; then
        status_aktif="  ${GREEN}[ sudah aktif ]${NC}"
      fi

      # Cetak nama sub-folder dan berkas secara bersih dan mendalam
      printf " [%d] %s%b\n" $((i+1)) "$item" "$status_aktif"
    done # end for targets

```

## 3. Modifikasi Logika Pilihan Angka (Daftar Tanpa Download)
Ketika pengguna memilih angka di menu utama, sistem **tidak boleh** langsung menjalankan perintah checkout penuh. Pilihan angka ini cukup digunakan sebagai penanda atau pemicu download *on-demand*.

Ubah blok kode `[0-9]*` pada menu seleksi folder (di bagian paling bawah struktur `case`, sekitar baris 660) menjadi seperti ini:
```bash
      [0-9]*)
        if [ -z "$rp" ] || [ -z "$current_branch" ] || [ -z "$pilihan" ]; then
          _e "Argumen proses seleksi folder tidak lengkap!"
          _pp
          exit 1
        fi

        if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
          idx=$((pilihan - 1))
          selected_file="${targets[$idx]}"
          target_file_fisik="${rp}/${selected_file}"

          if [ -f "$target_file_fisik" ]; then
            _pd "Berkas lokal terdeteksi. Apakah ingin MENONAKTIFKAN & HAPUS FISIK berkas ini?"
            read -r konfirmasi_nonaktif
            if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
              # Hapus dari tracking sparse lokal
              git -C "$rp" sparse-checkout set --no-cone '!/*'
              rm -f "$target_file_fisik"
              _o "Berkas fisik '${selected_file}' berhasil dihapus."
            fi
          else
            _ic "Menambahkan '${selected_file}' ke manifest virtual..."
            # Hanya daftarkan polanya tanpa memaksa download satu folder penuh
            git -C "$rp" sparse-checkout add "$selected_file"
            _o "Siap dibuka! Gunakan opsi [e] untuk mengedit berkas ini."
            sleep 1
          fi
        else
          _an "Pilihan tidak valid."
          _pp
        fi
        continue
        ;;

```

## 4. Implementasikan Lazy Checkout di Opsi `[eE]` (Sebelum Micro Terbuka)
Ini adalah bagian terpenting. Pada opsi `[eE]`, ubah alur pembacaan berkas agar langsung membaca seluruh isi repositori secara virtual. Saat pengguna memilih nomor berkas, jalankan perintah **Lazy Checkout** sesaat sebelum aplikasi `micro` dijalankan.

Ubah isi dari case `[eE])` Anda menjadi kode di bawah ini:
```bash
      [eE])
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori tidak valid!"
          _pp
          continue 1
        fi

        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          continue 1
        fi

        log_notify "Memetakan seluruh struktur repositori remote secara virtual..."
        
        # Tarik daftar seluruh berkas secara rekursif langsung dari remote index (0 bytes disk)
        mapfile -t valid_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Repositori kosong atau tidak terhubung ke remote server."
          _pp
          continue 1
        fi

        clear
        _cc "========================================"
        _cc "   DAFTAR FILE VIRTUAL (ON-DEMAND)      "
        _cc "========================================"
        echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
        _cc "========================================"
        for i in "${!valid_files[@]}"; do
          # Beri penanda visual jika file tersebut kebetulan sudah ter-download di lokal
          status_lokal=""
          if [ -f "${rp}/${valid_files[$i]}" ]; then
            status_lokal="  ${CYAN}[ lokal ready ]${NC}"
          fi
          printf " [%d] %s%b\n" $((i+1)) "${valid_files[$i]}" "$status_lokal"
        done
        _cc "----------------------------------------"
        _p "Pilih nomor file yang ingin dibuka dengan micro"
        read -r num_pilihan

        if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
          idx=$((num_pilihan - 1))
          selected_file="${valid_files[$idx]}"
          full_file_path="${rp}/${selected_file}"

          # -----------------------------------------------------------------
          # PROSEDUR LAZY LOADING (DOWNLOAD FILE HANYA KETIKA DI-EDIT)
          # -----------------------------------------------------------------
          if [ ! -f "$full_file_path" ]; then
            _ic "Berkas belum ada di lokal. Mengunduh secara instan dari remote..."
            
            # 1. Daftarkan berkas spesifik ini ke sparse-checkout
            git -C "$rp" sparse-checkout add "$selected_file" >/dev/null 2>&1
            
            # 2. Tarik paksa fisik file ini saja dari database Git (Proses sekejap mata)
            git -C "$rp" checkout "$current_branch" -- "$selected_file" >/dev/null 2>&1
          fi
          # -----------------------------------------------------------------

          _in "Membuka ${selected_file} dengan micro..."
          sleep 0.5
          micro "$full_file_path"
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi
        ;;

```

## Ringkasan Mekanisme Kerja Baru


| Tahapan Aksi | Cara Kerja Sistem Lama | Cara Kerja Sistem Baru (Lazy Loading) | Dampak Kuota / Disk |
| :--- | :--- | :--- | :--- |
| **Membuka Menu Utama** | Mendownload seluruh berkas di dalam folder terpilih sekaligus. | Hanya mengambil daftar teks pohon dari Git database lokal index. | **0 MB Terpakai** |
| **Memilih Menu `[e]`** | Hanya menampilkan berkas yang berada di folder yang sudah aktif di lokal. | Menampilkan seluruh struktur file proyek dari server GitHub secara virtual. | **0 MB Terpakai** |
| **Eksekusi Buka File** | Langsung membuka berkas karena foldernya sudah di-download utuh di awal. | Melakukan *sparse checkout add* khusus untuk berkas tersebut dan men-download-nya secara instan. | **Hanya berkas itu saja yang di-download** |

---

<br>

---

<br>

---

```bash
#!/bin/bash



# =====================================================================
# SISTEM LOGGING & UX TERMINAL KUSTOM (DIAMBIL DARI LIBRARY CONFIG)
# =====================================================================
# Mengunci jalur relatif modul_sh untuk memuat library warna terpusat

# 1. LOG VERBOSE: Memulai fase pemindaian pra-proses
echo -e "\033[0;33m[DEBUG] Menjalankan fungsi peninjauan integritas struktur proyek...\033[0m"
echo -e "\033[0;33m[~] Memindai komponen sistem: memeriksa berkas './modul_sh/utils.sh'...\033[0m"

if [ -f "./modul_sh/utils.sh" ]; then
  # 2. LOG VERBOSE: Memeriksa hak akses berkas (read permission) sebelum dieksekusi
  echo -e "  \033[0;36m-> [Stat] Berkas ditemukan secara fisik.\033[0m"
  if [ -r "./modul_sh/utils.sh" ]; then
    echo -e "  \033[0;36m-> [Stat] Hak akses baca berkas: \033[0;32m[Diizinkan]\033[0m"
  else
    echo -e "  \033[0;31m-> [Stat] Hak akses baca berkas: [DITOLAK/DIBLOKIR]!\033[0m"
    echo -e "\033[0;31m[X] FATAL ERROR: Berkas ada tetapi sistem tidak diizinkan membaca './modul_sh/utils.sh'!\033[0m"
    exit 1
  fi

  # Cetak log sukses jika berkas fisik ditemukan
  echo -e "\033[0;32m[✓] Berkas ditemukan. Memuat fungsi utilitas eksternal...\033[0m"
  # read -r
  source "./modul_sh/utils.sh"

  # 3. LOG VERBOSE: Memverifikasi apakah fungsi-fungsi internal inti sukses terpasang ke lingkungan
  echo -e "\033[0;33m[DEBUG] Melakukan verifikasi pemetaan fungsi alias internal...\033[0m"
  
  fungsi_inti=("_e" "_ic" "_o" "_cc" "_p" "_pp")
  total_aman=0
  
  for fungsi in "${fungsi_inti[@]}"; do
    if declare -f "$fungsi" > /dev/null; then
      echo -e "  \033[0;90m[Fungsi] Link token '${fungsi}()':\033[0m \033[0;32m[Terhubung Terbuka]\033[0m"
      ((total_aman++))
    else
      echo -e "  \033[0;31m[Fungsi] Link token '${fungsi}()': [Mati / Hilang di Utilitas]!\033[0m"
    fi
  done

  # 4. Cetak log penegasan akhir kompilasi berkas
  if [ "$total_aman" -eq "${#fungsi_inti[@]}" ]; then
    #  Cetak log penegasan bahwa fungsi siap digunakan
    echo -e "\033[0;32m[✓] Sukses! Seluruh fungsi di './modul_sh/utils.sh' berhasil di-import.\033[0m"
    # read -r
  else
    echo -e "\033[0;33m[⚠️ PERINGATAN] Modul termuat dengan Parsial. Beberapa fungsi utilitas tidak ditemukan.\033[0m\n"
  fi
else
  # Cetak log fatal berwarna merah jika berkas hilang
  echo -e "\033[0;31m[X] FATAL ERROR: Berkas './modul_sh/utils.sh' tidak ditemukan secara fisik!\033[0m"
  echo -e "\033[0;31m[X] Silakan periksa kembali struktur folder atau jalankan skrip dari direktori root proyek.\033[0m"
  exit 1
fi
# =====================================================================



# =====================================================================
# AMAN & DINAMIS: MEMBACA DAN MEMILIH REPOSITORI DARI FILE EKSTERNAL
# =====================================================================
repo_file="rp.txt" # Mengubah nama file target sesuai kebutuhan baru

# 1. LOG VERBOSE: Memulai fase audit ketersediaan file database eksternal
echo -e "\033[0;33m[DEBUG] Memulai pemeriksaan kesehatan basis data proyek...\033[0m"
echo -e "\033[0;33m[~] Mendeteksi keberadaan berkas target: './${repo_file}'...\033[0m"
# Pengaman awal: Membuat file rp.txt jika belum ada
if [ ! -f "$repo_file" ]; then
  # 2. LOG VERBOSE: Memberi peringatan visual bahwa file database kosong/hilang
  echo -e "  \033[0;31m-> [Stat] Hasil Pemindaian: Berkas '${repo_file}' NEGATIF (Tidak Ditemukan)!\033[0m"
  
  if declare -f "_e" > /dev/null; then
    _e "File eksternal '${repo_file}' tidak ditemukan!"
    _ic "Membuat file '${repo_file}' dengan struktur default otomatis..."
  else
    echo -e "\033[0;31m[X] File eksternal '${repo_file}' tidak ditemukan!\033[0m"
    echo -e "\033[0;33m[~] Membuat file '${repo_file}' dengan struktur default otomatis...\033[0m"
  fi
  
  # 3. LOG VERBOSE: Proses I/O penulisan template data berundak (EOF Stream)
  echo -e "  \033[0;36m-> [I/O] Menyuntikkan template repositori terstruktur ke '${repo_file}'...\033[0m"
  
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
  
  # 4. LOG VERBOSE: Melakukan audit ukuran file pasca-pembuatan untuk memastikan integritas data
  if [ -s "$repo_file" ]; then
    ukuran_berkas=$(wc -c < "$repo_file" | tr -d '[:space:]')
    echo -e "  \033[0;36m-> [Verify] Ukuran berkas tertulis:\033[0m ${ukuran_berkas} bytes."
    echo -e "\033[0;32m[✓ VERBOSE] Sukses! Berkas '${repo_file}' berhasil dibuat, divalidasi, dan dikunci.\033[0m\n"
    # read -r
  else
    echo -e "\033[0;31m  -> [Verify] Error: Berkas '${repo_file}' berhasil dibuat tetapi berukuran 0 bytes (Kosong)!\033[0m"
    echo -e "\033[0;31m[X] FATAL: Gagal melakukan sinkronisasi data fisik ke piringan disk.\033[0m\n"
    exit 1
  fi
else
  # 5. LOG VERBOSE: Jika berkas sudah ada sebelumnya, tampilkan info bypass aman
  ukuran_berkas=$(wc -c < "$repo_file" | tr -d '[:space:]')
  echo -e "  \033[0;32m-> [Stat] Hasil Pemindaian: Berkas '${repo_file}' POSITIF (\033[1;32mAman Terverifikasi\033[0;32m).\033[0m"
  echo -e "  \033[0;36m-> [Verify] Ukuran basis data aktif saat ini:\033[0m ${ukuran_berkas} bytes."
  echo -e "\033[0;32m[✓ VERBOSE] Prosedur bypass aktif. Mempersiapkan pemuatan data ke memori...\033[0m\n"
  # read -r
fi # end if [ ! -f "$repo_file" ]


# LOG PROSES PARSING: Membaca struktur berundak secara interaktif
echo -e "\033[0;33m[~] Memulai proses parsing struktur internal '${repo_file}'...\033[0m"
# =====================================================================
# MENU SELEKSI & MANAJEMEN REPOSITORI UTAMA (BERWARNA & FLEKSIBEL)
# =====================================================================
while true; do # Loop Utama (Tingkat 2 dari dalam)
  # --- PROSES IMPORT: Membaca berkas terstruktur rp.txt ke format fleksibel owner/repo ---
  valid_repos=()
  current_owner=""

  # 1. LOG VERBOSE: Tanda awal siklus pembacaan ulang database (useful jika file rp.txt sering berubah)
  echo -e "\033[0;33m[DEBUG] Memulai siklus pembacaan ulang berkas '${repo_file}'...\033[0m"
  baris_ke=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((baris_ke++))

    # Deteksi dan abaikan baris yang hanya berisi spasi atau kosong
    if [[ -z "${line//[:space:]/}" || -z "${line// }" ]]; then
      # 2. LOG VERBOSE: Beri tahu jika ada baris kosong yang dilewati secara aman
      echo -e "  \033[0;90m[Baris $baris_ke] Lewati baris kosong.\033[0m"
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]+ ]]; then
      repo=$(echo "$line" | xargs);
      if [ -n "$current_owner" ]; then
        gabung_repo="$current_owner/$repo";
        valid_repos+=("$gabung_repo");

        # 3. LOG VERBOSE: Sukses menggabungkan format menjadi owner/repo
        echo -e "  \033[0;36m[Baris $baris_ke] -> Kompilasi:\033[0m ${gabung_repo} \033[0;32m[Sukses Terpeta]\033[0m";
      else
        # Antispasi log jika ada anak repo kaku yang diletakkan sebelum nama owner dideklarasikan
        echo -e "  \033[0;31m[Baris $baris_ke] -> [⚠️ ERROR] Repo '${repo}' tidak memiliki Owner Group!\033[0m";
      fi
    else
      current_owner=$(echo "$line" | xargs)
      # 4. LOG VERBOSE: Menampilkan perpindahan fokus ke grup owner baru
      echo -e "  \033[0;34m[Baris $baris_ke] -> [Membuka Grup] Owner Baru Terkunci:\033[0m ${current_owner}"
    fi
  done < "$repo_file"

  # 5. LOG VERBOSE: Ringkasan hasil muatan memori final dalam siklus ini
  echo -e "\033[0;32m[✓ VERBOSE] Siklus pemetaan selesai. Total \033[1;32m${#valid_repos[@]}\033[0;32m entri aktif dimasukkan ke daftar repositori valid.\033[0m\n"
  # read -r
  # ... sisa menu pilihan repositori utama Anda di bawahnya ...
  # break # (Pastikan break ini disesuaikan dengan kebutuhan alur loop menu Anda)

  # Fungsi pembantu internal untuk meng-export kembali array ke file rp.txt
  fungsi_export_repo() {
    local last_owner=""
    # 1. LOG VERBOSE: Beri tahu bahwa file database siap dikosongkan untuk ditulis ulang
    echo -e "\033[0;33m[DEBUG] Membuka berkas '${repo_file}' untuk penulisan ulang (truncate)...\033[0m"
    > "$repo_file"

    local total_tertulis=0
    local grup_owner_ke=0

    for item in "${valid_repos[@]}"; do
      local owner="${item%%/*}"
      local repo="${item#*/}"

      # Deteksi pergantian owner group
      if [[ "$owner" != "$last_owner" ]]; then
        ((grup_owner_ke++))
        
        # Jika bukan owner pertama, berikan jeda baris kosong di dalam file rp.txt
        if [[ -n "$last_owner" ]]; then
          echo "" >> "$repo_file"
          echo -e "  \033[0;90m[Write] Menyisipkan baris pembatas kosong di atas grup baru.\033[0m"
        fi
        
        # Tulis nama owner ke file
        echo "$owner" >> "$repo_file"
        last_owner="$owner"
        
        # 2. LOG VERBOSE: Informasikan pembuatan kepala grup owner baru di dalam file
        echo -e "  \033[0;34m[Grup #$grup_owner_ke] -> Menulis Owner Kepala:\033[0m ${owner}"
      fi
      # Tulis nama sub-repository dengan undakan spasi bawaan Anda
      echo "    $repo" >> "$repo_file"
      ((total_tertulis++))
      
      # 3. LOG VERBOSE: Informasikan penulisan sub-repo berundak yang sedang berlangsung
      echo -e "    \033[0;36m[Item #$total_tertulis] -> Menyuntikkan Sub-Repo:\033[0m    ${repo}"
    done

    # 4. LOG VERBOSE: Laporan akhir kesuksesan proses I/O fisik ke piringan disk
    echo -e "\033[0;32m[✓ VERBOSE] Ekspor Berhasil! File '${repo_file}' telah diperbarui secara fisik."
    echo -e "            Total: \033[1;32m${grup_owner_ke}\033[0;32m Grup Owner dan \033[1;32m${total_tertulis}\033[0;32m Sub-Repo terkunci aman.\033[0m\n"
  }

  # =====================================================================
  # LOG VERBOSE: Memulai fase audit visual dan inspeksi direktori fisik
  # =====================================================================
  echo -e "\033[0;33m[DEBUG] Memulai inspeksi status lingkungan repositori lokal...\033[0m"
  echo -e "        \033[0;35m-> Basis Folder Utama:\033[0m ${PWD}"
  
  total_entri=${#valid_repos[@]}
  echo -e "        \033[0;36m-> Total data di memori:\033[0m ${total_entri} entri terdaftar."

  if [ $total_entri -eq 0 ]; then
    echo -e "  \033[0;31m[⚠️ WARNING] Array memori kosong. Tidak ada data untuk diinspeksi.\033[0m"
  else
    # Lakukan loop peninjauan latar belakang (Verbose Tracker) sebelum mencetak menu bersih
    for i in "${!valid_repos[@]}"; do
      owner_name="${valid_repos[$i]%%/*}"
      local_repo_name="${valid_repos[$i]#*/}"
      jalur_periksa="${PWD}/${owner_name}/${local_repo_name}/.git"
      
      echo -en "  \033[0;90m[Inspeksi #$((i+1))]\033[0m Memeriksa jalur: ./${owner_name}/${local_repo_name}/.git -> "
      
      if [ -d "$jalur_periksa" ]; then
        echo -e "\033[0;32m[Ditemukan] -> Status: LOKAL AKTIF\033[0m"
      else
        echo -e "\033[0;34m[Tidak Ada] -> Status: HANYA DAFTAR\033[0m"
      fi
    done
  fi
  echo -e "\033[0;32m[✓ VERBOSE] Seluruh status repositori berhasil dipetakan ke memori visual.\033[0m"
  # read -r
  # Berikan sedikit jeda pembacaan debug sebelum layar dibersihkan untuk memuat menu utama asli
  # sleep 1.5

  # =====================================================================
  # TAMPILAN MENU UTAMA ASLI (BERSIH & TERFORMAT)
  # =====================================================================

  clear
  _cc "========================================"
  _cc "       PILIH REPOSITORI UTAMA           "
  _cc "========================================"
  _cc "Daftar Repositori Terpantau (Format: owner/repo):"

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
  # Pengaman awal: Batalkan proses jika parameter krusial tidak lengkap
  if [ -z "$o" ] || [ -z "$rp" ] || [ -z "$owner_privkey" ] || [ -z "$owner_pubkey" ]; then
    _e "Parameter untuk manajemen SSH Key tidak lengkap!"
    _pp
    # exit 1
    continue 1
  fi

  _ic "Mengonfigurasi SSH Key dinamis untuk owner: ${o}..."
  # 3. VERIFIKASI JARRINGAN JIKA KEY BELUM ADA ATAU FOLDER LOKAL BELUM TERSEDIA
  if [ ! -f "$owner_privkey" ] || [ ! -d "$rp" ]; then
    _ic "Memeriksa jaringan untuk verifikasi kredensial dan repositori..."
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
      log_fatal "Anda sedang OFFLINE! Proses ini memerlukan koneksi internet."
      _pp
      # exit 1
      continue 1
    fi
  fi

  # Unduh SSH Key secara otomatis jika belum ada di lokal
  # Jalankan unduhan otomatis jika berkas key belum tersedia di penyimpanan lokal
  if [ ! -f "$owner_privkey" ]; then
    _ic "Mengunduh SSH Key untuk ${o} dari remote repository... atau Mengunduh SSH Key dinamis untuk owner: ${o}..."

    # Amankan hak akses folder .ssh terlebih dahulu
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    # Menggunakan subshell dengan umask ketat untuk file private key
    # Subshell umask ketat khusus untuk berkas Private Key (chmod 600)
    (
      umask 077
      # Mengunduh private key berdasarkan variabel nama owner ($o)
      if curl -fsSL "https://github.com/${o}/eucalypsih_rcrapsbash/raw/main/${o}_rsa_privkey" -o "${owner_privkey}.base64"; then
        base64 -d "${owner_privkey}.base64" > "$owner_privkey"
        sleep 1.5
        rm -f "${owner_privkey}.base64"
      else
        log_fatal "Gagal mengunduh Private Key untuk ${o}!"
        # exit 1
        continue 1
      fi
    )

    # Pastikan jika subshell private key gagal, hentikan skrip
    # [ $? -ne 0 ] && exit 1
    [ $? -ne 0 ] && continue 1
    # Menggunakan umask standar untuk public key
    # Subshell umask standar untuk berkas Public Key (chmod 644)
    (
      umask 022
      # Mengunduh public key berdasarkan variabel nama owner ($o)
      if curl -fsSL "https://github.com/${o}/eucalypsih_rcrapsbash/raw/main/${o}_rsa_pubkey" -o "${owner_pubkey}.base64"; then
        base64 -d "${owner_pubkey}.base64" > "$owner_pubkey"
        sleep 1.5
        rm -f "${owner_pubkey}.base64"
      else
        log_fatal "Gagal mengunduh Public Key untuk ${o}!"
        # exit 1
        continue 1
      fi
    )

    # Pastikan jika subshell public key gagal, hentikan skrip
    # [ $? -ne 0 ] && exit 1
    [ $? -ne 0 ] && continue 1
    _o "Kredensial SSH untuk ${o} berhasil disiapkan."
  fi

  # Validasi akhir apakah file key berhasil dibuat
  # 5. VALIDASI AKHIR KETERSEDIAAN BERKAS KEY
  if [ -f "$owner_privkey" ] && [ -f "$owner_pubkey" ]; then
    _o "SSH Key untuk ${o} berhasil diverifikasi."
    # exit 0
  else
    log_fatal "Kredensial SSH tidak lengkap. Skrip dihentikan."
    _pp
    # exit 1
    continue 1
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
      # exit 1
      continue 1 # Kembali ke atas, tampilkan kembali Menu Utama Pilih Repo
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
      # exit 1
      continue 1 # Kembali ke atas, tampilkan kembali Menu Utama Pilih Repo
    fi # end if clone success
    _o "Kloning berhasil dilakukan."
    sleep 0.5
  fi # end if rp terdeteksi

  # Mengambil daftar sparse saat ini di awal untuk pengecekan inisialisasi
  current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)

  # PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
  if [ -z "$current_sparse" ]; then
    # Pengaman awal: Jika parameter krusial kosong, batalkan demi mencegah gagal tulis konfigurasi
    # if [ ! -z "$rp" ] || [ ! -z "$o" ] || [ ! -z "$owner_pubkey" ] || [ ! -z "$owner_privkey" ]; then
    if [ -z "$rp" ] || [ -z "$o" ] || [ -z "$owner_pubkey" ] || [ -z "$owner_privkey" ]; then
      _e "Parameter untuk inisialisasi identitas Git tidak lengkap!"
      _pp
      # exit 1
      continue 1 # Kembali ke atas, tampilkan kembali Menu Utama Pilih Repo

      # break  # Keluar dari alur inisialisasi saat ini
      # exit 0
    fi

    # 3. EKSEKUSI INISIALISASI AWAL SPARSE-CHECKOUT
    _ic "Menyiapkan inisialisasi awal sparse-checkout..."
      
    # Inisialisasi awal sparse-checkout
    # PERBAIKAN: Mengaktifkan sparse-checkout dan mengizinkan SEMUA file langsung di root direktori
    # Pola "/*" memastikan file di root terunduh lengkap, sedangkan "!/*/" memastikan folder tingkat 1 tidak ikut terunduh sebelum dipilih
    if git -C "$rp" sparse-checkout set --no-cone '!/*'; then
      _o "Sukses mengonfigurasi akses file root direktori."
    else
      _e "Gagal menginisialisasi aturan sparse-checkout!"
      # exit 1   # Langsung keluar dari program/skrip secara total

      continue 1 # Kembali ke atas, tampilkan kembali Menu Utama Pilih Repo
      ## Menggunakan `continue 2` (Rekomendasi jika ingin Mengulang Menu Utama)
      ### Jika kegagalan tersebut terjadi pada satu repositori, namun Anda **tidak ingin skrip mati total** dan ingin memberikan kesempatan kepada pengguna untuk memilih repositori lain di Menu Utama, gunakan `continue 2`.
      ### - Efek: Perintah ini akan melompati sisa kode di bawahnya dan langsung **melompat kembali ke awal siklus `while true` terluar** (Menu Seleksi Repositori Utama).
      ### - Alasan: Angka 2 memberi tahu Bash untuk melakukan continue pada loop tingkat ke-2 (loop terluar).
    fi
    sleep 0.5

    # 4. TERAPKAN KONFIGURASI INTERNAL IDENTITAS GIT LOKAL REPOSITORI
    # =====================================================================
    # KONFIGURASI GIT DINAMIS BERDASARKAN OWNER
    # =====================================================================
    # Jalankan loop konfigurasi lokal repositori secara otomatis
    # SATU BLOK LOOP untuk semua Konfigurasi (cfg) otomatis  
    # Terapkan konfigurasi internal Git secara otomatis
    _ic "Mengunci konfigurasi identitas Git lokal..."

    # Menggunakan tanda pemisah khusus (semicolon ';') untuk memisahkan KEY dan VALUE secara aman
    for item in \
      "user.name;${o}" \
      "user.email;${o}@gmail.com" \
      "gpg.format;ssh" \
      "user.signingkey;${owner_pubkey}" \
      "commit.gpgsign;true" \
      "gpg.ssh.allowedSignersFile;~/.ssh/allowed_signers" \
      "core.sshCommand;ssh -i ${owner_privkey} -o IdentitiesOnly=yes";
    do
      # Memecah parameter menjadi KEY dan VALUE berdasarkan tanda pemisah ';'
      key="${item%%;*}"
      val="${item#*;}"

      # Eksekusi git config dengan membungkus nilai ($val) di dalam kutip double agar aman dari spasi
      git -C "$rp" config "$key" "$val"
      sleep 0.2
    done # end for item
    _o "Konfigurasi Git lokal untuk ${o} berhasil diterapkan."
    sleep 0.5

    # Perbarui variabel setelah inisialisasi pertama selesai
    current_sparse=$(git -C "$rp" sparse-checkout list 2>/dev/null)
    git -C "$rp" checkout "$current_branch"
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
        # exit 1
        continue 1 # Kembali ke atas, tampilkan kembali Menu Utama Pilih Repo
      fi # end if konfirmasi cache
    fi
  fi # end if current_sparse

  # Membaca seluruh isi root (folder & file) tingkat pertama dari remote
  mapfile -t targets < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

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
      # Cek status keaktifan berdasarkan kehadiran fisik file di lokal
      status_aktif=""
      if [ -f "${rp}/${item}" ]; then
        status_aktif="  ${GREEN}[ sudah aktif ]${NC}"
      fi

      # Cetak nama sub-folder dan berkas secara bersih dan mendalam
      printf " [%d] %s%b\n" $((i+1)) "$item" "$status_aktif"
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
        # LOGIKA KELUAR [q] (KOMPARASI LOG & AUTO-PUSH)
        # =====================================================================
        # 3. DETEKSI PERUBAHAN LOKAL (Mengabaikan efek samping berkas sparse-checkout)
        # perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null | grep -E '^([ MAU?][M?][D ]|[^D] )')

        # 1. Ambil semua perubahan mentah dari git status porcelain
        raw_status=$(git -C "$rp" status --porcelain 2>/dev/null)
        perubahan_lokal=""

        # 2. Iterasi baris per baris untuk memisahkan D asli vs efek sparse
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          
          status_code="${line:0:2}"
          file_path="${line:3}"

          # Jika statusnya adalah D (Deleted) baik di staging maupun working tree
          if [[ "$status_code" =~ "D" ]]; then
            # Periksa apakah file tersebut memiliki flag skip-worktree (artinya dikendalikan sparse)
            is_sparse=$(git -C "$rp" ls-files -v "$file_path" 2>/dev/null | grep -E '^[Ssmh]')
            
            if [ -n "$is_sparse" ]; then
              # Jika dia termasuk file sparse, lewati (jangan anggap sebagai hapus lokal manual)
              continue
            fi
          fi

          # Masukkan baris perubahan yang valid (Modified, Untracked, atau Real Deleted)
          if [[ "$status_code" =~ [MAU\?] ]] || [[ "$status_code" =~ "D" ]]; then
            perubahan_lokal+="$line"$'\n'
          fi
        done <<< "$raw_status"

        # JIKA ADA PERUBAHAN YANG BENAR-BENAR VALID
        # JIKA ADA PERUBAHAN YANG BELUM DI-COMMIT
        if [ -n "$perubahan_lokal" ]; then
          _w "Ada file yang telah Anda ubah/tambahkan secara lokal!"
          echo "$perubahan_lokal"
          echo "----------------------------------------"
          echo "Pilih tindakan Anda:"
          echo -e " [1] ${GREEN}Simpan perubahan (Commit secara lokal)${NC}"
          echo -e " [2] ${RED}Abaikan & Paksa update (Buang hasil editan Anda)${NC}"
          echo -e " [3] ${YELLOW}Abaikan & Batalkan Keluar (Kembali ke menu)${NC}"
          _cc "----------------------------------------"
          _p "Pilihan Anda (1/2/3)"
          read -r aksi_keluar

          if [ "$aksi_keluar" == "1" ]; then
            # LAPIS PENGAMAN KRITIS MENCEGAH HUMAN ERROR
            log_critical "Tindakan ini akan merekam perubahan (termasuk penghapusan) ke Git!"
            _p "Ketik 'EXPLICIT' (huruf besar) untuk melanjutkan konfirmasi"
            read -r verifikasi_aman

            if [ "$verifikasi_aman" != "EXPLICIT" ]; then
              _an "Verifikasi gagal! Tindakan dibatalkan demi keamanan repositori Anda."
              sleep 2
              # exit 0 # Menghentikan modul eksternal dan kembali aman ke menu interaktif utama
              continue # Kembali ke menu seleksi folder sparse, tidak jadi keluar
            fi


            # Generator Auto-Increment Pesan Commit Otomatis
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              next_num=$((last_num + 1))
              auto_msg="u${next_num}"
            else
              auto_msg="u1"
            fi # end if last_num

            echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk auto-msg, atau ketik pesan manual"
            read -r pesan_commit
            [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"

            # Menggunakan parameter --sparse agar Git mengizinkan perekaman file baru di luar daftar sparse aktif
            # git -C "$rp" add .
            git -C "$rp" add --sparse .
            git -C "$rp" commit -m "$pesan_commit"
            _o "Perubahan berhasil disimpan ke commit lokal!"

          elif [ "$aksi_keluar" == "2" ]; then
            _w "Membuang perubahan lokal dan melakukan paksa checkout..."
            git -C "$rp" checkout -f "$current_branch" 2>/dev/null
          else
            _r "Membatalkan proses keluar. Kembali ke menu utama..."
            sleep 1
            continue
            # exit 0 # Kembali ke menu interaktif tanpa mengubah apa pun
          fi # end if aksi_keluar pilihan
        else
          # Jika tidak ada uncommitted changes, langsung jalankan checkout sparse
          git -C "$rp" checkout "$current_branch" 2>/dev/null
        fi # end if perubahan_lokal

        # 4. KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE REPOSITORY
        _nc "========================================"
        _cc "       PERBANDINGAN STATUS COMMIT       "
        _cc "========================================"

        # Mengambil hash dan subjek commit terakhir dari lokal dan remote
        local_log=$(git -C "$rp" log -1 --format="%h - %s" "$current_branch" 2>/dev/null)
        remote_log=$(git -C "$rp" log -1 --format="%h - %s" "origin/${current_branch}" 2>/dev/null)

        echo -e "[Local]  : ${YELLOW}${local_log:-'Belum ada commit'}${NC}"
        echo -e "[Remote] : ${GREEN}${remote_log:-'Belum ada commit'}${NC}"
        _cc "----------------------------------------"

        # 5. EVALUASI DAN EKSEKUSI AUTO-PUSH SINKRONISASI
        # Cek apakah lokal berada di depan remote (butuh push)
        ahead_commits=$(git -C "$rp" rev-list --count "origin/${current_branch}..${current_branch}" 2>/dev/null)

        if [ "${ahead_commits:-0}" -gt 0 ]; then
          _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
          _p "Apakah Anda yakin ingin melakukan PUSH ke GitHub sekarang? (y/n)"
          read -r konfirmasi_push

          if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
            _ic "Melakukan git push origin ${current_branch}..."
            if git -C "$rp" push origin "${current_branch}"; then
              _o "Push berhasil! Repositori GitHub telah diperbarui."
            else
              _a "Gagal melakukan push! Periksa koneksi atau kredensial SSH Anda."
            fi # end if push success
          else
            _r "Push dibatalkan. Perubahan Anda tetap tersimpan di lokal."
          fi # end if konfirmasi_push
        else
          _o "Status: Sinkron! Log Local sama dengan Remote."
        fi # end if ahead_commits

        _on "Selesai dengan sukses! Keluar dari skrip."
        # Memutus seluruh rantai aplikasi secara bersih ke terminal karena pengguna memilih opsi Keluar
        # break
        # exit 0
        # continue
        # Membunuh Process ID (PID) dari skrip utama saat ini secara paksa namun aman
        # kill $$

        # Keluar dari 2 tingkat loop (While Menu Sparse DAN While Menu Utama)
        break 2
        ## Menggunakan `break 2` (Jika ingin keluar lewat jalur Loop)
        #### Alasan mengapa `break` biasa tidak bisa keluar dari program adalah karena break hanya memutus struktur case atau loop while terdalam (menu sparse). Skrip Anda memiliki struktur **Loop Terluar (Menu Utama)** dan **Loop Terdalam (Menu Sparse)**.
        #### Agar bisa menembus keluar dari kedua loop sekaligus, Anda harus menggunakan `break 2`.
        ;;


      [dD])
        # =====================================================================
        # FITUR BARU: HAPUS FILE ATAU SUB-DIREKTORI (DENGAN OTOMATISASI GIT RM)
        # =====================================================================

        # Pengaman awal: Jika argumen kosong, hentikan proses demi keamanan Git
        if [ -z "$rp" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue
        fi

        active_folders=()
        for folder in "${targets[@]}"; do
          if echo "$current_sparse" | grep -qE "^/?${folder}/?$"; then
            active_folders+=("$folder")
          fi
        done

        # 4. VALIDASI AWAL REPO AKTIF
        if [ ${#active_folders[@]} -eq 0 ]; then
          _hn "Belum ada folder aktif. Silakan add folder terlebih dahulu."
          _pp
        else
          log_notify "Memetakan seluruh file dan folder lokal..."
          
          # Mengambil semua file dan direktori di dalam folder aktif lokal (kecuali .git)
          all_local_items=()
          if [ -d "$rp" ]; then
            while IFS= read -r item; do
              [ -z "$item" ] && continue
              for active_dir in "${active_folders[@]}"; do
                if [[ "$item" == "$active_dir"/* || "$item" == "$active_dir" ]]; then
                  all_local_items+=("$item")
                  break
                fi
              done
            done < <(find "$rp" -mindepth 1 ! -path '*/.*' 2>/dev/null | sed "s|^${rp}/||" | sort)
          fi

          # 5. TAMPILKAN SUB-MENU DAFTAR FILE/FOLDER YANG BISA DIHAPUS
          if [ ${#all_local_items[@]} -eq 0 ]; then
            _rn "Tidak ada file atau sub-folder lokal yang dapat dihapus."
            _pp
          else
            clear
            _cc "========================================"
            _cc "     HAPUS FILE / SUB-DIREKTORI         "
            _cc "========================================"
            echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
            _cc "========================================"
            for i in "${!all_local_items[@]}"; do
              item_path="${all_local_items[$i]}"
              if [ -d "${rp}/${item_path}" ]; then
                printf " [%d] %s/ %b[ Folder ]%b\n" $((i+1)) "$item_path" "${YELLOW}" "${NC}"
              else
                printf " [%d] %s %b[ File ]%b\n" $((i+1)) "$item_path" "${GREEN}" "${NC}"
              fi
            done
            _cc "----------------------------------------"
            _p "Pilih nomor target yang ingin dihapus"
            read -r hapus_idx_num

            if [[ "$hapus_idx_num" =~ ^[0-9]+$ ]] && [ "$hapus_idx_num" -ge 1 ] && [ "$hapus_idx_num" -le "${#all_local_items[@]}" ]; then
              idx=$((hapus_idx_num - 1))
              target_hapus="${all_local_items[$idx]}"
              full_target_path="${rp}/${target_hapus}"

              _pd "Apakah Anda yakin ingin menghapus '${target_hapus}' dari Git & Penyimpanan?"
              read -r konfirmasi_item_hapus

              if [[ "$konfirmasi_item_hapus" =~ ^[yY]$ ]]; then
                _ic "Menghapus target menggunakan git rm..."

                # Logika Git RM: Cek apakah file sudah pernah di-track oleh git sebelumnya
                if git -C "$rp" ls-files --error-unmatch "$target_hapus" &>/dev/null; then
                  # Jika sudah di-track, gunakan git rm secara rekursif untuk folder/file
                  git -C "$rp" rm -rf "$target_hapus"
                  _o "'${target_hapus}' dihapus dan dicatat di staging area Git."
                else
                  # Jika file baru (untracked) dan belum di-commit, hapus secara fisik langsung
                  rm -rf "$full_target_path"
                  _o "Berkas untracked '${target_hapus}' telah dihapus fisik."
                fi
                sleep 1.5
              else
                _c "Penghapusan dibatalkan."
                sleep 1
              fi
            else
              _an "Pilihan tidak valid."
              sleep 1
            fi
          fi
        fi
        ;;


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
        # Pengaman awal: Jika argumen kosong, hentikan proses demi keamanan Git
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue 1
        fi

        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          # exit 1
          continue 1
        fi # end if micro check

        log_notify "Memetakan seluruh struktur repositori remote secara virtual..."

        # Tarik daftar file dari REMOTE (GitHub)
        # Tarik daftar seluruh berkas secara rekursif langsung dari remote index (0 bytes disk)
        mapfile -t remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null)

        if [ ${#remote_files[@]} -eq 0 ]; then
          _rn "Repositori kosong atau tidak terhubung ke remote server."
          _pp
          continue 1
        fi

        # Tampilkan sub-menu seluruh file yang tersedia untuk diedit

        clear
        _cc "========================================"
        _cc "   DAFTAR FILE VIRTUAL (ON-DEMAND)      "
        _cc "========================================"
        echo -e "Repositori: ${YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
        _cc "========================================"
        for i in "${!remote_files[@]}"; do
          # Beri penanda visual jika file tersebut kebetulan sudah ter-download di lokal
          status_lokal=""
          if [ -f "${rp}/${remote_files[$i]}" ]; then
            status_lokal="  ${CYAN}[ lokal ready ]${NC}"
          fi
          printf " [%d] %s%b\n" $((i+1)) "${remote_files[$i]}" "$status_lokal"
        done
        _cc "----------------------------------------"
        _p "Pilih nomor file yang ingin dibuka dengan micro"
        read -r num_pilihan

        if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#remote_files[@]}" ]; then
          idx=$((num_pilihan - 1))
          selected_file="${remote_files[$idx]}"
          full_file_path="${rp}/${selected_file}"

          ## Jaga-jaga buat folder induk lokal fisik jika membuka file remote yang belum ter-checkout lokal
          # parent_dir=$(dirname "$full_file_path")
          # mkdir -p "$parent_dir"
          # touch "$full_file_path"

# -----------------------------------------------------------------
          # PROSEDUR LAZY LOADING (DOWNLOAD FILE HANYA KETIKA DI-EDIT)
          # -----------------------------------------------------------------
          if [ ! -f "$full_file_path" ]; then
            _ic "Berkas belum ada di lokal. Mengunduh secara instan dari remote..."
            
            # 1. Daftarkan berkas spesifik ini ke sparse-checkout
            git -C "$rp" sparse-checkout add "$selected_file" >/dev/null 2>&1
            
            # 2. Tarik paksa fisik file ini saja dari database Git (Proses sekejap mata)
            git -C "$rp" checkout "$current_branch" -- "$selected_file" >/dev/null 2>&1
          fi
          # -----------------------------------------------------------------

          _in "Membuka ${selected_file} dengan micro..."
          sleep 0.5
          micro "$full_file_path"
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi # end if num_pilihan valid
        ;;

      [0-9]*)
        # Pengaman awal: Jika argumen penting kosong, gagalkan proses demi keamanan Git
        if [ -z "$rp" ] || [ -z "$current_branch" ] || [ -z "$pilihan" ]; then
          _e "Argumen proses seleksi folder tidak lengkap!"
          _pp
          continue 1
        fi

        # 3. JALANKAN LOGIKA PROSES SELEKSI FOLDER BERDASARKAN ANGKA INPUT
        if [[ "$pilihan" =~ ^[0-9]+$ ]] && [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#targets[@]}" ]; then
          idx=$((pilihan - 1))
          selected_file="${targets[$idx]}"
          target_file_fisik="${rp}/${selected_file}"

          if [ -f "$target_file_fisik" ]; then
            _pd "Berkas lokal terdeteksi. Apakah ingin MENONAKTIFKAN & HAPUS FISIK berkas ini?"
            read -r konfirmasi_nonaktif
            if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
              # Hapus dari tracking sparse lokal
              git -C "$rp" sparse-checkout set --no-cone '!/*'
              rm -f "$target_file_fisik"
              _o "Berkas fisik '${selected_file}' berhasil dihapus."
            fi
          else
            _ic "Menambahkan '${selected_file}' ke manifest virtual..."
            # Hanya daftarkan polanya tanpa memaksa download satu folder penuh
            git -C "$rp" sparse-checkout add "$selected_file"
            _o "Siap dibuka! Gunakan opsi [e] untuk mengedit berkas ini."
            sleep 1
          fi
        else
          _an "Pilihan tidak valid."
          _pp
        fi
        # me-refresh dan memperbarui status visual [ sudah aktif ] secara real-time.
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


<br>
