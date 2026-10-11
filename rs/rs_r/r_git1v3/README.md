# 

qs: 
"[] Git clone berhasil dieksekusi secara sinkron."
"[!] Git clone gagal. Status: {:?}, Pesan: {}"
"Tidak ada pesan galat standar"
"[!] Gagal memicu eksekusi subsistem perintah git: {}"
"Branch: {}"
"Owner: {}"
"Repo: {}"

bisakah tata ulang, menempatkan di tempat paling rekomendasi agar lebih rapi mempilkanya di terminal.draw

---

aa: 
Untuk menata visual komponen `Owner`, `Repo`, dan `Branch` di dalam terminal.draw agar terlihat sangat rapi, profesional, dan mengikuti standar industri TUI (*Text User Interface*), pendekatan terbaik adalah **memisahkan setiap informasi menggunakan elemen visual terstruktur (seperti label berwarna terpisah dan pembatas pipa `│`)** alih-alih mencampurnya ke dalam satu string format mentah biasa.

Kita juga akan memindahkan *literal label* TUI seperti `"Owner: "`, `"Repo: "`, dan `"Branch: "` ke bagian **konstanta global** bersama teks log agar kode rendering tetap bersih dan mudah dikonfigurasi.

Berikut adalah kode solusi lengkap yang telah ditata ulang secara optimal:

Kode Solusi Lengkap (Visual TUI Rapi & Terstruktur)
- `r_git1v3/Cargo.toml`
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

- `r_git1v3/src/main.rs`
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
    widgets::{Block, Borders, Paragraph, Wrap},
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

    // Template layout vertikal (Baris pertama untuk informasi panel atas)
    let layout_vertikal: Layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),      // Tinggi kotak info repo dibuat 3 baris agar border & teks pas sejajar
            Constraint::Min(0),         
        ]);

    // Distribusi ruang horizontal agar panel berada di tengah layar secara simetris
    let layout_horizontal: Layout = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(5),   // Margin kiri
            Constraint::Percentage(90),  // Lebar utama panel informasi
            Constraint::Percentage(5),   // Margin kanan
        ]);

    let poll_timeout: Duration = Duration::from_millis(16); // ~60 FPS responsif

    // LOOP RENDERING
    while !app_state.should_quit() {
        terminal.draw(|f: &mut Frame| {
            let area_layar: Rect = f.area();
            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);
            
            // Mengambil baris pertama (indeks 0) untuk menaruh panel atas secara rapi
            if let Some(&v_idx_0) = area_vertikal.get(0) {
                let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(v_idx_0);
                
                if let Some(&area_kotak_panel_info) = area_horizontal.get(1) {
                    
                    // Konstruksi visual berstruktur tinggi dengan membedakan warna label dan isi data dinamis
                    let info_text: Vec<Span> = vec![
                        // Segmen Owner
                        Span::styled(LABEL_OWNER, Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.owner, Style::default().fg(Color::White)),
                        
                        Span::styled(UI_SEPARATOR, Style::default().fg(Color::DarkGray)),
                        
                        // Segmen Repo
                        Span::styled(LABEL_REPO, Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.repo, Style::default().fg(Color::White)),
                        
                        Span::styled(UI_SEPARATOR, Style::default().fg(Color::DarkGray)),
                        
                        // Segmen Branch
                        Span::styled(LABEL_BRANCH, Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                        Span::styled(&app_state.current_branch, Style::default().fg(Color::White)),
                    ];

                    // Render widget dengan border Magenta tebal dan judul yang jelas
                    let widget_paragraf: Paragraph = Paragraph::new(Line::from(info_text))
                        .block(
                            Block::default()
                                .title(" Repository Status ")
                                .borders(Borders::ALL)
                                .border_style(Style::default().fg(Color::Magenta))
                        )
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

## Detail Strategi Penataan Visual TUI (Mengapa Ini Lebih Rapi?)
1. Pewarnaan Token Dinamis (*Tokenized Styling*):
Alih-alih mencetak teks putih polos yang membosankan, kode di atas memisahkan label (`Owner:`, `Repo:`, `Branch:`) dengan memberikan gaya **Tebal (_Bold_)** dan warna yang kontras (`Cyan`, `Green`, `Yellow`). Data variabel dari state tetap berwarna White sehingga mata pengguna dapat langsung membedakan mana *key* dan mana *value* secara cepat.

2. Penyekat Visual Moderen (`│`):
Menggunakan karakter pipa box-drawing (`│`) yang diberi warna abu-abu gelap (`Color::DarkGray`). Teknik ini memberikan batas antar kelompok data yang tegas namun tidak mencolok atau merusak estetika panel utama.

3. Optimasi Posisi Layout & Aspek Rasio Kontainer:
- Vertikal: Kotak dipindahkan ke posisi baris paling atas (`v_idx_0`) dengan batas konstan `Constraint::Length(3)`. Tinggi 3 baris sangat ideal karena menyisakan 1 baris kosong di tengah untuk teks setelah dipotong border atas dan bawah.
- Horizontal: Skema persentase diubah menjadi `5% - 90% - 5%`. Hal ini membuat kotak memanjang secara elegan di tengah layar terminal tanpa terlihat terlalu mepet ke sudut kiri atau kanan terminal pengguna.

## Matriks Komparasi Desain TUI


| Komponen TUI | Implementasi Lama | Desain Rekomendasi Industri (Baru) | Dampak Terhadap Pengalaman Pengguna (UX) |
| :--- | :--- | :--- | :--- |
| **Pewarnaan** | Semua teks berwarna putih polos dalam satu *string* tunggal | Kombinasi Warna Kontras<br>( Cyan / Green / Yellow / White ) | Informasi menjadi sangat mudah dipindai oleh mata (*High Scannability*). |
| **Karakter Pemisah** | Menggunakan spasi dan karakter pipa keyboard mentah `|` | . | Menggunakan pemisah grafis *box-drawing* `│`<br>( `Color::DarkGray` ) |
| **Lokasi Baris** | Berada di baris tengah ( `v_idx_1` ) dengan batasan tinggi rentan | Berada mantap di baris paling atas ( `v_idx_0` ) setinggi 3 piksel baris | Bertindak sempurna sebagai *header* status yang statis dan presisi. |
| **Arsitektur Kode** | Label teks menyatu di dalam fungsi gambarnya | Diekstrak ke struktur `const &str` di luar fungsi utama | Fungsi loop `draw` menjadi fokus pada logika tata letak tanpa tumpukan teks mentah. |

---

qa: 
Apakah Anda ingin menambahkan **widget tambahan** di bawah panel informasi tersebut (pada area sisa `Constraint::Min(0)`), seperti panel daftar riwayat komit (*commit log list*) atau indikator status proses pengunduhan (*loading progress bar*)?










<br>
