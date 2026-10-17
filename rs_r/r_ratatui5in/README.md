# 

qc: 
menambahkan **fitur interaktif** baru seperti input teks

---

aa: 
Untuk menambahkan fitur **input teks interaktif** (seperti membuat kotak form ketik), kita perlu memperbarui struktur `App` untuk menyimpan teks yang sedang diketik, menangani setiap event penekanan tombol karakter (`KeyCode::Char`), dan menampilkan kursor atau teks tersebut di UI.

Berikut adalah kode lengkap yang sudah diperbarui dengan fitur input teks, menggunakan gaya penulisan yang kompatibel dengan versi Ratatui terbaru.
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
    widgets::{Block, Borders, Paragraph},
    Frame, Terminal,
};
use std::io::{self, stdout, Stdout};

// ==========================================
// 1. STRUKTUR DATA APLIKASI (STATE)
// ==========================================
struct App {
    pub input_teks: String,  // Menyimpan teks yang sedang diketik
    pub teks_tersimpan: Vec<String>, // Menyimpan daftar teks setelah menekan Enter
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        Self {
            input_teks: String::new(),
            teks_tersimpan: Vec::new(),
            harus_keluar: false,
        }
    }

    // Fungsi untuk memasukkan karakter baru ke text input
    fn tambah_karakter(&mut self, c: char) {
        self.input_teks.push(c);
    }

    // Fungsi untuk menghapus satu karakter terakhir (Backspace)
    fn hapus_karakter(&mut self) {
        self.input_teks.pop();
    }

    // Fungsi saat menekan Enter untuk menyimpan teks
    fn simpan_teks(&mut self) {
        if !self.input_teks.is_empty() {
            self.teks_tersimpan.push(self.input_teks.clone());
            self.input_teks.clear(); // Kosongkan kembali kotak input
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

// Menggunakan penulisan eksplisit CrosstermBackend<Stdout> untuk menghindari Error E0277
fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> io::Result<()> {
    while !app.harus_keluar {
        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        // Kontrol Aplikasi
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Enter => app.simpan_teks(),
                        KeyCode::Backspace => app.hapus_karakter(),
                        // Menangkap input karakter apapun (huruf, angka, spasi, simbol)
                        KeyCode::Char(c) => app.tambah_karakter(c),
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
    // Membagi layar menjadi 3 area secara vertikal: Petunjuk, Kotak Input, Log Hasil
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Petunjuk atas
            Constraint::Length(3), // Kotak Input teks
            Constraint::Min(0),    // Riwayat teks tersimpan (sisa layar)
        ])
        .split(f.area());

    // --- AREA 1: Petunjuk ---
    let petunjuk = Paragraph::new("Ketik pesan Anda secara langsung. Tekan [Enter] untuk submit, [Esc] untuk keluar.")
        .block(Block::default().borders(Borders::ALL).title("Petunjuk Sistem"))
        .style(Style::default().fg(Color::Yellow));
    f.render_widget(petunjuk, chunks[0]);

    // --- AREA 2: Kotak Input Teks ---
    // Menambahkan karakter visual '_' di akhir sebagai representasi kursor
    let text_display = format!("> {}_", app.input_teks);
    let kotak_input = Paragraph::new(text_display)
        .block(Block::default().borders(Borders::ALL).title("Kotak Input Teks"))
        .style(Style::default().fg(Color::Cyan));
    f.render_widget(kotak_input, chunks[1]);

    // --- AREA 3: Riwayat Teks Tersimpan ---
    // Membuat teks multibaris dari daftar String menggunakan ratatui::text::Text
    let mut baris_riwayat = vec![Line::from(Span::styled(
        "Daftar pesan yang berhasil dikirim:",
        Style::default().add_modifier(Modifier::UNDERLINED)
    ))];

    // Iterasi semua teks yang tersimpan dan bungkus ke dalam objek Line
    for (i, teks) in app.teks_tersimpan.iter().enumerate() {
        baris_riwayat.push(Line::from(vec![
            Span::styled(format!("[{}] ", i + 1), Style::default().fg(Color::DarkGray)),
            Span::raw(teks.clone()),
        ]));
    }

    let isi_riwayat = Text::from(baris_riwayat);
    let kotak_riwayat = Paragraph::new(isi_riwayat)
        .block(Block::default().borders(Borders::ALL).title("Riwayat Pesan"))
        .style(Style::default().fg(Color::Green));
    f.render_widget(kotak_riwayat, chunks[2]);
}

```

---

## Cara Kerja Fitur Baru Ini:
1. `KeyCode::Char(c)`: Digunakan untuk menangkap tombol apa pun yang diketik user (huruf/angka/spasi) dan memasukkannya ke dalam `String`.
2. `KeyCode::Backspace`: Memanggil fungsi `.pop()` bawaan Rust untuk menghapus karakter paling belakang di String tersebut.
3. Kursor Visual (`_`): Di bagian UI (`chunks[1]`), kita menambahkan tanda garis bawah `_` secara dinamis di ujung string agar pengguna tahu posisi mengetik mereka saat ini.
4. Riwayat Dinamis: Setelah `Enter` ditekan, string dikirim ke `Vec<String>`. Komponen `Text::from` kemudian mengolah struktur array ini menjadi baris-baris teks (`Line`) baru ke terminal.

---

qa: 
Apakah Anda ingin meningkatkan fitur ini dengan menambahkan **validasi teks** (misal: membatasi jumlah karakter atau mendeteksi input kosong), atau ingin mencoba membuat **sistem tab menu** untuk memisahkan halaman input dengan halaman riwayat? Let me know!















<br>
