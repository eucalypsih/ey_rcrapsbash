#

[micro editor](https://github.com/micro-editor/micro)

<br>

---

<br>

## Mengaktifkan Sementara (Lewat Command Mode/Bar)
## Langsung dari Dalam Editor (Sementara/Sesi Ini)
Jika Anda hanya ingin mengaktifkannya pada sesi editor yang sedang terbuka:
1. Buka editor Micro Anda.
2. Tekan tombol `Ctrl + E` untuk membuka baris perintah (command mode/bar) di bagian bawah.
3. Ketik perintah berikut lalu tekan `Enter`:
```bash
setlocal autoclose false
```
```basb
setlocal softwrap true
```
(Catatan: Anda juga bisa mengetik `setlocal softwrap on`).*

<br>

---

<br>

## Mengaktifkan Permanen (Untuk Seterusnya)
Agar fitur ini selalu aktif setiap kali Anda membuka aplikasi Micro, Anda bisa mengaturnya secara permanen dengan dua cara:

### Cara A: Lewat/Melalui Perintah Bar (Command Bar)

1. Buka editor Micro Anda.
2. Tekan tombol `Ctrl + E` untuk membuka baris perintah (command mode/bar) di bagian bawah.
3. Ketik perintah berikut lalu tekan `Enter`:
```bash
set softwrap true
```
4. (*Opsional*) Agar pemotongan baris lebih rapi dan mengikuti batas kata (tidak memotong di tengah-tengah suku kata), aktifkan juga fitur **wordwrap** dengan mengetik:
```bash
set wordwrap true
```

<br>

---

<br>

### Cara B: Mengedit File Konfigurasi (`settings.json`)
### Cara B: Secara Permanen via File Konfigurasi (`settings.json`)
Buka atau edit langsung file konfigurasi Micro yang terletak di direktori internal Anda:
Agar pengaturan ini tidak hilang saat editor ditutup, Anda harus menyimpannya secara permanen.
Tambahkan atau ubah baris konfigurasi berikut di dalam tanda kurung kurawal `{}`.
1. Buka file konfigurasi utama Micro. Biasanya terletak di:
- Linux/macOS: `~/.config/micro/settings.json`
- Windows: `%USERPROFILE%\.config\micro\settings.json`
2. Tambahkan atau ubah baris `"autoclose"` menjadi `false`. Contoh isi file `settings.json`:
```json
{
    "autoclose": false
}

```
3. Simpan file tersebut.

Setelah opsi ini dimatikan, Micro tidak akan lagi otomatis membuat pasangan penutup saat Anda mengetik `{`, `[`, `(`, `"`, `'`, atau `` `.

<br>

---

<br>

# Beralih Antar Tab

<br>

---

<br>

# Beralih Antar Panel (Layar Terbagi / Split Screen)

<br>

---

<br>

# savecursor


```bash
set savecursor true
```

Agar pengaturan ini tersimpan secara permanen dan berlaku setiap kali Anda membuka aplikasi.
```bash
sethistory true
```

<br>

---

<br>

Untuk menyimpan posisi kursor (pointer) terakhir kalinya sebelum berkas ditutup di micro editor, Anda harus mengaktifkan opsi bawaan yang bernama `savecursor`.

Secara default, fitur ini **dimatikan**. Ketika Anda mengaktifkannya, editor akan mengingat baris dan kolom terakhir Anda berada, sehingga saat berkas tersebut dibuka kembali, Anda bisa langsung melanjutkan pekerjaan dari titik tersebut.
```json
{
    "savecursor": true
}

```

qa: 
Apakah Anda juga ingin mematikan fitur **autocomplete teks** atau **indentasi otomatis** di Micro? Beritahu saya jika Anda membutuhkan bantuan konfigurasi lainnya!

Apakah Anda juga ingin mengatur **keybinding (tombol pintas)** khusus agar bisa menyalakan atau mematikan softwrap secara cepat menggunakan kombinasi keyboard?



<br>

---

<br>

Untuk mencari kata (*search word*) di micro text editor, Anda bisa menggunakan kombinasi tombol shortcut yang mirip dengan editor teks modern seperti VS Code.

Berikut adalah langkah-langkahnya:
1. Buka menu pencarian: Tekan tombol `Ctrl + F`. [1] (https://nus-cs2030s.github.io/2526-s2/micro/operations.html), [2] (https://cheatography.com/mynocksonmyfalcon/cheat-sheets/micro-text-editor/)
2. Ketik kata yang dicari: Masukkan kata atau string teks yang ingin Anda temukan pada bilah perintah (*prompt*) di bagian bawah.
3. Eksekusi pencarian: Tekan tombol `Enter` untuk langsung melompat ke kata pertama yang ditemukan.
4. Navigasi hasil pencarian:
   - Tekan `Ctrl + N` untuk berpindah ke kata berikutnya (*Next*).
   - Tekan `Ctrl + P` untuk kembali ke kata sebelumnya (*Previous*).

Jika Anda juga ingin mencari sekaligus mengganti kata tersebut (*Find and Replace*), Anda bisa menekan `Ctrl + H`. [1] (https://tech.finlup.id/micro-editor-transformasi-terminal-menjadi-ide-modern-yang-ringan)

<br>

qa: 
Apakah Anda juga membutuhkan cara untuk melakukan **replace kata secara massal (replace all)** atau ingin tahu **cara mencari kata menggunakan regular expression (regex)** di micro editor? [1] (https://www.youtube.com/watch?v=kqCQLyrEZww&vl=id&t=430)













<br>
