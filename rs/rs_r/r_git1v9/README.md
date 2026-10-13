# 

aa: 
Berikut adalah kode program **Ratatui TUI lengkap** yang telah disesuaikan agar jalur (*path*) lokal repositori secara otomatis menggunakan format `$owner/$repo`. Dengan perubahan ini, folder lokal yang dihasilkan akan dinamis dan terisolasi di dalam subfolder `eucalypsih/ey_rcrapsbash`.

Kode di bawah ini tetap mempertahankan arsitektur **Builder Pattern**, manajemen *state* asinkron via *background thread*, tipe data eksplisit murni, serta konversi kalkulasi koordinat layar secara **type-safe** tanpa operator primitif `as`.

```rust
        let privkey: PathBuf = self.privkey_path.clone();
        
        // DINAMISASI JALUR LOKAL: Menyusun output_dir menjadi root/owner/repo (e.g., ./repo_output/eucalypsih/ey_rcrapsbash)
        let dynamic_local_path: PathBuf = self.output_dir.join(&owner).join(&repo);

        thread::spawn(move || {

```

---

```rust
            let repo_url: String = format!("git@github.com:{}/{}.git", owner, repo);
            let target_path_str: String = dynamic_local_path.to_string_lossy().into_owned();

            // Tahap 1: Membuat struktur folder dinamis lokal secara aman
            if let Err(e) = std::fs::create_dir_all(&dynamic_local_path) {
                let _ = tx.send(SparseStatus::Error(format_subsystem_error(&e.to_string())));

```

---

```rust
    let private_key_path: &str = "~/.ssh/id_rsa"; 
    let base_destination_dir: &str = "./repo_output"; // Bertindak sebagai root direktori utama

    // PROTEKSI PARAMETER: Menggunakan Builder Pattern demi keamanan alokasi state
    let mut app_state: AppState = AppState::builder()
        .with_owner("eucalypsih")
        .with_repo("ey_rcrapsbash")
        .with_branch("main")
        .with_privkey_path(private_key_path)
        .with_output_dir(base_destination_dir)
        .build();

```

### Penjelasan Pembaruan Sistem Jalur Lokal Dinamis:
- **Penggunaan `.join()` yang Kokoh**: Pada baris fungsi `trigger_git_sparse`, alokasi target direktori dirakit menggunakan `self.output_dir.join(&owner).join(&repo)`. Cara ini menjamin pemisahan pembatas direktori (*path separator*) akan menyesuaikan dengan OS secara otomatis (`/` pada Linux/macOS atau `\` pada Windows).
- **Eksekusi Multi-Platform Terisolasi**: Perintah `git -C` kini mengarah langsung ke folder sub-level `eucalypsih/ey_rcrapsbash`. Hal ini memastikan bahwa inisialisasi awal tidak akan mencemari root direktori utama (`./repo_output`) jika Anda nantinya menambahkan fungsionalitas manajemen *multi-repository* ke dalam aplikasi TUI ini.

---

<br>

---

- `r_git1v9`
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

- `r_git1v9/src/main.rs`
```rust
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
// KONSTANTA LOG & LABEL UI (Eksplisit & Murni Berdasarkan State)
// =========================================================================
const MSG_SESSION_CLEANUP: &str = "\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m";

// Konstanta Label Status UI Statis
const MSG_SPARSE_IDLE: &str = "Status: Idle (Tekan 'c' untuk Inisialisasi Sparse Checkout)";
const MSG_SPARSE_RUNNING: &str = "Status: Mengonfigurasi Git Sparse Checkout...";
const MSG_SPARSE_SUCCESS: &str = "[✓] Git sparse-checkout set --no-cone berhasil dieksekusi.";
const MSG_SPARSE_FAILED_PREFIX: &str = "[!] Konfigurasi Git Sparse gagal.";
const MSG_NO_STDERR: &str = "Tidak ada pesan galat standar";
const MSG_SUBSYSTEM_ERROR_PREFIX: &str = "[!] Gagal memicu eksekusi subsistem perintah git:";

// =========================================================================
// FUNGSI PEMBANTU (Menyembunyikan Makro format! dari Blok Utama)
// =========================================================================
fn format_sparse_error(status_code: Option<i32>, detail_pesan: &str) -> String {
    format!("{} Status: {:?}, Pesan: {}", MSG_SPARSE_FAILED_PREFIX, status_code, detail_pesan)
}

fn format_subsystem_error(err_msg: &str) -> String {
    format!("{} {}", MSG_SUBSYSTEM_ERROR_PREFIX, err_msg)
}

/// Representasi status operasi Git Sparse Checkout secara eksplisit dan murni.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SparseStatus {
    Idle,
    Configuring,
    Success(String), 
    Error(String),
}

