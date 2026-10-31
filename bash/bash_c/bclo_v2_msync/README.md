# 

qa: 
Prosedur optimasi memori lokal ini sudah **selesai dan tuntas sepenuhnya**. Jika di kemudian hari Anda ingin mengembangkan fitur baru seperti **otomatisasi backup branch** atau **multi-remote sync**, silakan panggil saya kembali. Selamat berkarya dengan skrip barunya!

---

qc: 
mengembangkan fitur baru seperti **multi-remote sync**

---

aa: 
`<!-- User Intent: Context: Git multi-remote sync automation | Constraints: Bahasa Indonesia, Tampilan UX Asli, Modular, Aman | Intent: Mengembangkan fitur sinkronisasi ke beberapa remote upstream sekaligus -->`Mengembangkan fitur **Multi-Remote Sync** pada skrip Anda sangat **berguna agar proyek yang Anda kelola di Termux dapat dicadangkan (backup) atau disinkronkan ke beberapa target remote sekaligus** (misalnya: akun GitHub cadangan, GitLab, Codeberg, atau server VPS pribadi) hanya dengan satu kali klik.

Untuk menjaga kerapian arsitektur skrip utama (`main.sh`), kita akan merancang fitur ini secara **modular**. Skrip utama hanya perlu mendaftarkan opsi menu baru, sedangkan seluruh logika biner Git akan dilempar ke berkas utilitas eksternal baru bernama `./modul_sh/sync.sh`.

---

## Langkah 1: Modifikasi Skrip Utama `main.sh`
Buka berkas `main.sh` Anda, lalu lakukan dua perubahan kecil berikut untuk menaruh tombol menu baru:

### A. Tambahkan Baris Opsi pada Tampilan Menu Visual Sparse
Cari baris cetak menu interaktif (sekitar baris yang menampilkan opsi `[b] Kembali...`), lalu sisipkan opsi `[m]` di atasnya:
```bash
    echo -e " [e] ${GREEN}Edit File (Jelajahi Folder Aktif)${NC}"
    echo -e " [n] ${GREEN}Buat File Baru di Folder Aktif${NC}"
    echo -e " [d] ${RED}Hapus File atau Sub-Folder (Git RM)${NC}"
    echo -e " [m] ${CYAN}Multi-Remote Sync (Sinkronisasi Massal)${NC}"  # <-- SISIPKAN BARIS BARU INI
    echo -e " [q] ${RED}Keluar & Terapkan Perubahan (Checkout)${NC}"
    echo -e " [b] ${YELLOW}Kembali ke Menu Pilih Repositori Utama${NC}"

```

### B. Sisipkan Handler Kasus `[mM]` pada `case "$pilihan" in`
Cari blok `case "$pilihan" in` di dalam skrip Anda, lalu posisikan kode pengarah eksternal ini di atas atau di bawah opsi `[nN])`:
```bash
      [mM])
        # =====================================================================
        # MEMANGGIL MODUL EKSTERNAL SINKRONISASI MULTI-REMOTE
        # =====================================================================
        if [ -f "./modul_sh/sync.sh" ]; then
          # Melempar parameter: jalur_repo (1), nama_owner (2), branch_aktif (3), ssh_privkey (4)
          bash ./modul_sh/sync.sh "$rp" "$o" "$current_branch" "$owner_privkey"
        else
          _e "File './modul_sh/sync.sh' tidak ditemukan secara fisik!"
          _pp
        fi
        continue
        ;;

```

---

