#!/bin/bash

# Pastikan utils.sh ada
if [ -f /usr/local/bin/utils.sh ]; then
  source /usr/local/bin/utils.sh
fi

# Senarai fail & servis utama
DROPBEAR_CONF="/etc/default/dropbear"
STUNNEL_CONF="/etc/stunnel/stunnel.conf"
WS_PROXY_SERVICE="/etc/systemd/system/ws-python-proxy.service"
OHP_SERVICE="/etc/systemd/system/ohp.service"
OPENVPN_PATH="/etc/openvpn"
OHP_OVPN="/var/www/html/ohp-ovpn-tcp.ovpn"

# Warna
NC='\e[0m'
RED='\e[31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
BOLD='\e[1m'

# Fungsi: Check port tersedia
check_port_available() {
    local port=$1
    if lsof -i :$port | grep -q LISTEN; then
        return 1
    fi
    return 0
}

# Fungsi: Ambil port dropbear
get_dropbear_ports() {
    local ports=()
    local p1="" p2=""
    p1=$(grep -E '^DROPBEAR_PORT=' "$DROPBEAR_CONF" | cut -d= -f2 | tr -d '"' | awk '{print $1}')
    p2=$(grep -E '^DROPBEAR_EXTRA_ARGS=' "$DROPBEAR_CONF" | grep -oP '(?<=-p )\d+')
    ports+=("$p1")
    ports+=("$p2")
    echo "${ports[@]}"
}

# Fungsi: Ambil port stunnel
get_stunnel_ports() {
    local ssh_port=""
    local dropbear_port=""
    ssh_port=$(awk '/\$ssh\$/,/\$/{if ($1=="accept") print $3}' $STUNNEL_CONF | head -n1)
    dropbear_port=$(awk '/\$dropbear\$/,/\$/{if ($1=="accept") print $3}' $STUNNEL_CONF | head -n1)
    echo "$ssh_port $dropbear_port"
}

# Fungsi: Ambil port ws proxy
get_wsproxy_port() {
    grep "ExecStart=" "$WS_PROXY_SERVICE" | grep -oP '(?<=-p )\d+'
}

# Fungsi: Ambil port OHP
get_ohp_port() {
    grep "ExecStart=" "$OHP_SERVICE" | grep -oP '(?<=-port )\d+'
}

# Fungsi: Ambil port OpenVPN standard (UDP 1194, TCP 1443, UDP 2053, TCP 8080)
get_openvpn_ports() {
    local out=""
    # UDP 1194
    if [ -f "$OPENVPN_PATH/server-udp-1194.conf" ]; then
        out+="UDP 1194: $(grep -w port "$OPENVPN_PATH/server-udp-1194.conf" | awk '{print $2}')   "
    fi
    # TCP 1443
    if [ -f "$OPENVPN_PATH/server-tcp-443.conf" ]; then
        out+="TCP 1443: $(grep -w port "$OPENVPN_PATH/server-tcp-443.conf" | awk '{print $2}')   "
    fi
    # UDP 2053
    if [ -f "$OPENVPN_PATH/server-udp-53.conf" ]; then
        out+="UDP 2053: $(grep -w port "$OPENVPN_PATH/server-udp-53.conf" | awk '{print $2}')   "
    fi
    # TCP 8080
    if [ -f "$OPENVPN_PATH/server-tcp-80.conf" ]; then
        out+="TCP 8080: $(grep -w port "$OPENVPN_PATH/server-tcp-80.conf" | awk '{print $2}')   "
    fi
    echo "$out"
}

# Fungsi: Papar semua port semasa
view_ports() {
    echo -e " ${YELLOW}${BOLD}Senarai Port Semasa:${NC}\n"
    # DROPBEAR
    local db_ports=($(get_dropbear_ports))
    echo -e " ${CYAN}Dropbear  :${NC} 1) ${db_ports[0]}  2) ${db_ports[1]}"
    # STUNNEL
    local stun_ports=($(get_stunnel_ports))
    echo -e " ${CYAN}Stunnel   :${NC} 1) ${stun_ports[0]}  2) ${stun_ports[1]}"
    # SSH WS Proxy
    echo -e " ${CYAN}SSH WS Proxy:${NC} ${BOLD}$(get_wsproxy_port)${NC}"
    # OHP
    echo -e " ${CYAN}OHP Proxy :${NC} ${BOLD}$(get_ohp_port)${NC}"
    # OPENVPN
    echo -e " ${CYAN}OpenVPN   :${NC} $(get_openvpn_ports)"
    echo ""
}

