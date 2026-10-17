# 


qc: 
apakah bisa lanjut menambahkan fitur **menyimpan riwayat teks ke dalam file fisik seperti format `JSON`** menggunakan pustaka standard bawaan Rust agar data tidak hilang saat aplikasi ditutup, kalo menambahkan fitur menghapus semua riwayat (Clear History) baik dari layar maupun dari file fisik lewat tombol shortcut tertentu (misal tombol C), dilanjut untuk nanti

---

aa: 
Tentu saja bisa! Kita bisa mengubah format penyimpanannya menjadi `JSON` menggunakan pustaka standar bawaan Rust (`std`).

Karena kita **tidak menggunakan library pihak ketiga** seperti `serde_json` (agar tetap murni bawaan Rust), kita akan memformat string JSON secara manual saat menyimpan (*Serialization*) dan melakukan parsing string sederhana saat memuat data (*Deserialization*). Data akan disimpan dalam bentuk JSON Array seperti: `["Teks 1", "Teks 2", "Teks 3"]`.

Untuk permintaan fitur **Clear History (tombol C)**, kita akan tunda dulu dan fokus sepenuhnya pada migrasi ke format JSON ini.

### Apa yang Berubah di Sistem JSON ini?
1. **Strategi Tulis File (`File::create`)**: Berbeda dengan format `.txt` sebelumnya yang memakai sistem *Append* (menempelkan teks baru di baris bawah), untuk format JSON kita menulis ulang seluruh array berkas dari awal secara terstruktur setiap kali ada penambahan data baru agar kurung siku pembuka `[` dan penutup `]` JSON tidak rusak.
2. **Parsing Manual Murni**: Fungsi `muat_dari_json` akan membaca file `.json`, menghapus tanda kurung siku di ujung-ujungnya, lalu memisahkannya lewat tanda koma `,`. Ini teknik manipulasi string dasar Rust yang sangat efisien dan cepat tanpa perlu bergantung pada external *crate*.

Silakan dicoba jalankan kodenya! Setelah Anda mengetik beberapa pesan, Anda bisa membuka file `riwayat_pesan.json` di text editor Anda untuk melihat struktur data array JSON yang rapi.

---

qa: 
Apakah sistem penyimpanan **JSON murni bawaan Rust** ini sudah bekerja dengan baik di perangkat Anda? Kabari saya jika Anda sudah siap untuk melanjutkan ke penambahan fitur berikutnya seperti **Clear History (tombol C)** kapan saja!


