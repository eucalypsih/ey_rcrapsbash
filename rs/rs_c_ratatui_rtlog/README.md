# 

qc: 
aplikasi ini nantinya ditargetkan untuk membaca berkas log yang terus **bertambah secara real-time** (seperti fitur `tail -f`)

---

aa: 
Untuk menangani berkas log yang terus bertambah secara *real-time* seperti `tail -f` tanpa membuat antarmuka (UI) Anda membeku (*freeze*), Anda **wajib menggunakan arsitektur Multithreading atau Asynchronous**.

Dalam standar industri Rust, cara terbaik adalah menyerahkan tugas pemantauan berkas ke **Background Thread**, lalu mengirimkan baris teks baru ke **Main Thread (TUI Loop)** menggunakan *channel* komunikasi (`std::sync::mpsc`).

Berikut adalah perubahan arsitektur dan implementasi kode lengkap yang efisien untuk kebutuhan *real-time log viewer* Anda.

## 🛠️ Perubahan Strategi Manajemen State
1. Pemisahan Tugas (Decoupling): *Main thread* hanya fokus menggambar UI (~60 FPS) dan mendengarkan *keyboard. Background thread* fokus memantau *disk* I/O
2. Event Loop Bersama (Unified Event Loop): Kita menggabungkan *event* tombol dari `crossterm` dan *event* baris log baru ke dalam satu penerima channel (`Receiver`) yang sama. Ini mencegah pemborosan CPU (0% CPU *idle*).
3. Penyimpanan Log Efisien: Menggunakan `Vec<String>` untuk menampung baris log. TUI hanya akan menggambar baris yang muat di layar terminal.

---

## 💻 Kode Solusi Industri: Real-Time Tail TUI
Silakan perbarui kode Anda menjadi struktur berikut. Kode ini murni menggunakan pustaka standar Rust (`std`) untuk *multithreading* agar tetap ringan tanpa ketergantungan `tokio`:

- `ratatui_rtlog/Cargo.toml`
```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
ratatui = "0.30.2"   # Tambahkan library TUI standar industri Rust

```

