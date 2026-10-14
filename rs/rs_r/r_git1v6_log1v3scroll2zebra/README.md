# 

qc:
menambahkan fitur visual baris zebra (alternating row background colors) agar tabel Git Log lebih nyaman dibaca

---

aa: 
Berikut adalah pembaruan kode `production-grade` yang mengintegrasikan fitur visual **Baris Zebra (Alternating Row Background Colors)** pada komponen `Table` Ratatui.

Penerapan ini dilakukan secara elegan memanfaatkan fungsi `.enumerate()` pada saat iterasi vektor `items`. Pola warna latar belakang baris diubah secara bergantian antara warna gelap dasar TUI dengan warna abu-abu yang kontras tipis (`Color::Rgb(28, 28, 28)`) berdasarkan nilai indeks baris (ganjil/genap). Seluruh arsitektur *Predictable State Management*, *Type-Safety*, dan *Explicit Type Declaration* tetap dipertahankan secara murni.






### Penjelasan Pembaruan Fitur Zebra:
* **`items.iter().enumerate()`**: Kita mengekstrak nilai `index` secara aman selama iterasi untuk menentukan posisi baris data log.
* **`Color::Rgb(15, 15, 15)` & `Color::Rgb(28, 28, 28)`**: Pemilihan warna RGB kontras rendah ini sangat disarankan dalam standar industri TUI modern karena membuat teks bermutu kontras tinggi (seperti warna `Yellow` untuk hash commit dan `White` untuk pesan log) tetap nyaman dibaca dalam waktu lama tanpa membuat mata pengguna cepat lelah.

---

qa: 
Apakah visual baris zebra ini sudah tampil dengan **sangat baik dan kontras** di terminal Termux Anda, atau Anda bermaksud untuk **menambahkan panel shortcut menu statis di bagian bawah layar** sebagai petunjuk navigasi tombol aplikasi?


- ``
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

