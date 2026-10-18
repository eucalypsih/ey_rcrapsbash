# 

qc: 
performa sistem tab ini saat dijalankan untuk saat sesuai ekspektasi. apakah bisa lanjut menambahkan fitur **menyimpan riwayat teks ke dalam file fisik (seperti format `JSON` atau `.txt`)** menggunakan pustaka standard bawaan Rust agar data tidak hilang saat aplikasi ditutup

---

aa: 
Tentu saja bisa! Kita akan menggunakan modul bawaan Rust yaitu `std::fs` untuk membaca dan menulis file fisik, serta pustaka standard `std::path::Path` untuk mengecek keberadaan file.

Agar data tersimpan secara terstruktur (sehingga mudah dibaca kembali saat aplikasi dibuka), kita akan menyimpannya dalam format **`.txt` baris demi baris**. Dengan pustaka standar bawaan Rust, pendekatan ini sangat bersih tanpa perlu menambah dependensi pihak ketiga (*third-party crate*).

Berikut adalah pembaruan kode lengkap yang otomatis **memuat data lama saat aplikasi dibuka (Load)** dan **menyimpan data baru setiap kali Anda menekan Enter (Save)**.

## Cara Kerja Fitur Penyimpanan Fisik Ini:
1. `App::muat_dari_file()`: Fungsi ini dipanggil di dalam `App::new()`. Ia mengecek keberadaan file `riwayat_pesan.txt`. Jika filenya ada, data dibaca baris demi baris menggunakan `BufReader` dan langsung dimasukkan ke riwayat UI. Jadi saat aplikasi ditutup lalu dibuka lagi, pesan lama Anda tidak hilang!
2. `OpenOptions::new().append(true)`: Ketika Anda mengirim teks baru, sistem tidak akan menghapus isi file lama (*overwrite*), melainkan menumpuk teks baru tersebut di baris paling bawah secara otomatis.
3. Pemberitahuan Error io: Jika aplikasi dijalankan di direktori yang tidak memiliki izin menulis (*read-only directory*), validasi `match` pada `simpan_ke_file` akan menangkap *error* sistem tersebut dan memunculkan notifikasi merah di UI tanpa membuat aplikasi Anda *crash*.
Setelah menjalankan kode ini, Anda akan melihat file baru bernama `riwayat_pesan.txt` muncul di folder proyek Cargo Anda!
---

