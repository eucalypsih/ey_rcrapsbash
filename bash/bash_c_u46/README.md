# 


qc: 
melanjutkan konversi ke modul **Inisialisasi Sparse-Checkout Pertama Kali & Loop Otomatis Penguncian Konfigurasi Identitas Git Lokal Proyek** (`user.name`, `user.email`, `core.sshCommand`)

---

aa: 
Mari kita lanjutkan konversi ke modul **Inisialisasi Sparse-Checkout Pertama Kali & Loop Penguncian Konfigurasi Identitas Git Lokal Proyek**.

Di dalam skrip Bash lama Anda, logika ini terdapat pada pemanggilan berkas eksternal `./modul_sh/init_git.sh`. Bagian ini bertugas untuk mendeteksi apakah *sparse-checkout* sudah pernah diaktifkan sebelumnya. Jika belum, skrip akan menginisialisasinya, mendaftarkan berkas konfigurasi agar tidak melacak seluruh isi repositori, serta mengunci identitas Git (`user.name` dan `user.email`) dan core.sshCommand secara lokal khusus untuk repositori tersebut agar aman dari kebocoran akun global.

Di dalam bahasa Rust, kita akan membuat modul baru bernama `src/init_git.rs` dengan memanfaatkan `std::process::Command` untuk mengunci seluruh rantai konfigurasi Git ini secara berurutan dan aman.

---

## Langkah 1: Buat Modul Inisialisasi Git (`src/init_git.rs`)
Buat berkas baru bernama `init_git.rs` di dalam folder `src/`. Salin seluruh kode arsitektur inisialisasi Git lokal di bawah ini ke dalam berkas tersebut:
```rust
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk menginisialisasi sparse-checkout dan mengunci konfigurasi Git lokal
pub fn jalankan_init_git(
    rp_path: &str,
    owner: &str,
    owner_privkey: &str,
    current_branch: &str,
) -> Result<(), ()> {
    // Mengambil status daftar sparse saat ini untuk mendeteksi inisialisasi awal
    let current_sparse = Command::new("git")
        .arg("-C")
        .arg(rp_path)
        .arg("sparse-checkout")
        .arg("list")
        .output();

    let mut is_initialized = false;
    if let Ok(output) = current_sparse {
        let text = String::from_utf8_lossy(&output.stdout);
        if !text.trim().is_empty() {
            is_initialized = true;
        }
    }

    // PENGAMAN UTAMA: Hanya jalankan set & config jika sparse-checkout belum pernah diinisialisasi
    if !is_initialized {
        utils::_ic("Mendeteksi repositori baru. Menginisialisasi sistem Sparse-Checkout...");

        // 1. Inisialisasi sparse-checkout dengan mode cone (standard Git modern)
        let init_sparse = Command::new("git")
            .arg("-C")
            .arg(rp_path)
            .arg("sparse-checkout")
            .arg("init")
            .arg("--cone")
            .status();

        if init_sparse.is_err() || !init_sparse.unwrap().success() {
            utils::log_fatal("Gagal menginisialisasi Git Sparse-Checkout!");
            return Err(());
        }

        utils::_ic("Mengonfigurasi identitas dan pengaman SSH lokal proyek...");

        // 2. Loop Otomatis Penguncian Konfigurasi Identitas Git Lokal Proyek
        // Menyusun rantai perintah konfigurasi lokal agar terisolasi dari Git global (~/.gitconfig)
        let ssh_command_value = format!("ssh -i {} -o IdentitiesOnly=yes", owner_privkey);
        let config_commands = vec![
            ("user.name", owner),
            ("user.email", &format!("{}@://github.com", owner)),
            ("core.sshCommand", &ssh_command_value),
            ("commit.gpgsign", "false"), // Memastikan tidak crash jika perangkat tidak punya GPG Key
        ];

        for (key, value) in config_commands {
            let config_status = Command::new("git")
                .arg("-C")
                .arg(rp_path)
                .arg("config")
                .arg("local")
                .arg(key)
                .arg(value)
                .status();

            if config_status.is_err() || !config_status.unwrap().success() {
                utils::_e(&format!("Gagal mengunci konfigurasi lokal: {}", key));
                return Err(());
            }
        }

        utils::_o("Sistem Sparse-Checkout dan kredensial lokal berhasil dikunci.");
    } else {
        utils::_o("Repositori terdeteksi sudah terinisialisasi sebelumnya.");
    }

    // =====================================================================
    // MODUL VALIDASI KONEKSI JARINGAN (PENCEGAHAN OFFLINE CRASH) & FETCH REMOTE
    // =====================================================================
    utils::_ic("Memperbarui informasi struktur remote dari GitHub...");

    if cek_koneksi_internet() {
        utils::_ic("Koneksi online terverifikasi. Memperbarui struktur remote...");

        // Eksekusi fetch data terbaru dari origin branch
        let fetch_status = Command::new("git")
            .arg("-C")
            .arg(rp_path)
            .arg("fetch")
            .arg("-q")
            .arg("origin")
            .arg(current_branch)
            .status();

        if let Ok(status) = fetch_status {
            if status.success() {
                utils::_o(&format!("Sukses menarik data terbaru dari origin/{}", current_branch));
                println!("------------------------------------------------");
                std::thread::sleep(std::time::Duration::from_millis(1200));
            } else {
                utils::_e("Gagal terhubung ke remote server GitHub!");
                if !konfirmasi_cache_lokal() {
                    return Err(());
                }
            }
        } else {
            utils::_e("Gagal mengeksekusi perintah git fetch!");
            return Err(());
        }
    } else {
        // Proteksi jika terdeteksi jaringan offline/tanpa internet
        utils::_w("Anda sedang OFFLINE! Tidak dapat memvalidasi data remote terbaru.");
        if !konfirmasi_cache_lokal() {
            return Err(());
        }
    }

    Ok(())
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

/// Fungsi internal pembantu untuk meminta konfirmasi memuat cache lokal lama jika offline / fetch gagal
fn konfirmasi_cache_lokal() -> bool {
    utils::_p("Apakah ingin memuat menu dengan cache lokal lama? (y/n)", None);
    let mut konfirmasi = String::new();
    if std::io::stdin().read_line(&mut konfirmasi).is_ok() {
        if konfirmasi.trim().eq_ignore_ascii_case("y") {
            utils::_o("Mengaktifkan mode cache lokal. Struktur remote tidak diperbarui.");
            println!("------------------------------------------------");
            std::thread::sleep(std::time::Duration::from_millis(1500));
            return true;
        }
    }
    utils::_a("Membatalkan proses. Keluar dari alur repositori.");
    std::thread::sleep(std::time::Duration::from_millis(1500));
    false
}

```

