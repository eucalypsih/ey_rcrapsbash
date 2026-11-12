# 


Untuk menampilkan teks berwarna **biru (BLUE) di terminal Bash Linux**, Anda dapat menggunakan kode *escape* ANSI.

Untuk membuat variabel `LIGHT_GRAY` yang berisi kode warna abu-abu muda di Bash, gunakan kode berikut:
Untuk membuat variabel `BLUE` yang berisi kode warna biru di Bash, gunakan kode berikut:
```bash
LIGHT_GRAY='\033[0;37m';
```
`LIGHT_GRAY='\033[0;37m';`

---

Kode Warna Biru
- Biru Standar: \e[34m
- Biru Muda / Terang: \e[94m
- Reset Warna (Kembali ke Normal): \e[0m (Wajib digunakan di akhir teks agar semua teks terminal setelahnya tidak ikut berwarna biru).
```bash
BLUE='\033[0;34m';
```
`BLUE='\033[0;34m';`

---



## Opsi Lain: Format 256-Warna
Jika terminal Anda mendukung 256 warna dan Anda ingin warna abu-abu yang lebih spesifik, Anda bisa menggunakan format ini:
```bash
LIGHT_GRAY='\033[38;5;250m' # Menggunakan indeks warna 250
```
`LIGHT_GRAY='\033[38;5;250m' # Menggunakan indeks warna 250`




## Cara Menggunakannya dalam Script
## Cara Menggunakan di Script Bash
### 1. Menggunakan Perintah `echo`
Pastikan Anda menambahkan flag `-e` agar perintah echo membaca kode escape.
Anda harus menggunakan perintah `echo -e` agar Bash mengenali kode *escape sequence* warna tersebut. Selalu gunakan variabel reset warna (`NC` atau *No Color*) di akhir teks agar warna terminal kembali normal.
```bash
#!/bin/bash

# Definisikan warna
LIGHT_GRAY='\033[0;37m'
NC='\033[0m' # No Color (Kembali ke default)

# Contoh penggunaan
echo -e "${LIGHT_GRAY}Teks ini berwarna abu-abu muda.${NC}"
echo "Teks ini kembali ke warna normal."

```

```bash
# Biru Standar
echo -e "\e[34mIni adalah teks berwarna biru standar\e[0m"

# Biru Muda
echo -e "\e[94mIni adalah teks berwarna biru muda\e[0m"

```

### 2. Membuat Variabel Warna (Sangat Direkomendasikan)
Agar *script* Anda lebih rapi dan mudah dibaca, simpan kode warna tersebut ke dalam variabel:
```bash
#!/bin/bash

# Definisikan variabel warna
BLUE='\e[34m'
LIGHT_BLUE='\e[94m'
NC='\e[0m' # No Color (Reset)

# Cara penggunaan
echo -e "${BLUE}Teks Biru${NC}"
echo -e "${LIGHT_BLUE}Teks Biru Muda${NC}"
echo "Ini kembali menjadi teks warna putih normal."

```

### Menggunakan Perintah `printf`
Alternatif selain `echo`, Anda juga bisa menggunakan `printf` yang tidak memerlukan flag `-e`:
```bash
printf "\e[34mTeks Biru dengan printf\e[0m\n"

```

```bash
BLUE='\033[0;34m'
NC='\033[0m'

printf "%bTeks Biru dengan printf%b\n" "$BLUE" "$NC"

```
- Gunakan \033 Sebagai Pengganti \e. Format \033 lebih portabel dan didukung oleh semua standar POSIX, sedangkan \e terkadang tidak dikenali di beberapa shell lama.
- Gunakan Penentu Format %b. Memasukkan variabel warna melalui argumen %b mencegah kesalahan jika teks yang dicetak mengandung karakter khusus seperti tanda persen (%).





```basb
#!/bin/bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "%b[INFO]%b Proses %bbackup%b selesai dengan %b2 peringatan%b.\n" \
  "$BLUE" "$NC" \
  "$GREEN" "$NC" \
  "$YELLOW" "$NC"

```



### Daftar Kode Warna Utama Lainnya

| Warna | Kode Standar | Kode Terang / Tebal |
| :--- | :--- | :--- |
| Merah (Red) | `\033[0;31m` | `\033[1;31m` |
| Hijau (Green) | `\033[0;32m` | `\033[1;32m` |
| Kuning (Yellow) | `\033[0;33m` | `\033[1;33m` |
| Biru (Blue) | `\033[0;34m` | `\033[1;34m` |
| Ungu (Purple) | `\033[0;35m` | `\033[1;35m` |
| Biru Muda (Cyan) | `\033[0;36m` | `\033[1;36m` |






<br>
