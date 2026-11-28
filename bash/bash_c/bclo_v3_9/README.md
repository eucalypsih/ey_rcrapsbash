
qs: 
# Contoh mengambil file dari backup_u330 langsung ke indeks biner (0-byte disk)
obj_info=$(git -C $HOME/ey_rcrapsbash ls-tree backup_u330 -- "go_r/README.md")
mode=$(echo "$obj_info" | awk '{print $1}')
sha=$(echo "$obj_info" | awk '{print $3}')

git -C $HOME/ey_rcrapsbash update-index --add --cacheinfo "${mode},${sha},go_r/README.md"
git -C $HOME/ey_rcrapsbash commit -m "u324"
bisa menambahkan fitur baru ini ke main.sh

---

aa: 
Menambahkan kemampuan membuat branch baru (0-byte `update-ref` ) dan opsi pembersihan branch backup di dalam alur manajemen branch adalah ide yang sangat tetap. Agar kode tetap terstruktur dan konsisten dengan filosofi *plumbing 0-byte* Anda, cara terbaik adalah memperluas menu `[v]` menjadi pusat manajemen branch virtual lengkap (pindah branch, buat branch baru 0-byte dari commit/HEAD mana pun, dan hapus branch lama), serta menambahkan pintasan langsung ke pembuatan branch di dalam menu `[i]` .

## 1. Perbarui Menu `[v]` Menjadi Manajemen Branch Virtual Lengkap (0-Byte)

Ganti blok `[vV]) ... :;`; Anda dengan versi terpadu berikut yang mendukung pindah branch, buat branch baru dari `HEAD` atau dari hash commit tertentu (misalnya membuat `backup_u330` sebelum reset), dan hapus branch:

```bash
      [vV])
        # =====================================================================
        # MANAJEMEN BRANCH VIRTUAL INSTAN (PINDAH, BUAT BARU, HAPUS - 0-BYTE)
        # =====================================================================
        while true; do
          clear
          _header "MANAJEMEN BRANCH VIRTUAL (0-BYTE)" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
          _line "=" 50 "$FG_CYAN"

          # Tampilkan semua branch lokal yang ada
          mapfile -t semua_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
          echo -e "${LIGHT_GRAY}Daftar Branch Lokal:${NC}"
          for i in "${!semua_branch[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
            if [ "${semua_branch[$i]}" == "$current_branch" ]; then
              printf "%b%b [%d] %-25s %b[ AKTIF ]%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$FG_GREEN" "${FG_REDUP}${bg_row}" "${NC}"
            else
              printf "%b%b [%d] %-25s\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          _menu_opt "c" "$FG_GREEN"  "Buat Branch Baru Virtual" "(0-Byte update-ref)"
          _menu_opt "x" "$RED"       "Hapus Branch Lokal" "(git branch -D)"
          _menu_opt "b" "$FG_YELLOW" "Kembali ke Menu Sparse-Checkout"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor branch untuk pindah, atau opsi [c/x/b]"
          read -r br_aksi

          [[ "$br_aksi" =~ ^[bB]$ ]] && break

          # --- OPSI [c]: BUAT BRANCH BARU 0-BYTE ---
          if [[ "$br_aksi" =~ ^[cC]$ ]]; then
            _line "-" 50 "$FG_CYAN"
            _p "Masukkan nama branch baru (Contoh: backup_u330 atau dev)"
            read -r nama_br_baru
            nama_br_clean=$(echo "$nama_br_baru" | tr -d '[:space:]')

            if [ -z "$nama_br_clean" ]; then
              _e "Nama branch tidak boleh kosong!"
              sleep 1
              continue
            fi

            if git -C "$rp" show-ref --verify --quiet "refs/heads/${nama_br_clean}"; then
              _w "Branch '${nama_br_clean}' sudah ada!"
              sleep 1.2
              continue
            fi

            _p "Titik awal branch (Kosongkan/Enter = HEAD saat ini, atau ketik hash commit)"
            read -r base_commit
            [ -z "$base_commit" ] && base_commit="HEAD"

            target_sha=$(git -C "$rp" rev-parse --verify "${base_commit}^{commit}" 2>/dev/null)
            if [ -z "$target_sha" ]; then
              _e "Referensi commit '${base_commit}' tidak ditemukan!"
              sleep 1.5
              continue
            fi

            # Tulis referensi branch baru langsung secara biner (0-Byte disk)
            if git -C "$rp" update-ref "refs/heads/${nama_br_clean}" "$target_sha" 2>/dev/null; then
              _o "Branch '${nama_br_clean}' berhasil dibuat pada commit ${target_sha:0:7} (0-Byte)!"
              _p "Apakah ingin langsung pindah ke branch '${nama_br_clean}'? (y/n)"
              read -r langsung_pindah
              if [[ "$langsung_pindah" =~ ^[yY]$ ]]; then
                git -C "$rp" symbolic-ref HEAD "refs/heads/${nama_br_clean}" 2>/dev/null
                current_branch="$nama_br_clean"
                git -C "$rp" read-tree "$current_branch" 2>/dev/null
                git -C "$rp" update-index --refresh &>/dev/null
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "Berhasil pindah ke '${current_branch}'."
                sleep 1
                break
              fi
            else
              _e "Gagal membuat branch '${nama_br_clean}'."
            fi
            sleep 1.2
            continue
          fi

          # --- OPSI [x]: HAPUS BRANCH LOKAL ---
          if [[ "$br_aksi" =~ ^[xX]$ ]]; then
            _p "Masukkan nomor branch yang ingin dihapus"
            read -r del_br_num
            if [[ "$del_br_num" =~ ^[0-9]+$ ]] && [ "$del_br_num" -ge 1 ] && [ "$del_br_num" -le "${#semua_branch[@]}" ]; then
              target_del_br="${semua_branch[$((del_br_num - 1))]}"
              if [ "$target_del_br" == "$current_branch" ]; then
                _e "Tidak dapat menghapus branch yang sedang aktif!"
                sleep 1.5
              else
                _pd "Yakin ingin menghapus branch '${target_del_br}' secara permanen?"
                read -r konf_del_br
                if [[ "$konf_del_br" =~ ^[yY]$ ]]; then
                  git -C "$rp" branch -D "$target_del_br" >/dev/null 2>&1
                  _o "Branch '${target_del_br}' berhasil dihapus."
                  sleep 1
                fi
              fi
            else
              _an "Nomor branch tidak valid."
              sleep 1
            fi
            continue
          fi

          # --- PINDAH KE BRANCH TERPILIH BERDASARKAN ANGKA ---
          if [[ "$br_aksi" =~ ^[0-9]+$ ]] && [ "$br_aksi" -ge 1 ] && [ "$br_aksi" -le "${#semua_branch[@]}" ]; then
            target_branch_clean="${semua_branch[$((br_aksi - 1))]}"
            if [ "$target_branch_clean" == "$current_branch" ]; then
              _w "Anda sudah berada di branch '${current_branch}'."
              sleep 1
              continue
            fi

            _ic "Mengalihkan pointer HEAD secara virtual ke refs/heads/${target_branch_clean}..."
            if git -C "$rp" symbolic-ref HEAD "refs/heads/${target_branch_clean}" 2>/dev/null; then
              current_branch="$target_branch_clean"
              git -C "$rp" read-tree "$current_branch" 2>/dev/null
              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
              _o "HEAD berhasil dialihkan secara instan ke branch: ${current_branch}"
              sleep 1
              break
            else
              _e "Gagal mengalihkan branch via symbolic-ref!"
              sleep 1.2
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue
        ;;

```

## 2. Pembaruan pada Menu `[i]` (Otomatis Menawarkan Pembuatan Branch Sumber Jika Belum Ada)

Pada blok `[II]` sebelumnya, jika belum ada branch lain selain `main`, skrip langsung keluar. Ubah bagian pemeriksaan awal di `[II]` agar Anda bisa langsung membuat branch baru di tempat:

```bash
        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          continue 1
        fi

```

# Mengapa Desain Ini Jauh Lebih Baik?

- **Pemisahan Tanggung Jawab** (*Separation of Concerns*): Menu `[V]` menjadi pusat kendal penuh seluruh siklus hidup branch (*buat branch 0-byte, pinDAH branch instan, dan hapus branch*), sementara menu `[i]` tetap fokus murni pada inspeksi `git diff` dan injeksi biner `--cacheinfo` antar-branch.
- **Keamanan Data**: Menghapus branch hanya bisa dilakukan lewat konfirmasi eksplisit di menu `[V]` dan dilindungi agar tidak bisa menghapus branch yang sedang aktif (`$current_branch`).
- **100% Bebas I/O Disk**: Baik pembuatan branch baru (`git update-ref`) maupun perpindahan branch (`git symbolic-ref` + `git read-tree`) berjalan murni di metadata `.git/refs/` dan `.git/index` tanpa mengunduh file ke disk Termux.

---

qa: 
Apakah Anda juga ingin menambahkan fitur Reset Pointer Branch (`git update-ref`) ke Commit Tertentu di dalam menu `[V]` sehingga proses *backup + reset* ke `a9e1c38` yang baru saja Anda lakukan bisa dijalkan sepenuhnya dari menu interaktif?

---

qc: 
ingin menambahkan fitur Reset Pointer Branch (git update-ref) ke Commit Tertentu di dalam menu [v] sehingga proses backup + reset ke a9e1c38 yang baru saja Anda lakukan bisa dijalankan sepenuhnya dari menu interaktif

---

aa: 
Untuk melengkapi **Manajemen Branch Virtual** ( `[v]` ) dengan fitur **Reset Pointer Branch ke Commit Tertentu** ( `[r]` ) yang tetap 100% murni 0-byte biner dan aman dari kejadian seperti penghapusan massal, fitur ini dapat langsung menawarkan **opsl auto-backup branch sebelum reset** serta menyinkronkan indeks dan file fisik lokal secara bersih.

## **Kode Lengkap Blok** `[v]` dengan **Fitur Reset Pointer** ( `[r]` )

Ganti seluruh blok `[v] ... ;;` Anda dengan kode berikut:

```bash
      [vV])
        # =====================================================================
        # MANAJEMEN BRANCH VIRTUAL (PINDAH, BUAT, RESET POINTER, HAPUS - 0-BYTE)
        # =====================================================================
        while true; do
          clear
          _header "MANAJEMEN BRANCH VIRTUAL (0-BYTE)" 50 "$FG_CYAN" "$FG_GREEN"
          head_short=$(git -C "$rp" rev-parse --short HEAD 2>/dev/null)
          head_msg=$(git -C "$rp" log -1 --format="%s" 2>/dev/null)
          echo -e "Repositori   : ${FG_YELLOW}${r}${NC}"
          echo -e "Branch Aktif : ${GREEN}${current_branch}${NC} (${FG_CYAN}${head_short}${NC} - ${head_msg})"
          _line "=" 50 "$FG_CYAN"

          # Tampilkan semua branch lokal yang ada
          mapfile -t semua_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
          echo -e "${LIGHT_GRAY}Daftar Branch Lokal:${NC}"
          for i in "${!semua_branch[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
            br_sha=$(git -C "$rp" rev-parse --short "refs/heads/${semua_branch[$i]}" 2>/dev/null)
            if [ "${semua_branch[$i]}" == "$current_branch" ]; then
              printf "%b%b [%d] %-20s (%s) %b[ AKTIF ]%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "$FG_GREEN" "${FG_REDUP}${bg_row}" "${NC}"
            else
              printf "%b%b [%d] %-20s (%s)\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          _menu_opt "c" "$FG_GREEN"  "Buat Branch Baru Virtual" "(0-Byte update-ref)"
          _menu_opt "r" "$FG_YELLOW" "Reset Pointer Branch Aktif" "(Pilih dari Riwayat Commit)"
          _menu_opt "x" "$RED"       "Hapus Branch Lokal" "(git branch -D)"
          _menu_opt "b" "$FG_CYAN"   "Kembali ke Menu Sparse-Checkout"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor branch untuk pindah, atau opsi [c/r/x/b]"
          read -r br_aksi

          [[ "$br_aksi" =~ ^[bB]$ ]] && break

          # --- OPSI [c]: BUAT BRANCH BARU 0-BYTE ---
          if [[ "$br_aksi" =~ ^[cC]$ ]]; then
            _line "-" 50 "$FG_CYAN"
            _p "Masukkan nama branch baru (Contoh: backup_u330)"
            read -r nama_br_baru
            nama_br_clean=$(echo "$nama_br_baru" | tr -d '[:space:]')

            if [ -z "$nama_br_clean" ]; then
              _e "Nama branch tidak boleh kosong!"
              sleep 1
              continue
            fi

            if git -C "$rp" show-ref --verify --quiet "refs/heads/${nama_br_clean}"; then
              _w "Branch '${nama_br_clean}' sudah ada!"
              sleep 1.2
              continue
            fi

            _p "Titik awal branch (Enter = HEAD saat ini, atau ketik hash commit)"
            read -r base_commit
            [ -z "$base_commit" ] && base_commit="HEAD"

            target_sha=$(git -C "$rp" rev-parse --verify "${base_commit}^{commit}" 2>/dev/null)
            if [ -z "$target_sha" ]; then
              _e "Referensi commit '${base_commit}' tidak ditemukan!"
              sleep 1.5
              continue
            fi

            if git -C "$rp" update-ref "refs/heads/${nama_br_clean}" "$target_sha" 2>/dev/null; then
              _o "Branch '${nama_br_clean}' berhasil dibuat pada ${target_sha:0:7} (0-Byte)!"
              _p "Langsung pindah ke branch '${nama_br_clean}'? (y/n)"
              read -r langsung_pindah
              if [[ "$langsung_pindah" =~ ^[yY]$ ]]; then
                git -C "$rp" symbolic-ref HEAD "refs/heads/${nama_br_clean}" 2>/dev/null
                current_branch="$nama_br_clean"
                git -C "$rp" read-tree "$current_branch" 2>/dev/null
                git -C "$rp" update-index --refresh &>/dev/null
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "Berhasil pindah ke '${current_branch}'."
                sleep 1
                break
              fi
            else
              _e "Gagal membuat branch '${nama_br_clean}'."
            fi
            sleep 1.2
            continue
          fi

          # --- OPSI [r]: RESET POINTER BRANCH AKTIF KE COMMIT TERTENTU (0-BYTE) ---
          if [[ "$br_aksi" =~ ^[rR]$ ]]; then
            clear
            _header "RESET POINTER BRANCH [${current_branch}]" 50 "$FG_CYAN" "$FG_YELLOW"
            echo -e "Riwayat 15 Commit Terakhir pada ${GREEN}${current_branch}${NC}:"
            _line "=" 50 "$FG_CYAN"

            mapfile -t log_commits < <(git -C "$rp" log -n 15 --format="%H|%h|%s|%cr" 2>/dev/null)
            for idx_c in "${!log_commits[@]}"; do
              IFS='|' read -r full_c short_c msg_c time_c <<< "${log_commits[$idx_c]}"
              bg_row="$BG_ZEBRA_1"
              (( idx_c % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b [%2d] %b%s%b - %-22s (%s)\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((idx_c+1)) "$FG_CYAN" "$short_c" "${FG_REDUP}${bg_row}" "${msg_c:0:22}" "$time_c" "${NC}"
            done

            _line "-" 50 "$FG_CYAN"
            _p "Pilih nomor commit (1-${#log_commits[@]}), ketik hash manual, atau 'b' batal"
            read -r pilih_commit

            [[ "$pilih_commit" =~ ^[bB]$ ]] && continue

            target_reset_sha=""
            if [[ "$pilih_commit" =~ ^[0-9]+$ ]] && [ "$pilih_commit" -ge 1 ] && [ "$pilih_commit" -le "${#log_commits[@]}" ]; then
              target_reset_sha=$(echo "${log_commits[$((pilih_commit - 1))]}" | cut -d'|' -f1)
            elif [ -n "$pilih_commit" ]; then
              target_reset_sha=$(git -C "$rp" rev-parse --verify "${pilih_commit}^{commit}" 2>/dev/null)
            fi

            if [ -z "$target_reset_sha" ]; then
              _e "Commit target tidak valid atau tidak ditemukan!"
              sleep 1.5
              continue
            fi

            _line "-" 50 "$FG_YELLOW"
            echo -e "Branch '${GREEN}${current_branch}${NC}' akan diputar balik ke: ${FG_CYAN}${target_reset_sha:0:7}${NC}"
            _p "Buat branch backup otomatis dari posisi HEAD saat ini sebelum reset? (y/n)"
            read -r buat_auto_backup
            if [[ "$buat_auto_backup" =~ ^[yY]$ ]]; then
              default_bk="backup_${current_branch}_$(date +%Y%m%d_%H%M)"
              _p "Nama branch backup (Enter = ${default_bk})"
              read -r nama_bk_input
              nama_bk_final=$(echo "${nama_bk_input:-$default_bk}" | tr -d '[:space:]')
              if git -C "$rp" update-ref "refs/heads/${nama_bk_final}" HEAD 2>/dev/null; then
                _o "Backup aman tersimpan di branch '${nama_bk_final}'!"
              else
                _e "Gagal membuat branch backup. Reset dibatalkan demi keamanan."
                sleep 1.5
                continue
              fi
            fi

            _pd "Konfirmasi: Reset pointer '${current_branch}' ke ${target_reset_sha:0:7} sekarang?"
            read -r konf_reset
            if [[ "$konf_reset" =~ ^[yY]$ ]]; then
              _ic "Memutar ulang referensi branch & menyinkronkan indeks biner 0-byte..."

              # 1. Pindahkan pointer branch secara biner (0-byte)
              git -C "$rp" update-ref "refs/heads/${current_branch}" "$target_reset_sha"

              # 2. Baca ulang pohon file target ke indeks dan pertahankan bit skip-worktree
              git -C "$rp" read-tree "$target_reset_sha"
              git -C "$rp" ls-files -z 2>/dev/null | \
                xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null

              # 3. Jika ada file fisik aktif di disk (tercatat di manifest), sinkronkan isinya
              if [ -s "$virtual_manifest_file" ]; then
                while IFS= read -r act_f || [[ -n "$act_f" ]]; do
                  [ -z "$act_f" ] && continue
                  if git -C "$rp" cat-file -e "${target_reset_sha}:${act_f}" 2>/dev/null; then
                    git -C "$rp" ls-files -z -- "$act_f" 2>/dev/null | \
                      xargs -0 -r git -C "$rp" update-index --no-skip-worktree -- 2>/dev/null
                    git -C "$rp" checkout "$target_reset_sha" -- "$act_f" 2>/dev/null
                  else
                    rm -rf "${rp}/${act_f}"
                    sed -i "\|^${act_f}$|d" "$virtual_manifest_file"
                  fi
                done < "$virtual_manifest_file"
              fi

              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

              _o "Pointer '${current_branch}' berhasil di-reset ke ${target_reset_sha:0:7} (0-Byte & tanpa jejak ' D')!"
              sleep 1.5
            else
              _c "Reset dibatalkan."
              sleep 0.8
            fi
            continue
          fi

          # --- OPSI [x]: HAPUS BRANCH LOKAL ---
          if [[ "$br_aksi" =~ ^[xX]$ ]]; then
            _p "Masukkan nomor branch yang ingin dihapus"
            read -r del_br_num
            if [[ "$del_br_num" =~ ^[0-9]+$ ]] && [ "$del_br_num" -ge 1 ] && [ "$del_br_num" -le "${#semua_branch[@]}" ]; then
              target_del_br="${semua_branch[$((del_br_num - 1))]}"
              if [ "$target_del_br" == "$current_branch" ]; then
                _e "Tidak dapat menghapus branch yang sedang aktif!"
                sleep 1.5
              else
                _pd "Yakin ingin menghapus branch '${target_del_br}' secara permanen?"
                read -r konf_del_br
                if [[ "$konf_del_br" =~ ^[yY]$ ]]; then
                  git -C "$rp" branch -D "$target_del_br" >/dev/null 2>&1
                  _o "Branch '${target_del_br}' berhasil dihapus."
                  sleep 1
                fi
              fi
            else
              _an "Nomor branch tidak valid."
              sleep 1
            fi
continue
fi
# --- PINDAH KE BRANCH TERPILIH BERDASARKAN ANGKA ---
if [[ "$br_aksi" =~ ^[0-9]+$ ]] && [ "$br_aksi" -ge 1 ] && [ "$br_aksi" -le "${#semua_branch[@]}" ]; then
target_branch_clean="${semua_branch[$((br_aksi - 1))]}"
if [ "$target_branch_clean" == "$current_branch" ]; then
_w "Anda sudah berada di branch '${current_branch}'."
sleep 1
continue
fi
_ic "Mengalihkan pointer HEAD secara virtual ke refs/heads/${target_branch_clean}..."
if git -C "$rp" symbolic-ref HEAD "refs/heads/${target_branch_clean}" 2>/dev/null; then
current_branch="$target_branch_clean"
git -C "$rp" read-tree "$current_branch" 2>/dev/null
git -C "$rp" update-index --refresh &>/dev/null
mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
_o "HEAD berhasil dialihkan secara instan ke branch: ${current_branch}"
sleep 1
break
else
_e "Gagal mengalihkan branch via symbolic-ref!"
sleep 1.2
fi
else
_an "Pilihan tidak valid."
sleep 1
fi
done
continue
;;

```

---

### Alur Kerja Terpadu Sekarang (`[v]` → `[i]`)
1. **Buka `[v]` → Pilih `[r]` (Reset Pointer Branch):**
   * Pilih commit target dari daftar 15 riwayat terakhir (atau tempel hash seperti `a9e1c38`).
   * Jawab **`y`** saat ditanya *"Buat branch backup otomatis dari posisi HEAD saat ini sebelum reset?"* (otomatis membuat misal `backup_main_20261123_2034`).
   * Konfirmasi reset—pointer `main` langsung mundur ke `a9e1c38` dalam mode **0-byte** tanpa mengunduh file yang tidak aktif dan tanpa memunculkan jejak ` D`.
2. **Buka `[i]` (Injeksi File 0-Byte dari Branch Lain):**
   * Pilih branch backup yang baru saja dibuat (`backup_main_...`), periksa `git diff` lewat tombol `[d]`, lalu suntikkan file yang diinginkan satu per satu ke `main` dengan `u323`, `u324`, dst. secara murni 0-byte.
3. **Kembali ke `[v]` → Pilih `[x]` (Hapus Branch Lokal):**
   * Hapus branch backup sementara setelah seluruh file selesai dipindahkan.

---

qa: 
Apakah Anda ingin melihat **versi gabungan utuh** atau pengecekan sintaksis (`bash -n main.sh`) untuk memastikan seluruh blok baru (`[dD]`, `[vV]`, dan `[iI]`) sudah terpasang rapi tanpa bentrok variabel di skrip `main.sh` Anda?

---

qs: 
```bash
# Contoh 2: Mengambil perubahan file spesifik (misal rs_r/README.md)
git -C $HOME/ey_rcrapsbash checkout backup_u331 -- rs_r/README.md
git -C $HOME/ey_rcrapsbash commit -m "u323"

git -C $HOME/ey_rcrapsbash checkout backup_u331 -- go_r/README.md
git -C $HOME/ey_rcrapsbash commit -m "u324"

git -C $HOME/ey_rcrapsbash checkout backup_u331 -- git/README.md
git -C $HOME/ey_rcrapsbash commit -m "u325"

git -C $HOME/ey_rcrapsbash checkout backup_u331 -- bash/bash_c/bclo_v3_8_fix/README.md
git -C $HOME/ey_rcrapsbash commit -m "u326"

git -C $HOME/ey_rcrapsbash checkout backup_u331 -- bash/bash_c/README.md
git -C $HOME/ey_rcrapsbash commit -m "u327"

bagaimana cara menerapkan urutan ini di bash main.sh

```

---

aa: 
Untuk menerapkan urutan pemulihan tersebut menggunakan `main.sh` yang sudah Anda perbarui (menggunakan opsi `[v]` dan `[i]` secara 0-byte biner tanpa mengunduh file ke disk Termux), ikuti langkah-langkah berikut:

## Perbaikan Kecil yang Perlu Disiapkan Sebelum Menjalankan

Dalam kode `main.sh` yang Anda kirimkan, terdapat 3 bug kecil pada blok `[v]` dan `[i]` yang harus diperbaiki terlebih dahulu agar tidak error:

1. Variabel `$br_sha` kosong di menu `[v]` (baris ~781): Tambahkan `br_sha=$(git -C "$rp" rev-parse --short "refs/heads/${semua_branch[$i]}" 2>/dev/null)` di dalam loop `for i in "${!semua_branch[@]}"; do` .
2. Double warning di menu `[i]` (baris ~655): Hapus baris `_w "Tidak ada branch lokal lain yang tersedia (misal: backup_u330)."` tepat sebelum `__pp` di blok `if [ ${#daftar_branch[@]} -eq 0 ]` .
3. Auto-fetch di awal saat masuk repo (baris ~348): Saat Anda menekan `[b]` (kembali ke menu utama) dan masuk lagi ke repo, skrip menjalankan `git fetch origin main` yang menarik ulang `refs/remotes/origin/main` dari GitHub. Ini normal—nanti setelah selesai, Anda cukup push dengan `--force-with-lease` .

## Urutan Langkah Menerapkan Pemulihan di `main.sh`

### Tahap 1: Buat Backup & Reset `main` ke `a9e1c38` (Lewat Menu `[v]` )

1. Jalankan `bash main.sh`, lalu pilih repositori `eucalypsih/ey_rcrapsbash` .
2. Pada menu Sparse-Checkout, ketik `v` (_Manajemen Branch Virtual_).
3. Ketik `r` (_Reset Pointer Branch Aktif_).
4. Pilih nomor urut commit `a9e1c38` ( `u322` ) dari daftar 15 commit terakhir (atau ketik manual `a9e1c38` ).
5. Saat ditanya "Buat branch backup otomatis dari posisi HEAD saat ini sebelum reset? (y/n)", ketik `y` , lalu beri nama `backup_u331` .
6. Saat ditanya konfirmasi reset, ketik `y` .
   (Sekarang branch `main` sudah kembali ke `a9e1c38` secara 0-byte, dan branch `backup_u331` tersimpan aman).
7. Ketik `b` untuk kembali ke menu Sparse-Checkout.

### Tahap 2: Suntikkan 5 File Secara Berurutan ( `u323` s/d `u327` ) Lewat Menu `[i]`

1. Pada menu Sparse-Checkout, ketik `i` (_Injeksi File 0-Byte dari Branch Lain_).
2. Pilih nomor branch `backup_u331` dari daftar branch sumber.
3. Layar akan menampilkan 5 file yang berubah/bertambah ( `AM` ):
   - `bash/bash_c/README.md`
   - `bash/bash_c/bclo_v3_8_fix/README.md`
   - `git/README.md`
   - `go_r/README.md`
   - `rs_r/README.md`
4. Masukkan nomor file satu per satu sesuai urutan yang Anda inginkan (tekan `Enter` untuk menyetujui pesan otomatis `u323` , `u324` , dst.):
   - Pilih nomor `rs_r/README.md` → `Enter` _(otomatis tercatat sebagai `u323` )_
   - Pilih nomor `go_r/README.md` → `Enter` _(otomatis tercatat sebagai `u324` )_
   - Pilih nomor `git/README.md` → `Enter` _(otomatis tercatat sebagai `u325` )_
   - Pilih nomor `bash/bash_c/bclo_v3_8_fix/README.md` → `Enter` _(otomatis tercatat sebagai `u326` )_
   - Pilih nomor `bash/bash_c/README.md` → `Enter` _(otomatis tercatat sebagai `u327` )_
5. Setelah ke-5 file selesai diinjeksi, daftar file akan kosong dan layer otomatis kembali ke menu Sparse-Checkout.

**Tahap 3: Hapus Branch Backup** `backup_u331` (Lewat Menu `[v]`)

1. Ketik `[v]` untuk masuk kembali ke Manajemen Branch Virtual.
2. Ketik `[x]` (_Hapus Branch Lokal_), pilih nomor `backup_u331`, lalu konfirmasi `[y]`.
3. Ketik `[b]` untuk kembali ke menu Sparse-Checkout.

**Tahap 4: Sinkronkan Riwayat Baru ke GitHub**

Karena riwayat lokal `main` baru saja diupload ulang dari `a9e1c38` (bukan fast-forward biasa), tombol `[q]` standar ( `git push` biasa) akan ditolak oleh GitHub ( `non-fast-forward` ). Jalankan satu perintah ini di terminal setelah keluar ( `[b]` -> `[q]` ):

```bash
git -C $HOME/ey_rcrapsbash push --force-with-lease origin main
```

Gunakan kode dengan hati-hati.

---

qa: 
Apakah Anda ingin saya menambahkan deteksi otomatis `force-with-lease` di dalam opsi! `[q]` ketika riwayat lokal divergen akibat reset pointer `[v]` -> `[r]` , sehingga proses push ke GitHub juga bisa langsung dilakukan dari menu `[q]` tanpa mengetik perintah manual di terminal?

---

qs: 
```bash
==================================================
 PILIH FILE DARI [backup_main_20261124_0229]
==================================================
Target Branch: main | Mode: 0-Byte Biner
==================================================
 [1] bash/bash_c/README.md [Ubah/M]
 [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A]
 [3] git/README.md [Ubah/M]
 [4] go_r/README.md [Baru/A]
 [5] rs_r/README.md [Ubah/M]
--------------------------------------------------
 [d] Lihat Diff Baris File Sebelum Injeksi
 [b] Kembali ke Menu Sparse-Checkout
==================================================
[~] Pilih nomor file untuk diinjeksi (0-Byte): 3
Pesan otomatis: u323
[~] Tekan [Enter] untuk 'u323', atau ketik pesan manual:

setelah menekan enter di bagian `[~] Tekan [Enter] untuk 'u323', atau ketik pesan manual:`, apakah bisa langsung menampilkan perubahan, atau adakah cara yang lebih baik untuk bash main.sh

```

---

aa: 
**Bisa.** Anda dapat menambahkan **ringkasan perubahan** (`git show --stat` dan `git diff` **berwarna**) tepat setelah commit berhasil dibuat, lalu memberi jeda singkat (atau tombol lanjut cepat) sebelum layar di-`clear` untuk kembali ke daftar file berikutnya.

Selain itu, agar alur kerja di menu `[1]` jauh lebih cepat dan informatif, berikut **3 peningkatan terbaik** yang bisa langsung Anda terapkan di blok `[ii]` pada `main.sh`:

## 1. Tampilkan Ringkasan Commit & Diff Otomatis Setelah Injeksi Berhasil

Ganti bagian akhir setelah `new_commit_id` berhasil dibuat (sekitar baris 740 di `main.sh`) dengan blok berikut agar langsung mencetak **hash commit baru, pesan commit, statistik file** (`--stat`), **serta diff baris** (`+ / -`) tepat sebelum kembali ke daftar:

```bash
if [ -n "$new_commit_id" ]; then
```

















































#!/bin/bash

GREEN='\033[0;32m';
YELLOW='\033[0;33m';
BLUE='\033[0;34m';
CYAN='\033[0;36m';
LIGHT_GRAY='\033[0;37m';

BG_ZEBRA_1='\033[48;2;18;22;28m';
BG_ZEBRA_2='\033[48;2;28;34;43m';

