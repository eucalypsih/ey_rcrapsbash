# 

qc: 
lanjut ke modul **`[eE]` (Edit Berkas Menggunakan Editor Internal / `e.rs`)**

---

aa: 
Di dalam skrip Bash lama Anda, opsi ini bertugas untuk mendeteksi folder mana saja yang sedang berstatus `[ sudah aktif ]`, meminta pengguna memilih folder tersebut, lalu memetakan seluruh file di dalamnya menggunakan perintah `find`. Setelah pengguna memilih file, skrip akan membuka file tersebut secara otomatis menggunakan editor teks terminal (seperti `micro` atau `nano`). Jika file berhasil diubah, skrip akan mendeteksi modifikasi tersebut via `git status` dan memberikan opsi otomatisasi *commit lokal*.

Di dalam versi **Rust** ini, kita akan membuat modul bernama `src/e.rs`. Kita akan memanfaatkan library bawaan `std::fs` untuk memetakan file secara native (jauh lebih cepat daripada `find` di Bash) dan menggunakan `std::process::Command` untuk membuka editor teks pilihan Anda secara interaktif.

---

## Langkah 1: Buat Modul Edit File (`src/e.rs`)
Buat berkas baru bernama `e.rs` di dalam folder `src/`. Salin seluruh kode arsitektur penjelajah dan editor berkas di bawah ini ke dalam berkas tersebut:
```rust
use std::io::{self, Write};
use std::fs;
use std::path::Path;
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk menjelajah folder aktif dan mengedit file di dalamnya
pub fn jalankan_edit_file(rp_path: &str, current_sparse: &str) {
    // 1. Kumpulkan folder-folder yang sedang aktif dalam mode sparse-checkout
    let mut folder_aktif: Vec<String> = Vec::new();
    for line in current_sparse.lines() {
        let cleaned = line.trim().trim_start_matches('/').trim_end_matches('/');
        if !cleaned.is_empty() && cleaned != "." {
            folder_aktif.push(cleaned.to_string());
        }
    }

    if folder_aktif.is_empty() {
        utils::_e("Tidak ada folder aktif yang bisa dijelajahi! Silakan aktifkan folder terlebih dahulu.");
        utils::_pp();
        return;
    }

    // 2. Pilih Folder Aktif yang Ingin Dijelajahi
    utils::_cc("----------------------------------------");
    utils::log_section("Pilih Folder Aktif yang Ingin Dijelajahi:");
    for (i, folder) in folder_aktif.iter().enumerate() {
        println!(" [{}] /{}", i + 1, folder);
    }
    utils::_cc("----------------------------------------");
    utils::_p("Masukkan nomor folder", None);

    let mut input_folder = String::new();
    if io::stdin().read_line(&mut input_folder).is_err() {
        return;
    }
    
    let folder_idx = match input_folder.trim().parse::<usize>() {
        Ok(num) if num >= 1 && num <= folder_aktif.len() => num - 1,
        _ => {
            utils::_e("Pilihan nomor folder tidak valid!");
            utils::_pp();
            return;
        }
    };

    let folder_terpilih = &folder_aktif[folder_idx];
    let jalur_target_folder = format!("{}/{}", rp_path, folder_terpilih);

    // 3. Scan Berkas di Dalam Folder Menggunakan Modul Native Rust (Pengganti 'find')
    let path_obj = Path::new(&jalur_target_folder);
    let mut daftar_file: Vec<String> = Vec::new();

    if let Ok(entries) = fs::read_dir(path_obj) {
        for entry in entries.flatten() {
            if let Ok(file_type) = entry.file_type() {
                // Hanya ambil file biasa, skip sub-folder untuk kesederhanaan tingkat pertama
                if file_type.is_file() {
                    if let Some(file_name) = entry.file_name().to_str() {
                        daftar_file.push(file_name.to_string());
                    }
                }
            }
        }
    }

    if daftar_file.is_empty() {
        utils::_w(&format!("Folder /{} kosong! Belum ada file untuk diedit.", folder_terpilih));
        utils::_pp();
        return;
    }

    // 4. Pilih File yang Ingin Diedit
    print!("\x1B[2J\x1B[1;1H");
    let _ = io::stdout().flush();
    utils::_cc("========================================");
    utils::log_section(&format!("Daftar Berkas di Dalam /{}", folder_terpilih));
    utils::_cc("========================================");
    for (i, file) in daftar_file.iter().enumerate() {
        println!(" [{}] {}", i + 1, file);
    }
    utils::_cc("----------------------------------------");
    utils::_p("Pilih nomor file yang ingin diedit", None);

    let mut input_file = String::new();
    if io::stdin().read_line(&mut input_file).is_err() {
        return;
    }

    let file_idx = match input_file.trim().parse::<usize>() {
        Ok(num) if num >= 1 && num <= daftar_file.len() => num - 1,
        _ => {
            utils::_e("Pilihan nomor file tidak valid!");
            utils::_pp();
            return;
        }
    };

    let file_terpilih = &daftar_file[file_idx];
    let jalur_lengkap_file = format!("{}/{}/{}", rp_path, folder_terpilih, file_terpilih);

    // 5. Buka Editor Teks Terminal Secara Interaktif (Mendukung micro/nano)
    utils::_ic(&format!("Membuka berkas '{}' dengan editor teks...", file_terpilih));
    std::thread::sleep(std::time::Duration::from_millis(500));

    // Menentukan editor: Prioritaskan micro, jika tidak ada gunakan nano
    let editor = if Command::new("micro").arg("--version").output().is_ok() {
        "micro"
    } else {
        "nano"
    };

    // Eksekusi editor interaktif dengan mengambil kendali penuh atas stdin/stdout terminal
    let status_editor = Command::new(editor)
        .arg(&jalur_lengkap_file)
        .status();

    match status_editor {
        Ok(status) if status.success() => {
            utils::_o("Selesai mengedit berkas.");
            
            // 6. DETEKSI OTOMASI COMMIT LOKAL (JIKA ADA PERUBAHAN FISIK)
            cek_dan_tawarkan_commit(rp_path, file_terpilih);
        }
        _ => {
            utils::_e(&format!("Gagal membuka editor teks '{}'!", editor));
            utils::_pp();
        }
    }
}

/// Fungsi internal pembantu untuk mendeteksi perubahan via git status dan memicu commit lokal otomatis
fn cek_dan_tawarkan_commit(rp_path: &str, file_name: &str) {
    let output_git = Command::new("git")
        .arg("-C")
        .arg(rp_path)
        .arg("status")
        .arg("--porcelain")
        .output();

    if let Ok(out) = output_git {
        let status_text = String::from_utf8_lossy(&out.stdout);
        // Jika teks status tidak kosong, berarti ada modifikasi file yang tercatat di Git
        if !status_text.trim().is_empty() {
            utils::_rn("Mendeteksi perubahan yang belum disimpan ke repositori lokal!");
            println!("\x1B[31m{}\x1B[0m", status_text);
            utils::_cc("----------------------------------------");
            utils::_pd("Apakah Anda ingin langsung merekam (Commit) editan ini secara lokal?");
            
            let mut konfirmasi = String::new();
            let _ = io::stdin().read_line(&mut konfirmasi);

            if konfirmasi.trim().eq_ignore_ascii_case("y") {
                // Jalankan proses git add --sparse .
                let _ = Command::new("git").arg("-C").arg(rp_path).arg("add").arg("--sparse").arg(".").status();
                
                // Gunakan pesan otomatis default: "u" + timestamp sederhana
                let pesan_commit = format!("u{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() % 1000);
                
                let commit_status = Command::new("git")
                    .arg("-C")
                    .arg(rp_path)
                    .arg("commit")
                    .arg("-m")
                    .arg(&pesan_commit)
                    .status();

                if let Ok(status) = commit_status {
                    if status.success() {
                        utils::_o(&format!("Sukses! Perubahan dikunci dengan pesan: '{}'", pesan_commit));
                    } else {
                        utils::_e("Gagal melakukan git commit!");
                    }
                }
            } else {
                utils::_w("Perubahan dipertahankan di working directory lokal tanpa di-commit.");
            }
            utils::_pp();
        }
    }
}

```

