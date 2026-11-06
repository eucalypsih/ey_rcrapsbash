# 



Untuk membuat variabel `LIGHT_GRAY` yang berisi kode warna abu-abu muda di Bash, gunakan kode berikut:
```bash
LIGHT_GRAY='\033[0;37m';
```
`LIGHT_GRAY='\033[0;37m';`

---

## Opsi Lain: Format 256-Warna
Jika terminal Anda mendukung 256 warna dan Anda ingin warna abu-abu yang lebih spesifik, Anda bisa menggunakan format ini:
```bash
LIGHT_GRAY='\033[38;5;250m' # Menggunakan indeks warna 250
```
`LIGHT_GRAY='\033[38;5;250m' # Menggunakan indeks warna 250`




## Cara Menggunakannya dalam Script
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





<br>
