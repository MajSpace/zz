#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Sub-Menu Hysteria2
hysteria_menu_ops() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Hysteria2${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Cipta Pengguna Hysteria2${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Semak Pengguna Hysteria2${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Padam Pengguna Hysteria2${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Maklumat Perkhidmatan${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}Restart Hysteria2${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}Status Hysteria2${RESET}"
    echo -e "${YELLOW}  7. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [1-7]: ${RESET}"
    read opt
    case $opt in
      1) # Cipta Pengguna Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Cipta Pengguna Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        read -rp "Masukkan nama pengguna Hysteria2: " HY2_USER
        if ! validate_username "$HY2_USER" "HYSTERIA"; then
          pause
          continue
        fi
        
        # Auto-generate password yang kuat
        HY2_PASS=$(generate_password 16)
        echo -e "${YELLOW}Password auto-generated: ${LIGHT_CYAN}$HY2_PASS${RESET}"
        read -rp "Gunakan password ini atau masukkan password sendiri [tekan Enter untuk guna auto]: " custom_pass
        if [[ -n "$custom_pass" ]]; then
          HY2_PASS="$custom_pass"
        fi
        
        read -rp "Berapa lama sah (hari)?: " HY2_DAYS
        if ! validate_days "$HY2_DAYS"; then
          pause
          continue
        fi
        
        # Bandwidth limit (opsional)
        read -rp "Bandwidth limit (Mbps) [kosong untuk unlimited]: " HY2_BANDWIDTH
        if [[ -z "$HY2_BANDWIDTH" ]]; then
          HY2_BANDWIDTH="unlimited"
        else
          if ! [[ "$HY2_BANDWIDTH" =~ ^[0-9]+$ ]] || [[ "$HY2_BANDWIDTH" -le 0 ]]; then
            echo -e "${RED}✘ Ralat: Bandwidth harus angka positif. Menggunakan unlimited.${RESET}"
            HY2_BANDWIDTH="unlimited"
          else
            HY2_BANDWIDTH="${HY2_BANDWIDTH} mbps"
          fi
        fi
        
        loading_animation "Mencipta pengguna Hysteria2"
        
        # Tambah user ke konfigurasi Hysteria2
        exp_date=$(date -d "$HY2_DAYS days" +"%Y-%m-%d")
        
        if add_hysteria_user "$HY2_USER" "$HY2_PASS" "$HY2_BANDWIDTH"; then
          # Simpan ke log file
          echo "$HY2_USER | $HY2_PASS | $HY2_BANDWIDTH | Exp: $exp_date" >> /var/log/hysteria-users.log
          
          # Restart Hysteria2 service
          systemctl restart hysteria2 2>/dev/null
          
          echo -e "${BRIGHT_GREEN}✔ Pengguna Hysteria2 berjaya dicipta.${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$HY2_USER${RESET}"
          echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$HY2_PASS${RESET}"
          echo -e "${YELLOW}  Bandwidth:     ${LIGHT_CYAN}$HY2_BANDWIDTH${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          
          # Generate client config
          generate_hysteria_client_config "$HY2_USER" "$HY2_PASS"
          
          show_hysteria_info
        else
          echo -e "${RED}✘ Ralat: Gagal mencipta pengguna Hysteria2.${RESET}"
        fi
        pause
        ;;
      2) # Semak Pengguna Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Senarai Pengguna Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t HY2_USERS < <(list_hysteria_users)
        if [[ ${#HY2_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna Hysteria2 ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna Hysteria2 Aktif:${RESET}"
          echo -e "${GRAY}┌─────┬──────────────┬──────────────┬──────────────┬──────────────┐${RESET}"
          echo -e "${GRAY}│ No  │ Username     │ Password     │ Bandwidth    │ Expiry       │${RESET}"
          echo -e "${GRAY}├─────┼──────────────┼──────────────┼──────────────┼──────────────┤${RESET}"
          
          local counter=1
          for user in "${HY2_USERS[@]}"; do
            user_info=$(grep "^$user |" /var/log/hysteria-users.log | head -n1)
            if [[ -n "$user_info" ]]; then
              password=$(echo "$user_info" | awk -F'|' '{print $2}' | xargs)
              bandwidth=$(echo "$user_info" | awk -F'|' '{print $3}' | xargs)
              exp_date=$(echo "$user_info" | awk -F'|' '{print $4}' | awk '{print $2}')
              printf "${GRAY}│ %-3s │ %-12s │ %-12s │ %-12s │ %-12s │${RESET}\n" "$counter" "$user" "${password:0:12}" "${bandwidth:0:12}" "$exp_date"
            fi
            ((counter++))
          done
          echo -e "${GRAY}└─────┴──────────────┴──────────────┴──────────────┴──────────────┘${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3) # Padam Pengguna Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Padam Pengguna Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t HY2_USERS < <(list_hysteria_users)
        if [[ ${#HY2_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna Hysteria2 ditemui.${RESET}"
          pause
          continue
        fi
        echo -e "${WHITE}Pilih pengguna Hysteria2 untuk dipadam:${RESET}"
        for i in "${!HY2_USERS[@]}"; do
          exp_date=$(grep "^${HY2_USERS[$i]}|" /var/log/hysteria-users.log | awk -F'|' '{print $4}' | awk '{print $2}')
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${HY2_USERS[$i]} ${GRAY}(Exp: $exp_date)${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#HY2_USERS[@]}]: ${RESET}"
        read HY2_NUM
        if [[ "$HY2_NUM" =~ ^[0-9]+$ ]] && (( HY2_NUM >= 1 && HY2_NUM <= ${#HY2_USERS[@]} )); then
          HY2_USER="${HY2_USERS[$((HY2_NUM-1))]}"
          echo -ne "${RED}Adakah anda pasti untuk memadam '$HY2_USER'? [y/N]: ${RESET}"
          read confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            loading_animation "Memadam pengguna Hysteria2"
            if remove_hysteria_user "$HY2_USER"; then
              # Hapus dari log
              sed -i "/^$HY2_USER|/d" /var/log/hysteria-users.log 2>/dev/null
              # Hapus client config file
              rm -f "/var/www/html/hysteria-$HY2_USER.yaml" 2>/dev/null
              # Restart service
              systemctl restart hysteria2 2>/dev/null
              echo -e "${BRIGHT_GREEN}✔ Pengguna Hysteria2 '$HY2_USER' berjaya dipadam.${RESET}"
            else
              echo -e "${RED}✘ Ralat: Gagal memadam pengguna Hysteria2 '$HY2_USER'.${RESET}"
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
      4) # Maklumat Perkhidmatan
        title_banner
        show_hysteria_info
        echo -e "${WHITE}Maklumat Sambungan Hysteria2:${RESET}"
        echo -e "${YELLOW}  Server:            ${LIGHT_CYAN}$DOMAIN:8443${RESET}"
        echo -e "${YELLOW}  Protocol:          ${LIGHT_CYAN}hysteria2${RESET}"
        echo -e "${YELLOW}  TLS:               ${LIGHT_CYAN}Enabled (SNI: $DOMAIN)${RESET}"
        echo -e "${YELLOW}  ALPN:              ${LIGHT_CYAN}h3${RESET}"
        echo -e "${YELLOW}  Obfuscation:       ${LIGHT_CYAN}salamander${RESET}"
        echo -e "${SECTION_DIVIDER}"
        echo -e "${WHITE}Download Client Configs:${RESET}"
        ls /var/www/html/hysteria-*.yaml 2>/dev/null && {
          for config in /var/www/html/hysteria-*.yaml; do
            filename=$(basename "$config")
            echo -e "${YELLOW}  http://$IP/$filename${RESET}"
          done
        } || echo -e "${GRAY}  Tiada konfigurasi dibuat lagi${RESET}"
        echo -e "${FULL_BORDER}"
        pause
        ;;
      5) # Restart Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Restart Perkhidmatan Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        loading_animation "Memulakan semula Hysteria2"
        if systemctl restart hysteria2; then
          echo -e "${BRIGHT_GREEN}✔ Hysteria2 berjaya dimulakan semula.${RESET}"
        else
          echo -e "${RED}✘ Ralat: Gagal memulakan semula Hysteria2.${RESET}"
          echo -e "${YELLOW}Memeriksa status...${RESET}"
          systemctl status hysteria2 --no-pager -l
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      6) # Status Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Status Perkhidmatan Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        status=$(systemctl is-active hysteria2 2>/dev/null)
        if [[ "$status" == "active" ]]; then
          echo -e "${BRIGHT_GREEN}✔ Hysteria2 sedang aktif${RESET}"
        else
          echo -e "${RED}✘ Hysteria2 tidak aktif (Status: $status)${RESET}"
        fi
        echo -e "${SECTION_DIVIDER}"
        echo -e "${WHITE}Status Terperinci:${RESET}"
        systemctl status hysteria2 --no-pager -l
        echo -e "${SECTION_DIVIDER}"
        echo -e "${WHITE}Log Terkini:${RESET}"
        journalctl -u hysteria2 --no-pager -l -n 10
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

# Fungsi untuk menambah user ke konfigurasi Hysteria2
add_hysteria_user() {
  local username=$1
  local password=$2
  local bandwidth=$3
  
  # Baca konfigurasi sedia ada
  if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
    echo -e "${RED}Fail konfigurasi Hysteria2 tidak ditemui!${RESET}"
    return 1
  fi
  
  # Update password dalam konfigurasi
  sed -i "s/password: .*/password: \"$password\"/" "$HYSTERIA_CONFIG"
  
  # Untuk Hysteria2 v2.6.2, kita gunakan single password approach
  # Setiap user akan menggunakan password yang sama
  return 0
}

# Fungsi untuk membuang user dari konfigurasi Hysteria2
remove_hysteria_user() {
  local username=$1
  
  if [[ ! -f "$HYSTERIA_CONFIG" ]]; then
    echo -e "${RED}Fail konfigurasi Hysteria2 tidak ditemui!${RESET}"
    return 1
  fi
  
  # Untuk single password approach, kita hanya perlu hapus dari log
  # Password tetap sama untuk user lain
  return 0
}

# Fungsi untuk menjana konfigurasi klien Hysteria2
generate_hysteria_client_config() {
  local username=$1
  local password=$2
  local config_file="/var/www/html/hysteria-$username.yaml"
  
  cat > "$config_file" <<EOF
server: $DOMAIN:8443
auth: $password

bandwidth:
  up: 100 mbps
  down: 100 mbps

tls:
  sni: $DOMAIN
  insecure: false

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false

fastOpen: true
lazy: false

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
EOF
  
  chmod 644 "$config_file"
  echo -e "${BRIGHT_GREEN}✔ Konfigurasi klien disimpan: ${LIGHT_CYAN}http://$IP/hysteria-$username.yaml${RESET}"
}

# Panggil fungsi menu
hysteria_menu_ops