## Langkah 2: Hubungkan Modul Baru di `src/main.rs`
Buka kembali berkas utama `src/main.rs` Anda. Kita perlu mendaftarkan `mod init_git;` di bagian atas berkas dan memanggil fungsinya tepat di bawah bagian deteksi remote branch yang kita kerjakan pada tahap sebelumnya.

Ubah isi berkas `src/main.rs` Anda menjadi susunan lengkap seperti di bawah ini:
```rust
use std::io::{self, Write};
mod utils; 
mod repo;  
mod t;     
mod h;     
mod f;     
mod ssh;   
mod clone; 
mod branch; 
mod init_git; // 1. Daftarkan modul init_git.rs baru

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
                                
                                // Eksekusi operasi clone otomatis
                                if clone::eksekusi_clone(o, r, &rp, &owner_privkey).is_err() {
                                    utils::_cc("----------------------------------------");
                                    utils::_pp();
                                    continue;
                                }

                                // Eksekusi deteksi branch dinamis
                                let current_branch = branch::deteksi_remote_branch(o, r, &owner_privkey);
                                
                                // 2. HUBUNGKAN DAN EKSEKUSI INISIALISASI UTAMA & FETCH REMOTE
                                if init_git::jalankan_init_git(&rp, o, &owner_privkey, &current_branch).is_err() {
                                    utils::_cc("----------------------------------------");
                                    utils::_pp();
                                    continue;
                                }

                                // DI SINI JALUR UNTUK MEMANGGIL FUNGSI MENU KEDUA (buka_menu_sparse) NANTI
                                utils::_o("Kesiapan alur Git proyek terverifikasi penuh.");
                                utils::_pp();
                                
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

### Cara Menguji Logika Penguncian Konfigurasi:
1. Pilih nomor repositori yang baru saja di-clone (atau hapus folder fisik repo lama dengan opsi `[f]` terlebih dahulu untuk mensimulasikan kondisi baru).
2. Setelah proses clone dan deteksi branch selesai, Rust akan langsung memanggil `modul init_git.rs`.
3. Anda akan melihat log biru: `[~] Mendeteksi repositori baru. Menginisialisasi sistem Sparse-Checkout...` disusul dengan loop otomatis penguncian identitas yang mencetak log sukses hijau.
4. Di akhir proses, Rust akan otomatis mengeksekusi `git fetch origin [nama_branch]`. Jika Anda matikan internet (offline), sistem proteksi *crash* kita akan langsung menginterupsi dengan rapi dan memberikan opsi konfirmasi memuat cache lokal lama (`y/n`) tanpa merusak jalannya aplikasi terminal!
Kini seluruh eksekusi rantai pra-pemrosesan berat dan konfigurasi mendalam sistem Git lokal Anda sudah rampung 100% dipindahkan ke Rust dengan sangat aman dan dinamis.

<br>

Langkah berikutnya adalah merakit **Fungsi Menu Kedua (Buka Menu Sparse-Checkout / Menu Interaktif Pilihan Folder)** yang akan menangani perintah pembuatan file, edit file, git rm, dan tombol Back yang terbebas dari *stack call overflow*.

Apakah Anda ingin kita langsung rancang kerangka fungsi menu kedua tersebut di tahap selanjutnya? Jika siap, silakan beri tahu saya! Or if there are any error/warning notes, please let me know.





<br>
