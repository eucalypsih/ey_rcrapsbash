# 

- `ratatui_1d/Cargo.toml`
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

- `ratatui_d1/src/main.rs``
```rust
use std::io::{self, Stdout};
use std::time::Duration;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
// Mengimpor komponen layout dan teks berwarna dari Ratatui
use ratatui::{
    backend::CrosstermBackend,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Terminal,
};

// =========================================================================
// 1. MANAJEMEN STATE: Mendefinisikan Struktur Data Aplikasi (Idiomatik Rust)
// =========================================================================
struct AppState {
    current_branch: String,
    repo: String,
    owner: String,
    should_quit: bool, // Flag state untuk mengontrol siklus hidup loop
}

impl AppState {
    // Konstruktor untuk inisialisasi state awal
    fn new(branch: &str, repo: &str, owner: &str) -> Self {
        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            should_quit: false,
        }
    }

    // Mengubah state untuk keluar dari aplikasi
    fn quit(&mut self) {
        self.should_quit = true;
    }
}

fn main() -> Result<(), io::Error> {
    // INISIALISASI TERMINAL KUSTOM (Masuk ke Mode TUI Fullscreen)
    enable_raw_mode()?;
    let mut stdout: Stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    
    let backend: CrosstermBackend<Stdout> = CrosstermBackend::new(stdout);
    let mut terminal: Terminal<CrosstermBackend<Stdout>> = Terminal::new(backend)?;

    // INERT STATE: Menginisialisasi objek state terpusat
    let mut app_state: AppState = AppState::new("main", "ey_rcrapsbash", "eucalypsih");

    // LOOP UTAMA RENDERING TUI
    while !app_state.should_quit {
        // Menggambar UI ke layar perangkat
        // Menggambar UI dengan meminjam data dari state (&app_state)
        terminal.draw(|f| {
            // Membagi layar menjadi area tengah agar panel kotak terlihat proporsional
            // let area_layar: Rect = f.size(); // ❌ Menggunakan metode usang
            let area_layar: Rect = f.area();    // ✅ BENAR: Menggunakan standar modern Ratatui 0.30+
            // Membagi layar secara VERTIKAL
            let daftar_constraint_vertikal: [Constraint; 3] = [
                Constraint::Percentage(35_u16),
                Constraint::Length(5_u16), // Kotak setinggi 5 baris
                Constraint::Percentage(45_u16),
            ];

            let layout_vertikal: Layout = Layout::default()
                .direction(Direction::Vertical)
                .constraints::<[Constraint; 3]>(daftar_constraint_vertikal);

            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);

            // Membagi layar secara HORIZONTAL (mengambil baris tengah / index 1)
            let daftar_constraint_horizontal: [Constraint; 3] = [
                Constraint::Percentage(5_16),
                Constraint::Percentage(90_u16), // Lebar kotak panel 90% layar
                Constraint::Percentage(5_16),
            ];

            let layout_horizontal: Layout = Layout::default()
                .direction(Direction::Horizontal)
                .constraints::<[Constraint; 3]>(daftar_constraint_horizontal);

            let area_horizontal: std::rc::Rc<[Rect]> = layout_horizontal.split(area_vertikal[1]);

            //  Mengambil area kotak panel utama
            let area_kotak_panel: Rect = area_horizontal[1];

            // 💡 RATATUI STYLE: Menyusun 6 Komponen Parameter ke dalam struktur Line & Span
            let susunan_teks_tui: Line<'static> = Line::from(vec![
                Span::<'static>::styled("[✓] Sukses Branch saat ini terdeteksi: ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::<'static>::styled(format!("{} ", app_state.current_branch), Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                Span::<'static>::styled("berada di repo: ", Style::default().fg(Color::Green)),
                Span::<'static>::styled(format!("{} ", app_state.repo), Style::default().fg(Color::Yellow).add_modifier(Modifier::UNDERLINED)),
                Span::<'static>::styled("menggunakan key: ", Style::default().fg(Color::Green)),
                Span::<'static>::styled(format!("{} ", app_state.owner), Style::default().fg(Color::Yellow)),
            ]);

            // Membuat Widget Kotak Panel (Block) dengan Border Hijau Tebal
            let block_panel: Block<'static> = Block::default()
                .title(" AUDIT SISTEM VERIFICATION ")
                .title_alignment(Alignment::Left)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Magenta))
                .style(Style::default().bg(Color::Reset));

            // Memasukkan paragraf teks ke dalam widget panel
            let widget_paragraf: Paragraph<'_> = Paragraph::new(susunan_teks_tui)
                .block(block_panel)
                .alignment(Alignment::Left)
                .wrap(Wrap { trim: true });

            // Render widget secara fisik ke layar Termux
            f.render_widget(widget_paragraf, area_kotak_panel);
        })?;

        // DETEKSI INPUT TOMBOL UNTUK KELUAR
        // LOGIKA UPDATE STATE (DETEKSI INPUT)
        if event::poll(Duration::from_millis(100))? {
            let akumulasi_event: Event = event::read()?;
            if let Event::Key(tombol_tertekan) = akumulasi_event {
                let key: KeyEvent = tombol_tertekan;
                
                // Jika tombol keluar ditekan, mutasi state melalui fungsi internal
                // Pengguna bisa menekan tombol 'q' atau 'Enter' atau 'Esc' untuk menutup dashboard TUI
                if key.code == KeyCode::Char('q') || key.code == KeyCode::Enter || key.code == KeyCode::Esc {
                    app_state.quit();
                }
            }
        }
    }

    // 4. PEMBERSIHAN TERMINAL (Kembali ke layar terminal Termux biasa)
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m");
    Ok(())
}

```



<br>
