

---

Menampilkan Baris Spesifik Berdasarkan Nomor Baris

Jika dari perintah di atas Anda sudah tahu nomor barisnya (misalnya baris 1250), dan Anda ingin meloncat langsung untuk melihat baris 1250 sampai 1280, Anda bisa menggunakan `sed`:
```bash
sed -n '4063,4086p' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```
`sed -n '4063,4086p' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h`

---



<br>
