#

Untuk mengunduh atau membaca file mentah (*raw file*) dari GitHub menggunakan library `reqwest` di Rust, Anda perlu mengirimkan request **GET** ke URL tersebut.

Berikut adalah **cara langsung dan contoh kode lengkap** untuk melakukannya:

## 1. Tambahkan Dependencies
Pastikan Anda menggunakan runtime async seperti `tokio` karena `reqwest` secara default berjalan secara asinkronus. Tambahkan ini di file `Cargo.toml` Anda:
```toml
[dependencies]
reqwest = { version = "0.12.28", features = ["json"] } # sesuaikan versi terbaru
tokio = { version = "1", features = ["full"] }

```

## 2. Contoh Kode Rust
Anda bisa menggunakan fungsi `reqwest::get` untuk mengambil response, lalu mengubahnya menjadi teks menggunakan `.text()`.
```rust
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Tentukan URL raw GitHub yang ingin dituju
    let url = "cara menggunakan reqwest https://github.com/{owner}/{repo}/raw/main/file";

    // 2. Kirim GET request
    let response = reqwest::get(url).await?;

    // 3. Pastikan request sukses (status 200 OK)
    if response.status().is_success() {
        // 4. Ambil isi file sebagai String
        let content = response.text().await?;
        println!("Isi file:\n{}", content);
    } else {
        println!("Gagal mengambil file. Status: {}", response.status());
    }

    Ok(())
}

```

### 💡 Tips Penting
- Perubahan URL: Perhatikan bahwa URL mentah GitHub biasanya otomatis dialihkan (*redirect*) dari `github.com/{owner}/{repo}/raw/...` ke `://githubusercontent.com{owner}/{repo}/...`. Library reqwest secara otomatis menangani redirect ini, jadi Anda bisa menggunakan kedua format URL tersebut.
- Repository Privat: Jika file berada di *private repository*, Anda harus menggunakan `reqwest::Client` dan menambahkan *header* berisi **Personal Access Token (PAT)** GitHub Anda seperti ini:
```rust
let client = reqwest::Client::new();
let response = client.get(url)
    .header("Authorization", format!("token {}", YOUR_GITHUB_TOKEN))
    .send()
    .await?;

```

---

aa: 
bisa menggunakan `reqwest` tanpa `tokio` dengan cara mengaktifkan fitur `blocking`. Fitur ini membuat `reqwest` berjalan secara sinkronus (synchronous), sehingga Anda tidak memerlukan runtime async maupun *keyword* `async/await`.

Berikut adalah cara konfigurasi dan contoh kodenya:

## 1. Tambahkan Dependencies
Di file `Cargo.toml`, Anda harus mengaktifkan fitur `blocking` secara eksplisit:
```toml
[dependencies]
reqwest = { version = "0.12.28", features = ["blocking"] }

```

## 2. Contoh Kode Rust (Sinkronus)
Gunakan modul `reqwest::blocking` untuk melakukan request. Kode akan dieksekusi baris demi baris secara langsung di fungsi `main` biasa:
```rust
fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Tentukan URL raw GitHub
    let url = "https://githubusercontent.com";

    // 2. Kirim GET request secara blocking (tanpa .await)
    let response = reqwest::blocking::get(url)?;

    // 3. Pastikan request sukses
    if response.status().is_success() {
        // 4. Ambil isi file sebagai String
        let content = response.text()?;
        println!("Isi file:\n{}", content);
    } else {
        println!("Gagal mengambil file. Status: {}", response.status());
    }

    Ok(())
}

```

## ⚠️ Kapan sebaiknya tidak menggunakan cara ini?
Gunakan fitur `blocking` ini jika program Anda adalah aplikasi CLI sederhana atau skrip kecil. Namun, jika Anda sedang membuat aplikasi web server (seperti Axum/Actix) atau aplikasi UI yang membutuhkan performa tinggi, cara sinkronus ini akan mengunci (*block*) thread utama dan membuat aplikasi terasa membeku.

qa: 
Apakah Anda ingin tahu cara **menyimpan file tersebut langsung ke harddisk** setelah diunduh, atau ada kebutuhan lain untuk mengolah isi filenya? Let me know!

---

aa: 
Perbedaan utama antara menggunakan **Tokio (Async/Asinkronus)** dan tidak menggunakan Tokio (**Blocking/Sinkronus**) terletak pada **bagaimana program Anda menunggu** proses download selesai.

Berikut adalah perbandingan langsungnya:


| Fitur | Menggunakan Tokio (Async) | Tanpa Tokio (Blocking) |
| :--- | :--- | :--- |
| **Cara Kerja** | **Non-blocking.** Saat menunggu file di-download, thread tidak menganggur dan bisa mengerjakan tugas lain. | **Blocking.** Thread utama berhenti total (terkunci) sampai proses download selesai. |
| **Kecepatan Download Masal** | **Sangat Cepat.** Bisa men-download 10-100 file dari GitHub secara bersamaan *(concurrently)*. | **Lambat.** Harus men-download file satu per satu secara bergantian (antre). |
| **Kebutuhan Resource** | **Ringan.** Efisien dalam penggunaan memori dan CPU untuk operasi jaringan skala besar. | **Boros.** Jika ingin melakukan banyak download bersamaan, Anda harus membuat thread OS baru yang memakan banyak memori. |
| **Kompleksitas Kode** | **Lebih Kompleks.** Membutuhkan keyword `async`, `.await`, dan runtime `#[tokio::main]`. | **Sangat Sederhana.** Seperti kode linear/biasa pada umumnya, tanpa fungsi khusus. |

---

## Analogi Sederhana: Memesan Kopi di Kafe ☕
- Tanpa Tokio (Blocking / Sinkronus):
Anda memesan kopi di kasir, lalu **Anda berdiri diam di depan kasir** menunggu barista membuatkan kopi Anda. Orang di belakang Anda tidak bisa memesan, dan Anda tidak bisa melakukan hal lain sampai kopi ada di tangan Anda.
- Menggunakan Tokio (Async / Asinkronus):
- Anda memesan kopi, kasir memberi Anda **nomor antrean (`Future`)**, lalu Anda bisa duduk sambil membaca buku atau membalas pesan. Ketika kopi selesai dibuat, nomor Anda dipanggil (`.await`), dan Anda mengambil kopinya.

---

## Kapan Harus Memilih Salah Satu?
### Gunakan Tanpa Tokio (Blocking) jika:
- Anda hanya membuat script CLI sederhana atau aplikasi kecil.
- Anda hanya perlu men-download satu atau beberapa file saja secara berurutan.
- Anda ingin kode yang bersih, pendek, dan mudah dipahami tanpa pusing memikirkan konsep *async*.

### Gunakan Dengan Tokio (Async) jika:
- Anda sedang membuat **Web Server** (seperti Axum, Actix-web) atau aplikasi GUI/Game agar aplikasi tidak *freeze* (membeku) saat men-download.
- Anda perlu men-download puluhan atau ratusan file dari GitHub secara bersamaan agar cepat selesai.
- Project Anda sudah menggunakan library lain yang berbasis async.

qa: 
Apakah Anda berencana menggunakan kode ini untuk **men-download banyak file sekaligus**, atau hanya **satu file sekali jalan**? Saya bisa bantu sesuaikan arsitekturnya.






























<br>
