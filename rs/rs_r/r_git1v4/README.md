# 

qc: 
menambahkan **widget tambahan** di bawah panel informasi tersebut (pada area sisa `Constraint::Min(0)`) indikator status proses pengunduhan (*loading progress bar*)

---

aa: 
Untuk menambahkan indikator status proses pengunduhan (*loading progress bar*) pada sisa area `Constraint::Min(0)`, kita dapat menggunakan widget `Gauge` bawaan dari **Ratatui**. Widget ini didesain khusus untuk menampilkan persentase *progress* secara visual dan terstruktur di dalam terminal.

Agar status pengunduhan ini dinamis dan tidak membuat aplikasi membeku (*freeze*), status persentase (`download_progress`) harus disimpan ke dalam `AppState`. Di dalam loop aplikasi utama, nilai ini akan disimulasikan meningkat secara bertahap hingga mencapai 100%.

Berikut adalah kode solusi lengkap yang telah diintegrasikan secara bersih dan rapi:

## Kode Solusi Lengkap (Termasuk Gauge Progress Bar)
- `r_git1v4/Cargo.toml`
```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
ratatui = "0.30.2"   # Tambahkan library TUI standar industri Rust

```

---

- `r_git1v4/src/main.rs`
```rust
use std::io;
use std::time::Duration;
use std::path::{Path, PathBuf}; 
use std::process::Command;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Gauge, Wrap},
    Frame, Terminal,
};

// =========================================================================
// KONSTANTA LOG & LABEL UI (Rekomendasi Terbaik untuk Kerapian Kode)
// =========================================================================
const MSG_CLONE_SUCCESS: &str = "[✓] Git clone berhasil dieksekusi secara sinkron.";
const MSG_CLONE_FAILED: &str = "[!] Git clone gagal. Status: {:?}, Pesan: {}";
const MSG_NO_STDERR: &str = "Tidak ada pesan galat standar";
const MSG_SUBSYSTEM_ERROR: &str = "[!] Gagal memicu eksekusi subsistem perintah git: {}";
const MSG_SESSION_CLEANUP: &str = "\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m";

// Label untuk TUI Render
const LABEL_OWNER: &str = " Owner: ";
const LABEL_REPO: &str = " Repo: ";
const LABEL_BRANCH: &str = " Branch: ";
const UI_SEPARATOR: &str = " │ ";

/// Struktur data State Management dengan penambahan state progress unduhan.
pub struct AppState {
    pub current_branch: String,
    pub repo: String,
    pub owner: String,
    pub privkey_path: PathBuf,
    pub output_dir: PathBuf,
    pub download_progress: u16, // Nilai 0 sampai 100 untuk Progress Bar Gauge
    should_quit: bool,
}

impl AppState {
    pub fn new<P: AsRef<Path>>(
        branch: &str, 
        repo: &str, 
        owner: &str, 
        privkey_path: P, 
        output_dir: P, 
    ) -> Self {
        let privkey: &Path = privkey_path.as_ref();
        let output: &Path = output_dir.as_ref();
        
        if !output.exists() {
            let ssh_command: String = format!("ssh -i {} -o IdentitiesOnly=yes", privkey.display());
            let repo_url: String = format!("git@github.com:{}/{}.git", owner, repo);

            let output_res = Command::new("git")
                .args([
                    "clone",
                    "-q",
                    "--filter=blob:none",
                    "--no-checkout",
                    "-c",
                    &format!("core.sshCommand={}", ssh_command),
                    &repo_url,
                    output.to_string_lossy().as_ref(),
                ])
                .output();

            match output_res {
                Ok(out) if out.status.success() => {
                    println!("{}", MSG_CLONE_SUCCESS);
                }
                Ok(out) => {
                    let err_msg: std::borrow::Cow<'_, str> = String::from_utf8_lossy(&out.stderr);
                    eprintln!(
                        "{}",
                        format!(
                            "{}{}",
                            MSG_CLONE_FAILED.replace("{:?}", &format!("{:?}", out.status.code())).replace("{}", ""),
                            if err_msg.is_empty() { MSG_NO_STDERR } else { &err_msg }
                        )
                    );
                }
                Err(err) => {
                    eprintln!("{}", MSG_SUBSYSTEM_ERROR.replace("{}", &err.to_string()));
                }
            }
        }

        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            privkey_path: privkey.to_path_buf(),
            output_dir: output.to_path_buf(),
            download_progress: 0, // Awal mula progress dari 0%
            should_quit: false,
        }
    }

    /// Metode untuk memperbarui progress secara berkala dan aman
    pub fn update_progress(&mut self) {
        if self.download_progress < 100 {
            self.download_progress += 1;
        }
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }

    pub fn should_quit(&self) -> bool {
        self.should_quit
    }
}

fn main() -> Result<(), io::Error> {
    enable_raw_mode()?;
    let mut stdout: io::Stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    
    let backend: CrosstermBackend<io::Stdout> = CrosstermBackend::new(stdout);
    let mut terminal: Terminal<CrosstermBackend<io::Stdout>> = Terminal::new(backend)?;

    let mut app_state: AppState = AppState::new(
        "main",
        "ey_rcrapsbash",
        "eucalypsih",
        "~/.ssh/id_rsa",
        "./output_repo"
    );

    // Tata Letak Vertikal: Panel Info (3 baris), Kotak Progress (3 baris), Sisa Kosong (Min 0)
    let layout_vertikal: Layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),      // Baris Atas: Panel Info
            Constraint::Length(3),      // Baris Tengah: Progress Bar
            Constraint::Min(0),         // Baris Bawah: Area Kerja Utama (Kelak)
        ]);

    let layout_horizontal: Layout = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(5),   
            Constraint::Percentage(90),  
            Constraint::Percentage(5),   
        ]);

    let poll_timeout: Duration = Duration::from_millis(16); // Target responsivitas ~60 FPS

    // LOOP RENDERING
    while !app_state.should_quit() {
        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);
            
            // 1. RENDER PANEL ATAS (REPOSITORY INFO)
            if let Some(&v_idx_0) = area_vertikal.get(0) {
                let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(v_idx_0);
                if let Some(&area_kotak_panel_info) = area_horizontal.get(1) {
                    
                    let info_text: Vec<Span> = vec![
                        Span::styled(LABEL_OWNER, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.owner, Style::default().fg(Color::White)),
                        Span::styled(UI_SEPARATOR, Style::default().fg(Color::DarkGray)),
                        Span::styled(LABEL_REPO, Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.repo, Style::default().fg(Color::White)),
                        Span::styled(UI_SEPARATOR, Style::default().fg(Color::DarkGray)),
                        Span::styled(LABEL_BRANCH, Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.current_branch, Style::default().fg(Color::White)),
                    ];

                    let widget_paragraf: Paragraph = Paragraph::new(Line::from(info_text))
                        .block(Block::default().title(" Repository Status ").borders(Borders::ALL).border_style(Style::default().fg(Color::Magenta)))
                        .wrap(Wrap { trim: true });
                        
                    f.render_widget(widget_paragraf, area_kotak_panel_info);
                }
            }

            // 2. RENDER WIDGET PROGRESS BAR (GAUGE)
            if let Some(&v_idx_1) = area_vertikal.get(1) {
                let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(v_idx_1);
                if let Some(&area_kotak_progress) = area_horizontal.get(1) {
                    
                    // Membuat visualisasi status text di dalam gauge
                    let label_status: String = if app_state.download_progress < 100 {
                        format!("Mengunduh repositori... {}%", app_state.download_progress)
                    } else {
                        "Repositori Sinkron! [✓]".to_string()
                    };

                    // Implementasi Widget Gauge bawaan Ratatui
                    let widget_gauge: Gauge = Gauge::default()
                        .block(Block::default().title(" Download Status ").borders(Borders::ALL).border_style(Style::default().fg(Color::Blue)))
                        .gauge_style(
                            Style::default()
                                .fg(if app_state.download_progress < 100 { Color::Blue } else { Color::Green }) // Berubah hijau saat selesai
                                .bg(Color::Black)
                                .add_modifier(Modifier::ITALIC | Modifier::BOLD)
                        )
                        .percent(app_state.download_progress)
                        .label(label_status);

                    f.render_widget(widget_gauge, area_kotak_progress);
                }
            }
        })?;

        // EVENT HANDLING & STATE TICK SIMULATION
        // Nilai progress bertambah setiap loop mendeteksi timeout (tidak ada input tombol)
        if event::poll(poll_timeout)? { 
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press { 
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => app_state.quit(),
                        _ => {}
                    }
                }
            }
        } else {
            // Ketika tidak ada tombol yang ditekan, loop mengalir ke sini dan menaikkan progress
            app_state.update_progress();
        }
    }

    // CLEANUP TERMINAL
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("{}", MSG_SESSION_CLEANUP);
    Ok(())
}

```

