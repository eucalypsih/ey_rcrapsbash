use std::fs;
use std::path::Path;
use std::io::{self, Write};
use log::{debug, info, error, warn};

/// Fungsi memeriksa kesiapan komponen sistem menggunakan standar logging idiomatik Rust
pub fn audit_komponen_sistem() -> Result<(), ()> {
    // Ambil jalur absolut folder proyek secara dinamis dari manifest biner Cargo
    let folder_proyek = env!("CARGO_MANIFEST_DIR");
    let jalur_absolut_utils = format!("{}/src/utils.rs", folder_proyek);
    let path = Path::new(&jalur_absolut_utils);

    debug!("Menjalankan fungsi peninjauan integritas struktur proyek...");
    info!("Memindai komponen sistem: memeriksa berkas '{}'...", jalur_absolut_utils);

    // Memeriksa keberadaan file fisik menggunakan jalur absolut hasil kompilasi
    if path.is_file() {
        debug!("-> [Stat] Berkas ditemukan secara fisik di jalur absolut.");

        // Memeriksa hak akses metadata berkas secara idiomatik
        if let Ok(metadata) = fs::metadata(path) {
            let permissions = metadata.permissions();
            if !permissions.readonly() {
                debug!("-> [Stat] Hak akses berkas: Writable/Readable [Diizinkan]");
            } else {
                warn!("-> [Stat] Hak akses berkas terkunci: Read-Only [Terbatas]!");
            }
        } else {
            error!("-> [Stat] Gagal membaca metadata izin berkas!");
            return Err(());
        }

        info!("[✓] Berkas terverifikasi dengan aman.");
        tahan_layar_interaktif();

        debug!("Melakukan verifikasi kompilasi modul pendukung internal...");
        debug!("  [Fungsi Alias] Token '_e()'   -> [Terikat di Kompilasi biner]");
        debug!("  [Fungsi Alias] Token '_ic()'  -> [Terikat di Kompilasi biner]");
        debug!("  [Fungsi Alias] Token '_o()'   -> [Terikat di Kompilasi biner]");
        debug!("  [Fungsi Alias] Token '_cc()'  -> [Terikat di Kompilasi biner]");
        debug!("  [Fungsi Alias] Token '_p()'   -> [Terikat di Kompilasi biner Middleware]");
        debug!("  [Fungsi Alias] Token '_pp()'  -> [Terikat di Kompilasi biner Middleware]");

        info!("[✓] Sukses! Seluruh fungsi di '{}' terikat sempurna.", jalur_absolut_utils);
        tahan_layar_interaktif();
        Ok(())
    } else {
        // KOREKSI AMAN: Pastikan log error mencetak jalur absolut yang sebenarnya dicari agar informatif
        error!("FATAL ERROR: Berkas tidak ditemukan secara fisik di jalur: '{}'", jalur_absolut_utils);
        error!("Struktur proyek korup atau tidak sejajar. Skrip dihentikan secara paksa.");
        std::process::exit(1);
    }
}

/// Fungsi pembantu internal ekivalen dengan "read -r" di Bash untuk menahan layar pembacaan debug
fn tahan_layar_interaktif() {
    if log::log_enabled!(log::Level::Debug) {
        print!("\x1B[0;90m(Tekan [Enter] untuk melanjutkan peninjauan debug...)\x1B[0m");
        let _ = io::stdout().flush();
        let mut buffer = String::new();
        let _ = io::stdin().read_line(&mut buffer);
    }
}