impl SparseStatus {
    pub fn to_style(&self) -> Style {
        match self {
            Self::Idle => Style::default().fg(Color::DarkGray),
            Self::Configuring => Style::default().fg(Color::Cyan).add_modifier(Modifier::SLOW_BLINK),
            Self::Success(_) => Style::default().fg(Color::Green).add_modifier(Modifier::BOLD),
            Self::Error(_) => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        }
    }

    pub fn to_text(&self) -> String {
        match self {
            Self::Idle => MSG_SPARSE_IDLE.to_string(),
            Self::Configuring => MSG_SPARSE_RUNNING.to_string(),
            Self::Success(msg) => msg.clone(), 
            Self::Error(err) => err.clone(),   
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
    pub sparse_status: SparseStatus,
    should_quit: bool,
}

impl AppState {
    /// Inisialisasi awal Builder Pattern secara standar industri.
    pub fn builder() -> AppStateBuilder {
        AppStateBuilder::default()
    }

    fn quit(&mut self) {
        self.should_quit = true;
    }

    /// Memicu proses inisialisasi Git Sparse Checkout di background thread agar tidak memblokir rendering TUI.
    fn trigger_git_sparse(&mut self, tx: Sender<SparseStatus>) {
        // Cegah eksekusi ganda jika proses sedang berjalan
        if self.sparse_status == SparseStatus::Configuring {
            return;
        }

        self.sparse_status = SparseStatus::Configuring;

        // Kloning data untuk dipindahkan (move) ke thread terpisah secara aman
        let owner: String = self.owner.clone();
        let repo: String = self.repo.clone();
        let privkey: PathBuf = self.privkey_path.clone();

        // DINAMISASI JALUR LOKAL: Menyusun output_dir menjadi root/owner/repo (e.g., ./repo_output/eucalypsih/ey_rcrapsbash)
        let dynamic_local_path: PathBuf = self.output_dir.join(&owner).join(&repo);

        // Standar Industri: Jalankan I/O heavy / blocking command di Thread terpisah
        thread::spawn(move || {
            let ssh_command: String = format!("ssh -i {} -o IdentitiesOnly=yes", privkey.display());
            let repo_url: String = format!("git@github.com:{}/{}.git", owner, repo);
            let target_path_str: String = dynamic_local_path.to_string_lossy().into_owned();

            // Tahap 1: Memastikan direktori tujuan ada
            // Tahap 1: Membuat struktur folder dinamis lokal secara aman
            if let Err(e) = std::fs::create_dir_all(&dynamic_local_path) {
                let _ = tx.send(SparseStatus::Error(format_subsystem_error(&e.to_string())));
                return;
            }


            // Tahap 2: Serangkaian perintah Git untuk inisialisasi Sparse Checkout secara murni
            let commands: [(&str, &[&str]); 4] = [
                ("git", &["-C", &target_path_str, "init"]),
                ("git", &["-C", &target_path_str, "remote", "add", "origin", &repo_url]),
                ("git", &["-C", &target_path_str, "config", "core.sshCommand", &ssh_command]),
                ("git", &["-C", &target_path_str, "sparse-checkout", "set", "--no-cone"]),
            ];

            for (cmd, args) in commands.iter() {
                let output_res = Command::new(cmd)
                    .args(*args)
                    .output();

                match output_res {
                    Ok(out) if out.status.success() => {
                        // Lanjut ke perintah berikutnya jika berhasil
                    }
                    Ok(out) => {
                        let err_msg: String = String::from_utf8_lossy(&out.stderr).into_owned();
                        let detail_pesan: String = if err_msg.is_empty() {
                            MSG_NO_STDERR.to_string()
                        } else {
                            err_msg
                        };
                        let final_err: String = format_sparse_error(out.status.code(), &detail_pesan);
                        let _ = tx.send(SparseStatus::Error(final_err));
                        return;
                    }
                    Err(err) => {
                        let final_err: String = format_subsystem_error(&err.to_string());
                        let _ = tx.send(SparseStatus::Error(final_err));
                        return;
                    }
                }
            }

            // Jika seluruh tahapan perintah di atas berhasil dieksekusi tanpa error
            let _ = tx.send(SparseStatus::Success(MSG_SPARSE_SUCCESS.to_string()));
        });
    }
}

// =========================================================================
// STRUKTUR BUILDER PATTERN (Anti Tertukar Parameter)
// =========================================================================
#[derive(Default)]
pub struct AppStateBuilder {
    branch: Option<String>,
    repo: Option<String>,
    owner: Option<String>,
    privkey_path: Option<PathBuf>,
    output_dir: Option<PathBuf>,
}

impl AppStateBuilder {
    pub fn with_branch(mut self, branch: &str) -> Self {
        self.branch = Some(branch.to_string());
        self
    }

    pub fn with_repo(mut self, repo: &str) -> Self {
        self.repo = Some(repo.to_string());
        self
    }

    pub fn with_owner(mut self, owner: &str) -> Self {
        self.owner = Some(owner.to_string());
        self
    }

    pub fn with_privkey_path<P: AsRef<Path>>(mut self, path: P) -> Self {
        self.privkey_path = Some(path.as_ref().to_path_buf());
        self
    }

    pub fn with_output_dir<P: AsRef<Path>>(mut self, path: P) -> Self {
        self.output_dir = Some(path.as_ref().to_path_buf());
        self
    }

    pub fn build(self) -> AppState {
        AppState {
            current_branch: self.branch.unwrap_or_else(|| "main".to_string()),
            repo: self.repo.unwrap_or_default(),
            owner: self.owner.unwrap_or_default(),
            privkey_path: self.privkey_path.unwrap_or_default(),
            output_dir: self.output_dir.unwrap_or_default(),
            sparse_status: SparseStatus::Idle,
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

    // Parameterisasi konfigurasi
    let private_key_path: &str = "~/.ssh/id_rsa"; // Contoh lokasi private key
    let base_destination_dir: &str = "./repo_output";  // Bertindak sebagai root direktori utama

    // Inisialisasi State dengan menyertakan path private key SSH
    // PROTEKSI PARAMETER: Menggunakan Builder Pattern, urutan pemanggilan di bawah bebas dan aman
    let mut app_state: AppState = AppState::builder()
        .with_owner("eucalypsih")
        .with_repo("ey_rcrapsbash")
        .with_branch("main")
        .with_privkey_path(private_key_path)
        .with_output_dir(base_destination_dir)
        .build();

    // Setup channel komunikasi antar-thread secara eksplisit
    let (tx, rx): (Sender<SparseStatus>, Receiver<SparseStatus>) = mpsc::channel();

    // Konversi Type-Safe konstan untuk Polling (Menggantikan parameter primitif mentah)
    // Menggunakan implementasi standard library u64 -> Duration secara aman & eksplisit
    let poll_timeout: Duration = Duration::from_millis(16);

    // LOOP RENDERING
    while !app_state.should_quit {
        // Ambil pembaruan status dari background thread tanpa memblokir loop (non-blocking)
        if let Ok(new_status) = rx.try_recv() {
            app_state.sparse_status = new_status;
        }

        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let current_text: String = app_state.sparse_status.to_text();
            
            // 1. HITUNG BATAS MAKSIMAL LEBAR SECARA AMAN (TYPE-SAFE)
            let text_length: usize = current_text.len();
            let max_allowed_width: u16 = area_layar.width.saturating_sub(4);

            // Mengubah tipe data secara aman dari usize ke u16 menggunakan try_from tanpa operator 'as'
            let dynamic_width = (u16::try_from(text_length).unwrap_or(30))
                .min(max_allowed_width)
                .max(30) + 4;

            // 2. HITUNG TINGGI VERTIKAL SECARA DINAMIS BERDASARKAN PEMBUNGKUSAN TEKS
            // Rumus: Kelipatan baris baru = (panjang teks / lebar bersih dalam kotak) + 1 baris
            let inner_width: u16 = dynamic_width.saturating_sub(2);
            let estimated_lines: u16 = if inner_width > 0 {
                (u16::try_from(text_length).unwrap_or(30) / inner_width) + 1
            } else {
                1
            };
            // Total tinggi = Jumlah baris tulisan + 2 baris (Garis Borders Atas & Bawah)
            let dynamic_height: u16 = estimated_lines + 2;

            // 3. BANGUN LAYOUT VERTIKAL DAN HORIZONTAL SECARA REAL-TIME DI DALAM LOOP
            let layout_vertikal: Layout = Layout::default()
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
            let status_style: Style = app_state.sparse_status.to_style();
            // Definisikan Teks berdasarkan state
            let status_text: String = app_state.sparse_status.to_text();

            let widget_status: Paragraph = Paragraph::new(status_text)
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
                            app_state.trigger_git_sparse(tx.clone());
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

```













<br>
