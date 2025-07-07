#!/bin/bash
# Menu Pengurusan Backup VPN ke Telegram

BACKUP_DIR="/root/vpn-backup"
TGL=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/root/vpn-backup-$TGL.tar.gz"
LOG="/root/backup_restore.log"
CONFIG_FILE="/etc/backup.conf"

# Warna
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
PURPLE="\033[1;35m"
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[1;32m"
RED="\033[1;31m"

# Baca config
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

backup_proses() {
  if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
    echo -e "${RED}✘ Bot token/chat id belum diisi! Sila set dahulu di menu ini.${RESET}"
    return
  fi
  echo -e "${YELLOW}Membuat backup ke $BACKUP_FILE ...${RESET}"
  rm -rf "$BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -r /etc/xray "$BACKUP_DIR/" 2>/dev/null
  cp -r /usr/local/etc/xray "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/openvpn "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/hysteria "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/slowdns "$BACKUP_DIR/" 2>/dev/null
  cp -r /var/log/xray-users.log "$BACKUP_DIR/" 2>/dev/null
  cp -r /var/log/ovpn-users.log "$BACKUP_DIR/" 2>/dev/null
  cp -r /var/log/ssh-users.log "$BACKUP_DIR/" 2>/dev/null
  cp -r /var/log/hysteria-users.log "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/xray/domain.conf "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/nsdomain "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/stunnel/stunnel.pem "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/nginx/nginx.conf "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/nginx/conf.d "$BACKUP_DIR/" 2>/dev/null
  cp -r /var/www/html "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/iptables.up.rules "$BACKUP_DIR/" 2>/dev/null
  cp -r /etc/ufw "$BACKUP_DIR/" 2>/dev/null
  cp /etc/passwd "$BACKUP_DIR/passwd"
  cp /etc/shadow "$BACKUP_DIR/shadow"
  cp /etc/group "$BACKUP_DIR/group"
  cp /etc/gshadow "$BACKUP_DIR/gshadow"
  tar -czf "$BACKUP_FILE" -C "$BACKUP_DIR" .
  echo -e "${YELLOW}Backup selesai. File: $BACKUP_FILE${RESET}"
  echo "$(date) BACKUP: $BACKUP_FILE" >> "$LOG"
  rm -rf "$BACKUP_DIR"

  # Kirim ke Telegram
  TEXT="Backup VPN $(hostname) ($TGL) - $(date)\nFile: $BACKUP_FILE"
  curl -s -F chat_id="$TELEGRAM_CHAT_ID" -F document=@"$BACKUP_FILE" -F caption="$TEXT" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" >/dev/null
  echo -e "${GREEN}Backup telah dihantar ke Telegram.${RESET}"
}

restore_proses() {
  read -rp "Masukkan path file backup (.tar.gz): " RESTORE_FILE
  if [[ ! -f "$RESTORE_FILE" ]]; then
    echo -e "${RED}✘ File tidak ditemui!${RESET}"
    return
  fi
  echo -e "${YELLOW}Memulihkan konfigurasi dari $RESTORE_FILE ...${RESET}"
  mkdir -p "$BACKUP_DIR"
  tar -xzf "$RESTORE_FILE" -C "$BACKUP_DIR"
  cp -r "$BACKUP_DIR/xray/"* /etc/xray/ 2>/dev/null
  cp -r "$BACKUP_DIR/xray/"* /usr/local/etc/xray/ 2>/dev/null
  cp -r "$BACKUP_DIR/openvpn/"* /etc/openvpn/ 2>/dev/null
  cp -r "$BACKUP_DIR/hysteria/"* /etc/hysteria/ 2>/dev/null
  cp -r "$BACKUP_DIR/slowdns/"* /etc/slowdns/ 2>/dev/null
  cp "$BACKUP_DIR/xray-users.log" /var/log/xray-users.log 2>/dev/null
  cp "$BACKUP_DIR/ovpn-users.log" /var/log/ovpn-users.log 2>/dev/null
  cp "$BACKUP_DIR/ssh-users.log" /var/log/ssh-users.log 2>/dev/null
  cp "$BACKUP_DIR/hysteria-users.log" /var/log/hysteria-users.log 2>/dev/null
  cp "$BACKUP_DIR/domain.conf" /etc/xray/domain.conf 2>/dev/null
  cp "$BACKUP_DIR/nsdomain" /etc/nsdomain 2>/dev/null
  cp "$BACKUP_DIR/stunnel.pem" /etc/stunnel/stunnel.pem 2>/dev/null
  cp "$BACKUP_DIR/nginx.conf" /etc/nginx/nginx.conf 2>/dev/null
  cp -r "$BACKUP_DIR/conf.d/"* /etc/nginx/conf.d/ 2>/dev/null
  cp -r "$BACKUP_DIR/html/"* /var/www/html/ 2>/dev/null
  cp "$BACKUP_DIR/iptables.up.rules" /etc/iptables.up.rules 2>/dev/null
  cp -r "$BACKUP_DIR/ufw/"* /etc/ufw/ 2>/dev/null
  cp "$BACKUP_DIR/passwd" /etc/passwd
  cp "$BACKUP_DIR/shadow" /etc/shadow
  cp "$BACKUP_DIR/group" /etc/group
  cp "$BACKUP_DIR/gshadow" /etc/gshadow
  systemctl restart nginx xray openvpn@server-udp-1194 openvpn@server-tcp-443 openvpn@server-udp-53 openvpn@server-tcp-80 dropbear stunnel4 badvpn-udpgw hysteria2 client-sldns server-sldns ws-python-proxy
  echo -e "${GREEN}Restore selesai.${RESET}"
  echo "$(date) RESTORE: $RESTORE_FILE" >> "$LOG"
  rm -rf "$BACKUP_DIR"
}

set_token() {
  read -rp "Masukkan TELEGRAM_BOT_TOKEN: " TOKEN
  read -rp "Masukkan TELEGRAM_CHAT_ID: " CHATID
  echo "TELEGRAM_BOT_TOKEN=\"$TOKEN\"" > "$CONFIG_FILE"
  echo "TELEGRAM_CHAT_ID=\"$CHATID\"" >> "$CONFIG_FILE"
  echo -e "${GREEN}Konfigurasi disimpan di $CONFIG_FILE.${RESET}"
}

menu_backup() {
  while true; do
    clear
    echo -e "${PURPLE}${BOLD}╾━━━━━━━━━  Pengurusan Backup VPN  ━━━━━━━━━╼${RESET}"
    echo -e "${YELLOW}  1. Backup & Hantar ke Telegram${RESET}"
    echo -e "${YELLOW}  2. Restore Konfigurasi VPN${RESET}"
    echo -e "${YELLOW}  3. Set Telegram Bot Token & Chat ID${RESET}"
    echo -e "${YELLOW}  0. Kembali ke Menu Utama${RESET}"
    echo -ne "${WHITE}Pilih pilihan [0-3]: ${RESET}"
    read opt
    case $opt in
      1) backup_proses; read -n 1 -s -r -p "Tekan sebarang kekunci...";;
      2) restore_proses; read -n 1 -s -r -p "Tekan sebarang kekunci...";;
      3) set_token; read -n 1 -s -r -p "Tekan sebarang kekunci...";;
      0) break;;
      *) echo -e "${RED}✘ Pilihan tidak sah.${RESET}"; sleep 1;;
    esac
  done
}

case "$1" in
  menu) menu_backup ;;
  backup) backup_proses ;;
  restore) restore_proses ;;
  config) set_token ;;
  *) menu_backup ;;
esac