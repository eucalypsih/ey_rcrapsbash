# 

- `r_ratatui5invatabjsondeletearrownoconfirm_socket_tcplistener_msgrx`

qc: 
melangkah lebih jauh untuk menambahkan fitur **menampilkan pesan teks yang dikirim oleh client** di dalam halaman Server Log tersebut

---

aa: 
Untuk menampilkan pesan teks yang dikirim oleh *client* secara langsung di halaman **Server Log**, kita perlu memodifikasi alur pembacaan data stream pada *background thread* jaringan.

Ketika koneksi Incoming masuk, program tidak hanya mencatat IP *client*, tetapi juga membaca isi buffer data dari koneksi TCP tersebut (`std::io::Read`). Untuk mencegah *blocking* (aplikasi macet saat menunggu *client* mengirim teks), kita akan menetapkan batas waktu tunggu pembacaan menggunakan `.set_read_timeout`.

Berikut adalah kode sumber lengkap yang telah diperbarui untuk membaca dan menampilkan pesan teks *client* secara interaktif:

---

### Ringkasan Penyesuaian Struktur Pemrosesan:

| Komponen Alur | Sistem Jaringan Awal | Sistem Jaringan Baru (Membaca Payload) |
| :--- | :--- | :--- |
| **I/O Penanganan Stream** | Hanya mengambil data `peer_addr()` | Membaca data isi *buffer* menggunakan fungsi `s.read()` |
| **Keamanan Thread** | Langsung bersiap menerima koneksi baru berikutnya | Memasang `.set_read_timeout` agar pembacaan tidak memblokir antrean |
| **Penyusunan UI Log** | Mewarnai hijau untuk log penanda sukses biasa | Memfilter string `[Pesan Teks]` menjadi warna kuning tebal (*Bold*) |

---

### Cara Baru Menguji Pengiriman Pesan Teks (Payload):
1. Jalankan program dengan `cargo run`.
2. Masukkan alamat (misal: `127.0.0.1:8080`) di **Halaman Input** dan simpan.
3. Masuk ke **Database Socket**, pilih alamat tersebut, lalu tekan tombol **`S`** untuk mengikat jaringan.
4. Buka terminal eksternal baru di komputer Anda, lalu kirim string teks nyata menggunakan perintah *pipe text* via `netcat` berikut:
```bash
echo "Hello from Client TUI!" | nc 127.0.0.1 8080

```

```bash
(echo "Hello from Client TUI!"; sleep 1) | telnet 127.0.0.1 8080

```

```bash
while true; do echo "[$(date '+%H:%M:%S')] [INFO] System audit checkpoint passed successfully." | telnet 127.0.0.1 8080; sleep 1; done

```

5. Perhatikan halaman **Real-time Server Log** pada TUI Anda. Log akan langsung memunculkan baris baru berwarna kuning terang:
```bash
🟢 [Koneksi] Terhubung dengan client: 127.0.0.1:xxxxx
 └─ [Pesan Teks]: "Hello from Client TUI!"

```

---

qa: 
Sekarang server mini Anda di dalam TUI sudah dapat membaca isi pesan dari *client*. Langkah menarik berikutnya adalah **membuat server membalas pesan tersebut (_echo back response_)** atau **menyimpan pesan kiriman client ke file log fisik terpisah**. Fitur mana yang ingin Anda implementasikan selanjutnya?

---

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
                                                let _ = tx_klon.send(format!("[Koneksi] Terhubung dengan client: {}", peer));

                                                // Beri read timeout agar thread tidak hang jika client tidak mengirim data
                                                let _ = s.set_read_timeout(Some(std::time::Duration::from_millis(500)));
                                                let mut buffer = [0; 512]; // Buffer 512 byte untuk menangkap teks kiriman
                                                match s.read(&mut buffer) {
                                                    Ok(bytes_read) => {
                                                        if bytes_read > 0 {
                                                            // Konversi bytes mentah menjadi string UTF-8 yang aman digambar UI
                                                            let pesan_mentah = String::from_utf8_lossy(&buffer[..bytes_read]);
                                                            let pesan_bersih = pesan_mentah.trim();
                                                            if !pesan_bersih.is_empty() {
                                                                let _ = tx_klon.send(format!(" └─ [Pesan Teks]: \"{}\"", pesan_bersih));
                                                            }
                                                        }
                                                    }
                                                    Err(ref e) if e.kind() == io::ErrorKind::WouldBlock => {
                                                        let _ = tx_klon.send(" └─ [Status]: Client tidak mengirim data (Timeout)".to_string());
                                                    }
                                                    Err(e) => {
                                                        let _ = tx_klon.send(format!(" └─ [Error Read]: {}", e));
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
    let daftar_judul = vec![" [1] Halaman Input ", " [2] Database Socket ", " [Real-time Server Log "];
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
            if app.teks_tersimpan.is_empty() {
                let teks_kosong = Paragraph::new("\n(Belum ada database socket tersimpan)")
                .block(Block::default().borders(Borders::ALL).title("Database Socket"))
                .style(Style::default().fg(Color::DarkGray))
                .centered();

            f.render_widget(teks_kosong, susunan_utama[1]);
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
                f.render_stateful_widget(komponen_list, susunan_utama[1], &mut app.state_riwayat);
            }
        }

        MenuTab::ServerLog => {
            // Merender log dinamis dari background server thread
            let lines: Vec<_> = app.server_logs.iter().map(|log| {
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
                Some(addr) => format!(" AKTIF MENDENGAR PAYLOAD: {} ", addr),
                None => " SERVER MATI (BELUM ADA SOCKET TERIKAT) ".to_string(),
            };

            let kotak_log = Paragraph::new(lines)
                .block(Block::default().borders(Borders::ALL).title(status_bind))
                .style(Style::default().fg(Color::White));

            f.render_widget(kotak_log, susunan_utama[1]);
        }
    }

    // --- 3. SEKTOR FOOTER ---
    let info_navigasi = match app.aktif_tab {
            MenuTab::Input => "Navigasi: [Tab] Pindah Menu | [Enter] Validasi & Simpan | [Esc] Keluar",
            MenuTab::Riwayat => "Navigasi: [Tab] Pindah Menu | [▲/▼] Pilih Baris | [S] Nyalakan Server Bind | [D] Hapus Instan",
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

















<br>
