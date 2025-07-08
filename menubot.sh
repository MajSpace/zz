# File: MultipleFiles/menubot.sh
#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

BOT_CONFIG_FILE="/etc/telegram_bot.conf"
BOT_SERVICE_FILE="/etc/systemd/system/vpn_telegram_bot.service"
BOT_SCRIPT_PATH="/usr/local/bin/telegram_bot.py"

# Fungsi untuk membaca konfigurasi bot
load_bot_config() {
  if [[ -f "$BOT_CONFIG_FILE" ]]; then
    source "$BOT_CONFIG_FILE"
  else
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_ADMIN_ID=""
  fi
}

# Fungsi untuk menyimpan konfigurasi bot
save_bot_config() {
  echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$BOT_CONFIG_FILE"
  echo "TELEGRAM_ADMIN_ID=\"$TELEGRAM_ADMIN_ID\"" >> "$BOT_CONFIG_FILE"
  echo -e "${GREEN}✔ Konfigurasi bot Telegram telah disimpan di $BOT_CONFIG_FILE.${RESET}"
}

# Fungsi untuk mengatur token dan ID admin
set_bot_credentials() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tetapan Bot Telegram${RESET}"
  echo -e "${FULL_BORDER}"
  read -rp "Masukkan TELEGRAM_BOT_TOKEN (dari BotFather): " NEW_TOKEN
  read -rp "Masukkan TELEGRAM_ADMIN_ID (ID Telegram anda): " NEW_ADMIN_ID

  TELEGRAM_BOT_TOKEN="$NEW_TOKEN"
  TELEGRAM_ADMIN_ID="$NEW_ADMIN_ID"
  save_bot_config
  pause
}

# Fungsi untuk mengaktifkan bot
start_telegram_bot() {
  load_bot_config
  if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_ADMIN_ID" ]]; then
    echo -e "${RED}✘ Ralat: Token bot atau ID admin belum ditetapkan. Sila tetapkan dahulu.${RESET}"
    pause
    return
  fi

  title_banner
  echo -e "${PURPLE}${BOLD}Mengaktifkan Bot Telegram${RESET}"
  echo -e "${FULL_BORDER}"
  loading_animation "Memulakan bot Telegram"

  # Pastikan skrip bot ada
  if [[ ! -f "$BOT_SCRIPT_PATH" ]]; then
    echo -e "${RED}✘ Ralat: Skrip bot Python tidak ditemui di $BOT_SCRIPT_PATH. Sila jalankan semula install.sh.${RESET}"
    pause
    return
  fi

  # Buat atau perbarui service systemd
  cat > "$BOT_SERVICE_FILE" <<EOF
[Unit]
Description=VPN Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/bin/python3 $BOT_SCRIPT_PATH
Restart=always
Environment="TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
Environment="TELEGRAM_ADMIN_ID=$TELEGRAM_ADMIN_ID"

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable vpn_telegram_bot
  systemctl start vpn_telegram_bot

  sleep 3 # Beri waktu bot untuk memulai
  if systemctl is-active vpn_telegram_bot >/dev/null; then
    echo -e "${BRIGHT_GREEN}✔ Bot Telegram berjaya diaktifkan.${RESET}"
    echo -e "${YELLOW}Sila cuba hantar /start kepada bot anda di Telegram.${RESET}"
  else
    echo -e "${RED}✘ Ralat: Gagal mengaktifkan bot Telegram.${RESET}"
    echo -e "${YELLOW}Sila semak log: journalctl -u vpn_telegram_bot --no-pager -l${RESET}"
  fi
  pause
}

# Fungsi untuk menghentikan bot
stop_telegram_bot() {
  title_banner
  echo -e "${PURPLE}${BOLD}Menghentikan Bot Telegram${RESET}"
  echo -e "${FULL_BORDER}"
  loading_animation "Menghentikan bot Telegram"

  systemctl stop vpn_telegram_bot
  systemctl disable vpn_telegram_bot

  if ! systemctl is-active vpn_telegram_bot >/dev/null; then
    echo -e "${BRIGHT_GREEN}✔ Bot Telegram berjaya dihentikan.${RESET}"
  else
    echo -e "${RED}✘ Ralat: Gagal menghentikan bot Telegram.${RESET}"
  fi
  pause
}

# Fungsi untuk melihat status bot
check_bot_status() {
  title_banner
  echo -e "${PURPLE}${BOLD}Status Bot Telegram${RESET}"
  echo -e "${FULL_BORDER}"
  status=$(systemctl is-active vpn_telegram_bot 2>/dev/null)
  if [[ "$status" == "active" ]]; then
    echo -e "${BRIGHT_GREEN}✔ Bot Telegram sedang aktif.${RESET}"
  elif [[ "$status" == "inactive" ]]; then
    echo -e "${RED}✘ Bot Telegram tidak aktif.${RESET}"
  elif [[ "$status" == "failed" ]]; then
    echo -e "${RED}✘ Bot Telegram gagal (${status}).${RESET}"
  else
    echo -e "${YELLOW}Status tidak diketahui: $status.${RESET}"
  fi
  echo -e "${SECTION_DIVIDER}"
  echo -e "${WHITE}Log Terkini:${RESET}"
  journalctl -u vpn_telegram_bot --no-pager -l -n 10
  echo -e "${FULL_BORDER}"
  pause
}

# Sub-Menu Bot Telegram
menubot() {
  while true; do
    load_bot_config # Muat konfigurasi setiap kali menu ditampilkan
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Bot Telegram${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Tetapkan Token Bot & ID Admin${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Aktifkan Bot Telegram${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Hentikan Bot Telegram${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Semak Status Bot Telegram${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  0. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  Token Bot: ${LIGHT_CYAN}${TELEGRAM_BOT_TOKEN:-Belum Ditetapkan}${RESET}"
    echo -e "${YELLOW}  ID Admin:  ${LIGHT_CYAN}${TELEGRAM_ADMIN_ID:-Belum Ditetapkan}${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [0-4]: ${RESET}"
    read opt
    case $opt in
      1) set_bot_credentials ;;
      2) start_telegram_bot ;;
      3) stop_telegram_bot ;;
      4) check_bot_status ;;
      0) return ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 0 dan 4.${RESET}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu
menubot