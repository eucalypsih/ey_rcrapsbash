

```bash
# =====================================================================
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / default
# =====================================================================
current_branch="main" # Nilai default awal

if [ -d "$rp/.git" ]; then
  # Mengambil nama branch saat ini
  detected_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
  
  # PERBAIKAN: Memeriksa apakah $detected_branch tidak kosong
  if [ -n "$detected_branch" ]; then
    current_branch="$detected_branch"
    echo "Branch saat ini adalah: ${current_branch}"
  else
    echo "Error: Branch tidak ditemukan!"
    exit 1
  fi
else
  # PERBAIKAN: Menangani kondisi jika direktori .git tidak ada
  echo "Error: Ini bukan repositori Git (direktori .git tidak ditemukan)!"
  exit 1
fi

sleep 2.5

# =====================================================================

```

---

```bash
current_branch="main" # Nilai default awal

if [ -d "$rp/.git" ]; then
  echo "Memeriksa repositori Git pada: $rp..."
  
  # Mengambil nama branch saat ini
  detected_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
  
  if [ -n "$detected_branch" ]; then
    current_branch="$detected_branch"
    echo "[OK] Berhasil mendeteksi branch aktif."
    echo "     -> Branch saat ini adalah: '${current_branch}'"
  else
    # Mengantisipasi jika Git valid tapi dalam kondisi Detached HEAD (tidak di branch manapun)
    latest_commit=$(git -C "$rp" rev-parse --short HEAD 2>/dev/null)
    echo "[ERROR] Gagal mengambil nama branch aktif!"
    echo "        Kemungkinan repositori dalam kondisi 'Detached HEAD' pada commit: ${latest_commit:-Tidak diketahui}"
    exit 1
  fi
else
  echo "[ERROR] Direktori target bukan repositori Git yang valid!"
  echo "        -> Pastikan folder '$rp' memiliki direktori '.git'."
  exit 1
fi

sleep 2.5

```

```bash
# =====================================================================
# TAMBAHAN PERBAIKAN: Deteksi branch utama secara dinamis / otomatis
# =====================================================================
if [ -d "$rp/.git" ]; then
    # Ambil nama branch aktif saat ini
    detected_branch=$(git -C "$rp" branch --show-current 2>/dev/null)
    
    # Jika branch kosong (Detached HEAD), ambil default branch dari remote HEAD
    if [ -z "$detected_branch" ]; then
        detected_branch=$(git -C "$rp" rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|^origin/||')
    fi
    current_branch="${detected_branch:-main}"
else
    current_branch="main"
fi
# =====================================================================

```


