# 

aa: 
Tempat paling direkomendasikan dan memenuhi standar industri Rust untuk menempatkan pesan-pesan string *log* atau *literal text* tersebut adalah dengan memisahkannya ke dalam **konstanta statis global (`const` atau `static &str`)** atau membungkusnya ke dalam struktur modul log terpisah.

Membiarkan string panjang berada di dalam blok logika fungsi (seperti di dalam `AppState::new`) membuat kode menjadi kotor (*hardcoded*) dan sulit dirawat jika suatu saat Anda ingin mengubah bahasa aplikasi atau mengubah format teksnya.

Berikut adalah kode utuh yang telah dirapikan dengan menaruh pesan-pesan tersebut di bagian atas sebagai konstanta global, lengkap dengan perbaikan tipe data *type-safe* dan pembersihan *warning* layout yang sempat muncul sebelumnya:
```bash
cargo run --manifest-path $HOME/r_git1v2/Cargo.toml

```

---

- `r_git1v2/Cargo.toml`
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

- `r_git1v2/src/main.rs`
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
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame, Terminal,
};

// =========================================================================
// KONSTANTA PESAN LOG (Rekomendasi Terbaik untuk Kerapian & Pemeliharaan)
// =========================================================================
const MSG_CLONE_SUCCESS: &str = "[✓] Git clone berhasil dieksekusi secara sinkron.";
const MSG_CLONE_FAILED: &str = "[!] Git clone gagal. Status: {:?}, Pesan: {}";
const MSG_NO_STDERR: &str = "Tidak ada pesan galat standar";
const MSG_SUBSYSTEM_ERROR: &str = "[!] Gagal memicu eksekusi subsistem perintah git: {}";
const MSG_SESSION_CLEANUP: &str = "\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m";

/// Struktur data State Management dengan tipe data eksplisit dan aman.
pub struct AppState {
    pub current_branch: String,
    pub repo: String,
    pub owner: String,
    pub privkey_path: PathBuf,
    pub output_dir: PathBuf,
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
        
        // Eksekusi Git Clone secara sinkron sebelum TUI Alternate Screen dimulai
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

            // Pencocokan logika dengan menggunakan konstanta pesan eksternal
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
            should_quit: false,
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

    // Inisialisasi State dengan menyertakan argumen path file secara lengkap
    let mut app_state: AppState = AppState::new(
        "main",
        "ey_rcrapsbash",
        "eucalypsih",
        "~/.ssh/id_rsa",
        "./output_repo"
    );

    // Template layout statis yang valid (Mencegah Warning & Runtime Panic)
    let layout_vertikal: Layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),      
            Constraint::Length(5),      
            Constraint::Min(0),         
        ]);

    let layout_horizontal: Layout = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(20),
            Constraint::Percentage(60),
            Constraint::Percentage(20),
        ]);

    // Mengubah timeout menjadi 16ms agar TUI merespon dengan lancar (~60 FPS)
    let poll_timeout: Duration = Duration::from_millis(16);

    // LOOP RENDERING
    while !app_state.should_quit() {
        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);
            
            // Pengambilan index array yang aman untuk baris kedua (indeks 1)
            if let Some(&v_idx_1) = area_vertikal.get(1) {
                let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(v_idx_1);
                
                if let Some(&area_kotak_panel_info) = area_horizontal.get(1) {
                    let display_info: String = format!(
                        " Owner: {} | Repo: {} | Branch: {}", 
                        app_state.owner, app_state.repo, app_state.current_branch
                    );

                    let info_text: Vec<Span> = vec![
                        Span::styled(display_info, Style::default().fg(Color::White)),
                    ];

                    let widget_paragraf: Paragraph = Paragraph::new(Line::from(info_text))
                        .block(Block::default().title(" Repository Info ").borders(Borders::ALL).border_style(Style::default().fg(Color::Magenta)))
                        .wrap(Wrap { trim: true });
                    f.render_widget(widget_paragraf, area_kotak_panel_info);
                }
            }
        })?;

        // EVENT HANDLING
        if event::poll(poll_timeout)? { 
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press { 
                    match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => app_state.quit(),
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

---

## Mengapa Pendekatan Ini Dianggap Paling Rapi?
1. Prinsip *Separation of Concerns* (Pemisahan Tugas): Fungsi logika `new()` kini murni menangani *flow* pemrograman (mengecek folder, menjalankan Git perintah CLI). Fungsi tersebut tidak lagi dibebani tugas menyimpan teks mentah panjang.
2. Kemudahan *Refactoring*: Jika kelak aplikasi Anda harus mendukung multi-bahasa (*Internationalization / i18n*), Anda hanya perlu mengganti bagian blok konstanta di atas atau memindahkannya ke file `.json`/`.toml` tanpa mengutak-atik logika inti program di bawahnya.
3. Mengurangi *Allocation Overload*: String yang dideklarasikan dengan `const &str` disimpan langsung di dalam memori binary statis (segmen data baca-saja), bukan dibuat berulang-ulang di memori *Heap* setiap kali fungsi dipanggil.

---

qa: 
Apakah Anda ingin pesan-pesan log ini nantinya **ditulis secara otomatis ke dalam file log fisik** (seperti `app.log`) alih-alih dicetak ke layar terminal menggunakan `println!`, agar tidak mengacaukan visual TUI Anda saat terjadi *error* di tengah jalan?











<br>