# Fungsi: Tukar port dropbear
change_port_dropbear() {
    local ports=($(get_dropbear_ports))
    echo -e "\n${YELLOW}Port Dropbear Semasa:"
    echo -e "1) ${ports[0]}"
    echo -e "2) ${ports[1]}${NC}"
    read -rp "Pilih nombor port yang ingin ditukar [1-2 / 0 batal]: " pilih
    if [[ $pilih == 1 || $pilih == 2 ]]; then
        local old_port="${ports[$((pilih-1))]}"
        read -rp "Masukkan port baru (1-65535): " new_port
        if ! [[ "$new_port" =~ ^[0-9]{1,5}$ && $new_port -ge 1 && $new_port -le 65535 ]]; then
            echo -e "${RED}✘ Ralat: Nilai port tidak sah.${NC}"
            sleep 1
            return
        fi
        check_port_available "$new_port"
        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Port $new_port sedang digunakan!${NC}"; sleep 1; return
        fi
        if [[ $pilih == 1 ]]; then
            sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" $DROPBEAR_CONF
        elif [[ $pilih == 2 ]]; then
            sed -i "s/\$DROPBEAR_EXTRA_ARGS=.*-p \$[0-9]\+/\1$new_port/" $DROPBEAR_CONF
        fi
        # Firewall
        ufw delete allow $old_port/tcp >/dev/null 2>&1
        ufw allow $new_port/tcp >/dev/null 2>&1
        iptables -D INPUT -p tcp --dport $old_port -j ACCEPT >/dev/null 2>&1
        iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
        systemctl restart dropbear
        echo -e "${GREEN}✔ Port Dropbear berjaya ditukar kepada $new_port.${NC}"
    fi
    sleep 1
}

# Tukar port Stunnel
change_port_stunnel() {
    local ports=($(get_stunnel_ports))
    echo -e "\n${YELLOW}Port Stunnel Semasa:"
    echo -e "1) ${ports[0]}"
    echo -e "2) ${ports[1]}${NC}"
    read -rp "Pilih nombor port yang ingin ditukar [1-2 / 0 batal]: " pilih
    if [[ $pilih == 1 || $pilih == 2 ]]; then
        local old_port="${ports[$((pilih-1))]}"
        read -rp "Masukkan port baru (1-65535): " new_port
        if ! [[ "$new_port" =~ ^[0-9]{1,5}$ && $new_port -ge 1 && $new_port -le 65535 ]]; then
            echo -e "${RED}✘ Ralat: Nilai port tidak sah.${NC}"
            sleep 1; return
        fi
        check_port_available "$new_port"
        if [ $? -ne 0 ]; then
            echo -e "${RED}✘ Port $new_port sedang digunakan!${NC}"; sleep 1; return
        fi
        # Update conf dan firewall
        sed -i "/^accept = $old_port/s/accept = $old_port/accept = $new_port/" "$STUNNEL_CONF"
        ufw delete allow $old_port/tcp >/dev/null 2>&1
        ufw allow $new_port/tcp >/dev/null 2>&1
        iptables -D INPUT -p tcp --dport $old_port -j ACCEPT >/dev/null 2>&1
        iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
        systemctl restart stunnel4
        echo -e "${GREEN}✔ Port Stunnel berjaya ditukar kepada $new_port.${NC}"
    fi
    sleep 1
}

# Tukar port SSH WS Proxy
change_port_wsproxy() {
    local old_port=$(get_wsproxy_port)
    echo -e "\n${YELLOW}Port SSH WS Proxy Semasa: ${old_port}${NC}"
    read -rp "Masukkan port baru (1-65535, 0 batal): " new_port
    [[ $new_port == 0 ]] && return
    if ! [[ "$new_port" =~ ^[0-9]{1,5}$ && $new_port -ge 1 && $new_port -le 65535 ]]; then
        echo -e "${RED}✘ Ralat: Nilai port tidak sah.${NC}"; sleep 1; return
    fi
    check_port_available "$new_port"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✘ Port $new_port sedang digunakan!${NC}"; sleep 1; return
    fi
    # Ubah .service file
    sed -i "s/-p $old_port/-p $new_port/" $WS_PROXY_SERVICE
    ufw delete allow $old_port/tcp >/dev/null 2>&1
    ufw allow $new_port/tcp >/dev/null 2>&1
    iptables -D INPUT -p tcp --dport $old_port -j ACCEPT >/dev/null 2>&1
    iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
    systemctl daemon-reload
    systemctl restart ws-python-proxy
    echo -e "${GREEN}✔ Port SSH WS Proxy berjaya ditukar kepada $new_port.${NC}"
    sleep 1
}

