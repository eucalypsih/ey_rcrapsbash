# 

```rust

            // Membagi layar menjadi area tengah agar panel kotak terlihat proporsional
            // let area_layar: Rect = f.size(); // ❌ Menggunakan metode usang
            let area_layar: Rect = f.area(); // ✅ BENAR: Menggunakan standar modern Ratatui 0.30+
            let area_vertikal = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Percentage(35),
                    Constraint::Length(5), // Kotak setinggi 5 baris
                    Constraint::Percentage(45),
                ])
                .split(area_layar);

            let area_horizontal = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(5),
                    Constraint::Percentage(90), // Lebar kotak panel 90% layar
                    Constraint::Percentage(5),
                ])
                .split(area_vertikal[1]);

            let area_kotak_panel = area_horizontal[1];

            // 💡 RATATUI STYLE: Menyusun 6 Komponen Parameter ke dalam struktur Line & Span
            let susunan_teks_tui = Line::from(vec![

```

aa: 
Variabel `area_vertikal` memiliki tipe data `std::collections::hash_map::RandomState` jika dilihat dari implementasi internal kompilasi, namun tipe data resmi publik yang diekspos oleh library Ratatui adalah `Rc<[Rect]>` (atau di beberapa versi dibungkus dalam tipe internal `LayoutSplit` yang mengimplementasikan *index indexing array*).

Secara sederhana, `area_vertikal` adalah sebuah **kumpulan (_array/slice_) dari koordinat kotak `Rect`** hasil pemotongan layar yang dibungkus oleh *Smart Pointer*.

Jika Anda ingin mendeklarasikan tipe datanya secara **eksplisit murni** (standar industri/idiomatik Rust), kodenya ditulis seperti ini:
```rust

            // Membagi layar menjadi area tengah agar panel kotak terlihat proporsional
            // let area_layar: Rect = f.size(); // ❌ Menggunakan metode usang
            let area_layar: Rect = f.area(); // ✅ BENAR: Menggunakan standar modern Ratatui 0.30+
            let area_vertikal: std::rc::Rc<[Rect]> = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Percentage(35),
                    Constraint::Length(5), // Kotak setinggi 5 baris
                    Constraint::Percentage(45),
                ])
                .split(area_layar);

            let area_horizontal: std::rc::Rc<[Rect]> = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(5),
                    Constraint::Percentage(90), // Lebar kotak panel 90% layar
                    Constraint::Percentage(5),
                ])
                .split(area_vertikal[1]);

            let area_kotak_panel = area_horizontal[1];

            // 💡 RATATUI STYLE: Menyusun 6 Komponen Parameter ke dalam struktur Line & Span
            let susunan_teks_tui: Line<'static> = Line::from(vec![

```

---

## 💡 Mengapa tipenya `Rc<[Rect]>`?
1. `Rect`: Merupakan struktur data yang menyimpan koordinat fisik layar (`x`, `y`, `width`, `height`).
2. `[Rect]`: Menunjukkan bahwa hasil pemotongan menghasilkan banyak kotak sekaligus (berupa array/slice), sesuai dengan jumlah `Constraint` yang Anda masukkan (dalam kasus Anda, menghasilkan 3 kotak).
3. `Rc` (Reference Counted): Adalah *smart pointer* bawaan Rust yang digunakan oleh Ratatui agar hasil potongan layout memori tersebut bisa dibaca dan diakses dengan sangat cepat oleh widget lain tanpa perlu melakukan proses kloning (*deep copy*) data yang boros RAM.
Karena tipe datanya berupa array dari Rect, Anda bisa memanggil kotak baris pertama dengan `area_vertikal[0]`, baris kedua dengan `area_vertikal[1]`, dan seterusnya.

Sekarang penulisan tipe data Layout Ratatui sudah sangat jelas.

---

```rust

            // Membagi layar menjadi area tengah agar panel kotak terlihat proporsional
            // let area_layar: Rect = f.size(); // ❌ Menggunakan metode usang
            let area_layar: Rect = f.area(); // ✅ BENAR: Menggunakan standar modern Ratatui 0.30+
            // 1. Membagi layar secara VERTIKAL
            let daftar_constraint_vertikal: [Constraint; 3] = [
                Constraint::Percentage(35),
                Constraint::Length(5), 
                Constraint::Percentage(45),
            ];

            let layout_vertikal: Layout = Layout::default()
                .direction(Direction::Vertical)
                .constraints::<[Constraint; 3]>(daftar_constraint_vertikal);

            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);

            // 2. Membagi layar secara HORIZONTAL (mengambil baris tengah / index 1)
            let daftar_constraint_horizontal: [Constraint; 3] = [
                Constraint::Percentage(5),
                Constraint::Percentage(90), 
                Constraint::Percentage(5),
            ];

            let layout_horizontal: Layout = Layout::default()
                .direction(Direction::Horizontal)
                .constraints::<[Constraint; 3]>(daftar_constraint_horizontal);

            let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(area_vertikal[1]);

            // 3. Mengambil area kotak panel utama
            let area_kotak_panel: Rect = area_horizontal[1];

            // 💡 RATATUI STYLE: Menyusun 6 Komponen Parameter ke dalam struktur Line & Span
            let susunan_teks_tui: Line<'static> = Line::from(vec![

```

## 💡 Mengapa Cara Ini Lebih Benar & Idiomatik?
1. `.constraints::<[Constraint; 3]>`: Kita memberi tahu compiler secara eksplisit menggunakan *turbofish operator* bahwa tipe data penampung iterator yang dimasukkan adalah sebuah fixed-size array berisi 3 elemen `Constraint`.
2. `std::rc::Rc<[Rect]>`: Secara bawaan, metode `.split()` pada Ratatui modern tidak mengembalikan `Vec`, melainkan sebuah Reference *Counted Slice* (`Rc<[Rect]>`). Mendeklarasikan tipe ini secara eksplisit jauh lebih efisien karena menghindari alokasi memori tambahan (tanpa `.to_vec()`).


<br>
