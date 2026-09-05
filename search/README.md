

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
<pre><code>1816:  FMT_CONSTEXPR void <span style="color: #ff4500; font-weight: bold;">push_back</span>(const T& value) {
2441:    container-><span style="color: #ff4500; font-weight: bold;">push_back</span>(c);</code></pre>


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

1. 
```bash
awk 'NR>=149 && NR<=177 {print NR ":" $0}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

2. 
```bash
awk 'NR>=1332 {print NR ":" $0} NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

qd:
```bash
awk 'NR>=1332 && NR<=1336 {print NR ":" $0} NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

awk 'NR>=1332 {print NR ":" $0} NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h
```
manakah yang lebih baik ?

aa:
Perintah **kedua jauh lebih baik** dari segi efisiensi penulisan kode (*code cleanliness*) tanpa mengorbankan performa.

Berikut adalah perbandingan mendalam mengapa perintah kedua lebih unggul:

`awk 'NR>=1332 {print NR ":" $0} NR==1336 {exit}' ...` (Pilihan Terbaik)
- **Lebih Efisien & Pendek**: Anda menghilangkan pemeriksaan kondisi `&& NR<=1336`.
- **Logika Sederhana**: Karena `awk` dipaksa berhenti tepat di baris 1336 (`NR==1336 {exit}`), maka secara otomatis `awk` **tidak akan pernah bisa** membaca atau mencetak baris 1337 ke atas. Batasan `NR<=1336` menjadi mubazir.

`awk 'NR>=1332 && NR<=1336 {print NR ":" $0} NR==1336 {exit}' ...`
- **Redundan (Mubazir)**: Di sini Anda melakukan pemeriksaan nomor baris sebanyak dua kali untuk batas atasnya (pertama di `NR<=1336`, kedua di `NR==1336`).
- Secara performa eksekusi pada komputer modern, perbedaannya sangat mikroskopis (hampir tidak terasa), namun kode ini menjadi lebih panjang dan kurang bersih dibaca.

Kesimpulan

Gunakan **perintah kedua**. Itu adalah cara paling *idiomatic* (lazim dan efisien) dalam menggunakan awk untuk mengambil rentang baris tertentu.

qa: Apakah Anda ingin melanjutkan dengan **mencari pola kata tertentu (seperti nama fungsi)** di dalam rentang baris tersebut menggunakan `awk` ?

qc: Saya ingin melanjutkan dengan **mencari pola kata tertentu (seperti nama fungsi)** di dalam rentang baris tersebut menggunakan `awk`

aa:
Untuk mencari pola kata tertentu (misalnya nama fungsi atau kata kunci) khusus di dalam rentang baris tersebut, Anda bisa menyisipkan kondisi pencocokan teks menggunakan operator ~ (match) atau `/pola/` di dalam perintah `awk`.

Berikut adalah beberapa cara terbaik yang bisa Anda gunakan:
Berikut adalah beberapa cara terbaik untuk bisa digunakan:

1. Hanya Mencetak Baris yang Cocok (Rekomendasi)
Jika Anda hanya ingin menampilkan baris di rentang 1332–1336 yang **mengandung kata tertentu** (misalnya kata `format`):
```bash
awk 'NR>=1332 { if ($0 ~ /format/) print NR ":" $0 } NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

2. Menyorot/Mewarnai Kata yang Dicari
Jika Anda ingin tetap mencetak semua baris (1332–1336), tetapi **kata yang dicari diberi warna merah** agar mudah dilihat di terminal, Anda bisa memanfaatkan fungsi `gsub` bawaan `awk`:
```bash
awk 'NR>=1332 { gsub(/format/, "\033[1;31m&\033[0m"); print NR ":" $0 } NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```
Note: Ganti kata format pada perintah di atas dengan nama fungsi atau pola yang sedang Anda cari.

3. Pencarian Tidak Sensitif Huruf Besar/Kecil (*Case-Insensitive*)
Jika Anda lupa apakah fungsi tersebut ditulis dengan huruf besar atau kecil (misal: `Format`, `FORMAT`, atau `format`), Anda bisa menambahkan fungsi `tolower()`:
```bash
awk 'NR>=1332 { if (tolower($0) ~ /format/) print NR ":" $0 } NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>

aa:
Untuk membuat perilaku `awk` sama persis dengan `sed -n '1332,1336p'`, Anda hanya perlu mencetak barisnya saja **tanpa menambahkan nomor baris (`NR ":"`)**.

Berikut adalah perintah `awk` yang perilakunya 100% identik dengan perintah `sed` tersebut:
```bash
awk 'NR>=1332 && NR<=1336' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>

Jika berkas `format.h` sangat besar, perintah di atas akan tetap membaca seluruh isi berkas sampai akhir meskipun baris 1336 sudah terlewati. Agar `awk` langsung **berhenti membaca (exit)** setelah baris 1336 (sama seperti efisiensi pada `sed`), Anda bisa menggunakan perintah ini:
```bash
awk 'NR>=3914; NR==3940{exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>

```bash
awk '{if(NR>=1439) print; if(NR==1446) exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>

```bash
awk 'NR==1439,NR==1446' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```

<br>

---

<br>

qs:
```bash
grep --color=always -n "push_back" $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/base.h

awk 'NR>=1332 { gsub(/format/, "\033[1;31m&\033[0m"); print NR ":" $0 } NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h
```
membuat awk beperilaku sama persis seperti grep

aa:
Untuk membuat `awk` berperilaku **sama persis seperti `grep --color=always -n "pola"`**, Anda harus melakukan tiga hal di dalam `awk`:
1. **Memfilter baris**: Hanya cetak baris yang mengandung pola tersebut.
2. **Menampilkan nomor baris**: Menggunakan format `NR:`.
3. **Mewarnai pola teks**: Menggunakan kode warna ANSI (`\033[1;31m`) lewat fungsi `gsub`.

Berikut adalah perintah `awk` yang perilakunya identik dengan perintah `grep` Anda untuk mencari kata `"push_back"` pada berkas `base.h`:
```bash
awk '/push_back/ { gsub(/push_back/, "\033[1;31m&\033[0m"); print NR ":" $0 }' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/base.h

```
🔍 Detail Komponen Warna:
- `\033[1;31m`: Mengaktifkan warna merah tebal (*bold red*) seperti warna bawaan `grep`.
- `&`: Variabel khusus `awk` yang berarti "teks yang cocok dengan pola" (dalam hal ini `push_back`).
- `\033[0m`: Mereset warna kembali ke normal agar teks setelahnya tidak ikut berwarna merah.

💡 Tips Gabungan (Mencari Pola + Batasan Baris + Exit)

Jika Anda ingin menggabungkan fitur pencarian ala grep ini dengan **batasan rentang baris (1332–1336) dan fitur `exit`** yang kita bahas sebelumnya di berkas `format.h`, gunakan perintah ini:
```bash
awk 'NR>=1332 { if ($0 ~ /push_back/) { gsub(/push_back/, "\033[1;31m&\033[0m"); print NR ":" $0 } } NR==1336 {exit}' $HOME/.cmake_fetchcontent_cache/fmt-v12.2.0/fmt-src/include/fmt/format.h

```











<br>







<br>
