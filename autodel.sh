#!/bin/bash
# Script Auto Delete User Expired (SSH, OpenVPN, Xray VMess/VLESS, Hysteria2)
# Sesuai struktur log dan config script menu MajSpace

source /usr/local/bin/utils.sh 2>/dev/null

TODAY=$(date +%Y-%m-%d)

# --- SSH & OpenVPN ---
clean_expired_linux_users() {
  for ULOG in /var/log/ssh-users.log /var/log/ovpn-users.log; do
    [[ ! -f "$ULOG" ]] && continue
    while IFS="|" read -r user pass exp; do
      username=$(echo "$user" | xargs)
      exdate=$(echo "$exp" | awk '{print $2}' | xargs)
      # Jika expired & user ada di sistem
      if [[ "$exdate" != "" && "$exdate" != "never" && "$exdate" != "-" ]]; then
        if [[ "$(date -d "$exdate" +%s 2>/dev/null)" -lt "$(date +%s)" ]]; then
          if id "$username" &>/dev/null; then
            userdel -r "$username"
            echo "User $username expired ($exdate) - deleted"
          fi
          # Hapus dari log
          sed -i "/^$username[ |]/d" "$ULOG"
          # Hapus OVPN config jika ada
          rm -f /var/www/html/client-${username}-*.ovpn 2>/dev/null
        fi
      fi
    done < "$ULOG"
  done
}

# --- XRAY VMess/VLESS ---
clean_expired_xray_users() {
  local changed=0
  [[ ! -f /var/log/xray-users.log ]] && return

  while IFS="|" read -r user uuid proto exp; do
    username=$(echo "$user" | xargs)
    proto=$(echo "$proto" | xargs)
    expdate=$(echo "$exp" | awk '{print $2}' | xargs)
    [[ -z "$username" || -z "$proto" || -z "$expdate" ]] && continue
    if [[ "$(date -d "$expdate" +%s 2>/dev/null)" -lt "$(date +%s)" ]]; then
      # Hapus user dari config Xray
      if [[ "$proto" == "vmess" || "$proto" == "vless" ]]; then
        proto_low=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
        if jq --arg user "$username" '
            .inbounds |= map(
              if .protocol == "'"$proto_low"'" and .settings.clients != null
              then .settings.clients |= map(select(.email != $user))
              else .
              end
            )' "$XRAY_CONFIG" > /tmp/xray_config.json; then
          mv /tmp/xray_config.json "$XRAY_CONFIG"
          changed=1
          echo "XRAY user $username ($proto) expired ($expdate) - deleted"
        fi
      fi
      # Hapus dari log
      sed -i "/^$username |.*$proto/d" /var/log/xray-users.log
    fi
  done < /var/log/xray-users.log

  # Restart Xray jika ada perubahan
  if [[ $changed -eq 1 ]]; then
    systemctl restart xray
  fi
}

# --- HYSTERIA2 ---
clean_expired_hysteria_users() {
  [[ ! -f /var/log/hysteria-users.log ]] && return
  while IFS="|" read -r user pass bandwidth exp; do
    username=$(echo "$user" | xargs)
    expdate=$(echo "$exp" | awk '{print $2}' | xargs)
    [[ -z "$username" || -z "$expdate" ]] && continue
    if [[ "$(date -d "$expdate" +%s 2>/dev/null)" -lt "$(date +%s)" ]]; then
      # Hapus dari log
      sed -i "/^$username |/d" /var/log/hysteria-users.log
      # Hapus config client file
      rm -f "/var/www/html/hysteria-$username.yaml" 2>/dev/null
      echo "Hysteria2 user $username expired ($expdate) - deleted"
    fi
  done < /var/log/hysteria-users.log
  # Restart hysteria2 supaya config terbaru
  systemctl restart hysteria2 2>/dev/null
}

# --- Eksekusi Semua ---
clean_expired_linux_users
clean_expired_xray_users
clean_expired_hysteria_users