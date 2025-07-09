#!/bin/bash

CONF="/etc/menubot.conf"
BOTLOG="/var/log/bot.log"
BOTPY="/usr/local/bin/bot.py"

function ensure_conf() {
    if [ ! -f "$CONF" ]; then
        echo "Membuat $CONF baru..."
        echo "[DEFAULT]" > "$CONF"
        echo "TELEGRAM_BOT_TOKEN=" >> "$CONF"
        echo "ALLOWED_CHAT_IDS=" >> "$CONF"
    fi

    if ! grep -q "^\[DEFAULT\]" "$CONF"; then
        sed -i '1i [DEFAULT]' "$CONF"
    fi
}

function edit_token() {
    ensure_conf
    read -p "Masukkan TOKEN BOT TELEGRAM baru: " token
    if grep -q "^TELEGRAM_BOT_TOKEN=" "$CONF"; then
        sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${token}|" "$CONF"
    else
        echo "TELEGRAM_BOT_TOKEN=${token}" >> "$CONF"
    fi
    echo "TOKEN diperbaharui."
}

function edit_id() {
    ensure_conf
    read -p "Masukkan ALLOWED_CHAT_IDS baru (pisahkan dengan koma): " ids
    if grep -q "^ALLOWED_CHAT_IDS=" "$CONF"; then
        sed -i "s|^ALLOWED_CHAT_IDS=.*|ALLOWED_CHAT_IDS=${ids}|" "$CONF"
    else
        echo "ALLOWED_CHAT_IDS=${ids}" >> "$CONF"
    fi
    echo "ID diupdate."
}

function start_bot() {
    pkill -f "$BOTPY" >/dev/null 2>&1
    nohup python3 $BOTPY >$BOTLOG 2>&1 &
    echo "Bot telah dijalankan. Cek log di $BOTLOG"
}

function stop_bot() {
    pkill -f "$BOTPY"
    echo "Bot dihentikan."
}

function status_bot() {
    if pgrep -f "$BOTPY" >/dev/null; then
        echo "Bot sedang berjalan."
    else
        echo "Bot tidak berjalan."
    fi
}

while true; do
clear
echo "╔════════════════════════╗"
echo "      Menu Bot Telegram  "
echo "╠════════════════════════╣"
echo " 1. Edit TOKEN"
echo " 2. Edit ALLOWED_CHAT_IDS"
echo " 3. Start Bot"
echo " 4. Stop Bot"
echo " 5. Status Bot"
echo " 0. Keluar"
echo "╚════════════════════════╝"
read -p " Pilih menu [1-5]: " opt
case $opt in
    1) edit_token ;;
    2) edit_id ;;
    3) start_bot ;;
    4) stop_bot ;;
    5) status_bot; read -p "Enter untuk kembali..." ;;
    0) exit ;;
    *) echo "Menu tidak ada!"; sleep 1 ;;
esac
done