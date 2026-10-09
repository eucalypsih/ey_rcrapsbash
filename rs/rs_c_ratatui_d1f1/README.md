# 

- `ratatui_d1f1/Cargo.toml`
```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
ratatui = "0.30.2"   # Tambahkan library TUI standar industri Rust

```

- `ratatui_d1f1/src/main.rs`
```rust
use std::io::{self, Stdout, Read};
use std::time::Duration;
use std::fs::File;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
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
    file_content: String, // Field baru untuk menyimpan data teks dari file
    should_quit: bool, 
}

impl AppState {
    // Konstruktor untuk inisialisasi state awal
    fn new(branch: &str, repo: &str, owner: &str, file_path: &str) -> Self {
        let konten: String = Self::baca_file_konten(file_path);
        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            file_content: konten,
            should_quit: false,
        }
    }

    // Fungsi pembacaan file dengan tipe data dan error handling eksplisit murni
    fn baca_file_konten(path: &str) -> String {
        // Eksplisit membuka berkas file
        let file_result: Result<File, io::Error> = File::open(path);
        
        let mut file_obj: File = match file_result {
            Ok(f) => f,
            Err(_) => return String::from("Gagal memuat berkas: File tidak ditemukan."),
        };

        let mut buffer_konten: String = String::new();
        // Eksplisit membaca data biner berkas ke dalam buffer string
        let read_result: Result<usize, io::Error> = file_obj.read_to_string(&mut buffer_konten);

        match read_result {
            Ok(_) => buffer_konten,
            Err(_) => String::from("Gagal membaca struktur data di dalam berkas."),
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

    // INERT STATE: Menginisialisasi objek dengan file target "log.txt" (silakan sesuaikan path-nya)
    let mut app_state: AppState = AppState::new("main", "ey_rcrapsbash", "eucalypsih", "log.txt");

    // LOOP UTAMA RENDERING TUI
    while !app_state.should_quit {
        // Menggambar UI ke layar perangkat
        terminal.draw(|f| {
            let area_layar: Rect = f.area();    
            
            // Mengubah ukuran layout vertikal agar memuat space konten file di bawahnya (menggunakan 4 susunan area)
            let daftar_constraint_vertikal: [Constraint; 4] = [
                Constraint::Percentage(10_u16),
                Constraint::Length(5_u16),      // Kotak setinggi 5 baris untuk info Repo
                Constraint::Percentage(50_u16),  // Kotak baru untuk memajang isi file teks
                Constraint::Percentage(10_u16),
            ];

            let layout_vertikal: Layout = Layout::default()
                .direction(Direction::Vertical)
                .constraints::<[Constraint; 4]>(daftar_constraint_vertikal);

            let area_vertikal: std::rc::Rc<[Rect]> = layout_vertikal.split(area_layar);

            // Membagi layar secara HORIZONTAL untuk area panel atas (index 1)
            let daftar_constraint_horizontal: [Constraint; 3] = [
                Constraint::Percentage(5_u16),
                Constraint::Percentage(90_u16), 
                Constraint::Percentage(5_u16),
            ];

            let layout_horizontal: Layout = Layout::default()
                .direction(Direction::Horizontal)
                .constraints::<[Constraint; 3]>(daftar_constraint_horizontal);

            let area_horizontal_atas: std::rc::Rc<[Rect]> = layout_horizontal.split(area_vertikal[1]);
            let area_kotak_panel_info: Rect = area_horizontal_atas[1];

            // Membagi layar secara HORIZONTAL untuk area konten berkas file (index 2)
            let area_horizontal_bawah: std::rc::Rc<[Rect]> = layout_horizontal.split(area_vertikal[2]);
            let area_kotak_panel_file: Rect = area_horizontal_bawah[1];

            // 💡 RATATUI STYLE: Baris Info Utama
            let susunan_teks_tui: Line<'static> = Line::from(vec![
                Span::<'static>::styled("[✓] Sukses Branch saat ini terdeteksi: ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::<'static>::styled(format!("{} ", app_state.current_branch), Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                Span::<'static>::styled("berada di repo: ", Style::default().fg(Color::Green)),
                Span::<'static>::styled(format!("{} ", app_state.repo), Style::default().fg(Color::Yellow).add_modifier(Modifier::UNDERLINED)),
                Span::<'static>::styled("menggunakan key: ", Style::default().fg(Color::Green)),
                Span::<'static>::styled(format!("{} ", app_state.owner), Style::default().fg(Color::Yellow)),
            ]);

            // Pembuatan Widget Panel Atas
            let block_panel: Block<'static> = Block::default()
                .title(" AUDIT SISTEM VERIFICATION ")
                .title_alignment(Alignment::Left)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Magenta))
                .style(Style::default().bg(Color::Reset));

            let widget_paragraf: Paragraph<'_> = Paragraph::new(susunan_teks_tui)
                .block(block_panel)
                .alignment(Alignment::Left)
                .wrap(Wrap { trim: true });

            f.render_widget(widget_paragraf, area_kotak_panel_info);

            // 💡 WIDGET BARU: Menampilkan teks dari File yang dibaca secara real-time
            let susunan_teks_file: Line<'static> = Line::from(vec![
                Span::<'static>::styled(app_state.file_content.clone(), Style::default().fg(Color::White)),
            ]);

            let block_panel_file: Block<'static> = Block::default()
                .title(" ISI BERKAS FILE DIBACA ")
                .title_alignment(Alignment::Left)
                .borders(Borders::ALL)
                .border_style(Style::default().fg(Color::Cyan))
                .style(Style::default().bg(Color::Reset));

            let widget_file_paragraf: Paragraph<'_> = Paragraph::new(susunan_teks_file)
                .block(block_panel_file)
                .alignment(Alignment::Left)
                .wrap(Wrap { trim: true });

            // Render widget file secara fisik ke layout baris ke-3 layar
            f.render_widget(widget_file_paragraf, area_kotak_panel_file);
        })?;

        // DETEKSI INPUT TOMBOL UNTUK KELUAR
        if event::poll(Duration::from_millis(100))? {
            let akumulasi_event: Event = event::read()?;
            if let Event::Key(tombol_tertekan) = akumulasi_event {
                let key: KeyEvent = tombol_tertekan;
                
                if key.code == KeyCode::Char('q') || key.code == KeyCode::Enter || key.code == KeyCode::Esc {
                    app_state.quit();
                }
            }
        }
    }

    // 4. PEMBERSIHAN TERMINAL
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("\x1B[1;32m[✓] Sesi peninjauan Ratatui TUI sukses ditutup bersih.\x1B[0m");
    Ok(())
}

```



<br>
