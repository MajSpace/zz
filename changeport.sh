#!/bin/bash

# Source file utilitas global
source /usr/local/bin/utils.sh

# Fungsi untuk memeriksa ketersediaan port
is_port_available() {
  local port=$1
  # Memeriksa apakah port sedang digunakan oleh proses lain
  if lsof -i :"$port" >/dev/null 2>&1; then
    return 1 # Port sedang digunakan
  fi
  # Memeriksa apakah port sudah diizinkan oleh UFW (untuk menghindari konflik dengan aturan firewall yang ada)
  if ufw status | grep -q "$port"; then
    return 1 # Port sudah diatur di UFW
  fi
  return 0 # Port tersedia
}

# Fungsi untuk mendapatkan port semasa
# Fungsi untuk mendapatkan port semasa
get_current_ports() {
  local service=$1
  case "$service" in
    "dropbear")
      # Ambil DROPBEAR_PORT
      local port1=$(grep -oP '(?<=^DROPBEAR_PORT=)[0-9]+' /etc/default/dropbear | xargs)
      # Ambil port dari DROPBEAR_EXTRA_ARGS, pastikan hanya angka
      local port2=$(grep -oP '(?<=DROPBEAR_EXTRA_ARGS=".*-p )[0-9]+' /etc/default/dropbear | xargs)
      echo "$port1 $port2"
      ;;
    "stunnel")
      local ports=$(grep "accept =" /etc/stunnel/stunnel.conf | awk '{print $3}' | xargs | tr '\n' ' ')
      echo "$ports"
      ;;
    "ssh_ws_proxy")
      # Gunakan grep -oP untuk mengambil hanya angka setelah LISTENING_PORT =
      local port=$(grep -oP '(?<=^LISTENING_PORT = )[0-9]+' /usr/local/proxy.py | xargs)
      echo "$port"
      ;;
    "openvpn_udp_1194")
      local port=$(grep "port" /etc/openvpn/server-udp-1194.conf | awk '{print $2}' | xargs)
      echo "$port"
      ;;
    "openvpn_tcp_1443")
      local port=$(grep "port" /etc/openvpn/server-tcp-443.conf | awk '{print $2}' | xargs)
      echo "$port"
      ;;
    "openvpn_udp_2053")
      local port=$(grep "port" /etc/openvpn/server-udp-53.conf | awk '{print $2}' | xargs)
      echo "$port"
      ;;
    "openvpn_tcp_8080")
      local port=$(grep "port" /etc/openvpn/server-tcp-80.conf | awk '{print $2}' | xargs)
      echo "$port"
      ;;
    "ohp")
      local port=$(grep "ExecStart" /etc/systemd/system/ohp.service | awk -F'-port ' '{print $2}' | awk '{print $1}' | xargs)
      echo "$port"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Fungsi untuk memaparkan port semasa
