# 



Jika indikator `[ daftar aktif ]` hanya ingin dimunculkan untuk repositori yang **sudah di-clone** dan **memiliki folder fisik di lokal** (sama seperti indikator `[ lokal aktif ]` di menu sparse-checkout), maka bagian perulangan daftar repositori diubah menjadi seperti ini:

```bash
  if [ ${#valid_repos[@]} -eq 0 ]; then
    _e "File '${repo_file}' kosong! Silakan isi nama repositori terlebih dahulu."
  else
    for i in "${!valid_repos[@]}"; do
      # Memisahkan owner dan nama repo
      owner_name="${valid_repos[$i]%%/*}"
      local_repo_name="${valid_repos[$i]#*/}"
      
      status_str=""
      status_args=()
      
      # Indikator [ daftar aktif ] HANYA muncul jika folder fisik .git sudah tersedia di lokal
      if [ -d "${PWD}/${owner_name}/${local_repo_name}/.git" ]; then
        status_str=" %b[ daftar aktif ]%b"
        status_args+=("${GREEN}" "${NC}")
      fi
      
      printf " [%d] %-30s${status_str}\n" $((i+1)) "${valid_repos[$i]}" "${status_args[@]}"
    done
  fi

```

### Ringkasan Perubahan:
- Kondisi Terbalik secara Aman: Sekarang teks `[ daftar aktif ]` dibungkus di dalam kondisi `if [ -d .../.git ]`.
- Visual Bersih: Repositori yang tertulis di `rp.txt` tetapi belum di-clone/dihapus folder fisiknya tidak akan memunculkan emblem warna apa pun (polos), sehingga Anda tahu mana repo yang siap digunakan secara luring (*offline*) dan mana yang belum di-clone.










<br>

