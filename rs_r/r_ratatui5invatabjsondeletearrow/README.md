# 

qs: 
menganti fitur **menghapus semua riwayat** menjadi **menghapus baris riwayat tertentu** langsung dari TUI

---

aa: 
Untuk mengubah fitur dari menghapus semua riwayat menjadi **menghapus baris riwayat tertentu**, kita perlu menambahkan mekanisme seleksi baris (seperti menggunakan tombol panah atas/bawah) untuk memilih pesan mana yang ingin dihapus, lalu menekan tombol `D` (Delete) untuk memicu konfirmasi penghapusan baris tersebut.

Kita akan menggunakan komponen `List` dan `ListState` bawaan Ratatui untuk mempermudah navigasi seleksi item di halaman riwayat.

Berikut adalah kode sumber lengkap yang telah diperbarui dengan fitur seleksi dan hapus baris tertentu:

---

### Penjelasan Perubahan Fitur Baru:
1. **`List` & `ListState`**: Di Halaman Riwayat, kita mengganti struktur `Paragraph` statis menjadi `List` interaktif. `ListState` bertindak sebagai penampung indeks baris mana yang sedang disorot oleh user.
2. **Navigasi `[▲ / ▼]` (Tombol Panah)**: Pengguna sekarang bisa menggerakkan pointer baris naik dan turun di halaman riwayat. Logikanya diatur di fungsi `baris_atas()` dan `baris_bawah()`, yang juga menyertakan fitur *wrapping* (jika sudah di baris paling bawah, ditekan panah bawah akan kembali ke baris paling atas).
3. **Pemicu Pintasan Baru `[D]` (Delete)**: Mengubah tombol `C` (Clear) menjadi `D` (Delete) untuk mencerminkan aksi penghapusan spesifik item terpilih.
4. **Pop-up Informatif**: Ketika tombol `D` ditekan, modal konfirmasi akan muncul dan secara cerdas menampilkan teks isi dari baris tersebut agar pengguna tahu pasti apa yang akan mereka hapus. Jika dikonfirmasi (`Y`), program memanggil `.remove(indeks)` pada Vector dan memperbarui file JSON fisik.

| Komponen Fitur | Sistem Sebelumnya (Clear All) | Sistem Baru (Delete Row) |
| :--- | :--- | :--- |
| **Widget UI Riwayat** | `Paragraph` (Teks Statis) | `List` & `ListState` (Stateful/Interaktif) |
| **Hotkeys Aksi** | `C` / `c` | `D` / `d` (Serta `▲`/`▼` untuk navigasi baris) |
| **Dampak File Fisik** | File `.json` dihapus total dari disk | Elemen array JSON dihapus, berkas di-update |

---

