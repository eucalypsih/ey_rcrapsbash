#

Terminal Output:
```bash
$ grep -rin "execl(\"/bin/sh\", \"sh\", \"-c\"," $HOME/gawk-5.4.1-mod/
/data/data/com.termux/files/home/gawk-5.4.1-mod/io.c:2083:              execl("/bin/sh", "sh", "-c", command, NULL);
/data/data/com.termux/files/home/gawk-5.4.1-mod/io.c:2135:              execl("/bin/sh", "sh", "-c", command, NULL);
/data/data/com.termux/files/home/gawk-5.4.1-mod/io.c:2474:              execl("/bin/sh", "sh", "-c", str, NULL);
/data/data/com.termux/files/home/gawk-5.4.1-mod/io.c:2722:              execl("/bin/sh", "sh", "-c", cmd, NULL);
/data/data/com.termux/files/home/gawk-5.4.1-mod/io.c:4734:              execl("/bin/sh", "sh", "-c", cmd, NULL);
/data/data/com.termux/files/home/gawk-5.4.1-mod/builtin.c:3424:         execl("/bin/sh", "sh", "-c", command, NULL);

```

<br>

Untuk mengganti `"/bin/sh"` menjadi jalur standar Termux `"/data/data/com.termux/files/usr/bin/sh"` pada file-file tersebut menggunakan `sed`, Anda dapat menjalankan perintah berikut langsung di terminal Termux Anda:
```bash
sed -i 's|execl("/bin/sh"|execl("/data/data/com.termux/files/usr/bin/sh"|g' $HOME/gawk-5.4.1-mod/io.c $HOME/gawk-5.4.1-mod/builtin.c

```
`sed -i 's|execl("/bin/sh"|execl("/data/data/com.termux/files/usr/bin/sh"|g' $HOME/gawk-5.4.1-mod/io.c $HOME/gawk-5.4.1-mod/builtin.c`
- `-i`: Mengubah file secara langsung (*in-place*), sehingga perubahan langsung disimpan ke dalam file target.

<br>

---

<br>

Jika Anda khawatir ada baris serupa di file lain yang terlewat, Anda bisa menggabungkan `grep` dan `sed` agar mencari sekaligus mengganti di seluruh folder otomatis:

```bash
grep -rl 'execl("/bin/sh"' $HOME/gawk-5.4.1-mod/ | xargs sed -i 's|execl("/bin/sh"|execl("/data/data/com.termux/files/usr/bin/sh"|g'

```
`grep -rl 'execl("/bin/sh"' $HOME/gawk-5.4.1-mod/ | xargs sed -i 's|execl("/bin/sh"|execl("/data/data/com.termux/files/usr/bin/sh"|g'`
*(Perintah ini akan mencari daftar file yang mengandung teks tersebut, lalu mengirimkannya ke sed untuk dieksekusi sekaligus).*













<br>