```rust
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Paragraph, Tabs},
    Frame, Terminal,
};
use std::fs::{self, File};
use std::io::{self, stdout, Read, Write, Stdout};
use std::path::Path;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.json"; // Ekstensi diubah menjadi .json

// ==========================================
// 1. STRUKTUR DATA & ENUM TAB MENU
// ==========================================
#[derive(Copy, Clone, PartialEq)]
enum MenuTab {
    Input,
    Riwayat,
}

struct App {
    pub input_teks: String,
    pub teks_tersimpan: Vec<String>,
    pub error_pesan: Option<String>,
    pub aktif_tab: MenuTab,
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            harus_keluar: false,
        }
    }

    // FUNGSI LOAD (DESERIALIZATION JSON MANUAL)
    // Membaca file format JSON Array: ["a", "b", "c"] tanpa dependensi luar
    fn muat_dari_json() -> Vec<String> {
        let mut list_data = Vec::new();
        
        if Path::new(FILE_PATH).exists() {
            if let Ok(mut file) = File::open(FILE_PATH) {
                let mut konten = String::new();
                if file.read_to_string(&mut konten).is_ok() {
                    // Bersihkan karakter whitespace, [ dan ] di ujung string JSON array
                    let bersih = konten.trim().trim_start_matches('[').trim_end_matches(']');
                    if !bersih.is_empty() {
                        // Memisahkan berdasarkan tanda koma ","
                        for item in bersih.split(',') {
                            // Bersihkan tanda kutip double (") dan spasi di sekitar teks kata
                            let kata = item.trim().trim_matches('"');
                            if !kata.is_empty() {
                                // Mengembalikan karakter escape JSON mentah jika ada (\") menjadi biasa
                                list_data.push(kata.replace("\\\"", "\""));
                            }
                        }
                    }
                }
            }
        }
        list_data
    }

    // FUNGSI SAVE (SERIALIZATION JSON MANUAL)
    // Menulis ulang seluruh struktur Vector menjadi string JSON Array yang valid
    fn simpan_ke_json(&self) -> io::Result<()> {
        let mut file = File::create(FILE_PATH)?;
        
        let mut json_string = String::new();
        json_string.push('[');

        for (i, teks) in self.teks_tersimpan.iter().enumerate() {
            // Lakukan escape pada tanda kutip di dalam teks agar tidak merusak format JSON
            let teks_escaped = teks.replace('"', "\\\"");
            
            json_string.push('"');
            json_string.push_str(&teks_escaped);
            json_string.push('"');

            // Tambahkan koma pemisah jika bukan elemen terakhir
            if i < self.teks_tersimpan.len() - 1 {
                json_string.push_str(", ");
            }
        }
        
        json_string.push(']');
        
        // Tulis teks string JSON secara utuh ke file
        file.write_all(json_string.as_bytes())?;
        Ok(())
    }

    fn ganti_tab(&mut self) {
        match self.aktif_tab {
            MenuTab::Input => self.aktif_tab = MenuTab::Riwayat,
            MenuTab::Riwayat => self.aktif_tab = MenuTab::Input,
        }
    }

    fn tambah_karakter(&mut self, c: char) {
        if self.input_teks.len() < MAX_KARAKTER {
            self.input_teks.push(c);
            self.error_pesan = None;
        } else {
            self.error_pesan = Some(format!("Maksimal hanya boleh {} karakter!", MAX_KARAKTER));
        }
    }

    fn hapus_karakter(&mut self) {
        self.input_teks.pop();
        self.error_pesan = None;
    }

    fn simpan_teks(&mut self) {
        let teks_bersih = self.input_teks.trim().to_string();
        if teks_bersih.is_empty() {
            self.error_pesan = Some("Gagal! Input tidak boleh kosong.".to_string());
        } else {
            // Tambahkan dulu ke memori Vector aplikasi
            self.teks_tersimpan.push(teks_bersih);

            // Simpan keseluruhan data Vector terbaru ke file JSON (Overwrite model)
            match self.simpan_ke_json() {
                Ok(_) => {
                    self.input_teks.clear();
                    self.error_pesan = None;
                }
                Err(_) => {
                    // Jika gagal tulis file, batalkan perubahan di Vector agar sinkron
                    self.teks_tersimpan.pop();
                    self.error_pesan = Some("Gagal menulis ke file JSON!".to_string());
                }
            }
        }
    }

    fn keluar(&mut self) {
        self.harus_keluar = true;
    }
}

// ==========================================
// 2. MAIN & RENDER LOOP
// ==========================================
fn main() -> io::Result<()> {
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;
    
    if let Err(err) = res {
        println!("Error: {:?}", err);
    }
    Ok(())
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> io::Result<()> {
    while !app.harus_keluar {
        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.aktif_tab = MenuTab::Input,
                        KeyCode::Char('2') => app.aktif_tab = MenuTab::Riwayat,

                        KeyCode::Enter if app.aktif_tab == MenuTab::Input => app.simpan_teks(),
                        KeyCode::Backspace if app.aktif_tab == MenuTab::Input => app.hapus_karakter(),
                        KeyCode::Char(c) if app.aktif_tab == MenuTab::Input => app.tambah_karakter(c),
                        
                        _ => {}
                    }
                }
            }
        }
    }
    Ok(())
}

// ==========================================
// 3. UI RENDERING LAYER
// ==========================================
fn ui(f: &mut Frame, app: &App) {
    let susunan_utama = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header Tab Menu
            Constraint::Min(0),    // Konten Dinamis
            Constraint::Length(3), // Footer Informasi
        ])
        .split(f.area());

    // --- 1. SEKTOR HEADER: Widget Tabs ---
    let daftar_judul = vec![" Halaman Input ", " Riwayat Penuh "];
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Menu Utama"))
        .select(indeks_aktif)
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED),
        );
    f.render_widget(komponen_tab, susunan_utama);

    // --- 2. SEKTOR KONTEN DINAMIS ---
    match app.aktif_tab {
        MenuTab::Input => {
            let area_input = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3),
                    Constraint::Min(0),
                ])
                .split(susunan_utama);

            let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
            let text_display = format!("> {}_", app.input_teks);
            
            let kotak_input = Paragraph::new(text_display)
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda (Format: JSON Archive){}", info_karakter)))
                .style(Style::default().fg(Color::Cyan));
            f.render_widget(kotak_input, area_input);

            if let Some(ref pesan) = app.error_pesan {
                let komponen_error = Paragraph::new(Span::styled(
                    format!("⚠ {}", pesan),
                    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
                ));
                f.render_widget(komponen_error, area_input);
            }
        }

        MenuTab::Riwayat => {
            let mut baris_riwayat = vec![Line::from(Span::styled(
                format!("Data dari file fisik ({}) yang berhasil diparsing:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan terenkode dalam JSON)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }
            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Database Riwayat JSON (Standard Library Mode)"))
                .style(Style::default().fg(Color::Green));

            f.render_widget(kotak_riwayat, susunan_utama);
        }
    }
    // --- 3. SEKTOR FOOTER ---
    let petunjuk_bawah = Paragraph::new("Navigasi: [Tab] atau / Pindah Menu | [Enter] Kirim & Update JSON | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    f.render_widget(petunjuk_bawah, susunan_utama);
}

```

