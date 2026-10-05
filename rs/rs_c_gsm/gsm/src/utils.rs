use crossterm::style::Stylize;
use std::io::{self, Write};

// --- FUNGSI PRINTING STANDAR ---
pub fn _o(text: &str) {
    println!("{}", format!("[✓] {text}").green());
}

pub fn _on(text: &str) {
    println!();
    _o(text);
}

pub fn _ic(text: &str) {
    println!("{}", format!("[~] {text}").cyan());
}

pub fn _nc(text: &str) {
    println!("\n{}", text.cyan());
}

pub fn _in(text: &str) {
    println!("\n{}", format!("[~] {text}").cyan());
}

pub fn _cc(text: &str) {
    println!("{}", text.cyan());
}


pub fn _c(text: &str) {
    println!("{}", format!("[+] {text}").yellow());
}

// Tambahkan baris ini tepat di atas fungsi log_notify
#[allow(dead_code)]
pub fn log_notify(text: &str) {
    println!("\n{}", format!("[+] {text}").yellow());
}

pub fn _r(text: &str) {
    println!("{}", format!("[!] {text}").yellow());
}

pub fn _rn(text: &str) {
    println!("\n{}", format!("[!] {text}").yellow());
}

pub fn _w(text: &str) {
    println!("{}", format!("[ ⚠️ ] Peringatan: {text}").yellow().bold());
}

pub fn _hn(text: &str) {
    println!("\n{}", format!("[!] {text}").red());
}

pub fn _e(text: &str) {
    println!("{}", format!("[X] ERROR: {text}").red());
}

// Tambahkan baris ini tepat di atas fungsi log_notify
#[allow(dead_code)]
pub fn log_detail(text: &str) {
    println!("{}", format!("     -> {text}").yellow());
}

pub fn _a(text: &str) {
    println!("{}", format!("[X] {text}").red());
}

pub fn _an(text: &str) {
    println!("\n{}", format!("[X] {text}").red());
}

// --- FUNGSI DENGAN LOGIKA INTERNAL (SUKSES) ---
pub fn _ls(label: &str, value: Option<&str>) {
    match value {
        // Some(val) => println!("{}", format!("[✓] {label}: ").green() + &val.yellow().to_string()), // ❌ Ilegal di Rust
        // KOREKSI: Gunakan makro format!() agar penggabungan warna aman dan legal di Rust
        Some(val) => println!("{}", format!("{} {}", format!("[✓] {label}:").green(), val.yellow())),
        None => println!("{}", format!("[✓] Sukses: {label}").green()),
    }
}

// --- FUNGSI PROMPT/INPUT (WAITING USER INPUT) ---
pub fn _p(prompt_text: &str, example: Option<&str>) {
    match example {
        // Some(ex) => print!("{}", format!("[~] {prompt_text}").yellow() + &ex.green().to_string() + &") ".yellow().to_string()),
        // KOREKSI MUTAKHIR: Menggabungkan prompt kuning, teks contoh hijau, dan tanda tutup kurung kuning menggunakan format!() // ❌ Ilegal di Rust
        Some(ex) => print!("{}", format!("{}{}{}", format!("[~] {prompt_text} (").yellow(), ex.green(), ") ".yellow())),
        None => print!("{}", format!("[~] {prompt_text}: ").yellow()),
    }
    let _ = io::stdout().flush(); // Paksa terminal cetak teks tanpa nunggu baris baru (seperti read -p di Bash)
}

pub fn _pd(danger_text: &str) {
    print!("{}", format!("[⚠️] {danger_text} (y/n): ").red().bold());
    let _ = io::stdout().flush();
}

pub fn _pp() {
    print!("{}", "Tekan [Enter] untuk kembali...".yellow());
    let _ = io::stdout().flush();
    let mut buffer = String::new();
    let _ = io::stdin().read_line(&mut buffer); // Menahan layar seperti read -r di Bash
}
