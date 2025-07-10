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
    echo -e "${GREEN}✔ TOKEN diperbaharui.${RESET}"
}

function edit_id() {
    ensure_conf
    read -p "Masukkan ALLOWED_CHAT_IDS baru (pisahkan dengan koma): " ids
    if grep -q "^ALLOWED_CHAT_IDS=" "$CONF"; then
        sed -i "s|^ALLOWED_CHAT_IDS=.*|ALLOWED_CHAT_IDS=${ids}|" "$CONF"
    else
        echo "ALLOWED_CHAT_IDS=${ids}" >> "$CONF"
    fi
    echo -e "${GREEN}✔ User ID diperbaharui.${RESET}"
}

function start_bot() {
    pkill -f "$BOTPY" >/dev/null 2>&1
    nohup python3 $BOTPY >$BOTLOG 2>&1 &
    echo -e "${BRIGHT_GREEN}✔ Bot telah dijalankan. Cek log di $BOTLOG${RESET}"
}

function stop_bot() {
    pkill -f "$BOTPY"
    echo -e "${YELLOW}✔ Bot dihentikan.${RESET}"
}

function status_bot() {
    if pgrep -f "$BOTPY" >/dev/null; then
        echo -e "${BRIGHT_GREEN}● Bot sedang berjalan.${RESET}"
    else
        echo -e "${RED}● Bot tidak berjalan.${RESET}"
    fi
}

telegram_bot_menu() {
  while true; do
    clear
    header_info
    header_service_status
    echo -e "${BGAQUA}                  PENGURUSAN BOT TELEGRAM                     ${NC}"
    echo -e "${FULL_BORDER}"
    echo -e " [${AQUA}01${NC}] Tetapan TOKEN"
    echo -e " [${AQUA}02${NC}] Tetapkan Telegram User ID"
    echo -e " [${AQUA}03${NC}] Start Bot"
    echo -e " [${AQUA}04${NC}] Stop Bot"
    echo -e " [${AQUA}05${NC}] Status Bot"
    echo -e " [${AQUA}00${NC}] Kembali ke Menu Utama"
    echo -e "${FULL_BORDER}"
    read -p "[###] Pilih Menu [00-05]: " opt
    case $opt in
      1|01)
        clear
        header_info
        header_service_status
        echo -e "${BGAQUA}                    TETAPAN TOKEN BOT TELEGRAM               ${NC}"
        echo -e "${FULL_BORDER}"
        edit_token
        echo -e "${FULL_BORDER}"
        pause
        ;;
      2|02)
        clear
        header_info
        header_service_status
        echo -e "${BGAQUA}                 TETAPAN TELEGRAM USER ID                    ${NC}"
        echo -e "${FULL_BORDER}"
        edit_id
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3|03)
        clear
        header_info
        header_service_status
        echo -e "${BGAQUA}                      MULAKAN BOT TELEGRAM                   ${NC}"
        echo -e "${FULL_BORDER}"
        start_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4|04)
        clear
        header_info
        header_service_status
        echo -e "${BGAQUA}                      HENTIKAN BOT TELEGRAM                  ${NC}"
        echo -e "${FULL_BORDER}"
        stop_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      5|05)
        clear
        header_info
        header_service_status
        echo -e "${BGAQUA}                       STATUS BOT TELEGRAM                   ${NC}"
        echo -e "${FULL_BORDER}"
        status_bot
        echo -e "${FULL_BORDER}"
        pause
        ;;
      0|00)
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 00 dan 05.${RESET}"
        pause
        ;;
    esac
  done
}

telegram_bot_menu
