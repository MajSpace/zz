#!/bin/bash

# Source utilitas global
source /usr/local/bin/utils.sh

# Warna (tambahan untuk style baru)
BGAQUA="\033[1;46m"
BGRED="\033[1;41m"
AQUA="\033[1;36m"
BGWHITE="\033[1;47m"
NC="\033[0m"
BGBLUE="\033[1;44m"    # Latar belakang biru
WHITE="\033[1;37m"     # Teks putih
BGBLACK="\033[1;40m"   # Latar belakang hitam
YELLOW="\033[1;33m"    # Teks kuning
GREEN="\033[1;32m"
RED="\033[1;31m"

main_menu() {
  while true; do
    clear
    # Header Sistem Info
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${BGBLUE}${WHITE}                     MAKLUMAT SISTEM                         ${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}ISP                  :${NC}  ${WHITE}$ISP${NC}"
    echo -e "${GREEN}Domain               :${NC}  ${WHITE}$DOMAIN${NC}"
    echo -e "${GREEN}IP Address           :${NC}  ${WHITE}$IP${NC}"
    echo -e "${GREEN}System Uptime        :${NC}  ${WHITE}$UPTIME${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${BGBLUE}${WHITE}                     MENU MANAGER                            ${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e " [${AQUA}01${NC}] ${WHITE}Pengurusan SSH & OpenVPN${NC}     [${AQUA}08${NC}] ${WHITE}Papar Port OpenVPN${NC}"
    echo -e " [${AQUA}02${NC}] ${WHITE}Pengurusan Xray VMess${NC}        [${AQUA}09${NC}] ${WHITE}Maklumat Hysteria2${NC}"
    echo -e " [${AQUA}03${NC}] ${WHITE}Pengurusan Xray VLESS${NC}        [${AQUA}10${NC}] ${WHITE}Maklumat SSH Proxy${NC}"
    echo -e " [${AQUA}04${NC}] ${WHITE}Pengurusan Hysteria2${NC}         [${AQUA}11${NC}] ${WHITE}Restart Semua Servis${NC}"
    echo -e " [${AQUA}05${NC}] ${WHITE}Pengurusan Backup${NC}            [${AQUA}12${NC}] ${WHITE}Tukar Port Perkhidmatan${NC}"
    echo -e " [${AQUA}06${NC}] ${WHITE}Pengurusan Bot Telegram${NC}      [${AQUA}13${NC}] ${WHITE}Kemas Kini Script${NC}"
    echo -e " [${AQUA}07${NC}] ${WHITE}Semak Status Perkhidmatan${NC}    [${AQUA}14${NC}] ${WHITE}Keluar${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Versi Script:${NC} ${RED}${SCRIPT_VERSION}${NC}"
    echo -e ""
    read -p "[###] Pilih Menu [01-14]: " num
    echo -e ""
    case $num in
      1|01) menussh ;;
      2|02) menuvmess ;;
      3|03) menuvless ;;
      4|04) menuhysteria ;;
      5|05) menubackup ;;
      6|06) menubot ;;
      7|07) 
        title_banner
        echo -e "${PURPLE}${BOLD}Status Perkhidmatan:${RESET}"
        echo -e "${FULL_BORDER}"
        services=(
          "nginx:Nginx Web Server"
          "xray:Xray-core"
          "dropbear:Dropbear SSH"
          "stunnel4:Stunnel4"
          "badvpn-udpgw:BadVPN UDPGW"
          "ssh:OpenSSH"
          "hysteria2:Hysteria2"
          "openvpn@server-udp-1194:OpenVPN UDP 1194"
          "openvpn@server-tcp-443:OpenVPN TCP 1443"
          "openvpn@server-udp-53:OpenVPN UDP 2053"
          "openvpn@server-tcp-80:OpenVPN TCP 8080"
          "squid:Squid Proxy" # Tambahkan Squid
          "ohp:OHP Server" # Tambahkan OHP
          "ws-python-proxy:SSH WS Python Proxy" # Tambahkan SSH WS Python Proxy
        )
        for service_info in "${services[@]}"; do
          service_name="${service_info%%:*}"
          service_desc="${service_info##*:}"
          status=$(systemctl is-active "$service_name" 2>/dev/null)
          if [[ "$status" == "active" ]]; then
            echo -e "${YELLOW}  $service_desc: ${BRIGHT_GREEN}●${RESET} ${BRIGHT_GREEN}Aktif${RESET}"
          elif [[ "$status" == "inactive" ]]; then
            echo -e "${YELLOW}  $service_desc: ${RED}●${RESET} ${RED}Tidak Aktif${RESET}"
          elif [[ "$status" == "failed" ]]; then
            echo -e "${YELLOW}  $service_desc: ${RED}●${RESET} ${RED}Gagal${RESET}"
          else
            echo -e "${YELLOW}  $service_desc: ${GRAY}●${RESET} ${GRAY}$status${RESET}"
          fi
        done
        echo -e "${FULL_BORDER}"
        echo -e "${WHITE}${BOLD}Maklumat Sistem Tambahan:${RESET}"
        echo -e "${YELLOW}  Load Average: ${LIGHT_CYAN}$(uptime | awk -F'load average:' '{print $2}')${RESET}"
        echo -e "${YELLOW}  Memory Usage: ${LIGHT_CYAN}$(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}')${RESET}"
        echo -e "${YELLOW}  Disk Usage:   ${LIGHT_CYAN}$(df -h / | awk 'NR==2{print $5}')${RESET}"
        echo -e "${FULL_BORDER}"
        pause ;;
      8|08) title_banner; show_openvpn_ports; pause ;;
      9|09) title_banner; show_hysteria_info; pause ;;
      10) title_banner
          echo -e "${PURPLE}${BOLD}Maklumat SSH WS Proxy${RESET}"
          echo -e "${FULL_BORDER}"
          echo -e "${YELLOW}  SSH Proxy: ${LIGHT_CYAN}8880${RESET}"
          echo -e " - Payload contoh: GET /cdn-cgi/trace HTTP/1.1[crlf]Host: [host][crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]"
          echo -e "${FULL_BORDER}"
          pause ;;
      11) 
        echo -e "${YELLOW}Restart semua servis...${NC}"
        systemctl restart nginx xray ws-python-proxy openvpn@server-udp-1194 openvpn@server-tcp-443 openvpn@server-udp-53 openvpn@server-tcp-80 dropbear stunnel4 badvpn-udpgw hysteria2
        echo -e "${BRIGHT_GREEN}✔ Semua servis telah direstart.${NC}"
        sleep 2 ;;
      12) changeport ;;
      13) update_script ;;
      14|x|X|exit|keluar) clear; echo "Terima kasih kerana menggunakan Sistem Pengurusan VPN MAJ SPACE!"; exit 0 ;;
      *) echo -e "${RED}✘ Pilihan tidak sah. Sila pilih angka yang tersedia.${NC}" ; sleep 1 ;;
    esac
  done
}

main_menu