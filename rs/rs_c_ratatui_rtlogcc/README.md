# 

qc: 
Saya ingin melengkapinya dengan **fitur statistik counter** di panel atas (misal menampilkan jumlah total `Error: X | Warn: Y | Info: Z` yang sudah tertangkap sejak aplikasi dibuka)

---

aa: 
Untuk menambahkan **fitur statistik counter** secara *real-time*, kita perlu menambahkan tiga kolom pencatat (*fields*) baru ke dalam `AppState`. Setiap kali ada baris log baru masuk dari *background thread*, aplikasi akan mendeteksi tipe lognya dan langsung menaikkan nilai (*increment*) counter yang sesuai.

Strategi ini sangat efisien karena kalkulasi dilakukan tepat saat data diterima (**Event-Driven Update**), bukan dihitung ulang dari awal pada setiap *frame* UI, sehingga penggunaan CPU tetap mendekati 0%.

## 🛠️ Kode Solusi Lengkap dengan Statistik Real-Time
Berikut adalah kode yang telah disempurnakan dengan menambahkan panel statistik di bagian atas aplikasi TUI Anda:

- `rs_c_ratatui_rtlogcc/Cargo.toml`
```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
ratatui = "0.30.2"   # Tambahkan library TUI standar industri Rust

```

- `rs_c_ratatui_rtlogcc/src/main.rs`
```rust
use std::io::{self, BufRead, BufReader, Seek, SeekFrom};
use std::time::Duration;
use std::fs::File;
use std::sync::mpsc;
use std::thread;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Terminal,
};

enum AppEvent {
    Key(KeyCode),
    LogLine(String),
}

// =========================================================================
// 1. MANAJEMEN STATE: Menambahkan Pencatat Statistik
// =========================================================================
struct AppState {
    current_branch: String,
    repo: String,
    owner: String,
    log_lines: Vec<String>,
    should_quit: bool,
    // Field Baru untuk Counter Statistik
    count_info: usize,
    count_warn: usize,
    count_error: usize,
}

impl AppState {
    fn new(branch: &str, repo: &str, owner: &str) -> Self {
        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            log_lines: Vec::new(),
            should_quit: false,
            count_info: 0,
            count_warn: 0,
            count_error: 0,
        }
    }

    // Fungsi internal untuk memperbarui counter berdasarkan teks log yang masuk
    fn perbarui_statistik(&mut self, line: &str) {
        if line.contains("[ERROR]") {
            self.count_error += 1;
        } else if line.contains("[WARN]") {
            self.count_warn += 1;
        } else if line.contains("[INFO]") {
            self.count_info += 1;
        }
    }
}

// PARSER WARNA LOG (Tetap cepat menggunakan .contains)
fn parsing_warna_log(line: &str) -> Line<'static> {
    if line.contains("[ERROR]") {
        Line::from(vec![
            Span::styled(line.to_string(), Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
        ])
    } else if line.contains("[WARN]") {
        Line::from(vec![
            Span::styled(line.to_string(), Style::default().fg(Color::Yellow))
        ])
    } else if line.contains("[INFO]") {
        if let Some(pos) = line.find("[INFO]") {
            let sisa_teks = &line[pos + 6..];
            Line::from(vec![
                Span::styled(line[..pos].to_string(), Style::default().fg(Color::DarkGray)),
                Span::styled("[INFO]", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::styled(sisa_teks.to_string(), Style::default().fg(Color::White)),
            ])
        } else {
            Line::from(vec![Span::styled(line.to_string(), Style::default().fg(Color::Green))])
        }
    } else {
        Line::from(vec![Span::styled(line.to_string(), Style::default().fg(Color::Gray))])
    }
}

fn main() -> Result<(), io::Error> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app_state = AppState::new("main", "ey_rcrapsbash", "eucalypsih");
    let (tx, rx) = mpsc::channel::<AppEvent>();

    // THREAD 1: TAIL -F MONITOR
    let tx_log = tx.clone();
    thread::spawn(move || {
        let file = loop {
            if let Ok(f) = File::open("log.txt") {
                break f;
            }
            thread::sleep(Duration::from_millis(500));
        };
        let mut reader = BufReader::new(file);
        let _ = reader.seek(SeekFrom::End(0));
        let mut line = String::new();

        loop {
            match reader.read_line(&mut line) {
                Ok(0) => thread::sleep(Duration::from_millis(100)),
                Ok(_) => {
                    let cleaned_line = line.trim_end().to_string();
                    if tx_log.send(AppEvent::LogLine(cleaned_line)).is_err() { break; }
                    line.clear();
                }
                Err(_) => thread::sleep(Duration::from_millis(500)),
            }
        }
    });

    // THREAD 2: KEYBOARD MONITOR
    let tx_key = tx.clone();
    thread::spawn(move || {
        loop {
            if let Ok(true) = event::poll(Duration::from_millis(200)) {
                if let Ok(Event::Key(key)) = event::read() {
                    if key.kind == KeyEventKind::Press {
                        if tx_key.send(AppEvent::Key(key.code)).is_err() { break; }
                    }
                }
            }
        }
    });

    // TEMPLATE LAYOUT ADAPTIF
    let layout_vertikal = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1), 
            Constraint::Length(3), // Panel Info & Statistik
            Constraint::Min(5),    // Panel Utama Log
            Constraint::Length(1),
        ]);

    let layout_horizontal = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(2),
            Constraint::Percentage(96),
            Constraint::Percentage(2),
        ]);

    // MAIN LOOP TUI
    while !app_state.should_quit {
        terminal.draw(|f| {
            let area_layar = f.area();
            let area_vertikal = layout_vertikal.split(area_layar);
            
            let area_panel_info = layout_horizontal.split(area_vertikal[1]);
            let area_panel_log = layout_horizontal.split(area_vertikal[2]);

            // =========================================================================
            // RENDERING PANEL INFO + LIVE METRICS COUNTER
            // =========================================================================
            let info_text = vec![
                Span::styled("[✓] Branch: ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::styled(&app_state.current_branch, Style::default().fg(Color::White)),
                Span::styled(" | Repo: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.repo, Style::default().fg(Color::White)),
                Span::styled("  |  Owner: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.owner, Style::default().fg(Color::Yellow)),

                // Pembatas Visual ke metrik counter
                Span::styled("  ║  METRICS: ", Style::default().fg(Color::Magenta).add_modifier(Modifier::BOLD)),
                
                // Counter INFO (Hijau)
                Span::styled("Info: ", Style::default().fg(Color::Green)),
                Span::styled(format!("{} ", app_state.count_info), Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                
                // Counter WARN (Kuning)
                Span::styled("| Warn: ", Style::default().fg(Color::Yellow)),
                Span::styled(format!("{} ", app_state.count_warn), Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                
                // Counter ERROR (Merah)
                Span::styled("| Error: ", Style::default().fg(Color::Red)),
                Span::styled(format!("{} ", app_state.count_error), Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)),
            ];

            let widget_info = Paragraph::new(Line::from(info_text))
                .block(Block::default().title(" LIVE LOG STREAM MONITOR ").borders(Borders::ALL).border_style(Style::default().fg(Color::Magenta)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_info, area_panel_info[1]);

            // RENDERING PANEL LIVE LOGS
            let tinggi_maks_layar = area_panel_log[1].height as usize;
            let baris_efektif = jika_tinggi_kurang(tinggi_maks_layar); 

            let baris_diambil = if app_state.log_lines.len() > baris_efektif {
                &app_state.log_lines[app_state.log_lines.len() - baris_efektif..]
            } else {
                &app_state.log_lines[..]
            };

            let konten_log_berwarna: Vec<Line> = baris_diambil
                .iter()
                .map(|s| parsing_warna_log(s))
                .collect();

            let widget_log = Paragraph::new(konten_log_berwarna)
                .block(Block::default().title(" LOG MESSAGES (tail -f) - Tekan 'q' untuk keluar ").borders(Borders::ALL).border_style(Style::default().fg(Color::Cyan)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_log, area_panel_log[1]);
        })?;

        // EVENT CONSUMER
        if let Ok(event) = rx.recv_timeout(Duration::from_millis(16)) {
            match event {
                AppEvent::Key(code) => match code {
                    KeyCode::Char('q') | KeyCode::Esc => app_state.should_quit = true,
                    _ => {}
                },
                AppEvent::LogLine(line) => {
                    // Update counter statistik terlebih dahulu sebelum memotong atau menyimpan log
                    app_state.perbarui_statistik(&line);

                    if app_state.log_lines.len() >= 1000 {
                        app_state.log_lines.remove(0);
                    }
                    app_state.log_lines.push(line);
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("\x1B[1;32m[✓] Sesi peninjauan Real-time Log ditutup bersih.\x1B[0m");
    Ok(())
}

fn jika_tinggi_kurang(tinggi: usize) -> usize {
    if tinggi > 2 { tinggi - 2 } else { 1 }
}

```