# =====================================================================
# FUNGSI UNIVERSAL PENGHITUNG WARNA ANSI 24-BIT (TRUECOLOR)
# Format Pemanggilan:
#   hitung_warna_rgb <mode> <persen> <bg_r> <bg_g> <bg_b> <fg_r> <fg_g> <fg_b>
#   - mode: "fg" (38 = warna teks) atau "bg" (48 = warna latar belakang)
# =====================================================================
hitung_warna_rgb() {
  local mode="$1"
  local persen="${2:-50}"
  local r1="$3" g1="$4" b1="$5"
  local r2="$6" g2="$7" b2="$8"

  local kode_ansi=38
  [[ "$mode" == "bg" ]] && kode_ansi=48

  # Rumus interpolasi linier tunggal untuk semua kanal warna
  local r=$(( r1 + (r2 - r1) * persen / 100 ))
  local g=$(( g1 + (g2 - g1) * persen / 100 ))
  local b=$(( b1 + (b2 - b1) * persen / 100 ))

  printf '\033[%d;2;%d;%d;%dm' "$kode_ansi" "$r" "$g" "$b"
}

# =====================================================================
# KONFIGURASI PALET WARNA DINAMIS (CUKUP UBAH ANGKA PERSENTASE)
# =====================================================================
SHOW_COLOR_PREVIEW=0   # 1 = Tampilkan pratinjau warna | 0 = Sembunyikan

zebra_gelap=2     # Persentase kecerahan baris zebra genap
zebra_terang=7    # Persentase kecerahan baris zebra ganjil
persen_redup=80   # Persentase kecerahan teks nama file
persen_cyan=55    # Persentase kecerahan label [ lokal ready ]
persen_green=55        # Persentase kecerahan label [ daftar aktif / sudah aktif ]
persen_yellow=80

# Generate seluruh variabel warna dari satu fungsi universal
BG_ZEBRA_1=$(hitung_warna_rgb "bg" "$zebra_gelap"   10 12 16  220 230 245)
BG_ZEBRA_2=$(hitung_warna_rgb "bg" "$zebra_terang"  10 12 16  220 230 245)
FG_REDUP=$(hitung_warna_rgb   "fg" "$persen_redup"  23 28 35  220 230 245)
FG_CYAN=$(hitung_warna_rgb    "fg" "$persen_cyan"   23 28 35    0 235 255)
FG_GREEN=$(hitung_warna_rgb   "fg" "$persen_green"  23 28 35   35 235 130)
FG_YELLOW=$(hitung_warna_rgb  "fg" "$persen_yellow" 23 28 35  245 200 65)


# Fungsi helper mencetak garis pemisah horizontal langsung ke terminal (tanpa _cc)
# Penggunaan:
#   _line                     -> 40 karakter '=' warna FG_REDUP (bawaan)
#   _line "-"                 -> 40 karakter '-' warna FG_REDUP
#   _line "=" 40 "$FG_CYAN"   -> 40 karakter '=' warna FG_CYAN
_line() {
  local char="${1:-=}"
  local len="${2:-40}"
  local color="${3:-$FG_REDUP}"
  local line_str

  printf -v line_str "%*s" "$len" ""
  printf "%b%s%b\n" "$color" "${line_str// /$char}" "$NC"
}


