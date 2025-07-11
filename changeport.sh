#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Fungsi untuk memeriksa ketersediaan port
check_port_available() {
    local port=$1
    if lsof -i :$port >/dev/null 2>&1; then
        return 1 # Port sedang digunakan
    else
        return 0 # Port tersedia
    fi
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi
update_config_file() {
    local file=$1
    local old_port_regex=$2
    local new_port=$3
    local service_name=$4

    if grep -q "$old_port_regex" "$file"; then
        sed -i "s/$old_port_regex/$new_port/" "$file"
        echo -e "${BRIGHT_GREEN}✔ Port $service_name dalam $file berjaya dikemas kini ke $new_port.${RESET}"
        return 0
    else
        echo -e "${YELLOW}Amaran: Port $service_name tidak ditemui dalam $file. Mungkin sudah diubah secara manual atau konfigurasi berbeza.${RESET}"
        return 1
    fi
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk multiple ports)
update_config_multiple_ports() {
    local file=$1
    local old_port_regex=$2
    local new_port=$3
    local service_name=$4
    local line_prefix=$5 # Contoh: "DROPBEAR_PORT=" atau "accept ="

    if grep -q "$line_prefix" "$file"; then
        sed -i "/$line_prefix/ s/$old_port_regex/$new_port/" "$file"
        echo -e "${BRIGHT_GREEN}✔ Port $service_name dalam $file berjaya dikemas kini ke $new_port.${RESET}"
        return 0
    else
        echo -e "${YELLOW}Amaran: Port $service_name tidak ditemui dalam $file. Mungkin sudah diubah secara manual atau konfigurasi berbeza.${RESET}"
        return 1
    fi
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk Nginx)
update_nginx_config() {
    local old_port=$1
    local new_port=$2
    local config_file="/etc/nginx/conf.d/xray.conf"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}✘ Ralat: Fail konfigurasi Nginx Xray tidak ditemui: $config_file.${RESET}"
        return 1
    fi

    # Gantikan port di bahagian listen
    sed -i "s/listen 127.0.0.1:$old_port;/listen 127.0.0.1:$new_port;/" "$config_file"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✘ Ralat: Gagal mengemas kini port $old_port di Nginx config.${RESET}"
        return 1
    fi
    echo -e "${BRIGHT_GREEN}✔ Port Nginx untuk Xray berjaya dikemas kini dari $old_port ke $new_port.${RESET}"
    return 0
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk Hysteria2)
update_hysteria_config() {
    local old_port=$1
    local new_port=$2
    local config_file="/etc/hysteria/hysteria2.yaml"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}✘ Ralat: Fail konfigurasi Hysteria2 tidak ditemui: $config_file.${RESET}"
        return 1
    fi

    # Gantikan port di bahagian listen
    sed -i "s/listen: :$old_port/listen: :$new_port/" "$config_file"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✘ Ralat: Gagal mengemas kini port $old_port di Hysteria2 config.${RESET}"
        return 1
    fi
    echo -e "${BRIGHT_GREEN}✔ Port Hysteria2 berjaya dikemas kini dari $old_port ke $new_port.${RESET}"
    return 0
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk Squid)
update_squid_config() {
    local old_port=$1
    local new_port=$2
    local config_file="/etc/squid/squid.conf"

    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}✘ Ralat: Fail konfigurasi Squid tidak ditemui: $config_file.${RESET}"
        return 1
    fi

    # Gantikan port di http_port
    sed -i "s/http_port $old_port/http_port $new_port/" "$config_file"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✘ Ralat: Gagal mengemas kini port $old_port di Squid config.${RESET}"
        return 1
    fi
    echo -e "${BRIGHT_GREEN}✔ Port Squid berjaya dikemas kini dari $old_port ke $new_port.${RESET}"
    return 0
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk OHP)
update_ohp_config() {
    local old_port=$1
    local new_port=$2
    local service_file="/etc/systemd/system/ohp.service"
    local ovpn_config_file="/var/www/html/ohp-ovpn-tcp.ovpn"

    if [[ ! -f "$service_file" ]]; then
        echo -e "${RED}✘ Ralat: Fail perkhidmatan OHP tidak ditemui: $service_file.${RESET}"
        return 1
    fi

    # Update di service file
    sed -i "s/-port $old_port/-port $new_port/" "$service_file"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✘ Ralat: Gagal mengemas kini port OHP di service file.${RESET}"
        return 1
    fi
    echo -e "${BRIGHT_GREEN}✔ Port OHP dalam service file berjaya dikemas kini dari $old_port ke $new_port.${RESET}"

    # Update di OVPN config file (jika ada)
    if [[ -f "$ovpn_config_file" ]]; then
        sed -i "s/http-proxy $IP $old_port/http-proxy $IP $new_port/" "$ovpn_config_file"
        echo -e "${BRIGHT_GREEN}✔ Port OHP dalam OVPN config berjaya dikemas kini dari $old_port ke $new_port.${RESET}"
    fi
    return 0
}