qa: 
Apakah fitur auto-save dan auto-load file fisik ini sudah berjalan lancar di terminal Anda? Jika Anda ingin melangkah lebih jauh, kita bisa menambahkan fitur **menghapus semua riwayat (Clear History)i* baik dari layar maupun dari file fisik lewat tombol shortcut tertentu (misal tombol `C`). Bagaimana menurut Anda?

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
use std::fs::{self, File, OpenOptions};
use std::io::{self, stdout, BufRead, BufReader, Write, Stdout};
use std::path::Path;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.txt"; // Nama file penyimpanan fisik

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
        // Otomatis memuat data dari file saat aplikasi pertama kali dijalankan
        let data_lama = Self::muat_dari_file();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            harus_keluar: false,
        }
    }

    // FUNGSI LOAD: Membaca file fisik saat aplikasi dimulai
    fn muat_dari_file() -> Vec<String> {
        let mut list_data = Vec::new();
        
        // Cek jika file fisik sudah ada
        if Path::new(FILE_PATH).exists() {
            if let Ok(file) = File::open(FILE_PATH) {
                let reader = BufReader::new(file);
                // Baca baris demi baris dan masukkan ke dalam Vector
                for baris in reader.lines() {
                    if let Ok(konten) = baris {
                        if !konten.trim().is_empty() {
                            list_data.push(konten);
                        }
                    }
                }
            }
        }
        list_data
    }

    // FUNGSI SAVE: Menulis teks baru secara permanen ke file fisik (Append Mode)
    fn simpan_ke_file(teks: &str) -> io::Result<()> {
        // Membuka file dengan opsi: Buat jika belum ada, dan Append (tambah di baris paling bawah)
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(FILE_PATH)?;
        
        // Tulis teks diikuti dengan karakter baris baru (\n)
        writeln!(file, "{}", teks)?;
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
            // 1. Simpan ke file fisik terlebih dahulu
            match Self::simpan_ke_file(&teks_bersih) {
                Ok(_) => {
                    // 2. Jika sukses di file fisik, simpan ke memori aplikasi (UI)
                    self.teks_tersimpan.push(teks_bersih);
                    self.input_teks.clear();
                    self.error_pesan = None;
                }
                Err(_) => {
                    self.error_pesan = Some("Gagal menulis ke file penyimpanan fisik!".to_string());
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
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda{}", info_karakter)))
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
                format!("Data dari file fisik ({}) yang berhasil dimuat:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan yang disimpan di file fisik)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }

            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Log Database Riwayat (Persisten)"))
                .style(Style::default().fg(Color::Green));
            f.render_widget(kotak_riwayat, susunan_utama);
        }
    }

    // --- 3. SEKTOR FOOTER ---
    let petunjuk_bawah = Paragraph::new("Navigasi: [Tab] atau / Pindah Menu | [Enter] Kirim & Simpan Fisik | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();
    f.render_widget(petunjuk_bawah, susunan_utama);
}

```

---

<br>

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
use std::fs::{File, OpenOptions};
use std::io::{self, stdout, BufRead, BufReader, Write, Stdout};
use std::path::Path;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.txt"; // Nama file penyimpanan fisik

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
        // Otomatis memuat data dari file saat aplikasi pertama kali dijalankan
        let data_lama = Self::muat_dari_file();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            harus_keluar: false,
        }
    }

    // FUNGSI LOAD: Membaca file fisik saat aplikasi dimulai
    fn muat_dari_file() -> Vec<String> {
        let mut list_data = Vec::new();
        
        // Cek jika file fisik sudah ada
        if Path::new(FILE_PATH).exists() {
            if let Ok(file) = File::open(FILE_PATH) {
                let reader = BufReader::new(file);
                // Baca baris demi baris dan masukkan ke dalam Vector
                for baris in reader.lines() {
                    if let Ok(konten) = baris {
                        if !konten.trim().is_empty() {
                            list_data.push(konten);
                        }
                    }
                }
            }
        }
        list_data
    }

    // FUNGSI SAVE: Menulis teks baru secara permanen ke file fisik (Append Mode)
    fn simpan_ke_file(teks: &str) -> io::Result<()> {
        // Membuka file dengan opsi: Buat jika belum ada, dan Append (tambah di baris paling bawah)
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(FILE_PATH)?;
        
        // Tulis teks diikuti dengan karakter baris baru (\n)
        writeln!(file, "{}", teks)?;
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
            // 1. Simpan ke file fisik terlebih dahulu
            match Self::simpan_ke_file(&teks_bersih) {
                Ok(_) => {
                    // 2. Jika sukses di file fisik, simpan ke memori aplikasi (UI)
                    self.teks_tersimpan.push(teks_bersih);
                    self.input_teks.clear();
                    self.error_pesan = None;
                }
                Err(_) => {
                    // Jika gagal tulis file, batalkan perubahan di Vector agar sinkron
                    self.teks_tersimpan.pop();
                    self.error_pesan = Some("Gagal menulis ke file penyimpanan fisik!".to_string());
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
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda{}", info_karakter)))
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
                format!("Data dari file fisik ({}) yang berhasil dimuat:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan yang disimpan di file fisik)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }

            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Log Database Riwayat (Persisten)"))
                .style(Style::default().fg(Color::Green));

            // Perbaikan: Gunakan susunan_utama[1] untuk menampilkan riwayat di area tengah
            f.render_widget(kotak_riwayat, susunan_utama[1]);
        }
    }

    // --- 3. SEKTOR FOOTER ---
    let petunjuk_bawah = Paragraph::new("Navigasi: [Tab] atau / Pindah Menu | [Enter] Kirim & Simpan Fisik | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```







<br>