---

## Detail Pembaruan Desain Dan Logika TUI
### 1. Penggunaan Widget Gauge Ratatui:
Widget `Gauge` digunakan secara eksklusif untuk menggambar batang persentase. Ia mengonsumsi nilai bilangan bulat `u16` dari rentang `0` hingga `100` lewat fungsi `.percent()`.
### 2. Perubahan Warna Status Secara Dinamis (Reactive Color):
Pada opsi `.gauge_style()`, terdapat logika kondisional. Selama persentase di bawah 100%, batang pengisian akan berwarna **Biru (`Color::Blue`)**, namun saat menyentuh angka 100%, secara otomatis warnanya berubah menjadi **Hijau (`Color::Green`)**. Ini memberikan kepuasan umpan balik visual (*User Experience*) yang sangat baik bagi pengguna.
### 3. Pemanfaatan Sisa Area Polling Timeout:
Fungsi `event::poll(poll_timeout)` akan menghasilkan nilai balik `false` jika dalam rentang 16 milidetik tidak ada interaksi keyboard dari pengguna. Blok `else` menangkap momen kosong ini untuk memicu eksekusi `.update_progress()`, menciptakan efek animasi pengisian progress bar secara halus (*smooth simulation*).

## Ringkasan Distribusi Blok Tata Letak (Layout Blueprint)


| Elemen Indeks | Batasan Tinggi ( Constraint ) | Komponen Widget | Perilaku Warna Utama |
| :--- | :--- | :--- | :--- |
| `v_idx_0` (Atas) | `Constraint::Length(3)` | Paragraph (Metadata Repo) | Border Magenta, Teks multi-warna ( Cyan / Green / Yellow ) |
| `v_idx_1` (Tengah) | `Constraint::Length(3)` | Gauge (Progress Status) | Border Biru, Batang Biru (Mengunduh) → Hijau (Selesai) |
| `v_idx_2` (Bawah) | `Constraint::Min(0)` | *Kosong / Siap Digunakan* | Menjamin elastisitas layar untuk sisa komponen masa depan |

Apakah Anda membutuhkan **penyesuaian format tabel** lain (seperti menambahkan kolom baru) atau ingin mengubah komponen ini menjadi **kode program spesifik** (misalnya untuk framework UI tertentu)?

---

qa: 
Apakah simulasi animasi peningkatan nilai progress ini sudah cukup pas bagi Anda, atau Anda ingin langsung **menghubungkannya dengan indikator byte real-time** dari command pengunduhan latar belakang (*Async Task/Thread*)?










<br>
