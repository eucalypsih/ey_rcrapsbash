

---

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

---

Menggunakan `sed` murni

Jika Anda wajib menggunakan `sed` saja, Anda bisa menggunakan perintah `=` untuk mencetak nomor baris, lalu menggabungkannya dengan `N` agar nomor baris dan teks berada di baris yang sama. Namun, formatnya agak kurang rapi dibanding `awk`.
```bash
sed -n '149,177{=;p;}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h | sed 'N;s/\n/: /'

```

---

Menggunakan `awk` (Direkomendasikan)

Jika Anda ingin nomor baris yang muncul **sesuai dengan nomor asli di dalam file** (baris 149 s.d 177 seperti `grep -n`), `awk` adalah solusi terbaik dan paling efisien.
```bash
awk 'NR>=149 && NR<=177 {print NR ":" $0}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

---










<br>
