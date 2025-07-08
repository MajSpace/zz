#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Menu Utama
main_menu() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}           ${UNDERLINE}Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}${BOLD}Pengurusan SSH & OpenVPN${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}${BOLD}Pengurusan Xray VMess${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}${BOLD}Pengurusan Xray VLESS${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}${BOLD}Pengurusan Hysteria2${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}${BOLD}pengurusan Backup${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}${BOLD}Pengurusan Bot Telegram${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  7. ${WHITE}${BOLD}Semak Status Perkhidmatan${RESET}"
    echo -e "${YELLOW}  8. ${WHITE}${BOLD}Papar Port OpenVPN${RESET}"
    echo -e "${YELLOW}  9. ${WHITE}${BOLD}Maklumat SlowDNS${RESET}"
    echo -e "${YELLOW} 10. ${WHITE}${BOLD}Maklumat Hysteria2${RESET}"
    echo -e "${YELLOW} 11. ${WHITE}${BOLD}Maklumat SSH Proxy${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  0. ${WHITE}${BOLD}Keluar${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [0-11]: ${RESET}"
    read opt
    case $opt in
      1) menussh ;; # Panggil skrip menussh.sh
      2) menuvmess ;; # Panggil skrip menuvmess.sh
      3) menuvless ;; # Panggil skrip menuvless.sh
      4) menuhysteria ;; # Panggil skrip menuhysteria.sh
      5) menubackup ;; # Panggil skrip backup.sh
      6) menubot ;; # Panggil skrip menubot.sh
      7) # Semak Status Perkhidmatan
        title_banner
        echo -e "${PURPLE}${BOLD}Status Perkhidmatan:${RESET}"
        echo -e "${FULL_BORDER}"
        
        # Array perkhidmatan untuk diperiksa
        services=(
          "nginx:Nginx Web Server"
          "xray:Xray-core"
          "dropbear:Dropbear SSH"
          "stunnel4:Stunnel4"
          "badvpn-udpgw:BadVPN UDPGW"
          "ssh:OpenSSH"
          "server-sldns:SlowDNS Server"
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
        
        # Tambahan maklumat sistem
        echo -e "${WHITE}${BOLD}Maklumat Sistem Tambahan:${RESET}"
        echo -e "${YELLOW}  Load Average: ${LIGHT_CYAN}$(uptime | awk -F'load average:' '{print $2}')${RESET}"
        echo -e "${YELLOW}  Memory Usage: ${LIGHT_CYAN}$(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}')${RESET}"
        echo -e "${YELLOW}  Disk Usage:   ${LIGHT_CYAN}$(df -h / | awk 'NR==2{print $5}')${RESET}"
        echo -e "${FULL_BORDER}"
        pause
        ;;
      8) # Papar Port OpenVPN
        title_banner
        show_openvpn_ports
        pause
        ;;
      9) # Maklumat SlowDNS
        title_banner
        show_slowdns_info
        pause
        ;;
      10) # Maklumat Hysteria2
        title_banner
        show_hysteria_info
        echo -e "${WHITE}Maklumat Sambungan:${RESET}"
        echo -e "${YELLOW}  Server:     ${LIGHT_CYAN}$DOMAIN:8443${RESET}"
        echo -e "${YELLOW}  Protocol:   ${LIGHT_CYAN}hysteria2${RESET}"
        echo -e "${YELLOW}  Encryption: ${LIGHT_CYAN}AES-256-GCM${RESET}"
        echo -e "${YELLOW}  Obfuscation:${LIGHT_CYAN}salamander${RESET}"
        echo -e "${SHORT_BORDER}"
        pause
        ;;
      11) # Maklumat SSH WebSocket
        title_banner
        echo -e "${PURPLE}${BOLD}Maklumat SSH WS Proxy${RESET}"
        echo -e "${FULL_BORDER}"
        echo -e "${YELLOW}  SSH Proxy: ${LIGHT_CYAN}8880${RESET}"
        echo -e "   - Payload contoh: GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Upgrade: websocket[crlf][crlf]"
        echo -e "${FULL_BORDER}"
        pause
        ;;
      0) # Keluar
        clear
        echo -e "${BRIGHT_GREEN}Terima kasih kerana menggunakan Sistem Pengurusan VPN!${RESET}"
        echo -e "${WHITE}Keluar dari sistem...${RESET}"
        exit 0
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 0 dan 8.${RESET}"
        pause
        ;;
    esac
  done
}

# Mulakan menu utama
main_menu