---

<br>

---

## Output: 
```bash
cargo run --manifest-path $HOME/r_git1v6_log1v3/Cargo.toml
   Compiling gsm v0.1.0 (/data/data/com.termux/files/home/r_git1v6_log1v3)
warning: unused import: `self`
  --> src/main.rs:14:15
   |
14 | use std::fs::{self, File};
   |               ^^^^
   |
   = note: `#[warn(unused_imports)]` (part of `#[warn(unused)]`) on by default

error[E0308]: mismatched types
   --> src/main.rs:233:35                                                                                                        |
233 |     f.render_widget(komponen_tab, susunan_utama);
    |       -------------               ^^^^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |       |
    |       arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/terminal/frame.rs:106:12
    |
106 |     pub fn render_widget<W: Widget>(&mut self, widget: W, area: Rect) {
    |            ^^^^^^^^^^^^^

error[E0308]: mismatched types
   --> src/main.rs:244:24
    |
244 |                 .split(susunan_utama);
    |                  ----- ^^^^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |                  |
    |                  arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/layout/layout.rs:688:12
    |
688 |     pub fn split(&self, area: Rect) -> Rects {
    |            ^^^^^

error[E0308]: mismatched types
   --> src/main.rs:252:42
    |
252 |             f.render_widget(kotak_input, area_input);
    |               -------------              ^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |               |
    |               arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/terminal/frame.rs:106:12
    |
106 |     pub fn render_widget<W: Widget>(&mut self, widget: W, area: Rect) {
    |            ^^^^^^^^^^^^^

error[E0308]: mismatched types
   --> src/main.rs:259:49
    |
259 |                 f.render_widget(komponen_error, area_input);
    |                   -------------                 ^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |                   |
    |                   arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/terminal/frame.rs:106:12
    |
106 |     pub fn render_widget<W: Widget>(&mut self, widget: W, area: Rect) {
    |            ^^^^^^^^^^^^^

error[E0308]: mismatched types
   --> src/main.rs:284:44
    |
284 |             f.render_widget(kotak_riwayat, susunan_utama);
    |               -------------                ^^^^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |               |
    |               arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/terminal/frame.rs:106:12
    |
106 |     pub fn render_widget<W: Widget>(&mut self, widget: W, area: Rect) {
    |            ^^^^^^^^^^^^^

error[E0308]: mismatched types
   --> src/main.rs:293:37
    |
293 |     f.render_widget(petunjuk_bawah, susunan_utama);
    |       -------------                 ^^^^^^^^^^^^^ expected `Rect`, found `Rc<[Rect]>`
    |       |
    |       arguments to this method are incorrect
    |
    = note: expected struct `Rect`
               found struct `Rc<[Rect]>`
note: method defined here
   --> /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/ratatui-core-0.1.2/src/terminal/frame.rs:106:12
    |
106 |     pub fn render_widget<W: Widget>(&mut self, widget: W, area: Rect) {
    |            ^^^^^^^^^^^^^

For more information about this error, try `rustc --explain E0308`.
warning: `gsm` (bin "gsm") generated 1 warning
error: could not compile `gsm` (bin "gsm") due to 6 previous errors; 1 warning emitted

```

---

aa: 
Error `E0308 (mismatched types)` terjadi karena fungsi `.split()` pada pustaka Ratatui versi terbaru tidak lagi mengembalikan *array* biasa, melainkan bertipe `Rc<[Rect]>` (atau sebuah koleksi/objek indexable).

Saat Anda memasukkan variabel hasil `.split()` secara utuh (seperti `susunan_utama` atau `area_input`) ke dalam fungsi `render_widget` atau `.split()` berikutnya, Rust menolaknya karena fungsi-fungsi tersebut membutuhkan satu buah objek `Rect` tunggal, bukan kumpulan `Rect`.

## Cara Memperbaiki
Anda harus **mengakses indeks spesifik** dari hasil *split* tersebut menggunakan format indeks array `[0]`, `[1]`, dst.

Berikut adalah baris kode di dalam fungsi `ui` yang telah diperbaiki. Ganti fungsi `ui` Anda (mulai dari baris 190 ke bawah) dengan kode di bawah ini:
```rust
// ==========================================
// 3. UI RENDERING LAYER
// ==========================================
fn ui(f: &mut Frame, app: &App) {
    let susunan_utama = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header Tab Menu -> Indeks [0]
            Constraint::Min(0),    // Konten Dinamis  -> Indeks [1]
            Constraint::Length(3), // Footer Informasi-> Indeks [2]
        ])
        .split(f.area());

    // --- 1. SEKTOR HEADER: Widget Tabs ---
    let daftar_judul = vec![" Halaman Input ", " Riwayat Penuh "];
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Menu Utama"))
        .select(indeks_aktif)
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED),
        );
    
    // Perbaikan: Gunakan susunan_utama[0] untuk area Header
    f.render_widget(komponen_tab, susunan_utama[0]);

    // --- 2. SEKTOR KONTEN DINAMIS ---
    match app.aktif_tab {
        MenuTab::Input => {
            let area_input = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3), // Kotak Input -> Indeks [0]
                    Constraint::Min(0),    // Area Pesan  -> Indeks [1]
                ])
                // Perbaikan: Lakukan split berdasarkan area konten dinamis yaitu susunan_utama[1]
                .split(susunan_utama[1]);

            let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
            let text_display = format!("> {}_", app.input_teks);
            
            let kotak_input = Paragraph::new(text_display)
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda (Format: JSON Archive){}", info_karakter)))
                .style(Style::default().fg(Color::Cyan));
            
            // Perbaikan: Gunakan area_input[0] untuk kotak input
            f.render_widget(kotak_input, area_input[0]);

            if let Some(ref pesan) = app.error_pesan {
                let komponen_error = Paragraph::new(Span::styled(
                    format!("⚠ {}", pesan),
                    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
                ));
                // Perbaikan: Gunakan area_input[1] untuk memunculkan pesan error di bawahnya
                f.render_widget(komponen_error, area_input[1]);
            }
        }

        MenuTab::Riwayat => {
            let mut baris_riwayat = vec![Line::from(Span::styled(
                format!("Data dari file fisik ({}) yang berhasil diparsing:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan terenkode dalam JSON)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }
            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Database Riwayat JSON (Standard Library Mode)"))
                .style(Style::default().fg(Color::Green));

            // Perbaikan: Gunakan susunan_utama[1] untuk menampilkan riwayat di area tengah
            f.render_widget(kotak_riwayat, susunan_utama[1]);
        }
    }
    // --- 3. SEKTOR FOOTER ---
    let petunjuk_bawah = Paragraph::new("Navigasi: [Tab] atau / Pindah Menu | [Enter] Kirim & Update JSON | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```

## Poin Perubahan:
1. susunan_utama diakses indeksnya menjadi `susunan_utama[0]` (Header), `susunan_utama[1]` (Konten Tengah), dan `susunan_utama[2]` (Footer bawah).
2. `area_input` diakses indeksnya menjadi `area_input[0]` (Kotak ketik teks) dan `area_input[1]` (Baris peringatan error).

---

<br>

---

```rust
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Paragraph, Tabs},
    Frame, Terminal,
};
use std::fs::File;
use std::io::{self, stdout, Read, Write, Stdout};
use std::path::Path;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.json"; // Ekstensi diubah menjadi .json

// ==========================================
// 1. STRUKTUR DATA & ENUM TAB MENU
// ==========================================
#[derive(Copy, Clone, PartialEq)]
enum MenuTab {
    Input,
    Riwayat,
}

struct App {
    pub input_teks: String,
    pub teks_tersimpan: Vec<String>,
    pub error_pesan: Option<String>,
    pub aktif_tab: MenuTab,
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            harus_keluar: false,
        }
    }

    // FUNGSI LOAD (DESERIALIZATION JSON MANUAL)
    // Membaca file format JSON Array: ["a", "b", "c"] tanpa dependensi luar
    fn muat_dari_json() -> Vec<String> {
        let mut list_data = Vec::new();
        
        if Path::new(FILE_PATH).exists() {
            if let Ok(mut file) = File::open(FILE_PATH) {
                let mut konten = String::new();
                if file.read_to_string(&mut konten).is_ok() {
                    // Bersihkan karakter whitespace, [ dan ] di ujung string JSON array
                    let bersih = konten.trim().trim_start_matches('[').trim_end_matches(']');
                    if !bersih.is_empty() {
                        // Memisahkan berdasarkan tanda koma ","
                        for item in bersih.split(',') {
                            // Bersihkan tanda kutip double (") dan spasi di sekitar teks kata
                            let kata = item.trim().trim_matches('"');
                            if !kata.is_empty() {
                                // Mengembalikan karakter escape JSON mentah jika ada (\") menjadi biasa
                                list_data.push(kata.replace("\\\"", "\""));
                            }
                        }
                    }
                }
            }
        }
        list_data
    }

    // FUNGSI SAVE (SERIALIZATION JSON MANUAL)
    // Menulis ulang seluruh struktur Vector menjadi string JSON Array yang valid
    fn simpan_ke_json(&self) -> io::Result<()> {
        let mut file = File::create(FILE_PATH)?;
        
        let mut json_string = String::new();
        json_string.push('[');

        for (i, teks) in self.teks_tersimpan.iter().enumerate() {
            // Lakukan escape pada tanda kutip di dalam teks agar tidak merusak format JSON
            let teks_escaped = teks.replace('"', "\\\"");
            
            json_string.push('"');
            json_string.push_str(&teks_escaped);
            json_string.push('"');

            // Tambahkan koma pemisah jika bukan elemen terakhir
            if i < self.teks_tersimpan.len() - 1 {
                json_string.push_str(", ");
            }
        }
        
        json_string.push(']');
        
        // Tulis teks string JSON secara utuh ke file
        file.write_all(json_string.as_bytes())?;
        Ok(())
    }

    fn ganti_tab(&mut self) {
        match self.aktif_tab {
            MenuTab::Input => self.aktif_tab = MenuTab::Riwayat,
            MenuTab::Riwayat => self.aktif_tab = MenuTab::Input,
        }
    }

    fn tambah_karakter(&mut self, c: char) {
        if self.input_teks.len() < MAX_KARAKTER {
            self.input_teks.push(c);
            self.error_pesan = None;
        } else {
            self.error_pesan = Some(format!("Maksimal hanya boleh {} karakter!", MAX_KARAKTER));
        }
    }

    fn hapus_karakter(&mut self) {
        self.input_teks.pop();
        self.error_pesan = None;
    }

    fn simpan_teks(&mut self) {
        let teks_bersih = self.input_teks.trim().to_string();
        if teks_bersih.is_empty() {
            self.error_pesan = Some("Gagal! Input tidak boleh kosong.".to_string());
        } else {
            // Tambahkan dulu ke memori Vector aplikasi
            self.teks_tersimpan.push(teks_bersih);

            // Simpan keseluruhan data Vector terbaru ke file JSON (Overwrite model)
            match self.simpan_ke_json() {
                Ok(_) => {
                    self.input_teks.clear();
                    self.error_pesan = None;
                }
                Err(_) => {
                    // Jika gagal tulis file, batalkan perubahan di Vector agar sinkron
                    self.teks_tersimpan.pop();
                    self.error_pesan = Some("Gagal menulis ke file JSON!".to_string());
                }
            }
        }
    }

    fn keluar(&mut self) {
        self.harus_keluar = true;
    }
}

// ==========================================
// 2. MAIN & RENDER LOOP
// ==========================================
fn main() -> io::Result<()> {
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;
    
    if let Err(err) = res {
        println!("Error: {:?}", err);
    }
    Ok(())
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> io::Result<()> {
    while !app.harus_keluar {
        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.aktif_tab = MenuTab::Input,
                        KeyCode::Char('2') => app.aktif_tab = MenuTab::Riwayat,

                        KeyCode::Enter if app.aktif_tab == MenuTab::Input => app.simpan_teks(),
                        KeyCode::Backspace if app.aktif_tab == MenuTab::Input => app.hapus_karakter(),
                        KeyCode::Char(c) if app.aktif_tab == MenuTab::Input => app.tambah_karakter(c),
                        
                        _ => {}
                    }
                }
            }
        }
    }
    Ok(())
}

// ==========================================
// 3. UI RENDERING LAYER
// ==========================================
fn ui(f: &mut Frame, app: &App) {
    let susunan_utama = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header Tab Menu  -> Indeks [0]
            Constraint::Min(0),    // Konten Dinamis   -> Indeks [1]
            Constraint::Length(3), // Footer Informasi -> Indeks [2]
        ])
        .split(f.area());

    // --- 1. SEKTOR HEADER: Widget Tabs ---
    let daftar_judul = vec![" Halaman Input ", " Riwayat Penuh "];
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Menu Utama"))
        .select(indeks_aktif)
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED),
        );
    
    // Perbaikan: Gunakan susunan_utama[0] untuk area Header
    f.render_widget(komponen_tab, susunan_utama[0]);

    // --- 2. SEKTOR KONTEN DINAMIS ---
    match app.aktif_tab {
        MenuTab::Input => {
            let area_input = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3), // Kotak Input -> Indeks [0]
                    Constraint::Min(0),    // Area Pesan  -> Indeks [1]
                ])
                // Perbaikan: Lakukan split berdasarkan area konten dinamis yaitu susunan_utama[1]
                .split(susunan_utama[1]);

            let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
            let text_display = format!("> {}_", app.input_teks);
            
            let kotak_input = Paragraph::new(text_display)
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda (Format: JSON Archive){}", info_karakter)))
                .style(Style::default().fg(Color::Cyan));

            // Perbaikan: Gunakan area_input[0] untuk kotak input
            f.render_widget(kotak_input, area_input[0]);

            if let Some(ref pesan) = app.error_pesan {
                let komponen_error = Paragraph::new(Span::styled(
                    format!("⚠ {}", pesan),
                    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
                ));

                // Perbaikan: Gunakan area_input[1] untuk memunculkan pesan error di bawahnya
                f.render_widget(komponen_error, area_input[1]);
            }
        }

        MenuTab::Riwayat => {
            let mut baris_riwayat = vec![Line::from(Span::styled(
                format!("Data dari file fisik ({}) yang berhasil diparsing:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan terenkode dalam JSON)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }
            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Database Riwayat JSON (Standard Library Mode)"))
                .style(Style::default().fg(Color::Green));

            // Perbaikan: Gunakan susunan_utama[1] untuk menampilkan riwayat di area tengah
            f.render_widget(kotak_riwayat, susunan_utama[1]);
        }
    }
    // --- 3. SEKTOR FOOTER ---
    let petunjuk_bawah = Paragraph::new("Navigasi: [Tab] atau / Pindah Menu | [Enter] Kirim & Update JSON | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```











<br>
