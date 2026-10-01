# 


aa: 
Mari kita lanjutkan ke pembuatan **Modul `[hH]` (Hapus Repo dari Daftar `rp.txt`)** ke dalam berkas `src/h.rs`.

Di dalam bahasa Rust, kita akan menggantikan logika pencarian string pintar `awk` yang kita diskusikan pada versi Bash menggunakan fungsi penataan *vector* bawaan Rust. Sesuai standar keamanan tertinggi, skrip ini juga akan **memeriksa status repositori Git lokal** sebelum melakukan penghapusan fisik, guna memastikan tidak ada pekerjaan Anda yang belum di-*commit* (`git status --porcelain`) yang ikut terhapus secara tidak sengaja.

---

## Langkah 1: Buat Modul Hapus Repo (`src/h.rs`)
Buat berkas baru bernama `h.rs` di dalam folder `src/`. Salin seluruh kode bersih di bawah ini ke dalam berkas tersebut:
```rust
use std::io::{self, Write};
use std::fs;
use std::path::Path;
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk menjalankan modul hapus repositori dari daftar dan penyimpanan fisik
pub fn jalankan_hapus_repo(repo_file: &str, mut valid_repos: Vec<String>) {
    if valid_repos.is_empty() {
        utils::_e("Tidak ada repositori yang bisa dihapus!");
        utils::_pp();
        return;
    }

    utils::_cr("----------------------------------------"); // ❌ Error karena _cr tidak ditemukan
    // utils::_cc("----------------------------------------"); // ✅ BENAR: Menggunakan warna Cyan dari fungsi _cc
    // pub fn _cr(text: &str) {
    //     println!("{}", text.red().bold());
    // }
    
    utils::_p("Pilih nomor repo yang ingin dibuang dari daftar rp.txt", None);
    
    let mut input_num = String::new();
    if io::stdin().read_line(&mut input_num).is_err() {
        utils::_e("Gagal membaca input terminal!");
        return;
    }

    let input_bersih = input_num.trim();

    // Validasi apakah input berupa angka indeks yang sah
    if let Ok(nomor) = input_bersih.parse::<usize>() {
        if nomor >= 1 && nomor <= valid_repos.len() {
            let idx_hapus = nomor - 1;
            let repo_terhapus = valid_repos[idx_hapus].clone();

            // Memisahkan owner dan nama repo secara aman
            if let Some((owner_name, repo_name)) = repo_terhapus.split_once('/') {
                let target_folder_fisik = format!("./{owner_name}/{repo_name}");
                let target_owner_dir = format!("./{owner_name}");

                utils::_pd(&format!("Anda yakin ingin menghapus '{repo_terhapus}' dari daftar {repo_file}?"));
                let mut konfirmasi = String::new();
                let _ = io::stdin().read_line(&mut konfirmasi);
                
                if konfirmasi.trim().eq_ignore_ascii_case("y") {
                    // 1. HAPUS DATA DARI VECTOR MEMORI
                    valid_repos.remove(idx_hapus);

                    // 2. TULIS ULANG DATABASE rp.txt (Logika Ekspor yang Aman & Rapi)
                    if ekspor_ke_file(repo_file, &valid_repos).is_ok() {
                        utils::_o(&format!("'{repo_terhapus}' telah dihapus dari daftar {repo_file}."));
                    }

                    // 3. SISTEM PURGE FOLDER FISIK LOKAL (JIKA DIREKTORI ADA)
                    let path_fisik = Path::new(&target_folder_fisik);
                    if path_fisik.is_dir() {
                        // Jalankan perintah 'git status --porcelain' untuk mendeteksi uncommitted changes
                        let output_git = Command::new("git")
                            .arg("-C")
                            .arg(&target_folder_fisik)
                            .arg("status")
                            .arg("--porcelain")
                            .output();

                        let mut ada_perubahan = false;
                        if let Ok(out) = output_git {
                            let status_text = String::from_utf8_lossy(&out.stdout);
                            if !status_text.trim().is_empty() {
                                ada_perubahan = true;
                                utils::log_critical(&format!("Terdeteksi berkas UNTRACKED / MODIFIED di dalam /{repo_name}!"));
                                println!("\x1B[31m{}\x1B[0m", status_text);
                                utils::_cc("------------------------------------------------------");
                                utils::_pd("Apakah Anda YAKIN ingin MEMUSHNAKAN folder repositori ini beserta seluruh isinya?");
                            } else {
                                utils::_pd("Apakah Anda ingin MENGHAPUS FISIK folder repositori ini dari penyimpanan lokal?");
                            }
                        } else {
                            utils::_pd("Apakah Anda ingin MENGHAPUS FISIK folder repositori ini dari penyimpanan lokal?");
                        }

                        let mut konfirmasi_fisik = String::new();
                        let _ = io::stdin().read_line(&mut konfirmasi_fisik);

                        if konfirmasi_fisik.trim().eq_ignore_ascii_case("y") {
                            utils::_ic(&format!("Memusnahkan folder fisik lokal: {}/{}...", owner_name, repo_name));
                            
                            // Eksekusi rm -rf secara aman via library bawaan Rust
                            if fs::remove_dir_all(&target_folder_fisik).is_ok() {
                                utils::_o("Folder fisik repositori berhasil dihapus sepenuhnya.");

                                // Bersihkan folder owner induk jika sudah kosong total
                                let path_owner = Path::new(&target_owner_dir);
                                if path_owner.is_dir() && fs::read_dir(path_owner).map(|mut d| d.next().is_none()).unwrap_or(false) {
                                    utils::_ic(&format!("Mendeteksi folder owner '{owner_name}' kosong. Membersihkan sisa direktori induk..."));
                                    let _ = fs::remove_dir(&target_owner_dir);
                                }
                            } else {
                                utils::_e("Gagal menghapus folder fisik lokal. Periksa hak izin akses!");
                            }
                        } else {
                            if ada_perubahan {
                                utils::_w("Folder fisik lokal dipertahankan demi keamanan editan Anda.");
                            } else {
                                utils::_w("Folder fisik lokal dipertahankan dan tetap aman.");
                            }
                        }
                    }
                } else {
                    utils::_c("Penghapusan dibatalkan.");
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

/// Fungsi internal untuk menulis ulang rp.txt setelah proses penghapusan data vector selesai
fn ekspor_ke_file(repo_file: &str, valid_repos: &[String]) -> Result<(), io::Error> {
    let mut file = fs::File::create(repo_file)?;
    let mut last_owner = String::new();

    for item in valid_repos {
        if let Some((owner, repo)) = item.split_once('/') {
            if owner != last_owner {
                if !last_owner.is_empty() {
                    writeln!(file)?;
                }
                writeln!(file, "{}", owner)?;
                last_owner = owner.to_string();
            }
            writeln!(file, "    {}", repo)?;
        }
    }
    Ok(())
}

```

