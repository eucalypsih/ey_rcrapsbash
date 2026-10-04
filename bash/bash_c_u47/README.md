# 



qc: 
merakit **Fungsi Menu Kedua (Buka Menu Sparse-Checkout / Menu Interaktif Pilihan Folder)** yang akan menangani perintah pembuatan file, edit file, git rm, dan tombol Back yang terbebas dari *stack call overflow*.

---

aa: 
Mari kita rakit **Fungsi Menu Kedua (Menu Interaktif Sparse-Checkout)** ke dalam proyek Rust Anda.

Agar menu ini **100% terbebas dari bahaya _stack call overflow_** saat Anda menekan tombol `[b]` (Back) secara bolak-balik, kita **tidak akan memakai teknik rekursi** (fungsi memanggil fungsi). Kita akan menggunakan arsitektur **Loop Induk Tunggal** di dalam `main.rs` dan memanfaatkan fitur `return` fungsi bawaan Rust.

Teknik ini menjamin memori RAM perangkat Anda tetap konstan dan sangat stabil meskipun digunakan berhari-hari tanpa henti.

---

## Langkah 1: Buat Modul Menu Sparse (`src/sparse_menu.rs`)
Buat berkas baru bernama `sparse_menu.rs` di dalam folder `src/`. Modul ini bertugas membaca folder dari remote secara otomatis (`git ls-tree`), menampilkan status `[ sudah aktif ]`, dan menangani opsi `[n]`, `[e]`, `[d]`, serta tombol `[b]` Back secara aman.

Salin seluruh kode bersih di bawah ini ke dalam `src/sparse_menu.rs`:
```rust
use std::io::{self, Write};
use std::process::Command;
use crate::utils;

/// Fungsi utama untuk mengendalikan Menu Kedua (Sparse-Checkout) secara interaktif
pub fn buka_menu_sparse(rp_path: &str, repo_name: &str, current_branch: &str) -> Result<(), ()> {
    loop {
        // 1. OTOMATISASI DAFTAR TARGET DARI REMOTE REPOSITORY (Folder Tingkat Pertama)
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

        // 2. AMBIL DAFTAR SPARSE YANG SEDANG AKTIF SAAT INI
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

        // 3. TAMPILKAN VISUAL INTERFAS MENU KEDUA
        print!("\x1B[2J\x1B[1;1H"); // Sapu bersih layar terminal sebelum cetak menu kedua
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
                // Cek apakah folder remote sudah aktif di lokal sparse-checkout
                // Menggunakan pola regex sederhana via pendeteksian baris
                let mut sudah_aktif = false;
                for active_line in current_sparse.lines() {
                    let cleaned_active = active_line.trim().trim_start_matches('/').trim_end_matches('/');
                    
                    // KOREKSI JELI: Lewati dan abaikan pola teks manual agar tidak merusak pencocokan folder
                    if cleaned_active == "*" || cleaned_active == "!*" || cleaned_active == "README.md" || cleaned_active.contains('*') {
                        continue;
                    }
                    
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
        println!(" [b] \x1B[33mKembali ke Menu Pilih Repositori Utama\x1B[0m"); // <--- TOMBOL BACK AMAN
        utils::_cc("========================================");

        utils::_p("Masukkan pilihan Anda", None);

        let mut input_pilihan = String::new();
        if io::stdin().read_line(&mut input_pilihan).is_err() {
            utils::_e("Gagal membaca input terminal!");
            continue;
        }
        let pilihan_bersih = input_pilihan.trim();

        // 4. EVALUASI OPSI TOMBOL NAVIGASI MENU KEDUA
        match pilihan_bersih {
            "b" | "B" => {
                utils::_o("Meninggalkan repositori. Kembali ke Pemilihan Utama...");
                std::thread::sleep(std::time::Duration::from_millis(800));
                
                // 💡 PENGAMAN UTAMA: Gunakan return Ok(()) untuk mematikan fungsi menu kedua ini.
                // Alur otomatis kembali jatuh ke loop utama main.rs tanpa menumpuk Stack Call RAM!
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
                // Logika jika pengguna memilih nomor urut folder untuk aktivasi sparse-checkout
                if let Ok(nomor) = pilihan_bersih.parse::<usize>() {
                    if nomor >= 1 && nomor <= targets.len() {
                        let folder_terpilih = &targets[nomor - 1];
                        utils::_ic(&format!("Memproses perubahan status folder: /{}", folder_terpilih));

                        // Di sini nanti tempat untuk mengeksekusi biner num.rs versi Rust
                        utils::_cc("----------------------------------------");
                        utils::_pp();
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

## Langkah 2: Daftarkan dan Panggil Menu di `src/main.rs`
Sekarang kita buka berkas utama `src/main.rs` Anda. Mari kita daftarkan `mod sparse_menu;` di bagian atas dan panggil fungsinya tepat di bawah baris kesuksesan inisialisasi Git yang kita buat di tahap sebelumnya.

Ubah bagian terdalam dari blok pemilihan repositori angka pada `src/main.rs` menjadi struktur lengkap di bawah ini:
```rust
// ... (Bagian pendaftaran modul di atas fn main())
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
mod sparse_menu; // 1. Daftarkan modul sparse_menu.rs yang baru

fn main() {
    // ... [Semua kode cetak menu utama biarkan tetap sama seperti sebelumnya] ...

                                // Eksekusi inisialisasi utama & fetch remote
                                if init_git::jalankan_init_git(&rp, o, &owner_privkey, &current_branch).is_err() {
                                    utils::_cc("----------------------------------------");
                                    utils::_pp();
                                    continue;
                                }

                                // 2. KOREKSI & SAMBUNGKAN KE MANAJEMEN MENU KEDUA (SPARSE-CHECKOUT)
                                utils::_o("Kesiapan alur Git proyek terverifikasi penuh.");
                                std::thread::sleep(std::time::Duration::from_millis(500));
                                
                                // Panggil fungsi menu kedua. 
                                // Jika user menekan tombol 'b', fungsi ini selesai dan loop induk main.rs akan memutar ulang otomatis!
                                let _ = sparse_menu::buka_menu_sparse(&rp, r, &current_branch);
                                
                            } else {
                                utils::_cc("----------------------------------------");
                                utils::_pp();
                                continue;
                            }
                        }

                        // Hapus atau komentari baris _pp() lama di luar sini agar tidak macet double enter saat kembali dari menu kedua
                        // utils::_cc("----------------------------------------");
                        // utils::_pp();
                    } else {
// ... [Sisa kode kurung kurawal ke bawah biarkan utuh] ...

```

---

## Uji Coba Transnavigation Bebas Overload 🚀
### Cara Menguji Navigasi Bolak-balik:
1. Pilih salah satu repositori yang berstatus `[ lokal aktif ]` (misal ketik `1` lalu Enter).
2. Aplikasi Rust Anda akan memverifikasi SSH Key, mendeteksi branch remote, melakukan sinkronisasi kilat, lalu layar terminal akan langsung ter-refresh bersih memuat halaman `SISTEM SELEKSI SPARSE-CHECKOUT` (Menu Kedua).
3. Anda akan melihat daftar folder internal repositori tersebut yang ditarik langsung dari struktur internal Git, lengkap dengan status `[ sudah aktif ]` jika folder itu sudah ter-download di Termux Anda.
4. Sekarang, tekan tombol `b` lalu Enter. Layar akan langsung kembali ke halaman `PILIH REPOSITORI UTAMA` secara instan dengan visual piringan menu yang bersih dari duplikasi garis pembatas `====`.




















<br>
