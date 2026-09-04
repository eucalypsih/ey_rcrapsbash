

<br>

---

<br>

```bash
grep -n "push_back" $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/base.h

```

Terminal Ouput:
```bash
1816:  FMT_CONSTEXPR void push_back(const T& value) {
2441:    container->push_back(c);

```

<br>

```bash
grep --color=always -n "push_back" $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/base.h

```

Terminal Output:
```bash
1816:  FMT_CONSTEXPR void push_back(const T& value) {
2441:    container->push_back(c);

```

<br>

---

<br>

Jika Anda ingin agar grep selalu berwarna di setiap sesi terminal tanpa perlu mengetik `--color=always`, Anda bisa menambahkan alias ke dalam file konfigurasi shell Anda (`~/.bashrc` atau `~/.zshrc`):
```bash
alias grep='grep --color=auto'

```
NOTE: Menggunakan `--color=auto` adalah pilihan terbaik untuk alias karena hanya akan memberikan warna saat ditampilkan di layar, dan tidak akan merusak teks dengan kode warna aneh jika Anda melakukan piping ke perintah lain (seperti `grep ... | less`).

<br>

---

<br>

qa: Apakah dengan menggunakan `--color=always` tidak akan merusak teks dengan kode warna aneh jika Anda melakukan piping ke perintah lain (seperti `grep ... | less`).

aa:
Ya, menggunakan `--color=always` **justru AKAN merusak teks dan memunculkan kode warna aneh** (seperti `^[[31m`) jika Anda melakukan *piping* ke perintah lain seperti `less`, `more`, atau disimpan ke file teks.

Hal ini terjadi karena `--color=always` memaksa `grep` untuk menyisipkan karakter kontrol ANSI (kode warna) ke dalam teks output, tidak peduli apakah outputnya dibaca oleh layar terminal atau oleh program lain.

Agar tidak rusak saat menggunakan perintah `less`, Anda memiliki dua pilihan solusi:

1. Gunakan Opsi `-R` pada Perintah `less`
Jika Anda tetap ingin menggunakan `grep --color=always`, Anda harus memberi tahu `less` agar menerjemahkan kode warna tersebut dengan menambahkan opsi `-R` (Raw control characters):
```bash
grep --color=always -n "push_back" file.h | less -R

```

2. Gunakan `--color=auto` (Sangat Direkomendasikan)
- `grep` akan otomatis **memberikan warna** jika outputnya langsung dibaca oleh mata manusia di terminal.
- `grep` akan otomatis **menghilangkan kode warna** jika outputnya dioper (*piping*) ke perintah lain atau dimasukkan ke dalam file teks.
```bash
grep --color=auto -n "push_back" file.h | less

```

<br>

---

<br>

# baris

<br>

---

<br>

Menampilkan Baris Spesifik Berdasarkan Nomor Baris

Jika dari perintah di atas Anda sudah tahu nomor barisnya (misalnya baris 1250), dan Anda ingin meloncat langsung untuk melihat baris 1250 sampai 1280, Anda bisa menggunakan `sed`:

menampilkan nomor baris saat mengekstrak baris tertentu dengan `sed`
```bash
sed -n '4063,4086p' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```
`sed -n '4063,4086p' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h`

<br>

---

<br>

Menggunakan pipa (`|`) ke `cat -n` (Paling Mudah)

Anda tetap menggunakan perintah sed Anda, lalu melemparkan hasilnya ke `cat -n`. Namun, perlu dicatat bahwa `cat -n` akan memulai penomoran dari angka 1.
```bash
sed -n '149,177p' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h | cat -n

```

<br>

---

<br>

Menggunakan `sed` murni

Jika Anda wajib menggunakan `sed` saja, Anda bisa menggunakan perintah `=` untuk mencetak nomor baris, lalu menggabungkannya dengan `N` agar nomor baris dan teks berada di baris yang sama. Namun, formatnya agak kurang rapi dibanding `awk`.
```bash
sed -n '149,177{=;p;}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h | sed 'N;s/\n/: /'

```

<br>

---

<br>

Menggunakan `awk` (Direkomendasikan)

Jika Anda ingin nomor baris yang muncul **sesuai dengan nomor asli di dalam file** (baris 149 s.d 177 seperti `grep -n`), `awk` adalah solusi terbaik dan paling efisien.
```bash
awk 'NR>=149 && NR<=177 {print NR ":" $0}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>










<br>
