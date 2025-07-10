#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

xray_vless_menu_ops() {
  while true; do
    clear
    header_info
    header_service_status
    echo -e "${BGAQUA}                    PENGURUSAN XRAY VLESS                    ${NC}"
    echo -e "${FULL_BORDER}"
    echo -e " [${AQUA}01${NC}] Cipta Pengguna VLESS"
    echo -e " [${AQUA}02${NC}] Semak Pengguna VLESS"
    echo -e " [${AQUA}03${NC}] Padam Pengguna VLESS"
    echo -e " [${AQUA}04${NC}] Kembali ke Menu Utama"
    echo -e "${FULL_BORDER}"
    read -p "[###] Pilih Menu [01-04]: " opt
    case $opt in
      1|01) # Cipta Pengguna VLESS
        clear
        header_info
        echo -e "${BGAQUA}                    CIPTA PENGGUNA VLESS                     ${NC}"
        echo -e "${FULL_BORDER}"
        read -rp "Nama pengguna: " XRAY_USER
        if ! validate_username "$XRAY_USER" "XRAY"; then pause; continue; fi
        read -rp "Berapa lama sah (hari)?: " XRAY_DAYS
        if ! validate_days "$XRAY_DAYS"; then pause; continue; fi
        if [[ ! -f "$XRAY_CONFIG" ]]; then
          echo -e "${RED}✘ Ralat: Fail konfigurasi Xray tidak ditemui.${RESET}"
          pause; continue
        fi
        loading_animation "Mencipta pengguna VLESS"
        XRAY_UUID=$(cat /proc/sys/kernel/random/uuid)
        exp_date=$(date -d "$XRAY_DAYS days" +"%Y-%m-%d")
        if jq --arg uuid "$XRAY_UUID" --arg user "$XRAY_USER" '
          .inbounds |= map(
            if (.protocol == "vless")
            then .settings.clients += [{"id": $uuid, "email": $user}]
            else .
            end
          )' "$XRAY_CONFIG" > /tmp/xray_config.json && mv /tmp/xray_config.json "$XRAY_CONFIG"; then
          systemctl restart xray 2>/dev/null
          echo "$XRAY_USER | $XRAY_UUID | vless | Exp: $exp_date" >> /var/log/xray-users.log
          vlesslink1="vless://${XRAY_UUID}@${DOMAIN}:443?path=/vless&security=tls&encryption=none&type=ws#${XRAY_USER}"
          vlesslink2="vless://${XRAY_UUID}@${DOMAIN}:80?path=/vless&encryption=none&type=ws#${XRAY_USER}"
          vlesslink3="vless://${XRAY_UUID}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${DOMAIN}#${XRAY_USER}"
          echo -e "${BRIGHT_GREEN}✔ Pengguna VLESS berjaya dicipta.${RESET}"
          echo -e "${SECTION_DIVIDER}"
          echo -e "${YELLOW}  VLESS WS TLS: ${LIGHT_CYAN}$vlesslink1${RESET}"
          echo -e "${YELLOW}  VLESS WS nTLS: ${LIGHT_CYAN}$vlesslink2${RESET}"
          echo -e "${YELLOW}  VLESS gRPC: ${LIGHT_CYAN}$vlesslink3${RESET}"
          echo -e "${YELLOW}  Tamat Tempoh: ${LIGHT_CYAN}$exp_date${RESET}"
          echo -e "${SECTION_DIVIDER}"
        else
          echo -e "${RED}✘ Ralat: Gagal mengemas kini konfigurasi Xray.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      2|02) # Semak Pengguna VLESS
        clear
        header_info
        echo -e "${BGAQUA}                   SENARAI PENGGUNA VLESS                    ${NC}"
        echo -e "${FULL_BORDER}"
        mapfile -t XRAY_USERS < <(list_xray_users | grep -E 'vless')
        if [[ ${#XRAY_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna VLESS ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna VLESS Aktif:${RESET}"
          for user in "${XRAY_USERS[@]}"; do
            exp_date=$(grep "^$user |" /var/log/xray-users.log | awk -F'|' '{print $4}' | awk '{print $2}')
            echo -e "${YELLOW}  - ${WHITE}$user ${GRAY}(Tamat Tempoh: $exp_date)${RESET}"
          done
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3|03) # Padam Pengguna VLESS
        clear
        header_info
        echo -e "${BGAQUA}                    PADAM PENGGUNA VLESS                     ${NC}"
        echo -e "${FULL_BORDER}"
        mapfile -t XRAY_USERS < <(list_xray_users | grep -E 'vless')
        if [[ ${#XRAY_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna VLESS ditemui.${RESET}"
          pause; continue
        fi
        echo -e "${WHITE}Pilih pengguna VLESS untuk dipadam:${RESET}"
        for i in "${!XRAY_USERS[@]}"; do
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${XRAY_USERS[$i]}${RESET}"
        done
        read -p "Masukkan nombor [1-${#XRAY_USERS[@]}]: " XRAY_NUM
        if [[ "$XRAY_NUM" =~ ^[0-9]+$ ]] && (( XRAY_NUM >= 1 && XRAY_NUM <= ${#XRAY_USERS[@]} )); then
          XRAY_USER="${XRAY_USERS[$((XRAY_NUM-1))]}"
          loading_animation "Memadam pengguna VLESS"
          if jq --arg user "$XRAY_USER" '
            .inbounds |= map(
              if .protocol == "vless" and .settings.clients != null
              then .settings.clients |= map(select(.email != $user))
              else .
              end
            )' "$XRAY_CONFIG" > /tmp/xray_config.json && mv /tmp/xray_config.json "$XRAY_CONFIG"; then
            systemctl restart xray 2>/dev/null
            sed -i "/^$XRAY_USER |.*vless/d" /var/log/xray-users.log 2>/dev/null
            echo -e "${BRIGHT_GREEN}✔ Pengguna VLESS '$XRAY_USER' berjaya dipadam.${RESET}"
          else
            echo -e "${RED}✘ Ralat: Gagal memadam pengguna VLESS '$XRAY_USER'.${RESET}"
          fi
        else
          echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4|04) return ;;
      *) echo -e "${RED}✘ Pilihan tidak sah. Sila pilih angka yang tersedia.${NC}" ; sleep 1 ;;
    esac
  done
}
xray_vless_menu_ops
