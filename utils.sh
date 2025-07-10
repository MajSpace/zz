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

# Title & Menu Title (untuk center)
MENU_TITLE="MENU UTAMA"
TITLE_TEXT="MAJ SPACE SCRIPT MANAGER"

# Laluan Konfigurasi
XRAY_CONFIG="/usr/local/etc/xray/config.json"
[[ ! -f "$XRAY_CONFIG" ]] && XRAY_CONFIG="/etc/xray/config.json"
HYSTERIA_CONFIG="/etc/hysteria/hysteria2.yaml"
DOMAIN=$(cat /etc/xray/domain.conf 2>/dev/null || echo "Tidak Tersedia")
IP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
ISP=$(curl -s ipinfo.io/org 2>/dev/null || echo "Tidak Tersedia")
UPTIME=$(uptime -p 2>/dev/null || echo "Tidak Tersedia")

# Sempadan Dekoratif
FULL_BORDER="${PURPLE}╾──────────────────────────────────────────────────────────────────────────────╼${RESET}"
SHORT_BORDER="${DARK_BLUE}─────────────────────────────────────────────────────${RESET}"
SECTION_DIVIDER="${GRAY}--------------------------------------------------------${RESET}"

# Fungsi center text
center_text() {
  local text="$1"
  local width=$(tput cols)
  local padding=$(( (width - ${#text}) / 2 ))
  printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# ASCII Art (modern)
TITLE_ART="
${DARK_BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}
${LIGHT_CYAN}║                                                          ║${RESET}
${DARK_BLUE}║${RESET}${BOLD}        $TITLE_TEXT        ${RESET}${DARK_BLUE}║${RESET}
${LIGHT_CYAN}║                                                          ║${RESET}
${DARK_BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}
"

# Papar tajuk dengan maklumat sistem (centered)
title_banner() {
  clear
  center_text "${TITLE_ART}"
  echo -e "${FULL_BORDER}"
  center_text "${BOLD}MAKLUMAT SISTEM${RESET}"
  echo -e "${SHORT_BORDER}"
  printf "%-15s %-32s\n" "${YELLOW}Alamat IP${RESET}   :" "${LIGHT_CYAN}$IP${RESET}"
  printf "%-15s %-32s\n" "${YELLOW}Domain${RESET}      :" "${LIGHT_CYAN}$DOMAIN${RESET}"
  printf "%-15s %-32s\n" "${YELLOW}ISP${RESET}         :" "${LIGHT_CYAN}$ISP${RESET}"
  printf "%-15s %-32s\n" "${YELLOW}Masa Aktif${RESET}  :" "${LIGHT_CYAN}$UPTIME${RESET}"
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
    echo -e "${RED}Nama pengguna tidak boleh kosong.${RESET}"
    return 1
  fi
  if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Nama pengguna hanya boleh mengandungi huruf, nombor, tanda hubung, atau garis bawah.${RESET}"
    return 1
  fi
  case $type in
    "SSH")
      if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}Nama pengguna '$username' sudah wujud untuk SSH.${RESET}"
        return 1
      fi
      ;;
    "XRAY")
      if [[ -f "$XRAY_CONFIG" ]] && jq -e --arg user "$username" '.inbounds[].settings.clients[]? | select(.email==$user)' "$XRAY_CONFIG" >/dev/null; then
        echo -e "${RED}Nama pengguna '$username' sudah wujud untuk Xray.${RESET}"
        return 1
      fi
      ;;
    "OPENVPN")
      if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}Nama pengguna '$username' sudah wujud untuk OpenVPN.${RESET}"
        return 1
      fi
      ;;
    "HYSTERIA")
      if grep -q "^$username|" /var/log/hysteria-users.log 2>/dev/null; then
        echo -e "${RED}Nama pengguna '$username' sudah wujud untuk Hysteria2.${RESET}"
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
    echo -e "${RED}Sila masukkan bilangan hari yang sah (nombor positif).${RESET}"
    return 1
  fi
  return 0
}

# Generate random password
generate_password() {
  local length=${1:-12}
  openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Papar port OpenVPN
show_openvpn_ports() {
  printf "%-22s %s\n" "${YELLOW}UDP Standard${RESET}" "${LIGHT_CYAN}1194${RESET}"
  printf "%-22s %s\n" "${YELLOW}TCP HTTPS Bypass${RESET}" "${LIGHT_CYAN}1443${RESET}"
  printf "%-22s %s\n" "${YELLOW}UDP DNS Bypass${RESET}" "${LIGHT_CYAN}2053${RESET}"
  printf "%-22s %s\n" "${YELLOW}TCP HTTP Bypass${RESET}" "${LIGHT_CYAN}8080${RESET}"
  echo -e "${SHORT_BORDER}"
}

# Papar maklumat Hysteria2
show_hysteria_info() {
  printf "%-22s %s\n" "${YELLOW}Port${RESET}" "${LIGHT_CYAN}8443 (UDP)${RESET}"
  printf "%-22s %s\n" "${YELLOW}Protocol${RESET}" "${LIGHT_CYAN}QUIC/HTTP3${RESET}"
  printf "%-22s %s\n" "${YELLOW}Bandwidth${RESET}" "${LIGHT_CYAN}Unlimited${RESET}"
  printf "%-22s %s\n" "${YELLOW}Congestion Control${RESET}" "${LIGHT_CYAN}BBR${RESET}"
  echo -e "${SHORT_BORDER}"
}