show_current_ports_info() {
  title_banner
  echo -e "${PURPLE}${BOLD}Port Semasa Perkhidmatan${RESET}"
  echo -e "${FULL_BORDER}"

  echo -e "${YELLOW}  Dropbear:${RESET}"
  local db_ports=$(get_current_ports "dropbear")
  echo -e "${LIGHT_CYAN}    Port Semasa: $db_ports${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  Stunnel (SSL/TLS):${RESET}"
  local st_ports=$(get_current_ports "stunnel")
  echo -e "${LIGHT_CYAN}    Port Semasa: $st_ports${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  SSH WS Proxy:${RESET}"
  local ws_port=$(get_current_ports "ssh_ws_proxy")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ws_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  OpenVPN UDP 1194:${RESET}"
  local ovpn_udp1194_port=$(get_current_ports "openvpn_udp_1194")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ovpn_udp1194_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  OpenVPN TCP 1443:${RESET}"
  local ovpn_tcp1443_port=$(get_current_ports "openvpn_tcp_1443")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ovpn_tcp1443_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  OpenVPN UDP 2053:${RESET}"
  local ovpn_udp2053_port=$(get_current_ports "openvpn_udp_2053")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ovpn_udp2053_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  OpenVPN TCP 8080:${RESET}"
  local ovpn_tcp8080_port=$(get_current_ports "openvpn_tcp_8080")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ovpn_tcp8080_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  echo -e "${YELLOW}  OHP:${RESET}"
  local ohp_port=$(get_current_ports "ohp")
  echo -e "${LIGHT_CYAN}    Port Semasa: $ohp_port${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk menukar port Dropbear
change_dropbear_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tukar Port Dropbear${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port1=$(grep "DROPBEAR_PORT" /etc/default/dropbear | cut -d'=' -f2 | xargs)
  local current_port2=$(grep "DROPBEAR_EXTRA_ARGS" /etc/default/dropbear | awk -F'-p ' '{print $2}' | awk '{print $1}' | xargs)

  echo -e "${WHITE}Port Dropbear Semasa:${RESET}"
  echo -e "${YELLOW}  1. Port Utama: ${LIGHT_CYAN}$current_port1${RESET}"
  echo -e "${YELLOW}  2. Port Tambahan: ${LIGHT_CYAN}$current_port2${RESET}"
  echo -e "${SECTION_DIVIDER}"

  read -rp "Pilih nombor port yang ingin ditukar (1 atau 2): " choice
  local old_port=""
  local config_line=""
  local new_port=""

  case "$choice" in
    1)
      old_port="$current_port1"
      config_line="DROPBEAR_PORT"
      ;;
    2)
      old_port="$current_port2"
      config_line="DROPBEAR_EXTRA_ARGS"
      ;;
    *)
      echo -e "${RED}✘ Pilihan tidak sah. Sila masukkan 1 atau 2.${RESET}"
      pause
      return
      ;;
  esac

  read -rp "Masukkan nombor port baru untuk $old_port: " new_port

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port <= 0 || new_port > 65535 )); then
    echo -e "${RED}✘ Ralat: Port tidak sah. Sila masukkan nombor antara 1 dan 65535.${RESET}"
    pause
    return
  fi

  if ! is_port_available "$new_port"; then
    echo -e "${RED}✘ Ralat: Port $new_port sudah digunakan atau diizinkan di sistem. Sila pilih port lain.${RESET}"
    pause
    return
  fi

  loading_animation "Menukar port Dropbear dari $old_port ke $new_port"

  # Hapus aturan UFW lama
  ufw delete allow "$old_port"/tcp >/dev/null 2>&1 || true
  iptables -D INPUT -p tcp --dport "$old_port" -j ACCEPT >/dev/null 2>&1 || true

  if [[ "$config_line" == "DROPBEAR_PORT" ]]; then
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=${new_port}/" /etc/default/dropbear
  elif [[ "$config_line" == "DROPBEAR_EXTRA_ARGS" ]]; then
    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*-p ${old_port}.*/DROPBEAR_EXTRA_ARGS=\"-p ${new_port}\"/" /etc/default/dropbear
  fi

  systemctl restart dropbear >/dev/null 2>&1

  # Tambah aturan UFW baru
  ufw allow "$new_port"/tcp >/dev/null 2>&1
  iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT

  echo -e "${BRIGHT_GREEN}✔ Port Dropbear berjaya ditukar dari $old_port ke $new_port.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk menukar port Stunnel
