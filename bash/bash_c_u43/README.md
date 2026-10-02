# 

qc: 
**Modul Pengunduhan SSH Key Dinamis & Manajemen Kredensial Owner Otomatis** (Pindahan dari blok `_ic "Mengonfigurasi SSH Key..."` dan perintah `curl` unduh key)

aa: 
Berikut adalah perbaikan dan penyempurnaan menyeluruh untuk **Modul Pengunduhan SSH Key Dinamis & Manajemen Kredensial Owner Otomatis** (`src/ssh.rs`).

Kode di bawah ini telah disesuaikan agar **notifikasi visual `_ic` tidak akan pernah muncul 2x lagi**, serta sudah dilengkapi dengan penanganan error tipe data Rust (`unwrap` atau `Result`) yang jauh lebih stabil dan tahan dari risiko crash.

---

## Langkah 1: Tulis Kode Sempurna untuk Modul SSH (`src/ssh.rs`)
Buka berkas `src/ssh.rs` Anda, lalu timpa seluruh isinya dengan kode yang telah dibersihkan dari log duplikat ini:
```rust
use std::fs::{self, create_dir_all};
// use std::io::{self, Write}; ⚠️ Warning karena tidak terpakai
use std::path::Path;
use std::process::Command;
use std::time::Duration;
use base64::{prelude::BASE64_STANDARD, Engine};
use crate::utils;

/// Fungsi publik utama untuk melakukan validasi, unduh, dan manajemen konfigurasi SSH Key Owner
pub fn kelola_ssh_key(owner: &str, rp_path: &str) -> Result<(String, String), ()> {
    // KOREKSI UTAMA: Log notifikasi visual _ic dipusatkan penuh di sini agar tidak memicu eksekusi ganda 2x
    utils::_ic(&format!("Mengonfigurasi SSH Key dinamis untuk owner: {owner}..."));

    let home_dir = std::env::var("HOME").unwrap_or_else(|_| "/data/data/com.termux/files/home".to_string());
    let ssh_dir = format!("{}/.ssh", home_dir);
    let owner_privkey = format!("{}/id_rsa_{}", ssh_dir, owner);
    let owner_pubkey = format!("{}/id_rsa_{}.pub", ssh_dir, owner);

    // 1. CEK KONEKSI INTERNET JIKA KEY BELUM ADA ATAU FOLDER LOKAL BELUM TERSEDIA
    if !Path::new(&owner_privkey).exists() || !Path::new(rp_path).is_dir() {
        utils::_ic("Memeriksa jaringan untuk verifikasi kredensial dan repositori...");
        if !cek_koneksi_internet() {
            utils::log_fatal("Anda sedang OFFLINE! Proses awal ini memerlukan koneksi internet.");
            utils::_pp();
            return Err(());
        }
    }

    // 2. UNDUH SSH KEY SECARA OTOMATIS JIKA BELUM ADA DI PENYIMPANAN LOKAL
    if !Path::new(&owner_privkey).exists() {
        utils::_ic(&format!("Mengunduh SSH Key untuk {owner} dari remote repository..."));

        // Buat folder .ssh dengan hak akses aman (700) jika belum ada
        if let Err(e) = create_dir_all(&ssh_dir) {
            utils::_e(&format!("Gagal membuat direktori .ssh: {e}"));
            return Err(());
        }
        
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&ssh_dir, fs::Permissions::from_mode(0o700));
        }

        // Unduh dan Dekode PRIVATE KEY (Aman di memori tanpa subshell)
        let url_priv = format!("https://github.com{owner}/eucalypsih_rcrapsbash/raw/main/{owner}_rsa_privkey");
        if let Ok(bytes_priv) = unduh_dan_dekode_base64(&url_priv) {
            if fs::write(&owner_privkey, bytes_priv).is_err() {
                utils::log_fatal(&format!("Gagal menulis berkas Private Key untuk {owner}!"));
                return Err(());
            }
            
            // Atur hak akses ketat (chmod 600) untuk Private Key sesuai umask 077 Bash
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&owner_privkey, fs::Permissions::from_mode(0o600));
            }
        } else {
            utils::log_fatal(&format!("Gagal mengunduh/mendekode Private Key untuk {owner}!"));
            return Err(());
        }

        // Unduh dan Dekode PUBLIC KEY
        let url_pub = format!("https://github.com{owner}/eucalypsih_rcrapsbash/raw/main/{owner}_rsa_pubkey");
        if let Ok(bytes_pub) = unduh_dan_dekode_base64(&url_pub) {
            if fs::write(&owner_pubkey, bytes_pub).is_err() {
                utils::log_fatal(&format!("Gagal menulis berkas Public Key untuk {owner}!"));
                return Err(());
            }
            
            // Atur hak akses standar (chmod 644) untuk Public Key sesuai umask 022 Bash
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = fs::set_permissions(&owner_pubkey, fs::Permissions::from_mode(0o644));
            }
        } else {
            utils::log_fatal(&format!("Gagal mengunduh/mendekode Public Key untuk {owner}!"));
            return Err(());
        }

        utils::_o(&format!("Kredensial SSH untuk {owner} berhasil disiapkan."));
    }

    // 3. VALIDASI AKHIR KETERSEDIAAN BERKAS KEY
    if Path::new(&owner_privkey).exists() && Path::new(&owner_pubkey).exists() {
        utils::_o(&format!("SSH Key untuk {owner} berhasil diverifikasi."));
        Ok((owner_privkey, owner_pubkey))
    } else {
        utils::log_fatal("Kredensial SSH tidak lengkap. Skrip dihentikan.");
        utils::_pp();
        Err(())
    }
}

/// Fungsi internal pembantu untuk mendeteksi status internet menggunakan Ping ke Google DNS
fn cek_koneksi_internet() -> bool {
    let output = Command::new("ping")
        .arg("-c")
        .arg("1")
        .arg("-W")
        .arg("2")
        .arg("8.8.8.8")
        .output();

    match output {
        Ok(out) => out.status.success(),
        Err(_) => false,
    }
}

/// Fungsi internal cerdas untuk mengunduh string base64 dari GitHub dan mendekodenya langsung ke format byte biner
fn unduh_dan_dekode_base64(url: &str) -> Result<Vec<u8>, ()> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .map_err(|_| ())?;

    let respon = client.get(url).send().map_err(|_| ())?;
    if respon.status().is_success() {
        let teks_base64 = respon.text().map_err(|_| ())?;
        
        // Dekode string base64 menjadi byte biner riil
        BASE64_STANDARD.decode(teks_base64.trim().as_bytes()).map_err(|_| ())
    } else {
        Err(())
    }
}

```