## ⚙️ Keunggulan Arsitektur Metrik Ini
- Akurasi Total: Counter menghitung seluruh log yang melintas sejak TUI dibuka, bahkan jika baris log lama sudah dihapus dari *buffer* RAM TUI (`log_lines.remove(0)`) demi mencegah kebocoran memori.
- Alokasi Memori Ringan: Menyimpan angka statistik hanya memakan ukuran memori primitif `usize` (sangat kecil), alih-alih mempertahankan tumpukan string raksasa di memori.

## Ringkasan Alur Event & State Statistik

| Alur Siklus TUI | Aksi Terjadi | Pengaruh pada State / UI |
| :--- | :--- | :--- |
| **Data Log Masuk** | *Background Thread* menangkap baris log baru dari berkas. | Mengirimkan sinyal `AppEvent::LogLine` ke Main Thread. |
| **Pemrosesan Event** | Main Thread mengevaluasi teks melalui `.perbarui_statistik()`. | Angka variabel `count_info`, `count_warn`, atau `count_error` bertambah (+1). |
| **Siklus Menggambar** | `terminal.draw` dipanggil pada frame berikutnya. | `Span::styled` mengambil nilai angka terbaru dan mencetaknya di layar secara instan. |

Apakah Anda ingin saya **mengubah struktur tabel*i ini atau **menambahkan penjelasan kode** terkait fungsi-fungsi TUI (*Terminal User Interface*) yang ada di dalamnya?

---

qa: 
Sekarang aplikasinya sudah sangat fungsional dan informatif! Apakah Anda ingin menambahkan **fitur pembersih statistik (clear/reset counter)** dengan menekan tombol tertentu (misalnya tombol 'c'), atau apakah arsitektur *real-time stream metrics* ini sudah cukup memenuhi kebutuhan Anda?

























<br>