change_stunnel_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tukar Port Stunnel (SSL/TLS)${RESET}"
  echo -e "${FULL_BORDER}"

  local current_ports=($(get_current_ports "stunnel"))
  local config_file="/etc/stunnel/stunnel.conf"

  echo -e "${WHITE}Port Stunnel Semasa:${RESET}"
  local i=1
  for p in "${current_ports[@]}"; do
    echo -e "${YELLOW}  $i. Port: ${LIGHT_CYAN}$p${RESET}"
    ((i++))
  done
  echo -e "${SECTION_DIVIDER}"

  read -rp "Pilih nombor port yang ingin ditukar (1-${#current_ports[@]}): " choice_idx
  if ! [[ "$choice_idx" =~ ^[0-9]+$ ]] || (( choice_idx < 1 || choice_idx > ${#current_ports[@]} )); then
    echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
    pause
    return
  fi

  local old_port="${current_ports[$((choice_idx-1))]}"
  read -rp "Masukkan nombor port baru untuk $old_port: " new_port

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port <= 0 || new_port > 65535 )); then
    echo -e "${RED}✘ Ralat: Port tidak sah. Sila masukkan nombor antara 1 dan 65535.${RESET}"
    pause
    return
  fi

  if ! is_port_available "$new_port"; then
    echo -e "${RED}✘ Ralat: Port $new_port sudah digunakan atau diizinkan di sistem. Sila pilih port lain.${RESET}"
    pause
    return
  fi

  loading_animation "Menukar port Stunnel dari $old_port ke $new_port"

  # Hapus aturan UFW lama
  ufw delete allow "$old_port"/tcp >/dev/null 2>&1 || true
  iptables -D INPUT -p tcp --dport "$old_port" -j ACCEPT >/dev/null 2>&1 || true

  # Ganti port dalam file konfigurasi
  sed -i "s/accept = ${old_port}/accept = ${new_port}/g" "$config_file"

  systemctl restart stunnel4 >/dev/null 2>&1

  # Tambah aturan UFW baru
  ufw allow "$new_port"/tcp >/dev/null 2>&1
  iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT

  echo -e "${BRIGHT_GREEN}✔ Port Stunnel berjaya ditukar dari $old_port ke $new_port.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk menukar port SSH WS Proxy
change_ssh_ws_proxy_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tukar Port SSH WS Proxy${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port=$(get_current_ports "ssh_ws_proxy")
  local proxy_path="/usr/local/proxy.py"
  local service_path="/etc/systemd/system/ws-python-proxy.service"

  echo -e "${WHITE}Port SSH WS Proxy Semasa: ${LIGHT_CYAN}$current_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  read -rp "Masukkan nombor port baru: " new_port

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port <= 0 || new_port > 65535 )); then
    echo -e "${RED}✘ Ralat: Port tidak sah. Sila masukkan nombor antara 1 dan 65535.${RESET}"
    pause
    return
  fi

  if ! is_port_available "$new_port"; then
    echo -e "${RED}✘ Ralat: Port $new_port sudah digunakan atau diizinkan di sistem. Sila pilih port lain.${RESET}"
    pause
    return
  fi

  loading_animation "Menukar port SSH WS Proxy dari $current_port ke $new_port"

  # Hapus aturan UFW lama
  ufw delete allow "$current_port"/tcp >/dev/null 2>&1 || true
  iptables -D INPUT -p tcp --dport "$current_port" -j ACCEPT >/dev/null 2>&1 || true

  # Update port di proxy.py
  sed -i "s/^LISTENING_PORT = .*/LISTENING_PORT = ${new_port}/" "$proxy_path"
  # Update port di service file
  # Perhatikan perubahan di sini: menggunakan variabel $current_port untuk mencari dan mengganti
  sed -i "s/-p ${current_port}/-p ${new_port}/" "$service_path"

  systemctl daemon-reload >/dev/null 2>&1
  systemctl restart ws-python-proxy >/dev/null 2>&1

  # Tambah aturan UFW baru
  ufw allow "$new_port"/tcp >/dev/null 2>&1
  iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT

  echo -e "${BRIGHT_GREEN}✔ Port SSH WS Proxy berjaya ditukar dari $current_port ke $new_port.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk menukar port OpenVPN