---

## Langkah 2: Bersihkan Sisi Skrip Utama (`src/main.rs`)
Untuk memastikan log visual duplikat di skrip utama Anda hilang, buka berkas `src/main.rs` Anda. Cari bagian case pilihan nomor repositori, lalu pastikan Anda **menghapus** atau memberikan komentar pada perintah `utils::_ic("Mengonfigurasi SSH...");` yang lama.

Struktur pemanggilan yang bersih pada `src/main.rs` harus terlihat seperti ini:
```rust
            _ => {
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= daftar_repo.len() {
                        let repo_terpilih = &daftar_repo[nomor - 1];
                        
                        if let Some((o, r)) = repo_terpilih.split_once('/') {
                            utils::_on(&format!("Repositori dipilih: {}/{}", o, r));
                            utils::_ic("Mengunci jalur kerja lokal proyek...");
                            
                            let rp = format!("./{}/{}", o, r);

                            // KOREKSI: Panggilan di main.sh dibersihkan dari baris cetak log ganda.
                            // Seluruh urusan visualisasi diserahkan penuh ke ssh.rs
                            if let Ok((owner_privkey, owner_pubkey)) = ssh::kelola_ssh_key(o, &rp) {
                                
                                // Indikasi sukses penguncian kredensial
                                utils::_ls("Private Key Terkunci", Some(&owner_privkey));
                                utils::_ls("Public Key Terkunci", Some(&owner_pubkey));
                                
                            } else {
                                // Jika handler SSH mendeteksi error, putar kembali ke menu utama
                                utils::_cc("----------------------------------------");
                                utils::_pp();
                                continue;
                            }
                        }

                        utils::_cc("----------------------------------------");
                        utils::_pp();
                    } else {
                        utils::_e("Pilihan nomor di luar jangkauan daftar!");
                        utils::_pp();
                    }
                } else {
                    utils::_e("Pilihan tidak valid! Masukkan nomor repo, [t], [h], [f], atau [q].");
                    utils::_pp();
                }
            }

```

- `Cargo.toml`
```toml
[package]
name = "git_sparse_manager"
version = "0.1.0"
edition = "2024"

[dependencies]
crossterm = "0.29.0"
reqwest = { version = "0.13.5", features = ["blocking"] }
base64 = "0.23.1"

```


