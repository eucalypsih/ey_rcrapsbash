# 

- `r_ratatui5invatabjsondeletearrownoconfirm_socket_tcplistener_msgrx_savelogexternalreverse_reverseview_timestampserver_countmsg` -> `r_ratatui5invatabjsondeletearrownoconfirm_socket_tcplistener_msgrx_savelogexternalreverse_reverseview_timestampserver_countmsg_savexternalcsv`

---

qc: 
ingin memperluas aplikasi ini—seperti menambahkan **fitur ekspor riwayat database socket ke format CSV**

---

aa: 
Untuk memperluas aplikasi Network TUI Control Panel Anda dengan fitur ekspor ke format CSV, kita akan menambahkan tombol pintasan baru, yaitu tombol **`E` (Export)** yang hanya aktif saat pengguna berada di halaman **Database Socket (`MenuTab::Riwayat`)**.

Fitur ini akan membaca seluruh daftar alamat socket yang sedang tersimpan di memori (`app.teks_tersimpan`) dan langsung menulisnya ke dalam berkas fisik baru bernama `database_socket.csv` dengan format tabular yang rapi, lengkap dengan nomor urut.

Fitur ini akan membaca seluruh daftar alamat socket yang sedang tersimpan di memori (`app.teks_tersimpan`) dan langsung menulisnya ke dalam berkas fisik baru bernama `database_socket.csv` dengan format tabular yang rapi, lengkap dengan nomor urut.

## Bagian yang Diubah (Modifikasi State & Event)
Berikut adalah penambahan fungsi `ekspor_ke_csv` di dalam `impl App` serta penanganan tombol pintasan `E` pada fungsi `run_app`:
```rust
// 1. TAMBAHKAN METODE BARU INI DI DALAM `impl App`
fn ekspor_ke_csv(&mut self) -> io::Result<()> {
    if self.teks_tersimpan.is_empty() {
        self.error_pesan = Some("Gagal Ekspor: Database socket masih kosong!".to_string());
        return Ok(());
    }

    let nama_file_csv = "database_socket.csv";
    let mut file = File::create(nama_file_csv)?;
    
    // Tulis Header CSV
    file.write_all(b"No,Socket Address\n")?;

    // Tulis Baris Data
    for (i, teks) in self.teks_tersimpan.iter().enumerate() {
        let baris = format!("{},\"{}\"\n", i + 1, teks.replace('"', "\"\""));
        file.write_all(baris.as_bytes())?;
    }

    self.error_pesan = Some(format!("Sukses ekspor {} alamat ke {}!", self.teks_tersimpan.len(), nama_file_csv));
    Ok(())
}

// 2. TAMBAHKAN HOTKEY 'E' DI DALAM `fn run_app` (Tepat di bawah KeyCode::Char('s') / 'S')
KeyCode::Char('e') | KeyCode::Char('E') if app.aktif_tab == MenuTab::Riwayat => {
    if let Err(err) = app.ekspor_ke_csv() {
        app.error_pesan = Some(format!("Gagal membuat CSV: {}", err));
    }
}

```

---

## Kode Sumber Lengkap yang Siap Digunakan
Berikut adalah kode utuh terintegrasi yang mencakup seluruh fitur optimasi I/O *prepend reverse logging* 8 KB, *live messaging counter*, dan fitur **Ekspor CSV Instan**:
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
use std::net::SocketAddr; // Tambahan Modul Jaringan Baru
use std::net::TcpListener; // Ditambahkan TcpListener untuk real listening
use std::str::FromStr;
use std::thread; // Ditambahkan untuk menjalankan server di latar belakang
use std::sync::mpsc::{self, Receiver, Sender}; // Ditambahkan untuk komunikasi antar thread

const MAX_KARAKTER: usize = 30;
const FILE_PATH: &str = "riwayat_pesan.json";
const LOG_FILE_PATH: &str = "server_network.log"; // File fisik baru khusus log pesan client

#[derive(Copy, Clone, PartialEq)]
enum MenuTab {
    Input,
    Riwayat,
    ServerLog, // Tab baru untuk melihat aktivitas server
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
    // State baru untuk fitur jaringan
    pub server_logs: Vec<String>,
    pub tx_log: Sender<String>,
    pub rx_log: Receiver<String>,
    pub alamat_aktif_mendengar: Option<String>,
}

