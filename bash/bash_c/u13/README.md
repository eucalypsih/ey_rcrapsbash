

qc: 
menambahkan opsi **[t]` Tambah Repo Baru** langsung dari dalam menu terminal agar Anda bisa memasukkan nama repositori baru ke dalam file `repo.txt` tanpa harus membuka file teksnya secara manual

aa: 
Berikut adalah pembaruan untuk bagian **Menu Seleksi Repositori Utama** yang telah ditambahkan fitur opsi **[t] Tambah Repo Baru**.

Jika Anda memilih opsi `[t]`, skrip akan meminta Anda memasukkan nama repositori baru, secara otomatis menyimpannya ke dalam file `repo.txt`, lalu langsung memperbarui daftar menu tanpa perlu keluar dari skrip.

```bash
o="eucalypsih"
repo_file="repo.txt"

# Kode warna lokal untuk inisialisasi awal menu
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color (Reset)

# Pengaman awal: Membuat file repo.txt jika belum ada
if [ ! -f "$repo_file" ]; then
    echo -e "${YELLOW}[+] File konfigurasi '${repo_file}' tidak ditemukan.${NC}"
    echo -e "${CYAN}[~] Membuat file '${repo_file}' default otomatis...${NC}"
    echo -e "ey_rcrapsbash\ney_repo2\ney_repo3\ney_repo4" > "$repo_file"
    sleep 1
fi

# =====================================================================
# MENU SELEKSI & MANAJEMEN REPOSITORI UTAMA (BERWARNA)
# =====================================================================
while true; do
    # Membaca daftar repo dari file ke dalam array secara dinamis setiap kali menu diulang
    mapfile -t daftar_repo < "$repo_file"

    # Menyaring elemen array dari baris kosong
    valid_repos=()
    for repo in "${daftar_repo[@]}"; do
        [ -n "$repo" ] && valid_repos+=("$repo")
    done

    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}       PILIH REPOSITORI UTAMA           ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}Daftar Repositori di GitHub (${o}):${NC}"
    
    if [ ${#valid_repos[@]} -eq 0 ]; then
        echo -e " ${RED}[!] Kosong: Belum ada repositori terdaftar${NC}"
    else
        for i in "${!valid_repos[@]}"; do
            # Cek apakah folder repo lokal fisik sudah ada/pernah di-clone sebelumnya
            if [ -d "${PWD}/${valid_repos[$i]}/.git" ]; then
                printf " [%d] %-20s %b[ lokal aktif ]%b\n" $((i+1)) "${valid_repos[$i]}" "${GREEN}" "${NC}"
            else
                printf " [%d] %-20s\n" $((i+1)) "${valid_repos[$i]}"
            fi
        done
    fi
    
    echo -e "${CYAN}----------------------------------------${NC}"
    echo -e " [t] ${YELLOW}Tambah Repositori Baru${NC}"
    echo -e " [q] ${RED}Keluar dari Skrip${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -n "Masukkan pilihan Anda: "
    read -r repo_pilihan

    # OPSI KELUAR
    if [[ "$repo_pilihan" =~ ^[qQ]$ ]]; then
        echo -e "\n${RED}[+] Proses dibatalkan. Keluar dari skrip.${NC}"
        exit 0
    fi

    # OPSI TAMBAH REPO BARU
    if [[ "$repo_pilihan" =~ ^[tT]$ ]]; then
        echo -e "${CYAN}----------------------------------------${NC}"
        echo -e -n "${YELLOW}[+] Masukkan nama repositori baru (tanpa .git): ${NC}"
        read -r repo_baru
        
        # Validasi agar input tidak kosong dan tidak mengandung spasi liar
        repo_bersih=$(echo "$repo_baru" | tr -d '[:space:]')
        
        if [ -z "$repo_bersih" ]; then
            echo -e "${RED}[X] Error: Nama repositori tidak boleh kosong!${NC}"
            sleep 1.5
        else
            # Cek apakah repo sudah ada di dalam daftar untuk mencegah duplikasi
            if [[ " ${valid_repos[*]} " =~ " ${repo_bersih} " ]]; then
                echo -e "${YELLOW}[!] Peringatan: Repositori '${repo_bersih}' sudah ada dalam daftar.${NC}"
            else
                # Memasukkan nama repo baru ke baris paling bawah file repo.txt
                echo "$repo_bersih" >> "$repo_file"
                echo -e "${GREEN}[✓] Sukses: '${repo_bersih}' berhasil ditambahkan ke ${repo_file}.${NC}"
            fi
            sleep 1.5
        fi
        continue # Ulangi loop menu untuk memuat ulang daftar repo terbaru
    fi

    # PROSES SELEKSI REPOSITORI BERDASARKAN ANGKA
    if [[ "$repo_pilihan" =~ ^[0-9]+$ ]] && [ "$repo_pilihan" -ge 1 ] && [ "$repo_pilihan" -le "${#valid_repos[@]}" ]; then
        idx=$((repo_pilihan - 1))
        r="${valid_repos[$idx]}"
        
        echo -e "\n${GREEN}[✓] Repositori dipilih: ${YELLOW}${r}${NC}"
        echo -e "${CYAN}[~] Mengunci jalur kerja lokal proyek...${NC}"
        sleep 1
        break # Keluar dari loop seleksi untuk melanjutkan ke alur utama skrip
    else
        echo -e "${RED}[X] Pilihan tidak valid! Masukkan nomor repo, [t], atau [q].${NC}"
        sleep 1.5
    fi
done

# Menentukan jalur kerja repositori yang dipilih di dalam direktori aktif saat ini
rp="${PWD}/${r}"

```

### ✨ Keunggulan Fitur Baru Ini:
1. Loop Dinamis Fleksibel: Skrip menggunakan perintah `continue` untuk mengulang menu dari awal setiap kali Anda selesai menambahkan repo baru. Dengan begitu, `mapfile` akan langsung membaca ulang berkas `repo.txt` yang sudah ter-update dan menampilkannya di layar detik itu juga.
2. Proteksi Duplikasi: Skrip memeriksa seluruh isi array sebelum menulis nama proyek baru. Jika nama proyek yang dimasukkan sudah terdaftar, skrip akan memberikan peringatan dan menolak menulis duplikat ke dalam berkas teks.
3. Pembersihan Karakter Spasi: Perintah `tr -d '[:space:]'` disematkan untuk memastikan input bersih dari spasi tidak sengaja yang bisa merusak susunan parameter URL Git remote.



<br>
