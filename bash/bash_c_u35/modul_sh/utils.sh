#!/bin/bash
# utils.sh
# =====================================================================
# UTILS LIBRARY: PUSAT KENDALI WARNA & UX LOGGING (SHARED MODULE)
# =====================================================================

# Standardisasi Kode Warna UX Terminal (Gunakan format \e agar universal)
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CYAN='\e[36m'
PURPLE='\e[35m'
BOLD='\e[1m'
NC='\e[0m' # No Color (Reset)

# Fungsi Logging Visual Rapi
_cr() { echo -e "${RED}${BOLD}$1${NC}"; }
_cc() { echo -e "${CYAN}$1${NC}"; } # _color_cyan() { ... }
_o()  { echo -e "${GREEN}[✓] $1${NC}"; } # log_ok
_on() { echo ""; _o "$1"; } # Memanggil baris baru dulu, baru jalankan log_ok
_ic() { echo -e "${CYAN}[~] $1${NC}"; } # log_info
_nc() { echo -e "\n${CYAN}$1${NC}"; } # _color_cyan_end() { ... }
_in() { echo -e "\n${CYAN}[~] $1${NC}"; } # _info_color_cyan_end() { ... } log_step berfungsi memberikan jarak visual/ruang sebelum menampilkan status proses baru di terminal
log_section()  { echo -e "${PURPLE}${BOLD}--- $1 ---${NC}"; } # Judul section lebih rapi dengan warna ungu tebal

_c()   { echo -e "${YELLOW}[+] $1${NC}"; }
log_notify()   { echo -e "\n${YELLOW}[+] $1${NC}"; }
_r()  { echo -e "${YELLOW}[!] $1${NC}"; }
_rn() { echo -e "\n${YELLOW}[!] $1${NC}"; } # Fungsi untuk menampilkan status navigasi atau pengalihan menu
_w()  { echo -e "${YELLOW}${BOLD}[ ⚠️ ] Peringatan: $1${NC}"; } # log_warn
_hn() { echo -e "\n${RED}[!] $1${NC}"; }
_e()  { echo -e "${RED}[X] ERROR: $1${NC}"; } # log_err
log_fatal()    { echo -e "${RED}${BOLD}[X] FATAL ERROR: $1${NC}"; } # Fungsi untuk menampilkan kesalahan fatal (Fatal Error) sebelum skrip berhenti
log_detail()   { echo -e "${YELLOW}     -> $1${NC}"; }

# log_success() { echo -e "${GREEN}[✓] Sukses: $1${NC}"; }
_ls() { # log_success
  if [ -n "$2" ]; then
    # log_success "Branch saat ini terdeteksi" "$current_branch"
    # echo -e "${GREEN}[✓] Branch saat ini terdeteksi: ${YELLOW}${current_branch}${NC}"
    echo -e "${GREEN}[✓] $1: ${YELLOW}$2${NC}"
  else
    echo -e "${GREEN}[✓] Sukses: $1${NC}"
  fi
}

_p() {
  if [ -n "$3" ]; then
    # Jika ada argumen kedua, kita cetak teks kustom dengan warna dinamis
    echo -e -n "${YELLOW}[~] $1${GREEN}$2${YELLOW}$3${NC}"
  else
    # Jika hanya satu argumen, cetak prompt standar kuning
    echo -e -n "${YELLOW}[~] $1: ${NC}" # prompt() { ... } Fungsi untuk mencetak teks tanpa baris baru (biasanya untuk menunggu input 'read')
  fi
}

_a()   { echo -e "${RED}[X] $1${NC}"; }
_an()  { echo -e "\n${RED}[X] $1${NC}"; } # Fungsi untuk pembatalan / keluar dari skrip (menyertakan baris baru di awal)

# Fungsi untuk meminta konfirmasi tindakan berbahaya (menunggu input 'read')
_pd()  { echo -e -n "${RED}${BOLD}[⚠️] $1 (y/n): ${NC}"; }
log_critical() { echo -e "\n${RED}${BOLD}[⚠️] PERINGATAN KRITIS: $1${NC}"; }

# Fungsi untuk menahan layar dan meminta konfirmasi kembali (menunggu input 'read')
_pp() { # prompt_pause
  echo -e -n "${YELLOW}Tekan [Enter] untuk kembali...${NC}"
  read -r
}
