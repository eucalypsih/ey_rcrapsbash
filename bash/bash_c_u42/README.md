# 

aa: 
Mari kita lanjutkan ke pembuatan **Modul `[fF]` (Hanya Hapus Folder Fisik Lokal)** ke dalam berkas `src/f.sh`. Eh, maksud saya `src/f.rs`!

Di dalam skrip Bash lama Anda, opsi ini bertugas untuk melakukan *purge* atau pembersihan direktori lokal proyek tanpa membuang nama repositori dari daftar database `rp.txt`. Sama seperti modul hapus sebelumnya (`h.rs`), di dalam versi Rust ini kita akan menyuntikkan pengaman `git status` internal. Jika terdeteksi ada pekerjaan editan berkas Anda yang belum di-*commit*, Rust akan memberikan peringatan visual merah yang tegas agar data penting Anda tidak terhapus sia-sia.

---

## Langkah 1: Buat Modul Purge Folder Fisik (`src/f.rs`)
Buat berkas baru bernama `f.rs` di dalam folder `src/`. Salin seluruh kode bersih di bawah ini ke dalam berkas tersebut:
```rust
use std::io; // {self, Write}; ⚠️ Warning karena tidak terpakai
use std::fs;
use std::path::Path;
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk menjalankan modul pembersihan (purge) folder fisik lokal repositori
pub fn jalankan_purge_folder(valid_repos: Vec<String>) {
    if valid_repos.is_empty() {
        utils::_e("Daftar repositori kosong!");
        utils::_pp();
        return;
    }

    utils::_cr("----------------------------------------");
    utils::_p("Pilih nomor repo yang ingin di-PURGE/HAPUS folder fisik lokalnya saja", None);
    
    let mut input_num = String::new();
    if io::stdin().read_line(&mut input_num).is_err() {
        utils::_e("Gagal membaca input terminal!");
        return;
    }

    let input_bersih = input_num.trim();

    // Validasi apakah masukan pengguna merupakan angka indeks daftar yang sah
    if let Ok(nomor) = input_bersih.parse::<usize>() {
        if nomor >= 1 && nomor <= valid_repos.len() {
            let idx_fisik = nomor - 1;
            let repo_target = &valid_repos[idx_fisik];

            // Memisahkan owner_name dan repo_name dari string format "owner/repo"
            if let Some((owner_name, repo_name)) = repo_target.split_once('/') {
                let target_folder_fisik = format!("./{owner_name}/{repo_name}");
                let target_owner_dir = format!("./{owner_name}");

                let path_fisik = Path::new(&target_folder_fisik);

                // Validasi awal: Periksa apakah folder fisik lokalnya memang ada di penyimpanan
                if !path_fisik.is_dir() {
                    utils::_w(&format!("Folder fisik untuk '{repo_target}' memang tidak ada di lokal (Sudah Bersih)."));
                    std::thread::sleep(std::time::Duration::from_millis(1500));
                    return;
                }

                utils::_rn("PERINGATAN: Tindakan ini HANYA menghapus folder fisik di penyimpanan lokal.");
                utils::_c(&format!("Pilihan ini TETAP MEMPERTAHANKAN '{repo_target}' di dalam daftar rp.txt."));

                // --- DETEKSI BEKAS MODIFIKASI GIT (UNCOMMITTED CHANGES) ---
                let output_git = Command::new("git")
                    .arg("-C")
                    .arg(&target_folder_fisik)
                    .arg("status")
                    .arg("--porcelain")
                    .output();

                // let mut ada_perubahan = false;
                let mut _ada_perubahan = false; // (Tambahkan tanda garis bawah di depannya)
                if let Ok(out) = output_git {
                    let status_text = String::from_utf8_lossy(&out.stdout);
                    if !status_text.trim().is_empty() {
                        // ada_perubahan = true;
                        _ada_perubahan = true; // (Tambahkan tanda garis bawah di depannya
                        utils::log_critical(&format!("Terdeteksi berkas UNTRACKED / MODIFIED di dalam /{repo_name}!"));
                        println!("\x1B[31m{}\x1B[0m", status_text); // Cetak berkas modifikasi warna merah
                        utils::_cc("------------------------------------------------------");
                        utils::_pd("Berkas belum di-commit! Yakin tetap ingin MEMUSHNAKAN folder fisik ini?");
                    } else {
                        utils::_pd(&format!("Apakah Anda yakin ingin menghapus folder fisik lokal '{owner_name}/{repo_name}'?"));
                    }
                } else {
                    utils::_pd(&format!("Apakah Anda yakin ingin menghapus folder fisik lokal '{owner_name}/{repo_name}'?"));
                }

                let mut konfirmasi_fisik_only = String::new();
                let _ = io::stdin().read_line(&mut konfirmasi_fisik_only);

                // --- EKSEKUSI PEMBONGKARAN DIREKTORI FISIK ---
                if konfirmasi_fisik_only.trim().eq_ignore_ascii_case("y") {
                    utils::_ic("Menghapus folder fisik lokal secara permanen...");
                    
                    if fs::remove_dir_all(&target_folder_fisik).is_ok() {
                        utils::_o("Folder fisik lokal berhasil dihapus. Konfigurasi di rp.txt tetap aman.");

                        // Otomatisasi Bersih: Sapu bersih direktori owner induk jika sudah kosong total
                        let path_owner = Path::new(&target_owner_dir);
                        if path_owner.is_dir() && fs::read_dir(path_owner).map(|mut d| d.next().is_none()).unwrap_or(false) {
                            utils::_ic(&format!("Mendapati direktori owner '{owner_name}' kosong, membersihkan folder induk..."));
                            let _ = fs::remove_dir(&target_owner_dir);
                        }
                    } else {
                        utils::_e("Gagal menghapus folder fisik lokal! Periksa hak akses penyimpanan perangkat.");
                    }
                } else {
                    utils::_c("Penghapusan fisik dibatalkan.");
                }
            }
        } else {
            utils::_e("Pilihan nomor di luar jangkauan daftar!");
        }
    } else {
        utils::_e("Pilihan nomor tidak valid!");
    }

    std::thread::sleep(std::time::Duration::from_millis(1500));
}

```

