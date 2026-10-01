# 

qc: 
**Modul `[tT]` (Tambah Repositori Baru)** untuk menulis data string ke dalam file `rp.txt` secara otomatis

---

aa: 
Mari kita lanjutkan ke **Modul `[tT]` (Tambah Repositori Baru)** untuk menulis data string ke dalam berkas `rp.txt` secara otomatis.

Di dalam skrip Bash lama Anda, opsi ini bertugas menerima masukan nama repositori baru, membersihkan spasi liar dengan `tr -d '[:space:]'`, memberikan *owner* default `eucalypsih/` jika pengguna hanya mengetikkan nama proyeknya saja, menyaring duplikasi, lalu meng-ekspor datanya kembali ke berkas `rp.txt` lewat fungsi `fungsi_export_repo` dengan format lekukan spasi (*indentation*) yang rapi.

Di dalam bahasa Rust, kita akan membuat modul baru bernama `src/t.rs` dan memanfaatkan fitur manipulasi string bawaan yang sangat aman dari risiko kebocoran data.

---

## Langkah 1: Buat Modul Tambah Repo (`src/t.rs`)
Buat berkas baru bernama `t.sh` di dalam folder `src/`. Eh, maaf maksud saya berkas bernama `t.rs` (kebiasaan Bash).

Salin kode Rust berikut ke dalam `src/t.rs`:
```rust
use std::io::{self, Write};
use crate::utils;
// use crate::repo; // <-- HAPUS BARIS INI DARI src/t.rs


/// Fungsi utama untuk menjalankan modul tambah repositori baru
pub fn jalankan_tambah_repo(repo_file: &str, mut valid_repos: Vec<String>) {
    utils::_cc("----------------------------------------");
    utils::_p("Masukkan repositori baru (Format: owner/repo atau cuma nama_repo)", None);

    // Membaca masukan dari pengguna
    let mut repo_baru = String::new();
    if io::stdin().read_line(&mut repo_baru).is_err() {
        utils::_e("Gagal membaca input terminal!");
        return;
    }

    // Bersihkan input dari spasi, tab, atau baris baru (\n) liar ala tr -d '[:space:]'
    let repo_bersih: String = repo_baru.chars().filter(|c| !c.is_whitespace()).collect();

    if repo_bersih.is_empty() {
        utils::_e("Input tidak boleh kosong!");
        std::thread::sleep(std::time::Duration::from_millis(1500));
        return;
    }

    // Jika user tidak memasukkan owner (tidak ada tanda '/'), gunakan default 'eucalypsih'
    let mut repo_final = repo_bersih;
    if !repo_final.contains('/') {
        repo_final = format!("eucalypsih/{}", repo_final);
    }

    // Validasi duplikasi data agar nama repo tidak ganda di dalam vector
    if valid_repos.contains(&repo_final) {
        utils::_w(&format!("Repositori '{repo_final}' sudah ada dalam daftar."));
    } else {
        // Masukkan ke dalam array dinamis (vector)
        valid_repos.push(repo_final.clone());
        
        // Ekspor susunan data terbaru kembali ke dalam file rp.txt
        if ekspor_ke_file(repo_file, &valid_repos).is_ok() {
            utils::_o(&format!("'{repo_final}' berhasil ditambahkan ke {repo_file}."));
        }
    }
    
    std::thread::sleep(std::time::Duration::from_millis(1500));
}

/// Fungsi internal untuk menulis ulang rp.txt dengan format spasiasi yang rapi
fn ekspor_ke_file(repo_file: &str, valid_repos: &[String]) -> Result<(), io::Error> {
    let mut file = std::fs::File::create(repo_file)?;
    let mut last_owner = String::new();

    for item in valid_repos {
        // Memisahkan owner dan repo menggunakan split_once yang aman di Rust
        if let Some((owner, repo)) = item.split_once('/') {
            // Jika owner berubah, tulis nama owner baru tanpa spasi di awal
            if owner != last_owner {
                if !last_owner.is_empty() {
                    writeln!(file)?; // Berikan baris kosong antar owner agar estetik
                }
                writeln!(file, "{}", owner)?;
                last_owner = owner.to_string();
            }
            // Tulis nama repo dengan indentasi 4 spasi sesuai standardisasi rp.txt Anda
            writeln!(file, "    {}", repo)?;
        }
    }
    Ok(())
}

```

---

## Langkah 2: Daftarkan Modul Baru di `src/main.rs`
Buka kembali berkas `src/main.rs` Anda. Kita perlu mendaftarkan `modul t` dan mengganti bagian penanda cetak `(Segera hadir)...` pada opsi `"t" | "T"` dengan fungsi asli yang baru saja kita rakit.

Ubah isi `src/main.rs` Anda menjadi seperti ini (perhatikan baris `mod t;` dan pemanggilannya):
```bash
use std::io::{self, Write};
mod utils; 
mod repo;  
mod t;     // 1. Daftarkan modul t.rs yang baru dibuat

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
                // utils::_an "Proses dibatalkan. Keluar dari skrip.";  // ❌ Error karena kurang tanda kurung ()
                utils::_an("Proses dibatalkan. Keluar dari skrip."); // ✅ BENAR: Menggunakan tanda kurung standar Rust
                std::process::exit(0);
            }
            "t" | "T" => {
                // 2. Hubungkan opsi tombol t dengan fungsi pemicu di dalam t.rs
                t::jalankan_tambah_repo(repo::REPO_FILE, daftar_repo);
            }
            "h" | "H" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka Modul Hapus Daftar Repo (Segera hadir)...");
                utils::_pp();
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


### Cara Menguji Operasi Tambah Data:
1. Tekan tombol `t` pada keyboard terminal Anda lalu tekan Enter.
2. Coba ketikkan sebuah nama repositori baru secara asal, contoh: `proyek_baru_otomasi`.
3. Rust akan langsung menangkap teks tersebut, membungkusnya secara otomatis dengan *owner* default sehingga menjadi `eucalypsih/proyek_baru_otomasia`, menyimpannya ke dalam memori, lalu menuliskan struktur barisnya ke dalam berkas fisik `rp.txt`.
4. Layar menu utama Anda akan langsung ter-refresh secara instan dan memunculkan `proyek_baru_otomasi` di baris nomor terbaru dengan visual yang sangat bersih. Anda juga bisa mencoba membuka berkas `rp.txt` untuk memastikan spasi lekukannya sudah tertulis dengan presisi.
Luar biasa, sistem manajemen basis data teks kustom kita sekarang sudah bekerja bolak-balik (baca-tulis) dengan aman!
Ke bagian mana kita akan melanjutkan konversinya agar arsitektur Menu Utama ini lengkap?
- **Modul `[hH]` (Hapus Repo dari Daftar `rp.txt`)** dengan integrasi sistem keamanan deteksi berkas modifikasi Git sebelum melakukan pembongkaran folder lokal?
- **Modul `[hH]` (Hapus Repo dari Daftar `rp.txt`)** dengan integrasi pencarian string pintar `awk` versi Rust agar aman dari risiko salah hapus nama repo yang kembar?
- Ataukah **Modul `[fF]` (Hanya Hapus Folder Fisik Lokal)** yang bertugas melakukan purge cache direktori?










<br>
