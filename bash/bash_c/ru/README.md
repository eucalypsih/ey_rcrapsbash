

```bash
# Ambil URL remote origin (contoh: git@github.com:eucalypsih/ey_rcrapsbash.git)
remote_url=$(git -C "$rp" config --get remote.origin.url 2>/dev/null)

```

```bash
if [ -n "$remote_url" ]; then
  # Ekstraksi nama repositori dari baris terakhir URL remote (menghapus ekstensi .git)
  r=$(basename "$remote_url" .git 2>/dev/null)
fi

```





