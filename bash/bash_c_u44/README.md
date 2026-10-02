# 

aa: 
Mari kita kembali ke proyek **Rust**! Sekarang kita akan masuk ke tahap **Modul proses `git clone` otomatis tanpa checkout** (`git clone -q --filter=blob:none --no-checkout`).

Di dalam skrip Bash lama Anda, bagian ini bertugas untuk membuat folder induk *owner* (`mkdir -p`), lalu melakukan proses *blobless clone* secara senyap (`-q`) dengan menyuntikkan konfigurasi SSH kustom via `-c core.sshCommand` agar menggunakan Private Key spesifik milik *owner* repositori tersebut.

Di dalam bahasa Rust, kita akan membuat modul baru bernama `src/clone.rs`. Kita akan memanfaatkan library bawaan `std::process::Command` untuk memicu biner Git eksternal secara aman, presisi, dan terhindar dari masalah celah keamanan argumen (*command injection*).

---

## Langkah 1: Buat Modul Clone Handler (`src/clone.rs`)
Buat berkas baru bernama `clone.rs` di dalam folder `src/`. Salin seluruh kode arsitektur kloning biner di bawah ini ke dalam berkas tersebut:
```rust
use std::fs::create_dir_all;
use std::path::Path;
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk mengeksekusi git clone blobless tanpa checkout secara otomatis
pub fn eksekusi_clone(
    owner: &str,
    repo_name: &str,
    rp_path: &str,
    owner_privkey: &str,
) -> Result<(), ()> {
    let path_target = Path::new(rp_path);

    // Pengaman awal: Hanya lakukan clone jika folder repositori lokal belum ada fisik
    if !path_target.exists() {
        utils::_ic("Memeriksa jaringan sebelum melakukan kloning repositori...");

        // Verifikasi status koneksi internet via Google DNS ping
        if !cek_koneksi_internet() {
            utils::log_fatal("Anda sedang OFFLINE! Kloning awal repositori baru memerlukan koneksi internet.");
            utils::_a("Skrip dihentikan. Silakan aktifkan koneksi internet Anda terlebih dahulu.");
            utils::_pp();
            return Err(());
        }

        utils::_o("Koneksi terverifikasi. Mengkloning repositori...");

        // Membuat folder induk (owner) secara aman sebelum eksekusi clone (mkdir -p)
        if let Some(parent_dir) = path_target.parent() {
            if let Err(e) = create_dir_all(parent_dir) {
                utils::_e(&format!("Gagal membuat folder induk owner: {e}"));
                return Err(());
            }
        }

        utils::_ic(&format!("Mengkloning repositori ke {rp_path} menggunakan key {owner}..."));

        // Mengunci konfigurasi perintah kustom SSH command secara spesifik
        let ssh_command_arg = format!("core.sshCommand=ssh -i {owner_privkey} -o IdentitiesOnly=yes");
        let remote_url = format!("git@github.com:{}/{}.git", owner, repo_name);

        // Eksekusi Biner Git: git clone -q --filter=blob:none --no-checkout -c core.sshCommand=...
        let status_git = Command::new("git")
            .arg("clone")
            .arg("-q")
            .arg("--filter=blob:none")
            .arg("--no-checkout")
            .arg("-c")
            .arg(&ssh_command_arg)
            .arg(&remote_url)
            .arg(rp_path)
            .status();

        match status_git {
            Ok(status) if status.success() => {
                utils::_o("Kloning berhasil dilakukan.");
                // Berikan jeda visual cepat seperti sleep 0.5 di Bash
                std::thread::sleep(std::time::Duration::from_millis(500));
                Ok(())
            }
            _ => {
                utils::log_fatal("Gagal melakukan git clone! Periksa koneksi internet atau validitas SSH Key Anda.");
                utils::_pp();
                Err(())
            }
        }
    } else {
        // Jika folder sudah ada, lewati proses clone secara aman
        Ok(())
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

```

---

## Langkah 2: Hubungkan Modul Baru di `src/main.rs`
Buka kembali berkas utama `src/main.rs` Anda. Kita perlu mendaftarkan `mod clone;` di bagian paling atas dan meletakkannya tepat di bawah blok sukses pengecekan SSH Key Modul sebelumnya.

