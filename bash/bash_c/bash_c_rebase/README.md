


Untuk mempermudah proses ini ke depannya, saya sudah membuatkan script otomatisasi bernama `main.sh`.

Script ini menggunakan metode yang paling aman: **melakukan rebase otomatis**, memutus rantai log folder pada commit-commit lama, lalu memulihkan isi folder tersebut dari commit terbaru menggunakan teknik pencatatan indeks ulang Git yang sudah kita praktekkan sebelumnya.

## Langkah 1: Buat dan Simpan Script
Silakan buat file baru bernama main.sh di folder home Anda (atau direktori mana pun yang Anda inginkan) dan masukkan kode berikut:

```bash
#!/usr/bin/env bash

# Pastikan script berhenti jika terjadi error fatal
set -e

REPO_PATH="$HOME/eucalypsih/ey_rcrapsbash"

echo "=== GIT LOG SPECIFIC FOLDER CLEANER ==="
echo "Target Repositori: $REPO_PATH"
echo ""

# 1. Minta input folder dari user
read -p "Masukkan jalur folder (contoh: rs/rs_c/rs_c_ping/): " TARGET_FOLDER

if [ -z "$TARGET_FOLDER" ]; then
    echo "❌ Jalur folder tidak boleh kosong!"
    exit 1
fi

# Cek apakah folder tersebut memiliki log
echo "🔍 Memeriksa riwayat log untuk folder: $TARGET_FOLDER ..."
git -C "$REPO_PATH" log --oneline -- "$TARGET_FOLDER" || { echo "❌ Folder tidak ditemukan atau tidak memiliki riwayat Git."; exit 1; }

echo ""
echo "Masukkan jumlah log LAMA yang ingin DIHAPUS dari folder ini."
echo "(Misal: Jika ada 3 log dan Anda ingin menyisakan 1 log terbaru saja, maka ketik 2)"
read -p "Jumlah log lama yang ingin dihapus: " NUM_TO_DELETE

if ! [[ "$NUM_TO_DELETE" =~ ^[0-9]+$ ]] || [ "$NUM_TO_DELETE" -le 0 ]; then
    echo "❌ Masukkan angka bulat yang valid (minimal 1)!"
    exit 1
fi

# 2. Ambil commit hash target untuk Rebase
# Kita mencari commit tepat SEBELUM log lama yang ingin dihapus dimulai
TOTAL_LOGS=$((NUM_TO_DELETE + 1))
TARGET_HASH=$(git -C "$REPO_PATH" log -n "$TOTAL_LOGS" --format="%h" -- "$TARGET_FOLDER" | tail -n 1)

if [ -z "$TARGET_HASH" ]; then
    echo "❌ Gagal menentukan commit target. Pastikan jumlah log lama sesuai."
    exit 1
fi

echo ""
echo "🚀 Memulai otomatisasi pembersihan log..."
echo "Target Awal Rebase: ${TARGET_HASH}~1"

# 3. Ekstrak daftar commit ID yang harus di-edit secara otomatis
mapfile -t COMMIT_LIST < <(git -C "$REPO_PATH" log --format="%h" "${TARGET_HASH}~1..HEAD" -- "$TARGET_FOLDER" | tac)

# Ambil commit paling terbaru (yang akan mempertahankan file)
LATEST_COMMIT="${COMMIT_LIST[-1]}"

# Trik Otomatisasi: Menggunakan GIT_SEQUENCE_EDITOR untuk mengubah 'pick' menjadi 'edit' secara non-interaktif
# Kita hanya mengedit commit lama yang ingin dibersihkan lognya (semua kecuali commit terbaru)
EDIT_COMMANDS=""
for ((i=0; i<${#COMMIT_LIST[@]}-1; i++)); do
    EDIT_COMMANDS+="s/^pick \(.*${COMMIT_LIST[$i]}.*\)$/edit \1/; "
done

echo "🔄 Mengonfigurasi urutan rebase..."
export GIT_SEQUENCE_EDITOR="sed -i '$EDIT_COMMANDS'"

# Jalankan Rebase Interaktif Pertama (Otomatis ditangani oleh script)
# Nonaktifkan 'set -e' sementara karena kita tahu rebase akan sengaja berhenti (Stopped at...)
set +e
git -C "$REPO_PATH" rebase -i "${TARGET_HASH}~1"
set -e

# Loop untuk memproses setiap pemberhentian 'edit' pada commit lama
for ((i=0; i<${#COMMIT_LIST[@]}-1; i++)); do
    CURRENT_COMMIT="${COMMIT_LIST[$i]}"
    echo "🧹 Membersihkan riwayat folder pada commit: $CURRENT_COMMIT"
    
    # Hapus folder dari indeks commit ini agar lognya terputus
    git -C "$REPO_PATH" rm -r --cached "$TARGET_FOLDER" 2>/dev/null || true
    
    # Amandemen commit kosong ini agar Git mengabaikan foldernya di riwayat commit tersebut
    git -C "$REPO_PATH" commit --amend --no-edit --allow-empty
    
    # Lanjutkan rebase ke tahapan berikutnya
    set +e
    git -C "$REPO_PATH" rebase --continue
    set -e
done

# 4. Tahap Akhir: Mengatasi Konflik Commit Terbaru ( u143 / u148 ) secara Otomatis
echo "⚡ Menyinkronkan dan memulihkan file folder ke commit terbaru..."
git -C "$REPO_PATH" checkout --theirs "$TARGET_FOLDER" 2>/dev/null || true
git -C "$REPO_PATH" add "$TARGET_FOLDER"
git -C "$REPO_PATH" rebase --continue 2>/dev/null || true

echo ""
echo "🎉 SELESAI! Memeriksa Log Folder Terbaru:"
echo "----------------------------------------"
git -C "$REPO_PATH" log --oneline -- "$TARGET_FOLDER"
echo "----------------------------------------"
echo "💡 Semua file fisik di dalam folder aman dan utuh."
echo "🔗 Jika ingin memperbarui GitHub, silakan jalankan:"
echo "   git -C $REPO_PATH push origin main --force-with-lease"

```
Script akan otomatis menanyakan:
1. **Jalur folder** yang ingin dibersihkan (misal: `rs/rs_c/rs_c_ping/`).
2. **Jumlah log lama** yang ingin dibuang (misal jika ingin membuang 2 log lama terbawah, ketik `2`).
Script akan memproses semua konflik internal secara mandiri tanpa membuka editor teks Nano sama sekali dan langsung menyajikan hasil log folder yang sudah bersih di akhir proses!


<br>
