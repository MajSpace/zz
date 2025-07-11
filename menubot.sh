#!/bin/bash

source /usr/local/bin/utils.sh

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

telegram_bot_menu() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Bot Telegram${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Tetapan TOKEN${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Tetapkan Telegram User ID${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Start Bot${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Stop Bot${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}Status Bot${RESET}"
    echo -e "${YELLOW}  0. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih menu [0-5]: ${RESET}"
    read opt
    case $opt in
      1)
        title_banner
        echo -e "${PURPLE}${BOLD}Tetapan TOKEN${RESET}"
        echo -e "${FULL_BORDER}"
        edit_token
        echo -e "${FULL_BORDER}"
        pause
        ;;
      2)
        title_banner
        echo -e "${PURPLE}${BOLD}Tetapkan Telegram User ID${RESET}"
        echo -e "${FULL_BORDER}"
        edit_id
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3)
        title_banner
        echo -e "${PURPLE}${BOLD}Mulakan Bot Telegram${RESET}"
        echo -e "${FULL_BORDER}"
        start_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4)
        title_banner
        echo -e "${PURPLE}${BOLD}Hentikan Bot Telegram${RESET}"
        echo -e "${FULL_BORDER}"
        stop_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      5)
        title_banner
        echo -e "${PURPLE}${BOLD}Status Bot Telegram${RESET}"
        echo -e "${FULL_BORDER}"
        status_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      0)
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 0 dan 5.${RESET}"
        pause
        ;;
    esac
  done
}

telegram_bot_menu
