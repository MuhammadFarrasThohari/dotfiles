#!/bin/bash

# --- Konfigurasi ---
# Pastikan kamu punya Nerd Font yang terpasang!
#
# Ikon untuk status:
ICON_WIFI_ENABLED="󰤥"
ICON_WIFI_DISABLED="󰤯"
ICON_WIFI_SECURE=""
ICON_WIFI_OPEN=""
ICON_WIFI_SIGNAL_HIGH="󰤥"
ICON_WIFI_SIGNAL_MID="󰤢"
ICON_WIFI_SIGNAL_LOW="󰤟"
ICON_WIFI_SIGNAL_NONE="󰤯"
ICON_MENU_CONNECT="check" # Tidak digunakan di sini, tapi bagus untuk notifikasi
ICON_MENU_DISCONNECT="󰤮"
ICON_MENU_REFRESH="󰑐"
ICON_MENU_EXIT="cancel"

INTERFACE=$(nmcli device status | grep wifi | awk '{print $1}')

# --- Theme Rofi ---
# Menyuntikkan theme CSS-based (.rasi) sederhana langsung ke Rofi
# untuk tampilan yang bersih dan modern.
THEME_STR="window {width: 350px; border-radius: 12px; padding: 18px;} \
           listview {lines: 6; spacing: 5px; columns: 1;} \
           element {padding: 10px 12px; border-radius: 8px;} \
           element-icon {size: 1.5em; vertical-align: 0.5;} \
           element-text {vertical-align: 0.5;} \
           element selected {background-color: #5294e2; text-color: #f8f8f2;}" # Ganti #5294e2 dengan warna aksen-mu

# --- Perintah Rofi ---
# Menggunakan theme string di atas
ROFI_CMD="rofi -dmenu -i -p 'WiFi' -theme-str \"$THEME_STR\""

# --- Fungsi ---

# Fungsi untuk mendapatkan daftar WiFi dengan ikon
get_wifi_list() {
    # 1. Daftar Jaringan WiFi yang Tersedia
    # Kita akan parse SSID, SIGNAL, dan SECURITY
    WIFI_LIST=$(nmcli -g SSID,SIGNAL,SECURITY device wifi list | \
    awk 'BEGIN{FS=":"} {
        signal=$2;
        security=$3;
        
        # Tentukan ikon sinyal berdasarkan kekuatan
        if (signal > 75) sig_icon="'$ICON_WIFI_SIGNAL_HIGH'";
        else if (signal > 50) sig_icon="'$ICON_WIFI_SIGNAL_MID'";
        else if (signal > 25) sig_icon="'$ICON_WIFI_SIGNAL_LOW'";
        else sig_icon="'$ICON_WIFI_SIGNAL_NONE'";
        
        # Tentukan ikon keamanan
        if (security == "" || security == "--") sec_icon="'$ICON_WIFI_OPEN'";
        else sec_icon="'$ICON_WIFI_SECURE'";
        
        # Format: [SSID] [IKON SINYAL] [IKON KEAMANAN]
        # Kita gunakan printf untuk padding agar rapi
        printf "%-25.25s %-4s %s\n", $1, sig_icon, sec_icon
    }')
    
    # 2. Opsi Menu Tambahan
    MENU_DISCONNECT="$ICON_MENU_DISCONNECT Disconnect"
    MENU_REFRESH="$ICON_MENU_REFRESH Refresh"
    
    # 3. Gabungkan semua dan tampilkan di Rofi
    echo -e "$MENU_DISCONNECT\n$MENU_REFRESH\n$WIFI_LIST"
}

# Fungsi untuk koneksi ke jaringan
connect_wifi() {
    local SELECTED_SSID=$1
    local KEY

    # Cek apakah jaringan terenkripsi (SECURITY tidak kosong)
    local SECURITY=$(nmcli -t -f SECURITY device wifi list | grep "$SELECTED_SSID" | head -n 1)

    if [[ -z "$SECURITY" || "$SECURITY" == "--" ]]; {
        # Jaringan terbuka (Open)
        nmcli device wifi connect "$SELECTED_SSID" ifname "$INTERFACE"
        notify-send "$ICON_WIFI_ENABLED Connecting to" "$SELECTED_SSID (Open)"
    } else {
        # Jaringan terenkripsi (Password diperlukan)
        # Gunakan theme yang sama untuk password prompt
        KEY=$(rofi -dmenu -password -i -p "$ICON_WIFI_SECURE Password:" -theme-str "$THEME_STR")
        
        if [[ -n "$KEY" ]]; then
            nmcli device wifi connect "$SELECTED_SSID" password "$KEY" ifname "$INTERFACE"
            notify-send "$ICON_WIFI_ENABLED Connecting to" "$SELECTED_SSID (Secured)"
        else
            notify-send "$ICON_MENU_EXIT Connection cancelled" "No password provided."
        fi
    }

    # Cek status koneksi
    if [ $? -eq 0 ]; then
        sleep 1
        notify-send "Connected!" "$(nmcli -t -f NAME connection show --active | head -n 1)"
    else
        notify-send "Connection Failed!" "Check password or logs."
    fi
}

# --- Logika Utama ---

# 1. Cek status WiFi
if nmcli radio wifi | grep -q 'disabled'; then
    # Jika WiFi dinonaktifkan
    ENABLE_WIFI=$(echo -e "$ICON_WIFI_ENABLED Enable WiFi\n$ICON_MENU_EXIT Exit" | $ROFI_CMD)
    if [[ "$ENABLE_WIFI" == "$ICON_WIFI_ENABLED Enable WiFi" ]]; then
        nmcli radio wifi on
        notify-send "WiFi Enabled" "Scanning for networks..."
        sleep 2
    else
        exit 0
    fi
fi

# 2. Tampilkan daftar WiFi
SELECTED_NETWORK=$(get_wifi_list | $ROFI_CMD)

# 3. Handle Pilihan
case "$SELECTED_NETWORK" in
    "$ICON_MENU_DISCONNECT Disconnect")
        nmcli device disconnect "$INTERFACE"
        notify-send "$ICON_MENU_DISCONNECT Disconnected" "from active network."
        ;;
    "$ICON_MENU_REFRESH Refresh")
        nmcli device wifi rescan
        notify-send "$ICON_MENU_REFRESH Refreshing" "Scanning for networks..."
        ;;
    "")
        # Rofi dibatalkan (Esc)
        exit 0
        ;;
    *)
        # Dapatkan SSID dari pilihan (parsing kolom pertama)
        SSID=$(echo "$SELECTED_NETWORK" | awk '{print $1}')
        connect_wifi "$SSID"
        ;;
esac