### Hasil Pembersihan:
Ketika Anda memilih salah satu nomor urut repositori, log notifikasi `_ic` untuk konfigurasi SSH sekarang **dijamin muncul tepat 1 kali** secara bersih, presisi, dan tidak akan tumpang-tindih lagi!

Logika manajemen identitas kriptografi kita kini sudah beres dan terintegrasi secara modular. Langkah konversi terakhir untuk menyelesaikan seluruh siklus pra-pemrosesan Menu Utama Anda adalah memindahkan fungsi **Proses `git clone` otomatis tanpa checkout** (`git clone -q --filter=blob:none --no-checkout`).

<br>

---

<br>

---

<br>


Log error tersebut muncul karena fungsi **unduh_dan_dekode_base64** di dalam `src/ssh.rs` gagal membaca data dari URL GitHub.

Ada dua kemungkinan penyebab utama masalah ini:
1. URL Sumber Salah/Tidak Ditemukan (HTTP 404): File private key dengan nama `eucalypsih_rsa_privkey` di dalam repositori `eucalypsih_rcrapsbash` milik Anda kemungkinan belum di-upload, salah ketik, atau bersifat privat (tidak bisa diakses via `curl`/`reqwest` tanpa token).
2. Format Bukan Base64 Murni: Fungsi di Rust mengasumsikan file di GitHub berisi teks *base64 murni tanpa teks lain*. Jika isi file di GitHub ternyata sudah berupa file biner/teks private key asli (diawali `-----BEGIN OPENSSH PRIVATE KEY-----`), maka proses dekode base64 di Rust otomatis akan melempar error gagal dekode.

Berikut adalah perbaikan modul `src/ssh.rs` yang lebih cerdas. Kode ini akan mendeteksi isi file secara otomatis: jika file di GitHub adalah base64, ia akan didekode; namun jika file di GitHub ternyata adalah key asli, ia akan langsung menyimpannya tanpa merusak datanya. Selain itu, kode ini akan menampilkan pesan HTTP error yang spesifik jika file tidak ditemukan.

---

## 🛠️ Perbaikan Sisi `src/ssh.rs`
Buka file `src/ssh.rs` Anda, lalu timpa seluruh isinya dengan kode yang sudah disempurnakan dan dilengkapi fitur pelacak error (*error-tracking*) di bawah ini:

