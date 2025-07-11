# File: MultipleFiles/menussh.sh
#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Fungsi untuk mengubah port SSH (OpenSSH)
change_ssh_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Ubah Port SSH (OpenSSH)${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' | head -n 1)
  echo -e "${YELLOW}Port SSH semasa: ${LIGHT_CYAN}$current_port${RESET}"
  read -rp "Masukkan port SSH baru (cth: 2222): " new_port

  if ! validate_port "$new_port"; then
    pause
    return
  fi
  if ! is_port_in_use "$new_port"; then
    pause
    return
  fi

  loading_animation "Mengubah port SSH ke $new_port"

  # Ubah dalam fail konfigurasi
  sed -i "s/^Port ${current_port}/Port ${new_port}/" /etc/ssh/sshd_config

  # Kemas kini firewall
  update_iptables_rule "$current_port" "$new_port" "tcp"
  update_ufw_rule "$current_port" "$new_port" "tcp"

  # Restart perkhidmatan
  systemctl restart ssh 2>/dev/null

  echo -e "${BRIGHT_GREEN}✔ Port SSH berjaya diubah dari ${current_port} ke ${new_port}.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk mengubah port Dropbear
change_dropbear_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Ubah Port Dropbear${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port1=$(grep -E "^DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2)
  local current_port2=$(grep -E "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | grep -oP '\-p \K\d+' | head -n 1)

  echo -e "${YELLOW}Port Dropbear semasa: ${LIGHT_CYAN}$current_port1, $current_port2${RESET}"
  read -rp "Masukkan port utama Dropbear baru (cth: 1099): " new_port1
  read -rp "Masukkan port tambahan Dropbear baru (cth: 1433): " new_port2

  if ! validate_port "$new_port1" || ! validate_port "$new_port2"; then
    pause
    return
  fi
  if ! is_port_in_use "$new_port1" || ! is_port_in_use "$new_port2"; then
    pause
    return
  fi
  if [[ "$new_port1" == "$new_port2" ]]; then
    echo -e "${RED}✘ Ralat: Port utama dan tambahan tidak boleh sama.${RESET}"
    pause
    return
  fi

  loading_animation "Mengubah port Dropbear"

  # Ubah dalam fail konfigurasi
  sed -i "s/^DROPBEAR_PORT=${current_port1}/DROPBEAR_PORT=${new_port1}/" /etc/default/dropbear
  sed -i "s/DROPBEAR_EXTRA_ARGS=\"-p ${current_port2}\"/DROPBEAR_EXTRA_ARGS=\"-p ${new_port2}\"/" /etc/default/dropbear

  # Kemas kini firewall
  update_iptables_rule "$current_port1" "$new_port1" "tcp"
  update_ufw_rule "$current_port1" "$new_port1" "tcp"
  update_iptables_rule "$current_port2" "$new_port2" "tcp"
  update_ufw_rule "$current_port2" "$new_port2" "tcp"

  # Restart perkhidmatan
  systemctl restart dropbear 2>/dev/null

  echo -e "${BRIGHT_GREEN}✔ Port Dropbear berjaya diubah dari ${current_port1}, ${current_port2} ke ${new_port1}, ${new_port2}.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk mengubah port Stunnel4
change_stunnel_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Ubah Port Stunnel4${RESET}"
  echo -e "${FULL_BORDER}"

  local current_ssh_port=$(grep -A1 "\$ssh\$" /etc/stunnel/stunnel.conf | grep "accept" | awk '{print $3}')
  local current_dropbear_port=$(grep -A1 "\$dropbear\$" /etc/stunnel/stunnel.conf | grep "accept" | awk '{print $3}')
  local current_openvpn_port=$(grep -A1 "\$openvpn-ssl\$" /etc/stunnel/stunnel.conf | grep "accept" | awk '{print $3}')

  echo -e "${YELLOW}Port Stunnel4 semasa:${RESET}"
  echo -e "${YELLOW}  SSH: ${LIGHT_CYAN}$current_ssh_port${RESET}"
  echo -e "${YELLOW}  Dropbear: ${LIGHT_CYAN}$current_dropbear_port${RESET}"
  echo -e "${YELLOW}  OpenVPN-SSL: ${LIGHT_CYAN}$current_openvpn_port${RESET}"

  read -rp "Masukkan port Stunnel4 untuk SSH baru (cth: 4444): " new_ssh_port
  read -rp "Masukkan port Stunnel4 untuk Dropbear baru (cth: 7777): " new_dropbear_port
  read -rp "Masukkan port Stunnel4 untuk OpenVPN-SSL baru (cth: 9922): " new_openvpn_port

  if ! validate_port "$new_ssh_port" || ! validate_port "$new_dropbear_port" || ! validate_port "$new_openvpn_port"; then
    pause
    return
  fi
  if ! is_port_in_use "$new_ssh_port" || ! is_port_in_use "$new_dropbear_port" || ! is_port_in_use "$new_openvpn_port"; then
    pause
    return
  fi

  loading_animation "Mengubah port Stunnel4"

  # Ubah dalam fail konfigurasi
  sed -i "s/accept = ${current_ssh_port}/accept = ${new_ssh_port}/" /etc/stunnel/stunnel.conf
  sed -i "s/accept = ${current_dropbear_port}/accept = ${new_dropbear_port}/" /etc/stunnel/stunnel.conf
  sed -i "s/accept = ${current_openvpn_port}/accept = ${new_openvpn_port}/" /etc/stunnel/stunnel.conf

  # Kemas kini firewall
  update_iptables_rule "$current_ssh_port" "$new_ssh_port" "tcp"
  update_ufw_rule "$current_ssh_port" "$new_ssh_port" "tcp"
  update_iptables_rule "$current_dropbear_port" "$new_dropbear_port" "tcp"
  update_ufw_rule "$current_dropbear_port" "$new_dropbear_port" "tcp"
  update_iptables_rule "$current_openvpn_port" "$new_openvpn_port" "tcp"
  update_ufw_rule "$current_openvpn_port" "$new_openvpn_port" "tcp"

  # Restart perkhidmatan
  systemctl restart stunnel4 2>/dev/null

  echo -e "${BRIGHT_GREEN}✔ Port Stunnel4 berjaya diubah.${RESET}"
  echo -e "${YELLOW}  SSH: ${current_ssh_port} -> ${new_ssh_port}${RESET}"
  echo -e "${YELLOW}  Dropbear: ${current_dropbear_port} -> ${new_dropbear_port}${RESET}"
  echo -e "${YELLOW}  OpenVPN-SSL: ${current_openvpn_port} -> ${new_openvpn_port}${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk mengubah port OpenVPN
change_openvpn_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Ubah Port OpenVPN${RESET}"
  echo -e "${FULL_BORDER}"

  echo -e "${WHITE}Pilih konfigurasi OpenVPN untuk diubah portnya:${RESET}"
  echo -e "${YELLOW}  1. ${WHITE}UDP 1194${RESET}"
  echo -e "${YELLOW}  2. ${WHITE}TCP 1443${RESET}"
  echo -e "${YELLOW}  3. ${WHITE}UDP 2053${RESET}"
  echo -e "${YELLOW}  4. ${WHITE}TCP 8080${RESET}"
  echo -e "${YELLOW}  5. ${WHITE}TCP 1194 (jika ada)${RESET}"
  echo -e "${YELLOW}  0. ${WHITE}Batal${RESET}"
  echo -ne "${WHITE}Pilih pilihan [0-5]: ${RESET}"
  read ovpn_choice

  local config_file=""
  local current_port=""
  local protocol=""
  local service_name=""

  case $ovpn_choice in
    1) config_file="/etc/openvpn/server-udp-1194.conf"; current_port="1194"; protocol="udp"; service_name="openvpn@server-udp-1194" ;;
    2) config_file="/etc/openvpn/server-tcp-443.conf"; current_port="1443"; protocol="tcp"; service_name="openvpn@server-tcp-443" ;;
    3) config_file="/etc/openvpn/server-udp-53.conf"; current_port="2053"; protocol="udp"; service_name="openvpn@server-udp-53" ;;
    4) config_file="/etc/openvpn/server-tcp-80.conf"; current_port="8080"; protocol="tcp"; service_name="openvpn@server-tcp-80" ;;
    5) config_file="/etc/openvpn/server-tcp-1194.conf"; current_port="1194"; protocol="tcp"; service_name="openvpn@server-tcp-1194" ;;
    0) echo -e "${YELLOW}Pembatalan diubah port.${RESET}"; pause; return ;;
    *) echo -e "${RED}✘ Pilihan tidak sah.${RESET}"; pause; return ;;
  esac

  if [[ ! -f "$config_file" ]]; then
    echo -e "${RED}✘ Ralat: Fail konfigurasi OpenVPN tidak ditemui untuk pilihan ini.${RESET}"
    pause
    return
  fi

  read -rp "Masukkan port baru untuk ${protocol^^} ${current_port}: " new_port

  if ! validate_port "$new_port"; then
    pause
    return
  fi
  if ! is_port_in_use "$new_port"; then
    pause
    return
  fi

  loading_animation "Mengubah port OpenVPN ${protocol^^} ${current_port} ke ${new_port}"

  # Ubah dalam fail konfigurasi
  sed -i "s/^port ${current_port}/port ${new_port}/" "$config_file"
  sed -i "s/^proto ${protocol}/proto ${protocol}/" "$config_file" # Pastikan proto tidak berubah

  # Kemas kini firewall
  update_iptables_rule "$current_port" "$new_port" "$protocol"
  update_ufw_rule "$current_port" "$new_port" "$protocol"

  # Restart perkhidmatan
  systemctl restart "$service_name" 2>/dev/null

  echo -e "${BRIGHT_GREEN}✔ Port OpenVPN ${protocol^^} berjaya diubah dari ${current_port} ke ${new_port}.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk mengubah port SSH WebSocket Python Proxy