# Fungsi untuk mengemas kini port dalam fail konfigurasi (untuk SSH WS Proxy)
update_ssh_ws_proxy_config() {
    local old_port=$1
    local new_port=$2
    local service_file="/etc/systemd/system/ws-python-proxy.service"
    local proxy_script="/usr/local/proxy.py"

    if [[ ! -f "$service_file" ]]; then
        echo -e "${RED}✘ Ralat: Fail perkhidmatan SSH WS Proxy tidak ditemui: $service_file.${RESET}"
        return 1
    fi

    # Update di service file
    sed -i "s/-p $old_port/-p $new_port/" "$service_file"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}✘ Ralat: Gagal mengemas kini port SSH WS Proxy di service file.${RESET}"
        return 1
    fi
    echo -e "${BRIGHT_GREEN}✔ Port SSH WS Proxy dalam service file berjaya dikemas kini dari $old_port ke $new_port.${RESET}"

    # Update di proxy script (jika perlu, bergantung pada bagaimana script membaca port)
    # Dalam kes ini, script membaca dari argumen, jadi service file sudah cukup.
    # Jika script membaca dari hardcoded variable, perlu diubah juga.
    # Contoh: sed -i "s/LISTENING_PORT = $old_port/LISTENING_PORT = $new_port/" "$proxy_script"

    return 0
}


# Fungsi untuk mengemas kini peraturan UFW dan IPTables
update_firewall_rules() {
    local old_port=$1
    local new_port=$2
    local protocol=$3 # tcp atau udp

    echo -e "${YELLOW}Mengemas kini peraturan firewall...${RESET}"

    # Hapus peraturan lama
    ufw delete allow "$old_port/$protocol" >/dev/null 2>&1 || true
    iptables -D INPUT -p "$protocol" --dport "$old_port" -j ACCEPT >/dev/null 2>&1 || true

    # Tambah peraturan baru
    ufw allow "$new_port/$protocol" >/dev/null 2>&1
    iptables -I INPUT -p "$protocol" --dport "$new_port" -j ACCEPT

    # Simpan peraturan IPTables
    iptables-save > /etc/iptables.up.rules
    netfilter-persistent save > /dev/null 2>&1

    echo -e "${BRIGHT_GREEN}✔ Peraturan firewall untuk port $old_port ($protocol) telah dikemas kini ke $new_port ($protocol).${RESET}"
}

