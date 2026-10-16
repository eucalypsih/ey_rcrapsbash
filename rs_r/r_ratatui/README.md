# 

aa: 
Dalam pustaka TUI Rust Ratatui, `ratatui::text::Text` adalah struktur data yang digunakan untuk merepresentasikan teks **multibaris** yang dapat diberi gaya (*styling*) per karakter atau per kata.

Secara hierarki di Ratatui, `Text` terdiri dari kumpulan `Line` (satu baris), dan `Line` terdiri dari kumpulan `Span` (bagian teks dengan gaya yang sama). `Text` juga mengimplementasikan *trait* `Widget`, sehingga Anda bisa merendernya langsung atau memasukkannya ke dalam widget lain seperti `Paragraph`.

Berikut adalah cara membuat, menata gaya, dan menampilkan `Text` di Ratatui.

---

## 1. Cara Membuat `Text`
Anda bisa membuat objek `Text` dari string biasa (`&str` atau `String`), dari kumpulan `Line`, atau menggunakan fungsi bawaan.

```rust
use ratatui::text::{Text, Line, Span};
use ratatui::style::{Style, Color, Modifier};

// Cara 1: Dari string biasa (otomatis mendeteksi \n untuk baris baru)
let text_biasa = Text::from("Baris Pertama\nBaris Kedua");

// Cara 2: Membuat baris demi baris secara manual menggunakan Line dan Span
let text_kustom = Text::from(vec![
    Line::from("Ini baris pertama."),
    Line::from(vec![
        Span::raw("Kata biasa, "),
        Span::styled("Kata tebal dan merah", Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
    ]),
]);

```

## 2. Menata Gaya (*Styling*) dan Penyelarasan (*Alignment*)
Struktur `Text` menyediakan metode *builder* yang intuitif untuk mengubah tampilan seluruh teks sekaligus.

```rust
// Memberikan warna latar belakang, warna teks, dan format rata tengah
let text_gaya = Text::from("Halo Ratatui!")
    .style(Style::default().fg(Color::Green).bg(Color::Black))
    .centered(); // Bisa juga .left_aligned() atau .right_aligned()

```

## 3. Cara Menampilkan `Text` ke Terminal
Di dalam fungsi `render` atau closure `terminal.draw`, Anda memiliki dua opsi untuk menampilkan `Text` ke area (`Rect`) yang ditentukan:

### Opsi A: Menggunakan Widget `Paragraph` (Sangat Direkomendasikan)

Menggunakan `Paragraph` lebih disukai karena mendukung fitur pembungkusan teks (*line wrapping*) otomatis dan *scrolling*.```rust
use ratatui::widgets::Paragraph;

fn draw_ui(f: &mut ratatui::Frame, area: ratatui::layout::Rect) {
    let teks = Text::from("Ini adalah teks panjang yang akan ditampilkan di dalam widget Paragraph.");
    
    // Masukkan Text ke dalam Paragraph
    let paragraf = Paragraph::new(teks);
    
    // Render ke terminal
    f.render_widget(paragraf, area);
}

```

### Opsi B: Merender `Text` Secara Langsung
Karena `Text` mengimplementasikan *trait* `Widget`, Anda bisa langsung merendernya tanpa pembungkus, tetapi teks yang terlalu panjang akan terpotong (tidak otomatis pindah baris).

```rust
fn draw_ui(f: &mut ratatui::Frame, area: ratatui::layout::Rect) {
    let teks = Text::from("Teks langsung tanpa paragraph widget.");
    
    // Langsung render ke area terminal
    f.render_widget(teks, area);
}

```
Untuk panduan lebih mendalam mengenai manipulasi teks, Anda dapat membaca dokumentasi resmi di [Ratatui Text Documentation](https://docs.rs/ratatui/latest/ratatui/text/index.html) atau resep kodenya di [Ratatui Display Text](https://ratatui.rs/recipes/render/display-text/).

---

qa: 
Apakah Anda sedang membuat TUI yang membutuhkan **line wrapping (pembungkusan teks otomatis)** atau fitur **scrolling**, atau Anda membutuhkan contoh **arsitektur aplikasi Ratatui lengkap** dengan *render loop*? Beritahu saya agar bisa memberikan kode contoh yang sesuai!





<br>
