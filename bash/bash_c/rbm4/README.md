# 

## Perbarui Script `rsm3.sh` dengan Blok Anti-Stuck Konten
Untuk mengantisipasi agar loop tidak terhenti saat mendeteksi `CONFLICT (content)` (bukan hanya modify/delete), kita harus menggunakan taktik penyelesaian konflik berbasis penanda file mentah unmerged.
```bash
#!/usr/bin/env bash

# Pastikan script berhenti jika terjadi error fatal di luar blok pengecekan
set -e

REPO_PATH="$HOME/eucalypsih/ey_rcrapsbash"

echo "=== AUTOMATIC MULTI-COMMIT FOLDER-TARGET DROPPER ==="
echo "Target Repositori : $REPO_PATH"
echo "--------------------------------------------------------"

# 1. Minta input folder target
read -p "Masukkan jalur folder target (contoh: bash/bash_c_u36/): " SPECIFIC_FOLDER

if [ -z "$SPECIFIC_FOLDER" ]; then
    echo "❌ Jalur folder tidak boleh kosong!"
    exit 1
fi

echo ""
# 2. Tampilkan 15 commit terakhir khusus folder tersebut
echo "📊 Menampilkan 15 commit terakhir khusus folder: $SPECIFIC_FOLDER"
echo "--------------------------------------------------------"
git -C "$REPO_PATH" log --oneline -n 15 -- "$SPECIFIC_FOLDER"
echo "--------------------------------------------------------"
echo ""

# 3. Minta input banyak hash commit sekaligus yang ingin dibuang
echo "Masukkan Commit Hash yang ingin DIHAPUS dari folder ini."
echo "Petunjuk: Jika lebih dari satu, pisahkan dengan spasi."
read -p "Masukkan Hash Commit: " -a COMMITS_TO_DROP

if [ ${#COMMITS_TO_DROP[@]} -eq 0 ]; then
    echo "❌ Commit Hash tidak boleh kosong!"
    exit 1
fi

echo ""
echo "🚀 Memulai proses penghapusan berantai untuk ${#COMMITS_TO_DROP[@]} commit..."
echo "--------------------------------------------------------"

# 4. LOOP UTAMA: Memproses setiap commit satu per satu
for DROP_COMMIT in "${COMMITS_TO_DROP[@]}"; do
    echo "⚙️  Memproses penghapusan commit: $DROP_COMMIT"
    
    # Validasi apakah commit tersebut masih ada di silsilah Git saat ini
    if ! git -C "$REPO_PATH" rev-parse --verify "$DROP_COMMIT" >/dev/null 2>&1; then
        echo "⚠️  Commit Hash ($DROP_COMMIT) sudah terhapus di putaran sebelumnya. Melewati..."
        continue
    fi

    # Lacak commit tepat SEBELUM commit yang akan dihapus
    BASE_COMMIT=$(git -C "$REPO_PATH" rev-parse "${DROP_COMMIT}~1")

    echo "✂️  Target Hapus : $DROP_COMMIT"
    echo "🔗 Menyambungkan kembali riwayat ke posisi: $BASE_COMMIT"

    # Jalankan Rebase Onto secara otomatis
    set +e
    git -C "$REPO_PATH" rebase --onto "$BASE_COMMIT" "$DROP_COMMIT" main
    REBASE_STATUS=$?
    set -e

    # 5. Loop Otomatis Penanganan Konflik Komprehensif (Anti-Stuck untuk Segala Jenis Konflik)
    while [ -d "$REPO_PATH/.git/rebase-merge" ] || [ -d "$REPO_PATH/.git/rebase-apply" ]; do
        echo "   ⚠️  Mendeteksi adanya konflik (content / modify-delete) pada putaran ini."
        echo "   ⚡ Memulihkan kode terbaru secara otomatis..."
        
        # Ambil daftar file berkonflik ke dalam array lokal agar terhindar dari pemutusan buffer sub-shell
        mapfile -t CONFLICTED_FILES < <(git -C "$REPO_PATH" diff --name-only --diff-filter=U)
        
        for FILE in "${CONFLICTED_FILES[@]}"; do
            if [ -n "$FILE" ]; then
                # Paksa ambil kondisi file versi terbaru dari commit atas (--theirs)
                git -C "$REPO_PATH" checkout --theirs "$FILE" 2>/dev/null || true
                git -C "$REPO_PATH" add "$FILE"
            fi
        done
        
        echo "   🔄 Melanjutkan proses rebase..."
        set +e
        GIT_EDITOR=true git -C "$REPO_PATH" rebase --continue
        REBASE_STATUS=$?
        set -e
        
        if [ $REBASE_STATUS -eq 0 ]; then
            break
        fi
    done
    echo "✅ Commit $DROP_COMMIT berhasil dicabut."
    echo "--------------------------------------------------------"
done

echo ""
echo "🎉 SELESAI SUKSES TOTAL!"
echo "📊 Menampilkan 10 riwayat log terbaru folder setelah pembersihan:"
echo "--------------------------------------------------------"
git -C "$REPO_PATH" log --oneline -n 10 -- "$SPECIFIC_FOLDER"
echo "--------------------------------------------------------"
echo "🔗 Mengotomatiskan sinkronisasi pembaruan riwayat ke GitHub..."
git -C "$REPO_PATH" push origin main --force-with-lease

```



<br>
