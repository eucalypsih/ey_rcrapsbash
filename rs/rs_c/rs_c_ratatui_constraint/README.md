# 

- `https://github.com/ratatui/ratatui/blob/main/ratatui-core/src/layout/constraint.rs`

Berkas `ratatui-core/src/layout/layout.rs` merupakan tempat untuk deklarasi struktur utama pengatur tata letak, yaitu `pub struct Layout` beserta logika pembagian layarnya (seperti fungsi `split` dan `areas`).

Pada struktur repositori terbaru Ratatui, `Constraint` dipisahkan ke dalam berkas tersendiri. Berkas yang tepat untuk deklarasi enum tersebut adalah:



---

qa: 
Apakah Anda sedang menelusuri kode sumber Ratatui untuk **mempelajari algoritma internal kasuari (layout solver)** atau sekadar ingin tahu **cara kerja varian baru `Constraint::Fill`** yang ada di versi modern ini?

## 👉 `ratatui-core/src/layout/constraint.rs`
```rust
pub enum Constraint {
    Min(u16),
    Max(u16),
    Length(u16),
    Percentage(u16),
    Ratio(u32, u32),
    Fill(u16),
}

```

## 1. `Constraint` adalah sebuah Enum murni
Di dalam pustaka Ratatui, `Constraint` dirancang sebagai sebuah `enum` biasa (bukan generik). Varian `Percentage` di dalamnya langsung menerima tipe data angka integer standar (biasanya `u16`).

## 2. Penulisan Idiomatik yang Tepat
Jika Anda ingin menuliskan tipe datanya secara super eksplisit tanpa melanggar sintaksis Rust, Anda cukup menegaskan tipe data angka integer di dalam argumennya saja, seperti ini:
- Sintaksis Standar (Disarankan):
```rust
Constraint::Percentage(5)

```

- Sintaksis Eksplisit Murni (Tipe Data Angka Ditegaskan):
```rust
Constraint::Percentage(5_u16)

```
Jadi, penulisan `Constraint::Percentage::<u16>(5)` justru akan menghasilkan **error kompilasi** (*compile error*) karena varian enum tersebut tidak memiliki parameter generik `<T>` yang perlu diisi.






<br>
