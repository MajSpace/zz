#!/bin/bash

# -------- Warna & Style --------
NC="\033[0m"
CYAN="\033[1;36m"
BRIGHT_CYAN="\033[1;96m"
PURPLE="\033[1;35m"
BRIGHT_PURPLE="\033[1;95m"
TEAL="\033[38;5;44m"
WHITE="\033[1;37m"
GRAY="\033[0;37m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
RESET="\033[0m"
BG_BLACK="\033[40m"

# -------- System Info --------
XRAY_CONFIG="/usr/local/etc/xray/config.json"
[[ ! -f "$XRAY_CONFIG" ]] && XRAY_CONFIG="/etc/xray/config.json"
HYSTERIA_CONFIG="/etc/hysteria/hysteria2.yaml"
DOMAIN=$(cat /etc/xray/domain.conf 2>/dev/null || echo "Tidak Tersedia")
IP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
ISP=$(curl -s ipinfo.io/org 2>/dev/null || echo "Tidak Tersedia")
UPTIME=$(uptime -p 2>/dev/null || echo "Tidak Tersedia")

# -------- Tampilan --------
# Fungsi untuk cetak tengah
center_text() {
  local str="$1"
  local width=$(tput cols)
  local len=${#str}
  local pad=$(( (width - len) / 2 ))
  if (( pad > 0 )); then
    printf "%*s%s\n" $pad "" "$str"
  else
    echo "$str"
  fi
}

# Modern Banner
modern_banner() {
  clear
  local width=$(tput cols)
  local bar="────────────────────────────────────────────────────────────"
  center_text "${TEAL}${BOLD}╭─────────────────────────────────────────────╮${RESET}"
  center_text "${BRIGHT_CYAN}${BOLD}│           ${PURPLE}MAJ SPACE VPN MANAGER           ${BRIGHT_CYAN}│${RESET}"
  center_text "${TEAL}${BOLD}╰─────────────────────────────────────────────╯${RESET}"
  center_text "${GRAY}${bar:0:$((width-2))}${RESET}"
  center_text "${WHITE}${BOLD}IP: ${BRIGHT_CYAN}$IP${WHITE}   Domain: ${BRIGHT_CYAN}$DOMAIN${WHITE}   ISP: ${BRIGHT_CYAN}$ISP${RESET}"
  center_text "${WHITE}Uptime: ${BRIGHT_CYAN}$UPTIME${RESET}"
  center_text "${GRAY}${bar:0:$((width-2))}${RESET}"
}

modern_section() {
  local width=$(tput cols)
  local bar="────────────────────────────────────────────────────────────"
  center_text "${GRAY}${bar:0:$((width-2))}${RESET}"
}

# Pause
pause() {
  read -n 1 -s -r -p "$(center_text "${GRAY}Tekan sebarang kekunci untuk kembali...${RESET}")"
  echo
}

# Animasi Loading
loading_animation() {
  local msg=$1
  echo -ne "${YELLOW}${msg} ["
  for i in {1..5}; do
    echo -ne "${BRIGHT_CYAN}■${RESET}"
    sleep 0.12
  done
  echo -e "] ${BRIGHT_CYAN}Selesai!${RESET}"
}

# -------- List Helper --------
list_ssh_users() {
  awk -F: '($3>=1000)&&($7=="/bin/bash"){print $1}' /etc/passwd
}
list_xray_users() {
  if [[ -f "$XRAY_CONFIG" ]]; then
    jq -r '.inbounds[].settings.clients[]? | select(.email != null) | .email' "$XRAY_CONFIG" | sort | uniq
  fi
}
list_openvpn_users() {
  if [[ -f "/var/log/ovpn-users.log" ]]; then
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' /var/log/ovpn-users.log
  fi
}
list_hysteria_users() {
  if [[ -f "/var/log/hysteria-users.log" ]]; then
    awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' /var/log/hysteria-users.log
  fi
}

# -------- Validation --------
validate_username() {
  local username=$1
  local type=$2
  if [[ -z "$username" ]]; then
    echo -e "${YELLOW}✘ Nama pengguna tidak boleh kosong.${RESET}"; return 1
  fi
  if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${YELLOW}✘ Nama pengguna hanya boleh mengandungi huruf/nombor/-/_${RESET}"; return 1
  fi
  case $type in
    "SSH") if id "$username" >/dev/null 2>&1; then
      echo -e "${YELLOW}✘ Nama pengguna '$username' sudah wujud untuk SSH.${RESET}"; return 1; fi ;;
    "XRAY") if [[ -f "$XRAY_CONFIG" ]] && jq -e --arg user "$username" '.inbounds[].settings.clients[]? | select(.email==$user)' "$XRAY_CONFIG" >/dev/null; then
      echo -e "${YELLOW}✘ Nama pengguna '$username' sudah wujud untuk Xray.${RESET}"; return 1; fi ;;
    "OPENVPN") if id "$username" >/dev/null 2>&1; then
      echo -e "${YELLOW}✘ Nama pengguna '$username' sudah wujud untuk OpenVPN.${RESET}"; return 1; fi ;;
    "HYSTERIA") if grep -q "^$username|" /var/log/hysteria-users.log 2>/dev/null; then
      echo -e "${YELLOW}✘ Nama pengguna '$username' sudah wujud untuk Hysteria2.${RESET}"; return 1; fi ;;
  esac
  return 0
}

validate_days() {
  local days=$1
  if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
    echo -e "${YELLOW}✘ Masukkan bilangan hari yang sah (nombor positif).${RESET}"; return 1
  fi
  return 0
}

generate_password() {
  local length=${1:-12}
  openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# -------- Info Helper --------
show_openvpn_ports() {
  center_text "${BRIGHT_PURPLE}${BOLD}Port OpenVPN:${RESET}"
  center_text "${CYAN}UDP: 1194   TCP: 1443   UDP DNS: 2053   TCP HTTP: 8080${RESET}"
  modern_section
}
show_hysteria_info() {
  center_text "${BRIGHT_PURPLE}${BOLD}Info Hysteria2:${RESET}"
  center_text "${CYAN}Port: 8443/UDP   Protocol: QUIC/HTTP3   Bandwidth: Unlimited${RESET}"
  modern_section
}
