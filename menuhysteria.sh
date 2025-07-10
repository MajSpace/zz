#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

hysteria_menu_ops() {
  while true; do
    clear
    header_info
    header_service_status
    echo -e "${BGAQUA}                   PENGURUSAN HYSTERIA2 MAJSPACE               ${NC}"
    echo -e "${FULL_BORDER}"
    echo -e " [${AQUA}01${NC}] Cipta Pengguna Hysteria2"
    echo -e " [${AQUA}02${NC}] Semak Pengguna Hysteria2"
    echo -e " [${AQUA}03${NC}] Padam Pengguna Hysteria2"
    echo -e " [${AQUA}04${NC}] Kembali ke Menu Utama"
    echo -e "${FULL_BORDER}"
    read -p "[###] Pilih Menu [01-04]: " opt
    case $opt in
      1|01) # Cipta Pengguna Hysteria2
        clear
        header_info
        echo -e "${BGAQUA}                CIPTA PENGGUNA HYSTERIA2 MAJSPACE              ${NC}"
        echo -e "${FULL_BORDER}"
        read -rp "Nama pengguna: " HYST_USER
        if ! validate_username "$HYST_USER" "HYSTERIA"; then pause; continue; fi
        read -rp "Berapa lama sah (hari)?: " HYST_DAYS
        if ! validate_days "$HYST_DAYS"; then pause; continue; fi
        loading_animation "Mencipta pengguna Hysteria2"
        HYST_PASS=$(generate_password 12)
        exp_date=$(date -d "$HYST_DAYS days" +"%Y-%m-%d")
        echo "$HYST_USER|$HYST_PASS|$exp_date" >> /var/log/hysteria-users.log
        # Tambah ke config YAML jika perlu (atau jika anda support multi-user)
        # Restart hysteria jika config diubah
        echo -e "${BRIGHT_GREEN}✔ Pengguna Hysteria2 berjaya dicipta.${RESET}"
        echo -e "${SECTION_DIVIDER}"
        echo -e "${YELLOW}  Nama Pengguna: ${LIGHT_CYAN}$HYST_USER${RESET}"
        echo -e "${YELLOW}  Kata Laluan:   ${LIGHT_CYAN}$HYST_PASS${RESET}"
        echo -e "${YELLOW}  Tamat Tempoh:  ${LIGHT_CYAN}$exp_date${RESET}"
        show_hysteria_info
        echo -e "${SECTION_DIVIDER}"
        pause
        ;;
      2|02) # Semak Pengguna Hysteria2
        clear
        header_info
        echo -e "${BGAQUA}                 SENARAI PENGGUNA HYSTERIA2                   ${NC}"
        echo -e "${FULL_BORDER}"
        if [[ ! -f /var/log/hysteria-users.log ]] || [[ ! $(cat /var/log/hysteria-users.log) ]]; then
          echo -e "${RED}Tiada pengguna Hysteria2 ditemui.${RESET}"
        else
          echo -e "${WHITE}Pengguna Hysteria2 Aktif:${RESET}"
          awk -F'|' '{printf "  - %s %s(Tamat Tempoh: %s)%s\n", $1, ENVIRON["GRAY"], $3, ENVIRON["RESET"]}' /var/log/hysteria-users.log
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3|03) # Padam Pengguna Hysteria2
        clear
        header_info
        echo -e "${BGAQUA}                  PADAM PENGGUNA HYSTERIA2                    ${NC}"
        echo -e "${FULL_BORDER}"
        mapfile -t HYST_USERS < <(list_hysteria_users)
        if [[ ${#HYST_USERS[@]} -eq 0 ]]; then
          echo -e "${RED}Tiada pengguna Hysteria2 ditemui.${RESET}"
          pause; continue
        fi
        echo -e "${WHITE}Pilih pengguna Hysteria2 untuk dipadam:${RESET}"
        for i in "${!HYST_USERS[@]}"; do
          echo -e "${YELLOW}  $((i+1)). ${WHITE}${HYST_USERS[$i]}${RESET}"
        done
        read -p "Masukkan nombor [1-${#HYST_USERS[@]}]: " HYST_NUM
        if [[ "$HYST_NUM" =~ ^[0-9]+$ ]] && (( HYST_NUM >= 1 && HYST_NUM <= ${#HYST_USERS[@]} )); then
          HYST_USER="${HYST_USERS[$((HYST_NUM-1))]}"
          loading_animation "Memadam pengguna Hysteria2"
          sed -i "/^$HYST_USER|/d" /var/log/hysteria-users.log 2>/dev/null
          # Jika anda edit config YAML, restart hysteria2 di sini
          echo -e "${BRIGHT_GREEN}✔ Pengguna Hysteria2 '$HYST_USER' berjaya dipadam.${RESET}"
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
hysteria_menu_ops
