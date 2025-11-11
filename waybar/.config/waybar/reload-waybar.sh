#!/bin/bash
CONFIG_DIR="$HOME/.config/waybar"
LOG_FILE="$CONFIG_DIR/reload.log"

# Pastikan inotifywait tersedia
if ! command -v inotifywait &>/dev/null; then
  echo "[ERROR] inotifywait tidak ditemukan. Jalankan: sudo pacman -S inotify-tools" | tee -a "$LOG_FILE"
  exit 1
fi

echo "[INFO] Waybar watcher aktif di $CONFIG_DIR" | tee -a "$LOG_FILE"

# Pastikan direktori dan file log ada (aman jika sudah ada)
mkdir -p "$CONFIG_DIR"
: >> "$LOG_FILE"

# Pantau semua file di folder Waybar yang diubah/disimpan
# Gunakan format terstruktur supaya parsing lebih andal: path, event, filename
inotifywait -m -r -e close_write --format '%w %e %f' "$CONFIG_DIR" | while read -r path event file; do
  # Abaikan event yang tidak menyertakan nama file (mis. event pada direktori)
  [[ -z "$file" ]] && continue

  # Cocokkan file konfigurasi Waybar (mis. config, config.json, config.jsonc) atau style.css
  if [[ "$file" == config* || "$file" == "style.css" || "$file" == "color.css" ]]; then
    echo "[RELOAD] File berubah: $path$file ($event)" | tee -a "$LOG_FILE"
    # Pastikan hanya proses bernama 'waybar' yang dikirimi sinyal
    pkill -x -SIGUSR2 waybar
  fi
done
