# 

## 💡 Tips Jika Tampilan Layar Menjadi Berantakan (Glitch)
Terkadang, setelah keluar dari mode layout, teks GEF dan prompt perintah bertumpuk atau rusak karena ukuran layar Termux yang kecil. Jika itu terjadi, cukup ketik perintah ini untuk menyegarkan (*refresh*) layar:
```text
shell clear

```

## 🛠️ Perintah Bonus GEF Khusus untuk Memantau Syscall brk (214)
- `vmmap` Ketik gef➤ vmmap sebelum dan sesudah instruksi svc #0. Anda akan melihat baris baru bertuliskan [heap] muncul di dalam tabel pemetaan memori RAM virtual aplikasi Anda, lengkap dengan rentang alamat memori heksadesimalnya.

```textq
tui disable

```


```text
info proc mappings

```

```text
shell cat /proc/self/maps

```

Saya ingin otomatis mencetak isi **alamat memori di register `x19`** setiap kali melangkah?




```text
gdb -q -ex "starti" ${rp}/kernel/kernel_s_clang_termux_aarch64/main

```



<br>