---

## Langkah 2: Daftarkan dan Hubungkan Modul di `src/main.rs`
Buka kembali berkas utama `src/main.rs` Anda. Kita perlu mendaftarkan `mod h;` di bagian atas dan mengganti baris petunjuk pembatas opsi `"h" | "H"` dengan fungsi pemicu yang sebenarnya.

Ubah isi `src/main.rs` Anda menjadi struktur final seperti di bawah ini:
```rust
use std::io::{self, Write};
mod utils; 
mod repo;  
mod t;     
mod h;     // 1. Daftarkan modul h.rs yang baru dibuat

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
                // 2. Hubungkan opsi tombol h dengan fungsi pemicu asli di h.rs
                h::jalankan_hapus_repo(repo::REPO_FILE, daftar_repo);
            }
            "f" | "F" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka Modul Purge Folder Fisik (Segera hadir)...");
                utils::_pp();
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

## Solusi 2: Tambahkan Fungsi `_cr` ke dalam `src/utils.rs` (Jika Ingin Tetap Merah)
Jika Anda bersikeras ingin garis pembatas pada menu hapus tersebut tetap menyala berwarna merah tebal sesuai skrip aslinya, Anda tinggal mendaftarkan fungsi `_cr` ke dalam library visual Anda.

Buka berkas `src/utils.rs`, cari bagian atas setelah fungsi `_in` (sekitar baris ke-20), lalu selipkan fungsi publik baru ini di sana:
```rust
pub fn _cr(text: &str) {
    println!("{}", text.red().bold());
}

```

---

### Cara Menguji Keamanan Modul Hapus (`h.rs`):
1. Pilih menu `h` lalu tekan *Enter*.
2. Masukkan nomor urut repositori yang ingin Anda buang dari daftar database `rp.txt`.
3. Skrip akan memberikan konfirmasi awal. Jika Anda menyetujuinya (`y`), nama repositori tersebut langsung terhapus dari file teks `rp.txt`.
4. Jika repositori tersebut kebetulan memiliki folder fisik ber-label `[ lokal aktif ]` di penyimpanan lokal, Rust akan secara otomatis menginterupsi proses untuk mengeksekusi `git status` internal. Jika Anda sempat mengubah isi file di dalam folder tersebut tanpa melakukan *commit*, Rust akan menampilkan daftar modifikasinya dalam warna merah dan menanyakan lapis pengaman konfirmasi kedua agar Anda tidak kehilangan berkas penting akibat kecerobohan perintah `rm -rf`.
Kini arsitektur Menu Utama dan sistem manajemen database repositori Anda sudah sepenuhnya berjalan di atas eksekusi binary Rust yang solid, aman, dan berkecepatan tinggi!

---

qa: 
- Apakah Anda ingin melanjutkan konversi ke modul **`[fF]` (Hanya Hapus Folder Fisik / `f.rs`)** untuk melengkapi seluruh opsi tombol Menu Utama?
- Ataukah Anda ingin langsung melompat ke bagian modul pemrosesan Git Core terberat, yaitu **logika Kloning Otomatis Proyek dan manajemen SSH Key dinamis**?





<br>
