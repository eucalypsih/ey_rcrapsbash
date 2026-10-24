# 

- `r_ratatui5invatabjsondeletearrownoconfirmsocket` -> - `r_ratatui5invatabjsondeletearrownoconfirmtaskcontext`

aa: 
Untuk menambahkan fitur yang melibatkan `std::task::Context` ke dalam aplikasi berbasis CLI TUI (Ratatui) Anda, kita perlu memahami konteks penggunaannya di Rust. `std::task::Context` adalah komponen inti dari pemrograman asinkron (*asynchronous*) di Rust yang digunakan untuk membungkus `Waker`. `Waker` bertugas memberi tahu *executor* (seperti `tokio` atau `async-std`) bahwa suatu `future` atau tugas asinkron siap untuk diproses kembali (*polled*).

Karena aplikasi Anda saat ini berjalan secara sinkron (`blocking`) menggunakan `crossterm::event::poll`, menerapkan komponen asinkron murni memerlukan sebuah mekanisme *runtime* minimal atau pembuatan struktur data yang menerapkan *trait* `Future`.

Berikut adalah strategi terbaik untuk menambahkan fitur ini: kita akan membuat sebuah **pembaca berkas asinkron sederhana** (simulasi *Future* kustom) untuk memuat ulang data riwayat JSON di latar belakang (*background task*), di mana fungsi `poll` di dalamnya secara eksplisit menggunakan `std::task::Context`.

## Perubahan Utama pada Kode:
1. Menambahkan Modul Asinkron: Membuat struct `AsyncFileLoader` yang menerapkan `std::future::Future`. Di dalam fungsi `poll`, kita menggunakan `cx: &mut std::task::Context` untuk menjadwalkan atau membangunkan *task*.
2. Pembaruan State Aplikasi (`App`): Menambahkan field `loading_future` untuk menyimpan status pembacaan berkas secara non-blocking di latar belakang.
3. Pembaruan UI: Menampilkan indikator status `"Memuat data dari berkas..."` ketika proses asinkron sedang berjalan.
4. Mekanisme Polling Manual: Di dalam `run_app`, kita membuat `Context` tiruan menggunakan `noop_waker` agar aplikasi TUI Anda tetap ringan tanpa harus bergantung pada *runtime* besar seperti `tokio`.

