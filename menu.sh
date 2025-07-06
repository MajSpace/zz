# File: MultipleFiles/menu.sh
#!/bin/bash

# Source global utilities file
source /usr/local/bin/utils.sh

# Main Menu
main_menu() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}${BOLD}Pengurusan SSH & OpenVPN${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}${BOLD}Pengurusan Xray Vmess${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}${BOLD}Pengurusan Xray VLESS${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}${BOLD}Pengurusan Hysteria2${RESET}" # Menambahkan Hysteria2
    echo -e "${YELLOW}  5. ${WHITE}${BOLD}Semak Status Perkhidmatan${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}${BOLD}Papar Port OpenVPN${RESET}"
    echo -e "${YELLOW}  0. ${WHITE}${BOLD}Keluar${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [0-6]: ${RESET}"
    read opt
    case $opt in
      1) menussh ;; # Panggil skrip menuss.sh
      2) menuvmess ;; # Panggil skrip menuvmess.sh
      3) menuvless ;; # Panggil skrip menuvless.sh
      4) menuhysteria ;; # Panggil skrip menuhysteria.sh
      5) # Semak Status Perkhidmatan
          title_banner
          echo -e "${PURPLE}${BOLD}Status Perkhidmatan:${RESET}"
          echo -e "${FULL_BORDER}"
          for svc in nginx xray dropbear stunnel4 badvpn-udpgw ssh server-sldns openvpn@server-udp-1194 openvpn@server-tcp-443 openvpn@server-udp-53 openvpn@server-tcp-80 hysteria2; do # Menambahkan hysteria2
            status=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$status" == "active" ]]; then
              echo -e "${YELLOW}  $svc: ${BRIGHT_GREEN}Aktif${RESET}"
            else
              echo -e "${YELLOW}  $svc: ${RED}$status${RESET}"
            fi
          done
          echo -e "${FULL_BORDER}"
          pause
          ;;
      6) # Papar Port OpenVPN
          title_banner
          show_openvpn_ports
          pause
          ;;
      0) # Keluar
          clear
          echo -e "${WHITE}Keluar dari Sistem Pengurusan VPN.${RESET}"
          exit 0
          ;;
      *)
          echo -e "${RED}✖ Pilihan tidak sah. Pilih nombor antara 0 dan 6.${RESET}"
          pause
          ;;
    esac
  done
}

# Mulakan menu utama
main_menu