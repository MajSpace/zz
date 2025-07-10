#!/bin/bash

# Source utilitas global
source /usr/local/bin/utils.sh

# Warna (tambahan untuk style baru)
BGAQUA="\033[1;46m"
BGRED="\033[1;41m"
AQUA="\033[1;36m"
NC="\033[0m"

main_menu() {
  while true; do
    clear
    # Header Sistem Info
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${BGAQUA}                     SISTEM INFORMATION                      ${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}ISP                  :${NC}  $ISP"
    echo -e "${GREEN}Domain               :${NC}  $DOMAIN"
    echo -e "${GREEN}IP Address           :${NC}  $IP"
    echo -e "${GREEN}System Uptime        :${NC}  $UPTIME"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"

    echo -e "${BGRED}                        SERVICE STATUS                       ${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    # Status servis utama (pakai logic script Anda)
    state_nginx=$(systemctl is-active nginx)
    state_xray=$(systemctl is-active xray)
    state_ws=$(systemctl is-active ws-python-proxy)
    state_openvpn=$(systemctl is-active openvpn@server-udp-1194)
    state_hysteria=$(systemctl is-active hysteria2)
    echo -e "  NGINX = $state_nginx   XRAY = $state_xray   WS-SSH = $state_ws"
    echo -e "  OPENVPN = $state_openvpn   HYSTERIA2 = $state_hysteria"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"

    echo -e "${BGAQUA}                         MENU MANAGER                        ${NC}"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e " [${AQUA}01${NC}] Pengurusan SSH & OpenVPN     [${AQUA}07${NC}] Semak Status Perkhidmatan"
    echo -e " [${AQUA}02${NC}] Pengurusan Xray VMess        [${AQUA}08${NC}] Papar Port OpenVPN"
    echo -e " [${AQUA}03${NC}] Pengurusan Xray VLESS        [${AQUA}09${NC}] Maklumat Hysteria2"
    echo -e " [${AQUA}04${NC}] Pengurusan Hysteria2         [${AQUA}10${NC}] Maklumat SSH Proxy"
    echo -e " [${AQUA}05${NC}] Pengurusan Backup            [${AQUA}11${NC}] Restart Semua Servis"
    echo -e " [${AQUA}06${NC}] Pengurusan Bot Telegram      [${AQUA}12${NC}] Keluar"
    echo -e "${YELLOW}═════════════════════════════════════════════════════════════${NC}"
    echo -e ""
    read -p "[###] Pilih Menu [01-12]: " num
    echo -e ""
    case $num in
      1|01) menussh ;;
      2|02) menuvmess ;;
      3|03) menuvless ;;
      4|04) menuhysteria ;;
      5|05) menubackup ;;
      6|06) menubot ;;
      7|07) 
        # Panggil logic status perkhidmatan dari script Anda
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
      12|x|X|exit|keluar) clear; echo "Terima kasih kerana menggunakan Sistem Pengurusan VPN MAJ SPACE!"; exit 0 ;;
      *) echo -e "${RED}✘ Pilihan tidak sah. Sila pilih angka yang tersedia.${NC}" ; sleep 1 ;;
    esac
  done
}

main_menu
