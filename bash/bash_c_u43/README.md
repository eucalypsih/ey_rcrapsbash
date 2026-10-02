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
use std::io;  // (Hapus {self, Write})
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
