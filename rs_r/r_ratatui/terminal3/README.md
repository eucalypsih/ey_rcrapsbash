# 

qc: 
ingin dibuatkan juga struktur fungsi `run_app` (Main Loop) untuk menangani *keyboard event* (seperti mendeteksi tombol `Esc` atau `q` untuk keluar)

---

aa: 
Berikut adalah struktur fungsi `run_app` (Main Loop) yang terstruktur, aman, dan menggunakan tipe data eksplisit murni sesuai standar industri Rust.

Fungsi ini mendengarkan *keyboard event* menggunakan `crossterm::event::read` dan akan langsung keluar dengan aman jika mendeteksi tombol `q` atau `Esc`.
```rust
use std::io::Stdout;
use std::time::Duration;
use crossterm::event::{
    self,
    Event,
    KeyCode,
    KeyEventKind
};
use ratatui::{
    backend::CrosstermBackend,
    Terminal
};

/// Fungsi Main Loop untuk menjalankan logika aplikasi dan menangani event keyboard.
pub fn run_app(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> Result<(), std::io::Error> {
    loop {
        // 1. Gambar antarmuka pengguna (UI) pada setiap perulangan
        terminal.draw(|_f| {
            // Logika penggambaran UI Anda diletakkan di sini
            // Contoh membuat blok sederhana:
            // let size = f.area();
            // f.render_widget(ratatui::widgets::Paragraph::new("Halo Dunia! Tekan 'q' atau 'Esc' untuk keluar."), size);
        })?;

        // 2. Periksa apakah ada event yang masuk (blocking/menunggu event)
        // Jika ingin menambahkan timeout agar loop berjalan periodik, gunakan event::poll(Duration::from_millis(16))?
        if event::poll(Duration::from_millis(100))? {
            // 3. Baca event yang tersedia
            if let Event::Key(key) = event::read()? {
                // Di Windows/beberapa terminal, pastikan hanya memproses event bertipe Press (bukan Release/Repeat)
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        // Keluar jika menekan tombol 'q' atau 'Esc'
                        KeyCode::Char('q') | KeyCode::Esc => {
                            return Ok(());
                        }
                        // Tambahkan penanganan tombol lainnya di sini
                        // KeyCode::Up => { /* Logika arah atas */ }
                        _ => {}
                    }
                }
            }
        }
    }
}

```

## Integrasi Lengkap pada Fungsi `main`
Berikut adalah cara Anda menggabungkan fungsi `setup_terminal`, `run_app`, dan `restore_terminal` secara utuh di fungsi `main`:
```rust
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Inisialisasi terminal
    let mut terminal = setup_terminal()?;

    // 2. Jalankan aplikasi utama
    let app_result = run_app(&mut terminal);

    // 3. Pastikan terminal SELALU dipulihkan kembali ke normal, 
    // bahkan jika aplikasi run_app menghasilkan error di tengah jalan.
    restore_terminal(terminal)?;

    // 4. Jika ada error saat aplikasi berjalan, lemparkan ke atas setelah terminal pulih
    app_result?;

    Ok(())
}

```

---

qa: 
Apakah Anda membutuhkan contoh bagaimana membuat komponen **UI sederhana** di dalam blok `terminal.draw`, seperti membuat layout panel (*layout split*) atau kotak input teks?





















<br>