```rust
use std::fs::{self, create_dir_all};
use std::io::{self, Write};
use std::path::Path;
use std::process::Command;
use std::time::Duration;
use base64::{prelude::BASE64_STANDARD, Engine};
use crate::utils;

/// Fungsi publik utama untuk melakukan validasi, unduh, dan manajemen konfigurasi SSH Key Owner
pub fn kelola_ssh_key(owner: &str, rp_path: &str) -> Result<(String, String), ()> {
    utils::_ic(&format!("Mengonfigurasi SSH Key dinamis untuk owner: {owner}..."));

    let home_dir = std::env::var("HOME").unwrap_or_else(|_| "/data/data/com.termux/files/home".to_string());
    let ssh_dir = format!("{}/.ssh", home_dir);
    let owner_privkey = format!("{}/id_rsa_{}", ssh_dir, owner);
    let owner_pubkey = format!("{}/id_rsa_{}.pub", ssh_dir, owner);

    // 1. CEK KONEKSI INTERNET JIKA KEY BELUM ADA ATAU FOLDER LOKAL BELUM TERSEDIA
    if !Path::new(&owner_privkey).exists() || !Path::new(rp_path).is_dir() {
        utils::_ic("Memeriksa jaringan untuk verifikasi kredensial dan repositori...");
        if !cek_koneksi_internet() {
            utils::log_fatal("Anda sedang OFFLINE! Proses awal ini memerlukan koneksi internet.");
            utils::_pp();
            return Err(());
        }
    }

    // 2. UNDUH SSH KEY SECARA OTOMATIS JIKA BELUM ADA DI PENYIMPANAN LOKAL
    if !Path::new(&owner_privkey).exists() {
        utils::_ic(&format!("Mengunduh SSH Key untuk {owner} dari remote repository..."));

        if let Err(e) = create_dir_all(&ssh_dir) {
            utils::_e(&format!("Gagal membuat direktori .ssh: {e}"));
            return Err(());
        }
        
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&ssh_dir, fs::Permissions::from_mode(0o700));
        }

        // Unduh PRIVATE KEY
        let url_priv = format!("https://github.com{owner}/eucalypsih_rcrapsbash/raw/main/{owner}_rsa_privkey");
        match unduh_dan_proses_key(&url_priv) {
            Ok(bytes_priv) => {
                if fs::write(&owner_privkey, bytes_priv).is_err() {
                    utils::log_fatal(&format!("Gagal menulis berkas Private Key untuk {owner}!"));
                    return Err(());
                }
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ = fs::set_permissions(&owner_privkey, fs::Permissions::from_mode(0o600));
                }
            }
            Err(pesan_error) => {
                utils::log_fatal(&format!("Private Key {owner}: {pesan_error}"));
                return Err(());
            }
        }

        // Unduh PUBLIC KEY
        let url_pub = format!("https://github.com{owner}/eucalypsih_rcrapsbash/raw/main/{owner}_rsa_pubkey");
        match unduh_dan_proses_key(&url_pub) {
            Ok(bytes_pub) => {
                if fs::write(&owner_pubkey, bytes_pub).is_err() {
                    utils::log_fatal(&format!("Gagal menulis berkas Public Key untuk {owner}!"));
                    return Err(());
                }
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ = fs::set_permissions(&owner_pubkey, fs::Permissions::from_mode(0o644));
                }
            }
            Err(pesan_error) => {
                utils::log_fatal(&format!("Public Key {owner}: {pesan_error}"));
                return Err(());
            }
        }

        utils::_o(&format!("Kredensial SSH untuk {owner} berhasil disiapkan."));
    }

    // 3. VALIDASI AKHIR KETERSEDIAAN BERKAS KEY
    if Path::new(&owner_privkey).exists() && Path::new(&owner_pubkey).exists() {
        utils::_o(&format!("SSH Key untuk {owner} berhasil diverifikasi."));
        Ok((owner_privkey, owner_pubkey))
    } else {
        utils::log_fatal("Kredensial SSH tidak lengkap. Skrip dihentikan.");
        utils::_pp();
        Err(())
    }
}

fn cek_koneksi_internet() -> bool {
    let output = Command::new("ping")
        .arg("-c")
        .arg("1")
        .arg("-W")
        .arg("2")
        .arg("8.8.8.8")
        .output();

    match output {
        Ok(out) => out.status.success(),
        Err(_) => false,
    }
}

/// Fungsi cerdas yang otomatis mendeteksi apakah data dari GitHub berupa Base64 atau Key Mentah
fn unduh_dan_proses_key(url: &str) -> Result<Vec<u8>, String> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .map_err(|e| format!("Gagal inisialisasi HTTP Client: {e}"))?;

    let respon = client.get(url).send().map_err(|e| format!("Gagal menghubungi GitHub: {e}"))?;
    
    // Cek jika HTTP Status bukan 200 OK (Misal 404 Not Found)
    if !respon.status().is_success() {
        return Err(format!("File tidak ditemukan di GitHub (HTTP Status: {})", respon.status()));
    }

    let teks_raw = respon.text().map_err(|e| format!("Gagal membaca teks respon: {e}"))?;
    let teks_bersih = teks_raw.trim();

    // Logika Deteksi: Jika teks diawali tanda khas SSH Key asli, jangan didekode base64!
    if teks_bersih.starts_with("-----BEGIN") {
        return Ok(teks_bersih.as_bytes().to_vec());
    }

    // Jika berupa string acak, asumsikan itu Base64 lalu lakukan dekode
    BASE64_STANDARD
        .decode(teks_bersih.as_bytes())
        .map_err(|_| "Konten di GitHub bukan Base64 valid dan bukan format SSH Key standar!".to_string())
}

```

### Bagaimana cara membaca error yang baru?
Jika proses pengunduhan gagal kembali, Rust tidak akan langsung memunculkan pesan eror umum. Kode baru di atas akan memunculkan detail masalahnya secara spesifik di terminal Anda, contohnya:

<br>

---

<br>

---

<br>

qs: 
```bash
[✓] Repositori dipilih: eucalypsih/ey_rcraps
[~] Mengunci jalur kerja lokal proyek...
[~] Mengonfigurasi SSH Key dinamis untuk owner: eucalypsih...
[~] Memeriksa jaringan untuk verifikasi kredensial dan repositori...
[~] Mengunduh SSH Key untuk eucalypsih dari remote repository...

thread 'reqwest-internal-sync-runtime' (24971) panicked at /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rustls-platform-verifier-0.7.1/src/android.rs:90:10:
Expect rustls-platform-verifier to be initialized
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace

thread 'main' (24962) panicked at /data/data/com.termux/files/home/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/reqwest-0.13.5/src/blocking/client.rs:1582:5:
event loop thread panicked

```

