#!/bin/bash

# Source utiliti global jika ada
source /usr/local/bin/utils.sh 2>/dev/null

BACKUP_DIR="/root/vpn-backup"
TGL=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/root/vpn-backup-$TGL.tar.gz"
LOG="/root/backup_restore.log"
CONFIG_FILE="/etc/backup.conf"

# Baca konfigurasi (token/chatid)
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

do_backup() {
  if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
    echo -e "${RED}✘ Token bot atau Chat ID Telegram belum disediakan! Sila tetapkan dahulu melalui menu ini.${RESET}"
    pause
    return
  fi

  echo -e "${YELLOW}Sedang membuat salinan sandaran ke $BACKUP_FILE ...${RESET}"
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
  echo -e "${GREEN}✔ Salinan sandaran telah selesai. Fail: $BACKUP_FILE${RESET}"
  echo "$(date) BACKUP: $BACKUP_FILE" >> "$LOG"
  rm -rf "$BACKUP_DIR"

  # Hantar ke Telegram dengan gaya profesional
  HOST=$(hostname)
  TANGGAL=$(date '+%d-%m-%Y %H:%M:%S')
  FILE_NAME=$(basename "$BACKUP_FILE")

  CAPTION="📦 *Maklumat Salinan Sandaran VPN*
━━━━━━━━━━━━━━━━━━━━
🖥 *Hostname:* \`$HOST\`
📅 *Tarikh:* \`$TANGGAL\`
📝 *Path Fail:* \`/root/$FILE_NAME\`

✅ *Status:* Berjaya disimpan & dihantar melalui Telegram

_Backup by Maj Space_"

  curl -s -F chat_id="$TELEGRAM_CHAT_ID" \
          -F document=@"$BACKUP_FILE" \
          -F caption="$CAPTION" \
          -F parse_mode="Markdown" \
          "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" >/dev/null

  echo -e "${BRIGHT_GREEN}✔ Sandaran telah dihantar ke Telegram.${RESET}"
  pause
}

do_restore() {
  read -rp "Sila masukkan path fail sandaran (.tar.gz): " RESTORE_FILE
  if [[ ! -f "$RESTORE_FILE" ]]; then
    echo -e "${RED}✘ Fail tidak ditemui! Sila semak semula.${RESET}"
    pause
    return
  fi

  echo -e "${YELLOW}Memulihkan konfigurasi daripada $RESTORE_FILE ...${RESET}"
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

  echo -e "${GREEN}✔ Proses pemulihan selesai.${RESET}"
  echo "$(date) RESTORE: $RESTORE_FILE" >> "$LOG"
  rm -rf "$BACKUP_DIR"
  pause
}

do_config() {
  read -rp "Masukkan TELEGRAM_BOT_TOKEN: " TOKEN
  read -rp "Masukkan TELEGRAM_CHAT_ID: " CHATID
  echo "TELEGRAM_BOT_TOKEN=\"$TOKEN\"" > "$CONFIG_FILE"
  echo "TELEGRAM_CHAT_ID=\"$CHATID\"" >> "$CONFIG_FILE"
  echo -e "${GREEN}✔ Konfigurasi Telegram telah disimpan di $CONFIG_FILE.${RESET}"
  source "$CONFIG_FILE"
  pause
}

backup_menu_ops() {
  while true; do
    if [[ -f "$CONFIG_FILE" ]]; then
      source "$CONFIG_FILE"
    fi
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Sandaran VPN${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Buat Sandaran & Hantar ke Telegram${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Pulihkan Konfigurasi dari Sandaran${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Tetapkan Bot Telegram & Chat ID${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Sila pilih [1-4]: ${RESET}"
    read opt
    case $opt in
      1) do_backup ;;
      2) do_restore ;;
      3) do_config ;;
      4) return ;;
      *) echo -e "${RED}✘ Pilihan tidak sah. Sila pilih antara 1-4.${RESET}"; pause ;;
    esac
  done
}

backup_menu_ops