Ubah isi `src/main.rs` Anda menjadi struktur lengkap berikut:
```rust
use std::io::{self, Write};
mod utils; 
mod repo;  
mod t;     
mod h;     
mod f;     
mod ssh;   
mod clone; // 1. Daftarkan modul clone.rs baru yang baru dirakit

fn main() {
    repo::pastikan_file_repo_ada();

    loop {
        print!("\x1B[2J\x1B[1;1H");
        let _ = io::stdout().flush();

        utils::_cc("========================================");
        utils::_cc("       PILIH REPOSITORI UTAMA           ");
        utils::_cc("========================================");
        utils::log_section("Daftar Repositori Terpantau (Format: owner/repo):");

        let daftar_repo = repo::baca_dan_parse_repo();

        if daftar_repo.is_empty() {
            utils::_e("File database 'rp.txt' kosong! Silakan isi nama repositori.");
        } else {
            for (i, repo_name) in daftar_repo.iter().enumerate() {
                let mut status_str = " \x1B[32m[ daftar aktif ]\x1B[0m".to_string();
                if repo::cek_lokal_aktif(repo_name) {
                    status_str.push_str(" \x1B[36m[ lokal aktif ]\x1B[0m");
                }
                println!(" [{}] {}{}", i + 1, format!("{:<30}", repo_name), status_str);
            }
        }

        utils::_cc("----------------------------------------");
        println!(" [t] \x1B[32mTambah Repositori Baru\x1B[0m");
        println!(" [h] \x1B[31mHapus Repo dari Daftar rp.txt\x1B[0m");
        println!(" [f] \x1B[33mHanya Hapus Folder Fisik Lokal\x1B[0m");
        println!(" [q] \x1B[31mKeluar dari Skrip\x1B[0m");
        utils::_cc("========================================");
        
        utils::_p("Masukkan pilihan Anda", None);
        
        let mut repo_pilihan = String::new();
        if io::stdin().read_line(&mut repo_pilihan).is_err() {
            utils::_e("Gagal membaca input terminal!");
            continue;
        }
        
        let pilihan_bersih = repo_pilihan.trim();

        match pilihan_bersih {
            "q" | "Q" => {
                utils::_an("Proses dibatalkan. Keluar dari skrip.");
                std::process::exit(0);
            }
            "t" | "T" => {
                t::jalankan_tambah_repo(repo::REPO_FILE, daftar_repo);
            }
            "h" | "H" => {
                h::jalankan_hapus_repo(repo::REPO_FILE, daftar_repo);
            }
            "f" | "F" => {
                f::jalankan_purge_folder(daftar_repo);
            }
            _ => {
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= daftar_repo.len() {
                        let repo_terpilih = &daftar_repo[nomor - 1];
                        
                        if let Some((o, r)) = repo_terpilih.split_once('/') {
                            utils::_on(&format!("Repositori dipilih: {}/{}", o, r));
                            utils::_ic("Mengunci jalur kerja lokal proyek...");
                            
                            let rp = format!("./{}/{}", o, r);

                            // Eksekusi manajemen SSH Key dinamis dari ssh.rs
                            if let Ok((owner_privkey, _owner_pubkey)) = ssh::kelola_ssh_key(o, &rp) {
                                
                                // 2. HUBUNGKAN DAN EKSEKUSI OPERASI CLONE OTOMATIS
                                if clone::eksekusi_clone(o, r, &rp, &owner_privkey).is_err() {
                                    // Jika proses clone gagal (offline/salah hak akses), lempar balik ke menu utama secara aman
                                    utils::_cc("----------------------------------------");
                                    utils::_pp();
                                    continue;
                                }

                                // DI SINI JALUR UNTUK PROSES INITIALISASI SPARSE-CHECKOUT & FETCH REMOTE BERIKUTNYA NANTI
                                
                            } else {
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
        } 
    } 
}

```

### Cara Menguji:
1. Pilih nomor repositori yang **belum memiliki folder lokal** (berstatus `[ daftar aktif ]`).










<br>
