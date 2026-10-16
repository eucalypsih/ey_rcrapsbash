# 

qc: 
membutuhkan contoh **arsitektur aplikasi Ratatui lengkap** dengan *render loop*

---

aa: 
Berikut adalah contoh **arsitektur aplikasi Ratatui lengkap** menggunakan pola desain *Event-driven Loop*. Arsitektur ini memisahkan struktur data aplikasi (`App`), sistem penanganan input/event, dan logika rendering UI.

Contoh ini menggunakan versi Ratatui modern yang memanfaatkan pustaka `crossterm` untuk mengelola terminal.

## Struktur Proyek Cargo
Pastikan file `Cargo.toml` Anda memiliki dependensi berikut:
```toml
[dependencies]
ratatui = "0.30.2" # Gunakan versi terbaru yang stabil
crossterm = { version = "0.29.0", features = ["event"] }

```

---

## Kode Sumber Lengkap (`src/main.rs`)
```rust
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::{Backend, CrosstermBackend},
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Paragraph},
    Frame, Terminal,
};
use std::io::{self, stdout};

// ==========================================
// 1. STRUKTUR DATA APLIKASI (STATE)
// ==========================================
struct App {
    pub counter: i32,
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        Self {
            counter: 0,
            harus_keluar: false,
        }
    }

    fn increment(&mut self) {
        self.counter += 1;
    }

    fn decrement(&mut self) {
        self.counter -= 1;
    }

    fn keluar(&mut self) {
        self.harus_keluar = true;
    }
}

// ==========================================
// 2. MAIN & RENDER LOOP
// ==========================================
fn main() -> io::Result<()> {
    // Inisialisasi terminal backend
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    // Membuat state aplikasi
    let mut app = App::new();
    
    // Jalankan aplikasi utama
    let res = run_app(&mut terminal, &mut app);

    // Kembalikan kondisi terminal semula setelah aplikasi ditutup
    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;
    
    // Jika ada error pada loop utama, cetak error-nya
    if let Err(err) = res {
        println!("Error: {:?}", err);
    }
    Ok(())
}

fn run_app<B: Backend>(terminal: &mut Terminal<B>, app: &mut App) -> io::Result<()> {
    while !app.harus_keluar {
        // Menggambar UI pada setiap iterasi loop
        terminal.draw(|f| ui(f, app))?;

        // Menangani input/event dari user (Blocking)
        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                // Pastikan hanya mendeteksi event tombol ditekan (menghindari double-trigger di Windows)
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => app.keluar(),
                        KeyCode::Right | KeyCode::Char('j') => app.increment(),
                        KeyCode::Left | KeyCode::Char('k') => app.decrement(),
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
    // Membagi layar menjadi 2 bagian secara vertikal (Atas dan Bawah)
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Bagian atas untuk instruksi (tinggi tetap 3 baris)
            Constraint::Min(0),    // Bagian bawah untuk konten utama (mengisi sisa layar)
        ])
        .split(f.area());

    // --- BAGIAN ATAS: Banner Instruksi ---
    let instruksi = Paragraph::new("Tekan [Panah Kanan / J] Tambah, [Panah Kiri / K] Kurang, [Q] Keluar")
        .block(Block::default().borders(Borders::ALL).title("Petunjuk"))
        .style(Style::default().fg(Color::Yellow));
    f.render_widget(instruksi, chunks[0]);

    // --- BAGIAN BAWAH: Konten Utama menggunakan ratatui::text::Text ---
    // Membuat teks multibaris dengan styling kustom per baris
    let isi_teks = Text::from(vec![
        Line::from(vec![
            Span::raw("Nilai Counter Saat Ini: "),
            Span::styled(
                format!("{}", app.counter),
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::from(""), // Baris kosong untuk space
        Line::from(Span::styled(
            if app.counter >= 0 { "Status: Positif" } else { "Status: Negatif" },
            Style::default().fg(if app.counter >= 0 { Color::Green } else { Color::Red })
        )),
    ]);

    // Masukkan Text ke dalam widget Paragraph agar bisa diberi border tengah
    let konten_utama = Paragraph::new(isi_teks)
        .block(Block::default().borders(Borders::ALL).title("Aplikasi Counter"))
        .centered(); // Ratakan text ke tengah area

    f.render_widget(konten_utama, chunks[1]);
}

```

**Penjelasan Komponen Arsitektur:**

1. **App (State Management):** Tempat menyimpan seluruh variabel status aplikasi (data *counter* dan *boolean exit*). Fungsi murni UI hanya membaca data dari struktur ini tanpa mengubahnya secara langsung.

2. **Terminal Setup & Cleanup (** `main` **):** Memasuki *Raw Mode* (untuk membaca input karakter per karakter tanpa menunggu tombol *Enter*) dan mengaktifkan *Alternate Screen* (agar terminal asli *user* tidak kotor/rusak setelah aplikasi ditutup).

3. **The Event Loop (** `run_app` **):**
   1. `terminal.draw` membersihkan layar dan menggambar ulang UI 60 kali per detik atau saat ada perubahan.
   2. `event::poll` membatasi CPU agar tidak bekerja 100% dengan menunggu event masukan dalam rentang waktu *timeout* (16ms).

4. **Layout Separation (** `ui` **):** Menggunakan `Layout::default()` untuk membagi koordinat layar ( `Rect` ) menjadi *grid* atau panel yang responsif terhadap perubahan ukuran *window* terminal.

---

qa: 
Apakah Anda ingin menambahkan fitur **sistem navigasi antar menu (Tabs)**, atau implementasi komponen input lanjutan seperti **kotak teks (Text Input)** untuk mengetik di dalam arsitektur ini? *Let me know* langkah berikutnya yang ingin Anda kembangkan!












<br>
