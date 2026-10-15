# 





- `current_text.width()`
Menggantikan `.len()` Fungsi bawaan Ratatui ini menghitung lebar visual karakter (sangat berguna jika teks Anda nantinya mengandung karakter multi-byte atau gaya pemformatan ansi).

alternatif `current_text.chars().count()` sebagai gantinya.

Tipe data `String` bawaan Rust tidak memiliki fungsi `.width()` bawaan.

tipe data visual milik `ratatui` (seperti `Text` atau `Line`)


cara paling mudah dan efisien tanpa menambah library baru adalah menggunakan crate `unicode-width` yang biasanya sudah otomatis ter-install sebagai dependensi Ratatui/Crossterm.

Ubah bagian `.width()` menjadi `.as_str().width()` agar fungsi dari trait UnicodeWidthStr bisa mendeteksi panjang visual string Anda:

- `use unicode_width::UnicodeWidthStr;`
Jika teks Anda mengandung karakter khusus atau emoji (misal tanda panah `→`, centang `✓`, dll), fungsi `.len()` bawaan Rust akan menghitung jumlah byte (bisa 2-4 byte per karakter) yang membuat kotak menjadi terlalu lebar/kosong di kanan. `UnicodeWidthStr::width()` memastikan yang dihitung adalah **lebar karakter saat tampil di layar terminal**.



<br>