change_openvpn_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tukar Port OpenVPN${RESET}"
  echo -e "${FULL_BORDER}"

  declare -A ovpn_configs
  ovpn_configs["udp_1194"]="/etc/openvpn/server-udp-1194.conf"
  ovpn_configs["tcp_1443"]="/etc/openvpn/server-tcp-443.conf"
  ovpn_configs["udp_2053"]="/etc/openvpn/server-udp-53.conf"
  ovpn_configs["tcp_8080"]="/etc/openvpn/server-tcp-80.conf"

  local current_ports=()
  local config_keys=()
  local i=1
  for key in "${!ovpn_configs[@]}"; do
    local current_port=$(get_current_ports "openvpn_$key")
    echo -e "${YELLOW}  $i. ${key^^}: ${LIGHT_CYAN}$current_port${RESET}"
    current_ports+=("$current_port")
    config_keys+=("$key")
    ((i++))
  done
  echo -e "${SECTION_DIVIDER}"

  read -rp "Pilih nombor konfigurasi OpenVPN yang ingin ditukar (1-${#config_keys[@]}): " choice_idx
  if ! [[ "$choice_idx" =~ ^[0-9]+$ ]] || (( choice_idx < 1 || choice_idx > ${#config_keys[@]} )); then
    echo -e "${RED}✘ Pilihan tidak sah.${RESET}"
    pause
    return
  fi

  local selected_key="${config_keys[$((choice_idx-1))]}"
  local old_port="${current_ports[$((choice_idx-1))]}"
  local config_file="${ovpn_configs[$selected_key]}"
  local proto=$(echo "$selected_key" | cut -d'_' -f1) # udp atau tcp
  local service_name="openvpn@server-${selected_key//_/-}" # openvpn@server-udp-1194

  read -rp "Masukkan nombor port baru untuk ${selected_key^^} (semasa: $old_port): " new_port

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port <= 0 || new_port > 65535 )); then
    echo -e "${RED}✘ Ralat: Port tidak sah. Sila masukkan nombor antara 1 dan 65535.${RESET}"
    pause
    return
  fi

  if ! is_port_available "$new_port"; then
    echo -e "${RED}✘ Ralat: Port $new_port sudah digunakan atau diizinkan di sistem. Sila pilih port lain.${RESET}"
    pause
    return
  fi

  loading_animation "Menukar port OpenVPN ${selected_key^^} dari $old_port ke $new_port"

  # Hapus aturan UFW lama
  ufw delete allow "$old_port"/"$proto" >/dev/null 2>&1 || true
  iptables -D INPUT -p "$proto" --dport "$old_port" -j ACCEPT >/dev/null 2>&1 || true

  # Update port di file konfigurasi OpenVPN
  sed -i "s/^port ${old_port}/port ${new_port}/" "$config_file"

  systemctl restart "$service_name" >/dev/null 2>&1

  # Tambah aturan UFW baru
  ufw allow "$new_port"/"$proto" >/dev/null 2>&1
  iptables -I INPUT -p "$proto" --dport "$new_port" -j ACCEPT

  echo -e "${BRIGHT_GREEN}✔ Port OpenVPN ${selected_key^^} berjaya ditukar dari $old_port ke $new_port.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Fungsi untuk menukar port OHP
change_ohp_port() {
  title_banner
  echo -e "${PURPLE}${BOLD}Tukar Port OHP${RESET}"
  echo -e "${FULL_BORDER}"

  local current_port=$(get_current_ports "ohp")
  local service_file="/etc/systemd/system/ohp.service"

  echo -e "${WHITE}Port OHP Semasa: ${LIGHT_CYAN}$current_port${RESET}"
  echo -e "${SECTION_DIVIDER}"

  read -rp "Masukkan nombor port baru: " new_port

  if ! [[ "$new_port" =~ ^[0-9]+$ ]] || (( new_port <= 0 || new_port > 65535 )); then
    echo -e "${RED}✘ Ralat: Port tidak sah. Sila masukkan nombor antara 1 dan 65535.${RESET}"
    pause
    return
  fi

  if ! is_port_available "$new_port"; then
    echo -e "${RED}✘ Ralat: Port $new_port sudah digunakan atau diizinkan di sistem. Sila pilih port lain.${RESET}"
    pause
    return
  fi

  loading_animation "Menukar port OHP dari $current_port ke $new_port"

  # Hapus aturan UFW lama
  ufw delete allow "$current_port"/tcp >/dev/null 2>&1 || true
  iptables -D INPUT -p tcp --dport "$current_port" -j ACCEPT >/dev/null 2>&1 || true

  # Update port di service file
  sed -i "s/-port ${current_port}/-port ${new_port}/" "$service_file"

  systemctl daemon-reload >/dev/null 2>&1
  systemctl restart ohp >/dev/null 2>&1

  # Tambah aturan UFW baru
  ufw allow "$new_port"/tcp >/dev/null 2>&1
  iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT

  echo -e "${BRIGHT_GREEN}✔ Port OHP berjaya ditukar dari $current_port ke $new_port.${RESET}"
  echo -e "${FULL_BORDER}"
  pause
}

# Menu utama Tukar Port
changeport_menu() {
  while true; do
    title_banner
    echo -e "${PURPLE}${BOLD}${UNDERLINE}Tukar Port Perkhidmatan${RESET}"
    echo -e "${FULL_BORDER}"
    echo -e "${YELLOW}  1. ${WHITE}Lihat Port Semasa Semua Perkhidmatan${RESET}"
    echo -e "${YELLOW}  2. ${WHITE}Tukar Port Dropbear${RESET}"
    echo -e "${YELLOW}  3. ${WHITE}Tukar Port Stunnel (SSL/TLS)${RESET}"
    echo -e "${YELLOW}  4. ${WHITE}Tukar Port SSH WS Proxy${RESET}"
    echo -e "${YELLOW}  5. ${WHITE}Tukar Port OpenVPN${RESET}"
    echo -e "${YELLOW}  6. ${WHITE}Tukar Port OHP${RESET}"
    echo -e "${YELLOW}  0. ${WHITE}Kembali ke Menu Utama${RESET}"
    echo -e "${FULL_BORDER}"
    echo -ne "${WHITE}Pilih pilihan [0-6]: ${RESET}"
    read opt
    case $opt in
      1) show_current_ports_info ;;
      2) change_dropbear_port ;;
      3) change_stunnel_port ;;
      4) change_ssh_ws_proxy_port ;;
      5) change_openvpn_port ;;
      6) change_ohp_port ;;
      0) return ;;
      *) echo -e "${RED}✘ Pilihan tidak sah. Sila pilih nombor antara 0 dan 6.${RESET}"; pause ;;
    esac
  done
}

# Panggil fungsi menu utama
changeport_menu
