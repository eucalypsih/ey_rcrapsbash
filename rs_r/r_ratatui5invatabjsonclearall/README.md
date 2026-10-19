# 

qc: 
fitur auto-save dan auto-load file fisik ini sudah berjalan lancar di terminal. ingin melangkah lebih jauh, apakah bisa menambahkan fitur **menghapus semua riwayat (Clear History)i* baik dari layar maupun dari file fisik lewat tombol shortcut tertentu (misal tombol `C`).

---

aa: 
Fitur hapus riwayat menggunakan tombol `C` sebenarnya **sudah diimplementasikan secara lengkap pada kode di atas** (pada respons sebelum ini).

Namun, mari kita melangkah lebih jauh lagi dengan menambahkan **Sistem Konfirmasi Pop-up (Dialog Box)**. Dengan begitu, saat Anda menekan tombol `C` di halaman riwayat, aplikasi tidak langsung menghapus data secara sepihak, melainkan memunculkan kotak dialog konfirmasi **"Apakah Anda yakin? (Y/N)"** terlebih dahulu di tengah layar. Ini akan membuat arsitektur aplikasi Ratatui Anda menjadi jauh lebih profesional dan aman dari salah pencet!

Berikut adalah kode arsitektur lengkap yang sudah dilengkapi tombol `C` beserta **Pop-up Konfirmasi**:

---

### Cara Kerja Tambahan Sistem Pop-up Konfirmasi:
1. **`ratatui::widgets::Clear`**: Ini adalah widget krusial di Ratatui untuk membuat UI berlapis (*multi-layer*). `Clear` berfungsi mengosongkan/menimpa area koordinat tertentu agar tulisan teks di belakang layar (Halaman Riwayat) tidak bercampur baur dengan teks di dalam kotak pop-up.
2. **`buat_kotak_tengah`**: Menggunakan teknik pembagian persentase `Layout` berlapis (Vertikal dilanjutkan Horizontal) untuk menghasilkan koordinat `Rect` kotak kecil yang presisi berada di tengah-tengah terminal, tidak peduli seberapa besar ukuran jendela terminal user.
3. **Pemberhentian Alur Input (`continue`)**: Di dalam event loop `run_app`, jika `app.konfirmasi_hapus` bernilai `true`, semua tombol navigasi utama dibekukan sementara. Program hanya akan mendengarkan tombol `Y` (untuk mengeksekusi `app.hapus_semua_riwayat()`) atau tombol `N`/`Esc` (untuk menutup kembali pop-up).

---

qa: 
Sekarang arsitektur aplikasi terminal Anda sudah sangat solid dan aman dari ketidaksengajaan terhapus! Apakah sistem dialog box ini sudah sesuai dengan visual yang Anda harapkan di terminal, atau ada fungsionalitas logika lain yang ingin Anda tambahkan berikutnya?

---

<br>

---

<br>

---

