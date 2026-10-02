# 

qc: 
menyelesaikan **Modul Deteksi Remote Branch Dinamis terlebih dahulu**.

aa: 
Di dalam skrip Bash lama Anda, nama *branch* dikunci secara statis ke main (pada baris `current_branch="main"`), lalu baru mendeteksi secara lokal jika folder `.git` sudah ada.

Di dalam versi **Rust** ini, kita akan membuat modul bernama `src/branch.rs` yang jauh lebih cerdas. Modul ini akan mengeksekusi biner Git secara native dengan perintah `git ls-remote --heads` untuk **mengintip langsung ke server GitHub secara real-time** guna mendeteksi *branch* utama apa saja yang tersedia di sana (seperti `main`, `master`, atau *branch* kustom), bahkan sebelum repositori tersebut di-clone ke penyimpanan lokal perangkat Anda!

---

## Langkah 1: Buat Modul Deteksi Branch (`src/branch.rs`)
Buat berkas baru bernama `branch.rs` di dalam folder `src/`. Salin seluruh kode arsitektur pelacak remote branch di bawah ini ke dalam berkas tersebut:
```rust
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk mendeteksi branch utama secara dinamis dari remote GitHub
pub fn deteksi_remote_branch(
    owner: &str,
    repo_name: &str,
    owner_privkey: &str,
) -> String {
    utils::_ic("Memeriksa struktur branch remote dari server GitHub...");

    // Menyusun argumen SSH kustom agar git ls-remote menggunakan key owner yang tepat
    let ssh_command_arg = format!("ssh -i {owner_privkey} -o IdentitiesOnly=yes");
    let remote_url = format!("git@github.com:{}/{}.git", owner, repo_name);

    // Eksekusi biner: git -c core.sshCommand="..." ls-remote --heads git@github.com:owner/repo.git
    let output_git = Command::new("git")
        .arg("-c")
        .arg(&format!("core.sshCommand={}", ssh_command_arg))
        .arg("ls-remote")
        .arg("--heads")
        .arg(&remote_url)
        .output();

    // Nilai default jika deteksi remote gagal atau perangkat sedang offline
    let mut branch_terdeteksi = String::from("main");

    match output_git {
        Ok(output) if output.status.success() => {
            let teks_output = String::from_utf8_lossy(&output.stdout);
            let mut list_branches: Vec<String> = Vec::new();

            // Membaca baris demi baris dari log hasil ls-remote
            for line in teks_output.lines() {
                // Contoh baris output: "d808867... refs/heads/main"
                if let Some(idx) = line.find("refs/heads/") {
                    let nama_branch = &line[idx + "refs/heads/".len()..];
                    list_branches.push(nama_branch.trim().to_string());
                }
            }

            // Aturan Penentuan Branch Otomatis:
            if !list_branches.is_empty() {
                // 1. Jika ada branch bernama 'main', priorotaskan main
                if list_branches.contains(&"main".to_string()) {
                    branch_terdeteksi = String::from("main");
                }
                // 2. Jika tidak ada 'main' tapi ada 'master' (repo lama), gunakan master
                else if list_branches.contains(&"master".to_string()) {
                    branch_terdeteksi = String::from("master");
                }
                // 3. Jika menggunakan nama kustom lain, ambil branch pertama yang muncul
                else {
                    branch_terdeteksi = list_branches[0].clone();
                }
                utils::_o(&format!("Sukses! Branch utama remote terdeteksi: '{branch_terdeteksi}'"));
            } else {
                utils::_w("Remote repositori terdeteksi kosong (Kosong/Belum ada branch). Menggunakan default: 'main'");
            }
        }
        _ => {
            // Jika gagal koneksi (offline), berikan peringatan visual dan gunakan fallback 'main'
            utils::_w("Gagal terhubung ke remote server! Mengaktifkan mode cache fallback branch: 'main'");
        }
    }

    std::thread::sleep(std::time::Duration::from_millis(800));
    branch_terdeteksi // Mengembalikan nama branch final
}

```

---

## Langkah 2: Hubungkan Modul Baru di `src/main.rs`
Buka kembali berkas utama `src/main.rs` Anda. Kita perlu mendaftarkan `mod branch;` di bagian atas berkas dan meletakkannya tepat di bawah blok sukses kloning repositori (`clone::eksekusi_clone`).

Ubah isi berkas `src/main.rs` Anda menjadi susunan final seperti di bawah ini:
```rust
use std::io::{self, Write};
mod utils; 
mod repo;  
mod t;     
mod h;     
mod f;     
mod ssh;   
mod clone; 
mod branch; // 1. Daftarkan modul branch.rs yang baru saja dirakit

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

                                // 2. HUBUNGKAN DAN EKSEKUSI DETEKSI BRANCH DINAMIS
                                let current_branch = branch::deteksi_remote_branch(o, r, &owner_privkey);
                                
                                // Tampilkan visual penguncian biner untuk pembuktian variabel branch
                                utils::_ls("Jalur Branch Terkunci", Some(&current_branch));

                                // DI SINI JALUR UNTUK PROSES INITIALISASI SPARSE-CHECKOUT & FETCH UTAMA BERIKUTNYA NANTI
                                
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
1. Pilih salah satu nomor repositori yang aktif.
2. Aplikasi Rust Anda akan mengamankan kredensial SSH, memverifikasi status clone folder fisik, lalu langsung menembak server GitHub untuk membaca struktur *heads*.
3. Jika repositori tersebut menggunakan branch bawaan bernama `main`, Rust akan mengunci variabelnya dan mencetak log hijau: `[✓] Jalur Branch Terkunci: main`. Jika Anda mengujinya pada repositori lama yang masih menggunakan `master`, Rust secara otomatis akan langsung mendeteksi perbedaannya tanpa salah target!

qa: 
Langkah berikutnya adalah masuk ke area terdalam dari fungsionalitas internal Git. Apakah kita akan melanjutkan konversi ke modul **Inisialisasi Sparse-Checkout Pertama Kali & Loop Otomatis Penguncian Konfigurasi Identitas Git Lokal Proyek** (`user.name`, `user.email`, `core.sshCommand`)? Silakan beri tahu saya jika Anda sudah siap untuk melanjutkannya!





<br>
