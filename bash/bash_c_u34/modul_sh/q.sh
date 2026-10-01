#!/bin/bash

# --- IMPORT VISUAL LIBRARY ---
# =====================================================================
# MODUL EKSTERNAL: EVALUASI COMMIT, PERBANDINGAN LOG & AUTO-PUSH (q.sh)
# SOLUSI AMAN: Menyaring git status agar mengabaikan efek sparse-checkout
# Hanya mendeteksi berkas baru (??), modifikasi (M), atau hapus riil (ditrack lalu di-rm)
# =====================================================================

# 1. AMBIL FUNGSI WARNA & LOGGING (utils.sh berada di folder yang sama)
CURRENT_MODUL_DIR="$(dirname "$0")"
if [ -f "${CURRENT_MODUL_DIR}/utils.sh" ]; then
  source "${CURRENT_MODUL_DIR}/utils.sh"
else
  echo -e "\033[0;31m[X] FATAL: File utils.sh tidak ditemukan di folder ${CURRENT_MODUL_DIR}!\033[0m"
  exit 1
fi

# 2. TANGKAP VARIABEL DAN ARGUMEN DARI SKRIP UTAMA
rp="$1"
r="$2"
current_branch="$3"
targets=($4)         # Mengubah kembali string menjadi format Array lokal
current_sparse="$5"   # Menangkap status sparse-checkout aktif

# Pengaman awal: Jika argumen penting kosong, gagalkan proses demi keamanan Git
if [ -z "$rp" ] || [ -z "$current_branch" ]; then
  _e "Argumen evaluasi repositori tidak lengkap!"
  _pp
  exit 1
fi

# 3. DETEKSI PERUBAHAN LOKAL (Mengabaikan efek samping berkas sparse-checkout)
perubahan_lokal=$(git -C "$rp" status --porcelain 2>/dev/null | grep -E '^([ MAU?][M?]|[^D] )')

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
    _p "Ketik 'COMMIT' (huruf besar) untuk melanjutkan konfirmasi"
    read -r verifikasi_aman

    if [ "$verifikasi_aman" != "COMMIT" ]; then
      _an "Verifikasi gagal! Tindakan dibatalkan demi keamanan repositori Anda."
      sleep 2
      exit 0 # Menghentikan modul eksternal dan kembali aman ke menu interaktif utama
      # continue # Kembali ke menu seleksi folder sparse, tidak jadi keluar
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
  
    git -C "$rp" add .
    git -C "$rp" commit -m "$pesan_commit"
    _o "Perubahan berhasil disimpan ke commit lokal!"

  elif [ "$aksi_keluar" == "2" ]; then
    _w "Membuang perubahan lokal dan melakukan paksa checkout..."
    git -C "$rp" checkout -f "$current_branch" 2>/dev/null
  else
    _r "Membatalkan proses keluar. Kembali ke menu utama..."
    sleep 1
    # continue
    exit 0 # Kembali ke menu interaktif tanpa mengubah apa pun
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
exit 0