```rust
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, Clear, Paragraph, Tabs},
    Frame, Terminal,
};
use std::fs::{self, File};
use std::io::{self, stdout, Read, Write, Stdout};
use std::path::Path;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.json";

#[derive(Copy, Clone, PartialEq)]
enum MenuTab {
    Input,
    Riwayat,
}

// ==========================================
// 1. STRUKTUR DATA APLIKASI (STATE)
// ==========================================
struct App {
    pub input_teks: String,
    pub teks_tersimpan: Vec<String>,
    pub error_pesan: Option<String>,
    pub aktif_tab: MenuTab,
    pub konfirmasi_hapus: bool, // State baru untuk mendeteksi apakah pop-up konfirmasi sedang terbuka
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            konfirmasi_hapus: false, // Default pop-up tertutup
            harus_keluar: false,
        }
    }

    fn muat_dari_json() -> Vec<String> {
        let mut list_data = Vec::new();
        if Path::new(FILE_PATH).exists() {
            if let Ok(mut file) = File::open(FILE_PATH) {
                let mut konten = String::new();
                if file.read_to_string(&mut konten).is_ok() {
                    let bersih = konten.trim().trim_start_matches('[').trim_end_matches(']');
                    if !bersih.is_empty() {
                        for item in bersih.split(',') {
                            let kata = item.trim().trim_matches('"');
                            if !kata.is_empty() {
                                list_data.push(kata.replace("\\\"", "\""));
                            }
                        }
                    }
                }
            }
        }
        list_data
    }

    fn simpan_ke_json(&self) -> io::Result<()> {
        let mut file = File::create(FILE_PATH)?;
        let mut json_string = String::new();
        json_string.push('[');

        for (i, teks) in self.teks_tersimpan.iter().enumerate() {
            let teks_escaped = teks.replace('"', "\\\"");
            json_string.push('"');
            json_string.push_str(&teks_escaped);
            json_string.push('"');

            if i < self.teks_tersimpan.len() - 1 {
                json_string.push_str(", ");
            }
        }
        
        json_string.push(']');
        file.write_all(json_string.as_bytes())?;
        Ok(())
    }

    // Eksekusi hapus setelah dikonfirmasi
    fn hapus_semua_riwayat(&mut self) {
        self.teks_tersimpan.clear();
        if Path::new(FILE_PATH).exists() {
            if let Err(_) = fs::remove_file(FILE_PATH) {
                self.error_pesan = Some("Gagal menghapus file JSON fisik!".to_string());
                return;
            }
        }
        self.error_pesan = None;
    }

    fn ganti_tab(&mut self) {
        if !self.konfirmasi_hapus { // Kunci perpindahan tab jika pop-up sedang terbuka
            match self.aktif_tab {
                MenuTab::Input => self.aktif_tab = MenuTab::Riwayat,
                MenuTab::Riwayat => self.aktif_tab = MenuTab::Input,
            }
        }
    }

    fn tambah_karakter(&mut self, c: char) {
        if self.input_teks.len() < MAX_KARAKTER {
            self.input_teks.push(c);
            self.error_pesan = None;
        } else {
            self.error_pesan = Some(format!("Maksimal hanya boleh {} karakter!", MAX_KARAKTER));
        }
    }

    fn hapus_karakter(&mut self) {
        self.input_teks.pop();
        self.error_pesan = None;
    }

    fn simpan_teks(&mut self) {
        let teks_bersih = self.input_teks.trim().to_string();
        if teks_bersih.is_empty() {
            self.error_pesan = Some("Gagal! Input tidak boleh kosong.".to_string());
        } else {
            self.teks_tersimpan.push(teks_bersih);
            match self.simpan_ke_json() {
                Ok(_) => {
                    self.input_teks.clear();
                    self.error_pesan = None;
                }
                Err(_) => {
                    self.teks_tersimpan.pop();
                    self.error_pesan = Some("Gagal menulis ke file JSON!".to_string());
                }
            }
        }
    }

    fn keluar(&mut self) {
        self.harus_keluar = true;
    }
}

// ==========================================
// 2. MAIN & RENDER LOOP
// ==========================================
fn main() -> io::Result<()> {
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    let mut app = App::new();
    let res = run_app(&mut terminal, &mut app);

    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;
    
    if let Err(err) = res {
        println!("Error: {:?}", err);
    }
    Ok(())
}

fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>, app: &mut App) -> io::Result<()> {
    while !app.harus_keluar {
        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    // JIKA POP-UP KONFIRMASI SEDANG TERBUKA
                    if app.konfirmasi_hapus {
                        match key.code {
                            KeyCode::Char('y') | KeyCode::Char('Y') => {
                                app.hapus_semua_riwayat();
                                app.konfirmasi_hapus = false;
                            }
                            KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Esc => {
                                app.konfirmasi_hapus = false; // Batalkan hapus
                            }
                            _ => {}
                        }
                        continue; // Lewati pemrosesan hotkeys utama jika pop-up aktif
                    }

                    // HOTKEYS UTAMA APLIKASI
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.ganti_tab(),
                        KeyCode::Char('2') => app.ganti_tab(),

                        // Tekan C di Halaman Riwayat untuk membuka dialog konfirmasi
                        KeyCode::Char('c') | KeyCode::Char('C') if app.aktif_tab == MenuTab::Riwayat => {
                            if !app.teks_tersimpan.is_empty() {
                                app.konfirmasi_hapus = true;
                            }
                        }

                        KeyCode::Enter if app.aktif_tab == MenuTab::Input => app.simpan_teks(),
                        KeyCode::Backspace if app.aktif_tab == MenuTab::Input => app.hapus_karakter(),
                        KeyCode::Char(c) if app.aktif_tab == MenuTab::Input => app.tambah_karakter(c),
                        
                        _ => {}
                    }
                }
            }
        }
    }
    Ok(())
}

// ==========================================
// 3. UI RENDERING LAYER
// ==========================================
fn ui(f: &mut Frame, app: &App) {
    let susunan_utama = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Header Tab Menu
            Constraint::Min(0),    // Konten Dinamis
            Constraint::Length(3), // Footer Informasi
        ])
        .split(f.area());

    // --- 1. SEKTOR HEADER ---
    let daftar_judul = vec![" Halaman Input ", " Riwayat Penuh "];
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Menu Utama"))
        .select(indeks_aktif)
        .style(Style::default().fg(Color::DarkGray))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::UNDERLINED),
        );
    
    // Perbaikan: Gunakan susunan_utama[0] untuk area Header
    f.render_widget(komponen_tab, susunan_utama[0]);

    // --- 2. SEKTOR KONTEN DINAMIS ---
    match app.aktif_tab {
        MenuTab::Input => {
            let area_input = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(3), // Kotak Input -> Indeks [0]
                    Constraint::Min(0),    // Area Pesan  -> Indeks [1]
                ])
                // Perbaikan: Lakukan split berdasarkan area konten dinamis yaitu susunan_utama[1]
                .split(susunan_utama[1]);

            let info_karakter = format!(" [{}/{}]", app.input_teks.len(), MAX_KARAKTER);
            let text_display = format!("> {}_", app.input_teks);
            
            let kotak_input = Paragraph::new(text_display)
                .block(Block::default().borders(Borders::ALL).title(format!("Silakan Ketik Teks Anda (Format: JSON Archive){}", info_karakter)))
                .style(Style::default().fg(Color::Cyan));

            // Perbaikan: Gunakan area_input[0] untuk kotak input
            f.render_widget(kotak_input, area_input[0]);

            if let Some(ref pesan) = app.error_pesan {
                let komponen_error = Paragraph::new(Span::styled(
                    format!("⚠ {}", pesan),
                    Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)
                ));
                // Perbaikan: Gunakan area_input[1] untuk memunculkan pesan error di bawahnya
                f.render_widget(komponen_error, area_input[1]);
            }
        }

        MenuTab::Riwayat => {
            let mut baris_riwayat = vec![Line::from(Span::styled(
                format!("Data dari file fisik ({}) yang berhasil diparsing:", FILE_PATH),
                Style::default().add_modifier(Modifier::UNDERLINED)
            ))];

            if app.teks_tersimpan.is_empty() {
                baris_riwayat.push(Line::from(""));

            baris_riwayat.push(Line::from(Span::styled("(Belum ada pesan terenkode dalam JSON)", Style::default().fg(Color::DarkGray))));
            } else {
                for (i, teks) in app.teks_tersimpan.iter().enumerate() {
                    baris_riwayat.push(Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]));
                }
            }

            let kotak_riwayat = Paragraph::new(Text::from(baris_riwayat))
               .block(Block::default().borders(Borders::ALL).title("Database Riwayat JSON"))
               .style(Style::default().fg(Color::Green));

            // Perbaikan: Gunakan susunan_utama[1] untuk menampilkan riwayat di area tengah
            f.render_widget(kotak_riwayat, susunan_utama[1]);
        }
    }

    // --- 3. SEKTOR FOOTER ---
    let info_navigasi = match app.aktif_tab {
        MenuTab::Input => "Navigasi: [Tab] Pindah Menu | [Enter] Kirim & Update JSON | [Esc] Keluar",
        MenuTab::Riwayat => "Navigasi: [Tab] Pindah Menu | [C] Hapus Semua Riwayat | [Esc] Keluar",
    };

    let petunjuk_bawah = Paragraph::new(info_navigasi)
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);

    // --- 4. SEKTOR POP-UP DIALOG (OVERLAY) ---
    // Jika state konfirmasi_hapus bernilai true, kita gambar kotak di tengah layar menggunakan fungsi pembantu
    if app.konfirmasi_hapus {
        let area_popup = buat_kotak_tengah(60, 20, f.area()); // Lebar 60% layar, tinggi 20% layar
        // Bersihkan area di bawah pop-up agar tulisan di halaman riwayat tidak menembus kotak dialog

        f.render_widget(Clear, area_popup);
        let teks_konfirmasi = Text::from(vec![
            Line::from(""),
            Line::from(Span::styled("Apakah Anda yakin ingin menghapus", Style::default().fg(Color::White))),
            Line::from(Span::styled("seluruh riwayat dan berkas JSON?", Style::default().fg(Color::White))),
            Line::from(""),
            Line::from(Span::styled("[Y] Ya, Hapus    [N] Tidak, Batalkan", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))),
        ]);

        let block_popup = Paragraph::new(teks_konfirmasi)
            .block(Block::default().borders(Borders::ALL).title(" ⚠ KONFIRMASI HAPUS DATA "))
            .style(Style::default().bg(Color::Red)) // Beri latar belakang merah sebagai penanda bahaya/warning
            .centered();

        f.render_widget(block_popup, area_popup);
    }
}
// Fungsi pembantu matematika tata letak untuk memposisikan widget tepat di tengah layar terminal secara proporsional
fn buat_kotak_tengah(persen_lebar: u16, persen_tinggi: u16, area_layar: Rect) -> Rect {
    let susunan_vertikal = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - persen_tinggi) / 2),
            Constraint::Percentage(persen_tinggi),
            Constraint::Percentage((100 - persen_tinggi) / 2),
        ])
        .split(area_layar);

    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - persen_lebar) / 2),
            Constraint::Percentage(persen_lebar),
            Constraint::Percentage((100 - persen_lebar) / 2),
        ])
        .split(susunan_vertikal[1])[1]
}

```

---















<br>