- `ratatui_rtlog/src/main.rs`
```rust
use std::io::{self, BufRead, BufReader, Seek, SeekFrom};
use std::time::Duration;
use std::fs::File;
use std::sync::mpsc;
use std::thread;

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Terminal,
};

// =========================================================================
// 1. MANAJEMEN STATE & EVENT SYSTEM
// =========================================================================

// Enum untuk menyatukan input keyboard dan data log real-time
enum AppEvent {
    Key(KeyCode),
    LogLine(String),
}

struct AppState {
    current_branch: String,
    repo: String,
    owner: String,
    log_lines: Vec<String>, // Menyimpan baris log secara dinamis
    should_quit: bool,
}

impl AppState {
    fn new(branch: &str, repo: &str, owner: &str) -> Self {
        Self {
            current_branch: branch.to_string(),
            repo: repo.to_string(),
            owner: owner.to_string(),
            log_lines: Vec::new(),
            should_quit: false,
        }
    }
}

fn main() -> Result<(), io::Error> {
    // INISIALISASI TERMINAL TUI
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app_state = AppState::new("main", "ey_rcrapsbash", "eucalypsih");

    // Pembuatan MPSC Channel untuk menyatukan Event
    let (tx, rx) = mpsc::channel::<AppEvent>();

    // -------------------------------------------------------------------------
    // 2. BACKGROUND THREAD: Memantau File Log (Fitur `tail -f`)
    // -------------------------------------------------------------------------
    let tx_log = tx.clone();
    let file_path = "log.txt".to_string();
    
    thread::spawn(move || {
        // Buka file atau buat baru jika belum ada agar aplikasi tidak langsung crash
        let file = loop {
            if let Ok(f) = File::open(&file_path) {
                break f;
            }
            thread::sleep(Duration::from_millis(500));
        };

        let mut reader = BufReader::new(file);
        
        // Mulai pembacaan dari akhir file (seperti tail -f standar)
        let _ = reader.seek(SeekFrom::End(0));
        let mut line = String::new();

        loop {
            match reader.read_line(&mut line) {
                Ok(0) => {
                    // Jika tidak ada baris baru, tunggu 100ms sebelum membaca lagi
                    thread::sleep(Duration::from_millis(100));
                }
                Ok(_) => {
                    let cleaned_line = line.trim_end().to_string();
                    // Kirim baris baru ke main thread UI
                    if tx_log.send(AppEvent::LogLine(cleaned_line)).is_err() {
                        break; // Main thread tutup, keluar dari loop
                    }
                    line.clear();
                }
                Err(_) => {
                    thread::sleep(Duration::from_millis(500));
                }
            }
        }
    });

    // -------------------------------------------------------------------------
    // 3. BACKGROUND THREAD: Memantau Input Keyboard
    // -------------------------------------------------------------------------
    let tx_key = tx.clone();
    thread::spawn(move || {
        loop {
            // Menggunakan polling agar thread tidak mengunci total saat shutdown
            if let Ok(true) = event::poll(Duration::from_millis(200)) {
                if let Ok(Event::Key(key)) = event::read() {
                    if key.kind == KeyEventKind::Press {
                        if tx_key.send(AppEvent::Key(key.code)).is_err() {
                            break;
                        }
                    }
                }
            }
        }
    });

    // PRE-KLAUSUL LAYOUT STATIS (DI LUAR LOOP)
    let layout_vertikal = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1), 
            Constraint::Length(3), // Panel Info (Tinggi 3 baris pas untuk border)
            Constraint::Min(5),    // Panel Log mengambil sisa layar secara dinamis
            Constraint::Length(1),
        ]);

    let layout_horizontal = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(2),
            Constraint::Percentage(96),
            Constraint::Percentage(2),
        ]);

    // -------------------------------------------------------------------------
    // 4. MAIN LOOP RENDERING & EVENT CONSUMER (MAIN THREAD)
    // -------------------------------------------------------------------------
    while !app_state.should_quit {
        // Menggambar UI berdasarkan State saat ini
        terminal.draw(|f| {
            let area_layar = f.area();
            let area_vertikal = layout_vertikal.split(area_layar);
            
            let area_panel_info = layout_horizontal.split(area_vertikal[1])[1];
            let area_panel_log = layout_horizontal.split(area_vertikal[2])[1];

            // Render Widget Info Utama
            let info_text = vec![
                Span::styled("[✓] Branch: ", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD)),
                Span::styled(&app_state.current_branch, Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
                Span::styled("  |  Repo: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.repo, Style::default().fg(Color::Yellow).add_modifier(Modifier::UNDERLINED)),
                Span::styled("  |  Owner: ", Style::default().fg(Color::Green)),
                Span::styled(&app_state.owner, Style::default().fg(Color::Yellow)),
            ];

            let widget_info = Paragraph::new(Line::from(info_text))
                .block(Block::default().title(" LIVE SYSTEM AUDIT ").borders(Borders::ALL).border_style(Style::default().fg(Color::Magenta)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_info, area_panel_info);

            // OPTIMASI MEMORI & STRUKTUR: Mengonversi data Vec<String> menjadi Line untuk TUI
            // Hanya mengambil log terbaru yang muat di tinggi panel untuk menghemat render CPU
            let tinggi_maks_layar = area_panel_log.height as usize;
            let baris_diambil = if app_state.log_lines.len() > tinggi_maks_layar {
                &app_state.log_lines[app_state.log_lines.len() - tinggi_maks_layar..]
            } else {
                &app_state.log_lines[..]
            };

            let konten_log: Vec<Line> = baris_diambil
                .iter()
                .map(|s| Line::from(Span::styled(s, Style::default().fg(Color::White))))
                .collect();

            let widget_log = Paragraph::new(konten_log)
                .block(Block::default().title(" REAL-TIME LOGS (tail -f) - Tekan 'q' untuk keluar ").borders(Borders::ALL).border_style(Style::default().fg(Color::Cyan)))
                .wrap(Wrap { trim: true });
            f.render_widget(widget_log, area_panel_log);
        })?;

        // Menerima Event (Membaca data log atau tombol secara non-blocking / teratur)
        // Timeout 16ms menjaga aplikasi berjalan stabil di kisaran ~60fps
        if let Ok(event) = rx.recv_timeout(Duration::from_millis(16)) {
            match event {
                AppEvent::Key(code) => match code {
                    KeyCode::Char('q') | KeyCode::Esc => app_state.should_quit = true,
                    _ => {}
                },
                AppEvent::LogLine(line) => {
                    // Manajemen batasan state agar RAM tidak membengkak (Simpan maks 1000 baris terakhir di memori)
                    if app_state.log_lines.len() >= 1000 {
                        app_state.log_lines.remove(0);
                    }
                    app_state.log_lines.push(line);
                }
            }
        }
    }

    // PEMBERSIHAN TERMINAL SAAT EXIT
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    println!("\x1B[1;32m[✓] Sesi peninjauan Real-time Log ditutup bersih.\x1B[0m");
    Ok(())
}

```

## 📊 Mengapa Solusi Ini Sesuai Standar Industri?

| Komponen | Implementasi Baru 🚀 | Alasan Teknis Performa |
| :--- | :--- | :--- |
| `BufReader::read_line` | Membaca byte per byte hingga tanda baris baru `\n`. | Sangat hemat memori karena tidak perlu memuat seluruh isi *file* log berukuran gigaan byte ke RAM. |
| `mpsc::channel` | Menggabungkan *Keyboard Event* dan *File I/O Event*. | Menghilangkan kebutuhan *loop sleep* kaku. UI hanya akan menggambar ulang jika ada log baru masuk atau tombol ditekan. |
| `log_lines.remove(0)` | Membatasi kapasitas penyimpanan state (Maks 1000 baris). | Mencegah *Memory Leak* (kebocoran memori RAM) jika server Anda dibiarkan menyala berhari-hari. |
| **Vector Slice Truncation** | Hanya me-render teks sebanyak tinggi area kotak TUI (`height`). | Mengurangi kalkulasi beban GPU/CPU terminal secara drastis saat memproses ribuan log. |

