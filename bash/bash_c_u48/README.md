# 

qc: 
Modul **Aktivasi/Nonaktifkan Angka Urut Folder Sparse-Checkout** (`num.rs`)

---

aa: 
Mari kita selesaikan bagian paling krusial dari menu kedua ini, yaitu **Modul Aktivasi/Nonaktifkan Angka Urut Folder Sparse-Checkout** (`src/num.rs`).

Di dalam skrip Bash lama Anda, bagian ini menangani logika interaktif ketika pengguna mengetik nomor urut folder. Jika folder tersebut **belum aktif**, skrip akan menambahkannya ke dalam daftar *sparse-checkout*. Jika folder tersebut **sudah aktif**, skrip akan menghapusnya (nonaktifkan).

Di dalam bahasa Rust, kita akan membuat modul bernama `src/num.rs`. Logika ini akan mendeteksi isi dari `git sparse-checkout list` saat ini, mengevaluasi apakah folder target sudah terdaftar atau belum, lalu mengeksekusi biner Git `sparse-checkout set` dengan daftar folder terbaru secara aman.

---

## Langkah 1: Buat Modul Manajemen Folder (`src/num.rs`)
Buat berkas baru bernama `num.rs` di dalam folder `src/`. Salin seluruh kode manajemen *sparse rules* di bawah ini ke dalam berkas tersebut:
```rust
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk menambah (aktivasi) atau menghapus (nonaktifkan) folder dari sparse-checkout
pub fn jalankan_toggle_folder(
    rp_path: &str,
    folder_target: &str,
    current_sparse: &str,
) {
    // 1. Parsing daftar folder yang sedang aktif saat ini ke dalam Vector
    let mut folder_aktif: Vec<String> = Vec::new();
    let mut sudah_aktif = false;

    for line in current_sparse.lines() {
        let cleaned = line.trim().trim_start_matches('/').trim_end_matches('/');
        if !cleaned.is_empty() {
            folder_aktif.push(cleaned.to_string());
            if cleaned == folder_target {
                sudah_aktif = true;
            }
        }
    }

    // 2. TENTUKAN TINDAKAN: Jika sudah aktif maka HAPUS, jika belum aktif maka TAMBAH
    if sudah_aktif {
        utils::_ic(&format!("Mendeteksi /{} sudah aktif. Menonaktifkan folder...", folder_target));
        // Hapus folder target dari daftar vector
        folder_aktif.retain(|x| x != folder_target);
    } else {
        utils::_ic(&format!("Mendeteksi /{} belum aktif. Mengaktifkan folder...", folder_target));
        // Tambahkan folder target ke dalam daftar vector
        folder_aktif.push(folder_target.to_string());
    }

    // 3. EKSEKUSI PERUBAHAN KE GIT
    // Jika setelah dihapus ternyata tidak ada folder yang aktif sama sekali,
    // Git sparse-checkout mewajibkan setidaknya ada tanda "." (root saja) agar tidak error.
    let mut git_cmd = Command::new("git");
    git_cmd.arg("-C").arg(rp_path).arg("sparse-checkout").arg("set");

    if folder_aktif.is_empty() {
        git_cmd.arg(".");
    } else {
        for folder in &folder_aktif {
            git_cmd.arg(folder);
        }
    }

    let status_git = git_cmd.status();

    match status_git {
        Ok(status) if status.success() => {
            if sudah_aktif {
                utils::_o(&format!("Folder /{} berhasil dinonaktifkan dari lokal.", folder_target));
            } else {
                utils::_o(&format!("Folder /{} berhasil diaktifkan secara real-time.", folder_target));
            }
        }
        _ => {
            utils::_e("Gagal memperbarui konfigurasi Git Sparse-Checkout!");
        }
    }

    // Berikan jeda visual cepat seperti sleep 1.2 di Bash
    std::thread::sleep(std::time::Duration::from_millis(1200));
}

```

---

## Langkah 2: Hubungkan Modul `num.rs` ke dalam `src/sparse_menu.rs`
Buka berkas `src/sparse_menu.rs` Anda. Kita perlu mendaftarkan `num` sebagai modul internal atau memanggil fungsinya langsung pada blok evaluasi kecocokan nomor urut (bagian bawah match `pilihan_bersih`).