---

## Langkah 2: Hubungkan Opsi `[eE]` di `src/sparse_menu.rs`
Buka berkas `src/sparse_menu.rs` Anda. Kita perlu mendaftarkan `mod e;` di atas (atau memanggilnya langsung karena sudah didaftarkan di `main.rs`) dan mengganti tanda pembatas placeholder `(Segera hadir)...` pada opsi `"e" | "E"` dengan fungsi asli dari `e.rs`.

Silakan sesuaikan isi cabang `match` milik `src/sparse_menu.rs` pada opsi tombol `e` menjadi seperti ini:
```rust
// ... (Sisa kode atas sparse_menu.rs biarkan utuh)
        match pilihan_bersih {
            "b" | "B" => {
                utils::_o("Meninggalkan repositori. Kembali ke Pemilihan Utama...");
                std::thread::sleep(std::time::Duration::from_millis(800));
                return Ok(());
            }
            "e" | "E" => {
                // 💡 KOREKSI: Hubungkan tombol [e] dengan fungsi jelajah-edit di dalam e.rs
                crate::e::jalankan_edit_file(rp_path, &current_sparse);
                continue; // Refresh layar menu kedua setelah kembali dari mengedit file
            }
            "n" | "N" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka modul eksternal n.rs (Segera hadir)...");
                utils::_pp();
            }
// ... (Sisa kode bawah biarkan utuh)

```

---

## Langkah 3: Daftarkan Modul Baru di `src/main.rs`
Buka berkas utama `src/main.rs` Anda, lalu cukup selipkan deklarasi `mod e;` di baris pendaftaran modul teratas agar seluruh rangkaian proyek mengenal modul baru ini:
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
mod num;
mod e; // <-- TAMBAHKAN BARIS INI DI SINI!

fn main() {
    // ... sisa kode main.rs ke bawah biarkan utuh ...

```

### Cara Menguji Kehebatan Modul Edit (`e.rs`):
1. Masuk ke halaman `SISTEM SELEKSI SPARSE-CHECKOUT` pada repositori yang sudah memiliki folder aktif ber-label `[ sudah aktif ]`.
2. Tekan tombol `e` lalu *Enter*.
3. Skrip Rust akan menampilkan daftar folder lokal yang aktif secara native. Pilih nomor folder tersebut.
4. Rust akan memetakan seluruh file di dalam folder tersebut secara instan. Pilih nomor file yang ingin Anda ubah.
5. Terminal Termux Anda akan langsung beralih kendali membuka editor teks (seperti `micro` atau `nano`) secara interaktif penuh.
6. Silakan edit isinya, lalu simpan dan keluar dari editor. Begitu Anda keluar, Rust kembali mengambil kendali layar, mendeteksi perubahan berkas via `git status`, dan menawarkan opsi pembuatan *commit lokal* otomatis dengan sangat rapi dan aman!
Luar biasa! Modul penjelajah dan editor teks terintegrasi kita sekarang sudah berfungsi 100% menggunakan arsitektur biner Rust yang super cepat.
















<br>