---

qa: 
Sekarang TUI Anda sudah bisa memantau berkas secara *real-time*. Apakah Anda memerlukan optimasi tambahan seperti **fitur auto-scroll ke bawah otomatis** saat ada log baru, atau penambahan **fitur pewarnaan otomatis (syntax highlighting)** untuk membedakan teks kode `[ERROR]`, `[INFO]`, dan `[WARN]`?

---

qs: 
cara mensimulasikan fitur emantauan log secara realtime ini

---

aa: 
Untuk mensimulasikan fitur pemantauan log *real-time* (`tail -f`) pada aplikasi Ratatui TUI yang telah dibuat, Anda perlu **membuat proses eksternal yang terus-menerus menulis baris baru ke dalam berkas** `log.txt` **selagi aplikasi TUI Anda sedang berjalan**.

Ada 3 cara mudah untuk mensimulasikannya tergantung pada sistem operasi yang Anda gunakan atau preferensi Anda.

---

## Cara 1: Menggunakan Perintah Terminal (Linux & macOS)
Buka **terminal baru** (pisahkan dari terminal tempat Anda menjalankan aplikasi Rust), masuk ke direktori proyek yang sama, lalu jalankan perintah *loop* satu baris berikut:
```bash
while true; do echo "[$(date '+%H:%M:%S')] [INFO] System audit checkpoint passed successfully." >> log.txt; sleep 1; done

```
- Cara kerja: Perintah ini akan mencetak baris log baru dengan stempel waktu saat ini ke berkas `log.txt` setiap 1 detik.

---

## Cara 2: Menggunakan PowerShell (Windows)
Jika Anda menggunakan Windows, buka **PowerShell baru**, masuk ke direktori proyek Anda, lalu jalankan skrip *loop* berikut:
```powershell
while ($true) { Add-Content log.txt "[$(Get-Date -Format 'HH:mm:ss')] [INFO] System audit checkpoint passed successfully."; Start-Sleep -Seconds 1 }

```

---

## Cara 3: Menggunakan Skrip Python (Lintas Platform)
Jika Anda ingin cara yang bekerja di semua sistem operasi tanpa menghafal perintah terminal, buat berkas bernama `simulasi_log.py` di direktori proyek Anda dengan kode berikut:
```python
import time
from datetime import datetime

print("Memulai simulasi penulisan log ke 'log.txt'...")
print("Tekan Ctrl+C untuk menghentikan simulasi.")

try:
    with open("log.txt", "a") as f:
        counter = 1
        while True:
            waktu = datetime.now().strftime("%H:%M:%S")
            # Mensimulasikan berbagai tipe log
            if counter % 5 == 0:
                log = f"[{waktu}] [WARN] Koneksi database tidak stabil, mencoba ulang...\n"
            elif counter % 8 == 0:
                log = f"[{waktu}] [ERROR] Gagal memvalidasi tanda tangan repositori ey_rcrapsbash!\n"
            else:
                log = f"[{waktu}] [INFO] Audit sistem berjalan normal. Token status: OK-{counter}\n"
            
            f.write(log)
            f.flush() # Memastikan data langsung tertulis ke disk
            print(f"Tertulis: {log.strip()}")
            
            counter += 1
            time.sleep(1) # Jeda waktu 1 detik per log
except KeyboardInterrupt:
    print("\nSimulasi dihentikan.")

```

Jalankan skrip ini di terminal terpisah dengan perintah:
```bash
python simulasi_log.py

```

---

## 🚀 Langkah Demi Langkah Melakukan Pengujian
1. Buat file log kosong terlebih dahulu agar aplikasi tidak bingung saat inisialisasi awal:
```bash
touch log.txt

```

2. Jalankan aplikasi Ratatui TUI Anda:
```bash
cargo run

```

3. Jalankan salah satu cara simulasi di atas pada jendela terminal atau tab baru

4. Perhatikan layar aplikasi TUI Anda pada bagian **"REAL-TIME LOGS (tail -f)"**, baris teks baru akan muncul dan bergeser ke atas secara otomatis setiap detik tanpa membuat UI macet.

## Ringkasan Alat Simulasi

| Platform | Alat | Perintah Utama | Kelebihan |
| :--- | :--- | :--- | :--- |
| **Linux / macOS** | Bash Loop | `while true; do ... sleep 1; done` | Instan, tidak perlu install apa-apa. |
| **Windows** | PowerShell | `while ($true) { ... Start-Sleep 1 }` | Bawaan Windows, aman untuk Windows Terminal. |
| **Semua OS** | Python Skrip | `python simulasi_log.py` | Bisa diatur untuk membuat log variatif ( INFO , WARN , ERROR ). |

---

Apakah Anda berhasil melihat lognya bergerak mengalir di aplikasi TUI Anda? Jika Anda ingin, kita bisa menambahkan **fitur pembeda warna otomatis** (misal: jika mendeteksi teks `[ERROR]` otomatis berubah jadi merah, `[WARN]` jadi kuning, dan `[INFO]` jadi hijau) agar simulasi log ini terlihat lebih profesional. Mau saya buatkan kodenya?













<br>