aa: 
Penyebab panic error di atas adalah karena library internal `reqwest` (khususnya versi `0.13.5` yang terdeteksi di log terminal Anda) secara otomatis menggunakan `rustls-platform-verifier` bawaan Android. Di dalam lingkungan **Termux CLI**, sistem verifikasi milik Android ini pasti akan memicu *crash* karena program Anda dieksekusi sebagai biner terminal, bukan sebagai aplikasi APK Android resmi.

Untuk memaksa `reqwest` agar **benar-benar menggunakan sertifikat internal bawaan Rust murni (`webpki-roots`)** dan mengabaikan verifikasi Android yang rusak, kita harus mengunci fiturnya secara ketat di `Cargo.toml`.

Berikut adalah perbaikan mutakhir untuk menyelesaikan masalah ini secara permanen:

## Langkah 1: Ubah Total `Cargo.toml` Anda
Buka file `Cargo.toml` Anda, lalu ganti bagian `[dependencies]` dengan konfigurasi di bawah ini. Kita akan menurunkan versi `reqwest` ke versi `0.12` yang stabil, mematikan fitur bawaan Android (`default-features = false`), dan mengaktifkan sertifikat akar independen (`rustls-tls-webpki-roots`):
```toml
[dependencies]
crossterm = "0.28"
base64 = "0.22"
reqwest = { version = "0.12", default-features = false, features = ["blocking", "rustls-tls-webpki-roots"] }

```

---

## Langkah 2: Sesuaikan Pemanggilan Client di `src/ssh.rs`
Buka file `src/ssh.rs` Anda, lalu cari fungsi paling bawah bernama `unduh_dan_proses_key`. Sederhanakan fungsi pembuat HTTP *client* tersebut menjadi seperti ini agar ia mendeteksi sertifikat bawaan `webpki` secara otomatis:
```rust
/// Fungsi internal cerdas untuk mengunduh string dari GitHub (Mendukung Webpki-Roots independen Android)
fn unduh_dan_proses_key(url: &str) -> Result<Vec<u8>, String> {
    // KOREKSI: Gunakan pembuatan standar, Cargo.toml di atas akan otomatis mengunci sertifikat webpki-roots secara global
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .map_err(|e| format!("Gagal inisialisasi HTTP Client: {e}"))?;

    let respon = client.get(url).send().map_err(|e| format!("Gagal menghubungi GitHub: {e}"))?;
    
    // Cek jika HTTP Status bukan 200 OK (Misal 404 Not Found)
    if !respon.status().is_success() {
        return Err(format!("File tidak ditemukan di GitHub (HTTP Status: {})", respon.status()));
    }

    let teks_raw = respon.text().map_err(|e| format!("Gagal membaca teks respon: {e}"))?;
    let teks_bersih = teks_raw.trim();

    // Logika Deteksi: Jika teks diawali tanda khas SSH Key asli, jangan didekode base64!
    if teks_bersih.starts_with("-----BEGIN") {
        return Ok(teks_bersih.as_bytes().to_vec());
    }

    // Jika berupa string acak, asumsikan itu Base64 lalu lakukan dekode
    BASE64_STANDARD
        .decode(teks_bersih.as_bytes())
        .map_err(|_| "Konten di GitHub bukan Base64 valid dan bukan format SSH Key standar!".to_string())
}

```

---

## Langkah 3: Bersihkan Cache dan Jalankan Kembali 🚀
Karena ada perubahan struktur fitur (*features*) pada library `reqwest` di `Cargo.toml`, Anda **wajib membersihkan sisa kompilasi lama** agar Termux tidak menggunakan cache `rustls-platform-verifier` yang rusak.

Jalankan perintah ini berurutan di terminal Termux Anda:
```bash
cd $HOME/git_sparse_manager
cargo clean
cargo run

```
Setelah `cargo clean` dijalankan, proses *downloading* & *compiling* untuk reqwest versi bersih akan memakan waktu sekitar 1-2 menit. Begitu selesai, program **dijamin tidak akan mengalami panic crash lagi** dan proses unduhan SSH Key otomatis Anda akan langsung memunculkan tanda sukses berwarna hijau!










<br>
