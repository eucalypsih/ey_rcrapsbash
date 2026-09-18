


```bash
current_branch=$(git -C "$rp" remote show origin | grep 'HEAD branch' | cut -d' ' -f5 2>/dev/null || echo "main")

```

```bash
o="eucalypsih"; r="ey_rcrapsbash";

# Menggunakan direktori aktif saat skrip dijalankan (pwd)
rp="${PWD}/${r}"

# =====================================================================
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
# =====================================================================
if [ -d "$rp/.git" ]; then
    current_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
fi
[ -z "$current_branch" ] && current_branch="main" 
# =====================================================================

# Kode warna untuk notifikasi terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color (Reset)

```