qa: 
Apakah fitur **hapus baris riwayat terpilih** ini sudah berjalan lancar dan interaktif di terminal Anda? Beritahu saya jika ada aspek visual atau logika kontrol lain yang ingin Anda kembangkan lagi!

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
    text::{Text, Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Tabs},
    Frame, Terminal,
};
use std::fs::File;
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
    pub state_riwayat: ListState, // State untuk menyimpan indeks baris yang sedang dipilih
    pub indeks_akan_dihapus: Option<usize>, // Menyimpan indeks baris yang akan didelete
    pub harus_keluar: bool,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();
        let mut state_riwayat = ListState::default();
        if !data_lama.is_empty() {
            state_riwayat.select(Some(0)); // Pilih baris pertama secara default jika ada data
        }

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            state_riwayat,
            indeks_akan_dihapus: None, // Default tidak ada baris yang dipilih untuk dihapus
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
                    if !clean_str(bersih).is_empty() {
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

    // FITUR BARU: Menghapus baris tertentu berdasarkan indeks
    fn hapus_baris_terpilih(&mut self) {
        if let Some(indeks) = self.indeks_akan_dihapus {
            if indeks < self.teks_tersimpan.len() {
                self.teks_tersimpan.remove(indeks);
                
                // Simpan ulang data terbaru ke file JSON
                if let Err(_) = self.simpan_ke_json() {
                    self.error_pesan = Some("Gagal memperbarui file JSON fisik!".to_string());
                }

                // Sesuaikan posisi kursor seleksi setelah item dihapus
                if self.teks_tersimpan.is_empty() {
                    self.state_riwayat.select(None);
                } else if indeks >= self.teks_tersimpan.len() {
                    self.state_riwayat.select(Some(self.teks_tersimpan.len() - 1));
                }
            }
        }
        self.indeks_akan_dihapus = None;
    }

    // Navigasi ke baris atas
    fn baris_atas(&mut self) {
        if self.teks_tersimpan.is_empty() { return; }
        let i = match self.state_riwayat.selected() {
            Some(i) => {
                if i == 0 {
                    self.teks_tersimpan.len() - 1
                } else {
                    i - 1
                }
            }
            None => 0,
        };
        self.state_riwayat.select(Some(i));
    }

    // Navigasi ke baris bawah
    fn baris_bawah(&mut self) {
        if self.teks_tersimpan.is_empty() { return; }
        let i = match self.state_riwayat.selected() {
            Some(i) => {
                if i >= self.teks_tersimpan.len() - 1 {
                    0
                } else {
                    i + 1
                }
            }
            None => 0,
        };
        self.state_riwayat.select(Some(i));
    }

    fn ganti_tab(&mut self) {
        if self.indeks_akan_dihapus.is_none() {
            match self.aktif_tab {
                MenuTab::Input => {
                    self.aktif_tab = MenuTab::Riwayat;
                    if !self.teks_tersimpan.is_empty() && self.state_riwayat.selected().is_none() {
                        self.state_riwayat.select(Some(0));
                    }
                }
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

fn clean_str(s: &str) -> &str {
    s.trim()
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
                    // JIKA MODAL KONFIRMASI AKTIF
                    if app.indeks_akan_dihapus.is_some() {
                        match key.code {
                            KeyCode::Char('y') | KeyCode::Char('Y') => {
                                app.hapus_baris_terpilih();
                            }
                            KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Esc => {
                                app.indeks_akan_dihapus = None; // Batalkan hapus
                            }
                            _ => {}
                        }
                        continue; // Lewati pemrosesan hotkeys utama jika pop-up aktif
                    }

                    // HOTKEYS NAVIGASI & KONTROL UTAMA
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.ganti_tab(),
                        KeyCode::Char('2') => app.ganti_tab(),

                        // Navigasi Baris (Hanya aktif di Tab Riwayat)
                        KeyCode::Up if app.aktif_tab == MenuTab::Riwayat => app.baris_atas(),
                        KeyCode::Down if app.aktif_tab == MenuTab::Riwayat => app.baris_bawah(),

                        // Tekan D untuk memicu hapus baris tertentu
                        KeyCode::Char('d') | KeyCode::Char('D') if app.aktif_tab == MenuTab::Riwayat => {
                            if let Some(indeks) = app.state_riwayat.selected() {
                                app.indeks_akan_dihapus = Some(indeks);
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
fn ui(f: &mut Frame, app: &mut App) {
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
            if app.teks_tersimpan.is_empty() {
                let teks_kosong = Paragraph::new("\n(Belum ada pesan terenkode dalam JSON)")
                .block(Block::default().borders(Borders::ALL).title("Database Riwayat JSON"))
                .style(Style::default().fg(Color::DarkGray))
                .centered();

            f.render_widget(teks_kosong, susunan_utama[1]);
            } else {
                // Konversi data string menjadi komponen ListItem untuk widget List
                let items: Vec<_> = app.teks_tersimpan.iter().enumerate().map(|(i, teks)| {
                    let baris = Line::from(vec![
                        Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                        Span::raw(teks.clone()),
                    ]);
                    ListItem::new(baris)
                }).collect();
                // Menggunakan widget List agar baris bisa diseleksi/di-highlight secara interaktif
                let komponen_list = List::new(items)
                .block(Block::default().borders(Borders::ALL).title(format!("Database Riwayat JSON (Total: {})", app.teks_tersimpan.len())))
                .highlight_style(
                    Style::default()
                    .bg(Color::Rgb(50, 50, 50)) // Background baris terpilih
                    .fg(Color::Yellow)          // Warna teks baris terpilih
                    .add_modifier(Modifier::BOLD),
                )
                .highlight_symbol("➡ "); // Simbol penunjuk baris aktif
                // Render List dengan status state-nya agar kursor seleksi bergerak
            f.render_stateful_widget(komponen_list, susunan_utama[1], &mut app.state_riwayat);
            }
        }
    }

    // --- 3. SEKTOR FOOTER ---
    let info_navigasi = match app.aktif_tab {
        MenuTab::Input => "Navigasi: [Tab] Pindah Menu | [Enter] Kirim & Update JSON | [Esc] Keluar",
        MenuTab::Riwayat => "Navigasi: [Tab] Pindah Menu | [▲/▼] Pilih Baris | [D] Hapus Baris Terpilih | [Esc] Keluar",
    };

    let petunjuk_bawah = Paragraph::new(info_navigasi)
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);

    // --- 4. SEKTOR POP-UP DIALOG (OVERLAY) ---
    if let Some(indeks) = app.indeks_akan_dihapus {
        let area_popup = buat_kotak_tengah(60, 20, f.area()); // Lebar 60% layar, tinggi 20% layar
        // Bersihkan area di bawah pop-up agar tulisan di halaman riwayat tidak menembus kotak dialog

        f.render_widget(Clear, area_popup);
        let pesan_konfirmasi = format!("Apakah Anda yakin ingin menghapus baris [{:02}]?", indeks + 1);
        let teks_konfirmasi = Text::from(vec![
            Line::from(""),
            Line::from(Span::styled(pesan_konfirmasi, Style::default().fg(Color::White))),
            Line::from(Span::styled(format!("{}", app.teks_tersimpan[indeks]), Style::default().fg(Color::DarkGray).add_modifier(Modifier::ITALIC))),
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

<br>
