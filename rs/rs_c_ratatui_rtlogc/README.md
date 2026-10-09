#

qc: 
penambahan **fitur pewarnaan otomatis (syntax highlighting)** untuk membedakan teks kode `[ERROR]`, `[INFO]`, dan `[WARN]`

---

aa: 
Untuk menambahkan fitur **syntax highlighting otomatis (pewarnaan log)**, kita tidak bisa lagi mengirim satu string polos (`String`) ke widget `Paragraph`. Kita harus membedah isi teks per baris dan memecahnya menjadi komponen `Span` yang memiliki warna (`Style`) berbeda.

Dalam standar industri Ratatui, optimasi ini dilakukan dengan membuat fungsi *parser* ringan yang mendeteksi kata kunci menggunakan metode bawaan `.contains()` atau `.starts_with()`. Pendekatan ini jauh lebih cepat dibanding menggunakan *Regular Expression* (Regex) yang memakan beban CPU besar setiap milidetik rendering.

## 🛠️ Perubahan Kode Utama
Berikut adalah kode aplikasi Ratatui TUI Anda yang telah diperbarui dengan modul **Log Parser Pintar**. Ganti fungsi `main` dan struktur rendering Anda dengan kode di bawah ini:

- `ratatui_rtlogc/Cargo.toml`
```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
ratatui = "0.30.2"   # Tambahkan library TUI standar industri Rust

```

- `ratatui_rtlogc/src/main.rs`
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

struct AppState {
    current_branch: String,
    repo: String,
    owner: String,
    log_lines: Vec<String>,
    should_quit: bool,
}

impl AppState {
    fn new(branch: &str, repo: &str, owner: &str) -> Self {
        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            log_lines: Vec::new(),
            should_quit: false,
        }
    }
}

// =========================================================================
// FITUR BARU: RENDERER & SYNTAX HIGHLIGHTER LOG OTOMATIS
// =========================================================================
fn parsing_warna_log(line: &str) -> Line<'static> {
    // Cari posisi tag log di dalam teks
    if line.contains("[ERROR]") {
        Line::from(vec![
            Span::styled(line.to_string(), Style::default().fg(Color::Red).add_modifier(Modifier::BOLD))
        ])
    } else if line.contains("[WARN]") {
        Line::from(vec![
            Span::styled(line.to_string(), Style::default().fg(Color::Yellow))
        ])
    } else if line.contains("[INFO]") {
        // Memberikan warna Hijau khusus untuk tag [INFO], sisanya putih standard
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
        // Jika tidak ada tag, gunakan warna abu-abu (misal log sistem biasa)
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

    // TEMPLATE LAYOUT
    let layout_vertikal = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1), 
            Constraint::Length(3), 
            Constraint::Min(5),    
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
            
            let area_panel_info = layout_horizontal.split(area_vertikal[1])[1];
            let area_panel_log = layout_horizontal.split(area_vertikal[2])[1];

            // Render Panel Info Top
            let info_text = vec![
                Span::styled("[✓] Branch: ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::styled(&app_state.current_branch, Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                Span::styled("  |  Repo: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.repo, Style::default().fg(Color::Yellow).add_modifier(Modifier::UNDERLINED)),
                Span::styled("  |  Owner: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.owner, Style::default().fg(Color::Yellow)),
            ];
            let widget_info = Paragraph::new(Line::from(info_text))
                .block(Block::default().title(" LIVE SYSTEM AUDIT ").borders(Borders::ALL).border_style(Style::default().fg(Color::Magenta)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_info, area_panel_info);

            // OPTIMASI DAN PEWARNAAN: Ambil log sebatas tinggi widget panel di layar
            let tinggi_maks_layar = area_panel_log.height as usize;
            // Dikurangi 2 untuk kompensasi garis border atas dan bawah widget
            let baris_efektif = jika_tinggi_kurang(tinggi_maks_layar); 

            let baris_diambil = if app_state.log_lines.len() > baris_efektif {
                &app_state.log_lines[app_state.log_lines.len() - baris_efektif..]
            } else {
                &app_state.log_lines[..]
            };

            // Mapping String murni menjadi Line bermotif warna secara real-time
            let konten_log_berwarna: Vec<Line> = baris_diambil
                .iter()
                .map(|s| parsing_warna_log(s))
                .collect();

            let widget_log = Paragraph::new(konten_log_berwarna)
                .block(Block::default().title(" REAL-TIME HIGHLIGHTED LOGS - Tekan 'q' untuk keluar ").borders(Borders::ALL).border_style(Style::default().fg(Color::Cyan)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_log, area_panel_log);
        })?;

        // EVENT CONSUMER
        if let Ok(event) = rx.recv_timeout(Duration::from_millis(16)) {
            match event {
                AppEvent::Key(code) => match code {
                    KeyCode::Char('q') | KeyCode::Esc => app_state.should_quit = true,
                    _ => {}
                },
                AppEvent::LogLine(line) => {
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

## 💡 Skema Pewarnaan Log yang Diterapkan
Saat Anda menjalankan skrip simulasi Python (`simulasi_log.py`) atau Bash loop yang kita buat sebelumnya, Ratatui akan langsung memberikan efek visual berikut:

| Teks Deteksi | Warna Tampilan | Gaya Teks (*Style*) | Kegunaan Industri |
| :--- | :--- | :--- | :--- |
| **[ERROR]** | **Merah Terang** | Cetak Tebal (*Bold*) | Menyoroti masalah fatal / *system crash* secara instan. |
| **[WARN]** | **Kuning** | Normal | Menandakan peringatan latensi atau kendala *resource*. |
| **[INFO]** | **Hijau** | Cetak Tebal pada Tag | Menunjukkan alur log normal (stempel waktu berwarna abu-abu). |
| *Lainnya* | Abu-abu Standard | Normal | Teks sistem atau *metadata* tambahan di luar kategori. |

Apakah Anda ingin saya **mengubah struktur kolomnya** atau **menambahkan baris kategori baru untuk dokumentasi sistem Anda**?

---

Anda akan melihat log yang masuk mengalir dengan pewarnaan kontras yang rapi, membuat proses pemantauan jauh lebih mudah dibaca oleh mata operator sistem.

---

qa: 
Fitur pewarnaan otomatis kini sudah aktif! Apakah Anda ingin melengkapinya dengan **fitur statistik counter** di panel atas (misal menampilkan jumlah total `Error: X | Warn: Y | Info: Z` yang sudah tertangkap sejak aplikasi dibuka)?


<br>
