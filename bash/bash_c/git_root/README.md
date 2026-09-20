

```bash
o="eucalypsih"

# =====================================================================
# PERBAIKAN: DINAMIS TOTAL UNTUK REPO APA PUN (ey_repo1, ey_repo2, dst)
# =====================================================================
# 1. Cek apakah terminal sudah berada di dalam suatu proyek Git (di root atau sub-folder)
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$git_root" ]; then
    # Jika sudah di dalam folder Git, kunci target direktori ke root repositori tersebut
    rp="$git_root"
    
    # Deteksi nama repositori otomatis dari URL remote origin GitHub
    remote_url=$(git -C "$rp" config --get remote.origin.url 2>/dev/null)
    if [ -n "$remote_url" ]; then
        r=$(basename "$remote_url" .git 2>/dev/null)
    fi
fi

# 2. Fallback: Jika tidak di dalam Git, ambil nama folder terminal saat ini secara dinamis
if [ -z "$r" ]; then
    # Mengambil nama folder aktif saat ini (misal terminal di /sdcard/ey_repo2, maka r="ey_repo2")
    r=$(basename "$PWD")
    rp="$PWD"
fi

```