# Fungsi helper mencetak header dengan posisi judul otomatis di tengah (center)
# Penggunaan:
#   _header "PILIH REPOSITORI UTAMA"
#   _header "PILIH REPOSITORI UTAMA" 50
#   _header "PILIH REPOSITORI UTAMA" 50 "$FG_CYAN" "$FG_GREEN"
_header() {
  local title="$1"
  local len="${2:-40}"               # Panjang garis (default 40, bebas diubah)
  local line_color="${3:-$FG_CYAN}"  # Warna garis (default Cyan)
  local title_color="${4:-$NC}"      # Warna teks judul (default Putih Terminal)

  local title_len=${#title}
  local pad=0

  # Hitung spasi kiri agar posisi teks berada tepat di tengah panjang garis
  if (( len > title_len )); then
    pad=$(( (len - title_len) / 2 ))
  fi

  _line "=" "$len" "$line_color"
  printf "%*s%b%s%b\n" "$pad" "" "$title_color" "$title" "$NC"
  _line "=" "$len" "$line_color"
}

_menu_opt() {
  local key="$1"
  local color="$2"
  local label="$3"
  local extra="${4:-}" # Opsional: teks tambahan di ujung kanan dengan warna redup

  if [ -n "$extra" ]; then
    printf "%b [%s] %b%s %b%s%b\n" "$FG_REDUP" "$key" "$color" "$label" "$FG_REDUP" "$extra" "$NC"
  else
    printf "%b [%s] %b%s%b\n" "$FG_REDUP" "$key" "$color" "$label" "$NC"
  fi
}

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
  _header "PILIH REPOSITORI UTAMA" 50 "$FG_CYAN" "$FG_GREEN"
  _cc "Daftar Repositori Terpantau (Format: owner/repo):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Pilih warna latar belakang selang-seling (ganjil/genap)
      if (( i % 2 == 0 )); then
        bg_row="$BG_ZEBRA_1"
      else
        bg_row="$BG_ZEBRA_2"
      fi

      # Cek apakah folder repo lokal fisik sudah ada berdasarkan nama reponya saja
      owner_name="${valid_repos[$i]%%/*}"
      local_repo_name="${valid_repos[$i]#*/}"

      status_str=" %b[ daftar aktif ]%b"
      status_args=("${FG_GREEN}" "${FG_REDUP}${bg_row}")

      if [ -d "${PWD}/${owner_name}/${local_repo_name}/.git" ]; then
        status_str="${status_str} %b[ lokal aktif ]%b"
        status_args+=("${FG_CYAN}" "${FG_REDUP}${bg_row}")
      fi
      # Cetak baris dengan teks redup dan latar belakang penuh hingga ujung kanan layar (\033[K)
      printf "%b%b [%d] %-30s${status_str}\033[K%b\n" \
        "$bg_row" "$FG_REDUP" $((i+1)) "${valid_repos[$i]}" "${status_args[@]}" "${NC}"
    done
  fi

  _line "-" 50 "$FG_CYAN"
  _menu_opt "t" "$FG_GREEN" "Tambah Repositori Baru"
  _menu_opt "h" "$RED" "Hapus Repo dari Daftar" "rp.txt"
  _menu_opt "f" "$YELLOW" "Hanya Hapus Folder Fisik Lokal"
  _menu_opt "q" "$RED" "Keluar dari Skrip"
  _line "=" 50 "$FG_CYAN"
  _p "Masukkan pilihan Anda"
  read -r repo_pilihan

  # OPSI KELUAR
  if [[ "$repo_pilihan" =~ ^[qQ]$ ]]; then
    _an "Proses dibatalkan. Keluar dari skrip."
    exit 0
  fi

  # OPSI TAMBAH REPO BARU (Mendukung input owner/repo secara fleksibel)
  if [[ "$repo_pilihan" =~ ^[tT]$ ]]; then
    _line "-" 50 "$FG_CYAN"
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
    sleep 0.5
    # break <-- HAPUS ATAU KOMENTARI BARIS INI AGAR LOOP MENU UTAMA TETAP HIDUP
  else
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], [f], atau [q]."
    sleep 1.5
    continue 1 # <-- KOREKSI: Melompat kembali ke atas jika salah input angka
  fi



  # Menentukan jalur kerja repositori yang dipilih di dalam direktori aktif saat ini
  # Menggunakan direktori aktif saat skrip dijalankan (pwd) + nama_owner + nama_repo
  rp="${PWD}/${o}/${r}"

  # =====================================================================
  # TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
  # =====================================================================
  current_branch="main" # Nilai default awal

  if [ -d "$rp/.git" ]; then
    # KOREKSI PLUMBING: Membaca referensi branch aktif langsung dari memori HEAD secara instan
    detected_ref=$(git -C "$rp" symbolic-ref --short HEAD 2>/dev/null)
    
    # PERBAIKAN: Memeriksa apakah $detected_ref tidak kosong
    if [ -n "$detected_ref" ]; then
      current_branch="$detected_ref"
      _o "Sukses Branch saat ini terdeteksi" "$current_branch"
    else
      # Fallback aman jika repositori dalam kondisi detached HEAD
      current_branch=$(git -C "$rp" rev-parse --abbrev-ref HEAD 2>/dev/null)
      _w "HEAD terlepas (detached). Mengunci branch ke" "$current_branch"
    fi # end if detected_branch
  else
    # PERBAIKAN: Menangani kondisi jika direktori .git tidak ada
    # Pengecekan awal dilewati jika folder belum di-clone
    _ic "Menyiapkan alur kloning untuk direktori baru..."
    # exit 1  <-- HAPUS ATAU KOMENTARI BARIS INI
  fi # end if git dir check

  sleep 0.5

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

    # 1. Deteksi otomatis cabang remote jika 'main' tidak ditemukan (misal: 'master')
    if ! git -C "$rp" show-ref --verify --quiet "refs/remotes/origin/${current_branch}"; then
      remote_head=$(git -C "$rp" symbolic-ref --short "refs/remotes/origin/HEAD" 2>/dev/null)
      if [ -n "$remote_head" ]; then
        current_branch="${remote_head#origin/}"
      fi
    fi

    mode_file="${rp}/.git/index_init_mode"

    # 2. Eksekusi 3 Baris Plumbing dengan Fallback ke Checkout Standar jika gagal
    if git -C "$rp" show-ref --verify --quiet "refs/remotes/origin/${current_branch}"; then
      if git -C "$rp" update-ref "refs/heads/${current_branch}" "refs/remotes/origin/${current_branch}" 2>/dev/null && \
         git -C "$rp" symbolic-ref HEAD "refs/heads/${current_branch}" 2>/dev/null && \
         git -C "$rp" read-tree --reset -u "HEAD" &>/dev/null; then
        _o "Inisialisasi cabang '${current_branch}' & indeks biner berhasil."
        echo "BINER" > "$mode_file"
      else
        _w "Metode plumbing gagal. Menjalankan fallback checkout standar..."
        git -C "$rp" checkout -q "$current_branch" &>/dev/null
        echo "FALLBACK" > "$mode_file"
      fi
    else
      # Pengaman jika repositori remote masih 0-commit (kosong total)
      _w "Repositori remote kosong (belum ada commit). Menyiapkan HEAD awal..."
      git -C "$rp" symbolic-ref HEAD "refs/heads/${current_branch}" 2>/dev/null
      echo "KOSONG" > "$mode_file"
    fi
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
          continue 1
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

  # Baca status metode inisialisasi indeks yang tersimpan
  saved_mode=$(cat "${rp}/.git/index_init_mode" 2>/dev/null)
  case "$saved_mode" in
    "FALLBACK") status_init_index="${FG_YELLOW}[Mode: Fallback Checkout]${NC}" ;;
    "KOSONG")   status_init_index="${LIGHT_GRAY}[Mode: HEAD Kosong]${NC}" ;;
    *)          status_init_index="${FG_CYAN}[Mode: Indeks Biner]${NC}" ;;
  esac

  # =====================================================================
  # MODUL REKOMENDASI: VIRTUAL MANIFEST-BASED LAZY LOADING (0-BYTE DISK)
  # =====================================================================

  # Array internal pelacak manifest virtual yang diaktifkan user via menu utama
  # Menggunakan file sementara atau variabel array state lokal
  virtual_manifest_file="${rp}/.git/virtual_sparse_manifest"
  touch "$virtual_manifest_file"

  # Membaca seluruh isi root (folder & file) tingkat pertama dari remote
  # Membaca daftar item tingkat pertama dari indeks remote (0-byte fisik)
  # =================================================================
  # OPTIMASI EKSTREM: REKAM TIPE DAN NAMA SEKALIGUS DALAM SATU TEMBAKAN
  # =================================================================
  # Mengambil tipe (tree/blob) dan nama file, dipisahkan dengan karakter TAB
  mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
  if [ ${#targets[@]} -eq 0 ]; then
      _w "Repositori saat ini tidak memiliki folder (hanya berisi file root)."
      sleep 1.5
  fi

  # =====================================================================
  # FITUR AUTO-HEALING: SINKRONISASI ULANG MANIFEST JIKA TERHAPUS (TREE & BLOB)
  # =====================================================================
  if [ -d "$rp" ]; then
    for baris_data in "${targets[@]}"; do
      # 1. Pisahkan tipe dan nama item berdasarkan karakter TAB di memori RAM
      tipe_item="${baris_data%%	*}"
      target_item="${baris_data#*	}"

      # 2. Inisialisasi bendera status keberadaan fisik di disk lokal Termux
      item_ditemukan_di_disk=0

      # 3. Jalankan pengecekan spesifik berdasarkan tipe manifes biner Git
      if [ "$tipe_item" == "tree" ]; then
        # Cek apakah folder fisik benar-benar eksis di penyimpanan
        if [ -d "${rp}/${target_item}" ]; then
          item_ditemukan_di_disk=1
        fi
      elif [ "$tipe_item" == "blob" ]; then
        # Cek apakah file fisik benar-benar eksis di penyimpanan
        if [ -f "${rp}/${target_item}" ]; then
          item_ditemukan_di_disk=1
        fi
      fi

      # 4. Sinkronisasi Otomatis: Jika fisik ada tapi belum tercatat di manifest virtual
      if [ "$item_ditemukan_di_disk" -eq 1 ]; then
        # Menyesuaikan dengan format penyimpanan manifest Anda (misal hanya menyimpan nama bersih $target_item)
        if ! grep -qx "${target_item}" "$virtual_manifest_file" 2>/dev/null; then
          echo "${target_item}" >> "$virtual_manifest_file"
        fi
      fi
    done
  fi
  # =====================================================================

  next_menu_action=""

  # MENU INTERAKTIF SELEKSI FOLDER
  while true; do # Loop Sparse (Tingkat 1 / Posisi saat ini)
    clear
    _header "SISTEM SELEKSI SPARSE-CHECKOUT" 50 "$FG_CYAN" "$FG_GREEN"
    _cc "Daftar folder otomatis dari Remote:"
    echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
    echo -e "Status Indeks: ${status_init_index}";

    # =====================================================================
    # PRATINJAU TERPADU PALET WARNA DINAMIS (VISUAL + KODE ANSI MENTAH)
    # =====================================================================
    if [ "${SHOW_COLOR_PREVIEW:-0}" -eq 1 ]; then
      raw_bg1="${BG_ZEBRA_1//$'\e'/\\033}"
      raw_bg2="${BG_ZEBRA_2//$'\e'/\\033}"
      raw_redup="${FG_REDUP//$'\e'/\\033}"
      raw_cyan="${FG_CYAN//$'\e'/\\033}"
      raw_green="${FG_GREEN//$'\e'/\\033}"

      _line "-" 50 "$FG_CYAN"
      printf " [BG 1] %b%b Baris Genap %b | %b%s%b\n" "$BG_ZEBRA_1" "$FG_REDUP" "$NC" "$LIGHT_GRAY" "$raw_bg1" "$NC"
      printf " [BG 2] %b%b Baris Ganjil%b | %b%s%b\n" "$BG_ZEBRA_2" "$FG_REDUP" "$NC" "$LIGHT_GRAY" "$raw_bg2" "$NC"
      printf " [FG 1] %bTeks Redup (%d%%)%b | %b%s%b\n" "$FG_REDUP" "$persen_redup" "$NC" "$LIGHT_GRAY" "$raw_redup" "$NC"
      printf " [FG 2] %b[ lokal ready ] (%d%%)%b | %b%s%b\n" "$FG_CYAN" "$persen_cyan" "$NC" "$LIGHT_GRAY" "$raw_cyan" "$NC"
      printf " [FG 3] %b[ daftar aktif ] (%d%%)%b | %b%s%b\n" "$FG_GREEN" "$persen_green" "$NC" "$LIGHT_GRAY" "$raw_green" "$NC"
      _line "-" 50 "$FG_CYAN"
    fi

    # GANTI BLOK LOOP CETAK MENU (SEKITAR BARIS 439-447) DENGAN INI:
    for i in "${!targets[@]}"; do
      # Ambil baris data mentah (Contoh: "tree	src", "blob	README.md", atau "commit	submodule_dir")
      baris_data="${targets[$i]}"

      # Trik Bash Internal: Pisahkan tipe dan nama berdasarkan karakter TAB tanpa panggil perintah eksternal
      tipe_item="${baris_data%%	*}"
      item="${baris_data#*	}"
      
      # UX ASLI: Status aktif dibaca jika item tercantum dalam manifest virtual memori
      status_aktif=""
      # Jalankan pengecekan indikator aktif (Gunakan logika cek manifest status Anda yang sudah ada)
      # Misal variabel $status_aktif Anda dikelola di sini...
      is_aktif=0
      if grep -qx "${item}" "$virtual_manifest_file" 2>/dev/null; then
        status_aktif=" ${FG_GREEN}[ sudah aktif ]"
        is_aktif=1
      fi

      # 2. VALIDASI STATUS COMMIT REAL-TIME (HANYA JIKA ITEM AKTIF DI DISK)
      status_commit=""
      target_jalur_fisik="${rp}/${item}"

      if [ "$is_aktif" -eq 1 ] && [ -e "$target_jalur_fisik" ]; then
        # Membaca manifes biner Git status secara kilat untuk file/folder spesifik ini
        # --porcelain menghasilkan output kosong jika file/folder 100% sinkron dan bersih
        perubahan_lokal=$(git -C "$rp" status --porcelain=v1 --untracked-files=all "$item" 2>/dev/null | grep -v '^ D')
        
        
        if [ -n "$perubahan_lokal" ]; then
          # Jika ada modifikasi yang belum di-commit di lokal
          status_commit="${FG_YELLOW} (Ada Perubahan Lokal)"
        else
          # Jika bersih, cek apakah HEAD lokal berbeda dengan pelacak remote origin
          diff_check=$(git -C "$rp" rev-list --count "origin/${current_branch}..HEAD" -- "$item" 2>/dev/null)
          if [ "${diff_check:-0}" -gt 0 ]; then
            status_commit="${BLUE} (Butuh Sinkronisasi)"
          else
            status_commit="${FG_REDUP} (Sinkron)"
          fi
        fi
      fi

      # 3. CETAK MENU INTERAKTIF BERDASARKAN SPESIFIKASI TIPE OBJEK GIT
      case "$tipe_item" in
        "tree")
          # Jika folder, cetak dengan tanda kurung / di depannya
          # Format untuk Folder (Garis miring di depan)
          printf "%b [%d] /%-12s%b%b%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$NC"
          ;;
        "blob")
          # Jika file di root (blob), cetak nama filenya saja secara bersih
          # Format untuk Berkas Reguler (Bersih tanpa tanda tambahan)
          printf "%b [%d]  %-12s%b%b%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$NC"
          ;;
        "commit")
          # Format khusus untuk Git Submodule / Nested Commit Object
          printf "%b [%d] @%-12s%b%b ${MAGENTA}[Submodule]${NC}\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit"
          ;;
        *)
          # Cadangan untuk tipe data asing lainnya
          printf "%b [%d] ?%-12s%b%b (%s)%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$tipe_item" "$NC"
          ;;
      esac
    done # end for targets

    _line "-" 50 "$FG_CYAN"
    _menu_opt "a" "$FG_CYAN"  "Aktifkan File Massal" "(Unduh ke Lokal Ready)"
    _menu_opt "e" "$FG_GREEN" "Edit File Lokal Ready" "(Buka di Micro)"
    _menu_opt "n" "$FG_GREEN" "Buat File Baru di Folder Aktif"
    _menu_opt "d" "$RED"      "Hapus File atau Sub-Folder" "(Git RM)"
    _menu_opt "v" "$FG_CYAN"  "Pindah Branch Virtual Instan" "(symbolic-ref)"
    _menu_opt "s" "$FG_CYAN"  "Injeksi Submodule Virtual 0-Byte" "(Objek Commit)"
    _menu_opt "i" "$FG_GREEN" "Injeksi File 0-Byte dari Branch Lain" "(cacheinfo)"
    _menu_opt "q" "$RED"      "Keluar & Terapkan Perubahan" "(Checkout)"
    _menu_opt "b" "$RED"      "Kembali ke Menu Pilih Repositori Utama"
    _line "=" 50 "$FG_CYAN"
    if [ -n "$next_menu_action" ]; then
      pilihan="$next_menu_action"
      next_menu_action=""
    else
      _p "Masukkan pilihan Anda"
      read -r pilihan
    fi

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
        # LOGIKA KELUAR [q] (PORCELAIN FILTER & PLUMBING SINKRONISASI SEJATI)
        # =====================================================================
        _ic "Memeriksa integritas berkas lokal sebelum keluar..."

        # 1. Ambil status porcelain tanpa file eksternal untracked agar cepat
        raw_status=$(git -C "$rp" status --porcelain=v1 --untracked-files=all 2>/dev/null)
        perubahan_lokal=""

        # 2. Saring status D palsu dari efek samping penyusutan sparse-checkout
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          
          status_code="${line:0:2}"
          file_path="${line:3}"

          if [[ "$status_code" =~ "D" ]]; then
            folder_induk="${file_path%%/*}"
            if ! grep -qx "${folder_induk}" "$virtual_manifest_file" 2>/dev/null; then
              continue
            fi

            # Abaikan jika kode adalah ' D' (file virtual 0-byte yang memang belum diunduh)
            if [[ "$status_code" == " D" ]]; then
              continue
            fi
          fi
          perubahan_lokal+="${line}\n"
        done <<< "$raw_status"

        # 3. KEPUTUSAN KELUAR BERDASARKAN HASIL FILTER SEJATI
        if [ -n "$perubahan_lokal" ] && [ "$perubahan_lokal" != "\n" ]; then
          _w "Peringatan: Ada berkas yang benar-benar telah Anda ubah/hapus secara lokal!"
          echo -e "${FG_YELLOW}${perubahan_lokal}${NC}"
          _line "-" 50 "$FG_REDUP"
          echo "Pilih tindakan Anda:"
          _menu_opt "1" "$FG_GREEN" "Simpan perubahan (Commit secara lokal)"
          echo -e " [2] ${RED}Abaikan & Paksa update (Buang hasil editan Anda)${NC}"
          echo -e " [3] ${FG_YELLOW}Abaikan & Batalkan Keluar (Kembali ke menu)${NC}"
          _line "-" 50 "$FG_CYAN"
          _p "Pilihan Anda (1/2/3)"
          read -r aksi_keluar

          if [ "$aksi_keluar" == "1" ]; then
            log_critical "Tindakan ini akan merekam perubahan ke Git!"
            _p "Ketik 'EXPLICIT' (huruf besar) untuk melanjutkan konfirmasi"
            read -r verifikasi_aman

            if [ "$verifikasi_aman" != "EXPLICIT" ]; then
              _an "Verifikasi gagal! Tindakan dibatalkan."
              sleep 2
              continue
            fi

            # Auto-Increment Pesan Commit
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              next_num=$((last_num + 1))
              auto_msg="u${next_num}"
            else
              auto_msg="u1"
            fi

            echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk auto-msg, atau ketik pesan manual"
            read -r pesan_commit
            [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"

            _ic "Merekam perubahan ke staging area..."
            git -C "$rp" add --sparse .

            _ic "Menghasilkan objek komit langsung di memori..."
            tree_id=$(git -C "$rp" write-tree 2>/dev/null)

            if [ -n "$tree_id" ]; then
              parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)
              if [ -n "$parent_id" ]; then
                new_commit_id=$(echo "$pesan_commit" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              else
                new_commit_id=$(echo "$pesan_commit" | git -C "$rp" commit-tree "$tree_id" -S 2>/dev/null)
              fi

              if [ -n "$new_commit_id" ]; then
                # Geser pointer cabang lokal aktif
                git -C "$rp" update-ref "refs/heads/$current_branch" "$new_commit_id"
                _o "Perubahan BERHASIL disuntikkan langsung ke commit binar lokal!"

                # 2. PAKSA REFERENSI TRACKING REMOTE TETAP BERADA PADA POSISI KOMIT LAMA (PARENT)
                # Ini adalah trik utama agar Git menyadari lokal Anda berada "Lebih Maju" daripada server
                # 2. PAKSA REFERENSI TRACKING UPSTREAM SERVER MUNDUR SATU LANGKAH KE PARENT COMMIT
                # Ini memaksa Git menyadari bahwa komit lokal Anda sekarang "Lebih Maju" daripada server
                git -C "$rp" update-ref "refs/remotes/origin/$current_branch" "$parent_id"

                # PENYELARASAN KRITIS AREA INDEKS MEMORI (AUTO-HEAL)
                # 3. Sinkronisasi biner pohon kerja indeks & refresh cache metadata instan
                git -C "$rp" read-tree "$new_commit_id"

                git -C "$rp" update-index --refresh &>/dev/null

                # 4. AMANKAN RACE CONDITION: Berikan jeda mikro agar I/O disk Termux selesai menulis referensi seutuhnya
                sleep 0.2
              else
                _w "Metode commit-tree gagal. Fallback ke commit standar..."
                git -C "$rp" commit -m "$pesan_commit"
              fi
            else
              _w "Gagal menulis tree. Fallback ke commit standar..."
              git -C "$rp" commit -m "$pesan_commit"
            fi

          elif [ "$aksi_keluar" == "2" ]; then
            _w "Membuang perubahan lokal..."
            git -C "$rp" checkout -f "$current_branch" 2>/dev/null
          else
            _r "Membatalkan proses keluar. Kembali ke menu..."
            sleep 1
            continue
          fi
        else
          # Jika tidak ada perubahan lokal, segarkan indeks lokal pasif secara aman
          git -C "$rp" update-index --refresh &>/dev/null
        fi

        # 4. KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE REPOSITORY
        _nc "========================================"
        _cc "       PERBANDINGAN STATUS COMMIT       "
        _cc "========================================"

        local_log=$(git -C "$rp" log -1 --format="%h - %s" "refs/heads/$current_branch" 2>/dev/null)
        remote_log=$(git -C "$rp" log -1 --format="%h - %s" "refs/remotes/origin/$current_branch" 2>/dev/null)

        echo -e "[Local]  : ${FG_YELLOW}${local_log:-'Belum ada commit'}${NC}"
        echo -e "[Remote] : ${FG_GREEN}${remote_log:-'Belum ada commit'}${NC}"
        _line "-" 50 "$FG_CYAN"

        # 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH
        mapfile -t semua_remote < <(git -C "$rp" remote 2>/dev/null)
        status_konflik_terdeteksi=0
        _ic "Menjalankan radar Pre-Emption pada ${#semua_remote[@]} remote server..."

        for rm_name in "${semua_remote[@]}"; do
          behind_commits=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
          if [ "${behind_commits:-0}" -gt 0 ]; then
            _e "KONFLIK TERDETEKSI: Remote [${rm_name}] lebih maju ${behind_commits} commit!"
            status_konflik_terdeteksi=1
          fi
        done

        if [ "$status_konflik_terdeteksi" -eq 1 ]; then
          log_critical "Proses Multi-Push DIBLOKIR demi keamanan data!"
          _w "Ada perbedaan riwayat di remote. Silakan lakukan 'git pull' manual terlebih dahulu."
          _line "-" 50 "$FG_REDUP"
          _p "Apakah Anda ingin mengintip daftar file yang berbeda di remote? (y/n)"
          read -r intip_diff
          
          if [[ "$intip_diff" =~ ^[yY]$ ]]; then
            _cc "=== DAFTAR PERUBAHAN BERKAS DI SERVER REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              behind_check=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
              if [ "${behind_check:-0}" -gt 0 ]; then
                _ic "Berkas berbeda pada Remote [${rm_name}] (Branch: ${current_branch}):"
                git -C "$rp" diff-tree -r --no-commit-id --name-status "refs/heads/${current_branch}" "refs/remotes/${rm_name}/${current_branch}" | while read -r status file; do
                  case "$status" in
                    A) echo -e "  ${FG_GREEN}[Ditambahkan di Server]${NC} -> $file" ;;
                    M) echo -e "  ${FG_YELLOW}[Dimodifikasi di Server]${NC} -> $file" ;;
                    D) echo -e "  ${RED}[Dihapus di Server]${NC} -> $file" ;;
                    *) echo -e "  [Perubahan: $status] -> $file" ;;
                  esac
                done
              fi
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali ke menu utama"
            read -r _
          fi
          sleep 1
        else
          # Hitung kemajuan riwayat komit lokal sejati terhadap remote origin
        # ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          # HITUNG SELISIH JARAK ANTARA REFS HEADS LOKAL AKTIF DENGAN POINTER BINARI SERVER REMOTE
          ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${ahead_commits:-0}" -gt 0 ]; then
            _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
            _p "Apakah Anda yakin ingin melakukan MULTI-PUSH ke semua remote sekarang? (y/n)"
            read -r konfirmasi_push

            if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Melakukan git push ${rm_target} ${current_branch}..."
                if git -C "$rp" push -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Push ke [${rm_target}] SUKSES!"
                else
                  _a "Gagal melakukan push ke [${rm_target}]! Periksa koneksi atau kredensial SSH Anda."
                fi
              done
            else
              _r "Push massal dibatalkan. Perubahan Anda tetap aman tersimpan di lokal."
            fi
          else
            _o "Status: Sinkron! Seluruh Remote server sama dengan Log Local Anda."
            continue 1
          fi
        fi

        _on "Selesai dengan sukses! Keluar dari skrip."
        continue 1
        ;;


      [iI])
        # =====================================================================
        # FITUR BARU: INJEKSI OBJEK FILE 0-BYTE DARI BRANCH LAIN (CACHEINFO)
        # =====================================================================
        clear
        _header "INJEKSI FILE 0-BYTE ANTAR BRANCH" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"

        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          _w "Tidak ada branch lokal lain yang tersedia (misal: backup_u330)."
          _pp
          continue 1
        fi

        echo -e "${LIGHT_GRAY}Daftar branch sumber yang tersedia:${NC}"
        for i in "${!daftar_branch[@]}"; do
          printf " [%d] %s\n" $((i+1)) "${daftar_branch[$i]}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor branch sumber (atau ketik 'b' untuk batal)"
        read -r br_pilihan

        [[ "$br_pilihan" =~ ^[bB]$ ]] && continue 1

        if ! [[ "$br_pilihan" =~ ^[0-9]+$ ]] || [ "$br_pilihan" -lt 1 ] || [ "$br_pilihan" -gt "${#daftar_branch[@]}" ]; then
          _an "Pilihan branch tidak valid."
          sleep 1
          continue 1
        fi

        source_branch="${daftar_branch[$((br_pilihan - 1))]}"

        # 2. Ambil daftar file yang bertambah (A) atau berubah (M) di branch sumber
        mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        if [ ${#diff_files[@]} -eq 0 ]; then
          _w "Tidak ada perbedaan file (A/M) antara '${current_branch}' dan '${source_branch}'."
          _pp
          continue 1
        fi

        while true; do
          # Muat ulang daftar perbedaan setiap kali selesai injeksi
          mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)
          [ ${#diff_files[@]} -eq 0 ] && break

          clear
          _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
          _line "=" 50 "$FG_CYAN"

          for i in "${!diff_files[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"

            st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
            f_path=$(echo "${diff_files[$i]}" | cut -f2-)

            if [ "$st_code" == "A" ]; then
              badge="${FG_GREEN}[Baru/A]${FG_REDUP}${bg_row}"
            else
              badge="${FG_YELLOW}[Ubah/M]${FG_REDUP}${bg_row}"
            fi

            printf "%b%b [%d] %s %b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$badge" "${NC}"
          done

          _line "-" 50 "$FG_CYAN"
          echo -e " [d] ${FG_CYAN}Lihat Diff Baris File Sebelum Injeksi${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor file untuk diinjeksi (0-Byte)"
          read -r f_pilihan

          [[ "$f_pilihan" =~ ^[bB]$ ]] && break

          # Opsi cepat melihat diff baris sebelum memutuskan injeksi
          if [[ "$f_pilihan" =~ ^[dD]$ ]]; then
            _p "Masukkan nomor file yang ingin dilihat diff-nya"
            read -r d_num
            if [[ "$d_num" =~ ^[0-9]+$ ]] && [ "$d_num" -ge 1 ] && [ "$d_num" -le "${#diff_files[@]}" ]; then
              target_diff_file=$(echo "${diff_files[$((d_num - 1))]}" | cut -f2-)
              clear
              git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_diff_file"
              _line "=" 50 "$FG_CYAN"
              _p "Tekan [Enter] untuk kembali"
              read -r _
            fi
            continue
          fi

          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            target_file=$(echo "${diff_files[$((f_pilihan - 1))]}" | cut -f2-)

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            # Auto-increment pesan commit (u323, u324, dst.)
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            echo -e "Pesan otomatis: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', atau ketik pesan manual"
            read -r pesan_injeksi
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

            _ic "Menyuntikkan '${target_file}' ke indeks biner & pohon komit..."

            # 4. Suntikkan ke index dengan --cacheinfo & --skip-worktree agar 0-byte di disk
            git -C "$rp" update-index --add --cacheinfo "${obj_mode},${obj_sha},${target_file}" 2>/dev/null
            git -C "$rp" update-index --skip-worktree -- "$target_file" 2>/dev/null

            tree_id=$(git -C "$rp" write-tree 2>/dev/null)
            parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)

            if [ -n "$tree_id" ] && [ -n "$parent_id" ]; then
              new_commit_id=$(echo "$pesan_injeksi" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

                _o "BERHASIL: '${target_file}' diinjeksi ke komit [${pesan_injeksi}] (0-Byte Disk)!"
                sleep 1.2
              else
                _e "Gagal membuat objek commit-tree (periksa SSH signing key)."
                sleep 1.5
              fi
            else
              _e "Gagal menulis tree biner Git."
              sleep 1.5
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue 1
        ;;


    [sS])
        # =====================================================================
        # FITUR: INJEKSI OBJEK COMMIT / SUBMODULE VIRTUAL 0-BYTE
        # =====================================================================
        clear
        echo -e "${BLUE}====================================================${NC}"
        echo -e "${BLUE}    FORMULIR INJEKSI SUBMODULE VIRTUAL 0-BYTE       ${NC}"
        echo -e "${BLUE}====================================================${NC}"
        echo -e "${LIGHT_GRAY}Fitur ini akan mendaftarkan repositori luar sebagai objek commit${NC}"
        echo -e "${LIGHT_GRAY}tanpa mengunduh 1-byte pun data fisik ke penyimpanan disk.${NC}"
        echo "----------------------------------------------------"
        
        # 1. Menjaring Input Data dari Pengguna
        echo -n -e "${FG_YELLOW}[?] Masukkan Nama Submodule (Misal: reqwest_core): ${NC}"
        read -r input_nama
        
        echo -n -e "${FG_YELLOW}[?] Masukkan SHA-1 Commit (Misal: 8e1c8061e5dd936762dcef08a64ef2cff584b295): ${NC}"
        read -r input_sha
        
        echo -n -e "${FG_YELLOW}[?] Masukkan URL Git Repositori SSH/HTTPS (Misal: git@github.com:seanmonstar/reqwest.git): ${NC}"
        read -r input_url

        # 2. Validasi Pengaman Input Kosong
        if [ -z "$input_nama" ] || [ -z "$input_sha" ] || [ -z "$input_url" ]; then
          echo ""
          _e "❌ Gagal: Seluruh kolom input wajib diisi secara lengkap!"
          sleep 2
          continue 1
        fi

        echo ""
        _ic "⏳ Memulai manipulasi memori biner Git tingkat rendah..."

        # 3. Daftarkan Metadata Kosmetik ke Berkas .gitmodules
        git -C "$rp" config -f .gitmodules submodule."${input_nama}".url "${input_url}"
        git -C "$rp" config -f .gitmodules submodule."${input_nama}".path "${input_nama}"
        
        # Paksa masuk ke staging area meskipun tersembunyi oleh aturan sparse
        git -C "$rp" add --sparse .gitmodules 2>/dev/null

        # 4. Eksekusi Inti: Suntikkan Kode Biner Mode 160000 ke Indeks
        if git -C "$rp" update-index --add --cacheinfo 160000,"${input_sha}","${input_nama}" 2>/dev/null; then
          
          # 5. Kunci ke Sejarah Komit Lokal Lewat commit-tree (0-Byte Overhead)
          current_tree=$(git -C "$rp" write-tree 2>/dev/null)
          pesan_otomatis="Suntikan Submodule Virtual 0-byte: ${input_nama}"
          new_commit_id=$(git -C "$rp" commit-tree "$current_tree" -p HEAD -m "$pesan_otomatis" 2>/dev/null)

          if [ -n "$new_commit_id" ]; then
            # Geser pointer cabang aktif ke commit biner baru
            git -C "$rp" update-ref "refs/heads/$current_branch" "$new_commit_id"
            
            # Sinkronkan radar tracking internal skrip agar menu langsung ter-refresh

            # ❌ HAPUS / BERIKAN TANDA KOMENTAR (#) PADA BARIS DI BAWAH INI:
            # git -C "$rp" update-ref "refs/remotes/origin/$current_branch" "$new_commit_id"  <-- HAPUS INI!

            git -C "$rp" read-tree "$new_commit_id"
            git -C "$rp" update-index --refresh &>/dev/null
            
            echo ""
            _o "✅ BERHASIL: Objek Commit /${input_nama} kini aktif dalam status 0-byte!"
          else
            _e "❌ Gagal mengunci pohon komit baru (commit-tree error)."
          fi
        else
          _e "❌ Gagal menginjeksi indeks biner Git. Pastikan format SHA-1 Anda valid."
        fi
        
        sleep 2
        continue 1
        ;;


      [vV])
        # =====================================================================
        # MANAJEMEN BRANCH VIRTUAL INSTAN (PINDAH, BUAT BARU, HAPUS - 0-BYTE)
        # =====================================================================
        while true; do
          clear
          _header "MANAJEMEN BRANCH VIRTUAL (0-BYTE)" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
          _line "=" 50 "$FG_CYAN"

          # Tampilkan semua branch lokal yang ada
          mapfile -t semua_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
          echo -e "${LIGHT_GRAY}Daftar Branch Lokal:${NC}"
          for i in "${!semua_branch[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
            if [ "${semua_branch[$i]}" == "$current_branch" ]; then
              printf "%b%b [%d] %-25s %b[ AKTIF ]%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$FG_GREEN" "${FG_REDUP}${bg_row}" "${NC}"
            else
              printf "%b%b [%d] %-25s\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          _menu_opt "c" "$FG_GREEN"  "Buat Branch Baru Virtual" "(0-Byte update-ref)"
          _menu_opt "x" "$RED"       "Hapus Branch Lokal" "(git branch -D)"
          _menu_opt "b" "$FG_YELLOW" "Kembali ke Menu Sparse-Checkout"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor branch untuk pindah, atau opsi [c/x/b]"
          read -r br_aksi

          [[ "$br_aksi" =~ ^[bB]$ ]] && break

          # --- OPSI [c]: BUAT BRANCH BARU 0-BYTE ---
          if [[ "$br_aksi" =~ ^[cC]$ ]]; then
            _line "-" 50 "$FG_CYAN"
            _p "Masukkan nama branch baru (Contoh: backup_u330 atau dev)"
            read -r nama_br_baru
            nama_br_clean=$(echo "$nama_br_baru" | tr -d '[:space:]')

            if [ -z "$nama_br_clean" ]; then
              _e "Nama branch tidak boleh kosong!"
              sleep 1
              continue
            fi

            if git -C "$rp" show-ref --verify --quiet "refs/heads/${nama_br_clean}"; then
              _w "Branch '${nama_br_clean}' sudah ada!"
              sleep 1.2
              continue
            fi

            _p "Titik awal branch (Kosongkan/Enter = HEAD saat ini, atau ketik hash commit)"
            read -r base_commit
            [ -z "$base_commit" ] && base_commit="HEAD"

            target_sha=$(git -C "$rp" rev-parse --verify "${base_commit}^{commit}" 2>/dev/null)
            if [ -z "$target_sha" ]; then
              _e "Referensi commit '${base_commit}' tidak ditemukan!"
              sleep 1.5
              continue
            fi

            # Tulis referensi branch baru langsung secara biner (0-Byte disk)
            if git -C "$rp" update-ref "refs/heads/${nama_br_clean}" "$target_sha" 2>/dev/null; then
              _o "Branch '${nama_br_clean}' berhasil dibuat pada commit ${target_sha:0:7} (0-Byte)!"
              _p "Apakah ingin langsung pindah ke branch '${nama_br_clean}'? (y/n)"
              read -r langsung_pindah
              if [[ "$langsung_pindah" =~ ^[yY]$ ]]; then
                git -C "$rp" symbolic-ref HEAD "refs/heads/${nama_br_clean}" 2>/dev/null
                current_branch="$nama_br_clean"
                git -C "$rp" read-tree "$current_branch" 2>/dev/null
                git -C "$rp" update-index --refresh &>/dev/null
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "Berhasil pindah ke '${current_branch}'."
                sleep 1
                break
              fi
            else
              _e "Gagal membuat branch '${nama_br_clean}'."
            fi
            sleep 1.2
            continue
          fi

          # --- OPSI [x]: HAPUS BRANCH LOKAL ---
          if [[ "$br_aksi" =~ ^[xX]$ ]]; then
            _p "Masukkan nomor branch yang ingin dihapus"
            read -r del_br_num
            if [[ "$del_br_num" =~ ^[0-9]+$ ]] && [ "$del_br_num" -ge 1 ] && [ "$del_br_num" -le "${#semua_branch[@]}" ]; then
              target_del_br="${semua_branch[$((del_br_num - 1))]}"
              if [ "$target_del_br" == "$current_branch" ]; then
                _e "Tidak dapat menghapus branch yang sedang aktif!"
                sleep 1.5
              else
                _pd "Yakin ingin menghapus branch '${target_del_br}' secara permanen?"
                read -r konf_del_br
                if [[ "$konf_del_br" =~ ^[yY]$ ]]; then
                  git -C "$rp" branch -D "$target_del_br" >/dev/null 2>&1
                  _o "Branch '${target_del_br}' berhasil dihapus."
                  sleep 1
                fi
              fi
            else
              _an "Nomor branch tidak valid."
              sleep 1
            fi
            continue
          fi

          # --- PINDAH KE BRANCH TERPILIH BERDASARKAN ANGKA ---
          if [[ "$br_aksi" =~ ^[0-9]+$ ]] && [ "$br_aksi" -ge 1 ] && [ "$br_aksi" -le "${#semua_branch[@]}" ]; then
            target_branch_clean="${semua_branch[$((br_aksi - 1))]}"
            if [ "$target_branch_clean" == "$current_branch" ]; then
              _w "Anda sudah berada di branch '${current_branch}'."
              sleep 1
              continue
            fi

            _ic "Mengalihkan pointer HEAD secara virtual ke refs/heads/${target_branch_clean}..."
            if git -C "$rp" symbolic-ref HEAD "refs/heads/${target_branch_clean}" 2>/dev/null; then
              current_branch="$target_branch_clean"
              git -C "$rp" read-tree "$current_branch" 2>/dev/null
              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
              _o "HEAD berhasil dialihkan secara instan ke branch: ${current_branch}"
              sleep 1
              break
            else
              _e "Gagal mengalihkan branch via symbolic-ref!"
              sleep 1.2
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue
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

        # Baca folder yang saat ini "aktif" di manifest virtual
        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        # 4. VALIDASI AWAL REPO AKTIF
        if [ ${#active_folders[@]} -eq 0 ]; then
          _hn "Belum ada folder aktif. Silakan aktifkan folder terlebih dahulu."
          _pp
        else
          log_notify "Memetakan seluruh file dan folder lokal..."
          
          # Mengambil semua file dan direktori di dalam folder aktif lokal (kecuali .git)
          all_local_items=()
          if [ -d "$rp" ]; then
            # PERBAIKAN: Kecualikan .git dengan benar (! -path '*/.git*')
            while IFS= read -r item; do
              [ -z "$item" ] && continue
              for active_dir in "${active_folders[@]}"; do
                if [[ "$item" == "$active_dir"/* || "$item" == "$active_dir" ]]; then
                  all_local_items+=("$item")
                  break
                fi
              done
            done < <(find "$rp" -mindepth 1 ! -path '*/.git*' 2>/dev/null | sed "s|^${rp}/||" | sort)
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
            echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
            _cc "========================================"
            for i in "${!all_local_items[@]}"; do
              item_path="${all_local_items[$i]}"
              if [ -d "${rp}/${item_path}" ]; then
                printf " [%d] %s/ %b[ Folder ]%b\n" $((i+1)) "$item_path" "${FG_YELLOW}" "${NC}"
              else
                printf " [%d] %s %b[ File ]%b\n" $((i+1)) "$item_path" "${FG_GREEN}" "${NC}"
              fi
            done
            _cc "----------------------------------------"
            _p "Pilih nomor target yang ingin dihapus"
            read -r hapus_idx_num

            if [[ "$hapus_idx_num" =~ ^[0-9]+$ ]] && [ "$hapus_idx_num" -ge 1 ] && [ "$hapus_idx_num" -le "${#all_local_items[@]}" ]; then
              idx=$((hapus_idx_num - 1))
              target_hapus="${all_local_items[$idx]}"
              full_target_path="${rp}/${target_hapus}"

              _line "-" 50 "$FG_REDUP"
              echo -e "Target terpilih: ${FG_YELLOW}${target_hapus}${NC}"
              _menu_opt "1" "$FG_CYAN" "Susutkan ke 0-Byte saja" "(Hapus fisik lokal, tetap ada di Git)"
              _menu_opt "2" "$RED"     "Hapus Permanen dari Git" "(git rm - akan terhapus di Remote)"
              _menu_opt "3" "$FG_REDUP" "Batal"
              _line "-" 50 "$FG_CYAN"
              _p "Pilih jenis penghapusan (1/2/3)"
              read -r mode_hapus

              case "$mode_hapus" in
                1)
                  _ic "Menyusutkan '${target_hapus}' kembali ke mode virtual 0-byte..."
                  # Kembalikan flag skip-worktree agar git status bersih total tanpa ' D'
                  git -C "$rp" ls-files -z -- "$target_hapus" 2>/dev/null | xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null

                  # 2. Hapus wujud fisik di penyimpanan lokal
                  rm -rf "$full_target_path"

                  # 3. Jika target adalah folder/item induk tingkat pertama (tidak mengandung '/'),
                  #    hapus juga dari virtual_manifest_file dan perbarui sparse-checkout
                  if [[ "$target_hapus" != */* ]]; then
                    sed -i "\|^${target_hapus}$|d" "$virtual_manifest_file"

                    new_sparse_list=("!/*")
                    while IFS= read -r line || [[ -n "$line" ]]; do
                      [ -n "$line" ] && new_sparse_list+=("/${line}")
                    done < "$virtual_manifest_file"

                    git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}" >/dev/null 2>&1
                  fi

                  # 4. Segarkan indeks biner secara ringan
                  git -C "$rp" update-index --refresh &>/dev/null
                  _o "'${target_hapus}' berhasil dihapus dari disk lokal tanpa jejak ' D'."
                  sleep 1
                  ;;
                2)
                  # Logika Git RM: Cek apakah file sudah pernah di-track oleh git sebelumnya
                  _ic "Menghapus permanen '${target_hapus}' dari Git & penyimpanan..."
                  if git -C "$rp" ls-files --error-unmatch "$target_hapus" &>/dev/null; then
                    # Pastikan skip-worktree dilepas dulu agar git rm berjalan mulus tanpa error
                    git -C "$rp" ls-files -z -- "$target_hapus" 2>/dev/null | xargs -0 -r git -C "$rp" update-index --no-skip-worktree -- 2>/dev/null
                    
                    # Jika sudah di-track, gunakan git rm secara rekursif untuk folder/file
                    git -C "$rp" rm -rf "$target_hapus"
                    _o "'${target_hapus}' dihapus permanen dan dicatat di staging area Git."
                  else
                    # Jika file baru (untracked) dan belum di-commit, hapus secara fisik langsung
                    rm -rf "$full_target_path"
                    _o "Berkas untracked '${target_hapus}' telah dihapus fisik."
                  fi
                  sleep 1
                  ;;
                *)
                  _c "Penghapusan dibatalkan."
                  sleep 0.8
                  ;;
              esac
            else
              _an "Pilihan tidak valid."
              sleep 1
            fi
          fi
        fi
        ;;


      [nN])
        # =====================================================================
        # FITUR: BUAT FILE BARU DI FOLDER AKTIF
        # =====================================================================
        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          continue # Kembali ke menu seleksi folder sparse, tidak jadi keluar
        fi # end if micro installed check

        # Baca list folder tingkat pertama yang saat ini aktif di manifest virtual
        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        _in "Memetakan struktur sub-folder repositori secara virtual (0-byte)..."

        # Tarik daftar sub-folder dari REMOTE (GitHub)
        # AMBIL SELURUH DAFTAR SUB-FOLDER DARI REMOTE INDEX SECARA REKURSIF
        mapfile -t remote_dirs < <(git -C "$rp" ls-tree -r -d --name-only "origin/${current_branch}" 2>/dev/null)

        # Reset array agar tidak menumpuk saat menu diulang
        valid_dirs=()

        # PERBAIKAN: Selalu masukkan pilihan "." (Root Utama) ke dalam daftar tujuan
        valid_dirs+=(".") # Selalu sediakan opsi Root Utama Repositori

        # FILTER STRUKTUR SUB-FOLDER BERDASARKAN FOLDER INDUK YANG SEDANG AKTIF
        for dir in "${remote_dirs[@]}"; do
          [ -z "$dir" ] && continue
          
          # Jika manifest kosong, hanya izinkan pembuatan file di Root '.'
          if [ ${#active_folders[@]} -eq 0 ]; then
            continue
          fi

          for active_dir in "${active_folders[@]}"; do
            # Pastikan folder/sub-folder diawali atau cocok dengan folder induk yang aktif
            # Validasi apakah sub-folder remote berada di dalam naungan folder virtual aktif
            if [[ "$dir" == "$active_dir"/* || "$dir" == "$active_dir" ]]; then
              # Mencegah duplikasi data agar daftar tetap bersih
              if [[ ! " ${valid_dirs[*]} " =~ " ${dir} " ]]; then
                valid_dirs+=("$dir")
              fi # end if duplicate check
            fi # end if check match active
          done # end for active_dir
        done # end for dir

        # Urutkan secara alfabetis agar berurutan rapi dari folder induk ke sub-sub folder terujung
        # Urutkan secara alfabetis agar terstruktur rapi
        # PERBAIKAN: Menggunakan printf '%s\n' agar pengurutan array dengan sort -u 
        # tetap akurat dan aman meskipun ada folder yang memiliki spasi
        # Untuk Blok [nN]
        mapfile -t sorted_dirs < <(printf '%s\n' "${valid_dirs[@]}" | sort -u)

        # Tampilkan daftar semua folder & sub-folder secara instan
        # TAMPILKAN SUB-MENU STRUKTUR FOLDER VIRTUAL SEUTUHNYA
        clear
        _header "PILIH STRUKTUR FOLDER TUJUAN" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"
        for i in "${!sorted_dirs[@]}"; do
          # Pilih warna latar belakang selang-seling (ganjil/genap)
          if (( i % 2 == 0 )); then
            bg_row="$BG_ZEBRA_1"
          else
            bg_row="$BG_ZEBRA_2"
          fi

          if [ "${sorted_dirs[$i]}" == "." ]; then
            printf "%b%b [%d] / (Direktori Utama / Root)\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${NC}"
          else
            # Berikan penanda visual jika folder beneran sudah menempati disk lokal
            # Berikan penanda visual jika folder sudah ada di disk lokal tanpa memutus latar zebra
            status_f_lokal=""
            if [ -d "${rp}/${sorted_dirs[$i]}" ]; then
              status_f_lokal="          ${FG_CYAN}[ lokal ready ]${FG_REDUP}${bg_row}"
            fi
            printf "%b%b [%d] /%s/%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${sorted_dirs[$i]}" "$status_f_lokal" "${NC}"
          fi
        done # end for display dirs
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor folder tempat menaruh file baru"
        read -r folder_num_pilihan

        if [[ "$folder_num_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_num_pilihan" -ge 1 ] && [ "$folder_num_pilihan" -le "${#sorted_dirs[@]}" ]; then
          idx=$((folder_num_pilihan - 1))
          target_folder_path="${sorted_dirs[$idx]}"

          _line "-" 50 "$FG_CYAN"
          if [ "$target_folder_path" == "." ]; then
            echo -e "Folder tujuan terkunci: ${YELLOW}/ (Root)${NC}"
            tree_target="origin/${current_branch}"
            local_scan_dir="$rp"
          else
            echo -e "Folder tujuan terkunci: ${FG_YELLOW}/${target_folder_path}/${NC}"
            tree_target="origin/${current_branch}:${target_folder_path}"
            local_scan_dir="${rp}/${target_folder_path}"
          fi

          # =================================================================
          # PRATINJAU ISI FILE DI DALAM FOLDER TUJUAN (REMOTE & LOKAL)
          # =================================================================
          mapfile -t r_folder_files < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" "$tree_target" 2>/dev/null | awk -F'\t' '$1=="blob" {print $2}')
          l_folder_files=()
          if [ -d "$local_scan_dir" ]; then
            mapfile -t l_folder_files < <(find "$local_scan_dir" -maxdepth 1 -type f 2>/dev/null | xargs -r -n1 basename)
          fi
          mapfile -t existing_files < <(printf '%s\n' "${r_folder_files[@]}" "${l_folder_files[@]}" | grep -v '^$' | sort -u)

          echo -e "${LIGHT_GRAY}Daftar file yang sudah ada di folder ini:${NC}"
          if [ ${#existing_files[@]} -eq 0 ]; then
            echo -e "  ${LIGHT_GRAY}(Kosong / Belum ada file)${NC}"
          else
            for ef in "${existing_files[@]}"; do
              echo -e "  ${FG_CYAN}- ${ef}${NC}"
            done
          fi
          _line "-" 50 "$FG_CYAN"

          # REKOMENDASI TERBAIK: Informatif dengan visual warna hijau pada contoh input
          _p "Masukkan NAMA FILE BARU (Contoh: " "script.py" ")"
          read -r nama_file_murni

          if [ -z "$nama_file_murni" ]; then
            _e "Nama file tidak boleh kosong!"
            sleep 1
          else
            # AMAN & OTOMATIS: Hapus tanda garis miring di awal input jika user mengetik "/u3/README.md"
            # Ini mengubah "/u3/README.md" menjadi "u3/README.md" agar penggabungan path tidak rusak
            nama_file_bersih=$(echo "$nama_file_murni" | sed 's|^/||')
            # Tentukan path lengkap berdasarkan apakah user memilih root atau subfolder
            # Formulasi penentuan jalur file virtual dinamis
            if [ "$target_folder_path" == "." ]; then
              selected_virtual_file="${nama_file_bersih}"
            else
              selected_virtual_file="${target_folder_path}/${nama_file_bersih}"
            fi
            full_new_file_path="${rp}/${selected_virtual_file}"

            # =================================================================
            # PENGAMAN: CEGAH MENIMPA FILE LOKAL ATAU FILE VIRTUAL YANG SUDAH ADA
            # =================================================================
            if [ -f "$full_new_file_path" ] || git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null | grep -qxF "$selected_virtual_file"; then
              _w "File '${selected_virtual_file}' sudah ada di repositori/lokal!"
              _p "Apakah Anda ingin membukanya untuk diedit sekarang? (y/n)"
              read -r konfirmasi_edit_ada

              if [[ "$konfirmasi_edit_ada" =~ ^[yY]$ ]]; then
                # Jika belum ada di disk lokal, ekstrak isinya dari Git (bukan file kosong)
                if [ ! -f "$full_new_file_path" ]; then
                  _ic "Mengekstrak isi asli berkas dari remote..."
                  git -C "$rp" sparse-checkout add "$selected_virtual_file" >/dev/null 2>&1
                  git -C "$rp" update-index --no-skip-worktree "$selected_virtual_file" >/dev/null 2>&1
                  if ! git -C "$rp" checkout-index --prefix="" --force -- "$selected_virtual_file" 2>/dev/null; then
                    git -C "$rp" checkout "$current_branch" -- "$selected_virtual_file" >/dev/null 2>&1
                  fi
                fi
                _in "Membuka ${selected_virtual_file} dengan micro..."
                sleep 0.5
                micro "$full_new_file_path"
              else
                _c "Pembuatan file dibatalkan agar isi file asli tidak tertimpa."
                sleep 1
              fi
              continue
            fi

            # =================================================================
            # PROSEDUR LAZY LAUNCH UNTUK FILE BARU DI FOLDER VIRTUAL
            # =================================================================
            # Pastikan folder target didaftarkan ke manifest sparse checkout asli Git
            git -C "$rp" sparse-checkout add "$selected_virtual_file" >/dev/null 2>&1

            # Mengambil path direktori induk (misal: /bash/bash_c/u3)
            new_parent_dir=$(dirname "$full_new_file_path")

            # Siapkan folder lokal fisik jika belum ada, lalu sentuh file barunya
            # JALUR UTAMA: Membuat semua folder/sub-folder baru secara otomatis jika belum ada
            mkdir -p "$new_parent_dir"

            # Membuat file kosong tiruan agar micro bisa langsung menyimpannya
            touch "$full_new_file_path"
            # =================================================================

            _in "Membuat dan membuka file baru dengan micro..."
            sleep 1.5
            micro "$full_new_file_path"
          fi # end if nama_file_murni kosong
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi # end if folder_num_pilihan valid
        ;; # Menutup opsi [nN] dengan benar


      [eE])
        # =====================================================================
        # MENU EDIT FILE (HANYA MENAMPILKAN FILE YANG SUDAH LOKAL READY)
        # =====================================================================
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue 1
        fi

        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          continue 1
        fi

        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        if [ ${#active_folders[@]} -gt 0 ]; then
          regex_pola="^($(printf '%s|' "${active_folders[@]}" | sed 's/|$//'))/"
        else
          regex_pola="^[^/]+$"
        fi

        # Ambil HANYA file fisik yang sudah eksis di disk lokal (Lokal Ready)
        valid_files=()
        if [ -d "$rp" ]; then
          mapfile -t valid_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git" | grep -E "$regex_pola" | sort -u)
        fi

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Belum ada file lokal ready di folder aktif. Gunakan opsi [a] untuk mengaktifkan file terlebih dahulu."
          _pp
          continue 1
        fi

        clear
        _header "DAFTAR FILE YANG DAPAT DIEDIT" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"
        for i in "${!valid_files[@]}"; do
          # Pilih warna latar belakang selang-seling (ganjil/genap)
          if (( i % 2 == 0 )); then
            bg_row="$BG_ZEBRA_1"
          else
            bg_row="$BG_ZEBRA_2"
          fi

          # Cetak baris dengan teks redup dan latar belakang penuh hingga ujung kanan layar (\033[K)
          printf "%b%b [%d] %s\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${valid_files[$i]}" "${NC}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor file yang ingin diedit dengan micro"
        read -r num_pilihan

        if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
          idx=$((num_pilihan - 1))
          selected_virtual_file="${valid_files[$idx]}"
          full_file_path="${rp}/${selected_virtual_file}"

          _in "Membuka ${selected_virtual_file} dengan micro..."
          sleep 0.5
          micro "$full_file_path"
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi
        ;;


      [aA])
        # =====================================================================
        # FITUR BARU: AKTIVASI / UNDUH FILE MASSAL KE LOKAL READY (TANPA MICRO)
        # =====================================================================
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue 1
        fi

        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        if [ ${#active_folders[@]} -gt 0 ]; then
          regex_pola="^($(printf '%s|' "${active_folders[@]}" | sed 's/|$//'))/"
        else
          regex_pola="^[^/]+$"
        fi

        mapfile -t remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null | grep -E "$regex_pola")
        local_files=()
        if [ -d "$rp" ]; then
          mapfile -t local_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git" | grep -E "$regex_pola")
        fi

        mapfile -t valid_files < <(printf '%s\n' "${remote_files[@]}" "${local_files[@]}" | grep -v '^$' | sort -u)

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Folder aktif Anda kosong atau belum ada folder aktif yang dipilih di menu utama."
          _pp
          continue 1
        fi

        while true; do
          clear
          _cc "========================================"
          _cc "   AKTIVASI FILE MASSAL (LOKAL READY)   "
          _cc "========================================"
          echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
          _line "=" 50 "$FG_CYAN"
          for i in "${!valid_files[@]}"; do
            # Pilih warna latar belakang selang-seling (ganjil/genap)
            if (( i % 2 == 0 )); then
              bg_row="$BG_ZEBRA_1"
            else
              bg_row="$BG_ZEBRA_2"
            fi

            status_lokal=""
            if [ -f "${rp}/${valid_files[$i]}" ]; then
              status_lokal=" ${FG_CYAN}[ lokal ready ]${FG_REDUP}${bg_row}"
            fi

            # Cetak baris dengan latar belakang penuh hingga ujung kanan layar (\033[K)
            printf "%b%b [%d] %s%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${valid_files[$i]}" "$status_lokal" "${NC}"
          done
          _cc "----------------------------------------"
          echo -e " Format Input : ${GREEN}3-5${NC} | ${GREEN}50-80${NC} | ${GREEN}1,4,7${NC}"
          echo -e " [e] ${FG_GREEN}Lanjut ke Menu Edit File Lokal Ready${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _cc "----------------------------------------"
          _p "Masukkan nomor/rentang file yang ingin diaktifkan"
          read -r input_multi

          if [[ "$input_multi" =~ ^[bB]$ ]]; then
            break
          fi

          # Jika user menekan [e] dari dalam sub-menu [a], langsung lompat ke blok edit di bawah
          if [[ "$input_multi" =~ ^[eE]$ ]]; then
            # Umpan langsung menuju menu [e]
            next_menu_action="e"
            break
          fi

          if [ -z "$input_multi" ]; then
            _an "Input tidak boleh kosong."
            sleep 1
            continue
          fi

          # Urai input rentang (contoh: 3-5) dan koma/spasi (contoh: 1,4,7)
          selected_indices=()
          input_norm=$(echo "$input_multi" | tr ',' ' ')
          for token in $input_norm; do
            if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
              start_num="${BASH_REMATCH[1]}"
              end_num="${BASH_REMATCH[2]}"
              if [ "$start_num" -le "$end_num" ]; then
                for ((n=start_num; n<=end_num; n++)); do
                  selected_indices+=("$n")
                done
              fi
            elif [[ "$token" =~ ^[0-9]+$ ]]; then
              selected_indices+=("$token")
            fi
          done

          if [ ${#selected_indices[@]} -eq 0 ]; then
            _an "Format nomor atau rentang tidak valid!"
            sleep 1.2
            continue
          fi

          # Kumpulkan daftar file unik yang valid untuk diunduh sekaligus
          files_to_fetch=()
          for num in "${selected_indices[@]}"; do
            if [ "$num" -ge 1 ] && [ "$num" -le "${#valid_files[@]}" ]; then
              idx=$((num - 1))
              cand_file="${valid_files[$idx]}"
              if [ ! -f "${rp}/${cand_file}" ]; then
                if [[ ! " ${files_to_fetch[*]} " =~ " ${cand_file} " ]]; then
                  files_to_fetch+=("$cand_file")
                fi
              fi
            fi
          done

          if [ ${#files_to_fetch[@]} -eq 0 ]; then
            _w "Seluruh nomor yang dipilih sudah berstatus [ lokal ready ] atau di luar jangkauan."
            sleep 1.5
            continue
          fi

          _ic "Mengaktifkan ${#files_to_fetch[@]} berkas ke lokal secara massal..."

          # Eksekusi massal sekaligus dalam satu gelombang (Jauh lebih cepat daripada satu per satu)
          git -C "$rp" sparse-checkout add "${files_to_fetch[@]}" >/dev/null 2>&1
          git -C "$rp" update-index --no-skip-worktree "${files_to_fetch[@]}" >/dev/null 2>&1

          if ! git -C "$rp" checkout-index --prefix="" --force -- "${files_to_fetch[@]}" 2>/dev/null; then
            git -C "$rp" checkout "$current_branch" -- "${files_to_fetch[@]}" >/dev/null 2>&1
          fi

          _o "${#files_to_fetch[@]} file berhasil diunduh dan berstatus [ lokal ready ]!"
          sleep 1.2
        done
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
          # =================================================================
          # PENYESUAIAN UTAMA: PISAHKAN TIPE DAN NAMA DARI ARRAY TARGETS
          # =================================================================
          baris_mentah="${targets[$idx]}"
          tipe_item="${baris_mentah%%	*}"
          selected_folder="${baris_mentah#*	}" # <-- Sekarang variabel ini murni nama folder/file saja!
          
          target_folder_fisik="${rp}/${selected_folder}"
        else
          _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
          _pp
          continue 1
        fi

        # CEK JIKA FOLDER TARGET SUDAH AKTIF (AKAN MELAKUKAN PROSES PENONAKTIFAN)
        # CEK AKTIF BERDASARKAN FISIK LOKAL
        # TOGGLE SYSTEM: Cek keaktifan murni berdasarkan manifes virtual batiniah skrip
        if grep -qx "${selected_folder}" "$virtual_manifest_file" 2>/dev/null; then
          _w "Item /${selected_folder} saat ini terdaftar AKTIF."

          # target_folder_fisik="${rp}/${selected_folder}"
          # Cek status modifikasi fisik lokal (jika ada file di dalam folder tersebut yang sempat diunduh)
          # 1. DETEKSI PERUBAHAN LOKAL & FILE UNTRACKED DI FOLDER SPESIFIK INI
          perubahan_folder=""
          if [ -d "$target_folder_fisik" ]; then
            perubahan_folder=$(git -C "$rp" status --porcelain=v1 --untracked-files=all "$selected_folder" 2>/dev/null | grep -v '^ D')
          fi

          if [ -n "$perubahan_folder" ]; then
            log_critical "Terdeteksi berkas UNTRACKED / MODIFIED di dalam /${selected_folder}!"
            echo -e "${RED}Berkas berikut belum di-commit dan akan HILANG PERMANEN:${NC}"
            echo "$perubahan_folder"
            echo "------------------------------------------------------"
            _pd "Apakah Anda YAKIN ingin MEMUSHNAKAN folder ini beserta isinya?"
          else
          _pd "Apakah Anda ingin MENONAKTIFKAN & HAPUS FISIK folder ini dari penyimpanan?"
          fi

          read -r konfirmasi_nonaktif
          
          if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
            _ic "Memproses penonaktifkan folder /${selected_folder}..."

            # Menghapus folder dari file manifest virtual
            # Menggunakan grep -v untuk membuang baris yang sama persis
            # tampung_manifest=$(grep -vX "${selected_folder}" "$virtual_manifest_file" 2>/dev/null)
            # echo "$tampung_manifest" > "$virtual_manifest_file"

            # Hapus nama folder dari database manifest teks internal skrip
            # Hapus dari manifest virtual teks skrip
            sed -i "/^${selected_folder}$/d" "$virtual_manifest_file"

            # Membuat daftar baru yang mengecualikan folder terpilih
            # Menyusun daftar sparse checkout baru dengan mengecualikan folder terpilih
            # Menyusun kembali aturan sparse checkout git asli berdasarkan manifes yang tersisa
            new_sparse_list=()
            # Pastikan README.md atau rules default dasar tetap ada
            new_sparse_list+=("!/*") # Aturan pengaman dasar default

            while IFS= read -r line || [[ -n "$line" ]]; do
              [ -n "$line" ] && new_sparse_list+=("/${line}")
            done < "$virtual_manifest_file"

            # Terapkan ulang daftar sparse-checkout yang baru
            if git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}"; then
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan dari Git!"
            else
              _e "Gagal memperbarui sparse-checkout list."
              sleep 1.5
              continue 1
            fi

            # Seketika hapus folder fisik lokal jika ada
            # 3. Musnahkan wujud fisik sisa download di disk lokal (kembali ke 0-byte sejati)
            # if [ -d "$target_folder_fisik" ]; then
            #   _ic "Memusnahkan direktori fisik lokal secara otomatis..."
            #   rm -rf "$target_folder_fisik"
            #   _o "Folder fisik '${selected_folder}' berhasil dihapus sepenuhnya."
            # fi

            # =================================================================
            # KOREKSI & OPTIMASI PARALEL KILAT UNTUK PEMBERSIHAN DISK
            # =================================================================
            _ic "Membersihkan metadata indeks dan wujud fisik sisa secara aman..."

            # =================================================================
            # KOREKSI & OPTIMASI PARALEL KILAT UNTUK PEMBERSIHAN DISK & INDEKS
            # =================================================================
            _ic "Mengembalikan flag skip-worktree dan membersihkan fisik sisa secara aman..."

            # A. Kembalikan bit skip-worktree untuk seluruh file di dalam folder ini
            #    agar Git tidak menganggapnya terhapus (' D') setelah rm -rf
            git -C "$rp" ls-files -z -- "$selected_folder" 2>/dev/null | \
              xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null
            
            # C. Gunakan pembacaan internal pohon kerja instan (Sangat Ringan dibanding read-tree -mu)
            # C. Segarkan indeks biner secara ringan
            git -C "$rp" update-index --refresh &>/dev/null
            
            # D. Hapus folder fisik lokal jika tersisa untuk mengembalikan status 0-byte sejati
            if [ -d "$target_folder_fisik" ]; then
              rm -rf "$target_folder_fisik"
            fi
            
            # C. ELIMINASI: Menghapus perintah 'git gc --prune=now' yang memicu hang/freeze berat di Termux
            # Basis data Git dibiarkan dikompresi berkala secara alami saja.

            _o "Item /${selected_folder} berhasil disusutkan kembali ke status 0-byte sejati!"
            sleep 1

          else
            _c "Tindakan dibatalkan. Folder tetap aktif aman."
            sleep 0.5
          fi
        else
          # Jika belum aktif, lakukan proses ADD seperti semula
          # JIKA FOLDER BELUM AKTIF (AKAN MELAKUKAN PROSES AKTIVASI / ADD FOLDER)
          # PERBAIKAN: Jika belum ada, cukup daftarkan polanya secara virtual (TANPA git checkout penuh)
          # PROSEDUR AKTIVASI VIRTUAL (0-BYTE DISK SEJATI)
          _ic "Mendaftarkan /${selected_folder} ke manifest virtual memori..."
          # Cukup catat namanya di file manifest batiniah (DISK TETAP KOSONG / 0-BYTE)
          if echo "${selected_folder}" >> "$virtual_manifest_file"; then
            _o "Berhasil ditambahkan ke daftar pantau virtual!"
            _ic "Gunakan opsi [e] untuk menjelajahi dan mengedit file secara On-Demand."
            sleep 1.5
          else
            _e "Gagal menambahkan folder ke virtual_manifest_file."
            _pp
          fi
        fi # end if target selection check

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




























      [vV])
        # =====================================================================
        # MANAJEMEN BRANCH VIRTUAL INSTAN (PINDAH, BUAT BARU, HAPUS - 0-BYTE)
        # =====================================================================
        while true; do
          clear
          _header "MANAJEMEN BRANCH VIRTUAL (0-BYTE)" 50 "$FG_CYAN" "$FG_GREEN"
          head_short=$(git -C "$rp" rev-parse --short HEAD 2>/dev/null)
          head_msg=$(git -C "$rp" log -1 --format="%s" 2>/dev/null)
          echo -e "Repositori   : ${FG_YELLOW}${r}${NC}"
          echo -e "Branch Aktif : ${GREEN}${current_branch}${NC} (${FG_CYAN}${head_short}${NC} - ${head_msg})"
          _line "=" 50 "$FG_CYAN"

          # Tampilkan semua branch lokal yang ada
          mapfile -t semua_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
          echo -e "${LIGHT_GRAY}Daftar Branch Lokal:${NC}"
          for i in "${!semua_branch[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
            br_sha=$(git -C "$rp" rev-parse --short "refs/heads/${semua_branch[$i]}" 2>/dev/null)
            if [ "${semua_branch[$i]}" == "$current_branch" ]; then
              printf "%b%b [%d] %-20s (%s) %b[ AKTIF ]%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "$FG_GREEN" "${FG_REDUP}${bg_row}" "${NC}"
            else
              printf "%b%b [%d] %-20s (%s)\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          _menu_opt "c" "$FG_GREEN"  "Buat Branch Baru Virtual" "(0-Byte update-ref)"
          _menu_opt "r" "$FG_YELLOW" "Reset Pointer Branch Aktif" "(Pilih dari Riwayat Commit)"
          _menu_opt "x" "$RED"       "Hapus Branch Lokal" "(git branch -D)"
          _menu_opt "b" "$FG_CYAN"   "Kembali ke Menu Sparse-Checkout"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor branch untuk pindah, atau opsi [c/r/x/b]"
          read -r br_aksi

          [[ "$br_aksi" =~ ^[bB]$ ]] && break


          # --- OPSI [x]: HAPUS BRANCH LOKAL ---
          if [[ "$br_aksi" =~ ^[xX]$ ]]; then
            _p "Masukkan nomor branch yang ingin dihapus"
            read -r del_br_num
            if [[ "$del_br_num" =~ ^[0-9]+$ ]] && [ "$del_br_num" -ge 1 ] && [ "$del_br_num" -le "${#semua_branch[@]}" ]; then
              target_del_br="${semua_branch[$((del_br_num - 1))]}"
              if [ "$target_del_br" == "$current_branch" ]; then
                _e "Tidak dapat menghapus branch yang sedang aktif!"
                sleep 1.5
              else
                _pd "Yakin ingin menghapus branch '${target_del_br}' secara permanen?"
                read -r konf_del_br
                if [[ "$konf_del_br" =~ ^[yY]$ ]]; then
                  git -C "$rp" branch -D "$target_del_br" >/dev/null 2>&1
                  _o "Branch '${target_del_br}' berhasil dihapus."
                  sleep 1
                fi
              fi
            else
              _an "Nomor branch tidak valid."
              sleep 1
            fi
            continue
          fi

          # --- OPSI [r]: RESET POINTER BRANCH AKTIF KE COMMIT TERTENTU (0-BYTE) ---
          if [[ "$br_aksi" =~ ^[rR]$ ]]; then
            clear
            _header "RESET POINTER BRANCH [${current_branch}]" 50 "$FG_CYAN" "$FG_YELLOW"
            echo -e "Riwayat 15 Commit Terakhir pada ${GREEN}${current_branch}${NC}:"
            _line "=" 50 "$FG_CYAN"

            mapfile -t log_commits < <(git -C "$rp" log -n 15 --format="%H|%h|%s|%cr" 2>/dev/null)
            for idx_c in "${!log_commits[@]}"; do
              IFS='|' read -r full_c short_c msg_c time_c <<< "${log_commits[$idx_c]}"
              bg_row="$BG_ZEBRA_1"
              (( idx_c % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b [%2d] %b%s%b - %-22s (%s)\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((idx_c+1)) "$FG_CYAN" "$short_c" "${FG_REDUP}${bg_row}" "${msg_c:0:22}" "$time_c" "${NC}"
            done

            _line "-" 50 "$FG_CYAN"
            _p "Pilih nomor commit (1-${#log_commits[@]}), ketik hash manual, atau 'b' batal"
            read -r pilih_commit

            [[ "$pilih_commit" =~ ^[bB]$ ]] && continue

            target_reset_sha=""
            if [[ "$pilih_commit" =~ ^[0-9]+$ ]] && [ "$pilih_commit" -ge 1 ] && [ "$pilih_commit" -le "${#log_commits[@]}" ]; then
              target_reset_sha=$(echo "${log_commits[$((pilih_commit - 1))]}" | cut -d'|' -f1)
            elif [ -n "$pilih_commit" ]; then
              target_reset_sha=$(git -C "$rp" rev-parse --verify "${pilih_commit}^{commit}" 2>/dev/null)
            fi

            if [ -z "$target_reset_sha" ]; then
              _e "Commit target tidak valid atau tidak ditemukan!"
              sleep 1.5
              continue
            fi

            _line "-" 50 "$FG_YELLOW"
            echo -e "Branch '${GREEN}${current_branch}${NC}' akan diputar balik ke: ${FG_CYAN}${target_reset_sha:0:7}${NC}"
            _p "Buat branch backup otomatis dari posisi HEAD saat ini sebelum reset? (y/n)"
            read -r buat_auto_backup
            if [[ "$buat_auto_backup" =~ ^[yY]$ ]]; then
              default_bk="backup_${current_branch}_$(date +%Y%m%d_%H%M)"
              _p "Nama branch backup (Enter = ${default_bk})"
              read -r nama_bk_input
              nama_bk_final=$(echo "${nama_bk_input:-$default_bk}" | tr -d '[:space:]')
              if git -C "$rp" update-ref "refs/heads/${nama_bk_final}" HEAD 2>/dev/null; then
                _o "Backup aman tersimpan di branch '${nama_bk_final}'!"
              else
                _e "Gagal membuat branch backup. Reset dibatalkan demi keamanan."
                sleep 1.5
                continue
              fi
            fi

            _pd "Konfirmasi: Reset pointer '${current_branch}' ke ${target_reset_sha:0:7} sekarang?"
            read -r konf_reset
            if [[ "$konf_reset" =~ ^[yY]$ ]]; then
              _ic "Memutar ulang referensi branch & menyinkronkan indeks biner 0-byte..."

              # 1. Pindahkan pointer branch secara biner (0-byte)
              git -C "$rp" update-ref "refs/heads/${current_branch}" "$target_reset_sha"

              # 2. Baca ulang pohon file target ke indeks dan pertahankan bit skip-worktree
              git -C "$rp" read-tree "$target_reset_sha"
              git -C "$rp" ls-files -z 2>/dev/null | \
                xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null

              # 3. Jika ada file fisik aktif di disk (tercatat di manifest), sinkronkan isinya
              if [ -s "$virtual_manifest_file" ]; then
                while IFS= read -r act_f || [[ -n "$act_f" ]]; do
                  [ -z "$act_f" ] && continue
                  if git -C "$rp" cat-file -e "${target_reset_sha}:${act_f}" 2>/dev/null; then
                    git -C "$rp" ls-files -z -- "$act_f" 2>/dev/null | \
                      xargs -0 -r git -C "$rp" update-index --no-skip-worktree -- 2>/dev/null
                    git -C "$rp" checkout "$target_reset_sha" -- "$act_f" 2>/dev/null
                  else
                    rm -rf "${rp}/${act_f}"
                    sed -i "\|^${act_f}$|d" "$virtual_manifest_file"
                  fi
                done < "$virtual_manifest_file"
              fi

              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

              _o "Pointer '${current_branch}' berhasil di-reset ke ${target_reset_sha:0:7} (0-Byte & tanpa jejak ' D')!"
              sleep 1.5
            else
              _c "Reset dibatalkan."
              sleep 0.8
            fi
            continue
          fi

          # --- OPSI [c]: BUAT BRANCH BARU 0-BYTE ---
          if [[ "$br_aksi" =~ ^[cC]$ ]]; then
            _line "-" 50 "$FG_CYAN"
            _p "Masukkan nama branch baru (Contoh: backup_u330 atau dev)"
            read -r nama_br_baru
            nama_br_clean=$(echo "$nama_br_baru" | tr -d '[:space:]')

            if [ -z "$nama_br_clean" ]; then
              _e "Nama branch tidak boleh kosong!"
              sleep 1
              continue
            fi

            if git -C "$rp" show-ref --verify --quiet "refs/heads/${nama_br_clean}"; then
              _w "Branch '${nama_br_clean}' sudah ada!"
              sleep 1.2
              continue
            fi

            _p "Titik awal branch (Kosongkan/Enter = HEAD saat ini, atau ketik hash commit)"
            read -r base_commit
            [ -z "$base_commit" ] && base_commit="HEAD"

            target_sha=$(git -C "$rp" rev-parse --verify "${base_commit}^{commit}" 2>/dev/null)
            if [ -z "$target_sha" ]; then
              _e "Referensi commit '${base_commit}' tidak ditemukan!"
              sleep 1.5
              continue
            fi

            # Tulis referensi branch baru langsung secara biner (0-Byte disk)
            if git -C "$rp" update-ref "refs/heads/${nama_br_clean}" "$target_sha" 2>/dev/null; then
              _o "Branch '${nama_br_clean}' berhasil dibuat pada commit ${target_sha:0:7} (0-Byte)!"
              _p "Apakah ingin langsung pindah ke branch '${nama_br_clean}'? (y/n)"
              read -r langsung_pindah
              if [[ "$langsung_pindah" =~ ^[yY]$ ]]; then
                git -C "$rp" symbolic-ref HEAD "refs/heads/${nama_br_clean}" 2>/dev/null
                current_branch="$nama_br_clean"
                git -C "$rp" read-tree "$current_branch" 2>/dev/null
                git -C "$rp" update-index --refresh &>/dev/null
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "Berhasil pindah ke '${current_branch}'."
                sleep 1
                break
              fi
            else
              _e "Gagal membuat branch '${nama_br_clean}'."
            fi
            sleep 1.2
            continue
          fi

          # --- PINDAH KE BRANCH TERPILIH BERDASARKAN ANGKA ---
          if [[ "$br_aksi" =~ ^[0-9]+$ ]] && [ "$br_aksi" -ge 1 ] && [ "$br_aksi" -le "${#semua_branch[@]}" ]; then
            target_branch_clean="${semua_branch[$((br_aksi - 1))]}"
            if [ "$target_branch_clean" == "$current_branch" ]; then
              _w "Anda sudah berada di branch '${current_branch}'."
              sleep 1
              continue
            fi

            _ic "Mengalihkan pointer HEAD secara virtual ke refs/heads/${target_branch_clean}..."
            if git -C "$rp" symbolic-ref HEAD "refs/heads/${target_branch_clean}" 2>/dev/null; then
              current_branch="$target_branch_clean"
              git -C "$rp" read-tree "$current_branch" 2>/dev/null
              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
              _o "HEAD berhasil dialihkan secara instan ke branch: ${current_branch}"
              sleep 1
              break
            else
              _e "Gagal mengalihkan branch via symbolic-ref!"
              sleep 1.2
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue
        ;;








---

qs: 
qs: 
```bash
==================================================
   PILIH FILE DARI [backup_main_20261124_0229]
==================================================
Target Branch: main | Mode: 0-Byte Biner
==================================================
 [1] bash/bash_c/README.md [Ubah/M]
 [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A]
 [3] git/README.md [Ubah/M]
 [4] go_r/README.md [Baru/A]
 [5] rs_r/README.md [Ubah/M]
--------------------------------------------------
 [d] Lihat Diff Baris File Sebelum Injeksi
 [b] Kembali ke Menu Sparse-Checkout
==================================================
[~] Pilih nomor file untuk diinjeksi (0-Byte): 3
Pesan otomatis: u323
[~] Tekan [Enter] untuk 'u323', atau ketik pesan manual:

setelah menekan enter di bagian `[~] Tekan [Enter] untuk 'u323', atau ketik pesan manual:`, apakah bisa langsung menampilkan perubahan, atau adakah cara yang lebih baik untuk bash main.sh

```

---

aa: 
Bisa. Anda dapat menambahkan ringkasan perubahan (git show --stat dan git diff berwarna) tepat setelah commit berhasil dibuat, lalu memberi jeda singkat (atau tombol lanjut cepat) sebelum layar di-clear untuk kembali ke daftar file berikutnya.

Selain itu, agar alur kerja di menu [i] jauh lebih cepat dan informatif, berikut 3 peningkatan terbaik yang bisa langsung Anda terapkan di blok [iI] pada main.sh:

---

## 1. Tampilkan Ringkasan Commit & Diff Otomatis Setelah Injeksi Berhasil
Ganti bagian akhir setelah new_commit_id berhasil dibuat (sekitar baris 740 di main.sh) dengan blok berikut agar langsung mencetak hash commit baru, pesan commit, statistik file (--stat), serta diff baris (+/-) tepat sebelum kembali ke daftar:
```bash
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

                _line "=" 50 "$FG_GREEN"
                _o "BERHASIL: '${target_file}' diinjeksi ke [${pesan_injeksi}] (${new_commit_id:0:7})"
                _line "-" 50 "$FG_CYAN"
                # Tampilkan ringkasan stat & pratinjau perubahan baris commit yang baru dibuat
                git -C "$rp" show --stat --color=always "$new_commit_id"
                _line "-" 50 "$FG_CYAN"
                git -C "$rp" show --format="" --color=always "$new_commit_id" | head -n 25
                _line "=" 50 "$FG_GREEN"
                _p "Tekan [Enter] untuk lanjut memilih file berikutnya"
                read -r _
              else

```
> (Penggunaan | head -n 25 menjaga tampilan tetap ringkas di layar Termux meskipun file yang diinjeksi memiliki ratusan baris).

---

## 2. Pratinjau Diff Otomatis Sebelum Menanyakan Pesan Commit (Lebih Aman)
Daripada harus mengetik d terlebih dahulu lalu mengetik ulang nomor file, Anda bisa membuat skrip langsung menampilkan pratinjau git diff singkat begitu nomor file dipilih (misal nomor 3), baru menanyakan konfirmasi pesan commit u323:
```bash
          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            target_file=$(echo "${diff_files[$((f_pilihan - 1))]}" | cut -f2-)

            # --- PRATINJAU OTOMATIS PERUBAHAN FILE TERPILIH ---
            _line "-" 50 "$FG_CYAN"
            echo -e "Pratinjau perubahan pada: ${FG_YELLOW}${target_file}${NC}"
            git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_file" | head -n 20
            _line "-" 50 "$FG_CYAN"

```
Dengan cara ini:
- Begitu Anda mengetik 3, Anda langsung melihat isi perubahan pada git/README.md di layar tanpa langkah tambahan.
- Jika sesuai, tinggal tekan Enter untuk langsung meng-commit sebagai u323. Jika ragu, Anda bisa langsung mengetik b atau Ctrl+C (atau tambahkan opsi n untuk batal).

---

## 3. Mendukung Input Banyak File Sekaligus (1,3,5 atau all)
Jika suatu saat Anda memiliki 10 file di branch backup dan ingin meng-commit semuanya secara berurutan (u323, u324, u325, dst.) tanpa harus menekan Enter berkali-kali, Anda bisa menambahkan dukungan input koma/rentang (seperti pada fitur [a]) di menu [i]:
- Ketik 3 → injeksi 1 file (u323).
- Ketik 5,4,3,2,1 → otomatis menginjeksi ke-5 file secara berurutan sesuai urutan angka yang Anda ketik (5 jadi u323, 4 jadi u324, 3 jadi u325, 2 jadi u326, 1 jadi u327) dalam sekali jalan!

---

qa: 
Apakah Anda ingin saya buatkan kode blok [iI] lengkap yang sudah menggabungkan pratinjau diff otomatis, tampilan hasil commit, dan input urutan angka banyak sekaligus (5,4,3,2,1) agar siap langsung ditempel ke main.sh?
---

qs: 
[4] go_r/README.md [Baru/A]

apakah bisa beri tanda saja setelah begitu nomor file dipilih

```

aa: 
Bisa. Anda dapat menambahkan penanda visual instan (seperti << TERPILIH / ikon ▶ dengan sorotan warna hijau/kuning) tepat pada baris nomor file yang Anda pilih begitu angka dimasukkan, sehingga Anda langsung melihat konfirmasi item mana yang sedang diproses sebelum menekan Enter untuk pesan commit.

## Pembaruan pada Blok [iI] di main.sh
Ganti bagian pemilihan nomor file di dalam while true; do pada blok [iI] (sekitar baris 705) dengan kode berikut agar layar langsung me-refresh daftar dan menandai baris file yang sedang dipilih:
```bash
          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            selected_idx=$((f_pilihan - 1))
            target_file=$(echo "${diff_files[$selected_idx]}" | cut -f2-)

            # Gambar ulang daftar dengan tanda sorotan pada nomor yang baru dipilih
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)

              if [ "$i" -eq "$selected_idx" ]; then
                # Baris yang sedang dipilih diberi tanda panah ▶ & label [ TERPILIH ]
                printf "%b%b ▶ [%d] %s %b[ TERPILIH ]%b\033[K%b\n" \
                  "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$FG_YELLOW" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              else
                bg_row="$BG_ZEBRA_1"
                (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
                if [ "$st_code" == "A" ]; then
                  badge="${FG_GREEN}[Baru/A]${FG_REDUP}${bg_row}"
                else
                  badge="${FG_YELLOW}[Ubah/M]${FG_REDUP}${bg_row}"
                fi
                printf "%b%b   [%d] %s %b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$badge" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            # Auto-increment pesan commit (u323, u324, dst.)
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            echo -e "File terpilih  : ${FG_YELLOW}${target_file}${NC}"
            echo -e "Pesan otomatis : ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', ketik pesan manual, atau 'b' batal"
            read -r pesan_injeksi

            [[ "$pesan_injeksi" =~ ^[bB]$ ]] && continue
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

```

---

## Tampilan Visual Setelah Nomor 4 Dipilih
Begitu Anda mengetik 4 dan menekan Enter, layar langsung berubah menjadi seperti ini:
```bash
==================================================
   PILIH FILE DARI [backup_main_20261124_0229]
==================================================
Target Branch: main | Mode: 0-Byte Biner
==================================================
   [1] bash/bash_c/README.md [Ubah/M]
   [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A]
   [3] git/README.md [Ubah/M]
 ▶ [4] go_r/README.md [ TERPILIH ]
   [5] rs_r/README.md [Ubah/M]
==================================================
File terpilih  : go_r/README.md
Pesan otomatis : u324
[~] Tekan [Enter] untuk 'u324', ketik pesan manual, atau 'b' batal:

```

- Baris ▶ [4] go_r/README.md [ TERPILIH ] langsung tersorot hijau-kuning.
- Tersedia juga pengaman ketik b jika Anda salah menekan nomor file dan ingin membatalkannya sebelum commit dibuat.

---

qa: 
Apakah Anda juga ingin menampilkan jumlah baris perubahan (+X -Y) di sebelah label [Baru/A] / [Ubah/M] pada setiap baris daftar file di menu [i]?

---

qc: 
ingin menampilkan jumlah baris perubahan (+X -Y) di sebelah label [Baru/A] / [Ubah/M] pada setiap baris daftar file di menu [i]?

---

aa: 
Anda dapat menambahkan statistik jumlah baris (+X -Y) langsung di samping label [Baru/A] atau [Ubah/M] menggunakan git diff --numstat. Perintah ini membandingkan blob biner langsung di database .git/objects sehingga tetap 100% 0-byte di disk.

## Pembaruan Lengkap Blok [iI] di main.sh
Ganti seluruh blok [iI]) ... ;; Anda dengan kode berikut yang sudah mengintegrasikan statistik baris (+X -Y) serta sorotan ▶ [ TERPILIH ]:
```bash
      [iI])
        # =====================================================================
        # FITUR BARU: INJEKSI OBJEK FILE 0-BYTE DARI BRANCH LAIN (CACHEINFO)
        # =====================================================================
        clear
        _header "INJEKSI FILE 0-BYTE ANTAR BRANCH" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"

        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          continue 1
        fi

        echo -e "${LIGHT_GRAY}Daftar branch sumber yang tersedia:${NC}"
        for i in "${!daftar_branch[@]}"; do
          printf " [%d] %s\n" $((i+1)) "${daftar_branch[$i]}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor branch sumber (atau ketik 'b' untuk batal)"
        read -r br_pilihan

        [[ "$br_pilihan" =~ ^[bB]$ ]] && continue 1

        if ! [[ "$br_pilihan" =~ ^[0-9]+$ ]] || [ "$br_pilihan" -lt 1 ] || [ "$br_pilihan" -gt "${#daftar_branch[@]}" ]; then
          _an "Pilihan branch tidak valid."
          sleep 1
          continue 1
        fi

        source_branch="${daftar_branch[$((br_pilihan - 1))]}"

        # 2. Ambil daftar file yang bertambah (A) atau berubah (M) di branch sumber
        mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        if [ ${#diff_files[@]} -eq 0 ]; then
          _w "Tidak ada perbedaan file (A/M) antara '${current_branch}' dan '${source_branch}'."
          _pp
          continue 1
        fi

        while true; do
          # Muat ulang daftar perbedaan & statistik baris (+X -Y) secara 0-byte
          mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)
          [ ${#diff_files[@]} -eq 0 ] && break

          declare -A file_numstat=()
          while IFS=$'\t' read -r add_cnt del_cnt stat_path; do
            [ -n "$stat_path" ] && file_numstat["$stat_path"]="+${add_cnt} -${del_cnt}"
          done < <(git -C "$rp" diff --numstat --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

          clear
          _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
          _line "=" 50 "$FG_CYAN"

          for i in "${!diff_files[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"

            st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
            f_path=$(echo "${diff_files[$i]}" | cut -f2-)
            stat_label="${file_numstat[$f_path]:-+0 -0}"

            if [ "$st_code" == "A" ]; then
              badge="${FG_GREEN}[Baru/A] ${FG_CYAN}(${stat_label})${FG_REDUP}${bg_row}"
            else
              badge="${FG_YELLOW}[Ubah/M] ${FG_CYAN}(${stat_label})${FG_REDUP}${bg_row}"
            fi

            printf "%b%b   [%d] %s %b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$badge" "${NC}"
          done

          _line "-" 50 "$FG_CYAN"
          echo -e " [d] ${FG_CYAN}Lihat Diff Baris File Sebelum Injeksi${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor file untuk diinjeksi (0-Byte)"
          read -r f_pilihan

          [[ "$f_pilihan" =~ ^[bB]$ ]] && break

          # Opsi cepat melihat diff baris sebelum memutuskan injeksi
          if [[ "$f_pilihan" =~ ^[dD]$ ]]; then
            _p "Masukkan nomor file yang ingin dilihat diff-nya"
            read -r d_num
            if [[ "$d_num" =~ ^[0-9]+$ ]] && [ "$d_num" -ge 1 ] && [ "$d_num" -le "${#diff_files[@]}" ]; then
              target_diff_file=$(echo "${diff_files[$((d_num - 1))]}" | cut -f2-)
              clear
              git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_diff_file"
              _line "=" 50 "$FG_CYAN"
              _p "Tekan [Enter] untuk kembali"
              read -r _
            fi
            continue
          fi

          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            selected_idx=$((f_pilihan - 1))
            target_file=$(echo "${diff_files[$selected_idx]}" | cut -f2-)

            # Gambar ulang daftar dengan tanda sorotan pada nomor yang baru dipilih
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)
              stat_label="${file_numstat[$f_path]:-+0 -0}"

              if [ "$i" -eq "$selected_idx" ]; then
                printf "%b%b ▶ [%d] %s %b[ TERPILIH ] (%s)%b\033[K%b\n" \
                  "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$FG_YELLOW" "$stat_label" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              else
                bg_row="$BG_ZEBRA_1"
                (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
                if [ "$st_code" == "A" ]; then
                  badge="${FG_GREEN}[Baru/A] ${FG_CYAN}(${stat_label})${FG_REDUP}${bg_row}"
                else
                  badge="${FG_YELLOW}[Ubah/M] ${FG_CYAN}(${stat_label})${FG_REDUP}${bg_row}"
                fi
                printf "%b%b   [%d] %s %b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$badge" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            # Auto-increment pesan commit (u323, u324, dst.)
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            echo -e "File terpilih  : ${FG_YELLOW}${target_file}${NC}"
            echo -e "Pesan otomatis : ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', ketik pesan manual, atau 'b' batal"
            read -r pesan_injeksi

            [[ "$pesan_injeksi" =~ ^[bB]$ ]] && continue
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

            _ic "Menyuntikkan '${target_file}' ke indeks biner & pohon komit..."

            # 4. Suntikkan ke index dengan --cacheinfo & --skip-worktree agar 0-byte di disk
            git -C "$rp" update-index --add --cacheinfo "${obj_mode},${obj_sha},${target_file}" 2>/dev/null
            git -C "$rp" update-index --skip-worktree -- "$target_file" 2>/dev/null

            tree_id=$(git -C "$rp" write-tree 2>/dev/null)
            parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)

            if [ -n "$tree_id" ] && [ -n "$parent_id" ]; then
              new_commit_id=$(echo "$pesan_injeksi" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

                _o "BERHASIL: '${target_file}' diinjeksi ke komit [${pesan_injeksi}] (0-Byte Disk)!"
                sleep 1.2
              else
                _e "Gagal membuat objek commit-tree (periksa SSH signing key)."
                sleep 1.5
              fi
            else
              _e "Gagal menulis tree biner Git."
              sleep 1.5
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue 1
        ;;

```

---

## Hasil Tampilan Akhir di Terminal
- Daftar Awal:
```bash
   [1] bash/bash_c/README.md [Ubah/M] (+12 -4)
   [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A] (+85 -0)
   [3] git/README.md [Ubah/M] (+19 -3)
   [4] go_r/README.md [Baru/A] (+64 -0)
   [5] rs_r/README.md [Ubah/M] (+27 -5)

```
- Begitu Nomor 4 Dipilih:
```bash
   [1] bash/bash_c/README.md [Ubah/M] (+12 -4)
   [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A] (+85 -0)
   [3] git/README.md [Ubah/M] (+19 -3)
 ▶ [4] go_r/README.md [ TERPILIH ] (+64 -0)
   [5] rs_r/README.md [Ubah/M] (+27 -5)

```

---

qa: 
Apakah ada bagian lain dari main.sh yang ingin Anda rapikan atau tambahkan (misalnya dukungan --force-with-lease di opsi [q] setelah melakukan reset branch)?

---

qs: 
apakah hasilnya seperti ini  ▶ [4] go_r/README.md [Ubah/M] [ TERPILIH ] (+64 -0) agar jelas, atau ada yang jauh lebih baik

---

aa: 
Ya, format ▶ [4] go_r/README.md [Baru/A] [ TERPILIH ] (+64 -0) (atau [Ubah/M]) jauh lebih jelas karena tidak menghilangkan status asli file ([Baru/A] vs [Ubah/M]) saat sedang disorot.

Namun, agar lebih rapi secara visual dan langsung menunjukkan identitas commit yang akan dibuat, struktur terbaik yang lebih informatif adalah:
▶ [4] go_r/README.md [Baru/A] (+64 -0) ◀ [ TARGET: u324 ]

## Mengapa Format Ini Lebih Baik?
- Menjaga Konsistensi Kolom: Urutan asli [Baru/A] (+64 -0) tetap sejajar dengan baris lainnya sehingga mata tidak perlu mencari ulang status file.
- Langsung Menampilkan Nomor Commit (u324): Begitu nomor dipilih, Anda langsung melihat nomor commit yang akan dikunci (◀ [ TARGET: u324 ]) tepat di ujung baris file tersebut.

---

## Potongan Kode Perbaikan pada Blok Sorotan (if [ "$i" -eq "$selected_idx" ])
Cukup perbarui bagian hitung auto_msg dan printf pada blok gambar ulang di menu [i] menjadi seperti berikut:
```bash
            # Hitung auto_msg lebih awal agar bisa ditampilkan langsung pada sorotan baris
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            # Gambar ulang daftar dengan tanda sorotan lengkap (Status + Statistik + Target Commit)
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)
              stat_label="${file_numstat[$f_path]:-+0 -0}"

              if [ "$st_code" == "A" ]; then
                status_tag="${FG_GREEN}[Baru/A]"
              else
                status_tag="${FG_YELLOW}[Ubah/M]"
              fi

              if [ "$i" -eq "$selected_idx" ]; then
                printf "%b%b ▶ [%d] %s %b %b(%s) %b◀ [ TARGET: %s ]%b\033[K%b\n" \
                  "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_YELLOW" "$auto_msg" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              else
                bg_row="$BG_ZEBRA_1"
                (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
                printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                  "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

```


## Contoh Hasil Tampilan di Layar
```bash
   [1] bash/bash_c/README.md [Ubah/M] (+12 -4)
   [2] bash/bash_c/bclo_v3_8_fix/README.md [Baru/A] (+85 -0)
   [3] git/README.md [Ubah/M] (+19 -3)
 ▶ [4] go_r/README.md [Baru/A] (+64 -0) ◀ [ TARGET: u324 ]
   [5] rs_r/README.md [Ubah/M] (+27 -5)

```

---

qa: 
Apakah Anda ingin menerapkan gaya sorotan ▶ ... ◀ [ TARGET ] dan statistik baris yang sama ke sub-menu lain di main.sh (seperti menu [d] Hapus File atau [e] Edit File)?

---

qs: 
Kalo bisa usai  ▶ [4] go_r/README.md [Baru/A] (+64 -0) dan memberi pesan, saat mengulang kembali loop kalo bisa jangan hilang melainkan ditandai sertakan pesanya juga atau ada cara yang lebih baik biar jelas

---

aa: 
Bisa. Daripada menghilangkan item dari daftar setelah diinjeksi, jauh lebih baik jika daftar item tetap utuh (tetap 5 baris dengan nomor urut tetap [1]–[5]), dan setiap file yang sudah selesai diinjeksi langsung ditandai dengan ✓ [ SELESAI: u323 (a1b2c3d) ] di sebelah barisnya.

## Mengapa Cara Ini Jauh Lebih Baik?
- Nomor Urut Tidak Bergeser: Nomor [1] sampai [5] tetap konsisten dari awal sampai akhir, sehingga Anda tidak salah pencet saat memilih file berikutnya.
- Jejak Audit Terlihat Jelas: Anda bisa langsung melihat file mana saja yang sudah diinjeksi, pesan commit-nya (u323, u324, dst.), dan hash commit pendeknya di satu layar.
- Perlindungan Injeksi Ganda: Jika nomor yang sudah berstatus ✓ [ SELESAI ] dipilih lagi, skrip otomatis memberi peringatan agar tidak membuat commit duplikat.

---

## Kode Lengkap Blok [iI] di main.sh
Ganti seluruh blok [iI]) ... ;; Anda dengan kode berikut:
```bash
      [iI])
        # =====================================================================
        # FITUR BARU: INJEKSI OBJEK FILE 0-BYTE DARI BRANCH LAIN (CACHEINFO)
        # =====================================================================
        clear
        _header "INJEKSI FILE 0-BYTE ANTAR BRANCH" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"

        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          continue 1
        fi

        echo -e "${LIGHT_GRAY}Daftar branch sumber yang tersedia:${NC}"
        for i in "${!daftar_branch[@]}"; do
          printf " [%d] %s\n" $((i+1)) "${daftar_branch[$i]}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor branch sumber (atau ketik 'b' untuk batal)"
        read -r br_pilihan

        [[ "$br_pilihan" =~ ^[bB]$ ]] && continue 1

        if ! [[ "$br_pilihan" =~ ^[0-9]+$ ]] || [ "$br_pilihan" -lt 1 ] || [ "$br_pilihan" -gt "${#daftar_branch[@]}" ]; then
          _an "Pilihan branch tidak valid."
          sleep 1
          continue 1
        fi

        source_branch="${daftar_branch[$((br_pilihan - 1))]}"

        # 2. Ambil daftar file awal sekali saja agar nomor urut [1..N] tetap terkunci
        mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        if [ ${#diff_files[@]} -eq 0 ]; then
          _w "Tidak ada perbedaan file (A/M) antara '${current_branch}' dan '${source_branch}'."
          _pp
          continue 1
        fi

        # Simpan statistik (+X -Y) dan catatan riwayat injeksi sesi ini di memori
        declare -A file_numstat=()
        declare -A injected_log=()
        while IFS=$'\t' read -r add_cnt del_cnt stat_path; do
          [ -n "$stat_path" ] && file_numstat["$stat_path"]="+${add_cnt} -${del_cnt}"
        done < <(git -C "$rp" diff --numstat --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        while true; do
          clear
          _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
          _line "=" 50 "$FG_CYAN"

          for i in "${!diff_files[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"

            st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
            f_path=$(echo "${diff_files[$i]}" | cut -f2-)
            stat_label="${file_numstat[$f_path]:-+0 -0}"

            if [ "$st_code" == "A" ]; then
              status_tag="${FG_GREEN}[Baru/A]"
            else
              status_tag="${FG_YELLOW}[Ubah/M]"
            fi

            if [ -n "${injected_log[$f_path]}" ]; then
              # Tandai item yang sudah selesai diinjeksi beserta pesan commit-nya
              printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
            else
              printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          echo -e " [d] ${FG_CYAN}Lihat Diff Baris File Sebelum Injeksi${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor file untuk diinjeksi (0-Byte)"
          read -r f_pilihan

          [[ "$f_pilihan" =~ ^[bB]$ ]] && break

          # Opsi cepat melihat diff baris sebelum memutuskan injeksi
          if [[ "$f_pilihan" =~ ^[dD]$ ]]; then
            _p "Masukkan nomor file yang ingin dilihat diff-nya"
            read -r d_num
            if [[ "$d_num" =~ ^[0-9]+$ ]] && [ "$d_num" -ge 1 ] && [ "$d_num" -le "${#diff_files[@]}" ]; then
              target_diff_file=$(echo "${diff_files[$((d_num - 1))]}" | cut -f2-)
              clear
              git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_diff_file"
              _line "=" 50 "$FG_CYAN"
              _p "Tekan [Enter] untuk kembali"
              read -r _
            fi
            continue
          fi

          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            selected_idx=$((f_pilihan - 1))
            target_file=$(echo "${diff_files[$selected_idx]}" | cut -f2-)

            # Cegah injeksi ulang jika file sudah berstatus SELESAI
            if [ -n "${injected_log[$target_file]}" ]; then
              _w "File '${target_file}' sudah diinjeksi (${injected_log[$target_file]})!"
              sleep 1.2
              continue
            fi

            # Hitung auto_msg lebih awal untuk ditampilkan pada sorotan baris
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            # Gambar ulang daftar dengan tanda sorotan lengkap pada nomor yang dipilih
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)
              stat_label="${file_numstat[$f_path]:-+0 -0}"

              if [ "$st_code" == "A" ]; then
                status_tag="${FG_GREEN}[Baru/A]"
              else
                status_tag="${FG_YELLOW}[Ubah/M]"
              fi

              if [ "$i" -eq "$selected_idx" ]; then
                printf "%b%b ▶ [%d] %s %b %b(%s) %b◀ [ TARGET: %s ]%b\033[K%b\n" \
                  "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_YELLOW" "$auto_msg" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              elif [ -n "${injected_log[$f_path]}" ]; then
                bg_row="$BG_ZEBRA_1"
                (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
                printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                  "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
              else
                bg_row="$BG_ZEBRA_1"
                (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
                printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                  "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            echo -e "File terpilih  : ${FG_YELLOW}${target_file}${NC}"
            echo -e "Pesan otomatis : ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', ketik pesan manual, atau 'b' batal"
            read -r pesan_injeksi

            [[ "$pesan_injeksi" =~ ^[bB]$ ]] && continue
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

            _ic "Menyuntikkan '${target_file}' ke indeks biner & pohon komit..."

            # 4. Suntikkan ke index dengan --cacheinfo & --skip-worktree agar 0-byte di disk
            git -C "$rp" update-index --add --cacheinfo "${obj_mode},${obj_sha},${target_file}" 2>/dev/null
            git -C "$rp" update-index --skip-worktree -- "$target_file" 2>/dev/null

            tree_id=$(git -C "$rp" write-tree 2>/dev/null)
            parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)

            if [ -n "$tree_id" ] && [ -n "$parent_id" ]; then
              new_commit_id=$(echo "$pesan_injeksi" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Simpan status selesai ke array sesi agar tetap tampil di loop berikutnya
                injected_log["$target_file"]="${pesan_injeksi} (${new_commit_id:0:7})"

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "BERHASIL: '${target_file}' diinjeksi ke komit [${pesan_injeksi}] (0-Byte Disk)!"
                sleep 1
              else
                _e "Gagal membuat objek commit-tree (periksa SSH signing key)."
                sleep 1.5
              fi
            else
              _e "Gagal menulis tree biner Git."
              sleep 1.5
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue 1
        ;;

```

- `setelah diubah bagian [iI])`
```bash
      [iI])
        # =====================================================================
        # FITUR BARU: INJEKSI OBJEK FILE 0-BYTE DARI BRANCH LAIN (CACHEINFO)
        # =====================================================================
        clear
        _header "INJEKSI FILE 0-BYTE ANTAR BRANCH" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"

        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          continue 1
        fi

        echo -e "${LIGHT_GRAY}Daftar branch sumber yang tersedia:${NC}"
        for i in "${!daftar_branch[@]}"; do
          printf " [%d] %s\n" $((i+1)) "${daftar_branch[$i]}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor branch sumber (atau ketik 'b' untuk batal)"
        read -r br_pilihan

        [[ "$br_pilihan" =~ ^[bB]$ ]] && continue 1

        if ! [[ "$br_pilihan" =~ ^[0-9]+$ ]] || [ "$br_pilihan" -lt 1 ] || [ "$br_pilihan" -gt "${#daftar_branch[@]}" ]; then
          _an "Pilihan branch tidak valid."
          sleep 1
          continue 1
        fi

        source_branch="${daftar_branch[$((br_pilihan - 1))]}"

        # 2. Ambil daftar file yang bertambah (A) atau berubah (M) di branch sumber
        # 2. Ambil daftar file awal sekali saja agar nomor urut [1..N] tetap terkunci
        mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        if [ ${#diff_files[@]} -eq 0 ]; then
          _w "Tidak ada perbedaan file (A/M) antara '${current_branch}' dan '${source_branch}'."
          _pp
          continue 1
        fi

        # Simpan statistik (+X -Y) dan catatan riwayat injeksi sesi ini di memori
        declare -A file_numstat=()
        declare -A injected_log=()
        while IFS=$'\t' read -r add_cnt del_cnt stat_path; do
          [ -n "$stat_path" ] && file_numstat["$stat_path"]="+${add_cnt} -${del_cnt}"
        done < <(git -C "$rp" diff --numstat --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        while true; do
          clear
          _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
          _line "=" 50 "$FG_CYAN"

          for i in "${!diff_files[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"

            st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
            f_path=$(echo "${diff_files[$i]}" | cut -f2-)
            stat_label="${file_numstat[$f_path]:-+0 -0}"

            if [ "$st_code" == "A" ]; then
              status_tag="${FG_GREEN}[Baru/A]"
            else
              status_tag="${FG_YELLOW}[Ubah/M]"
            fi

            if [ -n "${injected_log[$f_path]}" ]; then
              # Tandai item yang sudah selesai diinjeksi beserta pesan commit-nya
              printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
            else
              printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          echo -e " [d] ${FG_CYAN}Lihat Diff Baris File Sebelum Injeksi${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor file untuk diinjeksi (0-Byte)"
          read -r f_pilihan

          [[ "$f_pilihan" =~ ^[bB]$ ]] && break

          # Opsi cepat melihat diff baris sebelum memutuskan injeksi
          if [[ "$f_pilihan" =~ ^[dD]$ ]]; then
            _p "Masukkan nomor file yang ingin dilihat diff-nya"
            read -r d_num
            if [[ "$d_num" =~ ^[0-9]+$ ]] && [ "$d_num" -ge 1 ] && [ "$d_num" -le "${#diff_files[@]}" ]; then
              target_diff_file=$(echo "${diff_files[$((d_num - 1))]}" | cut -f2-)
              clear
              git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_diff_file"
              _line "=" 50 "$FG_CYAN"
              _p "Tekan [Enter] untuk kembali"
              read -r _
            fi
            continue
          fi

          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            selected_idx=$((f_pilihan - 1))
            target_file=$(echo "${diff_files[$selected_idx]}" | cut -f2-)

            # Cegah injeksi ulang jika file sudah berstatus SELESAI
            if [ -n "${injected_log[$target_file]}" ]; then
              _w "File '${target_file}' sudah diinjeksi (${injected_log[$target_file]})!"
              sleep 1.2
              continue
            fi

            # Hitung auto_msg lebih awal untuk ditampilkan pada sorotan baris
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            # Gambar ulang daftar dengan tanda sorotan pada nomor yang baru dipilih
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)
              stat_label="${file_numstat[$f_path]:-+0 -0}"

              if [ "$st_code" == "A" ]; then
                status_tag="${FG_GREEN}[Baru/A]"
              else
                status_tag="${FG_YELLOW}[Ubah/M]"
              fi

              if [ "$i" -eq "$selected_idx" ]; then
                # Baris yang sedang dipilih diberi tanda panah ▶ & label [ TERPILIH ]
printf "%b%b ▶ [%d] %s %b %b(%s) %b◀ [ TARGET: %s ]%b\033[K%b\n" \
                "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_YELLOW" "$auto_msg" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              elif [ -n "${injected_log[$f_path]}" ]; then
              bg_row="$BG_ZEBRA_1"
              (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
              else
              bg_row="$BG_ZEBRA_1"
              (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            echo -e "File terpilih  : ${FG_YELLOW}${target_file}${NC}"
            echo -e "Pesan otomatis: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', ketik pesan manual, atau 'b' batal"
            read -r pesan_injeksi

            [[ "$pesan_injeksi" =~ ^[bB]$ ]] && continue
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

            _ic "Menyuntikkan '${target_file}' ke indeks biner & pohon komit..."

            # 4. Suntikkan ke index dengan --cacheinfo & --skip-worktree agar 0-byte di disk
            git -C "$rp" update-index --add --cacheinfo "${obj_mode},${obj_sha},${target_file}" 2>/dev/null
            git -C "$rp" update-index --skip-worktree -- "$target_file" 2>/dev/null

            tree_id=$(git -C "$rp" write-tree 2>/dev/null)
            parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)

            if [ -n "$tree_id" ] && [ -n "$parent_id" ]; then
              new_commit_id=$(echo "$pesan_injeksi" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Simpan status selesai ke array sesi agar tetap tampil di loop berikutnya
                injected_log["$target_file"]="${pesan_injeksi} (${new_commit_id:0:7})"

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

                _line "=" 50 "$FG_GREEN"
                _o "BERHASIL: '${target_file}' diinjeksi ke [${pesan_injeksi}] (${new_commit_id:0:7})"
                _line "-" 50 "$FG_CYAN"

                _p "Tekan [Enter] untuk lanjut memilih file berikutnya"
                read -r _
              else
                _e "Gagal membuat objek commit-tree (periksa SSH signing key)."
                sleep 1.5
              fi
            else
              _e "Gagal menulis tree biner Git."
              sleep 1.5
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue 1
        ;;



```

---

### Ilustrasi Alur Tampilan di Layar Anda
1. **Saat Memilih Nomor `4`:**
```text
    bash/bash_c/README.md [Ubah/M] (+12 -4)
    bash/bash_c/bclo_v3_8_fix/README.md [Baru/A] (+85 -0)
    git/README.md [Ubah/M] (+19 -3)
  ▶ go_r/README.md [Baru/A] (+64 -0) ◀ [ TARGET: u323 ]
    rs_r/README.md [Ubah/M] (+27 -5)

```
2. Setelah Menekan Enter & Loop Berulang (Nomor 4 Tetap Ada dengan Penanda ✓):
```bash
   bash/bash_c/README.md [Ubah/M] (+12 -4)
   bash/bash_c/bclo_v3_8_fix/README.md [Baru/A] (+85 -0)
   git/README.md [Ubah/M] (+19 -3)
 ✓ go_r/README.md [Baru/A] (+64 -0) [ SELESAI: u323 (8f4c12a) ]
   rs_r/README.md [Ubah/M] (+27 -5)

```

---

qa: 
Apakah Anda juga ingin menambahkan opsi all (injeksi otomatis semua file yang belum SELESAI secara berurutan u323, u324, dst.) di menu [i]?

---




- `main.sh`
```bash
#!/bin/bash

GREEN='\033[0;32m';
YELLOW='\033[0;33m';
BLUE='\033[0;34m';
CYAN='\033[0;36m';
LIGHT_GRAY='\033[0;37m';

BG_ZEBRA_1='\033[48;2;18;22;28m';
BG_ZEBRA_2='\033[48;2;28;34;43m';

# =====================================================================
# FUNGSI UNIVERSAL PENGHITUNG WARNA ANSI 24-BIT (TRUECOLOR)
# Format Pemanggilan:
#   hitung_warna_rgb <mode> <persen> <bg_r> <bg_g> <bg_b> <fg_r> <fg_g> <fg_b>
#   - mode: "fg" (38 = warna teks) atau "bg" (48 = warna latar belakang)
# =====================================================================
hitung_warna_rgb() {
  local mode="$1"
  local persen="${2:-50}"
  local r1="$3" g1="$4" b1="$5"
  local r2="$6" g2="$7" b2="$8"

  local kode_ansi=38
  [[ "$mode" == "bg" ]] && kode_ansi=48

  # Rumus interpolasi linier tunggal untuk semua kanal warna
  local r=$(( r1 + (r2 - r1) * persen / 100 ))
  local g=$(( g1 + (g2 - g1) * persen / 100 ))
  local b=$(( b1 + (b2 - b1) * persen / 100 ))

  printf '\033[%d;2;%d;%d;%dm' "$kode_ansi" "$r" "$g" "$b"
}

# =====================================================================
# KONFIGURASI PALET WARNA DINAMIS (CUKUP UBAH ANGKA PERSENTASE)
# =====================================================================
SHOW_COLOR_PREVIEW=0   # 1 = Tampilkan pratinjau warna | 0 = Sembunyikan

zebra_gelap=2     # Persentase kecerahan baris zebra genap
zebra_terang=7    # Persentase kecerahan baris zebra ganjil
persen_redup=80   # Persentase kecerahan teks nama file
persen_cyan=55    # Persentase kecerahan label [ lokal ready ]
persen_green=55        # Persentase kecerahan label [ daftar aktif / sudah aktif ]
persen_yellow=80

# Generate seluruh variabel warna dari satu fungsi universal
BG_ZEBRA_1=$(hitung_warna_rgb "bg" "$zebra_gelap"   10 12 16  220 230 245)
BG_ZEBRA_2=$(hitung_warna_rgb "bg" "$zebra_terang"  10 12 16  220 230 245)
FG_REDUP=$(hitung_warna_rgb   "fg" "$persen_redup"  23 28 35  220 230 245)
FG_CYAN=$(hitung_warna_rgb    "fg" "$persen_cyan"   23 28 35    0 235 255)
FG_GREEN=$(hitung_warna_rgb   "fg" "$persen_green"  23 28 35   35 235 130)
FG_YELLOW=$(hitung_warna_rgb  "fg" "$persen_yellow" 23 28 35  245 200 65)


# Fungsi helper mencetak garis pemisah horizontal langsung ke terminal (tanpa _cc)
# Penggunaan:
#   _line                     -> 40 karakter '=' warna FG_REDUP (bawaan)
#   _line "-"                 -> 40 karakter '-' warna FG_REDUP
#   _line "=" 40 "$FG_CYAN"   -> 40 karakter '=' warna FG_CYAN
_line() {
  local char="${1:-=}"
  local len="${2:-40}"
  local color="${3:-$FG_REDUP}"
  local line_str

  printf -v line_str "%*s" "$len" ""
  printf "%b%s%b\n" "$color" "${line_str// /$char}" "$NC"
}


# Fungsi helper mencetak header dengan posisi judul otomatis di tengah (center)
# Penggunaan:
#   _header "PILIH REPOSITORI UTAMA"
#   _header "PILIH REPOSITORI UTAMA" 50
#   _header "PILIH REPOSITORI UTAMA" 50 "$FG_CYAN" "$FG_GREEN"
_header() {
  local title="$1"
  local len="${2:-40}"               # Panjang garis (default 40, bebas diubah)
  local line_color="${3:-$FG_CYAN}"  # Warna garis (default Cyan)
  local title_color="${4:-$NC}"      # Warna teks judul (default Putih Terminal)

  local title_len=${#title}
  local pad=0

  # Hitung spasi kiri agar posisi teks berada tepat di tengah panjang garis
  if (( len > title_len )); then
    pad=$(( (len - title_len) / 2 ))
  fi

  _line "=" "$len" "$line_color"
  printf "%*s%b%s%b\n" "$pad" "" "$title_color" "$title" "$NC"
  _line "=" "$len" "$line_color"
}

_menu_opt() {
  local key="$1"
  local color="$2"
  local label="$3"
  local extra="${4:-}" # Opsional: teks tambahan di ujung kanan dengan warna redup

  if [ -n "$extra" ]; then
    printf "%b [%s] %b%s %b%s%b\n" "$FG_REDUP" "$key" "$color" "$label" "$FG_REDUP" "$extra" "$NC"
  else
    printf "%b [%s] %b%s%b\n" "$FG_REDUP" "$key" "$color" "$label" "$NC"
  fi
}

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
  _header "PILIH REPOSITORI UTAMA" 50 "$FG_CYAN" "$FG_GREEN"
  _cc "Daftar Repositori Terpantau (Format: owner/repo):"

  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Pilih warna latar belakang selang-seling (ganjil/genap)
      if (( i % 2 == 0 )); then
        bg_row="$BG_ZEBRA_1"
      else
        bg_row="$BG_ZEBRA_2"
      fi

      # Cek apakah folder repo lokal fisik sudah ada berdasarkan nama reponya saja
      owner_name="${valid_repos[$i]%%/*}"
      local_repo_name="${valid_repos[$i]#*/}"

      status_str=" %b[ daftar aktif ]%b"
      status_args=("${FG_GREEN}" "${FG_REDUP}${bg_row}")

      if [ -d "${PWD}/${owner_name}/${local_repo_name}/.git" ]; then
        status_str="${status_str} %b[ lokal aktif ]%b"
        status_args+=("${FG_CYAN}" "${FG_REDUP}${bg_row}")
      fi
      # Cetak baris dengan teks redup dan latar belakang penuh hingga ujung kanan layar (\033[K)
      printf "%b%b [%d] %-30s${status_str}\033[K%b\n" \
        "$bg_row" "$FG_REDUP" $((i+1)) "${valid_repos[$i]}" "${status_args[@]}" "${NC}"
    done
  fi

  _line "-" 50 "$FG_CYAN"
  _menu_opt "t" "$FG_GREEN" "Tambah Repositori Baru"
  _menu_opt "h" "$RED" "Hapus Repo dari Daftar" "rp.txt"
  _menu_opt "f" "$YELLOW" "Hanya Hapus Folder Fisik Lokal"
  _menu_opt "q" "$RED" "Keluar dari Skrip"
  _line "=" 50 "$FG_CYAN"
  _p "Masukkan pilihan Anda"
  read -r repo_pilihan

  # OPSI KELUAR
  if [[ "$repo_pilihan" =~ ^[qQ]$ ]]; then
    _an "Proses dibatalkan. Keluar dari skrip."
    exit 0
  fi

  # OPSI TAMBAH REPO BARU (Mendukung input owner/repo secara fleksibel)
  if [[ "$repo_pilihan" =~ ^[tT]$ ]]; then
    _line "-" 50 "$FG_CYAN"
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
    sleep 0.5
    # break <-- HAPUS ATAU KOMENTARI BARIS INI AGAR LOOP MENU UTAMA TETAP HIDUP
  else
    _a "Pilihan tidak valid! Masukkan nomor repo, [t], [h], [f], atau [q]."
    sleep 1.5
    continue 1 # <-- KOREKSI: Melompat kembali ke atas jika salah input angka
  fi



  # Menentukan jalur kerja repositori yang dipilih di dalam direktori aktif saat ini
  # Menggunakan direktori aktif saat skrip dijalankan (pwd) + nama_owner + nama_repo
  rp="${PWD}/${o}/${r}"

  # =====================================================================
  # TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
  # =====================================================================
  current_branch="main" # Nilai default awal

  if [ -d "$rp/.git" ]; then
    # KOREKSI PLUMBING: Membaca referensi branch aktif langsung dari memori HEAD secara instan
    detected_ref=$(git -C "$rp" symbolic-ref --short HEAD 2>/dev/null)
    
    # PERBAIKAN: Memeriksa apakah $detected_ref tidak kosong
    if [ -n "$detected_ref" ]; then
      current_branch="$detected_ref"
      _o "Sukses Branch saat ini terdeteksi" "$current_branch"
    else
      # Fallback aman jika repositori dalam kondisi detached HEAD
      current_branch=$(git -C "$rp" rev-parse --abbrev-ref HEAD 2>/dev/null)
      _w "HEAD terlepas (detached). Mengunci branch ke" "$current_branch"
    fi # end if detected_branch
  else
    # PERBAIKAN: Menangani kondisi jika direktori .git tidak ada
    # Pengecekan awal dilewati jika folder belum di-clone
    _ic "Menyiapkan alur kloning untuk direktori baru..."
    # exit 1  <-- HAPUS ATAU KOMENTARI BARIS INI
  fi # end if git dir check

  sleep 0.5

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

    # 1. Deteksi otomatis cabang remote jika 'main' tidak ditemukan (misal: 'master')
    if ! git -C "$rp" show-ref --verify --quiet "refs/remotes/origin/${current_branch}"; then
      remote_head=$(git -C "$rp" symbolic-ref --short "refs/remotes/origin/HEAD" 2>/dev/null)
      if [ -n "$remote_head" ]; then
        current_branch="${remote_head#origin/}"
      fi
    fi

    mode_file="${rp}/.git/index_init_mode"

    # 2. Eksekusi 3 Baris Plumbing dengan Fallback ke Checkout Standar jika gagal
    if git -C "$rp" show-ref --verify --quiet "refs/remotes/origin/${current_branch}"; then
      if git -C "$rp" update-ref "refs/heads/${current_branch}" "refs/remotes/origin/${current_branch}" 2>/dev/null && \
         git -C "$rp" symbolic-ref HEAD "refs/heads/${current_branch}" 2>/dev/null && \
         git -C "$rp" read-tree --reset -u "HEAD" &>/dev/null; then
        _o "Inisialisasi cabang '${current_branch}' & indeks biner berhasil."
        echo "BINER" > "$mode_file"
      else
        _w "Metode plumbing gagal. Menjalankan fallback checkout standar..."
        git -C "$rp" checkout -q "$current_branch" &>/dev/null
        echo "FALLBACK" > "$mode_file"
      fi
    else
      # Pengaman jika repositori remote masih 0-commit (kosong total)
      _w "Repositori remote kosong (belum ada commit). Menyiapkan HEAD awal..."
      git -C "$rp" symbolic-ref HEAD "refs/heads/${current_branch}" 2>/dev/null
      echo "KOSONG" > "$mode_file"
    fi
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
          continue 1
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

  # Baca status metode inisialisasi indeks yang tersimpan
  saved_mode=$(cat "${rp}/.git/index_init_mode" 2>/dev/null)
  case "$saved_mode" in
    "FALLBACK") status_init_index="${FG_YELLOW}[Mode: Fallback Checkout]${NC}" ;;
    "KOSONG")   status_init_index="${LIGHT_GRAY}[Mode: HEAD Kosong]${NC}" ;;
    *)          status_init_index="${FG_CYAN}[Mode: Indeks Biner]${NC}" ;;
  esac

  # =====================================================================
  # MODUL REKOMENDASI: VIRTUAL MANIFEST-BASED LAZY LOADING (0-BYTE DISK)
  # =====================================================================

  # Array internal pelacak manifest virtual yang diaktifkan user via menu utama
  # Menggunakan file sementara atau variabel array state lokal
  virtual_manifest_file="${rp}/.git/virtual_sparse_manifest"
  touch "$virtual_manifest_file"

  # Membaca seluruh isi root (folder & file) tingkat pertama dari remote
  # Membaca daftar item tingkat pertama dari indeks remote (0-byte fisik)
  # =================================================================
  # OPTIMASI EKSTREM: REKAM TIPE DAN NAMA SEKALIGUS DALAM SATU TEMBAKAN
  # =================================================================
  # Mengambil tipe (tree/blob) dan nama file, dipisahkan dengan karakter TAB
  mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
  if [ ${#targets[@]} -eq 0 ]; then
      _w "Repositori saat ini tidak memiliki folder (hanya berisi file root)."
      sleep 1.5
  fi

  # =====================================================================
  # FITUR AUTO-HEALING: SINKRONISASI ULANG MANIFEST JIKA TERHAPUS (TREE & BLOB)
  # =====================================================================
  if [ -d "$rp" ]; then
    for baris_data in "${targets[@]}"; do
      # 1. Pisahkan tipe dan nama item berdasarkan karakter TAB di memori RAM
      tipe_item="${baris_data%%	*}"
      target_item="${baris_data#*	}"

      # 2. Inisialisasi bendera status keberadaan fisik di disk lokal Termux
      item_ditemukan_di_disk=0

      # 3. Jalankan pengecekan spesifik berdasarkan tipe manifes biner Git
      if [ "$tipe_item" == "tree" ]; then
        # Cek apakah folder fisik benar-benar eksis di penyimpanan
        if [ -d "${rp}/${target_item}" ]; then
          item_ditemukan_di_disk=1
        fi
      elif [ "$tipe_item" == "blob" ]; then
        # Cek apakah file fisik benar-benar eksis di penyimpanan
        if [ -f "${rp}/${target_item}" ]; then
          item_ditemukan_di_disk=1
        fi
      fi

      # 4. Sinkronisasi Otomatis: Jika fisik ada tapi belum tercatat di manifest virtual
      if [ "$item_ditemukan_di_disk" -eq 1 ]; then
        # Menyesuaikan dengan format penyimpanan manifest Anda (misal hanya menyimpan nama bersih $target_item)
        if ! grep -qx "${target_item}" "$virtual_manifest_file" 2>/dev/null; then
          echo "${target_item}" >> "$virtual_manifest_file"
        fi
      fi
    done
  fi
  # =====================================================================

  next_menu_action=""

  # MENU INTERAKTIF SELEKSI FOLDER
  while true; do # Loop Sparse (Tingkat 1 / Posisi saat ini)
    clear
    _header "SISTEM SELEKSI SPARSE-CHECKOUT" 50 "$FG_CYAN" "$FG_GREEN"
    _cc "Daftar folder otomatis dari Remote:"
    echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
    echo -e "Status Indeks: ${status_init_index}";

    # =====================================================================
    # PRATINJAU TERPADU PALET WARNA DINAMIS (VISUAL + KODE ANSI MENTAH)
    # =====================================================================
    if [ "${SHOW_COLOR_PREVIEW:-0}" -eq 1 ]; then
      raw_bg1="${BG_ZEBRA_1//$'\e'/\\033}"
      raw_bg2="${BG_ZEBRA_2//$'\e'/\\033}"
      raw_redup="${FG_REDUP//$'\e'/\\033}"
      raw_cyan="${FG_CYAN//$'\e'/\\033}"
      raw_green="${FG_GREEN//$'\e'/\\033}"

      _line "-" 50 "$FG_CYAN"
      printf " [BG 1] %b%b Baris Genap %b | %b%s%b\n" "$BG_ZEBRA_1" "$FG_REDUP" "$NC" "$LIGHT_GRAY" "$raw_bg1" "$NC"
      printf " [BG 2] %b%b Baris Ganjil%b | %b%s%b\n" "$BG_ZEBRA_2" "$FG_REDUP" "$NC" "$LIGHT_GRAY" "$raw_bg2" "$NC"
      printf " [FG 1] %bTeks Redup (%d%%)%b | %b%s%b\n" "$FG_REDUP" "$persen_redup" "$NC" "$LIGHT_GRAY" "$raw_redup" "$NC"
      printf " [FG 2] %b[ lokal ready ] (%d%%)%b | %b%s%b\n" "$FG_CYAN" "$persen_cyan" "$NC" "$LIGHT_GRAY" "$raw_cyan" "$NC"
      printf " [FG 3] %b[ daftar aktif ] (%d%%)%b | %b%s%b\n" "$FG_GREEN" "$persen_green" "$NC" "$LIGHT_GRAY" "$raw_green" "$NC"
      _line "-" 50 "$FG_CYAN"
    fi

    # GANTI BLOK LOOP CETAK MENU (SEKITAR BARIS 439-447) DENGAN INI:
    for i in "${!targets[@]}"; do
      # Ambil baris data mentah (Contoh: "tree	src", "blob	README.md", atau "commit	submodule_dir")
      baris_data="${targets[$i]}"

      # Trik Bash Internal: Pisahkan tipe dan nama berdasarkan karakter TAB tanpa panggil perintah eksternal
      tipe_item="${baris_data%%	*}"
      item="${baris_data#*	}"
      
      # UX ASLI: Status aktif dibaca jika item tercantum dalam manifest virtual memori
      status_aktif=""
      # Jalankan pengecekan indikator aktif (Gunakan logika cek manifest status Anda yang sudah ada)
      # Misal variabel $status_aktif Anda dikelola di sini...
      is_aktif=0
      if grep -qx "${item}" "$virtual_manifest_file" 2>/dev/null; then
        status_aktif=" ${FG_GREEN}[ sudah aktif ]"
        is_aktif=1
      fi

      # 2. VALIDASI STATUS COMMIT REAL-TIME (HANYA JIKA ITEM AKTIF DI DISK)
      status_commit=""
      target_jalur_fisik="${rp}/${item}"

      if [ "$is_aktif" -eq 1 ] && [ -e "$target_jalur_fisik" ]; then
        # Membaca manifes biner Git status secara kilat untuk file/folder spesifik ini
        # --porcelain menghasilkan output kosong jika file/folder 100% sinkron dan bersih
        perubahan_lokal=$(git -C "$rp" status --porcelain=v1 --untracked-files=all "$item" 2>/dev/null | grep -v '^ D')
        
        
        if [ -n "$perubahan_lokal" ]; then
          # Jika ada modifikasi yang belum di-commit di lokal
          status_commit="${FG_YELLOW} (Ada Perubahan Lokal)"
        else
          # Jika bersih, cek apakah HEAD lokal berbeda dengan pelacak remote origin
          diff_check=$(git -C "$rp" rev-list --count "origin/${current_branch}..HEAD" -- "$item" 2>/dev/null)
          if [ "${diff_check:-0}" -gt 0 ]; then
            status_commit="${BLUE} (Butuh Sinkronisasi)"
          else
            status_commit="${FG_REDUP} (Sinkron)"
          fi
        fi
      fi

      # 3. CETAK MENU INTERAKTIF BERDASARKAN SPESIFIKASI TIPE OBJEK GIT
      case "$tipe_item" in
        "tree")
          # Jika folder, cetak dengan tanda kurung / di depannya
          # Format untuk Folder (Garis miring di depan)
          printf "%b [%d] /%-12s%b%b%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$NC"
          ;;
        "blob")
          # Jika file di root (blob), cetak nama filenya saja secara bersih
          # Format untuk Berkas Reguler (Bersih tanpa tanda tambahan)
          printf "%b [%d]  %-12s%b%b%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$NC"
          ;;
        "commit")
          # Format khusus untuk Git Submodule / Nested Commit Object
          printf "%b [%d] @%-12s%b%b ${MAGENTA}[Submodule]${NC}\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit"
          ;;
        *)
          # Cadangan untuk tipe data asing lainnya
          printf "%b [%d] ?%-12s%b%b (%s)%b\n" "$FG_REDUP" $((i+1)) "$item" "$status_aktif" "$status_commit" "$tipe_item" "$NC"
          ;;
      esac
    done # end for targets

    _line "-" 50 "$FG_CYAN"
    _menu_opt "a" "$FG_CYAN"  "Aktifkan File Massal" "(Unduh ke Lokal Ready)"
    _menu_opt "e" "$FG_GREEN" "Edit File Lokal Ready" "(Buka di Micro)"
    _menu_opt "n" "$FG_GREEN" "Buat File Baru di Folder Aktif"
    _menu_opt "d" "$RED"      "Hapus File atau Sub-Folder" "(Git RM)"
    _menu_opt "v" "$FG_CYAN"  "Pindah Branch Virtual Instan" "(symbolic-ref)"
    _menu_opt "s" "$FG_CYAN"  "Injeksi Submodule Virtual 0-Byte" "(Objek Commit)"
    _menu_opt "i" "$FG_GREEN" "Injeksi File 0-Byte dari Branch Lain" "(cacheinfo)"
    _menu_opt "q" "$RED"      "Keluar & Terapkan Perubahan" "(Checkout)"
    _menu_opt "b" "$RED"      "Kembali ke Menu Pilih Repositori Utama"
    _line "=" 50 "$FG_CYAN"
    if [ -n "$next_menu_action" ]; then
      pilihan="$next_menu_action"
      next_menu_action=""
    else
      _p "Masukkan pilihan Anda"
      read -r pilihan
    fi

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
        # LOGIKA KELUAR [q] (PORCELAIN FILTER & PLUMBING SINKRONISASI SEJATI)
        # =====================================================================
        _ic "Memeriksa integritas berkas lokal sebelum keluar..."

        # 1. Ambil status porcelain tanpa file eksternal untracked agar cepat
        raw_status=$(git -C "$rp" status --porcelain=v1 --untracked-files=all 2>/dev/null)
        perubahan_lokal=""

        # 2. Saring status D palsu dari efek samping penyusutan sparse-checkout
        while IFS= read -r line; do
          [ -z "$line" ] && continue
          
          status_code="${line:0:2}"
          file_path="${line:3}"

          if [[ "$status_code" =~ "D" ]]; then
            folder_induk="${file_path%%/*}"
            if ! grep -qx "${folder_induk}" "$virtual_manifest_file" 2>/dev/null; then
              continue
            fi

            # Abaikan jika kode adalah ' D' (file virtual 0-byte yang memang belum diunduh)
            if [[ "$status_code" == " D" ]]; then
              continue
            fi
          fi
          perubahan_lokal+="${line}\n"
        done <<< "$raw_status"

        # 3. KEPUTUSAN KELUAR BERDASARKAN HASIL FILTER SEJATI
        if [ -n "$perubahan_lokal" ] && [ "$perubahan_lokal" != "\n" ]; then
          _w "Peringatan: Ada berkas yang benar-benar telah Anda ubah/hapus secara lokal!"
          echo -e "${FG_YELLOW}${perubahan_lokal}${NC}"
          _line "-" 50 "$FG_REDUP"
          echo "Pilih tindakan Anda:"
          _menu_opt "1" "$FG_GREEN" "Simpan perubahan (Commit secara lokal)"
          echo -e " [2] ${RED}Abaikan & Paksa update (Buang hasil editan Anda)${NC}"
          echo -e " [3] ${FG_YELLOW}Abaikan & Batalkan Keluar (Kembali ke menu)${NC}"
          _line "-" 50 "$FG_CYAN"
          _p "Pilihan Anda (1/2/3)"
          read -r aksi_keluar

          if [ "$aksi_keluar" == "1" ]; then
            log_critical "Tindakan ini akan merekam perubahan ke Git!"
            _p "Ketik 'EXPLICIT' (huruf besar) untuk melanjutkan konfirmasi"
            read -r verifikasi_aman

            if [ "$verifikasi_aman" != "EXPLICIT" ]; then
              _an "Verifikasi gagal! Tindakan dibatalkan."
              sleep 2
              continue
            fi

            # Auto-Increment Pesan Commit
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              next_num=$((last_num + 1))
              auto_msg="u${next_num}"
            else
              auto_msg="u1"
            fi

            echo -e "Pesan otomatis yang disarankan: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk auto-msg, atau ketik pesan manual"
            read -r pesan_commit
            [ -z "$pesan_commit" ] && pesan_commit="$auto_msg"

            _ic "Merekam perubahan ke staging area..."
            git -C "$rp" add --sparse .

            _ic "Menghasilkan objek komit langsung di memori..."
            tree_id=$(git -C "$rp" write-tree 2>/dev/null)

            if [ -n "$tree_id" ]; then
              parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)
              if [ -n "$parent_id" ]; then
                new_commit_id=$(echo "$pesan_commit" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              else
                new_commit_id=$(echo "$pesan_commit" | git -C "$rp" commit-tree "$tree_id" -S 2>/dev/null)
              fi

              if [ -n "$new_commit_id" ]; then
                # Geser pointer cabang lokal aktif
                git -C "$rp" update-ref "refs/heads/$current_branch" "$new_commit_id"
                _o "Perubahan BERHASIL disuntikkan langsung ke commit binar lokal!"

                # 2. PAKSA REFERENSI TRACKING REMOTE TETAP BERADA PADA POSISI KOMIT LAMA (PARENT)
                # Ini adalah trik utama agar Git menyadari lokal Anda berada "Lebih Maju" daripada server
                # 2. PAKSA REFERENSI TRACKING UPSTREAM SERVER MUNDUR SATU LANGKAH KE PARENT COMMIT
                # Ini memaksa Git menyadari bahwa komit lokal Anda sekarang "Lebih Maju" daripada server
                git -C "$rp" update-ref "refs/remotes/origin/$current_branch" "$parent_id"

                # PENYELARASAN KRITIS AREA INDEKS MEMORI (AUTO-HEAL)
                # 3. Sinkronisasi biner pohon kerja indeks & refresh cache metadata instan
                git -C "$rp" read-tree "$new_commit_id"

                git -C "$rp" update-index --refresh &>/dev/null

                # 4. AMANKAN RACE CONDITION: Berikan jeda mikro agar I/O disk Termux selesai menulis referensi seutuhnya
                sleep 0.2
              else
                _w "Metode commit-tree gagal. Fallback ke commit standar..."
                git -C "$rp" commit -m "$pesan_commit"
              fi
            else
              _w "Gagal menulis tree. Fallback ke commit standar..."
              git -C "$rp" commit -m "$pesan_commit"
            fi

          elif [ "$aksi_keluar" == "2" ]; then
            _w "Membuang perubahan lokal..."
            git -C "$rp" checkout -f "$current_branch" 2>/dev/null
          else
            _r "Membatalkan proses keluar. Kembali ke menu..."
            sleep 1
            continue
          fi
        else
          # Jika tidak ada perubahan lokal, segarkan indeks lokal pasif secara aman
          git -C "$rp" update-index --refresh &>/dev/null
        fi

        # 4. KOMPARASI REAL-TIME: LOG LOCAL VS REMOTE REPOSITORY
        _nc "========================================"
        _cc "       PERBANDINGAN STATUS COMMIT       "
        _cc "========================================"

        local_log=$(git -C "$rp" log -1 --format="%h - %s" "refs/heads/$current_branch" 2>/dev/null)
        remote_log=$(git -C "$rp" log -1 --format="%h - %s" "refs/remotes/origin/$current_branch" 2>/dev/null)

        echo -e "[Local]  : ${FG_YELLOW}${local_log:-'Belum ada commit'}${NC}"
        echo -e "[Remote] : ${FG_GREEN}${remote_log:-'Belum ada commit'}${NC}"
        _line "-" 50 "$FG_CYAN"

        # 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH
        mapfile -t semua_remote < <(git -C "$rp" remote 2>/dev/null)
        status_konflik_terdeteksi=0
        _ic "Menjalankan radar Pre-Emption pada ${#semua_remote[@]} remote server..."

        for rm_name in "${semua_remote[@]}"; do
          behind_commits=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
          if [ "${behind_commits:-0}" -gt 0 ]; then
            _e "KONFLIK TERDETEKSI: Remote [${rm_name}] lebih maju ${behind_commits} commit!"
            status_konflik_terdeteksi=1
          fi
        done

        if [ "$status_konflik_terdeteksi" -eq 1 ]; then
          log_critical "Proses Multi-Push DIBLOKIR demi keamanan data!"
          _w "Ada perbedaan riwayat di remote. Silakan lakukan 'git pull' manual terlebih dahulu."
          _line "-" 50 "$FG_REDUP"
          _p "Apakah Anda ingin mengintip daftar file yang berbeda di remote? (y/n)"
          read -r intip_diff
          
          if [[ "$intip_diff" =~ ^[yY]$ ]]; then
            _cc "=== DAFTAR PERUBAHAN BERKAS DI SERVER REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              behind_check=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
              if [ "${behind_check:-0}" -gt 0 ]; then
                _ic "Berkas berbeda pada Remote [${rm_name}] (Branch: ${current_branch}):"
                git -C "$rp" diff-tree -r --no-commit-id --name-status "refs/heads/${current_branch}" "refs/remotes/${rm_name}/${current_branch}" | while read -r status file; do
                  case "$status" in
                    A) echo -e "  ${FG_GREEN}[Ditambahkan di Server]${NC} -> $file" ;;
                    M) echo -e "  ${FG_YELLOW}[Dimodifikasi di Server]${NC} -> $file" ;;
                    D) echo -e "  ${RED}[Dihapus di Server]${NC} -> $file" ;;
                    *) echo -e "  [Perubahan: $status] -> $file" ;;
                  esac
                done
              fi
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali ke menu utama"
            read -r _
          fi
          sleep 1
        else
          # Hitung kemajuan riwayat komit lokal sejati terhadap remote origin
        # ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          # HITUNG SELISIH JARAK ANTARA REFS HEADS LOKAL AKTIF DENGAN POINTER BINARI SERVER REMOTE
          ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${ahead_commits:-0}" -gt 0 ]; then
            _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
            _p "Apakah Anda yakin ingin melakukan MULTI-PUSH ke semua remote sekarang? (y/n)"
            read -r konfirmasi_push

            if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Melakukan git push ${rm_target} ${current_branch}..."
                if git -C "$rp" push -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Push ke [${rm_target}] SUKSES!"
                else
                  _a "Gagal melakukan push ke [${rm_target}]! Periksa koneksi atau kredensial SSH Anda."
                fi
              done
            else
              _r "Push massal dibatalkan. Perubahan Anda tetap aman tersimpan di lokal."
            fi
          else
            _o "Status: Sinkron! Seluruh Remote server sama dengan Log Local Anda."
            continue 1
          fi
        fi

        _on "Selesai dengan sukses! Keluar dari skrip."
        continue 1
        ;;


      [iI])
        # =====================================================================
        # FITUR BARU: INJEKSI OBJEK FILE 0-BYTE DARI BRANCH LAIN (CACHEINFO)
        # =====================================================================
        clear
        _header "INJEKSI FILE 0-BYTE ANTAR BRANCH" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch Aktif: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"

        # 1. Tampilkan daftar branch lokal yang tersedia (kecuali branch aktif)
        mapfile -t daftar_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null | grep -vxF "$current_branch")

        if [ ${#daftar_branch[@]} -eq 0 ]; then
          _w "Belum ada branch lokal lain selain '${current_branch}'."
          _p "Apakah Anda ingin membuat branch baru sekarang? (y/n)"
          read -r buat_br_sekarang
          if [[ "$buat_br_sekarang" =~ ^[yY]$ ]]; then
            _p "Masukkan nama branch baru"
            read -r br_baru_i
            br_baru_i=$(echo "$br_baru_i" | tr -d '[:space:]')
            if [ -n "$br_baru_i" ] && git -C "$rp" update-ref "refs/heads/${br_baru_i}" HEAD 2>/dev/null; then
              _o "Branch '${br_baru_i}' berhasil dibuat (0-Byte)! Silakan gunakan menu [v] untuk manajemen lanjut."
              sleep 1.5
            fi
          fi
          continue 1
        fi

        echo -e "${LIGHT_GRAY}Daftar branch sumber yang tersedia:${NC}"
        for i in "${!daftar_branch[@]}"; do
          printf " [%d] %s\n" $((i+1)) "${daftar_branch[$i]}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor branch sumber (atau ketik 'b' untuk batal)"
        read -r br_pilihan

        [[ "$br_pilihan" =~ ^[bB]$ ]] && continue 1

        if ! [[ "$br_pilihan" =~ ^[0-9]+$ ]] || [ "$br_pilihan" -lt 1 ] || [ "$br_pilihan" -gt "${#daftar_branch[@]}" ]; then
          _an "Pilihan branch tidak valid."
          sleep 1
          continue 1
        fi

        source_branch="${daftar_branch[$((br_pilihan - 1))]}"

        # 2. Ambil daftar file yang bertambah (A) atau berubah (M) di branch sumber
        # 2. Ambil daftar file awal sekali saja agar nomor urut [1..N] tetap terkunci
        mapfile -t diff_files < <(git -C "$rp" diff --name-status --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        if [ ${#diff_files[@]} -eq 0 ]; then
          _w "Tidak ada perbedaan file (A/M) antara '${current_branch}' dan '${source_branch}'."
          _pp
          continue 1
        fi

        # Simpan statistik (+X -Y) dan catatan riwayat injeksi sesi ini di memori
        declare -A file_numstat=()
        declare -A injected_log=()
        while IFS=$'\t' read -r add_cnt del_cnt stat_path; do
          [ -n "$stat_path" ] && file_numstat["$stat_path"]="+${add_cnt} -${del_cnt}"
        done < <(git -C "$rp" diff --numstat --diff-filter=AM "$current_branch" "$source_branch" 2>/dev/null)

        while true; do
          clear
          _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
          echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
          _line "=" 50 "$FG_CYAN"

          for i in "${!diff_files[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"

            st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
            f_path=$(echo "${diff_files[$i]}" | cut -f2-)
            stat_label="${file_numstat[$f_path]:-+0 -0}"

            if [ "$st_code" == "A" ]; then
              status_tag="${FG_GREEN}[Baru/A]"
            else
              status_tag="${FG_YELLOW}[Ubah/M]"
            fi

            if [ -n "${injected_log[$f_path]}" ]; then
              # Tandai item yang sudah selesai diinjeksi beserta pesan commit-nya
              printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
            else
              printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          echo -e " [d] ${FG_CYAN}Lihat Diff Baris File Sebelum Injeksi${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor file untuk diinjeksi (0-Byte)"
          read -r f_pilihan

          [[ "$f_pilihan" =~ ^[bB]$ ]] && break

          # Opsi cepat melihat diff baris sebelum memutuskan injeksi
          if [[ "$f_pilihan" =~ ^[dD]$ ]]; then
            _p "Masukkan nomor file yang ingin dilihat diff-nya"
            read -r d_num
            if [[ "$d_num" =~ ^[0-9]+$ ]] && [ "$d_num" -ge 1 ] && [ "$d_num" -le "${#diff_files[@]}" ]; then
              target_diff_file=$(echo "${diff_files[$((d_num - 1))]}" | cut -f2-)
              clear
              git -C "$rp" diff --color=always "$current_branch" "$source_branch" -- "$target_diff_file"
              _line "=" 50 "$FG_CYAN"
              _p "Tekan [Enter] untuk kembali"
              read -r _
            fi
            continue
          fi

          if [[ "$f_pilihan" =~ ^[0-9]+$ ]] && [ "$f_pilihan" -ge 1 ] && [ "$f_pilihan" -le "${#diff_files[@]}" ]; then
            selected_idx=$((f_pilihan - 1))
            target_file=$(echo "${diff_files[$selected_idx]}" | cut -f2-)

            # Cegah injeksi ulang jika file sudah berstatus SELESAI
            if [ -n "${injected_log[$target_file]}" ]; then
              _w "File '${target_file}' sudah diinjeksi (${injected_log[$target_file]})!"
              sleep 1.2
              continue
            fi

            # Hitung auto_msg lebih awal untuk ditampilkan pada sorotan baris
            last_num=$(git -C "$rp" log --format="%s" 2>/dev/null | grep -E "^u[0-9]+$" | head -n 1 | sed 's/^u//')
            if [[ "$last_num" =~ ^[0-9]+$ ]]; then
              auto_msg="u$((last_num + 1))"
            else
              auto_msg="u1"
            fi

            # Gambar ulang daftar dengan tanda sorotan pada nomor yang baru dipilih
            clear
            _header "PILIH FILE DARI [${source_branch}]" 50 "$FG_CYAN" "$FG_GREEN"
            echo -e "Target Branch: ${GREEN}${current_branch}${NC} | Mode: ${FG_CYAN}0-Byte Biner${NC}"
            _line "=" 50 "$FG_CYAN"

            for i in "${!diff_files[@]}"; do
              st_code=$(echo "${diff_files[$i]}" | awk '{print $1}')
              f_path=$(echo "${diff_files[$i]}" | cut -f2-)
              stat_label="${file_numstat[$f_path]:-+0 -0}"

              if [ "$st_code" == "A" ]; then
                status_tag="${FG_GREEN}[Baru/A]"
              else
                status_tag="${FG_YELLOW}[Ubah/M]"
              fi

              if [ "$i" -eq "$selected_idx" ]; then
                # Baris yang sedang dipilih diberi tanda panah ▶ & label [ TERPILIH ]
printf "%b%b ▶ [%d] %s %b %b(%s) %b◀ [ TARGET: %s ]%b\033[K%b\n" \
                "$BG_ZEBRA_2" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_YELLOW" "$auto_msg" "${FG_GREEN}${BG_ZEBRA_2}" "${NC}"
              elif [ -n "${injected_log[$f_path]}" ]; then
              bg_row="$BG_ZEBRA_1"
              (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b ✓ [%d] %s %b %b(%s) %b[ SELESAI: %s ]%b\033[K%b\n" \
                "$bg_row" "$FG_GREEN" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "$FG_GREEN" "${injected_log[$f_path]}" "${FG_GREEN}${bg_row}" "${NC}"
              else
              bg_row="$BG_ZEBRA_1"
              (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b   [%d] %s %b %b(%s)%b\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((i+1)) "$f_path" "$status_tag" "$FG_CYAN" "$stat_label" "${FG_REDUP}${bg_row}" "${NC}"
              fi
            done

            _line "=" 50 "$FG_CYAN"

            # 3. Ekstrak mode dan SHA blob langsung dari tree branch sumber (0-Byte)
            obj_info=$(git -C "$rp" ls-tree "$source_branch" -- "$target_file" 2>/dev/null)
            obj_mode=$(echo "$obj_info" | awk '{print $1}')
            obj_sha=$(echo "$obj_info" | awk '{print $3}')

            if [ -z "$obj_mode" ] || [ -z "$obj_sha" ]; then
              _e "Gagal membaca metadata objek biner untuk '${target_file}'."
              sleep 1.5
              continue
            fi

            echo -e "File terpilih  : ${FG_YELLOW}${target_file}${NC}"
            echo -e "Pesan otomatis: ${GREEN}${auto_msg}${NC}"
            _p "Tekan [Enter] untuk '${auto_msg}', ketik pesan manual, atau 'b' batal"
            read -r pesan_injeksi

            [[ "$pesan_injeksi" =~ ^[bB]$ ]] && continue
            [ -z "$pesan_injeksi" ] && pesan_injeksi="$auto_msg"

            _ic "Menyuntikkan '${target_file}' ke indeks biner & pohon komit..."

            # 4. Suntikkan ke index dengan --cacheinfo & --skip-worktree agar 0-byte di disk
            git -C "$rp" update-index --add --cacheinfo "${obj_mode},${obj_sha},${target_file}" 2>/dev/null
            git -C "$rp" update-index --skip-worktree -- "$target_file" 2>/dev/null

            tree_id=$(git -C "$rp" write-tree 2>/dev/null)
            parent_id=$(git -C "$rp" rev-parse HEAD 2>/dev/null)

            if [ -n "$tree_id" ] && [ -n "$parent_id" ]; then
              new_commit_id=$(echo "$pesan_injeksi" | git -C "$rp" commit-tree "$tree_id" -S -p "$parent_id" 2>/dev/null)
              if [ -n "$new_commit_id" ]; then
                git -C "$rp" update-ref "refs/heads/${current_branch}" "$new_commit_id"
                git -C "$rp" read-tree "$new_commit_id"
                git -C "$rp" update-index --refresh &>/dev/null

                # Simpan status selesai ke array sesi agar tetap tampil di loop berikutnya
                injected_log["$target_file"]="${pesan_injeksi} (${new_commit_id:0:7})"

                # Refresh array targets di menu utama agar folder/file baru langsung muncul
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

                _line "=" 50 "$FG_GREEN"
                _o "BERHASIL: '${target_file}' diinjeksi ke [${pesan_injeksi}] (${new_commit_id:0:7})"
                _line "-" 50 "$FG_CYAN"

                _p "Tekan [Enter] untuk lanjut memilih file berikutnya"
                read -r _
              else
                _e "Gagal membuat objek commit-tree (periksa SSH signing key)."
                sleep 1.5
              fi
            else
              _e "Gagal menulis tree biner Git."
              sleep 1.5
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue 1
        ;;


    [sS])
        # =====================================================================
        # FITUR: INJEKSI OBJEK COMMIT / SUBMODULE VIRTUAL 0-BYTE
        # =====================================================================
        clear
        echo -e "${BLUE}====================================================${NC}"
        echo -e "${BLUE}    FORMULIR INJEKSI SUBMODULE VIRTUAL 0-BYTE       ${NC}"
        echo -e "${BLUE}====================================================${NC}"
        echo -e "${LIGHT_GRAY}Fitur ini akan mendaftarkan repositori luar sebagai objek commit${NC}"
        echo -e "${LIGHT_GRAY}tanpa mengunduh 1-byte pun data fisik ke penyimpanan disk.${NC}"
        echo "----------------------------------------------------"
        
        # 1. Menjaring Input Data dari Pengguna
        echo -n -e "${FG_YELLOW}[?] Masukkan Nama Submodule (Misal: reqwest_core): ${NC}"
        read -r input_nama
        
        echo -n -e "${FG_YELLOW}[?] Masukkan SHA-1 Commit (Misal: 8e1c8061e5dd936762dcef08a64ef2cff584b295): ${NC}"
        read -r input_sha
        
        echo -n -e "${FG_YELLOW}[?] Masukkan URL Git Repositori SSH/HTTPS (Misal: git@github.com:seanmonstar/reqwest.git): ${NC}"
        read -r input_url

        # 2. Validasi Pengaman Input Kosong
        if [ -z "$input_nama" ] || [ -z "$input_sha" ] || [ -z "$input_url" ]; then
          echo ""
          _e "❌ Gagal: Seluruh kolom input wajib diisi secara lengkap!"
          sleep 2
          continue 1
        fi

        echo ""
        _ic "⏳ Memulai manipulasi memori biner Git tingkat rendah..."

        # 3. Daftarkan Metadata Kosmetik ke Berkas .gitmodules
        git -C "$rp" config -f .gitmodules submodule."${input_nama}".url "${input_url}"
        git -C "$rp" config -f .gitmodules submodule."${input_nama}".path "${input_nama}"
        
        # Paksa masuk ke staging area meskipun tersembunyi oleh aturan sparse
        git -C "$rp" add --sparse .gitmodules 2>/dev/null

        # 4. Eksekusi Inti: Suntikkan Kode Biner Mode 160000 ke Indeks
        if git -C "$rp" update-index --add --cacheinfo 160000,"${input_sha}","${input_nama}" 2>/dev/null; then
          
          # 5. Kunci ke Sejarah Komit Lokal Lewat commit-tree (0-Byte Overhead)
          current_tree=$(git -C "$rp" write-tree 2>/dev/null)
          pesan_otomatis="Suntikan Submodule Virtual 0-byte: ${input_nama}"
          new_commit_id=$(git -C "$rp" commit-tree "$current_tree" -p HEAD -m "$pesan_otomatis" 2>/dev/null)

          if [ -n "$new_commit_id" ]; then
            # Geser pointer cabang aktif ke commit biner baru
            git -C "$rp" update-ref "refs/heads/$current_branch" "$new_commit_id"
            
            # Sinkronkan radar tracking internal skrip agar menu langsung ter-refresh

            # ❌ HAPUS / BERIKAN TANDA KOMENTAR (#) PADA BARIS DI BAWAH INI:
            # git -C "$rp" update-ref "refs/remotes/origin/$current_branch" "$new_commit_id"  <-- HAPUS INI!

            git -C "$rp" read-tree "$new_commit_id"
            git -C "$rp" update-index --refresh &>/dev/null
            
            echo ""
            _o "✅ BERHASIL: Objek Commit /${input_nama} kini aktif dalam status 0-byte!"
          else
            _e "❌ Gagal mengunci pohon komit baru (commit-tree error)."
          fi
        else
          _e "❌ Gagal menginjeksi indeks biner Git. Pastikan format SHA-1 Anda valid."
        fi
        
        sleep 2
        continue 1
        ;;


      [vV])
        # =====================================================================
        # MANAJEMEN BRANCH VIRTUAL INSTAN (PINDAH, BUAT BARU, HAPUS - 0-BYTE)
        # =====================================================================
        while true; do
          clear
          _header "MANAJEMEN BRANCH VIRTUAL (0-BYTE)" 50 "$FG_CYAN" "$FG_GREEN"
          head_short=$(git -C "$rp" rev-parse --short HEAD 2>/dev/null)
          head_msg=$(git -C "$rp" log -1 --format="%s" 2>/dev/null)
          echo -e "Repositori   : ${FG_YELLOW}${r}${NC}"
          echo -e "Branch Aktif : ${GREEN}${current_branch}${NC} (${FG_CYAN}${head_short}${NC} - ${head_msg})"
          _line "=" 50 "$FG_CYAN"

          # Tampilkan semua branch lokal yang ada
          mapfile -t semua_branch < <(git -C "$rp" for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)
          echo -e "${LIGHT_GRAY}Daftar Branch Lokal:${NC}"
          for i in "${!semua_branch[@]}"; do
            bg_row="$BG_ZEBRA_1"
            (( i % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
            br_sha=$(git -C "$rp" rev-parse --short "refs/heads/${semua_branch[$i]}" 2>/dev/null)
            if [ "${semua_branch[$i]}" == "$current_branch" ]; then
              printf "%b%b [%d] %-20s (%s) %b[ AKTIF ]%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "$FG_GREEN" "${FG_REDUP}${bg_row}" "${NC}"
            else
              printf "%b%b [%d] %-20s (%s)\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${semua_branch[$i]}" "$br_sha" "${NC}"
            fi
          done

          _line "-" 50 "$FG_CYAN"
          _menu_opt "c" "$FG_GREEN"  "Buat Branch Baru Virtual" "(0-Byte update-ref)"
          _menu_opt "r" "$FG_YELLOW" "Reset Pointer Branch Aktif" "(Pilih dari Riwayat Commit)"
          _menu_opt "x" "$RED"       "Hapus Branch Lokal" "(git branch -D)"
          _menu_opt "b" "$FG_CYAN"   "Kembali ke Menu Sparse-Checkout"
          _line "=" 50 "$FG_CYAN"
          _p "Pilih nomor branch untuk pindah, atau opsi [c/r/x/b]"
          read -r br_aksi

          [[ "$br_aksi" =~ ^[bB]$ ]] && break


          # --- OPSI [x]: HAPUS BRANCH LOKAL ---
          if [[ "$br_aksi" =~ ^[xX]$ ]]; then
            _p "Masukkan nomor branch yang ingin dihapus"
            read -r del_br_num
            if [[ "$del_br_num" =~ ^[0-9]+$ ]] && [ "$del_br_num" -ge 1 ] && [ "$del_br_num" -le "${#semua_branch[@]}" ]; then
              target_del_br="${semua_branch[$((del_br_num - 1))]}"
              if [ "$target_del_br" == "$current_branch" ]; then
                _e "Tidak dapat menghapus branch yang sedang aktif!"
                sleep 1.5
              else
                _pd "Yakin ingin menghapus branch '${target_del_br}' secara permanen?"
                read -r konf_del_br
                if [[ "$konf_del_br" =~ ^[yY]$ ]]; then
                  git -C "$rp" branch -D "$target_del_br" >/dev/null 2>&1
                  _o "Branch '${target_del_br}' berhasil dihapus."
                  sleep 1
                fi
              fi
            else
              _an "Nomor branch tidak valid."
              sleep 1
            fi
            continue
          fi

          # --- OPSI [r]: RESET POINTER BRANCH AKTIF KE COMMIT TERTENTU (0-BYTE) ---
          if [[ "$br_aksi" =~ ^[rR]$ ]]; then
            clear
            _header "RESET POINTER BRANCH [${current_branch}]" 50 "$FG_CYAN" "$FG_YELLOW"
            echo -e "Riwayat 15 Commit Terakhir pada ${GREEN}${current_branch}${NC}:"
            _line "=" 50 "$FG_CYAN"

            mapfile -t log_commits < <(git -C "$rp" log -n 15 --format="%H|%h|%s|%cr" 2>/dev/null)
            for idx_c in "${!log_commits[@]}"; do
              IFS='|' read -r full_c short_c msg_c time_c <<< "${log_commits[$idx_c]}"
              bg_row="$BG_ZEBRA_1"
              (( idx_c % 2 != 0 )) && bg_row="$BG_ZEBRA_2"
              printf "%b%b [%2d] %b%s%b - %-22s (%s)\033[K%b\n" \
                "$bg_row" "$FG_REDUP" $((idx_c+1)) "$FG_CYAN" "$short_c" "${FG_REDUP}${bg_row}" "${msg_c:0:22}" "$time_c" "${NC}"
            done

            _line "-" 50 "$FG_CYAN"
            _p "Pilih nomor commit (1-${#log_commits[@]}), ketik hash manual, atau 'b' batal"
            read -r pilih_commit

            [[ "$pilih_commit" =~ ^[bB]$ ]] && continue

            target_reset_sha=""
            if [[ "$pilih_commit" =~ ^[0-9]+$ ]] && [ "$pilih_commit" -ge 1 ] && [ "$pilih_commit" -le "${#log_commits[@]}" ]; then
              target_reset_sha=$(echo "${log_commits[$((pilih_commit - 1))]}" | cut -d'|' -f1)
            elif [ -n "$pilih_commit" ]; then
              target_reset_sha=$(git -C "$rp" rev-parse --verify "${pilih_commit}^{commit}" 2>/dev/null)
            fi

            if [ -z "$target_reset_sha" ]; then
              _e "Commit target tidak valid atau tidak ditemukan!"
              sleep 1.5
              continue
            fi

            _line "-" 50 "$FG_YELLOW"
            echo -e "Branch '${GREEN}${current_branch}${NC}' akan diputar balik ke: ${FG_CYAN}${target_reset_sha:0:7}${NC}"
            _p "Buat branch backup otomatis dari posisi HEAD saat ini sebelum reset? (y/n)"
            read -r buat_auto_backup
            if [[ "$buat_auto_backup" =~ ^[yY]$ ]]; then
              default_bk="backup_${current_branch}_$(date +%Y%m%d_%H%M)"
              _p "Nama branch backup (Enter = ${default_bk})"
              read -r nama_bk_input
              nama_bk_final=$(echo "${nama_bk_input:-$default_bk}" | tr -d '[:space:]')
              if git -C "$rp" update-ref "refs/heads/${nama_bk_final}" HEAD 2>/dev/null; then
                _o "Backup aman tersimpan di branch '${nama_bk_final}'!"
              else
                _e "Gagal membuat branch backup. Reset dibatalkan demi keamanan."
                sleep 1.5
                continue
              fi
            fi

            _pd "Konfirmasi: Reset pointer '${current_branch}' ke ${target_reset_sha:0:7} sekarang?"
            read -r konf_reset
            if [[ "$konf_reset" =~ ^[yY]$ ]]; then
              _ic "Memutar ulang referensi branch & menyinkronkan indeks biner 0-byte..."

              # 1. Pindahkan pointer branch secara biner (0-byte)
              git -C "$rp" update-ref "refs/heads/${current_branch}" "$target_reset_sha"

              # 2. Baca ulang pohon file target ke indeks dan pertahankan bit skip-worktree
              git -C "$rp" read-tree "$target_reset_sha"
              git -C "$rp" ls-files -z 2>/dev/null | \
                xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null

              # 3. Jika ada file fisik aktif di disk (tercatat di manifest), sinkronkan isinya
              if [ -s "$virtual_manifest_file" ]; then
                while IFS= read -r act_f || [[ -n "$act_f" ]]; do
                  [ -z "$act_f" ] && continue
                  if git -C "$rp" cat-file -e "${target_reset_sha}:${act_f}" 2>/dev/null; then
                    git -C "$rp" ls-files -z -- "$act_f" 2>/dev/null | \
                      xargs -0 -r git -C "$rp" update-index --no-skip-worktree -- 2>/dev/null
                    git -C "$rp" checkout "$target_reset_sha" -- "$act_f" 2>/dev/null
                  else
                    rm -rf "${rp}/${act_f}"
                    sed -i "\|^${act_f}$|d" "$virtual_manifest_file"
                  fi
                done < "$virtual_manifest_file"
              fi

              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)

              _o "Pointer '${current_branch}' berhasil di-reset ke ${target_reset_sha:0:7} (0-Byte & tanpa jejak ' D')!"
              sleep 1.5
            else
              _c "Reset dibatalkan."
              sleep 0.8
            fi
            continue
          fi

          # --- OPSI [c]: BUAT BRANCH BARU 0-BYTE ---
          if [[ "$br_aksi" =~ ^[cC]$ ]]; then
            _line "-" 50 "$FG_CYAN"
            _p "Masukkan nama branch baru (Contoh: backup_u330 atau dev)"
            read -r nama_br_baru
            nama_br_clean=$(echo "$nama_br_baru" | tr -d '[:space:]')

            if [ -z "$nama_br_clean" ]; then
              _e "Nama branch tidak boleh kosong!"
              sleep 1
              continue
            fi

            if git -C "$rp" show-ref --verify --quiet "refs/heads/${nama_br_clean}"; then
              _w "Branch '${nama_br_clean}' sudah ada!"
              sleep 1.2
              continue
            fi

            _p "Titik awal branch (Kosongkan/Enter = HEAD saat ini, atau ketik hash commit)"
            read -r base_commit
            [ -z "$base_commit" ] && base_commit="HEAD"

            target_sha=$(git -C "$rp" rev-parse --verify "${base_commit}^{commit}" 2>/dev/null)
            if [ -z "$target_sha" ]; then
              _e "Referensi commit '${base_commit}' tidak ditemukan!"
              sleep 1.5
              continue
            fi

            # Tulis referensi branch baru langsung secara biner (0-Byte disk)
            if git -C "$rp" update-ref "refs/heads/${nama_br_clean}" "$target_sha" 2>/dev/null; then
              _o "Branch '${nama_br_clean}' berhasil dibuat pada commit ${target_sha:0:7} (0-Byte)!"
              _p "Apakah ingin langsung pindah ke branch '${nama_br_clean}'? (y/n)"
              read -r langsung_pindah
              if [[ "$langsung_pindah" =~ ^[yY]$ ]]; then
                git -C "$rp" symbolic-ref HEAD "refs/heads/${nama_br_clean}" 2>/dev/null
                current_branch="$nama_br_clean"
                git -C "$rp" read-tree "$current_branch" 2>/dev/null
                git -C "$rp" update-index --refresh &>/dev/null
                mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
                _o "Berhasil pindah ke '${current_branch}'."
                sleep 1
                break
              fi
            else
              _e "Gagal membuat branch '${nama_br_clean}'."
            fi
            sleep 1.2
            continue
          fi

          # --- PINDAH KE BRANCH TERPILIH BERDASARKAN ANGKA ---
          if [[ "$br_aksi" =~ ^[0-9]+$ ]] && [ "$br_aksi" -ge 1 ] && [ "$br_aksi" -le "${#semua_branch[@]}" ]; then
            target_branch_clean="${semua_branch[$((br_aksi - 1))]}"
            if [ "$target_branch_clean" == "$current_branch" ]; then
              _w "Anda sudah berada di branch '${current_branch}'."
              sleep 1
              continue
            fi

            _ic "Mengalihkan pointer HEAD secara virtual ke refs/heads/${target_branch_clean}..."
            if git -C "$rp" symbolic-ref HEAD "refs/heads/${target_branch_clean}" 2>/dev/null; then
              current_branch="$target_branch_clean"
              git -C "$rp" read-tree "$current_branch" 2>/dev/null
              git -C "$rp" update-index --refresh &>/dev/null
              mapfile -t targets < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" HEAD 2>/dev/null)
              _o "HEAD berhasil dialihkan secara instan ke branch: ${current_branch}"
              sleep 1
              break
            else
              _e "Gagal mengalihkan branch via symbolic-ref!"
              sleep 1.2
            fi
          else
            _an "Pilihan tidak valid."
            sleep 1
          fi
        done
        continue
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

        # Baca folder yang saat ini "aktif" di manifest virtual
        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        # 4. VALIDASI AWAL REPO AKTIF
        if [ ${#active_folders[@]} -eq 0 ]; then
          _hn "Belum ada folder aktif. Silakan aktifkan folder terlebih dahulu."
          _pp
        else
          log_notify "Memetakan seluruh file dan folder lokal..."
          
          # Mengambil semua file dan direktori di dalam folder aktif lokal (kecuali .git)
          all_local_items=()
          if [ -d "$rp" ]; then
            # PERBAIKAN: Kecualikan .git dengan benar (! -path '*/.git*')
            while IFS= read -r item; do
              [ -z "$item" ] && continue
              for active_dir in "${active_folders[@]}"; do
                if [[ "$item" == "$active_dir"/* || "$item" == "$active_dir" ]]; then
                  all_local_items+=("$item")
                  break
                fi
              done
            done < <(find "$rp" -mindepth 1 ! -path '*/.git*' 2>/dev/null | sed "s|^${rp}/||" | sort)
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
            echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
            _cc "========================================"
            for i in "${!all_local_items[@]}"; do
              item_path="${all_local_items[$i]}"
              if [ -d "${rp}/${item_path}" ]; then
                printf " [%d] %s/ %b[ Folder ]%b\n" $((i+1)) "$item_path" "${FG_YELLOW}" "${NC}"
              else
                printf " [%d] %s %b[ File ]%b\n" $((i+1)) "$item_path" "${FG_GREEN}" "${NC}"
              fi
            done
            _cc "----------------------------------------"
            _p "Pilih nomor target yang ingin dihapus"
            read -r hapus_idx_num

            if [[ "$hapus_idx_num" =~ ^[0-9]+$ ]] && [ "$hapus_idx_num" -ge 1 ] && [ "$hapus_idx_num" -le "${#all_local_items[@]}" ]; then
              idx=$((hapus_idx_num - 1))
              target_hapus="${all_local_items[$idx]}"
              full_target_path="${rp}/${target_hapus}"

              _line "-" 50 "$FG_REDUP"
              echo -e "Target terpilih: ${FG_YELLOW}${target_hapus}${NC}"
              _menu_opt "1" "$FG_CYAN" "Susutkan ke 0-Byte saja" "(Hapus fisik lokal, tetap ada di Git)"
              _menu_opt "2" "$RED"     "Hapus Permanen dari Git" "(git rm - akan terhapus di Remote)"
              _menu_opt "3" "$FG_REDUP" "Batal"
              _line "-" 50 "$FG_CYAN"
              _p "Pilih jenis penghapusan (1/2/3)"
              read -r mode_hapus

              case "$mode_hapus" in
                1)
                  _ic "Menyusutkan '${target_hapus}' kembali ke mode virtual 0-byte..."
                  # Kembalikan flag skip-worktree agar git status bersih total tanpa ' D'
                  git -C "$rp" ls-files -z -- "$target_hapus" 2>/dev/null | xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null

                  # 2. Hapus wujud fisik di penyimpanan lokal
                  rm -rf "$full_target_path"

                  # 3. Jika target adalah folder/item induk tingkat pertama (tidak mengandung '/'),
                  #    hapus juga dari virtual_manifest_file dan perbarui sparse-checkout
                  if [[ "$target_hapus" != */* ]]; then
                    sed -i "\|^${target_hapus}$|d" "$virtual_manifest_file"

                    new_sparse_list=("!/*")
                    while IFS= read -r line || [[ -n "$line" ]]; do
                      [ -n "$line" ] && new_sparse_list+=("/${line}")
                    done < "$virtual_manifest_file"

                    git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}" >/dev/null 2>&1
                  fi

                  # 4. Segarkan indeks biner secara ringan
                  git -C "$rp" update-index --refresh &>/dev/null
                  _o "'${target_hapus}' berhasil dihapus dari disk lokal tanpa jejak ' D'."
                  sleep 1
                  ;;
                2)
                  # Logika Git RM: Cek apakah file sudah pernah di-track oleh git sebelumnya
                  _ic "Menghapus permanen '${target_hapus}' dari Git & penyimpanan..."
                  if git -C "$rp" ls-files --error-unmatch "$target_hapus" &>/dev/null; then
                    # Pastikan skip-worktree dilepas dulu agar git rm berjalan mulus tanpa error
                    git -C "$rp" ls-files -z -- "$target_hapus" 2>/dev/null | xargs -0 -r git -C "$rp" update-index --no-skip-worktree -- 2>/dev/null
                    
                    # Jika sudah di-track, gunakan git rm secara rekursif untuk folder/file
                    git -C "$rp" rm -rf "$target_hapus"
                    _o "'${target_hapus}' dihapus permanen dan dicatat di staging area Git."
                  else
                    # Jika file baru (untracked) dan belum di-commit, hapus secara fisik langsung
                    rm -rf "$full_target_path"
                    _o "Berkas untracked '${target_hapus}' telah dihapus fisik."
                  fi
                  sleep 1
                  ;;
                *)
                  _c "Penghapusan dibatalkan."
                  sleep 0.8
                  ;;
              esac
            else
              _an "Pilihan tidak valid."
              sleep 1
            fi
          fi
        fi
        ;;


      [nN])
        # =====================================================================
        # FITUR: BUAT FILE BARU DI FOLDER AKTIF
        # =====================================================================
        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          continue # Kembali ke menu seleksi folder sparse, tidak jadi keluar
        fi # end if micro installed check

        # Baca list folder tingkat pertama yang saat ini aktif di manifest virtual
        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        _in "Memetakan struktur sub-folder repositori secara virtual (0-byte)..."

        # Tarik daftar sub-folder dari REMOTE (GitHub)
        # AMBIL SELURUH DAFTAR SUB-FOLDER DARI REMOTE INDEX SECARA REKURSIF
        mapfile -t remote_dirs < <(git -C "$rp" ls-tree -r -d --name-only "origin/${current_branch}" 2>/dev/null)

        # Reset array agar tidak menumpuk saat menu diulang
        valid_dirs=()

        # PERBAIKAN: Selalu masukkan pilihan "." (Root Utama) ke dalam daftar tujuan
        valid_dirs+=(".") # Selalu sediakan opsi Root Utama Repositori

        # FILTER STRUKTUR SUB-FOLDER BERDASARKAN FOLDER INDUK YANG SEDANG AKTIF
        for dir in "${remote_dirs[@]}"; do
          [ -z "$dir" ] && continue
          
          # Jika manifest kosong, hanya izinkan pembuatan file di Root '.'
          if [ ${#active_folders[@]} -eq 0 ]; then
            continue
          fi

          for active_dir in "${active_folders[@]}"; do
            # Pastikan folder/sub-folder diawali atau cocok dengan folder induk yang aktif
            # Validasi apakah sub-folder remote berada di dalam naungan folder virtual aktif
            if [[ "$dir" == "$active_dir"/* || "$dir" == "$active_dir" ]]; then
              # Mencegah duplikasi data agar daftar tetap bersih
              if [[ ! " ${valid_dirs[*]} " =~ " ${dir} " ]]; then
                valid_dirs+=("$dir")
              fi # end if duplicate check
            fi # end if check match active
          done # end for active_dir
        done # end for dir

        # Urutkan secara alfabetis agar berurutan rapi dari folder induk ke sub-sub folder terujung
        # Urutkan secara alfabetis agar terstruktur rapi
        # PERBAIKAN: Menggunakan printf '%s\n' agar pengurutan array dengan sort -u 
        # tetap akurat dan aman meskipun ada folder yang memiliki spasi
        # Untuk Blok [nN]
        mapfile -t sorted_dirs < <(printf '%s\n' "${valid_dirs[@]}" | sort -u)

        # Tampilkan daftar semua folder & sub-folder secara instan
        # TAMPILKAN SUB-MENU STRUKTUR FOLDER VIRTUAL SEUTUHNYA
        clear
        _header "PILIH STRUKTUR FOLDER TUJUAN" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"
        for i in "${!sorted_dirs[@]}"; do
          # Pilih warna latar belakang selang-seling (ganjil/genap)
          if (( i % 2 == 0 )); then
            bg_row="$BG_ZEBRA_1"
          else
            bg_row="$BG_ZEBRA_2"
          fi

          if [ "${sorted_dirs[$i]}" == "." ]; then
            printf "%b%b [%d] / (Direktori Utama / Root)\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${NC}"
          else
            # Berikan penanda visual jika folder beneran sudah menempati disk lokal
            # Berikan penanda visual jika folder sudah ada di disk lokal tanpa memutus latar zebra
            status_f_lokal=""
            if [ -d "${rp}/${sorted_dirs[$i]}" ]; then
              status_f_lokal="          ${FG_CYAN}[ lokal ready ]${FG_REDUP}${bg_row}"
            fi
            printf "%b%b [%d] /%s/%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${sorted_dirs[$i]}" "$status_f_lokal" "${NC}"
          fi
        done # end for display dirs
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor folder tempat menaruh file baru"
        read -r folder_num_pilihan

        if [[ "$folder_num_pilihan" =~ ^[0-9]+$ ]] && [ "$folder_num_pilihan" -ge 1 ] && [ "$folder_num_pilihan" -le "${#sorted_dirs[@]}" ]; then
          idx=$((folder_num_pilihan - 1))
          target_folder_path="${sorted_dirs[$idx]}"

          _line "-" 50 "$FG_CYAN"
          if [ "$target_folder_path" == "." ]; then
            echo -e "Folder tujuan terkunci: ${YELLOW}/ (Root)${NC}"
            tree_target="origin/${current_branch}"
            local_scan_dir="$rp"
          else
            echo -e "Folder tujuan terkunci: ${FG_YELLOW}/${target_folder_path}/${NC}"
            tree_target="origin/${current_branch}:${target_folder_path}"
            local_scan_dir="${rp}/${target_folder_path}"
          fi

          # =================================================================
          # PRATINJAU ISI FILE DI DALAM FOLDER TUJUAN (REMOTE & LOKAL)
          # =================================================================
          mapfile -t r_folder_files < <(git -C "$rp" ls-tree --format="%(objecttype)	%(path)" "$tree_target" 2>/dev/null | awk -F'\t' '$1=="blob" {print $2}')
          l_folder_files=()
          if [ -d "$local_scan_dir" ]; then
            mapfile -t l_folder_files < <(find "$local_scan_dir" -maxdepth 1 -type f 2>/dev/null | xargs -r -n1 basename)
          fi
          mapfile -t existing_files < <(printf '%s\n' "${r_folder_files[@]}" "${l_folder_files[@]}" | grep -v '^$' | sort -u)

          echo -e "${LIGHT_GRAY}Daftar file yang sudah ada di folder ini:${NC}"
          if [ ${#existing_files[@]} -eq 0 ]; then
            echo -e "  ${LIGHT_GRAY}(Kosong / Belum ada file)${NC}"
          else
            for ef in "${existing_files[@]}"; do
              echo -e "  ${FG_CYAN}- ${ef}${NC}"
            done
          fi
          _line "-" 50 "$FG_CYAN"

          # REKOMENDASI TERBAIK: Informatif dengan visual warna hijau pada contoh input
          _p "Masukkan NAMA FILE BARU (Contoh: " "script.py" ")"
          read -r nama_file_murni

          if [ -z "$nama_file_murni" ]; then
            _e "Nama file tidak boleh kosong!"
            sleep 1
          else
            # AMAN & OTOMATIS: Hapus tanda garis miring di awal input jika user mengetik "/u3/README.md"
            # Ini mengubah "/u3/README.md" menjadi "u3/README.md" agar penggabungan path tidak rusak
            nama_file_bersih=$(echo "$nama_file_murni" | sed 's|^/||')
            # Tentukan path lengkap berdasarkan apakah user memilih root atau subfolder
            # Formulasi penentuan jalur file virtual dinamis
            if [ "$target_folder_path" == "." ]; then
              selected_virtual_file="${nama_file_bersih}"
            else
              selected_virtual_file="${target_folder_path}/${nama_file_bersih}"
            fi
            full_new_file_path="${rp}/${selected_virtual_file}"

            # =================================================================
            # PENGAMAN: CEGAH MENIMPA FILE LOKAL ATAU FILE VIRTUAL YANG SUDAH ADA
            # =================================================================
            if [ -f "$full_new_file_path" ] || git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null | grep -qxF "$selected_virtual_file"; then
              _w "File '${selected_virtual_file}' sudah ada di repositori/lokal!"
              _p "Apakah Anda ingin membukanya untuk diedit sekarang? (y/n)"
              read -r konfirmasi_edit_ada

              if [[ "$konfirmasi_edit_ada" =~ ^[yY]$ ]]; then
                # Jika belum ada di disk lokal, ekstrak isinya dari Git (bukan file kosong)
                if [ ! -f "$full_new_file_path" ]; then
                  _ic "Mengekstrak isi asli berkas dari remote..."
                  git -C "$rp" sparse-checkout add "$selected_virtual_file" >/dev/null 2>&1
                  git -C "$rp" update-index --no-skip-worktree "$selected_virtual_file" >/dev/null 2>&1
                  if ! git -C "$rp" checkout-index --prefix="" --force -- "$selected_virtual_file" 2>/dev/null; then
                    git -C "$rp" checkout "$current_branch" -- "$selected_virtual_file" >/dev/null 2>&1
                  fi
                fi
                _in "Membuka ${selected_virtual_file} dengan micro..."
                sleep 0.5
                micro "$full_new_file_path"
              else
                _c "Pembuatan file dibatalkan agar isi file asli tidak tertimpa."
                sleep 1
              fi
              continue
            fi

            # =================================================================
            # PROSEDUR LAZY LAUNCH UNTUK FILE BARU DI FOLDER VIRTUAL
            # =================================================================
            # Pastikan folder target didaftarkan ke manifest sparse checkout asli Git
            git -C "$rp" sparse-checkout add "$selected_virtual_file" >/dev/null 2>&1

            # Mengambil path direktori induk (misal: /bash/bash_c/u3)
            new_parent_dir=$(dirname "$full_new_file_path")

            # Siapkan folder lokal fisik jika belum ada, lalu sentuh file barunya
            # JALUR UTAMA: Membuat semua folder/sub-folder baru secara otomatis jika belum ada
            mkdir -p "$new_parent_dir"

            # Membuat file kosong tiruan agar micro bisa langsung menyimpannya
            touch "$full_new_file_path"
            # =================================================================

            _in "Membuat dan membuka file baru dengan micro..."
            sleep 1.5
            micro "$full_new_file_path"
          fi # end if nama_file_murni kosong
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi # end if folder_num_pilihan valid
        ;; # Menutup opsi [nN] dengan benar


      [eE])
        # =====================================================================
        # MENU EDIT FILE (HANYA MENAMPILKAN FILE YANG SUDAH LOKAL READY)
        # =====================================================================
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue 1
        fi

        if ! command -v micro &> /dev/null; then
          _an "Editor 'micro' belum terinstall! Jalankan 'pkg install micro' terlebih dahulu."
          _pp
          continue 1
        fi

        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        if [ ${#active_folders[@]} -gt 0 ]; then
          regex_pola="^($(printf '%s|' "${active_folders[@]}" | sed 's/|$//'))/"
        else
          regex_pola="^[^/]+$"
        fi

        # Ambil HANYA file fisik yang sudah eksis di disk lokal (Lokal Ready)
        valid_files=()
        if [ -d "$rp" ]; then
          mapfile -t valid_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git" | grep -E "$regex_pola" | sort -u)
        fi

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Belum ada file lokal ready di folder aktif. Gunakan opsi [a] untuk mengaktifkan file terlebih dahulu."
          _pp
          continue 1
        fi

        clear
        _header "DAFTAR FILE YANG DAPAT DIEDIT" 50 "$FG_CYAN" "$FG_GREEN"
        echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
        _line "=" 50 "$FG_CYAN"
        for i in "${!valid_files[@]}"; do
          # Pilih warna latar belakang selang-seling (ganjil/genap)
          if (( i % 2 == 0 )); then
            bg_row="$BG_ZEBRA_1"
          else
            bg_row="$BG_ZEBRA_2"
          fi

          # Cetak baris dengan teks redup dan latar belakang penuh hingga ujung kanan layar (\033[K)
          printf "%b%b [%d] %s\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${valid_files[$i]}" "${NC}"
        done
        _line "-" 50 "$FG_CYAN"
        _p "Pilih nomor file yang ingin diedit dengan micro"
        read -r num_pilihan

        if [[ "$num_pilihan" =~ ^[0-9]+$ ]] && [ "$num_pilihan" -ge 1 ] && [ "$num_pilihan" -le "${#valid_files[@]}" ]; then
          idx=$((num_pilihan - 1))
          selected_virtual_file="${valid_files[$idx]}"
          full_file_path="${rp}/${selected_virtual_file}"

          _in "Membuka ${selected_virtual_file} dengan micro..."
          sleep 0.5
          micro "$full_file_path"
        else
          _an "Pilihan tidak valid."
          sleep 1
        fi
        ;;


      [aA])
        # =====================================================================
        # FITUR BARU: AKTIVASI / UNDUH FILE MASSAL KE LOKAL READY (TANPA MICRO)
        # =====================================================================
        if [ -z "$rp" ] || [ -z "$r" ] || [ -z "$current_branch" ]; then
          _e "Argumen repositori atau branch tidak valid!"
          _pp
          continue 1
        fi

        active_folders=()
        while IFS= read -r f || [[ -n "$f" ]]; do
          [ -n "$f" ] && active_folders+=("$f")
        done < "$virtual_manifest_file"

        if [ ${#active_folders[@]} -gt 0 ]; then
          regex_pola="^($(printf '%s|' "${active_folders[@]}" | sed 's/|$//'))/"
        else
          regex_pola="^[^/]+$"
        fi

        mapfile -t remote_files < <(git -C "$rp" ls-tree -r --name-only "origin/${current_branch}" 2>/dev/null | grep -E "$regex_pola")
        local_files=()
        if [ -d "$rp" ]; then
          mapfile -t local_files < <(find "$rp" -type f 2>/dev/null | sed "s|^${rp}/||" | grep -v "^\.git" | grep -E "$regex_pola")
        fi

        mapfile -t valid_files < <(printf '%s\n' "${remote_files[@]}" "${local_files[@]}" | grep -v '^$' | sort -u)

        if [ ${#valid_files[@]} -eq 0 ]; then
          _rn "Folder aktif Anda kosong atau belum ada folder aktif yang dipilih di menu utama."
          _pp
          continue 1
        fi

        while true; do
          clear
          _cc "========================================"
          _cc "   AKTIVASI FILE MASSAL (LOKAL READY)   "
          _cc "========================================"
          echo -e "Repositori: ${FG_YELLOW}${r}${NC} | Branch: ${FG_GREEN}${current_branch}${NC}"
          _line "=" 50 "$FG_CYAN"
          for i in "${!valid_files[@]}"; do
            # Pilih warna latar belakang selang-seling (ganjil/genap)
            if (( i % 2 == 0 )); then
              bg_row="$BG_ZEBRA_1"
            else
              bg_row="$BG_ZEBRA_2"
            fi

            status_lokal=""
            if [ -f "${rp}/${valid_files[$i]}" ]; then
              status_lokal=" ${FG_CYAN}[ lokal ready ]${FG_REDUP}${bg_row}"
            fi

            # Cetak baris dengan latar belakang penuh hingga ujung kanan layar (\033[K)
            printf "%b%b [%d] %s%b\033[K%b\n" "$bg_row" "$FG_REDUP" $((i+1)) "${valid_files[$i]}" "$status_lokal" "${NC}"
          done
          _cc "----------------------------------------"
          echo -e " Format Input : ${GREEN}3-5${NC} | ${GREEN}50-80${NC} | ${GREEN}1,4,7${NC}"
          echo -e " [e] ${FG_GREEN}Lanjut ke Menu Edit File Lokal Ready${NC}"
          echo -e " [b] ${FG_YELLOW}Kembali ke Menu Sparse-Checkout${NC}"
          _cc "----------------------------------------"
          _p "Masukkan nomor/rentang file yang ingin diaktifkan"
          read -r input_multi

          if [[ "$input_multi" =~ ^[bB]$ ]]; then
            break
          fi

          # Jika user menekan [e] dari dalam sub-menu [a], langsung lompat ke blok edit di bawah
          if [[ "$input_multi" =~ ^[eE]$ ]]; then
            # Umpan langsung menuju menu [e]
            next_menu_action="e"
            break
          fi

          if [ -z "$input_multi" ]; then
            _an "Input tidak boleh kosong."
            sleep 1
            continue
          fi

          # Urai input rentang (contoh: 3-5) dan koma/spasi (contoh: 1,4,7)
          selected_indices=()
          input_norm=$(echo "$input_multi" | tr ',' ' ')
          for token in $input_norm; do
            if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
              start_num="${BASH_REMATCH[1]}"
              end_num="${BASH_REMATCH[2]}"
              if [ "$start_num" -le "$end_num" ]; then
                for ((n=start_num; n<=end_num; n++)); do
                  selected_indices+=("$n")
                done
              fi
            elif [[ "$token" =~ ^[0-9]+$ ]]; then
              selected_indices+=("$token")
            fi
          done

          if [ ${#selected_indices[@]} -eq 0 ]; then
            _an "Format nomor atau rentang tidak valid!"
            sleep 1.2
            continue
          fi

          # Kumpulkan daftar file unik yang valid untuk diunduh sekaligus
          files_to_fetch=()
          for num in "${selected_indices[@]}"; do
            if [ "$num" -ge 1 ] && [ "$num" -le "${#valid_files[@]}" ]; then
              idx=$((num - 1))
              cand_file="${valid_files[$idx]}"
              if [ ! -f "${rp}/${cand_file}" ]; then
                if [[ ! " ${files_to_fetch[*]} " =~ " ${cand_file} " ]]; then
                  files_to_fetch+=("$cand_file")
                fi
              fi
            fi
          done

          if [ ${#files_to_fetch[@]} -eq 0 ]; then
            _w "Seluruh nomor yang dipilih sudah berstatus [ lokal ready ] atau di luar jangkauan."
            sleep 1.5
            continue
          fi

          _ic "Mengaktifkan ${#files_to_fetch[@]} berkas ke lokal secara massal..."

          # Eksekusi massal sekaligus dalam satu gelombang (Jauh lebih cepat daripada satu per satu)
          git -C "$rp" sparse-checkout add "${files_to_fetch[@]}" >/dev/null 2>&1
          git -C "$rp" update-index --no-skip-worktree "${files_to_fetch[@]}" >/dev/null 2>&1

          if ! git -C "$rp" checkout-index --prefix="" --force -- "${files_to_fetch[@]}" 2>/dev/null; then
            git -C "$rp" checkout "$current_branch" -- "${files_to_fetch[@]}" >/dev/null 2>&1
          fi

          _o "${#files_to_fetch[@]} file berhasil diunduh dan berstatus [ lokal ready ]!"
          sleep 1.2
        done
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
          # =================================================================
          # PENYESUAIAN UTAMA: PISAHKAN TIPE DAN NAMA DARI ARRAY TARGETS
          # =================================================================
          baris_mentah="${targets[$idx]}"
          tipe_item="${baris_mentah%%	*}"
          selected_folder="${baris_mentah#*	}" # <-- Sekarang variabel ini murni nama folder/file saja!
          
          target_folder_fisik="${rp}/${selected_folder}"
        else
          _an "Pilihan tidak valid. Silakan masukkan nomor atau opsi yang tertera."
          _pp
          continue 1
        fi

        # CEK JIKA FOLDER TARGET SUDAH AKTIF (AKAN MELAKUKAN PROSES PENONAKTIFAN)
        # CEK AKTIF BERDASARKAN FISIK LOKAL
        # TOGGLE SYSTEM: Cek keaktifan murni berdasarkan manifes virtual batiniah skrip
        if grep -qx "${selected_folder}" "$virtual_manifest_file" 2>/dev/null; then
          _w "Item /${selected_folder} saat ini terdaftar AKTIF."

          # target_folder_fisik="${rp}/${selected_folder}"
          # Cek status modifikasi fisik lokal (jika ada file di dalam folder tersebut yang sempat diunduh)
          # 1. DETEKSI PERUBAHAN LOKAL & FILE UNTRACKED DI FOLDER SPESIFIK INI
          perubahan_folder=""
          if [ -d "$target_folder_fisik" ]; then
            perubahan_folder=$(git -C "$rp" status --porcelain=v1 --untracked-files=all "$selected_folder" 2>/dev/null | grep -v '^ D')
          fi

          if [ -n "$perubahan_folder" ]; then
            log_critical "Terdeteksi berkas UNTRACKED / MODIFIED di dalam /${selected_folder}!"
            echo -e "${RED}Berkas berikut belum di-commit dan akan HILANG PERMANEN:${NC}"
            echo "$perubahan_folder"
            echo "------------------------------------------------------"
            _pd "Apakah Anda YAKIN ingin MEMUSHNAKAN folder ini beserta isinya?"
          else
          _pd "Apakah Anda ingin MENONAKTIFKAN & HAPUS FISIK folder ini dari penyimpanan?"
          fi

          read -r konfirmasi_nonaktif
          
          if [[ "$konfirmasi_nonaktif" =~ ^[yY]$ ]]; then
            _ic "Memproses penonaktifkan folder /${selected_folder}..."

            # Menghapus folder dari file manifest virtual
            # Menggunakan grep -v untuk membuang baris yang sama persis
            # tampung_manifest=$(grep -vX "${selected_folder}" "$virtual_manifest_file" 2>/dev/null)
            # echo "$tampung_manifest" > "$virtual_manifest_file"

            # Hapus nama folder dari database manifest teks internal skrip
            # Hapus dari manifest virtual teks skrip
            sed -i "/^${selected_folder}$/d" "$virtual_manifest_file"

            # Membuat daftar baru yang mengecualikan folder terpilih
            # Menyusun daftar sparse checkout baru dengan mengecualikan folder terpilih
            # Menyusun kembali aturan sparse checkout git asli berdasarkan manifes yang tersisa
            new_sparse_list=()
            # Pastikan README.md atau rules default dasar tetap ada
            new_sparse_list+=("!/*") # Aturan pengaman dasar default

            while IFS= read -r line || [[ -n "$line" ]]; do
              [ -n "$line" ] && new_sparse_list+=("/${line}")
            done < "$virtual_manifest_file"

            # Terapkan ulang daftar sparse-checkout yang baru
            if git -C "$rp" sparse-checkout set --no-cone "${new_sparse_list[@]}"; then
              _o "Folder /${selected_folder} BERHASIL dinonaktifkan dari Git!"
            else
              _e "Gagal memperbarui sparse-checkout list."
              sleep 1.5
              continue 1
            fi

            # Seketika hapus folder fisik lokal jika ada
            # 3. Musnahkan wujud fisik sisa download di disk lokal (kembali ke 0-byte sejati)
            # if [ -d "$target_folder_fisik" ]; then
            #   _ic "Memusnahkan direktori fisik lokal secara otomatis..."
            #   rm -rf "$target_folder_fisik"
            #   _o "Folder fisik '${selected_folder}' berhasil dihapus sepenuhnya."
            # fi

            # =================================================================
            # KOREKSI & OPTIMASI PARALEL KILAT UNTUK PEMBERSIHAN DISK
            # =================================================================
            _ic "Membersihkan metadata indeks dan wujud fisik sisa secara aman..."

            # =================================================================
            # KOREKSI & OPTIMASI PARALEL KILAT UNTUK PEMBERSIHAN DISK & INDEKS
            # =================================================================
            _ic "Mengembalikan flag skip-worktree dan membersihkan fisik sisa secara aman..."

            # A. Kembalikan bit skip-worktree untuk seluruh file di dalam folder ini
            #    agar Git tidak menganggapnya terhapus (' D') setelah rm -rf
            git -C "$rp" ls-files -z -- "$selected_folder" 2>/dev/null | \
              xargs -0 -r git -C "$rp" update-index --skip-worktree -- 2>/dev/null
            
            # C. Gunakan pembacaan internal pohon kerja instan (Sangat Ringan dibanding read-tree -mu)
            # C. Segarkan indeks biner secara ringan
            git -C "$rp" update-index --refresh &>/dev/null
            
            # D. Hapus folder fisik lokal jika tersisa untuk mengembalikan status 0-byte sejati
            if [ -d "$target_folder_fisik" ]; then
              rm -rf "$target_folder_fisik"
            fi
            
            # C. ELIMINASI: Menghapus perintah 'git gc --prune=now' yang memicu hang/freeze berat di Termux
            # Basis data Git dibiarkan dikompresi berkala secara alami saja.

            _o "Item /${selected_folder} berhasil disusutkan kembali ke status 0-byte sejati!"
            sleep 1

          else
            _c "Tindakan dibatalkan. Folder tetap aktif aman."
            sleep 0.5
          fi
        else
          # Jika belum aktif, lakukan proses ADD seperti semula
          # JIKA FOLDER BELUM AKTIF (AKAN MELAKUKAN PROSES AKTIVASI / ADD FOLDER)
          # PERBAIKAN: Jika belum ada, cukup daftarkan polanya secara virtual (TANPA git checkout penuh)
          # PROSEDUR AKTIVASI VIRTUAL (0-BYTE DISK SEJATI)
          _ic "Mendaftarkan /${selected_folder} ke manifest virtual memori..."
          # Cukup catat namanya di file manifest batiniah (DISK TETAP KOSONG / 0-BYTE)
          if echo "${selected_folder}" >> "$virtual_manifest_file"; then
            _o "Berhasil ditambahkan ke daftar pantau virtual!"
            _ic "Gunakan opsi [e] untuk menjelajahi dan mengedit file secara On-Demand."
            sleep 1.5
          else
            _e "Gagal menambahkan folder ke virtual_manifest_file."
            _pp
          fi
        fi # end if target selection check

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

---

<br>

---

<br>

---

qc: menambahkan deteksi otomatis `force-with-lease` di dalam opsi! `[q]` ketika riwayat lokal divergen akibat reset pointer `[v]` -> `[r]` , sehingga proses push ke GitHub juga bisa langsung dilakukan dari menu `[q]` tanpa mengetik perintah manual di terminal

---

aa: 
Untuk menambahkan deteksi otomatis `--force-with-lease` pada opsi `[q]` ketika riwayat lokal divergen (baik karena reset pointer di `[v]` → `[r]` maupun penulisan ulang commit di `[i]`), Anda dapat `memperbarui bagian 5 (Radar Pre-Emption & Evaluasi Sinkronisasi Push)` di dalam blok `[qq]`).

## Kode Pembaruan untuk Blok `[qq]` (Bagian 5)

Ganti mulai dari komentar `# 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH` hingga penutup `;;` di blok `[qq]`) pada `main.sh` Anda dengan kode berikut:

```bash
        # 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH (DENGAN DETEKSI DIVERGEN)
        mapfile -t semua_remote < <(git -C "$rp" remote 2>/dev/null)
        status_konflik_terdeteksi=0
        status_divergen_terdeteksi=0
        _ic "Menjalankan radar Pre-Emption pada ${#semua_remote[@]} remote server..."

        for rm_name in "${semua_remote[@]}"; do
          behind_commits=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
          ahead_check=$(git -C "$rp" rev-list --count "refs/remotes/${rm_name}/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${behind_commits:-0}" -gt 0 ] && [ "${ahead_check:-0}" -gt 0 ]; then
            # Kondisi Divergen (Terjadi pasca Reset Pointer [v]->[r] & Injeksi ulang)
            _w "RIWAYAT DIVERGEN pada [${rm_name}]: Lokal maju ${ahead_check} commit, Remote tertinggal/berbeda ${behind_commits} commit."
            status_divergen_terdeteksi=1
          elif [ "${behind_commits:-0}" -gt 0 ]; then
            # Kondisi Tertinggal Murni (Remote punya commit baru yang belum ada di lokal)
            _e "KONFLIK TERDETEKSI: Remote [${rm_name}] lebih maju ${behind_commits} commit!"
            status_konflik_terdeteksi=1
          fi
        done

        # KASUS A: REMOTE LEBIH MAJU MURNI (BLOKIR PUSH NORMAL, TAWARKAN INSPEKSI)
        if [ "$status_konflik_terdeteksi" -eq 1 ] && [ "$status_divergen_terdeteksi" -eq 0 ]; then
          log_critical "Proses Multi-Push DIBLOKIR demi keamanan data!"
          _w "Remote memiliki commit lebih baru. Lakukan 'git pull' manual atau gunakan Reset [v]->[r]."
          _line "-" 50 "$FG_REDUP"
          _p "Apakah Anda ingin mengintip daftar file yang berbeda di remote? (y/n)"
          read -r intip_diff

          if [[ "$intip_diff" =~ ^[yY]$ ]]; then
            _cc "=== DAFTAR PERUBAHAN BERKAS DI SERVER REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              behind_check=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
              if [ "${behind_check:-0}" -gt 0 ]; then
                _ic "Berkas berbeda pada Remote [${rm_name}] (Branch: ${current_branch}):"
                git -C "$rp" diff-tree -r --no-commit-id --name-status "refs/heads/${current_branch}" "refs/remotes/${rm_name}/${current_branch}" | while read -r status file; do
                  case "$status" in
                    A) echo -e "  ${FG_GREEN}[Ditambahkan di Server]${NC} -> $file" ;;
                    M) echo -e "  ${FG_YELLOW}[Dimodifikasi di Server]${NC} -> $file" ;;
                    D) echo -e "  ${RED}[Dihapus di Server]${NC} -> $file" ;;
                    *) echo -e "  [Perubahan: $status] -> $file" ;;
                  esac
                done
              fi
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali ke menu utama"
            read -r _
          fi
          sleep 1

        # KASUS B: RIWAYAT DIVERGEN (OTOMATIS TAWARKAN --force-with-lease)
        elif [ "$status_divergen_terdeteksi" -eq 1 ]; then
          _line "-" 50 "$FG_YELLOW"
          _w "Terdeteksi perubahan riwayat commit (hasil Reset Pointer [v]->[r] atau amend)."
          _menu_opt "1" "$FG_YELLOW" "Force Push Aman (--force-with-lease)" "(Timpa riwayat remote dengan lokal)"
          _menu_opt "2" "$FG_CYAN"   "Intip Perbedaan File (Local vs Remote)"
          _menu_opt "3" "$FG_REDUP"  "Batal & Simpan Lokal Saja"
          _line "-" 50 "$FG_YELLOW"
          _p "Pilih tindakan sinkronisasi (1/2/3)"
          read -r aksi_divergen

          if [ "$aksi_divergen" == "1" ]; then
            log_critical "PERINGATAN: Riwayat remote [${current_branch}] akan ditulis ulang sesuai lokal!"
            _p "Ketik 'FORCE' (huruf besar) untuk konfirmasi push --force-with-lease"
            read -r konf_force

            if [ "$konf_force" == "FORCE" ]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Menjalankan git push --force-with-lease ${rm_target} ${current_branch}..."
                if git -C "$rp" push --force-with-lease -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Force-Push Aman ke [${rm_target}] SUKSES!"
                else
                  _e "Gagal melakukan force-push ke [${rm_target}]! Periksa lease/jaringan/SSH Anda."
                fi
              done
            else
              _an "Konfirmasi dibatalkan. Force-push tidak dijalankan."
            fi
          elif [ "$aksi_divergen" == "2" ]; then
            _cc "=== PERBANDINGAN FILE LOCAL VS REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              _ic "Remote [${rm_name}]:"
              git -C "$rp" diff --stat --color=always "refs/remotes/${rm_name}/${current_branch}" "refs/heads/${current_branch}"
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali"
            read -r _
          else
            _r "Force-push dibatalkan. Perubahan tetap tersimpan di lokal."
          fi

        # KASUS C: FAST-FORWARD NORMAL (LOKAL LEBIH MAJU TANPA DIVERGEN)
        else
          ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${ahead_commits:-0}" -gt 0 ]; then
            _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
            _p "Apakah Anda yakin ingin melakukan MULTI-PUSH ke semua remote sekarang? (y/n)"
            read -r konfirmasi_push

            if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Melakukan git push ${rm_target} ${current_branch}..."
                if git -C "$rp" push -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Push ke [${rm_target}] SUKSES!"
                else
                  _a "Gagal melakukan push ke [${rm_target}]! Periksa koneksi atau kredensial SSH Anda."
                fi
              done
            else
              _r "Push massal dibatalkan. Perubahan Anda tetap aman tersimpan di lokal."
            fi
          else
            _o "Status: Sinkron! Seluruh Remote server sama dengan Log Local Anda."
            continue 1
          fi
        fi

        _on "Selesai dengan sukses! Keluar dari skrip."
        continue 1
        ;;

```

## Cara Kerja Deteksi Otomatis Ini

| Kondisi Riwayat ( Local vs Remote ) | Deteksi Skrip | Tindakan di Menu `[q]` |
| :--- | :--- | :--- |
| **Ahead > 0, Behind = 0** (Commit baru normal) | Fast-Forward Normal | Menawarkan `git push` standar ke semua remote. |
| **Ahead > 0, Behind > 0** (Pasca `[v]` → `[r]` + injeksi) | Divergen Terdeteksi | Otomatis membuka opsi `--force-with-lease` dengan verifikasi ketik `FORCE`. |
| **Ahead = 0, Behind > 0** (Remote punya update baru, lokal belum) | Konflik Tertinggal | Memblokir push agar commit di server tidak tertimpa secara tidak sengaja. |
| **Ahead = 0, Behind = 0** (Setelah Reset Pointer tanpa commit baru) | Tersinkronisasi (0-0) | Catatan: Jika Anda hanya mereset mundur tanpa menambah commit baru, `ahead_check` bernilai `0` sehingga masuk ke Kasus A (bisa intip diff atau reset ulang). |

(_Catatan: Untuk memastikan SSH key yang benar selalu dipakai saat push otomatis di atas, pastikan konfigurasi `core.sshCommand` sudah tersimpan di `.git/config` lokal—pada `main.sh`. Anda, konfigurasi tersebut sudah otomatis diset saat inisialisasi awal._) ⓘ

---

qa: 
Apakah Anda juga ingin menambahkan dukungan `--force-with-lease` saat kondisi **Ahead = 0, Behind > 0** (misalnya jika Anda mereset mundur branch di `[v]` → `[r]` lalu ingin langsung menghapus commit teratas di GitHub tanpa membuat commit baru)?

---

qc: 
menambahkan deteksi otomatis `force-with-lease` di dalam opsi! `[q]` ketika riwayat lokal divergen akibat reset pointer `[v]` -> `[r]` , sehingga proses push ke GitHub juga bisa langsung dilakukan dari menu `[q]` tanpa mengetik perintah manual di terminal

---

aa: 
Untuk menambahkan deteksi otomatis `--force-with-lease` pada opsi `[q]` ketika riwayat lokal divergen (atau ketika lokal di-reset mundur via `[v]` $\rightarrow$ `[r]`), perbarui **bagian 5 (Radar Pre-Emption & Evaluasi Sinkronisasi Push)** di dalam blok `[qQ]` pada `main.sh` Anda.

## Kode Pembaruan Lengkap Blok `[qQ]` (Mulai Bagian 5)

Ganti mulai dari baris `# 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH` hingga penutup `;;` pada blok `[qQ]` dengan kode berikut:

```bash
        # 5. RADAR PRE-EMPTION & EVALUASI SINKRONISASI PUSH (DENGAN DETEKSI DIVERGEN)
        mapfile -t semua_remote < <(git -C "$rp" remote 2>/dev/null)
        status_konflik_terdeteksi=0
        status_divergen_terdeteksi=0
        _ic "Menjalankan radar Pre-Emption pada ${#semua_remote[@]} remote server..."

        for rm_name in "${semua_remote[@]}"; do
          behind_commits=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
          ahead_check=$(git -C "$rp" rev-list --count "refs/remotes/${rm_name}/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${behind_commits:-0}" -gt 0 ] && [ "${ahead_check:-0}" -gt 0 ]; then
            # Kondisi Divergen: Lokal di-reset mundur lalu ditambah commit baru
            _w "RIWAYAT DIVERGEN pada [${rm_name}]: Lokal maju ${ahead_check} commit, Remote berbeda ${behind_commits} commit."
            status_divergen_terdeteksi=1
          elif [ "${behind_commits:-0}" -gt 0 ]; then
            # Kondisi Tertinggal Murni: Bisa karena remote lebih baru ATAU lokal baru di-reset mundur tanpa commit baru
            _e "PERBEDAAN RIWAYAT: Remote [${rm_name}] memiliki ${behind_commits} commit yang tidak ada di Lokal!"
            status_konflik_terdeteksi=1
          fi
        done

        # KASUS A: REMOTE MEMILIKI COMMIT LEBIH BANYAK (BEHIND > 0, AHEAD = 0)
        if [ "$status_konflik_terdeteksi" -eq 1 ] && [ "$status_divergen_terdeteksi" -eq 0 ]; then
          log_critical "Riwayat Lokal tertinggal/lebih mundur dari Remote!"
          _menu_opt "1" "$FG_CYAN"   "Intip Daftar File yang Berbeda di Remote"
          _menu_opt "2" "$FG_YELLOW" "Force Push Mundur (--force-with-lease)" "(Jika sengaja reset via [v]->[r])"
          _menu_opt "3" "$FG_REDUP"  "Batalkan & Kembali ke Menu"
          _line "-" 50 "$FG_REDUP"
          _p "Pilih tindakan Anda (1/2/3)"
          read -r aksi_behind

          if [ "$aksi_behind" == "1" ]; then
            _cc "=== DAFTAR PERUBAHAN BERKAS DI SERVER REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              behind_check=$(git -C "$rp" rev-list --count "refs/heads/${current_branch}..refs/remotes/${rm_name}/${current_branch}" 2>/dev/null)
              if [ "${behind_check:-0}" -gt 0 ]; then
                _ic "Berkas berbeda pada Remote [${rm_name}] (Branch: ${current_branch}):"
                git -C "$rp" diff-tree -r --no-commit-id --name-status "refs/heads/${current_branch}" "refs/remotes/${rm_name}/${current_branch}" | while read -r status file; do
                  case "$status" in
                    A) echo -e "  ${FG_GREEN}[Ditambahkan di Server]${NC} -> $file" ;;
                    M) echo -e "  ${FG_YELLOW}[Dimodifikasi di Server]${NC} -> $file" ;;
                    D) echo -e "  ${RED}[Dihapus di Server]${NC} -> $file" ;;
                    *) echo -e "  [Perubahan: $status] -> $file" ;;
                  esac
                done
              fi
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali ke menu"
            read -r _
          elif [ "$aksi_behind" == "2" ]; then
            log_critical "PERINGATAN: Commit teratas di Remote [${current_branch}] akan dihapus mengikuti Lokal!"
            _p "Ketik 'FORCE' (huruf besar) untuk konfirmasi push --force-with-lease"
            read -r konf_force_behind
            if [ "$konf_force_behind" == "FORCE" ]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Menjalankan git push --force-with-lease ${rm_target} ${current_branch}..."
                if git -C "$rp" push --force-with-lease -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Force-Push Aman ke [${rm_target}] SUKSES!"
                else
                  _e "Gagal melakukan force-push ke [${rm_target}]! Periksa lease/jaringan/SSH Anda."
                fi
              done
            else
              _an "Konfirmasi dibatalkan. Force-push tidak dijalankan."
            fi
          else
            _r "Proses dibatalkan. Kembali ke menu..."
          fi
          sleep 1

        # KASUS B: RIWAYAT DIVERGEN (AHEAD > 0 DAN BEHIND > 0)
        elif [ "$status_divergen_terdeteksi" -eq 1 ]; then
          _line "-" 50 "$FG_YELLOW"
          _w "Terdeteksi perubahan riwayat commit (hasil Reset Pointer [v]->[r] & injeksi ulang)."
          _menu_opt "1" "$FG_YELLOW" "Force Push Aman (--force-with-lease)" "(Timpa riwayat remote dengan lokal)"
          _menu_opt "2" "$FG_CYAN"   "Intip Perbedaan File (Local vs Remote)"
          _menu_opt "3" "$FG_REDUP"  "Batal & Simpan Lokal Saja"
          _line "-" 50 "$FG_YELLOW"
          _p "Pilih tindakan sinkronisasi (1/2/3)"
          read -r aksi_divergen

          if [ "$aksi_divergen" == "1" ]; then
            log_critical "PERINGATAN: Riwayat remote [${current_branch}] akan ditulis ulang sesuai lokal!"
            _p "Ketik 'FORCE' (huruf besar) untuk konfirmasi push --force-with-lease"
            read -r konf_force

            if [ "$konf_force" == "FORCE" ]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Menjalankan git push --force-with-lease ${rm_target} ${current_branch}..."
                if git -C "$rp" push --force-with-lease -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Force-Push Aman ke [${rm_target}] SUKSES!"
                else
                  _e "Gagal melakukan force-push ke [${rm_target}]! Periksa lease/jaringan/SSH Anda."
                fi
              done
            else
              _an "Konfirmasi dibatalkan. Force-push tidak dijalankan."
            fi
          elif [ "$aksi_divergen" == "2" ]; then
            _cc "=== PERBANDINGAN FILE LOCAL VS REMOTE ==="
            for rm_name in "${semua_remote[@]}"; do
              _ic "Remote [${rm_name}]:"
              git -C "$rp" diff --stat --color=always "refs/remotes/${rm_name}/${current_branch}" "refs/heads/${current_branch}"
            done
            _line "=" 50 "$FG_CYAN"
            _p "Tekan [Enter] untuk kembali"
            read -r _
          else
            _r "Force-push dibatalkan. Perubahan tetap tersimpan di lokal."
          fi

        # KASUS C: FAST-FORWARD NORMAL (AHEAD > 0, BEHIND = 0)
        else
          ahead_commits=$(git -C "$rp" rev-list --count "refs/remotes/origin/${current_branch}..refs/heads/${current_branch}" 2>/dev/null)

          if [ "${ahead_commits:-0}" -gt 0 ]; then
            _r "Status: Local Anda lebih maju ${ahead_commits} commit dari Remote."
            _p "Apakah Anda yakin ingin melakukan MULTI-PUSH ke semua remote sekarang? (y/n)"
            read -r konfirmasi_push

            if [[ "$konfirmasi_push" =~ ^[yY]$ ]]; then
              for rm_target in "${semua_remote[@]}"; do
                _ic "Melakukan git push ${rm_target} ${current_branch}..."
                if git -C "$rp" push -q "${rm_target}" "${current_branch}" 2>/dev/null; then
                  _o "Push ke [${rm_target}] SUKSES!"
                else
                  _a "Gagal melakukan push ke [${rm_target}]! Periksa koneksi atau kredensial SSH Anda."
                fi
              done
            else
              _r "Push massal dibatalkan. Perubahan Anda tetap aman tersimpan di lokal."
            fi
          else
            _o "Status: Sinkron! Seluruh Remote server sama dengan Log Local Anda."
            continue 1
          fi
        fi

        _on "Selesai dengan sukses! Keluar dari skrip."
        continue 1
        ;;

```

---

## Ringkasan Skenario yang Ditangani Otomatis di `[q]`

| Skenario Penggunaan | Status Git ( Ahead / Behind ) | Perilaku Otomatis Menu `[q]` |
| :--- | :--- | :--- |
| Commit normal (edit file atau injeksi baru tanpa reset) | Ahead > 0 , Behind = 0 | Menawarkan `git push` biasa (Fast-Forward). |
| Reset mundur `[V]` → `[R]` lalu injeksi file baru `[i]` | Ahead > 0 , Behind > 0 | Otomatis masuk **Kasus B (Divergen)** dan menawarkan `git push --force-with-lease` dengan konfirmasi **FORCE** . |
| Reset mundur `[V]` → `[R]` saja tanpa injeksi ulang | Ahead = 0 , Behind > 0 | Otomatis masuk **Kasus A** yang memungkinkan intip file remote atau `git push --force-with-lease` untuk memaksa commit di GitHub. |
| Tidak ada perubahan | Ahead = 0 , Behind = 0 | Menampilkan status `Sinkron` dan langsung kembali ke menu. |

(Catatan: Perintah `git push --force-with-lease` di atas otomatis menggunakan SSH key masing-masing owner karena `core.sshCommand` sudah terkunci di `.git/config` lokal saat inisialisasi awal).

---

qa: 
Apakah Anda juga ingin menambahkan **jalur pintas (shortcut)** di akhir menu `[i]` setelah semua file selesai diinjeksi agar bisa langsung menjalankan `[q]` (sinkronisasi & force-push ke GitHub) tanpa kembali ke menu utama terlebih dahulu?

---

<br>

---

<br>

---
























<br>
