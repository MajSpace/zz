# File: MultipleFiles/menuvmess.sh
#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Sub-Menu Xray VMess
xray_vmess_menu_ops() { # Mengganti nama fungsi
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Xray VMess${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Cipta Pengguna VMess${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Semak Pengguna VMess${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Padam Pengguna VMess${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [1-4]: ${RESET}"
    read opt
    case $opt in
      1) # Cipta Pengguna VMess
        title_banner
        echo -e "${PURPLE}${BOLD}Cipta Pengguna VMess${RESET}"
        echo -e "${FULL_BORDER}"
        read -rp "Nama pengguna: " XRAY_USER
        if ! validate_username "$XRAY_USER" "XRAY"; then
          pause
          continue
        fi
        read -rp "Berapa lama sah?: " XRAY_DAYS
        if ! validate_days "$XRAY_DAYS"; then
          pause
          continue
        fi
        if [[ ! -f "$XRAY_CONFIG" ]]; then
          echo -e "${RED}✘ Ralat: Fail konfigurasi Xray tidak ditemui.${RESET}"
          pause
          continue
        fi
        loading_animation "Mencipta pengguna VMess"
        XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
        exp_date=$(date -d "$XRAY_DAYS days" +"%Y-%m-%d")
        if jq --arg uuid "$XRAY_UUID" --arg user "$XRAY_USER" '
          .inbounds |= map(
            if (.protocol == "vmess")
            then .settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}]
            else .
            end
          )' "$XRAY_CONFIG" > /tmp/xray_config.json && mv /tmp/xray_config.json "$XRAY_CONFIG"; then
          systemctl restart xray 2>/dev/null
          echo "$XRAY_USER | $XRAY_UUID | vmess | Exp: $exp_date" >> /var/log/xray-users.log
          vmess_json_tls=$(cat <<EOF
{
  "v": "2",
  "ps": "$XRAY_USER",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$XRAY_UUID",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "",
  "tls": "tls"
}
EOF
)
          vmesslink1="vmess://$(echo "$vmess_json_tls" | base64 -w 0)"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  VMess WS TLS: ${LIGHT_CYAN}$vmesslink1${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh: ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          vmess_json_ntls=$(cat <<EOF
{
  "v": "2",
  "ps": "$XRAY_USER",
  "add": "$DOMAIN",
  "port": "80",
  "id": "$XRAY_UUID",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "",
  "tls": "none"
}
EOF
)
          vmesslink2="vmess://$(echo "$vmess_json_ntls" | base64 -w 0)"
          echo -e "${YELLOW}  VMess WS nTLS: ${LIGHT_CYAN}$vmesslink2${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
          vmess_json_grpc=$(cat <<EOF
{
  "v": "2",
  "ps": "$XRAY_USER",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$XRAY_UUID",
  "aid": "0",
  "net": "grpc",
  "path": "vmess-grpc",
  "type": "none",
  "host": "",
  "tls": "tls"
}
EOF
)
          vmesslink3="vmess://$(echo "$vmess_json_grpc" | base64 -w 0)"
          echo -e "${YELLOW}  VMess gRPC: ${LIGHT_CYAN}$vmesslink3${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh: ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
        else
          echo -e "${RED}✘ Ralat: Gagal mengemas kini konfigurasi Xray.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      2) # Semak Pengguna VMess
        title_banner
        echo -e "${PURPLE}${BOLD}Senarai Pengguna VMess${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t XRAY_USERS < <(list_xray_users | grep -E 'vmess') # Filter hanya pengguna VMess
        if [[ ${#XRAY_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna VMess ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna VMess Aktif:${RESET}"
          for user in "${XRAY_USERS[@]}"; do
            exp_date=$(grep "^$user |" /var/log/xray-users.log | awk -F'|' '{print $4}' | awk '{print $2}')
            echo -e "${YELLOW}  - ${WHITE}$user ${GRAY}(Tamat Tempoh: $exp_date)${RESET}"
          done
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3) # Padam Pengguna VMess
        title_banner
        echo -e "${PURPLE}${BOLD}Padam Pengguna VMess${RESET}"
        echo -e "${FULL_BORDER}"
        mapfile -t XRAY_USERS < <(list_xray_users | grep -E 'vmess') # Filter hanya pengguna VMess
        if [[ ${#XRAY_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna VMess ditemui.${RESET}"
          pause
          continue
        fi
        echo -e "${WHITE}Pilih pengguna VMess untuk dipadam:${RESET}"
        for i in "${!XRAY_USERS[@]}"; do
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${XRAY_USERS[$i]}${RESET}"
        done
        echo -ne "${WHITE}Masukkan nombor [1-${#XRAY_USERS[@]}]: ${RESET}"
        read XRAY_NUM
        if [[ "$XRAY_NUM" =~ ^[0-9]+$ ]] && (( XRAY_NUM >= 1 && XRAY_NUM <= ${#XRAY_USERS[@]} )); then
          XRAY_USER="${XRAY_USERS[$((XRAY_NUM-1))]}"
          loading_animation "Memadam pengguna VMess"
          if jq --arg user "$XRAY_USER" '
            .inbounds |= map(
              if .protocol == "vmess" and .settings.clients != null
              then .settings.clients |= map(select(.email != $user))
              else .
              end
            )' "$XRAY_CONFIG" > /tmp/xray_config.json && mv /tmp/xray_config.json "$XRAY_CONFIG"; then
            systemctl restart xray 2>/dev/null
            sed -i "/^$XRAY_USER |.*vmess/d" /var/log/xray-users.log 2>/dev/null # Hapus hanya entri VMess
            echo -e "${BRIGHT_GREEN}✔ Pengguna VMess '$XRAY_USER' berjaya dipadam.${RESET}"
          else
            echo -e "${RED}✘ Ralat: Gagal memadam pengguna VMess '$XRAY_USER'.${RESET}"
          fi
        else
          echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4) # Kembali ke Menu Utama
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 1 dan 4.${RESET}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu
xray_vmess_menu_ops