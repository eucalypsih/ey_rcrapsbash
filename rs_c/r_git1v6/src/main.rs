use std::io;
use std::path::{Path, PathBuf};
use std::time::Duration;
use std::sync::mpsc::{self, Receiver, Sender};
use std::process::Command;
use std::thread;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame, Terminal,
};

// =========================================================================
// KONSTANTA LOG & LABEL UI (Rekomendasi Terbaik untuk Kerapian Kode)
// KONSTANTA LOG & LABEL UI (Eksplisit & Murni)
// KONSTANTA LOG & LABEL UI (Eksplisit, Murni & Singkron Berdasarkan State)
// =========================================================================
const MSG_SESSION_CLEANUP: &str = "\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m";

// Konstanta Label Status UI Statis
const MSG_CLONE_IDLE: &str = "Status: Idle (Tekan 'c' untuk Clone)";
const MSG_CLONE_RUNNING: &str = "Status: Menyinkronkan Repositori Git...";
const MSG_CLONE_SUCCESS: &str = "[✓] Git clone berhasil dieksekusi secara sinkron.";
const MSG_CLONE_FAILED_PREFIX: &str = "[!] Git clone gagal.";
const MSG_NO_STDERR: &str = "Tidak ada pesan galat standar";
const MSG_SUBSYSTEM_ERROR_PREFIX: &str = "[!] Gagal memicu eksekusi subsistem perintah git:";

// =========================================================================
// FUNGSI PEMBANTU (Menyembunyikan Makro format! dari Blok Utama)
// =========================================================================
fn format_clone_error(status_code: Option<i32>, detail_pesan: &str) -> String {
    format!("{} Status: {:?}, Pesan: {}", MSG_CLONE_FAILED_PREFIX, status_code, detail_pesan)
}

fn format_subsystem_error(err_msg: &str) -> String {
    format!("{} {}", MSG_SUBSYSTEM_ERROR_PREFIX, err_msg)
}

/// Representasi status operasi Git Clone secara eksplisit dan murni.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CloneStatus {
    Idle,
    Cloning,
    Success(String), // Diubah agar dapat menampung pesan sukses dari konstanta
    Error(String),
}

impl CloneStatus {
    pub fn to_style(&self) -> Style {
        match self {
            Self::Idle => Style::default().fg(Color::DarkGray),
            Self::Cloning => Style::default().fg(Color::Cyan).add_modifier(Modifier::SLOW_BLINK),
            Self::Success(_) => Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
            Self::Error(_) => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        }
    }

    pub fn to_text(&self) -> String {
        match self {
            Self::Idle => MSG_CLONE_IDLE.to_string(),
            Self::Cloning => MSG_CLONE_RUNNING.to_string(),
            Self::Success(msg) => msg.clone(), // Menampilkan pesan sukses dari thread
            Self::Error(err) => err.clone(),   // Menampilkan pesan galat lengkap dari thread
        }
    }
}

/// Struktur data State Management dengan tipe data yang dideklarasikan secara eksplisit dan aman.
pub struct AppState {
    pub current_branch: String,
    pub repo: String,
    pub owner: String,
    pub privkey_path: PathBuf,
    pub output_dir: PathBuf,
    pub clone_status: CloneStatus,
    should_quit: bool,
}

impl AppState {
    /// Konstruktor idiomatik dengan trait generic `AsRef<Path>` untuk flexibilitas path file.
    pub fn new<P: AsRef<Path>>(
        branch: &str,
        repo: &str,
        owner: &str,
        privkey_path: P,
        output_dir: P,
    ) -> Self {
        let privkey: &Path = privkey_path.as_ref();
        let output: &Path = output_dir.as_ref();

        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            privkey_path: privkey.to_path_buf(),
            output_dir: output.to_path_buf(),
            clone_status: CloneStatus::Idle,
            should_quit: false,
        }
    }

    fn quit(&mut self) {
        self.should_quit = true;
    }

    /// Memicu proses git clone di background thread agar tidak memblokir rendering TUI.
    fn trigger_git_clone(&mut self, tx: Sender<CloneStatus>) {
        // Cegah eksekusi ganda jika proses sedang berjalan
        if self.clone_status == CloneStatus::Cloning {
            return;
        }

        self.clone_status = CloneStatus::Cloning;

        // Kloning data untuk dipindahkan (move) ke thread terpisah secara aman
        let owner: String = self.owner.clone();
        let repo: String = self.repo.clone();
        let privkey: PathBuf = self.privkey_path.clone();
        let output_dir: PathBuf = self.output_dir.clone();

        // Standar Industri: Jalankan I/O heavy / blocking command di Thread terpisah
        thread::spawn(move || {
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
                    &output_dir.to_string_lossy(),
                ])
                .output();

            match output_res {
                // Kasus 1: Perintah Git berhasil dieksekusi dan mengembalikan status sukses (Exit Code 0)
                Ok(out) if out.status.success() => {
                    // MSG_CLONE_SUCCESS digunakan langsung karena tidak membutuhkan placeholder
                    let _ = tx.send(CloneStatus::Success(MSG_CLONE_SUCCESS.to_string()));
                }
                // Kasus 2: Perintah Git berhasil dieksekusi tetapi gagal di tingkat sistem Git (misal: repositori tidak ditemukan)
                Ok(out) => {
                    let err_msg: String = String::from_utf8_lossy(&out.stderr).into_owned();
                    let detail_pesan = if err_msg.is_empty() {
                        MSG_NO_STDERR.to_string() // Menggunakan MSG_NO_STDERR jika stderr kosong
                    } else {
                        err_msg
                    };

                    // Menggunakan MSG_CLONE_FAILED menggunakan makro format!
                    let final_err = format_clone_error(out.status.code(), &detail_pesan);
                    let _ = tx.send(CloneStatus::Error(final_err));
                }
                // Kasus 3: Subsistem gagal memicu perintah (misal: aplikasi 'git' tidak terpasang di OS)
                Err(err) => {
                    // Menggunakan MSG_SUBSYSTEM_ERROR untuk kegagalan fatal pemanggilan Command
                    let final_err = format_subsystem_error(&err.to_string());
                    let _ = tx.send(CloneStatus::Error(final_err));
                }
            }
        });
    }
}

