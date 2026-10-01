# 

qc: 
**Struktur Menu Utama (`loop`)** tempat mendeteksi ketikan tombol input (`[t]`, `[h]`, atau pengetikan nomor indeks repo untuk melompat maju) dan melihat bagaimana Rust **mendeteksi keberadaan folder fisik `.git` lokal** secara otomatis untuk memunculkan status `[ lokal aktif ]`

manakah yang sebaiknya didahulukan

---

Sebaiknya kita mendahulukan **logika pendeteksian folder fisik `.git` lokal** terlebih dahulu.

Alasan teknis mengapa ini harus didahulukan adalah karena **Menu Utama (`loop`) bertugas menampilkan status visual tersebut**. Menu Utama membutuhkan data apakah suatu repositori sudah di-clone atau belum (`[ lokal aktif ]` atau `[ daftar aktif ]`) *sebelum* menu tersebut dicetak ke layar terminal dan menunggu input dari Anda. Jika kita membuat menu utama duluan, daftar repositori Anda akan terlihat "mati" karena tidak bisa mendeteksi folder proyek riil di penyimpanan Termux/Linux Anda.

Mari kita gabungkan kedua logika ini secara berurutan: kita buat fungsi deteksi `.git` dulu, lalu kita rakit di dalam kerangka loop Menu Utama.

---

## Langkah 1: Tambahkan Deteksi `.git` di Modul Repo (`src/repo.rs`)
Buka file `src/repo.rs`, lalu tambahkan fungsi publik `cek_lokal_aktif` di bagian paling bawah. Fungsi ini menggunakan `std::path::Path` untuk memeriksa keberadaan folder `.git` secara instan dan hemat baterai.
```rust
/// Fungsi untuk mengecek apakah folder fisik repositori lokal sudah memiliki konfigurasi .git
pub fn cek_lokal_aktif(repo_gabung: &str) -> bool {
    // Memisahkan owner dan nama_repo dari format "owner/repo"
    let parts: Vec<&str> = repo_gabung.split('/').collect();
    if parts.len() == 2 {
        let owner = parts[0];
        let repo_name = parts[1];
        
        // Menyusun jalur target path fisik: ./owner/repo/.git
        let jalur_git = format!("{}/{}/.git", owner, repo_name);
        
        // Mengembalikan nilai true jika folder .git benar-benar ada fisik
        Path::new(&jalur_git).is_dir()
    } else {
        false
    }
}

```

---

## Langkah 2: Rakit Menu Utama (`loop`) Dinamis di `src/main.rs`
Sekarang kita akan merombak total file `src/main.rs` Anda. Kita akan membuat perulangan loop yang menampilkan status `[ lokal aktif ]` secara otomatis (menggunakan fungsi di atas) serta membaca ketikan input keyboard (`read_line`) untuk mendeteksi pilihan tombol `[t]`, `[h]`, `[f]`, `[q]`, atau nomor indeks repo.

Hapus seluruh isi `src/main.rs` Anda saat ini, lalu ganti dengan kode final Menu Utama ini:
```rust
use std::io::{self, Write};
mod utils; 
mod repo;  

fn main() {
    // Pastikan file database rp.txt sudah siap di awal program
    repo::pastikan_file_repo_ada();

    // MASUK KE KERANGKA MENU UTAMA TANPA PERLUNYA WHILE
    loop {
        // Bersihkan layar terminal secara bersih di setiap perulangan menu
        print!("\x1B[2J\x1B[1;1H");
        let _ = io::stdout().flush();

        utils::_cc("========================================");
        utils::_cc("       PILIH REPOSITORI UTAMA           ");
        utils::_cc("========================================");
        utils::log_section("Daftar Repositori Terpantau (Format: owner/repo):");

        // Ambil data repositori terbaru dari rp.txt secara real-time
        let daftar_repo = repo::baca_dan_parse_repo();

        if daftar_repo.is_empty() {
            utils::_e("File database 'rp.txt' kosong! Silakan isi nama repositori.");
        } else {
            // Pemetaan daftar repo beserta status deteksi fisik .git lokal
            for (i, repo_name) in daftar_repo.iter().enumerate() {
                let mut status_str = " \x1B[32m[ daftar aktif ]\x1B[0m".to_string(); // Hijau standar
                
                // Panggil fungsi deteksi .git fisik yang baru kita buat
                if repo::cek_lokal_aktif(repo_name) {
                    // Jika folder .git ditemukan, tambahkan label lokal aktif warna Cyan
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
        
        // Logika menangkap input ketikan Anda di Rust (read -r di Bash)
        let mut repo_pilihan = String::new();
        if io::stdin().read_line(&mut repo_pilihan).is_err() {
            utils::_e("Gagal membaca input terminal!");
            continue;
        }
        
        // Bersihkan spasi atau baris baru (\n) dari hasil ketikan keyboard
        let pilihan_bersih = repo_pilihan.trim();

        // --- SISTEM EVALUASI TOMBOL NAVIGASI ---
        match pilihan_bersih {
            "q" | "Q" => {
                utils::_an("Proses dibatalkan. Keluar dari skrip.");
                std::process::exit(0); // Keluar aplikasi secara bersih
            }
            "t" | "T" => {
                utils::_cc("----------------------------------------");
                utils::_ic("Membuka Modul Tambah Repositori (Segera hadir)...");
                utils::_pp();
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
                // Evaluasi jika pengguna memasukkan nomor indeks repositori
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= daftar_repo.len() {
                        let repo_terpilih = &daftar_repo[nomor - 1];
                        
                        utils::_on(&format!("Repositori dipilih: {}", repo_terpilih));
                        utils::_ic("Mengunci jalur kerja lokal proyek...");
                        
                        // DI SINI TEMPAT UNTUK MELOMPAT KE PROSES GIT CORE & MENU KEDUA NANTI
                        utils::_cc("----------------------------------------");
                        utils::_pp();
                        
                        // Sementara break ini kita matikan dulu agar program memutar kembali ke menu utama
                        // break; 
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

### Cara Menguji Logika Deteksi Fisik:
1. Menu Utama akan langsung muncul dengan daftar nomor dari file `rp.txt`.
2. Saat ini statusnya hanya berupa `[ daftar aktif ]`.
3. Untuk menguji deteksi fisik `.git`, silakan buka sesi terminal Termux baru, lalu buat folder tiruan di dalam folder proyek Anda sesuai nama *owner* dan *repo* yang tertera di menu, misalnya:
```bash
mkdir -p eucalypsih/ey_rcraps/.git

```
4. Kembali ke layar aplikasi Rust Anda, masukkan input asal atau tekan Enter untuk me-refresh menu. Anda akan melihat repositori tersebut secara ajaib langsung berubah statusnya menjadi memiliki label **`[ lokal aktif ]`** berwarna cyan yang menyala terang!

Bagian fondasi terberat dari Menu Utama dan sistem interaksi data kita telah sukses 100% dikonversi ke Rust. Ke bagian mana kita akan melangkah berikutnya?
- **Modul `[tT]` (Tambah Repositori Baru)** untuk menulis data string ke dalam file `rp.txt` secara otomatis?
- **Modul `[hH]` (Hapus Daftar Repo)** untuk melakukan pembersihan teks dan manajemen *purge folder* fisik?









<br>
