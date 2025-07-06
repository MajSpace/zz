#!/bin/bash

# Palet Warna yang Diperkaya
PURPLE="\033[1;35m"
DARK_BLUE="\033[0;34m"
LIGHT_CYAN="\033[1;36m"
BRIGHT_GREEN="\033[1;92m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
GRAY="\033[0;37m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
BG_CYAN="\033[46m"
BG_PURPLE="\033[45m"
RESET="\033[0m"

# Laluan Konfigurasi
XRAY_CONFIG="/usr/local/etc/xray/config.json"
[[ ! -f "$XRAY_CONFIG" ]] && XRAY_CONFIG="/etc/xray/config.json"
HYSTERIA_CONFIG="/etc/hysteria/hysteria2.yaml"
DOMAIN=$(cat /etc/xray/domain.conf 2>/dev/null || echo "Tidak Tersedia")
IP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
ISP=$(curl -s ipinfo.io/org 2>/dev/null || echo "Tidak Tersedia")
SLOWDNS_DOMAIN=$(cat /etc/nsdomain 2>/dev/null || echo "Tidak Tersedia")
SLOWDNS_PUBKEY=$(cat /etc/slowdns/server.pub 2>/dev/null | head -n 1 || echo "Tidak Tersedia")
UPTIME=$(uptime -p 2>/dev/null || echo "Tidak Tersedia")

# Sempadan Dekoratif
FULL_BORDER="${PURPLE}╾━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╼${RESET}"
SHORT_BORDER="${DARK_BLUE}┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅${RESET}"
SECTION_DIVIDER="${GRAY}----------------------------------------${RESET}"

# ASCII Art yang Diperbarui dengan Kesan Gradasi
TITLE_ART="
${DARK_BLUE}   ╔════╗ ╔════╗ ╔════╗ ╔════╗${RESET}
${LIGHT_CYAN}   ║    ║ ║    ║ ║    ║ ║    ║${RESET}
${DARK_BLUE}   ╚════╝ ╚════╝ ╚════╝ ╚════╝${RESET}
${PURPLE}   Sistem Pengurusan VPN${RESET}
"

# Papar tajuk dengan maklumat sistem
title_banner() {
  clear
  echo -e "${TITLE_ART}"
  echo -e "${FULL_BORDER}"
  echo -e "${WHITE}${BOLD}Maklumat Sistem:${RESET}"
  echo -e "${SHORT_BORDER}"
  echo -e "${YELLOW}  Alamat IP:    ${LIGHT_CYAN}$IP${RESET}"
  echo -e "${YELLOW}  Hos/Domain:   ${LIGHT_CYAN}$DOMAIN${RESET}"
  echo -e "${YELLOW}  ISP:          ${LIGHT_CYAN}$ISP${RESET}"
  echo -e "${YELLOW}  Masa Aktif:   ${LIGHT_CYAN}$UPTIME${RESET}"
  echo -e "${SHORT_BORDER}"
  echo
}

# Berhenti dan minta untuk kembali ke menu
pause() {
  read -n 1 -s -r -p "$(echo -e "${GRAY}Tekan sebarang kekunci untuk kembali...${RESET}")"
  echo
}

# Animasi Memuat yang Diperkaya
loading_animation() {
  local msg=$1
  echo -ne "${YELLOW}${msg} ["
  for i in {1..5}; do
    echo -ne "${BRIGHT_GREEN}█${RESET}"
    sleep 0.2
  done
  echo -e "] ${BRIGHT_GREEN}Selesai!${RESET}"
}

# Senarai pengguna SSH
list_ssh_users() {
  awk -F: '($3>=1000)&&($7=="/bin/bash"){print $1}' /etc/passwd
}

# Senarai pengguna Xray
list_xray_users() {
  if [[ -f "$XRAY_CONFIG" ]]; then
    jq -r '.inbounds[].settings.clients[]? | select(.email != null) | .email' "$XRAY_CONFIG" | sort | uniq
  fi
}

# Senarai pengguna OpenVPN
list_openvpn_users() {
  if [[ -f "/var/log/ovpn-users.log" ]]; then
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' /var/log/ovpn-users.log
  fi
}

# Senarai pengguna Hysteria2
list_hysteria_users() {
  if [[ -f "/var/log/hysteria-users.log" ]]; then
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' /var/log/hysteria-users.log
  fi
}

