
- `grep -qE "^/?${selected_folder}/?$"`: Tanda tanya (`/?`) berarti garis miring di depan atau di belakang folder bersifat opsional. Ini menjamin status `[ sudah aktif ]` dan notifikasi already sinkron dengan apa yang terdaftar di Git internal, apa pun versi Git yang Anda gunakan di Termux.



<br>

---

<br>

qs: 
```bash
echo -e "${CYAN}[~] Menyiapkan inisialisasi awal sparse-checkout...${NC}"

```

Untuk melakukan **Find & Replace** menggunakan regex di text editor micro, Anda perlu memanfaatkan fitur *Capture Group* (mengurung teks yang ingin dipertahankan dengan tanda kurung `(...)`).

Berikut adalah pola pencarian dan penggantian yang harus Anda masukkan di micro:

## 1. Pola Pencarian (Find)
Tekan `Ctrl+F` atau buka command mode (tekan `Ctrl+E` lalu ketik `find`), kemudian masukkan regex berikut:
```bash
echo -e "\$\{CYAN\}\[~\] ([^"\r\n]+)\$\{NC\}"
echo -e "\$\{CYAN\}\[~\].*?\$\{NC\}"

```
> 💡 Catatan: Tanda kurung `([^"\r\n]+)` berfungsi untuk "menangkap" teks pesan di dalamnya (misalnya: Menyiapkan inisialisasi awal sparse-checkout...) agar bisa dipanggil kembali saat proses replace.

## 2. Pola Penggantian (Replace)
Tekan `Ctrl+E` untuk membuka command mode di bagian bawah micro, lalu ketik perintah `replace` berikut dan tekan **Enter**:
```bash
replace "echo -e \"\$\{CYAN\}\[~\] ([^\"\r\n]+)\$\{NC\}\"" "log_info \"$1\""

```
atau
```bash
replace 'echo -e "\$\{CYAN\}\[~\] (.*?)\$\{NC\}"' 'log_info "$1"'

```
`log_info "Menyiapkan inisialisasi awal sparse-checkout..."`

reverse
```bash
replace 'log_info "(.*?)"' 'echo -e "\$\{CYAN\}\[~\] $1\$\{NC\}"'

```

- ! 
```bash
replace 'echo -e "\$\{YELLOW\}(?!\[\+\]|\[!\]|\[~\])(.*?)\$\{NC\}"' 'log_abort "\\n$1"'

```








<br>
