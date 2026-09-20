

Untuk membuat variabel `$rp` (repository path) menjadi lebih dinamis, **Anda bisa menggunakan beberapa metode pendekatan tergantung bagaimana cara Anda ingin mengeksekusi skrip ini**.

Berikut adalah **3 metode terbaik** untuk membuat `$rp` dinamis, dari yang paling otomatis hingga yang fleksibel menggunakan argumen:

---

### Metode 1: Menggunakan Direktori Saat Ini secara Otomatis (Rekomendasi Utama)
Jika skrip ini akan ditaruh di dalam folder proyek atau dieksekusi langsung dari folder target, Anda bisa mendeteksi lokasi *Current Working Directory* menggunakan `$PWD`.
```bash
# ==============================================================================
# PERBAIKAN DINAMIS: Menggunakan argumen pertama ($1), jika kosong gunakan $PWD
# ==============================================================================
# Otomatis mengambil folder tempat terminal Anda sedang berada saat ini
rp="$PWD"

```

---

### Metode 2: Menggunakan Argumen Input Terminal (Paling Fleksibel)
Anda bisa menentukan folder target saat menjalankan skrip melalui terminal, misalnya: `./skrip.sh /path/ke/folder/git`. Jika Anda lupa memasukkan argumen, skrip akan otomatis menggunakan folder saat ini (`$PWD`) sebagai cadangan (*fallback*).
```bash
# Jika argumen pertama ($1) tidak diisi, gunakan direktori aktif saat ini ($PWD)
rp="${1:-$PWD}"

```

---

Metode 3: Mencari Direktori `.git` Terdekat ke Atas (Sistem Otomatis)
Jika skrip dieksekusi di dalam subfolder dari sebuah proyek Git (bukan di root folder), skrip biasa akan gagal. Metode ini akan mencari ke atas sampai menemukan folder root yang berisi `.git`.
```bash
# Mencari folder root Git dari lokasi saat ini ke atas
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$git_root" ]; then
  rp="$git_root"
else
  # Jika sama sekali bukan di dalam proyek Git, gunakan folder saat ini untuk memicu error bawaan skrip
  rp="$PWD"
fi

```

---