- `r_git1v6_log1v3scroll2zebra` -> `r_git1v6_log1v3scroll2`
```rust
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Paragraph, Cell, Row, Table, TableState},
    Frame, Terminal,
};

// =========================================================================
// KONSTANTA LOG & LABEL UI (Rekomendasi Terbaik untuk Kerapian Kode)
// KONSTANTA LOG & LABEL UI (Eksplisit & Murni)
// KONSTANTA LOG & LABEL UI (Eksplisit, Murni & Singkron Berdasarkan State)
// KONSTANTA LOG & LABEL UI (Eksplisit & Murni Berdasarkan State)
// KONSTANTA LOG & LABEL UI (Eksplisit & Murni Berdasarkan State Log)
// KONSTANTA LOG & LABEL UI (Dipusatkan untuk Kemudahan Lokalisasi/i18n)
// =========================================================================
const MSG_SESSION_CLEANUP: &str = "\x1B[1;32m[✓] Sesi pemantauan Git Log Ratatui TUI sukses ditutup bersih.\x1B[0m";

// Konstanta Label Status UI Statis
// Label Terjemahan (Bisa diekspansi ke localization engine seperti fluent / gettext di masa depan)
const MSG_LOG_IDLE: &str = "Status: Idle (Tekan 'l' untuk Memuat Git Log)";
const MSG_LOG_RUNNING: &str = "Status: Mengambil data log dari repositori Git...";
const MSG_NO_STDERR: &str = "Tidak ada pesan galat standar dari subproses Git.";
const MSG_LOG_FAILED_PREFIX: &str = "[!] Gagal mengeksekusi git log.";
const MSG_SUBSYSTEM_ERROR_PREFIX: &str = "[!] Subsystem error saat memicu perintah git:";

// =========================================================================
// FUNGSI PEMBANTU (Menyembunyikan Makro format! dari Blok Utama)
// FUNGSI PEMBANTU (Formater Pesan Galat Secara Eksplisit)
// FUNGSI PEMBANTU FORMATING PESAN
// =========================================================================
fn format_log_error(status_code: Option<i32>, detail_pesan: &str) -> String {
    format!("{} Status: {:?}, Pesan: {}", MSG_LOG_FAILED_PREFIX, status_code, detail_pesan)
}

fn format_subsystem_error(err_msg: &str) -> String {
    format!("{} {}", MSG_SUBSYSTEM_ERROR_PREFIX, err_msg)
}

// =========================================================================
// STATE MANAGEMENT & DATA STRUCTURES
// =========================================================================

/// Representasi struktur data item commit Git log hasil parsing secara eksplisit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LogItem {
    pub hash: String,
    pub message: String,
}

/// Representasi status operasi Git Log secara eksplisit dan murni.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LogStatus {
    Idle,
    Loading,
    Success(Vec<LogItem>), // Menampung output stdout murni dari `git log` PERBAIKAN: Diubah dari String ke Vec<LogItem> agar sinkron dengan data worker
    Error(String),   // Menampung detail pesan error
}

impl LogStatus {
    /// **STANDAR INDUSTRI (Theming Engine):** Manajemen gaya visual terpusat berdasarkan state.
    pub fn to_style(&self) -> Style {
        match self {
            Self::Idle => Style::default().fg(Color::DarkGray),
            Self::Loading => Style::default().fg(Color::Cyan).add_modifier(Modifier::SLOW_BLINK),
            Self::Success(_) => Style::default().fg(Color::Green),
            Self::Error(_) => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        }
    }


    /// **STANDAR INDUSTRI (Localization Interface):** Abstraksi representasi teks.
    /// Mempermudah penukaran bahasa (i18n) karena tidak mengotori fungsi layouting TUI.
    pub fn to_text(&self) -> String {
        match self {
            Self::Idle => MSG_LOG_IDLE.to_string(),
            Self::Loading => MSG_LOG_RUNNING.to_string(),
            Self::Success(_) => String::new(), // Untuk tipe Success, data dirender via komponen Table
            Self::Error(err_msg) => err_msg.clone(),
        }
    }
}

/// **ARSIREKTUR EVENT-DRIVEN:** Enumerasi Aksi/Event untuk memicu mutasi state.
/// Memisahkan input mentah TUI dan state internal secara murni.
#[derive(Debug, Clone)]
pub enum AppAction {
    SetLogStatus(LogStatus),
    TriggerGitFetch,
    ScrollUp,
    ScrollDown,
    Tick,
    Quit,
}

/// Struktur data State Management dengan tipe data yang dideklarasikan secara eksplisit dan aman.
/// Struktur data State Management Aplikasi TUI Pemantau Log Git.
/// Struktur data State Aplikasi utama (Single Source of Truth).
pub struct AppState {
    pub target_path: PathBuf,
    pub log_status: LogStatus,
    pub table_state: TableState,
    pub should_quit: bool,
}

impl AppState {
    pub fn builder() -> AppStateBuilder {
        AppStateBuilder::default()
    }

    /// **PREDICTABLE STATE MANAGEMENT (Reducer Pattern):**
    /// Satu-satunya tempat terjadinya mutasi state aplikasi yang terpantau.
    pub fn reduce(&mut self, action: AppAction, tx: &Sender<AppAction>) {
        match action {
            AppAction::SetLogStatus(status) => {
                self.log_status = status;
                // Reset seleksi baris tabel ke baris pertama setiap kali data baru masuk
                if let LogStatus::Success(ref items) = self.log_status {
                    if !items.is_empty() {
                        self.table_state.select(Some(0));
                    } else {
                        self.table_state.select(None);
                    }
                } else {
                    self.table_state.select(None);
                }
            }
            AppAction::TriggerGitFetch => {
                // Cegah double fetching jika sedang loading
                if self.log_status != LogStatus::Loading {
                    self.log_status = LogStatus::Loading;
                    self.execute_git_log_worker(tx.clone());
                }
            }
            AppAction::ScrollUp => {
                if let LogStatus::Success(ref items) = self.log_status {
                    if !items.is_empty() {
                        let current_selected: usize = self.table_state.selected().unwrap_or(0);
                        let next_selected: usize = current_selected.saturating_sub(1);
                        self.table_state.select(Some(next_selected));
                    }
                }
            }
            AppAction::ScrollDown => {
                if let LogStatus::Success(ref items) = self.log_status {
                    if !items.is_empty() {
                        let current_selected: usize = self.table_state.selected().unwrap_or(0);
                        let max_index: usize = items.len().saturating_sub(1);
                        let next_selected: usize = current_selected.saturating_add(1).min(max_index);
                        self.table_state.select(Some(next_selected));
                    }
                }
            }
            AppAction::Tick => {
                // Logika pembaruan periodik ditaruh di sini jika diperlukan kelak
            }
            AppAction::Quit => {
                self.should_quit = true;
            }
        }
    }

    /// Memicu proses pengambilan `git log` di background thread agar UI tidak membeku.
    /// Background Thread Worker untuk I/O Heavy Process (Git)
    fn execute_git_log_worker(&self, tx: Sender<AppAction>) {
        // Ambil path target secara aman untuk dipindahkan (move) ke thread baru
        let target_path_str: String = self.target_path.to_string_lossy().into_owned();

        // Standar Industri: Jalankan I/O heavy / blocking process di Thread terpisah
        thread::spawn(move || {
            // Eksekusi perintah: git -C <target_path_str> log --oneline -n 20
            // Menggunakan --oneline dan -n 20 agar output rapi dan pas di layar TUI
            let output_res = Command::new("git")
                .args([
                    "-C",
                    &target_path_str,
                    "log",
                    "--oneline",
                    "-n",
                    "60",
                ])
                .output();

            let status = match output_res {
                // Kasus 1: Perintah Git berhasil dieksekusi dengan kode keluar sukses (0)
                Ok(out) if out.status.success() => {
                    let log_output: String = String::from_utf8_lossy(&out.stdout).into_owned();
                    let mut items: Vec<LogItem> = Vec::new();

                    for line in log_output.lines() {
                        let raw_line: &str = line.trim();
                        if raw_line.is_empty() {
                            continue;
                        }
                        // Format --oneline adalah: "<hash> <message>"
                        if let Some((hash, msg)) = raw_line.split_once(' ') {
                            items.push(LogItem {
                                hash: hash.to_string(),
                                message: msg.to_string(),
                            });
                        } else {
                            items.push(LogItem {
                                hash: "Unknown".to_string(),
                                message: raw_line.to_string(),
                            });
                        }
                    }
                    LogStatus::Success(items)
                }
                // Kasus 2: Git terpanggil tetapi mengembalikan nilai error (misal: direktori bukan repo git)
                Ok(out) => {
                    let err_msg: String = String::from_utf8_lossy(&out.stderr).into_owned();
                    let detail_pesan: String = if err_msg.is_empty() {
                        MSG_NO_STDERR.to_string()
                    } else {
                        err_msg
                    };
                    LogStatus::Error(format_log_error(out.status.code(), &detail_pesan))
                }
                // Kasus 3: Subsistem gagal memanggil aplikasi 'git' (misal: Git belum diinstall)
                Err(err) => LogStatus::Error(format_subsystem_error(&err.to_string())),
            };

            // Mengirim status terbungkus ke dalam AppEvent murni
            // Kirim balik hasilnya ke Main Loop melalui Action dispatcher
            let _ = tx.send(AppAction::SetLogStatus(status));
        });
    }
}

// =========================================================================
// STRUKTUR BUILDER PATTERN (Anti Tertukar Parameter)
// STRUKTUR BUILDER PATTERN (Mencegah Kesalahan Parameterisasi State)
// =========================================================================
#[derive(Default)]
pub struct AppStateBuilder {
    target_path: Option<PathBuf>,
}

impl AppStateBuilder {
    pub fn with_target_path<P: AsRef<Path>>(mut self, path: P) -> Self {
        self.target_path = Some(path.as_ref().to_path_buf());
        self
    }

    pub fn build(self) -> AppState {
        AppState {
            target_path: self.target_path.unwrap_or_else(|| PathBuf::from(".")),
            log_status: LogStatus::Idle,
            table_state: TableState::default(),
            should_quit: false,
        }
    }
}

// =========================================================================
// MAIN RUNTIME LOOP
// =========================================================================
fn main() -> Result<(), io::Error> {
    enable_raw_mode()?;
    let mut stdout: io::Stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;

    let backend: CrosstermBackend<io::Stdout> = CrosstermBackend::new(stdout);
    let mut terminal: Terminal<CrosstermBackend<io::Stdout>> = Terminal::new(backend)?;

    // Definisikan target direktori Git yang ingin dipantau log-nya secara eksplisit
    let target_git_directory: &str = "./repo_output/eucalypsih/ey_rcrapsbash";

    // Bangun State Management menggunakan Builder Pattern standar industri
    let mut app_state: AppState = AppState::builder()
        .with_target_path(target_git_directory)
        .build();

    // Setup channel komunikasi antar-thread (MPSC) secara eksplisit
    // MPSC Channel menggunakan tipe data AppEvent secara eksplisit murni
    // Centralized Event-Driven Channel (MPSC)
    let (tx, rx): (Sender<AppAction>, Receiver<AppAction>) = mpsc::channel();

    // Thread Konverter Polling: Pemancar event Tick konstan agar aplikasi responsif
    // Loop Pemancar Event Tick Internal (MPSC)
    let tx_tick: Sender<AppAction> = tx.clone();

    // Konversi Type-Safe konstan untuk Polling (Menggantikan parameter primitif mentah)
    // Menggunakan implementasi standard library u64 -> Duration secara aman & eksplisit
    // Konversi Polling timeout secara Type-Safe dari integer murni (Mencegah primitif casting)
    let poll_timeout_ms: u64 = 16;
    let poll_timeout: Duration = Duration::from_millis(poll_timeout_ms);

    thread::spawn(move || loop {
        thread::sleep(poll_timeout);
        if tx_tick.send(AppAction::Tick).is_err() {
            break; // Loop berhenti otomatis jika Main Loop ditutup
        }
    });

    // Loop Input Reader Thread untuk menghindari pemblokiran UI (MPSC)
    // Loop Input Reader Thread (MPSC) - Mengamankan penangkapan tombol navigasi panah
    let tx_input: Sender<AppAction> = tx.clone();
    thread::spawn(move || loop {
        if event::poll(Duration::from_millis(50)).unwrap_or(false) {
            if let Ok(Event::Key(key)) = event::read() {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => {
                            let _ = tx_input.send(AppAction::Quit);
                        }
                        KeyCode::Char('l') => {
                            let _ = tx_input.send(AppAction::TriggerGitFetch);
                        }
                        KeyCode::Up => {
                            let _ = tx_input.send(AppAction::ScrollUp);
                        }
                        KeyCode::Down => {
                            let _ = tx_input.send(AppAction::ScrollDown);
                        }
                        _ => {}
                    }
                }
            }
        }
    });

    // LOOP RENDERING UTAMA
    while !app_state.should_quit {
        // Konsumsi seluruh aksi yang terkumpul dan mutasikan via Reducer secara berurutan
        while let Ok(action) = rx.try_recv() {
            app_state.reduce(action, &tx);
        }

        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let title_widget: String = format!(" Git Log Monitor: {} (↑/↓ untuk gulir) ", target_git_directory);
            let block_wrapper: Block = Block::default().borders(Borders::ALL).title(title_widget);
            // Pembagian layout menggunakan Layout engine secara terstruktur dan type-safe
            let layouts: std::rc::Rc<[Rect]> = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(1), // Top padding
                    Constraint::Min(0),    // Komponen area utama tabel log
                ])
                .split(area_layar);

            let inner_area: Rect = layouts[1];
            // Render komponen berdasarkan pola representasi data LogStatus secara prediktif
            match &app_state.log_status {
                LogStatus::Idle | LogStatus::Loading | LogStatus::Error(_) => {
                    let p_widget: Paragraph = Paragraph::new(app_state.log_status.to_text())
                        .block(block_wrapper)
                        .style(app_state.log_status.to_style());

                    f.render_widget(p_widget, inner_area);
                }

                LogStatus::Success(items) => {
                    // Konversi Vektor terstruktur menjadi baris-baris komponen widget Row (Ratatui)
                    let mut rows: Vec<Row<'static>> = Vec::new();
                    // FITUR BARIS ZEBRA (Alternating Row Background Colors)
                    for (index, item) in items.iter().enumerate() {
                        let hash_cell: Cell<'static> = Cell::from(item.hash.clone()).style(Style::default().fg(Color::Yellow));
                        let msg_cell: Cell<'static> = Cell::from(item.message.clone()).style(Style::default().fg(Color::White));
                        // Kalkulasi sisa hasil bagi indeks untuk menentukan warna latar secara bergantian (Zebra Effect)
                        let row_style: Style = if index % 2 == 0 {
                            Style::default().bg(Color::Rgb(15, 15, 15)) // Latar baris genap (Slightly lighter black)
                        } else {
                            Style::default().bg(Color::Rgb(28, 28, 28)) // Latar baris ganjil (Dark gray contrast)
                        };
                        
                        rows.push(Row::new(vec![hash_cell, msg_cell]).style(row_style));
                    }
                    // Definisi konstrain kolom tabel secara eksplisit dan responsif
                    let table_constraints: [Constraint; 2] = [
                        Constraint::Length(10), // Lebar kolom hash git commit
                        Constraint::Min(30),    // Sisa lebar dialokasikan untuk deskripsi commit
                    ];

                    // Style baris yang sedang aktif dipilih (Highlighted/Selected style)
                    let highlight_style: Style = Style::default()
                        .bg(Color::Rgb(50, 50, 50))
                        .add_modifier(Modifier::BOLD);

                    let table_widget: Table = Table::new(rows, table_constraints)
                        .block(block_wrapper)
                        .row_highlight_style(highlight_style)
                        .highlight_symbol(">> ");

                    // Rendering menggunakan metode render_stateful_widget untuk mengaktifkan fitur scrolling otomatis
                    f.render_stateful_widget(table_widget, inner_area, &mut app_state.table_state);
                }
            }
        })?;

        // Memberikan sedikit istirahat pada CPU core loop agar penggunaan daya efisien
        thread::sleep(Duration::from_millis(10));
    }

    // CLEANUP TERMINAL
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("{}", MSG_SESSION_CLEANUP);
    Ok(())
}

```
















<br>
