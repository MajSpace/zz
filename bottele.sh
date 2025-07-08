#!/bin/bash

source /usr/local/bin/utils.sh 2>/dev/null

CONFIG="/etc/backup.conf"
SERVICE_PATH="/etc/systemd/system/vpn-telegram-bot.service"
BOT_PATH="/root/bot_vpn.py"

set_token_id() {
  echo -ne "${WHITE}Masukkan TELEGRAM_BOT_TOKEN: ${RESET}"
  read TOKEN
  echo -ne "${WHITE}Masukkan TELEGRAM_CHAT_ID (ID admin): ${RESET}"
  read CHATID

  echo "TELEGRAM_BOT_TOKEN=\"$TOKEN\"" > "$CONFIG"
  echo "TELEGRAM_CHAT_ID=\"$CHATID\"" >> "$CONFIG"
  echo -e "${GREEN}Konfigurasi bot telah disimpan di $CONFIG.${RESET}"
}

generate_service() {
  if [[ ! -f "$BOT_PATH" ]]; then
    echo -e "${RED}File bot python tidak ditemukan di $BOT_PATH!${RESET}"
    echo -e "${YELLOW}Pastikan file bot_vpn.py sudah diletakkan di $BOT_PATH.${RESET}"
    return 1
  fi
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Bot Telegram VPN MajSpace
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $BOT_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
  chmod 644 "$SERVICE_PATH"
  systemctl daemon-reload
  echo -e "${GREEN}Systemd service untuk Bot Telegram telah dibuat!${RESET}"
}

start_bot() {
  generate_service
  systemctl restart vpn-telegram-bot
  systemctl enable vpn-telegram-bot
  sleep 1
  systemctl status vpn-telegram-bot --no-pager -l
}

stop_bot() {
  systemctl stop vpn-telegram-bot
  systemctl disable vpn-telegram-bot
  echo -e "${YELLOW}Bot telah dihentikan.${RESET}"
}

status_bot() {
  systemctl status vpn-telegram-bot --no-pager -l
}

remove_service() {
  systemctl stop vpn-telegram-bot
  systemctl disable vpn-telegram-bot
  rm -f "$SERVICE_PATH"
  systemctl daemon-reload
  echo -e "${YELLOW}Systemd service bot telah dihapus.${RESET}"
}

while true; do
  title_banner
  echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Bot Telegram VPN${RESET}"
  echo -e "${FULL_BORDER}"
  echo -e "${YELLOW}  1. ${WHITE}Set Token & ID Admin${RESET}"
  echo -e "${YELLOW}  2. ${WHITE}Start Bot Telegram${RESET}"
  echo -e "${YELLOW}  3. ${WHITE}Stop Bot Telegram${RESET}"
  echo -e "${YELLOW}  4. ${WHITE}Status Bot Telegram${RESET}"
  echo -e "${YELLOW}  5. ${WHITE}(Re)Generate Systemd Service${RESET}"
  echo -e "${YELLOW}  6. ${WHITE}Hapus Systemd Service Bot${RESET}"
  echo -e "${YELLOW}  7. ${WHITE}Kembali ke Menu Utama${RESET}"
  echo -e "${FULL_BORDER}"
  echo -ne "${WHITE}Sila pilih [1-7]: ${RESET}"
  read opt
  case $opt in
    1) set_token_id; pause ;;
    2) start_bot; pause ;;
    3) stop_bot; pause ;;
    4) status_bot; pause ;;
    5) generate_service; pause ;;
    6) remove_service; pause ;;
    7) break ;;
    *) echo -e "${RED}✘ Pilihan tidak sah.${RESET}"; pause ;;
  esac
done