# Tukar port OHP
change_port_ohp() {
    local old_port=$(get_ohp_port)
    echo -e "\n${YELLOW}Port OHP Semasa: ${old_port}${NC}"
    read -rp "Masukkan port baru (1-65535, 0 batal): " new_port
    [[ $new_port == 0 ]] && return
    if ! [[ "$new_port" =~ ^[0-9]{1,5}$ && $new_port -ge 1 && $new_port -le 65535 ]]; then
        echo -e "${RED}✘ Ralat: Nilai port tidak sah.${NC}"; sleep 1; return
    fi
    check_port_available "$new_port"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✘ Port $new_port sedang digunakan!${NC}"; sleep 1; return
    fi
    sed -i "s/-port $old_port/-port $new_port/" $OHP_SERVICE
    if [[ -f "$OHP_OVPN" ]]; then
        sed -i "s/http-proxy .* $old_port/http-proxy 127.0.0.1 $new_port/" $OHP_OVPN
    fi
    ufw delete allow $old_port/tcp >/dev/null 2>&1
    ufw allow $new_port/tcp >/dev/null 2>&1
    iptables -D INPUT -p tcp --dport $old_port -j ACCEPT >/dev/null 2>&1
    iptables -I INPUT -p tcp --dport $new_port -j ACCEPT
    systemctl daemon-reload
    systemctl restart ohp
    echo -e "${GREEN}✔ Port OHP berjaya ditukar kepada $new_port.${NC}"
    sleep 1
}

# Tukar port OpenVPN
change_port_openvpn() {
    echo -e "\n${YELLOW}OpenVPN Config:${NC}"
    declare -A OVPN_FILES
    OVPN_FILES["1"]="$OPENVPN_PATH/server-udp-1194.conf"
    OVPN_FILES["2"]="$OPENVPN_PATH/server-tcp-443.conf"
    OVPN_FILES["3"]="$OPENVPN_PATH/server-udp-53.conf"
    OVPN_FILES["4"]="$OPENVPN_PATH/server-tcp-80.conf"
    OVPN_NAMES=("UDP 1194" "TCP 1443" "UDP 2053" "TCP 8080")
    for i in {1..4}; do
        if [ -f "${OVPN_FILES[$i]}" ]; then
            curp=$(grep -w port "${OVPN_FILES[$i]}" | awk '{print $2}')
            echo "$i) ${OVPN_NAMES[$((i-1))]} : $curp"
        fi
    done
    echo "0) Batal"
    read -rp "Pilih nombor config untuk ditukar [1-4/0]: " pilih
    [[ $pilih == 0 ]] && return
    conf="${OVPN_FILES[$pilih]}"
    [[ ! -f "$conf" ]] && echo -e "${RED}Config tidak wujud!${NC}"; sleep 1; return
    curp=$(grep -w port "$conf" | awk '{print $2}')
    echo -e "Port Semasa: $curp"
    read -rp "Masukkan port baru (1-65535): " new_port
    if ! [[ "$new_port" =~ ^[0-9]{1,5}$ && $new_port -ge 1 && $new_port -le 65535 ]]; then
        echo -e "${RED}✘ Ralat: Nilai port tidak sah.${NC}"; sleep 1; return
    fi
    check_port_available "$new_port"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✘ Port $new_port sedang digunakan!${NC}"; sleep 1; return
    fi
    sed -i "s/^port $curp/port $new_port/" "$conf"
    proto=$(grep -w proto "$conf" | awk '{print $2}')
    ufw delete allow $curp/$proto >/dev/null 2>&1
    ufw allow $new_port/$proto >/dev/null 2>&1
    iptables -D INPUT -p $proto --dport $curp -j ACCEPT >/dev/null 2>&1
    iptables -I INPUT -p $proto --dport $new_port -j ACCEPT
    # Restart VPN service
    svc_name=""
    case $pilih in
        1) svc_name="openvpn@server-udp-1194" ;;
        2) svc_name="openvpn@server-tcp-443" ;;
        3) svc_name="openvpn@server-udp-53" ;;
        4) svc_name="openvpn@server-tcp-80" ;;
    esac
    [ -n "$svc_name" ] && systemctl restart $svc_name
    echo -e "${GREEN}✔ Port OpenVPN berjaya ditukar kepada $new_port.${NC}"
    sleep 1
}

# MAIN MENU
while true; do
    clear
    echo -e "${BOLD}${CYAN}========= MENU TUKAR PORT =========${NC}"
    echo -e " 1) Tukar port Dropbear"
    echo -e " 2) Tukar port Stunnel (SSL)"
    echo -e " 3) Tukar port SSH WS Proxy"
    echo -e " 4) Tukar port OpenVPN"
    echo -e " 5) Tukar port OHP"
    echo -e " 6) Lihat Semua Port Semasa"
    echo -e " 0) Kembali"
    echo
    read -rp "Pilih menu [0-6]: " pmenu
    case $pmenu in
        1) change_port_dropbear ;;
        2) change_port_stunnel ;;
        3) change_port_wsproxy ;;
        4) change_port_openvpn ;;
        5) change_port_ohp ;;
        6) clear; view_ports; read -n1 -rsp $'Tekan sebarang kekunci untuk kembali ke menu...\n' ;;
        0) exit 0 ;;
        *) echo -e "${RED}Pilihan tidak sah!${NC}"; sleep 1 ;;
    esac
done