# Fungsi utama menu tukar port
change_port_menu() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Pengurusan Tukar Port Perkhidmatan${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Tukar Port Dropbear (109, 143)${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Tukar Port Stunnel (444, 777)${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Tukar Port SSH WS Proxy (8880)${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Tukar Port OpenVPN (UDP 1194, TCP 1443, UDP 2053, TCP 8080)${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}Tukar Port OHP (8087)${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}Tukar Port Hysteria2 (8443)${RESET}"
    echo -e "${YELLOW}  7. ${WHITE}Tukar Port Xray VMess/VLESS (Internal Nginx Proxy 10000, 10010, 10080, 10081)${RESET}"
    echo -e "${YELLOW}  0. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [0-7]: ${RESET}"
    read opt
    case $opt in
      1) # Tukar Port Dropbear
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port Dropbear${RESET}"
        echo -e "${FULL_BORDER}"
        current_port_109=$(grep "DROPBEAR_PORT=" /etc/default/dropbear | cut -d'=' -f2 | xargs)
        current_port_143=$(grep "DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear | awk -F'-p ' '{print $2}' | xargs)
        echo -e "${YELLOW}Port Dropbear semasa: ${LIGHT_CYAN}$current_port_109, $current_port_143${RESET}"
        read -rp "Masukkan port baru untuk Dropbear (cth: 109): " NEW_PORT_109
        read -rp "Masukkan port tambahan baru untuk Dropbear (cth: 143): " NEW_PORT_143

        if ! validate_days "$NEW_PORT_109" || ! validate_days "$NEW_PORT_143"; then # Menggunakan validate_days sebagai check angka positif
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT_109" == "$current_port_109" && "$NEW_PORT_143" == "$current_port_143" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT_109" && check_port_available "$NEW_PORT_143"; then
            loading_animation "Mengemas kini port Dropbear"
            update_config_file "/etc/default/dropbear" "DROPBEAR_PORT=$current_port_109" "DROPBEAR_PORT=$NEW_PORT_109" "Dropbear Port 1"
            update_config_file "/etc/default/dropbear" "DROPBEAR_EXTRA_ARGS=\"-p $current_port_143\"" "DROPBEAR_EXTRA_ARGS=\"-p $NEW_PORT_143\"" "Dropbear Port 2"
            
            update_firewall_rules "$current_port_109" "$NEW_PORT_109" "tcp"
            update_firewall_rules "$current_port_143" "$NEW_PORT_143" "tcp"

            systemctl restart dropbear
            echo -e "${BRIGHT_GREEN}✔ Port Dropbear berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      2) # Tukar Port Stunnel
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port Stunnel${RESET}"
        echo -e "${FULL_BORDER}"
        current_port_444=$(grep -A 2 "\$ssh\$" /etc/stunnel/stunnel.conf | grep "accept =" | awk '{print $3}' | xargs)
        current_port_777=$(grep -A 2 "\$dropbear\$" /etc/stunnel/stunnel.conf | grep "accept =" | awk '{print $3}' | xargs)
        echo -e "${YELLOW}Port Stunnel semasa: ${LIGHT_CYAN}$current_port_444, $current_port_777${RESET}"
        read -rp "Masukkan port baru untuk Stunnel SSH (cth: 444): " NEW_PORT_444
        read -rp "Masukkan port baru untuk Stunnel Dropbear (cth: 777): " NEW_PORT_777

        if ! validate_days "$NEW_PORT_444" || ! validate_days "$NEW_PORT_777"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT_444" == "$current_port_444" && "$NEW_PORT_777" == "$current_port_777" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT_444" && check_port_available "$NEW_PORT_777"; then
            loading_animation "Mengemas kini port Stunnel"
            update_config_multiple_ports "/etc/stunnel/stunnel.conf" "accept = $current_port_444" "accept = $NEW_PORT_444" "Stunnel SSH" "accept ="
            update_config_multiple_ports "/etc/stunnel/stunnel.conf" "accept = $current_port_777" "accept = $NEW_PORT_777" "Stunnel Dropbear" "accept ="
            
            update_firewall_rules "$current_port_444" "$NEW_PORT_444" "tcp"
            update_firewall_rules "$current_port_777" "$NEW_PORT_777" "tcp"

            systemctl restart stunnel4
            echo -e "${BRIGHT_GREEN}✔ Port Stunnel berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      3) # Tukar Port SSH WS Proxy
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port SSH WS Proxy${RESET}"
        echo -e "${FULL_BORDER}"
        current_port=$(grep "ExecStart=.*-p" /etc/systemd/system/ws-python-proxy.service | awk -F'-p ' '{print $2}' | xargs)
        echo -e "${YELLOW}Port SSH WS Proxy semasa: ${LIGHT_CYAN}$current_port${RESET}"
        read -rp "Masukkan port baru untuk SSH WS Proxy (cth: 8880): " NEW_PORT

        if ! validate_days "$NEW_PORT"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT" == "$current_port" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT"; then
            loading_animation "Mengemas kini port SSH WS Proxy"
            update_ssh_ws_proxy_config "$current_port" "$NEW_PORT"
            update_firewall_rules "$current_port" "$NEW_PORT" "tcp"
            systemctl daemon-reload
            systemctl restart ws-python-proxy
            echo -e "${BRIGHT_GREEN}✔ Port SSH WS Proxy berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      4) # Tukar Port OpenVPN
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port OpenVPN${RESET}"
        echo -e "${FULL_BORDER}"
        echo -e "${YELLOW}Pilih konfigurasi OpenVPN untuk diubah:${RESET}"
        echo -e "${YELLOW}  1. ${WHITE}OpenVPN UDP 1194${RESET}"
        echo -e "${YELLOW}  2. ${WHITE}OpenVPN TCP 1443${RESET}"
        echo -e "${YELLOW}  3. ${WHITE}OpenVPN UDP 2053${RESET}"
        echo -e "${YELLOW}  4. ${WHITE}OpenVPN TCP 8080${RESET}"
        echo -e "${YELLOW}  0. ${WHITE}Kembali${RESET}"
        echo -ne "${WHITE}Pilih pilihan [0-4]: ${RESET}"
        read OVPN_OPT

        case $OVPN_OPT in
            1) OVPN_FILE="/etc/openvpn/server-udp-1194.conf"; OVPN_PROTO="udp"; OVPN_SVC="openvpn@server-udp-1194"; OVPN_NAME="OpenVPN UDP 1194" ;;
            2) OVPN_FILE="/etc/openvpn/server-tcp-443.conf"; OVPN_PROTO="tcp"; OVPN_SVC="openvpn@server-tcp-443"; OVPN_NAME="OpenVPN TCP 1443" ;;
            3) OVPN_FILE="/etc/openvpn/server-udp-53.conf"; OVPN_PROTO="udp"; OVPN_SVC="openvpn@server-udp-53"; OVPN_NAME="OpenVPN UDP 2053" ;;
            4) OVPN_FILE="/etc/openvpn/server-tcp-80.conf"; OVPN_PROTO="tcp"; OVPN_SVC="openvpn@server-tcp-80"; OVPN_NAME="OpenVPN TCP 8080" ;;
            0) continue ;;
            *) echo -e "${RED}✘ Pilihan tidak sah.${RESET}"; pause; continue ;;
        esac

        current_port=$(grep "^port " "$OVPN_FILE" | awk '{print $2}' | xargs)
        echo -e "${YELLOW}Port $OVPN_NAME semasa: ${LIGHT_CYAN}$current_port${RESET}"
        read -rp "Masukkan port baru untuk $OVPN_NAME: " NEW_PORT

        if ! validate_days "$NEW_PORT"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT" == "$current_port" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT"; then
            loading_animation "Mengemas kini port $OVPN_NAME"
            update_config_file "$OVPN_FILE" "port $current_port" "port $NEW_PORT" "$OVPN_NAME"
            update_firewall_rules "$current_port" "$OVPN_PROTO" "$NEW_PORT" "$OVPN_PROTO"
            systemctl restart "$OVPN_SVC"
            echo -e "${BRIGHT_GREEN}✔ Port $OVPN_NAME berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      5) # Tukar Port OHP
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port OHP${RESET}"
        echo -e "${FULL_BORDER}"
        current_port=$(grep "ExecStart=.*-port" /etc/systemd/system/ohp.service | awk -F'-port ' '{print $2}' | awk '{print $1}' | xargs)
        echo -e "${YELLOW}Port OHP semasa: ${LIGHT_CYAN}$current_port${RESET}"
        read -rp "Masukkan port baru untuk OHP (cth: 8087): " NEW_PORT

        if ! validate_days "$NEW_PORT"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT" == "$current_port" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT"; then
            loading_animation "Mengemas kini port OHP"
            update_ohp_config "$current_port" "$NEW_PORT"
            update_firewall_rules "$current_port" "$NEW_PORT" "tcp"
            systemctl daemon-reload
            systemctl restart ohp
            echo -e "${BRIGHT_GREEN}✔ Port OHP berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      6) # Tukar Port Hysteria2
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port Hysteria2${RESET}"
        echo -e "${FULL_BORDER}"
        current_port=$(grep "listen: :" /etc/hysteria/hysteria2.yaml | awk -F':' '{print $3}' | xargs)
        echo -e "${YELLOW}Port Hysteria2 semasa: ${LIGHT_CYAN}$current_port${RESET}"
        read -rp "Masukkan port baru untuk Hysteria2 (cth: 8443): " NEW_PORT

        if ! validate_days "$NEW_PORT"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        if [[ "$NEW_PORT" == "$current_port" ]]; then
            echo -e "${YELLOW}Tiada perubahan port dikesan.${RESET}"
            pause
            continue
        fi

        if check_port_available "$NEW_PORT"; then
            loading_animation "Mengemas kini port Hysteria2"
            update_hysteria_config "$current_port" "$NEW_PORT"
            update_firewall_rules "$current_port" "$NEW_PORT" "udp"
            systemctl restart hysteria2
            echo -e "${BRIGHT_GREEN}✔ Port Hysteria2 berjaya ditukar dan perkhidmatan direstart.${RESET}"
        else
            echo -e "${RED}✘ Ralat: Port baru sudah digunakan atau tidak tersedia.${RESET}"
        fi
        echo -e "${FULL_BORDER}"
        pause
        ;;
      7) # Tukar Port Xray VMess/VLESS (Internal Nginx Proxy)
        title_banner
        echo -e "${PURPLE}${BOLD}Tukar Port Xray VMess/VLESS (Internal Nginx Proxy)${RESET}"
        echo -e "${FULL_BORDER}"
        echo -e "${YELLOW}Port ini adalah port internal yang digunakan oleh Nginx untuk proxy ke Xray.${RESET}"
        echo -e "${YELLOW}Perubahan ini tidak akan mengubah port yang diakses dari luar (443/80).${RESET}"
        echo -e "${YELLOW}Port semasa: ${LIGHT_CYAN}VLESS TLS: 10000, VMess TLS: 10010, VLESS nTLS: 10080, VMess nTLS: 10081${RESET}"
        
        read -rp "Masukkan port baru untuk VLESS TLS (cth: 10000): " NEW_VLESS_TLS_PORT
        read -rp "Masukkan port baru untuk VMess TLS (cth: 10010): " NEW_VMESS_TLS_PORT
        read -rp "Masukkan port baru untuk VLESS nTLS (cth: 10080): " NEW_VLESS_NTLS_PORT
        read -rp "Masukkan port baru untuk VMess nTLS (cth: 10081): " NEW_VMESS_NTLS_PORT

        if ! validate_days "$NEW_VLESS_TLS_PORT" || ! validate_days "$NEW_VMESS_TLS_PORT" || \
           ! validate_days "$NEW_VLESS_NTLS_PORT" || ! validate_days "$NEW_VMESS_NTLS_PORT"; then
            echo -e "${RED}✘ Ralat: Port harus angka positif.${RESET}"
            pause
            continue
        fi

        # Ambil port semasa dari config
        CURRENT_VLESS_TLS_PORT=$(jq -r '.inbounds[] | select(.protocol=="vless" and .streamSettings.network=="ws" and .port==10000) | .port' "$XRAY_CONFIG" 2>/dev/null || echo "10000")
        CURRENT_VMESS_TLS_PORT=$(jq -r '.inbounds[] | select(.protocol=="vmess" and .streamSettings.network=="ws" and .port==10010) | .port' "$XRAY_CONFIG" 2>/dev/null || echo "10010")
        CURRENT_VLESS_NTLS_PORT=$(jq -r '.inbounds[] | select(.protocol=="vless" and .streamSettings.network=="ws" and .port==10080) | .port' "$XRAY_CONFIG" 2>/dev/null || echo "10080")
        CURRENT_VMESS_NTLS_PORT=$(jq -r '.inbounds[] | select(.protocol=="vmess" and .streamSettings.network=="ws" and .port==10081) | .port' "$XRAY_CONFIG" 2>/dev/null || echo "10081")

        # Periksa konflik port baru
        declare -A new_ports_check
        new_ports_check["$NEW_VLESS_TLS_PORT"]=1
        new_ports_check["$NEW_VMESS_TLS_PORT"]=1
        new_ports_check["$NEW_VLESS_NTLS_PORT"]=1
        new_ports_check["$NEW_VMESS_NTLS_PORT"]=1

        local conflict_found=0
        for port_to_check in "${!new_ports_check[@]}"; do
            if [[ "$port_to_check" != "$CURRENT_VLESS_TLS_PORT" && "$port_to_check" != "$CURRENT_VMESS_TLS_PORT" && \
                  "$port_to_check" != "$CURRENT_VLESS_NTLS_PORT" && "$port_to_check" != "$CURRENT_VMESS_NTLS_PORT" ]]; then
                if ! check_port_available "$port_to_check"; then
                    echo -e "${RED}✘ Ralat: Port $port_to_check sudah digunakan oleh perkhidmatan lain.${RESET}"
                    conflict_found=1
                    break
                fi
            fi
        done

        if [[ "$conflict_found" -eq 1 ]]; then
            pause
            continue
        fi

        loading_animation "Mengemas kini port Xray internal"
        
        # Update Xray config
        jq --arg old_vless_tls "$CURRENT_VLESS_TLS_PORT" --arg new_vless_tls "$NEW_VLESS_TLS_PORT" \
           --arg old_vmess_tls "$CURRENT_VMESS_TLS_PORT" --arg new_vmess_tls "$NEW_VMESS_TLS_PORT" \
           --arg old_vless_ntls "$CURRENT_VLESS_NTLS_PORT" --arg new_vless_ntls "$NEW_VLESS_NTLS_PORT" \
           --arg old_vmess_ntls "$CURRENT_VMESS_NTLS_PORT" --arg new_vmess_ntls "$NEW_VMESS_NTLS_PORT" \
           '.inbounds |= map(
             if .protocol == "vless" and .streamSettings.network == "ws" and .port == ($old_vless_tls | tonumber) then .port = ($new_vless_tls | tonumber)
             elif .protocol == "vmess" and .streamSettings.network == "ws" and .port == ($old_vmess_tls | tonumber) then .port = ($new_vmess_tls | tonumber)
             elif .protocol == "vless" and .streamSettings.network == "ws" and .port == ($old_vless_ntls | tonumber) then .port = ($new_vless_ntls | tonumber)
             elif .protocol == "vmess" and .streamSettings.network == "ws" and .port == ($old_vmess_ntls | tonumber) then .port = ($new_vmess_ntls | tonumber)
             else . end
           )' "$XRAY_CONFIG" > /tmp/xray_config.json && mv /tmp/xray_config.json "$XRAY_CONFIG"

        # Update Nginx config
        update_nginx_config "$CURRENT_VLESS_TLS_PORT" "$NEW_VLESS_TLS_PORT"
        update_nginx_config "$CURRENT_VMESS_TLS_PORT" "$NEW_VMESS_TLS_PORT"
        update_nginx_config "$CURRENT_VLESS_NTLS_PORT" "$NEW_VLESS_NTLS_PORT"
        update_nginx_config "$CURRENT_VMESS_NTLS_PORT" "$NEW_VMESS_NTLS_PORT"

        systemctl restart xray
        systemctl restart nginx
        echo -e "${BRIGHT_GREEN}✔ Port Xray internal dan Nginx proxy berjaya ditukar dan perkhidmatan direstart.${RESET}"
        echo -e "${FULL_BORDER}"
        pause
        ;;
      0) # Kembali ke Menu Utama
        return
        ;;
      *)
        echo -e "${RED}✘ Pilihan tidak sah. Pilih nombor antara 0 dan 7.${RESET}"
        pause
        ;;
    esac
  done
}

# Panggil fungsi menu
change_port_menu