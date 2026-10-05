
```rust
pub fn _pp() {
    print!("{}", "Tekan [Enter] untuk kembali...".yellow());
    let _ = io::stdout().flush();
    let mut buffer = String::new();
    let _ = io::stdin().read_line(&mut buffer); // Menahan layar seperti read -r di Bash
}

```

---

---

```toml
[package]
name = "gsm"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.28"
log = "0.4"           # Facade logging standar Rust
env_logger = "0.11"   # Logger terminal berbasis environment variable

```

```rust
use std::io::{self, Write};
use log::debug;

/// Fungsi pembantu internal ekivalen dengan "read -r" di Bash untuk menahan layar pembacaan debug
fn tahan_layar_interaktif() {
    if log::log_enabled!(log::Level::Debug) {
        print!("\x1B[0;90m(Tekan [Enter] untuk melanjutkan peninjauan debug...)\x1B[0m");
        let _ = io::stdout().flush();
        let mut buffer = String::new();
        let _ = io::stdin().read_line(&mut buffer);
    }
}

```

```rust
use std::io::{self, Write};
use log::{debug, info, error, warn};

// 1. TAMBAHKAN IMPORT CROSTERM INI DI ATAS BERKAS src/verbose_init.rs
use crossterm::{
    execute,
    style::{Color, Print, ResetColor, SetForegroundColor},
};

// ... (Sisa fungsi audit_komponen_sistem biarkan tetap utuh seperti sebelumnya) ...

/// Fungsi pembantu internal ekivalen dengan "read -r" di Bash menggunakan gaya Crossterm
fn tahan_layar_interaktif() {
    if log::log_enabled!(log::Level::Debug) {
        // 2. MODIFIKASI GAYA MENGGUNAKAN CROSTERM
        // Mengatur warna teks menjadi abu-abu gelap (Grey / DarkGrey) dan mencetak teks instruksi
        let mut stdout = io::stdout();
        let _ = execute!(
            stdout,
            SetForegroundColor(Color::Grey), // Set warna abu-abu
            Print("(Tekan [Enter] untuk melanjutkan peninjauan debug...)"),
            ResetColor // Kembalikan warna terminal ke default
        );
        let _ = stdout.flush();

        // Tahan layar hingga user menekan tombol Enter
        let mut buffer = String::new();
        let _ = io::stdin().read_line(&mut buffer);
    }
}

```
