# 

qc: 
menambahkan **validasi teks** (misal: membatasi jumlah karakter atau mendeteksi input kosong) terlebih dahulu

---

aa: 
Untuk menambahkan fitur **validasi teks**, kita akan memodifikasi logika pada fungsi `tambah_karakter` untuk membatasi panjang teks, serta fungsi `simpan_teks` untuk mendeteksi input kosong atau hanya berisi spasi.

Selain itu, kita akan menambahkan status pesan error (`error_pesan`) pada struktur `App` agar pengguna tahu jika input mereka tidak valid.

Berikut adalah kode lengkap yang sudah diperbarui dengan sistem validasi teks:
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

// Batasan panjang karakter maksimal
const MAX_KARAKTER: usize = 20;

// ==========================================
// 1. STRUKTUR DATA APLIKASI (STATE)
// ==========================================
struct App {
    pub input_teks: String,
    pub teks_tersimpan: Vec<String>,
    pub error_pesan: Option<String>, // Menyimpan pesan error jika validasi gagal
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        Self {
            input_teks: String::new(),
            teks_tersimpan: Vec::new(),
            error_pesan: None, // Default tidak ada error
            harus_keluar: false,
        }
    }

    // VALIDASI 1: Batasi jumlah karakter maksimal
    fn tambah_karakter(&mut self, c: char) {
        if self.input_teks.len() < MAX_KARAKTER {
            self.input_teks.push(c);
            self.error_pesan = None; // Reset error saat user mulai mengetik ulang
        } else {
            self.error_pesan = Some(format!("Maksimal hanya boleh {} karakter!", MAX_KARAKTER));
        }
    }

    fn hapus_karakter(&mut self) {
        self.input_teks.pop();
        self.error_pesan = None; // Reset error setelah menghapus teks
    }

    // VALIDASI 2 & 3: Deteksi input kosong atau hanya spasi
    fn simpan_teks(&mut self) {
        let teks_bersih = self.input_teks.trim(); // Menghapus spasi di awal/akhir

        if teks_bersih.is_empty() {
            self.error_pesan = Some("Gagal! Input tidak boleh kosong.".to_string());
        } else {
            self.teks_tersimpan.push(teks_bersih.to_string());
            self.input_teks.clear(); // Kosongkan input form
            self.error_pesan = None; // Pastikan error hilang setelah sukses
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
                        KeyCode::Enter => app.simpan_teks(),
                        KeyCode::Backspace => app.hapus_karakter(),
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
    // Membagi layar menjadi 4 area secara vertikal: Petunjuk, Kotak Input, Error Bar, Log Hasil
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Petunjuk atas
            Constraint::Length(3), // Kotak Input teks
            Constraint::Length(1), // Baris pesan error (tinggi 1 baris)
            Constraint::Min(0),    // Riwayat teks tersimpan (sisa layar)
        ])
        .split(f.area());

    // --- AREA 1: Petunjuk ---
    let petunjuk = Paragraph::new(format!(
        "Ketik pesan Anda (Maks {} karakter). Tekan [Enter] untuk kirim, [Esc] untuk keluar.", 
        MAX_KARAKTER
    ))
    .block(Block::default().borders(Borders::ALL).title("Petunjuk"))
    .style(Style::default().fg(Color::Yellow));
    f.render_widget(petunjuk, chunks[0]);

    // --- AREA 2: Kotak Input Teks ---
    // Menghitung sisa kuota karakter secara real-time
    let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
    let text_display = format!("> {}_", app.input_teks);
    
    let kotak_input = Paragraph::new(text_display)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(format!("Kotak Input Teks{}", info_karakter))
        )
        .style(Style::default().fg(Color::Cyan));
    f.render_widget(kotak_input, chunks[1]);

    // --- AREA 3: Baris Validasi Error ---
    if let Some(ref pesan) = app.error_pesan {
        let komponen_error = Paragraph::new(Span::styled(
            format!("⚠ {}", pesan),
            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
        ));
        f.render_widget(komponen_error, chunks[2]);
    }

    // --- AREA 4: Riwayat Teks Tersimpan ---
    let mut baris_riwayat = vec![Line::from(Span::styled(
        "Daftar pesan yang berhasil dikirim:",
        Style::default().add_modifier(Modifier::UNDERLINED)
    ))];

    for (i, teks) in app.teks_tersimpan.iter().enumerate() {
        baris_riwayat.push(Line::from(vec![
            Span::styled(format!("[{}] ", i + 1), Style::default().fg(Color::DarkGray)),
            Span::raw(teks.clone()),
        ]));
    }

    let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
        .block(Block::default().borders(Borders::ALL).title("Riwayat Pesan"))
        .style(Style::default().fg(Color::Green));
    f.render_widget(kotak_riwayat, chunks[3]);
}

```

---

## Fitur Validasi Baru yang Ditambahkan:
1. Counter Karakter Dinamis (`[X/20]`): Ditampilkan pada judul *Border* Kotak Input, memberikan petunjuk langsung kepada pengguna mengenai sisa ruang ketik yang tersedia.
2. Pencegahan Overflow: Jika teks menyentuh angka 20 karakter, input tombol baru akan diabaikan dan sistem akan memicu pesan peringatan merah.
3. Penyaringan Spasi (`.trim()`): Jika pengguna mengetik spasi berkali-kali lalu menekan Enter, `.trim()` akan mendeteksinya sebagai string kosong `""` sehingga tidak akan lolos masuk ke riwayat pesan.
4. Kondisional Rendering Area Error: Komponen teks error di `chunks[2]` hanya akan dirender dan memakan tempat di layar apabila status `app.error_pesan` bernilai `Some(String)`.

---

qa: 
Apakah sistem validasi ini sudah berjalan sesuai ekspektasi Anda saat dicoba? Jika sudah pas, kita bisa lanjut membuat **sistem tab menu** untuk memisahkan halaman input dengan halaman riwayat penuh!














<br>
