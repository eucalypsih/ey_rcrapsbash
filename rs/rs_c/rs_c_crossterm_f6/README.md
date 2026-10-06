# 

Untuk membuat fungsi pencetakan log sukses yang menerima **6 parameter** dengan format dinamis dan bergaya standar industri murni menggunakan `crossterm`, kita harus merancang fungsinya agar menerima array dari teks statis (label) dan teks dinamis (nilai variabel).

Dalam *idiomatic Rust*, penanganan cetak terminal beruntun yang aman dan efisien dilakukan dengan melemparkan referensi teks `&str` ke dalam engine `execute!` milik `crossterm`.

Berikut adalah implementasi fungsi `_ls6` beserta contoh cara memanggilnya di dalam berkas `src/utils.rs` (atau tempat fungsi `_ls` Anda berada):

---

## 🛠️ Implementasi Fungsi `_ls6` di `src/utils.rs`
Buka berkas `src/utils.rs`, lalu sematkan fungsi baru ini di bawah fungsi `_ls` lama Anda:
```rust
use std::io::{self, Stdout, Write};
use crossterm::{
    execute,
    style::{Color, Print, ResetColor, SetForegroundColor},
};

/// Fungsi pembantu eksternal untuk mencetak log sukses panjang dengan 6 komponen parameter.
/// Output divalidasi dan dicetak secara eksplisit menggunakan engine Crossterm.
pub fn _ls6(
    label1: &str, val1: &str, 
    label2: &str, val2: &str, 
    label3: &str, val3: &str
) {
    let mut stdout: Stdout = io::stdout();

    // Eksekusi rangkaian modifikasi warna dan karakter teks secara linear
    let hasil_render: Result<(), io::Error> = execute!(
        stdout,
        // Komponen 1: Hijau [✓] Sukses Branch saat ini terdeteksi:
        SetForegroundColor(Color::Green),
        Print("[✓] "),
        Print(label1),
        Print(" "),

        // Komponen 2: Kuning "$current_branch"
        SetForegroundColor(Color::Yellow),
        Print(val1),
        Print(" "),

        // Komponen 3: Hijau "berada di repo"
        SetForegroundColor(Color::Green),
        Print(label2),
        Print(" "),

        // Komponen 4: Kuning "$repo"
        SetForegroundColor(Color::Yellow),
        Print(val2),
        Print(" "),

        // Komponen 5: Hijau "menggunakan key"
        SetForegroundColor(Color::Green),
        Print(label3),
        Print(" "),

        // Komponen 6: Kuning "$owner"
        SetForegroundColor(Color::Yellow),
        Print(val3),

        // Kembalikan warna terminal ke bawaan sistem dan cetak baris baru
        ResetColor,
        Print("\n")
    );

    // Tangkap evaluasi I/O Stream secara ekspresif jika rendering gagal
    if let Err(eror_io) = hasil_render {
        let eror_fisik: io::Error = eror_io;
        log::warn!("Gagal merender log visual komponen _ls6: {}", eror_fisik);
    }
}

```

---

## 🚀 Cara Memanggil Fungsinya di `src/main.rs`
Sekarang, Anda bisa langsung memanggil fungsi tersebut dari dalam loop utama `src/main.rs` tempat data Git terdeteksi. Teks tipe data argumennya dikunci secara eksplisit:
```rust
// Contoh data simulasi biner string yang didapat dari modul branch & repo Anda
let current_branch: String = "main".to_string();
let repo: String = "ey_rcrapsbash".to_string();
let owner: String = "eucalypsih".to_string();

// MEMANGGIL FUNGSI DENGAN DEKLARASI PARAMETER EKSPLISIT
utils::_ls6(
    "Sukses Branch saat ini terdeteksi:", &current_branch,
    "berada di repo:", &repo,
    "menggunakan key:", &owner
);

```

---

## 🔍 Hasil Cetakan Visual di Layar Termux Anda:
Saat kode di atas dieksekusi, baris kalimat tersebut akan tercetak di terminal dengan penataan warna yang sangat rapi:

`[✓] Sukses Branch saat ini terdeteksi: main berada di repo: ey_rcrapsbash menggunakan key: eucalypsih`

## 💡 Mengapa Struktur Ini Sangat Bagus?
1. Zero Memory Allocation: Fungsi ini tidak melakukan penyambungan string (`+`) atau alokasi heap baru lewat fungsi `.to_string()` atau makro `format!()`. Semua data langsung didorong murni ke *buffer stream* terminal sehingga eksekusinya secepat kilat.
2. Type Safety: Setiap komponen dilindungi oleh referensi `&str` yang menjamin memori aplikasi Anda terkelola secara efisien tanpa ancaman `leak`.

Sistem pencetakan log multi-parameter berbasis crossterm ini sekarang sudah siap 100%.



<br>
