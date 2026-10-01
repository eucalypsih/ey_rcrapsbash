# 

qc: 
Ingin melanjutkan konversi ke bagian **Modul Pembuatan File Otomatis `rp.txt`**

---

aa: 
Mari kita lanjutkan ke bagian berikutnya, yaitu **Modul Pembuatan File Otomatis `rp.txt`**.

Di dalam skrip Bash lama Anda, bagian ini bertugas untuk mendeteksi keberadaan file database repositori. Jika file `rp.txt` tidak ditemukan, skrip akan membuatnya secara otomatis dan mengisinya dengan struktur default (*owner* dan daftar sub-repo).

Di dalam bahasa Rust, kita akan memanfaatkan library bawaan `std::fs` dan `std::path::Path` untuk memproses pembacaan dan penulisan file ke penyimpanan lokal perangkat secara aman.

---

### Langkah 1: Buat Modul Repo (`src/repo.rs`)
Buat file baru bernama `repo.rs` di dalam folder `src/`. File ini akan menjadi modul khusus yang menangani file database `rp.txt`.

Salin kode Rust berikut ke dalam `src/repo.rs`:
```rust
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use crate::utils; // Menghubungkan ke fungsi logging di utils.rs

// Nama file target database repositori
pub const REPO_FILE: &str = "rp.txt";

/// Fungsi untuk memastikan file rp.txt ada. Jika tidak ada, buat otomatis dengan isi default.
pub fn pastikan_file_repo_ada() {
    let path = Path::new(REPO_FILE);

    // Cek apakah file sudah ada di penyimpanan lokal
    if !path.exists() {
        utils::_e(&format!("File eksternal '{REPO_FILE}' tidak ditemukan!"));
        utils::_ic(&format!("Membuat file '{REPO_FILE}' dengan struktur default otomatis..."));

        // Struktur teks default yang akan ditulis ke file rp.txt
        let isi_default = "\
eucalypsih
    ey_rcraps
    ey_rcrapsbash
    ey_rcrapsc
    ey_rsrapsc
    ey_rcrapsrs
    ey_rsrapsrs
    eucalypsih_rcrapsbash
    ey_tp
    ey_ta
    eucalypsih_rcrapskt
    ey_vsvapsosj

owner_lain
    repo1
    repo2
";

        // Proses pembuatan dan penulisan file secara aman di Rust
        match File::create(REPO_FILE) {
            Ok(mut file) => {
                if let Err(e) = file.write_all(isi_default.as_bytes()) {
                    utils::_e(&format!("Gagal menulis data ke {REPO_FILE}: {e}"));
                } else {
                    utils::_o(&format!("File '{REPO_FILE}' berhasil diinisialisasi."));
                }
            }
            Err(e) => {
                utils::_e(&format!("Gagal membuat file {REPO_FILE}: {e}"));
            }
        }

        // Memberikan jeda visual seperti sleep 1 di Bash
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

```

---

### Langkah 2: Daftarkan dan Uji Coba Modul di `src/main.rs`
Sekarang buka file `src/main.rs` Anda. Kita perlu mendaftarkan modul `repo` yang baru saja dibuat agar bisa dieksekusi oleh program utama.

Ubah isi `src/main.rs` menjadi seperti ini:
```rust
mod utils; // Menghubungkan file utils.rs
mod repo;  // Menghubungkan file repo.rs

fn main() {
    // Bersihkan layar terminal ala Rust
    print!("\x1B[2J\x1B[1;1H");

    utils::_cc("========================================");
    utils::_cc("     UJI COBA MODUL FILE DATABASE       ");
    utils::_cc("========================================");

    // Eksekusi fungsi pengaman otomatis pembuat rp.txt
    repo::pastikan_file_repo_ada();

    utils::_cc("----------------------------------------");
    utils::_o("Pengecekan database selesai.");
    utils::_cc("========================================");
    
    utils::_pp(); // Menahan layar terminal
}

```

### Hasil Ekspektasi:
- Jika `rp.txt` tidak ada, Rust akan langsung memunculkan pesan error merah, membuat file baru berwarna cyan, menulis isinya, memberikan status sukses hijau, dan jika Anda cek folder proyek, file `rp.txt` riil akan muncul secara instan dengan susunan data owner yang rapi.
- Jika Anda menjalankan `cargo run` untuk kedua kalinya, Rust akan melewati proses pembuatan karena mendeteksi file sudah ada secara aman.

Setelah modul otomatisasi file database `rp.txt` ini sukses berjalan tanpa kendala, ke bagian mana kita akan melanjutkan konversinya?
- **Modul membaca dan parsing isi `rp.txt`** ke dalam sistem array Rust (untuk mendata daftar nama repositori terpantau)?
- Ataukah **struktur kerangka Menu Utama (`loop`)** tempat mendeteksi ketikan pilihan tombol `[t]`, `[h]`, atau `[q]`?

---











<br>