---

## Langkah 2: Daftarkan dan Hubungkan Modul di `src/main.rs`
Sekarang buka kembali berkas utama `src/main.rs` Anda. Kita perlu mendaftarkan `mod f;` di bagian atas berkas dan mengganti pesan `(Segera hadir)...` pada opsi `"f" | "F"` dengan memanggil fungsi asli dari `f.rs`.

Ubah isi `src/main.rs` Anda menjadi susunan kode berikut:
```rust
use std::io; // {self, Write}; ⚠️ Warning karena tidak terpakai
mod utils; 
mod repo;  
mod t;     
mod h;     
mod f;     // 1. Daftarkan modul f.rs yang baru saja dirakit

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
                // 2. KOREKSI: Hubungkan tombol f dengan modul fungsi pembersih di f.rs
                f::jalankan_purge_folder(daftar_repo);
            }
            _ => {
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= daftar_repo.len() {
                        let repo_terpilih = &daftar_repo[nomor - 1];
                        utils::_on(&format!("Repositori dipilih: {}", repo_terpilih));
                        utils::_ic("Mengunci jalur kerja lokal proyek...");
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

### Hasil Ekspektasi:
- Ketika Anda menekan tombol `f`, Anda bisa menghapus isi folder lokal proyek yang sudah berstatus `[ lokal aktif ]` secara instan, namun daftar nama repositori di dalam file database `rp.txt` dijamin akan tetap awet dipertahankan.
Sekarang bagian permukaan dari **Menu Utama** skrip Anda sudah selesai dikonversi total ke arsitektur modern Rust dengan manajemen memori yang luar biasa stabil.
Langkah berikutnya adalah masuk ke area terdalam dan krusial dari otomasi Git skrip Anda. Apakah Anda ingin kita mulai menyusun konversi untuk:
1. **Modul Pengunduhan SSH Key Dinamis & Manajemen Kredensial Owner Otomatis** (Pindahan dari blok `_ic "Mengonfigurasi SSH Key..."` dan perintah `curl` unduh key)?
2. Ataukah **Modul `git clone` otomatis tanpa checkout** (`git clone -q --filter=blob:none --no-checkout`)
Silakan beri tahu saya bagian mana yang paling menantang dan menarik minat Anda untuk kita ubah ke kode Rust selanjutnya!



















<br>
