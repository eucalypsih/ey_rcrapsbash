
qc: 
**Modul membaca dan parsing isi `rp.txt`** ke dalam sistem array Rust (untuk mendata daftar nama repositori terpantau)

---

aa: 
Mari kita lanjutkan ke bagian **Modul membaca dan parsing isi `rp.txt`** ke dalam sistem *vector* (sebutan *array* dinamis di Rust).

Di dalam skrip Bash lama Anda, terdapat perulangan `while IFS= read -r line` yang membaca baris demi baris, mendeteksi baris tanpa spasi sebagai *owner*, dan baris ber-spasi sebagai *repo*, lalu menjahitnya menjadi format `owner/repo`.

Di Rust, kita akan mengonversi logika parsing teks tersebut menggunakan library bawaan `std::fs::read_to_string` yang jauh lebih cepat, aman, dan efisien dalam memproses data string.

---

## Langkah 1: Tambahkan Fungsi Parsing di `src/repo.rs`
Buka kembali file `src/repo.rs` Anda, lalu tambahkan fungsi `baca_dan_parse_repo()` di bagian paling bawah berkas.

Berikut adalah kode lengkap file `src/repo.rs` yang baru (Anda bisa langsung menimpa seluruh isinya):
```rust
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use crate::utils;

// Nama file target database repositori
pub const REPO_FILE: &str = "rp.txt";

/// Fungsi untuk memastikan file rp.txt ada. Jika tidak ada, buat otomatis dengan isi default.
pub fn pastikan_file_repo_ada() {
    let path = Path::new(REPO_FILE);

    if !path.exists() {
        utils::_e(&format!("File eksternal '{REPO_FILE}' tidak ditemukan!"));
        utils::_ic(&format!("Membuat file '{REPO_FILE}' dengan struktur default otomatis..."));

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

        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

/// KOREKSI & KONVERSI PARSING: Membaca teks rp.txt ke format Vector ["owner/repo", ...]
pub fn baca_dan_parse_repo() -> Vec<String> {
    let mut list_repositori: Vec<String> = Vec::new();
    
    // Membaca seluruh isi file rp.txt menjadi satu kesatuan String besar
    match fs::read_to_string(REPO_FILE) {
        Ok(isi_file) => {
            let mut current_owner = String::new();

            // Membaca teks baris demi baris secara otomatis
            for line in isi_file.lines() {
                // Saring baris kosong atau baris yang hanya berisi spasi liar
                if line.trim().is_empty() {
                    continue;
                }

                // Logika Bash: Jika baris diawali oleh spasi/tab, berarti ini nama REPO
                if line.starts_with(' ') || line.starts_with('\t') {
                    let nama_repo = line.trim();
                    if !current_owner.is_empty() {
                        // Jahit menjadi format "owner/repo" sesuai standardisasi skrip Anda
                        list_repositori.push(format!("{}/{}", current_owner, nama_repo));
                    }
                } else {
                    // Jika tidak diawali spasi, berarti baris ini mengunci nama OWNER baru
                    current_owner = line.trim().to_string();
                }
            }
        }
        Err(e) => {
            utils::_e(&format!("Gagal membaca file {REPO_FILE} untuk di-parsing: {e}"));
        }
    }

    list_repositori // Mengembalikan data hasil jahit array ke Main Program
}

```

---

## Langkah 2: Uji Coba Pemetaan Data di `src/main.rs`
Sekarang buka file `src/main.rs` Anda. Mari kita panggil fungsi parsing tersebut dan tampilkan hasilnya ke terminal menggunakan penomoran format cetak Rust.

Ubah isi `src/main.rs` menjadi seperti ini:

```rust
mod utils; 
mod repo;  

fn main() {
    print!("\x1B[2J\x1B[1;1H"); // Clear screen

    utils::_cc("========================================");
    utils::_cc("     UJI COBA PARSING DATA rp.txt       ");
    utils::_cc("========================================");

    // 1. Pastikan file database tersedia
    repo::pastikan_file_repo_ada();

    // 2. Eksekusi fungsi parsing teks ke Vector (Array dinamis)
    utils::_ic("Memetakan isi database rp.txt ke sistem memori...");
    let daftar_repo = repo::baca_dan_parse_repo();

    utils::_cc("\n----------------------------------------");
    utils::log_section("Daftar Repositori Terpantau (Format: owner/repo):");

    if daftar_repo.is_empty() {
        utils::_w("Database kosong atau gagal di-parse!");
    } else {
        // Tampilkan hasil parsing menggunakan perulangan loop index bawaan Rust
        for (i, repo_name) in daftar_repo.iter().enumerate() {
            println!(" [{}] {}", i + 1, repo_name);
        }
    }

    utils::_cc("----------------------------------------");
    utils::_o("Proses pemetaan string array sukses.");
    utils::_cc("========================================");
    
    utils::_pp(); 
}

```

### Hasil Ekspektasi di Terminal:
Rust akan langsung membaca file `rp.txt`, memisahkan mana owner dan sub-reponya di latar belakang, lalu menampilkannya dalam bentuk daftar bernomor rapi yang presisi (`[1] eucalypsih/ey_rcraps`, `[2] eucalypsih/ey_rcrapsbash`, dst)!

Hebatnya, proses parsing string berbasis *iterator lines* di Rust ini berjalan **puluhan kali lebih cepat** dibandingkan loop internal Bash, serta memakan konsumsi daya baterai yang sangat minim.

Modul visual dan modul database (`rp.txt`) kita sekarang sudah rampung dan saling terhubung dengan solid. Ke bagian mana kita akan melanjutkan konversinya?
- **Struktur Menu Utama (`loop`)** tempat mendeteksi ketikan tombol input (`[t]`, `[h]`, atau pengetikan nomor indeks repo untuk melompat maju)?
- Ataukah Anda ingin melihat bagaimana Rust **mendeteksi keberadaan folder fisik `.git` lokal** secara otomatis untuk memunculkan status `[ lokal aktif ]`?





<br>
