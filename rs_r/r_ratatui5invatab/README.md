# 

qc: 
sistem validasi ini sudah berjalan sesuai ekspektasi saat dicoba. apakah bisa lanjut membuat **sistem tab menu** untuk memisahkan halaman input dengan halaman riwayat penuh

---

aa: 
Tentu saja, mari kita tingkatkan arsitektur aplikasi kita menjadi **sistem tab menu**!

Kita akan memisahkan aplikasi menjadi dua tab utama:
1. Tab Mengetik: Berisi kotak form input teks beserta validasinya (seperti yang sudah kita buat sebelumnya).
2. Tab Riwayat: Halaman khusus yang menampilkan seluruh daftar teks yang tersimpan secara penuh.

Untuk mewujudkannya, kita akan menambahkan status `aktif_tab` menggunakan sebuah *Enum*, memproses tombol arah/angka untuk berganti tab, serta menggunakan widget `Tabs` bawaan dari Ratatui.
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
use std::io::{self, stdout, Stdout};

const MAX_KARAKTER: usize = 20;

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
    pub aktif_tab: MenuTab, // Menyimpan status tab mana yang sedang aktif
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        Self {
            input_teks: String::new(),
            teks_tersimpan: Vec::new(),
            error_pesan: None,
            aktif_tab: MenuTab::Input, // Default dimulai di Tab Input
            harus_keluar: false,
        }
    }

    // Fungsi untuk berpindah tab menggunakan tombol Tab atau keyboard angka
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
        let teks_bersih = self.input_teks.trim();
        if teks_bersih.is_empty() {
            self.error_pesan = Some("Gagal! Input tidak boleh kosong.".to_string());
        } else {
            self.teks_tersimpan.push(teks_bersih.to_string());
            self.input_teks.clear();
            self.error_pesan = None;
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
                        // Tombol global (bisa diakses dari tab mana saja)
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.aktif_tab = MenuTab::Input,
                        KeyCode::Char('2') => app.aktif_tab = MenuTab::Riwayat,

                        // Tombol kondisional (hanya bekerja jika berada di Tab Input)
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
    // Membagi layar utama menjadi 3 area vertikal secara permanen: Header Menu, Konten Tab, Footer
    let susunan_utama = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Barisan Tab Menu atas
            Constraint::Min(0),    // Wilayah konten dinamis (mengikuti tab)
            Constraint::Length(3), // Petunjuk Navigasi bawah
        ])
        .split(f.area());

    // --- 1. SEKTOR HEADER: Widget Tabs ---
    let daftar_judul = vec![" [1] Halaman Input ", " [2] Riwayat Penuh "];
    
    // Menentukan indeks tab aktif (0 untuk Input, 1 untuk Riwayat)
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Menu Utama"))
        .select(indeks_aktif) // Menyorot tab yang aktif
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED),
        );
    f.render_widget(komponen_tab, susunan_utama[0]);

    // --- 2. SEKTOR KONTEN DINAMIS ---
    match app.aktif_tab {
        // --- JIKA MENU INPUT AKTIF ---
        MenuTab::Input => {
            // Bagi area tengah menjadi tempat input dan baris error
            let area_input = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3),
                    Constraint::Min(0),
                ])
                .split(susunan_utama[1]);

            let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
            let text_display = format!("> {}_", app.input_teks);
            
            let kotak_input = Paragraph::new(text_display)
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda{}", info_karakter)))
                .style(Style::default().fg(Color::Cyan));
            f.render_widget(kotak_input, area_input[0]);

            // Jika ada pesan error validasi, tampilkan di bawah kotak input
            if let Some(ref pesan) = app.error_pesan {
                let komponen_error = Paragraph::new(Span::styled(
                    format!("⚠ {}", pesan),
                    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
                ));
                f.render_widget(komponen_error, area_input[1]);
            }
        }

        // --- JIKA MENU RIWAYAT AKTIF ---
        MenuTab::Riwayat => {
            let mut baris_riwayat = vec![Line::from(Span::styled(
                "Semua data yang tersimpan di dalam memori database aplikasi:",
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));
                baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan yang disimpan)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }

            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
                .block(Block::default().borders(Borders::ALL).title("Log Database Riwayat"))
                .style(Style::default().fg(Color::Green));
            f.render_widget(kotak_riwayat, susunan_utama[1]);
        }
    }

    // --- 3. SEKTOR FOOTER: Informasi Navigasi ---
    let petunjuk_bawah = Paragraph::new("Navigasi: Tekan [Tab] atau tombol [1]/[2] untuk pindah menu | [Esc] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```

## Pembaruan Utama pada Sistem Tab Ini:
1. `match app.aktif_tab` pada Polling Input: Memanfaatkan fitur *pattern matching* Rust. Tombol ketik dan `Backspace` kini dikunci, mereka **hanya berfungsi** jika `aktif_tab == MenuTab::Input`. Ketika Anda di Halaman Riwayat, menekan tombol keyboard tidak akan merusak data input.
2. `Tabs` Widget: Menggunakan komponen resmi Ratatui untuk memvisualisasikan pilihan menu di bagian atas secara modern dengan penanda garis bawah dinamis (`.highlight_style`).
3. Kondisional UI Rendering: `susunan_utama[1]` bertindak sebagai wadah bunglon. Area koordinat ini akan mengganti isinya secara total menjadi *Form Input* atau menjadi *Halaman List Riwayat* tergantung pada *state* tab yang sedang dipilih.

---

qa: 
Bagaimana performa sistem tab ini saat dijalankan? Jika Anda tertarik, kita bisa menambahkan fitur **menyimpan riwayat teks ke dalam file fisik (seperti format `JSON` atau `.txt`)** menggunakan pustaka standard bawaan Rust agar data tidak hilang saat aplikasi ditutup!














<br>