## Langkah 2: Buat Berkas Modul Baru `./modul_sh/sync.sh`
Buat sebuah berkas baru di dalam folder modul Anda dengan nama `sync.sh` (`micro ./modul_sh/sync.sh`). Suntikkan arsitektur kode di bawah ini seutuhnya:
```bash
#!/bin/bash

# Tangkap parameter limpahan dari skrip utama
rp="$1"
o="$2"
current_branch="$3"
owner_privkey="$4"

# Pengaman Parameter Krusial
if [ -z "$rp" ] || [ -z "$o" ] || [ -z "$current_branch" ] || [ -z "$owner_privkey" ]; then
  echo -e "\033[0;31m[X] Error: Parameter limpahan Multi-Remote Sync tidak lengkap!\033[0m"
  exit 1
fi

clear
echo -e "\033[0;36m========================================\033[0m"
echo -e "\033[1;36m       SISTEM MULTI-REMOTE SYNC         \033[0m"
echo -e "\033[0;36m========================================\033[0m"
echo -e "Lokasi Proyek : \033[0;33m${rp}\033[0m"
echo -e "Branch Aktif  : \033[0;32m${current_branch}\033[0m"
echo -e "SSH PrivKey   : \033[0;90m${owner_privkey}\033[0m"
echo -e "\033[0;36m----------------------------------------\033[0m"

# 1. DETEKSI DAFTAR REMOTE YANG TERSEDIA SAAT INI
echo -e "\033[0;33m[~] Memindai repositori biner Git...\033[0m"
mapfile -t existing_remotes < <(git -C "$rp" remote 2>/dev/null)

echo -e "Daftar Remote Terdaftar:"
for rmt in "${existing_remotes[@]}"; do
  url=$(git -C "$rp" remote get-url "$rmt" 2>/dev/null)
  echo -e "  -> \033[0;32m%-10s\033[0m : \033[0;90m%s\033[0m" "$rmt" "$url"
done
echo -e "\033[0;36m----------------------------------------\033[0m"

# 2. MENU PILIHAN AKSI SINKRONISASI
echo -e "Pilih tindakan Multi-Remote:"
echo -e " [1] \033[0;32mPush massal ke SEMUA Remote sekaligus\033[0m"
echo -e " [2] \033[0;36mDaftarkan Remote Target Baru (Backup)\033[0m"
echo -e " [3] \033[0;31mHapus Remote Target dari Daftar\033[0m"
echo -e " [q] Kembali ke Menu Sebelumnya"
echo -e "\033[0;36m========================================\033[0m"
echo -n "[~] Masukkan pilihan Anda: "
read -r aksi_sync

case "$aksi_sync" in
  1)
    if [ ${#existing_remotes[@]} -eq 0 ]; then
      echo -e "\033[0;31m[!] Gagal: Tidak ada remote yang terdaftar di repositori ini.\033[0m"
      sleep 2
      exit 0
    fi

    # Cek jaringan internet sebelum push massal
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
      echo -e "\033[0;31m[X] Error: Anda sedang OFFLINE! Push massal memerlukan internet.\033[0m"
      read -r
      exit 0
    fi

    echo -e "\n\033[0;33m[~] Memulai proses unggah data berundak...\033[0m"
    for rmt in "${existing_remotes[@]}"; do
      echo -e "\n\033[0;35m[Sync -> $rmt]\033[0m Mengirim branch \033[0;32m$current_branch\033[0m..."
      
      # Eksekusi push menggunakan SSH Key yang terisolasi aman
      if git -C "$rp" push \
        -c "core.sshCommand=ssh -i ${owner_privkey} -o IdentitiesOnly=yes" \
        "$rmt" "$current_branch"; then
        echo -e "\033[0;32m[✓ Sync -> $rmt] Sukses terbarui!\033[0m"
      else
        echo -e "\033[0;31m[X Sync -> $rmt] Gagal kirim! Periksa hak akses remote target.\033[0m"
      fi
    done
    echo -e "\n\033[0;32m[✓] Siklus Multi-Push Selesai.\033[0m"
    read -r
    ;;

  2)
    echo -e "\n\033[0;36m----------------------------------------\033[0m"
    echo -n "[~] Masukkan NAMA ALIAS remote baru (Contoh: backup, gitlab): "
    read -r alias_baru
    alias_bersih=$(echo "$alias_baru" | tr -d '[:space:]')

    if [ -z "$alias_bersih" ]; then
      echo -e "\033[0;31m[X] Nama alias tidak boleh kosong!\033[0m"
      sleep 1.5
      exit 0
    fi

    # Cegah penimpaan nama remote origin utama
    if [ "$alias_bersih" == "origin" ]; then
      echo -e "\033[0;31m[X] Prosedur Ditolak: Nama 'origin' dikunci untuk server utama!\033[0m"
      sleep 2
      exit 0
    fi

    echo -n "[~] Masukkan SSH URL Remote Target: "
    read -r url_baru
    url_bersih=$(echo "$url_baru" | tr -d '[:space:]')

    if [ -z "$url_bersih" ]; then
      echo -e "\033[0;31m[X] URL Target tidak boleh kosong!\033[0m"
      sleep 1.5
      exit 0
    fi

    # Daftarkan remote baru ke konfigurasi lokal biner Git
    if git -C "$rp" remote add "$alias_bersih" "$url_bersih"; then
      echo -e "\033[0;32m[✓] Sukses mendaftarkan target cadangan [$alias_bersih]!\033[0m"
    else
      echo -e "\033[0;31m[X] Gagal mendaftarkan remote. Kemungkinan nama alias sudah dipakai.\033[0m"
    fi
    sleep 2
    ;;

  3)
    echo -e "\n\033[0;36m----------------------------------------\033[0m"
    echo -n "[~] Masukkan nama alias remote yang mau DIHAPUS: "
    read -r alias_hapus
    alias_hapus_bersih=$(echo "$alias_hapus" | tr -d '[:space:]')

    if [ "$alias_hapus_bersih" == "origin" ]; then
      echo -e "\033[0;31m[X] Bahaya: Remote 'origin' utama tidak boleh dihapus dari skrip ini!\033[0m"
      sleep 2
      exit 0
    fi

    if git -C "$rp" remote remove "$alias_hapus_bersih" 2>/dev/null; then
      echo -e "\033[0;32m[✓] Remote target [$alias_hapus_bersih] berhasil dicabut dari pelacakan.\033[0m"
    else
      echo -e "\033[0;31m[X] Gagal: Nama alias remote tidak ditemukan dalam basis data Git.\033[0m"
    fi
    sleep 2
    ;;

  *)
    exit 0
    ;;
esac

```

Jangan lupa untuk memberikan izin eksekusi pada modul baru tersebut melalui terminal Termux Anda:
```bash
chmod +x ./modul_sh/sync.sh

```

---

## Cara Kerja Arsitektur Multi-Remote Sync Baru Anda
1. Isolasi Identitas SSH Aman: Saat Anda memilih Opsi `1`, skrip akan mengekstrak variabel `$owner_privkey` milik owner repositori aktif tersebut (`id_rsa_eucalypsih`) untuk melakukan push secara paralel menggunakan opsi `IdentitiesOnly=yes`. Ini memastikan Anda tidak akan terkena error *Permission Denied* dari server GitHub/GitLab tujuan.
2. Fleksibilitas Tambah/Hapus Target: Anda bisa menambahkan remote baru sebanyak mungkin (misal: `gitlab`, `vps`, `backup_github`) langsung dari menu interaktif skrip tanpa perlu mengedit file teks `.git/config` secara manual.

---

qa: 
Silakan pasang kode modul `sync.sh` baru tersebut. Apakah menu interaktif penambahan dan pemindaian status URL remote target-nya sudah berhasil tercetak dengan rapi di layar terminal Anda?





















<br>