```rust
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Tabs},
    Frame, Terminal,
};
use std::fs::File;
use std::io::{self, stdout, Read, Write, Stdout};
use std::path::Path;
use std::future::Future;
use std::task::{Context, Poll, Waker};
use std::pin::Pin;
use std::task::RawWaker;
use std::task::RawWakerVTable;

const MAX_KARAKTER: usize = 20;
const FILE_PATH: &str = "riwayat_pesan.json";

#[derive(Copy, Clone, PartialEq)]
enum MenuTab {
    Input,
    Riwayat,
}

// ==========================================
// FEATURE BARU: Asynchronous File Loader (Menggunakan std::task::Context)
// ==========================================
struct AsyncFileLoader {
    sudah_jalan: bool,
}

impl AsyncFileLoader {
    fn new() -> Self {
        Self { sudah_jalan: false }
    }
}

// Implementasi Future secara manual agar kita bisa berinteraksi langsung dengan std::task::Context
impl Future for AsyncFileLoader {
    type Output = Vec<String>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if !self.sudah_jalan {
            // Menandakan bahwa operasi latar belakang sedang dimulai
            self.sudah_jalan = true;
            
            // Memicu Waker dari Context untuk memberi tahu executor agar melakukan poll kembali sesegera mungkin
            cx.waker().wake_by_ref();
            
            Poll::Pending
        } else {
            // Ketika di-poll untuk kedua kalinya, lakukan pembacaan file secara fisik
            let data = App::muat_dari_json();
            Poll::Ready(data)
        }
    }
}

// ==========================================
// 1. STRUKTUR DATA APLIKASI (STATE)
// ==========================================
struct App {
    pub input_teks: String,
    pub teks_tersimpan: Vec<String>,
    pub error_pesan: Option<String>,
    pub aktif_tab: MenuTab,
    pub state_riwayat: ListState, // Menyimpan indeks baris yang aktif dipilih
    pub harus_keluar: bool,
    // Menyimpan state dari Fitur Asinkron kustom
    pub loading_future: Option<AsyncFileLoader>,
    pub sedang_memuat: bool,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();
        let mut state_riwayat = ListState::default();
        if !data_lama.is_empty() {
            state_riwayat.select(Some(0)); // Sorot baris pertama secara default
        }

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            state_riwayat,
            harus_keluar: false,
            loading_future: None,
            sedang_memuat: false,
        }
    }

    // Fitur Baru: Memicu pemuatan berkas ulang secara asinkron
    fn muat_ulang_asinkron(&mut self) {
        self.sedang_memuat = true;
        self.loading_future = Some(AsyncFileLoader::new());
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

    // Menghapus baris tertentu berdasarkan indeks
    fn hapus_baris_aktif(&mut self) {
        if let Some(indeks) = self.state_riwayat.selected() {
            if indeks < self.teks_tersimpan.len() {
                self.teks_tersimpan.remove(indeks);
                
                // Perbarui isi berkas fisik JSON secara instan
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

// Helper untuk membuat Waker tiruan (No-Op Waker) tanpa runtime eksternal
fn dummy_raw_waker() -> RawWaker {
    fn no_op(_: *const ()) {}
    fn clone(_: *const ()) -> RawWaker { dummy_raw_waker() }
    
    let vtable = &RawWakerVTable::new(clone, no_op, no_op, no_op);
    RawWaker::new(std::ptr::null(), vtable)
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
    // Membuat waker dan context untuk mengeksekusi Future buatan kita
    let raw_waker = dummy_raw_waker();
    let waker = unsafe { Waker::from_raw(raw_waker) };
    let mut cx = Context::from_waker(&waker);

    while !app.harus_keluar {
        // DRIVE FUTURE: Jika proses memuat sedang aktif, lakukan polling secara periodik
        if let Some(mut fut) = app.loading_future.take() {
            match Pin::new(&mut fut).poll(&mut cx) {
                Poll::Ready(data_baru) => {
                    app.teks_tersimpan = data_baru;
                    app.sedang_memuat = false;
                    app.loading_future = None;
                    if !app.teks_tersimpan.is_empty() {
                        app.state_riwayat.select(Some(0));
                    }
                }
                Poll::Pending => {
                    // Kembalikan objek future ke state agar di-poll kembali pada iterasi berikutnya
                    app.loading_future = Some(fut);
                }
            }
        }

        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    // HOTKEYS NAVIGASI & KONTROL UTAMA
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),
                        KeyCode::Char('1') => app.ganti_tab(),
                        KeyCode::Char('2') => app.ganti_tab(),

                        // HOTKEY BARU: Tekan R untuk memuat ulang data secara asinkron
                         KeyCode::Char('r') | KeyCode::Char('R') if app.aktif_tab == MenuTab::Riwayat => {
                            app.muat_ulang_asinkron();
                        }
                        // Navigasi Baris (Hanya aktif di Tab Riwayat)
                        KeyCode::Up if app.aktif_tab == MenuTab::Riwayat => app.baris_atas(),
                        KeyCode::Down if app.aktif_tab == MenuTab::Riwayat => app.baris_bawah(),

                        // Tekan D untuk memicu hapus baris tertentu
                        KeyCode::Char('d') | KeyCode::Char('D') if app.aktif_tab == MenuTab::Riwayat => {
                            app.get_current_row_and_delete();
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

// Fungsi perantara untuk memperjelas pemanggilan alur hapus instan
impl App {
    fn get_current_row_and_delete(&mut self) {
        self.hapus_baris_aktif();
    }
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

    // KONDISI RENDERING BARU: Menampilkan status Loading asinkron jika sedang aktif
    if app.sedang_memuat {
        let komponen_loading = Paragraph::new("\n⏳ Sedang memuat data dari berkas JSON di latar belakang...")
            .block(Block::default().borders(Borders::ALL).title("Status Operasi Asinkron"))
            .style(Style::default().fg(Color::Yellow))
            .centered();
        f.render_widget(komponen_loading, susunan_utama[1]);
    } else {

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
    }

    // --- 3. SEKTOR FOOTER ---
    // FOOTER BARU: Menambahkan info pintasan [R] untuk reload data
    let info_navigasi = match app.aktif_tab {
            MenuTab::Input => "Navigasi: [Tab] Pindah Menu | [Enter] Validasi & Simpan | [Esc] Keluar",
            MenuTab::Riwayat => "Navigasi: [Tab] Pindah Menu | [▲/▼] Pilih | [D] Hapus | [R] Async Reload JSON | [Esc] Keluar",
    };

    let petunjuk_bawah = Paragraph::new(info_navigasi)
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```


### Ringkasan Penambahan Fitur Baru

| Nama Komponen | Tipe Berkas / Konstruksi | Kegunaan Utama |
| :--- | :--- | :--- |
| **`AsyncFileLoader`** | Implementasi `std::future::Future` | Melakukan operasi I/O pembacaan berkas secara *non-blocking* dengan memanipulasi parameter `std::task::Context`. |
| **`dummy_raw_waker`** | *Low-level No-Op Executor Waker* | Memfasilitasi pembuatan objek `Waker` dan `Context` standar Rust tanpa membutuhkan ketergantungan pustaka luar (*Zero Dependency Async*). |
| **Pintasan `[R]` / `[r]`** | *Event Controller Binder* | Memicu state `app.sedang_memuat = true` dan mendaftarkan instansiasi `Future` ke dalam *main loop runtime pipeline*. |

---

qa: 
Apakah Anda ingin meningkatkan sistem asinkron ini agar terintegrasi dengan **Tokio Runtime** untuk I/O yang sepenuhnya multi-threaded, atau membutuhkan **indikator animasi loading (spinner)** saat data sedang dimuat?







<br>
