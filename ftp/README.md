

Untuk menyembunyikan pesan eror `Unable to start a standalone server` dan keluaran nomor proses bawaan dari shell (seperti `[2] 5811`), Anda perlu mengarahkan seluruh keluaran eror (*stderr*) milik Pure-FTPD ke `/dev/null` dan membungkus eksekusinya ke dalam subshell `( ... )`.

Berikut adalah perintah final yang sudah diperbaiki total. Saat dijalankan, perintah ini **hanya akan memunculkan teks roket dan alamat FTP Anda** tanpa gangguan teks sistem lainnya:
```bash
( killall pure-ftpd 2>/dev/null; IP_LO=$(ifconfig 2>/dev/null | awk -v RS="" '/lo:/ {print $0}' | awk '/inet / {print $2}' | tr -d '\n'); pure-ftpd -A -S "$IP_LO",8021 &>/dev/null & echo -e '\n🚀 Server FTP Berhasil Dijalankan!\n👉 Alamat FTP Anda: ftp://'"$IP_LO"':8021\n' )


```
- `pkill pure-ftpd 2>/dev/null`: Membunuh paksa sisa server FTP yang menggantung di latar belakang [^1] dan membuang pesan erornya jika ternyata server belum berjalan.
- 2>/dev/null: Menangkap semua pesan eror atau peringatan (*stderr*) yang dihasilkan oleh `ifconfig` dan membuangnya secara otomatis.
- `&>/dev/null &`: Bagian ini akan membungkam semua pesan sukses maupun pesan eror (seperti *Address already in use*) yang dikeluarkan oleh biner `pure-ftpd`.
- Menggunakan Tanda Kurung `( ... )`: Membungkus seluruh rangkaian perintah ke dalam *subshell* baru. Ini secara otomatis menyembunyikan notifikasi teks penanda tugas latar belakang (seperti `[2] 5811` dan `[2]+ Done`) dari terminal Anda.









<br>