fn main() -> Result<(), io::Error> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    
    let backend: CrosstermBackend<io::Stdout> = CrosstermBackend::new(stdout);
    let mut terminal: Terminal<CrosstermBackend<io::Stdout>> = Terminal::new(backend)?;

    // Parameterisasi konfigurasi
    let private_key_path: &str = "~/.ssh/id_rsa"; // Contoh lokasi private key
    let destination_dir: &str = "./repo_output";

    // Inisialisasi State dengan menyertakan path private key SSH
    let mut app_state: AppState = AppState::new(
        "main", 
        "ey_rcrapsbash", 
        "eucalypsih", 
        private_key_path,
        destination_dir,
    );

    // Setup channel komunikasi antar-thread secara eksplisit
    let (tx, rx): (Sender<CloneStatus>, Receiver<CloneStatus>) = mpsc::channel();

    // Konversi Type-Safe konstan untuk Polling (Menggantikan parameter primitif mentah)
    // Menggunakan implementasi standard library u64 -> Duration secara aman & eksplisit
    let poll_timeout: Duration = Duration::from_millis(16);

    // LOOP RENDERING
    while !app_state.should_quit {
        // Ambil pembaruan status dari background thread tanpa memblokir loop (non-blocking)
        if let Ok(new_status) = rx.try_recv() {
            app_state.clone_status = new_status;
        }

        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let current_text = app_state.clone_status.to_text();

            // 1. HITUNG PANJANG TEKS BERSIH (Gunakan lebar visual teks asli)
            // .width() dari ratatui Text/Span menghitung lebar visual string dengan tepat
            let text_visual_width = u16::try_from(current_text.as_str().width()).unwrap_or(30);

            // Batas maksimal lebar layar dikurangi padding luar (kiri 2 + kanan bebas)
            let max_allowed_width = area_layar.width.saturating_sub(4);

            // Lebar kotak dinamis: pas dengan teks, tapi tidak melebihi layar, dan minimal lebar 30
            let dynamic_width = text_visual_width
                .min(max_allowed_width)
                .max(30) + 4; // +4 untuk space border kiri/kanan dan padding dalam

            // 2. HITUNG TINGGI VERTIKAL SECARA DINAMIS BERDASARKAN PEMBUNGKUSAN TEKS
            let inner_width = dynamic_width.saturating_sub(2); // lebar bersih dalam kotak
            // Kelipatan baris baru
            let estimated_lines = if inner_width > 0 && text_visual_width > 0 {
                // Jika teks lebih panjang dari space dalam kotak, dia akan membungkus (wrap)
                (text_visual_width + inner_width - 1) / inner_width
            } else {
                1
            };
            // Total tinggi = Jumlah baris tulisan + 2 baris (Garis Borders Atas & Bawah)
            let dynamic_height = estimated_lines + 2;

            // 3. BANGUN LAYOUT VERTIKAL DAN HORIZONTAL SECARA REAL-TIME DI DALAM LOOP
            let layout_vertikal = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(1),                  // Top padding
                    Constraint::Length(dynamic_height),     // PERBAIKAN: Tinggi OTOMATIS pas dengan baris teks
                    Constraint::Min(0),                     // Sisa layar bawah murni kosong
                ]);

            let layout_horizontal = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Length(2),             
                    Constraint::Length(dynamic_width),  
                    Constraint::Min(0),                
                ]);

            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);

            // Menerapkan pembagian horizontal pada baris kedua (indeks 1) dari layout vertikal
            // Lalu mengambil indeks 1 dari layout horizontal (area tengah dengan porsi 90%)
            let area_status: Rect = layout_horizontal.split(area_vertikal[1])[1];

            // Render Widget Status Git Clone
            // Definisikan Style berdasarkan state
            // RENDER UI: Ekstraksi Style dan Text murni didelegasikan langsung ke dalam impl CloneStatus
            let status_style: Style = app_state.clone_status.to_style();
            // Definisikan Teks berdasarkan state
            let status_text: String = app_state.clone_status.to_text();

            let widget_status = Paragraph::new(status_text)
                .block(Block::default().borders(Borders::ALL).title(" Git Terminal Status "))
                .style(status_style)
                .wrap(Wrap { trim: true }); // UBAH: Mengaktifkan pemotongan kata otomatis ke baris baru

            f.render_widget(widget_status, area_status);
        })?;

        // EVENT HANDLING (ASINKRON / POLLED)
        if event::poll(poll_timeout)? { 
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press { 
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => app_state.quit(),
                        KeyCode::Char('c') => {
                            // Kirim klon ke background thread menggunakan tx clone channel
                            app_state.trigger_git_clone(tx.clone());
                        }
                        _ => {}
                    }
                }
            }
        }
    }

    // CLEANUP TERMINAL
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("{}", MSG_SESSION_CLEANUP);
    Ok(())
}