impl App {
    fn new() -> Self {
        let data_lama = Self::muat_dari_json();
        let mut state_riwayat = ListState::default();
        if !data_lama.is_empty() {
            state_riwayat.select(Some(0)); // Sorot baris pertama secara default
        }

        // Membuat channel komunikasi antar-thread
        let (tx, rx) = mpsc::channel();

        Self {
            input_teks: String::new(),
            teks_tersimpan: data_lama,
            error_pesan: None,
            aktif_tab: MenuTab::Input,
            state_riwayat,
            harus_keluar: false,
            server_logs: vec!["[Sistem] Log server siap...".to_string()],
            tx_log: tx,
            rx_log: rx,
            alamat_aktif_mendengar: None,
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

    // 1. TAMBAHKAN METODE BARU INI DI DALAM `impl App`
    // FITUR BARU: Menulis database socket saat ini ke bentuk CSV
    fn ekspor_ke_csv(&mut self) -> io::Result<()> {
        if self.teks_tersimpan.is_empty() {
            self.error_pesan = Some("Gagal Ekspor: Database socket masih kosong!".to_string());
            return Ok(());
        }

        let nama_file_csv = "database_socket.csv";
        let mut file = File::create(nama_file_csv)?;
        
        // Tulis Header CSV
        file.write_all(b"No,Socket Address\n")?;

        // Tulis Baris Data
        for (i, teks) in self.teks_tersimpan.iter().enumerate() {
            let baris = format!("{},\"{}\"\n", i + 1, teks.replace('"', "\"\""));
            file.write_all(baris.as_bytes())?;
        }

        self.error_pesan = Some(format!("Sukses ekspor {} alamat ke {}!", self.teks_tersimpan.len(), nama_file_csv));
        Ok(())
    }

    // =========================================================================
    // METODE KUSTOM BUATAN SENDIRI: PREPEND AMAN & HEMAT RAM (BUFFER CHUNK 8KB)
    // =========================================================================
    fn prepend_log_efisien(baris_baru: &str) -> io::Result<()> {
        let path = Path::new(LOG_FILE_PATH);
        let temp_path = path.with_extension("log.tmp");

        // 1. Tulis payload log terbaru di baris pertama file temporary (.tmp)
        let mut file_temp = File::create(&temp_path)?;
        file_temp.write_all(baris_baru.as_bytes())?;

        // 2. Jika berkas log lama ada, alirkan isinya ke file baru bertahap per 8 KB
        if path.exists() {
            let mut file_lama = File::open(path)?;
            let mut buffer = [0; 8192]; 

            loop {
                let bytes_read = file_lama.read(&mut buffer)?;
                if bytes_read == 0 {
                    break; 
                }
                file_temp.write_all(&buffer[..bytes_read])?;
            }
        }

        // 3. Ganti file lama dengan file baru secara atomik memanfaatkan fungsi bawaan OS
        std::fs::rename(temp_path, path)?;
        Ok(())
    }

    // FITUR BARU: Menyalakan Listener nyata di latar belakang thread
    fn jalankan_listener_nyata(&mut self) {
        if let Some(indeks) = self.state_riwayat.selected() {
            if indeks < self.teks_tersimpan.len() {
                let target_alamat = self.teks_tersimpan[indeks].clone();
                
                // Parse ulang ke SocketAddr untuk mematangkan validitas sebelum binding
                if let Ok(addr) = SocketAddr::from_str(&target_alamat) {
                    let tx_klon = self.tx_log.clone();
                    self.alamat_aktif_mendengar = Some(target_alamat.clone());
                    
                    // SPAWN THREAD: Agar TUI tidak freeze saat mendengarkan request masuk
                    thread::spawn(move || {
                        match TcpListener::bind(addr) {
                            Ok(listener) => {
                                let _ = tx_klon.send(format!("[Sukses] Berhasil mendengarkan di: {}", addr));
                                
                                // Loop memantau koneksi TCP yang masuk (Incoming streams)
                                for stream in listener.incoming() {
                                    match stream {
                                        Ok(mut s) => {
                                            if let Ok(peer) = s.peer_addr() {
                                                // 1. Dapatkan stempel waktu server (Jam:Menit:Detik.Milidetik) menggunakan pustaka standar
                                                // std::time::SystemTime; Tambahkan modul waktu ini di bagian atas kode Anda jika belum ada
                                                // Ditambahkan untuk stempel waktu server internal
                                                let waktu_sekarang = std::time::SystemTime::now()
                                                    .duration_since(std::time::SystemTime::UNIX_EPOCH)
                                                    .unwrap_or_default();

                                                let total_detik = waktu_sekarang.as_secs();
                                                let milidetik = waktu_sekarang.subsec_millis();

                                                // Konversi detik ke format Jam, Menit, Detik (Zona Waktu UTC/Lokal tergantung mesin)
                                                let jam = (total_detik % 86400) / 3600;
                                                let menit = (total_detik % 3600) / 60;
                                                let detik = total_detik % 60;

                                                let server_timestamp = format!(
                                                    "[{:02}:{:02}:{:02}.{:03}] [SERVER]",
                                                    jam, menit, detik, milidetik
                                                );


                                                // Beri read timeout agar thread tidak hang jika client tidak mengirim data
                                                let _ = s.set_read_timeout(Some(std::time::Duration::from_millis(500)));
                                                let mut buffer = [0; 512]; // Buffer 512 byte untuk menangkap teks kiriman
                                                match s.read(&mut buffer) {
                                                    Ok(bytes_read) => {
                                                        if bytes_read > 0 {
                                                            let pesan_mentah = String::from_utf8_lossy(&buffer[..bytes_read]);
                                                            let pesan_bersih = pesan_mentah.trim();
                                                            if !pesan_bersih.is_empty() {
                                                                // Konversi bytes mentah menjadi string UTF-8 yang aman digambar UI
                                                                // 2. KIRIM LOG KONEKSI MASUK HANYA SATU KALI DENGAN TIMESTAMP
                                                                let _ = tx_klon.send(format!("{} [Koneksi Masuk] Terhubung dengan client: {}", server_timestamp, peer));

                                                                // 1. Kirim log ke channel UI TUI
                                                                // 2. Kirim log ke channel UI TUI dengan imbuhan stempel waktu server di depannya
                                                                // Hasilnya di UI: "[17:45:12.345] [SERVER]  └─ [Pesan Teks]: "[17:45:12.300] [INFO] ...""
                                                                let log_ui = format!("{}  └─ [Pesan Teks]: \"{}\"", server_timestamp, pesan_bersih);
                                                                let _ = tx_klon.send(log_ui);

                                                                // 2. MODIFIKASI: Tulis ke file log fisik terpisah secara aman (Thread-Safe)

                                                                // =================================================================
                                                                // EKSEKUSI INTEGRASI BARU: Tulis terbalik via chunk buffering 8 KB
                                                                // =================================================================
                                                                let format_baris = format!(
                                                                    "{} [Client: {}] Pesan: {}\n",
                                                                    server_timestamp, peer, pesan_bersih
                                                                );

                                                                if let Err(e) = Self::prepend_log_efisien(&format_baris) {
                                                                    let _ = tx_klon.send(format!("[Error File I/O]: Gagal menulis log fisik: {}", e));
                                                                }
                                                            }
                                                        }
                                                    }
                                                    // Mencegah ganda saat timeout stream (Bila client memutus koneksi/nggantung)
                                                    Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => {
                                                        let _ = tx_klon.send(" └─ [Status]: Client tidak mengirim data (Timeout)".to_string());
                                                    }
                                                    Err(e) => {
                                                        // Opsional: aktifkan jika ingin mendeteksi error pemutusan paksa
                                                        let _ = tx_klon.send(format!("{}  └─ [Error Read]: {}", server_timestamp, e));
                                                    }
                                                }
                                            }
                                        }
                                        Err(e) => {
                                            let _ = tx_klon.send(format!("[Error Stream] Masalah koneksi: {}", e));
                                        }
                                    }
                                }
                            }
                            Err(err) => {
                                let _ = tx_klon.send(format!("[Gagal Bind] Alamat {} ditolak: {}", addr, err));
                            }
                        }
                    });

                    // Pindahkan pandangan tab langsung ke Server Log untuk memantau status
                    self.aktif_tab = MenuTab::ServerLog;
                }
            }
        }
    }

    // Mengambil pesan log kiriman dari thread latar belakang ke state TUI utama
    fn perbarui_log_dari_channel(&mut self) {
        while let Ok(pesan_log) = self.rx_log.try_recv() {
            self.server_logs.push(pesan_log);
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
            MenuTab::Riwayat => self.aktif_tab = MenuTab::ServerLog,
            MenuTab::ServerLog => self.aktif_tab = MenuTab::Input,
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
            return;
        }

        // Coba parsing teks menjadi struktur data SocketAddr resmi
        match SocketAddr::from_str(&teks_bersih) {
            Ok(alamat_soket) => {
                // Jika valid sebagai IP:Port, simpan representasi string-nya ke DB
                let data_simpan = alamat_soket.to_string();
                self.teks_tersimpan.push(data_simpan);

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
            Err(err) => {
                // Jika gagal di-parse, tampilkan pesan error spesifik dari std::net
                self.error_pesan = Some(format!("Format Socket Salah: {}", err));
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
        // Tarik log baru dari background thread sebelum merender UI
        app.perbarui_log_dari_channel();
        terminal.draw(|f| ui(f, app))?;

        if event::poll(std::time::Duration::from_millis(50))? { // Mengubah poll time jadi 50ms agar responsif membaca log channel
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    // HOTKEYS NAVIGASI & KONTROL UTAMA
                    match key.code {
                        KeyCode::Esc => app.keluar(),
                        KeyCode::Tab => app.ganti_tab(),

                        // Navigasi Baris (Hanya aktif di Tab Riwayat)
                        KeyCode::Up if app.aktif_tab == MenuTab::Riwayat => app.baris_atas(),
                        KeyCode::Down if app.aktif_tab == MenuTab::Riwayat => app.baris_bawah(),

                        // Tekan D untuk memicu hapus baris tertentu
                        KeyCode::Char('d') | KeyCode::Char('D') if app.aktif_tab == MenuTab::Riwayat => {
                            app.get_current_row_and_delete();
                        }

                        // TOMBOL PINTASAN BARU: Tekan 'S' untuk START/LISTEN server nyata di background
                        KeyCode::Char('s') | KeyCode::Char('S') if app.aktif_tab == MenuTab::Riwayat => {
                            app.jalankan_listener_nyata();
                        }

                        // HOTKEY BARU: Tekan E untuk melakukan proses ekspor database ke file CSV
                        KeyCode::Char('e') | KeyCode::Char('E') if app.aktif_tab == MenuTab::Riwayat => {
                            if let Err(err) = app.ekspor_ke_csv() {
                                app.error_pesan = Some(format!("Gagal Ekspor CSV: {}", err));
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
    let daftar_judul = vec![" [1] Halaman Input ", " [2] Database Socket ", " [3] Real-time Server Log "];
    let indeks_aktif = match app.aktif_tab {
        MenuTab::Input => 0,
        MenuTab::Riwayat => 1,
        MenuTab::ServerLog => 2,
    };

    let komponen_tab = Tabs::new(daftar_judul)
        .block(Block::default().borders(Borders::ALL).title("Network TUI Control Panel Panel"))
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
                .block(Block::default().borders(Borders::ALL).title(format!("Masukkan Alamat Jaringan valid (Contoh: 127.0.0.1:8080 atau [::1]:9000){}", info_karakter)))
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
            let area_riwayat_bertingkat = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Min(0),
                    Constraint::Length(1), // Tempat notifikasi sukses ekspor muncul secara dinamis
                ])
                .split(susunan_utama[1]);

            if app.teks_tersimpan.is_empty() {
                let teks_kosong = Paragraph::new("\n(Belum ada database socket tersimpan)")
                .block(Block::default().borders(Borders::ALL).title("Database Socket"))
                .style(Style::default().fg(Color::DarkGray))
                .centered();

            f.render_widget(teks_kosong, area_riwayat_bertingkat[0]);
            } else {
                // Konversi data string menjadi komponen ListItem untuk widget List
                let items: Vec<_> = app.teks_tersimpan.iter().enumerate().map(|(i, teks)| {
                    let mut simbol_status = "📡 ";
                    let mut warna_teks = Color::White;

                    if let Some(ref terikat) = app.alamat_aktif_mendengar {
                        if terikat == teks {
                            simbol_status = "🟢 [ACTIVE LISTENING] ";
                            warna_teks = Color::Green;
                        }
                    }

                    let baris = Line::from(vec![
                            Span::styled(format!("  [{:02}] ", i + 1), Style::default().fg(Color::Cyan)),
                            Span::styled(simbol_status, Style::default().fg(Color::Magenta)),
                            Span::styled(teks.clone(), Style::default().fg(warna_teks)),
                        ]);
                    ListItem::new(baris)
                }).collect();
                // Menggunakan widget List agar baris bisa diseleksi/di-highlight secara interaktif
                let komponen_list = List::new(items)
                    .block(Block::default().borders(Borders::ALL).title(format!("Database Alamat Tersedia (Pilih dan tekan [S] untuk Bind) (Total: {})", app.teks_tersimpan.len())))
                    .highlight_style(
                        Style::default()
                            .bg(Color::Rgb(50, 50, 50)) // Background baris terpilih
                            .fg(Color::Yellow)          // Warna teks baris terpilih
                            .add_modifier(Modifier::BOLD),
                    )
                    .highlight_symbol("➡ "); // Simbol penunjuk baris aktif
                // Render List dengan status state-nya agar kursor seleksi bergerak
                f.render_stateful_widget(komponen_list, area_riwayat_bertingkat[0], &mut app.state_riwayat);
            }
                // Gambar status pemberitahuan ekspor CSV jika ada di dalam variabel error_pesan
                if let Some(ref pesan) = app.error_pesan {
                    let warna_status = if pesan.contains("Sukses") { Color::LightGreen } else { Color::Red };
                    let komponen_status = Paragraph::new(Span::styled(
                        format!("ℹ {}", pesan),
                        Style::default().fg(warna_status).add_modifier(Modifier::BOLD)
                    ));
                f.render_widget(komponen_status, area_riwayat_bertingkat[1]);
            }
        }


        MenuTab::ServerLog => {
            // =================================================================
            // INTEGRASI BARU: MEMBAGI AREA LOG MENJADI PANEL UTAMA & SUB-STATISTIK
            // =================================================================
            let area_log_bertingkat = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Min(0),    // Kotak Log Utama -> Indeks [0]
                    Constraint::Length(1), // Baris Counter di bawah kotak log -> Indeks [1]
                ])
                .split(susunan_utama[1]);

            // 1. HITUNG TINGGI MAKSIMAL PANEL SECARA TYPE-SAFE (Bebas dari operator `as`)
            // Dikurangi 2 karena terpotong oleh garis border atas dan bawah widget Block
            let tinggi_maks_layar = usize::from(area_log_bertingkat[0].height).saturating_sub(2);

            // 2. POTONG VECTOR AGAR HANYA MENGAMBIL LOG TERBARU (Auto-Scroll Logic)
            let log_diambil = if app.server_logs.len() > tinggi_maks_layar {
                &app.server_logs[app.server_logs.len() - tinggi_maks_layar..]
            } else {
                &app.server_logs[..]
            };

            // Merender log dinamis dari background server thread
            // 3. GENERASI LINE UNTUK RENDER WIDGET (Menggunakan data log yang sudah dipotong)
            // Menggunakan `.iter().rev()` agar data terbaru berada di indeks paling atas UI
            let lines: Vec<_> = log_diambil.iter().rev().map(|log| {
                if log.contains("[Pesan Teks]") {
                    // Beri warna kuning mencolok khusus untuk pesan teks yang dikirim client
                    Line::from(Span::styled(log.clone(), Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)))
                } else if log.contains("[Sukses]") || log.contains("[Koneksi Masuk]") {
                    Line::from(Span::styled(log.clone(), Style::default().fg(Color::Green)))
                } else if log.contains("[Gagal]") || log.contains("[Error]") {
                    Line::from(Span::styled(log.clone(), Style::default().fg(Color::Red).add_modifier(Modifier::BOLD)))
                } else {
                    Line::from(Span::styled(log.clone(), Style::default().fg(Color::DarkGray)))
                }
            }).collect();

            let status_bind = match &app.alamat_aktif_mendengar {
                Some(addr) => format!(" AKTIF MENDENGAR PAYLOAD (TERBARU DI ATAS): {} ", addr),
                None => " SERVER MATI (BELUM ADA SOCKET TERIKAT) ".to_string(),
            };

            let kotak_log = Paragraph::new(lines)
                .block(Block::default().borders(Borders::ALL).title(status_bind))
                .style(Style::default().fg(Color::White));

            f.render_widget(kotak_log, area_log_bertingkat[0]);
            // -----------------------------------------------------------------
            // PROSES HITUNG STATISTIK COUNTER SECARA DINAMIS
            // -----------------------------------------------------------------
            let total_koneksi = app.server_logs.iter().filter(|log| log.contains("[Koneksi Masuk]")).count();
            let total_payload = app.server_logs.iter().filter(|log| log.contains("[Pesan Teks]")).count();
            let teks_stat_kanan = format!(
                "📊 Total Handshake TCP: {} | 📩 Pesan Diterima: {} ",
                total_koneksi, total_payload
            );
            let komponen_counter = Paragraph::new(Span::styled(
                teks_stat_kanan,
                Style::default().fg(Color::LightGreen).add_modifier(Modifier::BOLD)
            )).right_aligned(); // Rata Kanan Pas di Pojok Bawah
            // Render statistik tepat di bawah garis border kotak log
            f.render_widget(komponen_counter, area_log_bertingkat[1]);

        }
    }

    // --- 3. SEKTOR FOOTER ---
    let info_navigasi = match app.aktif_tab {
            MenuTab::Input => "Navigasi: [Tab] Pindah Menu | [Enter] Validasi & Simpan | [Esc] Keluar",
            MenuTab::Riwayat => "Navigasi: [Tab] Pindah Menu | [▲/▼] Pilih Baris | [S] Server Bind | [D] Hapus | [E] Ekspor CSV",
            MenuTab::ServerLog => "Navigasi: [Tab] Pindah Menu | Uji Payload: echo \"Halo Rust\" | nc <IP> <PORT> | [Esc] Keluar",
    };

    let petunjuk_bawah = Paragraph::new(info_navigasi)
        .block(Block::default().borders(Borders::ALL).title("Sistem Hotkeys"))
        .style(Style::default().fg(Color::DarkGray))
        .centered();

    // Perbaikan: Gunakan susunan_utama[2] untuk area Footer bawah
    f.render_widget(petunjuk_bawah, susunan_utama[2]);
}

```


### Format Struktur Hasil Ekspor CSV

Ketika tombol **`E`** ditekan pada halaman database, sebuah berkas baru bernama `database_socket.csv` akan tercipta dengan struktur isi data tabular yang bersih seperti berikut:
```csv
No,Socket Address
1,"127.0.0.1:8080"
2,"192.168.1.100:9000"
3,"[::1]:5000"

```


### Ringkasan Penambahan Komponen Fitur CSV

| Sektor Bagian Kode | Cara Kerja Fungsionalitas | Visualisasi pada Antarmuka TUI |
| :--- | :--- | :--- |
| `app.ekspor_ke_csv()` | Iterasi array murni dengan *string escape* standar murni tanpa dependensi eksternal. | Notifikasi warna hijau terang muncul di baris bawah: `Sukses ekspor X alamat ke database_socket.csv!` . |
| **Hotkey Control Loop** | Memetakan `KeyCode::Char('e' \| 'E')` khusus saat `aktif_tab == MenuTab::Riwayat`. | Tombol ekspor terisolasi aman, tidak akan memicu konflik fungsi saat mengetik di halaman input teks. |

---

qa: 
Fitur penulisan CSV instan ini sudah terpasang rapi dan aman dari konflik karakter *double quotes* (`"`). Apakah hasil visualisasi notifikasi ekspor di halaman *Database Socket* sudah terlihat pas pada monitor Anda?










<br>
