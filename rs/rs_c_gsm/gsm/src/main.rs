mod utils; // Menghubungkan file utils.rs
mod verbose_init; // 1. Daftarkan modul verbose idiomatik

fn main() {
    // 2. INISIALISASI LOGGER STANDAR INDUSTRI (env_logger)
    // Fungsi ini akan membaca variabel RUST_LOG dari terminal luar perangkat Anda
    env_logger::init();

    // 3. Jalankan audit kesehatan komponen sistem secara verbose
    let _ = verbose_init::audit_komponen_sistem();    // Bersihkan layar terminal ala Rust (menggunakan ANSI Escape Code)

    print!("\x1B[2J\x1B[1;1H");

    utils::_cc("========================================");
    utils::_cc("   UJI COBA MODUL UTILS VERSI RUST      ");
    utils::_cc("========================================");

    utils::_o("Sistem warna berhasil dikonversi!");
    utils::_w("Ini adalah contoh visual peringatan.");
    utils::_e("Ini adalah contoh jika ada proses error.");
    
    utils::_ls("Branch saat ini terdeteksi", Some("main"));
    
    utils::_cc("----------------------------------------");
    utils::_pp(); // Menahan layar terminal
}
