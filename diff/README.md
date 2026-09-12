#

Flag atau parameter `-r` (atau `--recursive`) pada perintah `diff` digunakan untuk **membandingkan seluruh isi folder (direktori) beserta sub-folder di dalamnya secara rekursif (berakar/mendalam), bukan hanya membandingkan satu file tunggal**.

Berikut adalah rincian pengaruh penggunaan `-r` berdasarkan situasi kompilasi Anda:

1. Pengaruh Jika Membandingkan Folder ke Folder (`diff -u -r $HOME/gawk-5.4.1 $HOME/gawk-5.4.1-mod`)
Jika Anda membandingkan dua buah direktori, flag `-r` sangat penting.
- Dengan `-r`: Sistem akan menelusuri setiap file di dalam folder tersebut hingga sub-folder terdalam. Jika ada file yang berbeda, baru atau dihapus, semuanya akan dicatat ke dalam satu file patch tunggal.
- Tanpa `-r`: Perintah `diff` akan langsung menolak berjalan atau mengabaikan sub-folder di dalamnya dengan memunculkan pesan eror semacam `"diff: folder1: Is a directory"`.






<br>