change_ws_proxy_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Ubah Port SSH WebSocket Python Proxy${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port=$(grep -oP '\-p \K\d+' /etc/systemd/system/ws-python-proxy.service | head -n 1)
  echo -e "${YELLOW}Port SSH WS Proxy semasa: ${LIGHT_CYAN}$current_port${RESET}"
  read -rp "Masukkan port SSH WS Proxy baru (cth: 8888): " new_port

  if ! validate_port "$new_port"; then
    pause
    return
  fi
  if ! is_port_in_use "$new_port"; then
    pause
    return
  fi

  loading_animation "Mengubah port SSH WS Proxy ke $new_port"

  # Ubah dalam fail konfigurasi systemd service
  sed -i "s/\-p ${current_port}/\-p ${new_port}/" /etc/systemd/system/ws-python-proxy.service

  # Ubah dalam fail proxy.py (jika ada hardcode, walaupun sepatutnya dari argumen)
  # Ini adalah langkah berjaga-jaga jika ada hardcode di dalam proxy.py
  sed -i "s/LISTENING_PORT = ${current_port}/LISTENING_PORT = ${new_port}/" /usr/local/proxy.py 2>/dev/null

  # Kemas kini firewall
  update_iptables_rule "$current_port" "$new_port" "tcp"
  update_ufw_rule "$current_port" "$new_port" "tcp"

  # Reload daemon dan restart perkhidmatan
  systemctl daemon-reload > /dev/null 2>&1
  systemctl restart ws-python-proxy 2>/dev/null

  echo -e "${BRIGHT_GREEN}✔ Port SSH WebSocket Python Proxy berjaya diubah dari ${current_port} ke ${new_port}.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

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
    echo -e "${YELLOW}  7. ${WHITE}Ubah Port SSH (OpenSSH)${RESET}"
    echo -e "${YELLOW}  8. ${WHITE}Ubah Port Dropbear${RESET}"
    echo -e "${YELLOW}  9. ${WHITE}Ubah Port Stunnel4${RESET}"
    echo -e "${YELLOW} 10. ${WHITE}Ubah Port OpenVPN${RESET}"
    echo -e "${YELLOW} 11. ${WHITE}Ubah Port SSH WS Python Proxy${RESET}"
    echo -e "${SECTION_DIVIDER}"
    echo -e "${YELLOW} 12. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [1-12]: ${RESET}"
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
          echo -e "${YELLOW}  Domain:        ${LIGHT_CYAN}$DOMAIN${RESET}"
          echo -e "${YELLOW}  SSH:           ${LIGHT_CYAN}22${RESET}"
          echo -e "${YELLOW}  DROPBEAR:      ${LIGHT_CYAN}143, 109${RESET}"
          echo -e "${YELLOW}  SSL/TLS:       ${LIGHT_CYAN}444, 777${RESET}"
          echo -e "${YELLOW}  UDPGW:         ${LIGHT_CYAN}7100-7900${RESET}"
          echo -e "${YELLOW}  SSH WS PROXY:  ${LIGHT_CYAN}8880${RESET}"
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
          echo -e "${YELLOW}  OHP 8087: ${LIGHT_CYAN}http://$IP/ohp-ovpn-tcp.ovpn${RESET}"
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
      7) change_ssh_port ;;
      8) change_dropbear_port ;;
      9) change_stunnel_port ;;
      10) change_openvpn_port ;;
      11) change_ws_proxy_port ;;
      12) # Kembali ke Menu Utama
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 1 dan 12.${NC}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu
ssh_menu_ops