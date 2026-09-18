

```bash
  echo -n "Masukkan pilihan Anda: "
  read -r pilihan

  if [[ "$pilihan" == "q" || "$pilihan" == "Q" ]]; then
    # ... Logika Keluar ...
    break
  fi

  if [[ "$pilihan" == "n" || "$pilihan" == "N" ]]; then
    # ... Logika Buat File ...
    continue # <-- Mengandalkan continue agar tidak jeblos ke bawah
  fi

  if [[ "$pilihan" == "e" || "$pilihan" == "E" ]]; then
    # ... Logika Edit File ...
    continue # <-- Mengandalkan continue agar tidak jeblos ke bawah
  fi

  # Logika angka langsung dieksekusi di bawah jika tidak ada 'continue' di atas
  if [[ "$pilihan" =~ ^[0-9]+$ ]] && ...

```