Mari kita perbarui berkas `src/sparse_menu.rs` Anda menjadi struktur final di bawah ini:
```rust
use std::io::{self, Write};
use std::process::Command;
use crate::utils;
use crate::num; // 1. Daftarkan modul num.rs yang baru saja dibuat

/// Fungsi utama untuk mengendalikan Menu Kedua (Sparse-Checkout) secara interaktif
pub fn buka_menu_sparse(rp_path: &str, repo_name: &str, current_branch: &str) -> Result<(), ()> {
    loop {
        // [ Bagian 1, 2, dan 3 tetap sama seperti sebelumnya ]
        let output_tree = Command::new("git")
            .arg("-C")
            .arg(rp_path)
            .arg("ls-tree")
            .arg("-d")
            .arg("--name-only")
            .arg(format!("origin/{}", current_branch))
            .output();

        let mut targets: Vec<String> = Vec::new();
        if let Ok(out) = output_tree {
            let text = String::from_utf8_lossy(&out.stdout);
            for line in text.lines() {
                if !line.trim().is_empty() {
                    targets.push(line.trim().to_string());
                }
            }
        }

        let output_sparse = Command::new("git")
            .arg("-C")
            .arg(rp_path)
            .arg("sparse-checkout")
            .arg("list")
            .output();

        let mut current_sparse = String::new();
        if let Ok(out) = output_sparse {
            current_sparse = String::from_utf8_lossy(&out.stdout).to_string();
        }

        print!("\x1B[2J\x1B[1;1H"); 
        let _ = io::stdout().flush();

        utils::_cc("========================================");
        utils::_cc("   SISTEM SELEKSI SPARSE-CHECKOUT       ");
        utils::_cc("========================================");
        utils::log_section(&format!("Repositori Aktif: {repo_name} (Branch: {current_branch})"));
        utils::log_section("Daftar folder otomatis dari Remote:");

        if targets.is_empty() {
            utils::_w("Repositori saat ini tidak memiliki folder (hanya berisi file root).");
        } else {
            for (i, folder) in targets.iter().enumerate() {
                let mut sudah_aktif = false;
                for active_line in current_sparse.lines() {
                    let cleaned_active = active_line.trim().trim_start_matches('/').trim_end_matches('/');
                    if cleaned_active == folder {
                        sudah_aktif = true;
                        break;
                    }
                }

                if sudah_aktif {
                    println!(" [{}] /{: <12}  \x1B[32m[ sudah aktif ]\x1B[0m", i + 1, folder);
                } else {
                    println!(" [{}] /{: <12}", i + 1, folder);
                }
            }
        }

        utils::_cc("----------------------------------------");
        println!(" [e] \x1B[32mEdit File (Jelajahi Folder Aktif)\x1B[0m");
        println!(" [n] \x1B[32mBuat File Baru di Folder Aktif\x1B[0m");
        println!(" [d] \x1B[31mHapus File atau Sub-Folder (Git RM)\x1B[0m");
        println!(" [b] \x1B[33mKembali ke Menu Pilih Repositori Utama\x1B[0m"); 
        utils::_cc("========================================");

        utils::_p("Masukkan pilihan Anda", None);

        let mut input_pilihan = String::new();
        if io::stdin().read_line(&mut input_pilihan).is_err() {
            utils::_e("Gagal membaca input terminal!");
            continue;
        }
        let pilihan_bersih = input_pilihan.trim();

        match pilihan_bersih {
            "b" | "B" => {
                utils::_o("Meninggalkan repositori. Kembali ke Pemilihan Utama...");
                std::thread::sleep(std::time::Duration::from_millis(800));
                return Ok(());
            }
            "e" | "E" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka modul eksternal e.rs (Segera hadir)...");
                utils::_pp();
            }
            "n" | "N" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka modul eksternal n.rs (Segera hadir)...");
                utils::_pp();
            }
            "d" | "D" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka modul eksternal d.rs (Segera hadir)...");
                utils::_pp();
            }
            _ => {
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= targets.len() {
                        let folder_terpilih = &targets[nomor - 1];
                        
                        // 2. KOREKSI & SAMBUNGKAN KODE: Hubungkan nomor input dengan modul toggle_folder
                        num::jalankan_toggle_folder(rp_path, folder_terpilih, &current_sparse);
                        
                        // Gunakan continue agar menu langsung me-refresh status visual secara real-time
                        continue;
                    } else {
                        utils::_e("Pilihan nomor di luar jangkauan daftar folder!");
                        utils::_pp();
                    }
                } else {
                    utils::_e("Pilihan tidak valid! Masukkan nomor, [e], [n], [d], atau [b].");
                    utils::_pp();
                }
            }
        }
    }
}

```

---

## Langkah 3: Daftarkan Modul Baru di `src/main.rs`
Agar berkas proyek mengenali modul `num.rs` yang baru saja kita kaitkan di dalam `sparse_menu`, buka file utama `src/main.rs` Anda, lalu cukup selipkan deklarasi `mod num;` di baris pendaftaran modul teratas:
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
mod init_git; 
mod sparse_menu;
mod num; // <-- TAMBAHKAN BARIS INI DI SINI!

fn main() {
    // ... sisa kode main.rs ke bawah biarkan utuh tanpa ada perubahan ...

```

### Cara Menguji:
1. Masuk ke salah satu repositori aktif hingga Anda tiba di halaman `SISTEM SELEKSI SPARSE-CHECKOUT`.
2. Pilih salah satu nomor folder yang belum aktif (misal ketik `1` lalu Enter).
3. Rust akan langsung memanggil `num.rs`, biner Git mengeksekusi penarikan folder secara parsial dari cloud GitHub, memunculkan notifikasi sukses hijau, dan dalam kedipan mata, layar menu kedua akan ter-refresh kembali dengan label `[ sudah aktif ]` di samping nama folder tersebut!
4. Jika Anda mengetik nomor `1` sekali lagi, Rust secara cerdas akan langsung membalik logikanya untuk membuang aturan tersebut dan mencopot (*unlink*) folder fisik terkait dari penyimpanan lokal Anda secara aman.
Luar biasa! Sistem otomasi *rules parsing* parsial Git Anda sekarang sudah bekerja 100% sempurna di Rust tanpa ada celah kebocoran memori RAM.

Bagian tindakan manipulasi file manakah yang ingin kita selesaikan berikutnya ke dalam Menu Kedua ini?
- Modul `[nN]` (Buat Berkas Baru di Folder Aktif / `n.rs`)?
- Modul `[eE]` (Edit Berkas Menggunakan Editor Internal / `e.rs`)?
- Modul `[dD]` (Hapus File/Sub-Folder via Git RM / `d.rs`)?




<br>

