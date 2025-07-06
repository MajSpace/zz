#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Sub-Menu SSH
ssh_menu_ops() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan SSH & OpenVPN${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}${BOLD}Cipta Pengguna SSH${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}${BOLD}Semak Pengguna SSH${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}${BOLD}Padam Pengguna SSH${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  4. ${WHITE}${BOLD}Cipta Pengguna OpenVPN${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}${BOLD}Semak Pengguna OpenVPN${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}${BOLD}Padam Pengguna OpenVPN${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  7. ${WHITE}${BOLD}Test HTTP Proxy SSH${RESET}"
    echo -e "${YELLOW}  8. ${WHITE}${BOLD}Restart HTTP Proxy SSH${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW}  9. ${WHITE}${BOLD}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [1-9]: ${RESET}"
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
        read -rp "Berapa lama sah? (hari): " SSH_DAYS
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
          echo -e "${WHITE}${BOLD}Maklumat Pengguna SSH:${RESET}"
          echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$SSH_USER${RESET}"
          echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$SSH_PASS${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${WHITE}${BOLD}Maklumat Server:${RESET}"
          echo -e "${YELLOW}  Alamat IP:     ${LIGHT_CYAN}$IP${RESET}"
          echo -e "${YELLOW}  Hos/Domain:    ${LIGHT_CYAN}$DOMAIN${RESET}"
          echo -e "${SECTION_DIVIDER}"
          show_ssh_info
          show_slowdns_info
          echo -e "${SECTION_DIVIDER}"
          echo -e "${WHITE}${BOLD}HTTP Proxy SSH:${RESET}"
          echo -e "${YELLOW}  Server:        ${LIGHT_CYAN}$DOMAIN${RESET}"
          echo -e "${YELLOW}  Port HTTP:     ${LIGHT_CYAN}8880${RESET}"
          echo -e "${YELLOW}  Port SSH:      ${LIGHT_CYAN}22${RESET}"
          echo -e "${YELLOW}  Method:        ${LIGHT_CYAN}HTTP CONNECT${RESET}"
          echo -e "${SECTION_DIVIDER}"
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
          echo -e "${WHITE}${BOLD}Pengguna SSH Aktif:${RESET}"
          echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────┐${RESET}"
          printf "${YELLOW}│ %-15s │ %-20s │ %-15s │${RESET}\n" "Pengguna" "Tamat Tempoh" "Status"
          echo -e "${YELLOW}├─────────────────────────────────────────────────────────────┤${RESET}"
          for user in "${SSH_USERS[@]}"; do
            exp_date=$(chage -l "$user" | grep "Account expires" | awk -F": " '{print $2}')
            if [[ "$exp_date" == "never" ]]; then
              status="${BRIGHT_GREEN}Kekal${RESET}"
              exp_display="Tiada"
            else
              exp_timestamp=$(date -d "$exp_date" +%s 2>/dev/null)
              current_timestamp=$(date +%s)
              if [[ $exp_timestamp -gt $current_timestamp ]]; then
                status="${BRIGHT_GREEN}Aktif${RESET}"
                exp_display="$exp_date"
              else
                status="${RED}Tamat${RESET}"
                exp_display="$exp_date"
              fi
            fi
            printf "${YELLOW}│${RESET} %-15s ${YELLOW}│${RESET} %-20s ${YELLOW}│${RESET} %-15s ${YELLOW}│${RESET}\n" "$user" "$exp_display" "$status"
          done
          echo -e "${YELLOW}└─────────────────────────────────────────────────────────────┘${RESET}"
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
        echo -e "${WHITE}${BOLD}Pilih pengguna SSH untuk dipadam:${RESET}"
        for i in "${!SSH_USERS[@]}"; do
          exp_date=$(chage -l "${SSH_USERS[$i]}" | grep "Account expires" | awk -F": " '{print $2}')
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${SSH_USERS[$i]} ${GRAY}(Tamat: $exp_date)${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#SSH_USERS[@]}]: ${RESET}"
        read SSH_NUM
        if [[ "$SSH_NUM" =~ ^[0-9]+$ ]] && (( SSH_NUM >= 1 && SSH_NUM <= ${#SSH_USERS[@]} )); then
          SSH_USER="${SSH_USERS[$((SSH_NUM-1))]}"
          echo -ne "${RED}Adakah anda pasti mahu memadam pengguna '$SSH_USER'? (y/N): ${RESET}"
          read confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            loading_animation "Memadam pengguna SSH"
            if userdel -r "$SSH_USER" 2>/dev/null; then
              sed -i "/^$SSH_USER|/d" /var/log/ssh-users.log 2>/dev/null
              sed -i "/^$SSH_USER|/d" /var/log/ovpn-users.log 2>/dev/null
              echo -e "${BRIGHT_GREEN}✔ Pengguna SSH '$SSH_USER' berjaya dipadam.${RESET}"
            else
              echo -e "${RED}✘ Ralat: Gagal memadam pengguna SSH '$SSH_USER'.${RESET}"
            fi
          else
            echo -e "${YELLOW}Pembatalan dipadam.${RESET}"
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
        read -rp "Berapa lama sah? (hari): " OVPN_DAYS
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
          echo -e "${WHITE}${BOLD}Maklumat Pengguna OpenVPN:${RESET}"
          echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$OVPN_USER${RESET}"
          echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$OVPN_PASS${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          show_openvpn_ports
          echo -e "${WHITE}${BOLD}Muat Turun Konfigurasi OVPN:${RESET}"
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
          echo -e "${WHITE}${BOLD}Pengguna OpenVPN Aktif:${RESET}"
          echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────┐${RESET}"
          printf "${YELLOW}│ %-15s │ %-20s │ %-15s │${RESET}\n" "Pengguna" "Tamat Tempoh" "Status"echo -e "${YELLOW}├─────────────────────────────────────────────────────────────┤${RESET}"
          for user in "${OVPN_USERS[@]}"; do
            exp_date=$(grep "^$user |" /var/log/ovpn-users.log | awk -F'| Exp: ' '{print $2}' | awk '{print $1}')
            if [[ -z "$exp_date" ]]; then
              exp_display="Tidak Diketahui"
              status="${GRAY}Tidak Diketahui${RESET}"
            else
              exp_timestamp=$(date -d "$exp_date" +%s 2>/dev/null)
              current_timestamp=$(date +%s)
              if [[ $exp_timestamp -gt $current_timestamp ]]; then
                status="${BRIGHT_GREEN}Aktif${RESET}"
                exp_display="$exp_date"
              else
                status="${RED}Tamat${RESET}"
                exp_display="$exp_date"
              fi
            fi
            printf "${YELLOW}│${RESET} %-15s ${YELLOW}│${RESET} %-20s ${YELLOW}│${RESET} %-15s ${YELLOW}│${RESET}\n" "$user" "$exp_display" "$status"
          done
          echo -e "${YELLOW}└─────────────────────────────────────────────────────────────┘${RESET}"
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
        echo -e "${WHITE}${BOLD}Pilih pengguna OpenVPN untuk dipadam:${RESET}"
        for i in "${!OVPN_USERS[@]}"; do
          exp_date=$(grep "^${OVPN_USERS[$i]} |" /var/log/ovpn-users.log | awk -F'| Exp: ' '{print $2}' | awk '{print $1}')
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${OVPN_USERS[$i]} ${GRAY}(Tamat: $exp_date)${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#OVPN_USERS[@]}]: ${RESET}"
        read OVPN_NUM
        if [[ "$OVPN_NUM" =~ ^[0-9]+$ ]] && (( OVPN_NUM >= 1 && OVPN_NUM <= ${#OVPN_USERS[@]} )); then
          OVPN_USER="${OVPN_USERS[$((OVPN_NUM-1))]}"
          echo -ne "${RED}Adakah anda pasti mahu memadam pengguna '$OVPN_USER'? (y/N): ${RESET}"
          read confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            loading_animation "Memadam pengguna OpenVPN"
            if userdel -r "$OVPN_USER" 2>/dev/null; then
              sed -i "/^$OVPN_USER|/d" /var/log/ovpn-users.log 2>/dev/null
              rm -f /var/www/html/client-"$OVPN_USER"-*.ovpn 2>/dev/null
              echo -e "${BRIGHT_GREEN}✔ Pengguna OpenVPN '$OVPN_USER' berjaya dipadam.${RESET}"
            else
              echo -e "${RED}✘ Ralat: Gagal memadam pengguna OpenVPN '$OVPN_USER'.${RESET}"
            fi
          else
            echo -e "${YELLOW}Pembatalan dipadam.${RESET}"
          fi
        else
          echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      7) # Test HTTP Proxy SSH
        title_banner
        echo -e "${PURPLE}${BOLD}Test HTTP Proxy SSH${RESET}"
        echo -e "${FULL_BORDER}"
        echo -e "${WHITE}Melakukan ujian koneksi ke HTTP Proxy SSH (Port 8880)...${RESET}"
        echo -e "${YELLOW}  Perintah: ${LIGHT_CYAN}curl -I http://$DOMAIN:8880${RESET}"
        echo -e "${SHORT_BORDER}"
        curl -I http://"$DOMAIN":8880
        echo -e "${SHORT_BORDER}"
        echo -e "${WHITE}Jika Anda melihat respons HTTP (misalnya, 'HTTP/1.1 400 Bad Request' atau 'HTTP/1.1 200 OK'),${RESET}"
        echo -e "${WHITE}itu berarti HTTP Proxy SSH berfungsi. '400 Bad Request' adalah normal karena ini bukan permintaan HTTP standar.${RESET}"
        echo -e "${FULL_BORDER}"
        pause
        ;;
      8) # Restart HTTP Proxy SSH
        title_banner
        echo -e "${PURPLE}${BOLD}Restart HTTP Proxy SSH${RESET}"
        echo -e "${FULL_BORDER}"
        loading_animation "Memulakan semula Nginx (HTTP Proxy SSH)"
        if systemctl restart nginx; then
          echo -e "${BRIGHT_GREEN}✔ Nginx (HTTP Proxy SSH) berjaya dimulakan semula.${RESET}"
        else
          echo -e "${RED}✘ Ralat: Gagal memulakan semula Nginx.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      9) # Kembali ke Menu Utama
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 1 dan 9.${RESET}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu SSH
ssh_menu_ops