# Sahkan nama pengguna (tidak kosong dan tidak berulang)
validate_username() {
  local username=$1
  local type=$2
  if [[ -z "$username" ]]; then
    echo -e "${RED}✘ Ralat: Nama pengguna tidak boleh kosong.${RESET}"
    return 1
  fi
  if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}✘ Ralat: Nama pengguna hanya boleh mengandungi huruf, nombor, tanda hubung, atau garis bawah.${RESET}"
    return 1
  fi
  case $type in
    "SSH")
      if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}✘ Ralat: Nama pengguna '$username' sudah wujud untuk SSH.${RESET}"
        return 1
      fi
      ;;
    "XRAY")
      if [[ -f "$XRAY_CONFIG" ]] && jq -e --arg user "$username" '.inbounds[].settings.clients[]? | select(.email==$user)' "$XRAY_CONFIG" >/dev/null; then
        echo -e "${RED}✘ Ralat: Nama pengguna '$username' sudah wujud untuk Xray.${RESET}"
        return 1
      fi
      ;;
    "OPENVPN")
      if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}✘ Ralat: Nama pengguna '$username' sudah wujud untuk OpenVPN.${RESET}"
        return 1
      fi
      ;;
    "HYSTERIA")
      if grep -q "^$username|" /var/log/hysteria-users.log 2>/dev/null; then
        echo -e "${RED}✘ Ralat: Nama pengguna '$username' sudah wujud untuk Hysteria2.${RESET}"
        return 1
      fi
      ;;
  esac
  return 0
}

# Sahkan input hari
validate_days() {
  local days=$1
  if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
    echo -e "${RED}✘ Ralat: Sila masukkan bilangan hari yang sah (nombor positif).${RESET}"
    return 1
  fi
  return 0
}

# Generate random password
generate_password() {
  local length=${1:-12}
  openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Tambahkan fungsi baru untuk menampilkan informasi SSH
show_ssh_info() {
  echo -e "${PURPLE}${BOLD}Port Perkhidmatan SSH:${RESET}"
  echo -e "${YELLOW}  OpenSSH:         ${LIGHT_CYAN}22${RESET}"
  echo -e "${YELLOW}  Dropbear:        ${LIGHT_CYAN}109, 143${RESET}"
  echo -e "${YELLOW}  Stunnel4:        ${LIGHT_CYAN}444, 777, 992${RESET}"
  echo -e "${YELLOW}  BadVPN-UDPGW:    ${LIGHT_CYAN}7100-7900 UDP${RESET}"
  echo -e "${YELLOW}  HTTP Proxy SSH:  ${LIGHT_CYAN}8880 TCP${RESET}" # BARIS BARU
  echo -e "${SHORT_BORDER}"
}

# Papar maklumat SlowDNS
show_slowdns_info() {
  echo -e "${WHITE}Maklumat SlowDNS:${RESET}"
  echo -e "${YELLOW}  DNS:           ${LIGHT_CYAN}8.8.8.8${RESET}"
  echo -e "${YELLOW}  Nama Pelayan:  ${LIGHT_CYAN}${SLOWDNS_DOMAIN}${RESET}"
  echo -e "${YELLOW}  Kunci PUB DNS: ${LIGHT_CYAN}${SLOWDNS_PUBKEY}${RESET}"
  echo -e "${YELLOW}  SSH SlowDNS:   ${LIGHT_CYAN}5300${RESET}"
  echo -e "${SHORT_BORDER}"
}

# Papar port OpenVPN
show_openvpn_ports() {
  echo -e "${PURPLE}${BOLD}Port Perkhidmatan OpenVPN:${RESET}"
  echo -e "${YELLOW}  UDP Standard:      ${LIGHT_CYAN}1194${RESET}"
  echo -e "${YELLOW}  TCP HTTPS Bypass:  ${LIGHT_CYAN}1443${RESET}"
  echo -e "${YELLOW}  UDP DNS Bypass:    ${LIGHT_CYAN}2053${RESET}"
  echo -e "${YELLOW}  TCP HTTP Bypass:   ${LIGHT_CYAN}8080${RESET}"
  echo -e "${SHORT_BORDER}"
}

# Papar maklumat Hysteria2
show_hysteria_info() {
  echo -e "${PURPLE}${BOLD}Maklumat Perkhidmatan Hysteria2:${RESET}"
  echo -e "${YELLOW}  Port:              ${LIGHT_CYAN}8443 (UDP)${RESET}"
  echo -e "${YELLOW}  Protocol:          ${LIGHT_CYAN}QUIC/HTTP3${RESET}"
  echo -e "${YELLOW}  Bandwidth:         ${LIGHT_CYAN}Unlimited${RESET}"
  echo -e "${YELLOW}  Congestion Control:${LIGHT_CYAN}BBR${RESET}"
  echo -e "${SHORT_BORDER}"
}
