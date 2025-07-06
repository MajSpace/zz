# File: MultipleFiles/menussh.sh
#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Sub-Menu SSH
ssh_menu_ops() { # Mengganti nama fungsi agar tidak bentrok dengan nama file
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan SSH & OpenVPN${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Cipta Pengguna SSH${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Semak Pengguna SSH${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Padam Pengguna SSH${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  4. ${WHITE}Cipta Pengguna OpenVPN${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}Semak Pengguna OpenVPN${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}Padam Pengguna OpenVPN${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  7. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [1-7]: ${RESET}"
    read opt
    case $opt in
      1) # Cipta Pengguna SSH
        title_banner
        echo -e "${PURPLE}${BOLD}Cipta Pengguna SSH${RESET}"
        echo -e "${FULL_BORDER}"
        read -rp "Masukkan nama pengguna SSH: " SSH_USER
        if ! validate_username "$SSH_USER" "SSH"; then
          pause
          continue
        fi
        read -rp "Masukkan kata laluan SSH: " SSH_PASS
        if [[ -z "$SSH_PASS" ]]; then
          echo -e "${RED}✘ Ralat: Kata laluan tidak boleh kosong.${RESET}"
          pause
          continue
        fi
        read -rp "Berapa lama sah?: " SSH_DAYS
        if ! validate_days "$SSH_DAYS"; then
          pause
          continue
        fi
        loading_animation "Mencipta pengguna SSH"
        if useradd -e $(date -d "$SSH_DAYS days" +"%Y-%m-%d") -m -s /bin/bash "$SSH_USER" 2>/dev/null; then
          echo "$SSH_USER:$SSH_PASS" | chpasswd
          exp_date=$(chage -l "$SSH_USER" | grep "Account expires" | awk -F": " '{print $2}')
          echo "$SSH_USER | $SSH_PASS | Exp: $exp_date" >> /var/log/ssh-users.log
          echo -e "${BRIGHT_GREEN}✔ Pengguna SSH berjaya dicipta.${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$SSH_USER${RESET}"
          echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$SSH_PASS${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  Alamat IP:     ${LIGHT_CYAN}$IP${RESET}"
          echo -e "${YELLOW}  Hos:           ${LIGHT_CYAN}$DOMAIN${RESET}"
          echo -e "${YELLOW}  SSL/TLS:       ${LIGHT_CYAN}444, 777${RESET}"
          echo -e "${YELLOW}  UDPGW:         ${LIGHT_CYAN}7100-7900${RESET}"
          echo -e "${SECTION_DIVIDER}"
          show_slowdns_info
        else
          echo -e "${RED}✘ Ralat: Gagal mencipta pengguna SSH.${RESET}"
        fi
        pause
        ;;
      2) # Semak Pengguna SSH
        title_banner
        echo -e "${PURPLE}${BOLD}Senarai Pengguna SSH${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t SSH_USERS < <(list_ssh_users)
        if [[ ${#SSH_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna SSH ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna SSH Aktif:${RESET}"
          for user in "${SSH_USERS[@]}"; do
            exp_date=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
            echo -e "${YELLOW}  - ${WHITE}$user ${GRAY}(Tamat Tempoh: $exp_date)${RESET}"
          done
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3) # Padam Pengguna SSH
        title_banner
        echo -e "${PURPLE}${BOLD}Padam Pengguna SSH${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t SSH_USERS < <(list_ssh_users)
        if [[ ${#SSH_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna SSH ditemui.${RESET}"
          pause
          continue
        fi
        echo -e "${WHITE}Pilih pengguna SSH untuk dipadam:${RESET}"
        for i in "${!SSH_USERS[@]}"; do
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${SSH_USERS[$i]}${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#SSH_USERS[@]}]: ${RESET}"
        read SSH_NUM
        if [[ "$SSH_NUM" =~ ^[0-9]+$ ]] && (( SSH_NUM >= 1 && SSH_NUM <= ${#SSH_USERS[@]} )); then
          SSH_USER="${SSH_USERS[$((SSH_NUM-1))]}"
          loading_animation "Memadam pengguna SSH"
          if userdel -r "$SSH_USER" 2>/dev/null; then
            sed -i "/^$SSH_USER|/d" /var/log/ssh-users.log 2>/dev/null
            sed -i "/^$SSH_USER|/d" /var/log/ovpn-users.log 2>/dev/null
            echo -e "${BRIGHT_GREEN}✔ Pengguna SSH '$SSH_USER' berjaya dipadam.${RESET}"
          else
            echo -e "${RED}✘ Ralat: Gagal memadam pengguna SSH '$SSH_USER'.${RESET}"
          fi
        else
          echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4) # Cipta Pengguna OpenVPN
        title_banner
        echo -e "${PURPLE}${BOLD}Cipta Pengguna OpenVPN${RESET}"
        echo -e "${FULL_BORDER}"
        read -rp "Masukkan nama pengguna OpenVPN: " OVPN_USER
        if ! validate_username "$OVPN_USER" "OPENVPN"; then
          pause
          continue
        fi
        read -rp "Masukkan kata laluan OpenVPN: " OVPN_PASS
        if [[ -z "$OVPN_PASS" ]]; then
          echo -e "${RED}✘ Ralat: Kata laluan tidak boleh kosong.${RESET}"
          pause
          continue
        fi
        read -rp "Berapa lama sah?: " OVPN_DAYS
        if ! validate_days "$OVPN_DAYS"; then
          pause
          continue
        fi
        loading_animation "Mencipta pengguna OpenVPN"
        if useradd -e $(date -d "$OVPN_DAYS days" +"%Y-%m-%d") -m -s /bin/bash "$OVPN_USER" 2>/dev/null; then
          echo "$OVPN_USER:$OVPN_PASS" | chpasswd
          exp_date=$(chage -l "$OVPN_USER" | grep "Account expires" | awk -F": " '{print $2}')
          echo "$OVPN_USER | $OVPN_PASS | Exp: $exp_date" >> /var/log/ovpn-users.log
          OVPN_WEBDIR="/var/www/html"
          mkdir -p "$OVPN_WEBDIR"
          for MODE in udp1194 tcp1443 udp2053 tcp8080; do
            case $MODE in
              udp1194) PORT=1194; PROTO=udp ;;
              tcp1443) PORT=1443; PROTO=tcp ;;
              udp2053) PORT=2053; PROTO=udp ;;
              tcp8080) PORT=8080; PROTO=tcp ;;
            esac
            cat > "$OVPN_WEBDIR/client-${OVPN_USER}-${MODE}.ovpn" <<-END
client
dev tun
proto $PROTO
remote $DOMAIN $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
setenv CLIENT_CERT 0
verb 3
<ca>
$(cat /etc/openvpn/ca.crt 2>/dev/null)
</ca>
<tls-auth>
$(cat /etc/openvpn/ta.key 2>/dev/null)
</tls-auth>
key-direction 1
END
          done
          echo -e "${BRIGHT_GREEN}✔ Pengguna OpenVPN berjaya dicipta.${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$OVPN_USER${RESET}"
          echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$OVPN_PASS${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          show_openvpn_ports
          echo -e "${WHITE}Muat Turun Konfigurasi OVPN:${RESET}"
          echo -e "${YELLOW}  UDP 1194: ${LIGHT_CYAN}http://$IP/client-${OVPN_USER}-udp1194.ovpn${RESET}"
          echo -e "${YELLOW}  TCP 1443: ${LIGHT_CYAN}http://$IP/client-${OVPN_USER}-tcp1443.ovpn${RESET}"
          echo -e "${YELLOW}  UDP 2053: ${LIGHT_CYAN}http://$IP/client-${OVPN_USER}-udp2053.ovpn${RESET}"
          echo -e "${YELLOW}  TCP 8080: ${LIGHT_CYAN}http://$IP/client-${OVPN_USER}-tcp8080.ovpn${RESET}"
          echo -e "${SECTION_DIVIDER}"
        else
          echo -e "${RED}✘ Ralat: Gagal mencipta pengguna OpenVPN.${RESET}"
        fi
        pause
        ;;
      5) # Semak Pengguna OpenVPN
        title_banner
        echo -e "${PURPLE}${BOLD}Senarai Pengguna OpenVPN${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t OVPN_USERS < <(list_openvpn_users)
        if [[ ${#OVPN_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna OpenVPN ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna OpenVPN Aktif:${RESET}"
          for user in "${OVPN_USERS[@]}"; do
            exp_date=$(grep "^$user |" /var/log/ovpn-users.log | awk -F'|' '{print $3}' | awk '{print $2}')
            echo -e "${YELLOW}  - ${WHITE}$user ${GRAY}(Tamat Tempoh: $exp_date)${RESET}"
          done
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      6) # Padam Pengguna OpenVPN
        title_banner
        echo -e "${PURPLE}${BOLD}Padam Pengguna OpenVPN${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t OVPN_USERS < <(list_openvpn_users)
        if [[ ${#OVPN_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna OpenVPN ditemui.${RESET}"
          pause
          continue
        fi
        echo -e "${WHITE}Pilih pengguna OpenVPN untuk dipadam:${RESET}"
        for i in "${!OVPN_USERS[@]}"; do
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${OVPN_USERS[$i]}${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#OVPN_USERS[@]}]: ${RESET}"
        read OVPN_NUM
        if [[ "$OVPN_NUM" =~ ^[0-9]+$ ]] && (( OVPN_NUM >= 1 && OVPN_NUM <= ${#OVPN_USERS[@]} )); then
          OVPN_USER="${OVPN_USERS[$((OVPN_NUM-1))]}"
          loading_animation "Memadam pengguna OpenVPN"
          if userdel -r "$OVPN_USER" 2>/dev/null; then
            sed -i "/^$OVPN_USER|/d" /var/log/ovpn-users.log 2>/dev/null
            sed -i "/^$OVPN_USER|/d" /var/log/ssh-users.log 2>/dev/null
            rm -f /var/www/html/client-${OVPN_USER}-*.ovpn 2>/dev/null
            echo -e "${BRIGHT_GREEN}✔ Pengguna OpenVPN '$OVPN_USER' berjaya dipadam.${RESET}"
          else
            echo -e "${RED}✘ Ralat: Gagal memadam pengguna OpenVPN '$OVPN_USER'.${RESET}"
          fi
        else
          echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      7) # Kembali ke Menu Utama
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 1 dan 7.${RESET}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu
ssh_menu_ops