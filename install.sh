#!/bin/bash
# AutoScriptSSH/Xray/OpenVPN Installer (Complete VPN Solution) for Ubuntu 22.04+

set -e

PERMISSION_URL="https://raw.githubusercontent.com/MajSpace/auth/refs/heads/main/permission.txt"
PERMISSION_FILE="/tmp/permission.txt"

check_permission() {
    local MYIP
    MYIP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
    TODAY=$(date +%Y-%m-%d)

    if ! curl -sfL "$PERMISSION_URL" -o "$PERMISSION_FILE"; then
        echo -e "\033[1;31mFailed to fetch permission file from server! Please contact the script provider.\033[0m"
        exit 1
    fi

    while IFS="|" read -r ALLOWED_IP CLIENT_NAME EXPIRY; do
        [[ -z "$ALLOWED_IP" || "$ALLOWED_IP" =~ ^# ]] && continue
        if [[ "$MYIP" == "$ALLOWED_IP" ]]; then
            if [[ "$EXPIRY" < "$TODAY" ]]; then
                echo -e "\033[1;31mYour VPS IP ($MYIP) is expired on $EXPIRY. Permission denied.\033[0m"
                exit 1
            fi
            echo -e "\033[1;32mPermission accepted for $CLIENT_NAME ($MYIP). Valid until $EXPIRY.\033[0m"
            return
        fi
    done < "$PERMISSION_FILE"

    echo -e "\033[1;31mYour VPS IP ($MYIP) is not registered. Permission denied.\033[0m"
    exit 1
}

check_permission

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

read -rp "Enter your domain name (e.g., majspace.works): " DOMAIN
mkdir -p /etc/xray
echo "$DOMAIN" > /etc/xray/domain.conf
read -rp "Enter your public IP address (e.g., 188.166.245.30): " SERVER_IP

echo -e "${GREEN}---> Updating system and installing dependencies...${RESET}"
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y curl wget unzip jq screen nginx certbot python3-certbot-nginx iptables stunnel4 dropbear socat xz-utils gnupg2 lsb-release pwgen openssl netcat iptables-persistent openvpn easy-rsa ufw

systemctl enable ssh
systemctl restart ssh

echo -e "${GREEN}---> Installing Python...${RESET}"
apt install -y python3 python3-pip

echo -e "${GREEN}---> Installing python-telegram-bot...${RESET}"
pip3 install python-telegram-bot==13.15

echo -e "${GREEN}---> Configuring Dropbear...${RESET}"
cat >/etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF
systemctl enable dropbear
systemctl restart dropbear

echo -e "${GREEN}---> Configuring Stunnel4...${RESET}"
mkdir -p /etc/stunnel
cat >/etc/stunnel/stunnel.conf <<EOF
pid = /var/run/stunnel4/stunnel.pid
cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/stunnel.pem

[ssh]
accept = 444
connect = 127.0.0.1:22

[dropbear]
accept = 777
connect = 127.0.0.1:109

[openvpn-ssl]
accept = 992
connect = 127.0.0.1:1194
EOF

SSL_KEY="/etc/stunnel/stunnel.key"
SSL_CERT="/etc/stunnel/stunnel.crt"
openssl req -new -x509 -days 3650 -nodes -out $SSL_CERT -keyout $SSL_KEY -subj "/CN=$DOMAIN"
cat $SSL_KEY $SSL_CERT > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable stunnel4
systemctl restart stunnel4

echo -e "${GREEN}---> Installing BadVPN-UDPGW...${RESET}"
systemctl stop badvpn-udpgw 2>/dev/null || true
wget -O /usr/bin/badvpn-udpgw "https://github.com/MajSpace/udpgw/raw/refs/heads/main/newudpgw"
chmod +x /usr/bin/badvpn-udpgw

cat >/etc/systemd/system/badvpn-udpgw.service <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7100 --listen-addr 0.0.0.0:7200 --listen-addr 0.0.0.0:7300 --listen-addr 0.0.0.0:7400 --listen-addr 0.0.0.0:7500 --listen-addr 0.0.0.0:7600 --listen-addr 0.0.0.0:7700 --listen-addr 0.0.0.0:7800 --listen-addr 0.0.0.0:7900
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn-udpgw
systemctl start badvpn-udpgw
systemctl restart badvpn-udpgw

# --- PATCH: Nginx config for .ovpn download ---

echo -e "${GREEN}---> Configuring Nginx for .ovpn download...${RESET}"

# Create /etc/nginx/sites-available/default if not exist and link
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# PATCH: add .ovpn MIME type to nginx.conf if missing
if ! grep -q "application/octet-stream ovpn;" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    types { application/octet-stream ovpn; }' /etc/nginx/nginx.conf
fi

# Clean up any other default config that might conflict
rm -f /etc/nginx/sites-enabled/000-default
rm -f /etc/nginx/sites-enabled/default.conf

# Reload Nginx after config
systemctl restart nginx

cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;

    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10010;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location ^~ /vless-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10001;
    }
    location ^~ /vmess-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10011;
    }
}
server {
    listen 80;
    server_name $DOMAIN;

    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

mkdir -p /etc/xray
mkdir -p /root/.acme.sh

echo -e "${GREEN}---> Installing acme.sh and issuing SSL (nginx will be stopped briefly)...${RESET}"
systemctl stop nginx
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256 || true

if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
    echo -e "${YELLOW}No Let's Encrypt cert, generating self-signed...${RESET}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/xray/xray.key \
        -out /etc/xray/xray.crt \
        -subj "/CN=$DOMAIN"
fi

systemctl start nginx

cat > /usr/local/bin/ssl_renew.sh <<EOF
#!/bin/bash
systemctl stop nginx
/root/.acme.sh/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
systemctl start nginx
systemctl status nginx
EOF
chmod +x /usr/local/bin/ssl_renew.sh
if ! crontab -l | grep -q 'ssl_renew.sh'; then
    (crontab -l; echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab
fi

echo -e "${GREEN}---> Installing Xray-core (v1.6.1)...${RESET}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.6.1

mkdir -p /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
chmod 640 /var/log/xray/*.log
chown www-data:www-data /var/log/xray/*.log

cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "info",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vless-grpc" }
      }
    },
    {
      "port": 10010,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "port": 10011,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vmess-grpc" }
      }
    },
    {
      "port": 10080,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "port": 10081,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF

systemctl restart xray

# --- Install & Configure OpenVPN ---
echo -e "${GREEN}---> Setting up OpenVPN with Multiple Ports & Protocols...${RESET}"

mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

# Initialize PKI and generate certificates
echo yes | ./easyrsa init-pki
echo "AutoScriptSSH-OpenVPN-CA" | ./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
./easyrsa gen-crl
openvpn --genkey secret /etc/openvpn/ta.key

cp pki/ca.crt /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/dh.pem /etc/openvpn/
cp pki/crl.pem /etc/openvpn/
chmod 644 /etc/openvpn/crl.pem

chmod 644 /etc/openvpn/ca.crt /etc/openvpn/server.crt /etc/openvpn/dh.pem /etc/openvpn/crl.pem /etc/openvpn/ta.key
chmod 600 /etc/openvpn/server.key
chown root:root /etc/openvpn/*

mkdir -p /var/log/openvpn
chown nobody:nogroup /var/log/openvpn
chmod 755 /var/log/openvpn

# --- OpenVPN Server Configurations (all using verify-client-cert none) ---
cat > /etc/openvpn/server-udp-1194.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
tls-auth ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp-udp-1194.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status-udp-1194.log
log-append /var/log/openvpn/openvpn-udp-1194.log
verb 3
explicit-exit-notify 1
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
username-as-common-name
verify-client-cert none
EOF

cat > /etc/openvpn/server-tcp-443.conf <<EOF
port 1443
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
tls-auth ta.key 0
server 10.9.0.0 255.255.255.0
ifconfig-pool-persist ipp-tcp-443.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status-tcp-443.log
log-append /var/log/openvpn/openvpn-tcp-443.log
verb 3
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
username-as-common-name
verify-client-cert none
EOF

cat > /etc/openvpn/server-udp-53.conf <<EOF
port 2053
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
tls-auth ta.key 0
server 10.10.0.0 255.255.255.0
ifconfig-pool-persist ipp-udp-53.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status-udp-53.log
log-append /var/log/openvpn/openvpn-udp-53.log
verb 3
explicit-exit-notify 1
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
username-as-common-name
verify-client-cert none
EOF

cat > /etc/openvpn/server-tcp-80.conf <<EOF
port 8080
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
crl-verify crl.pem
tls-auth ta.key 0
server 10.11.0.0 255.255.255.0
ifconfig-pool-persist ipp-tcp-80.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status-tcp-80.log
log-append /var/log/openvpn/openvpn-tcp-80.log
verb 3
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
username-as-common-name
verify-client-cert none
EOF

if [[ ! -f /usr/lib/openvpn/openvpn-plugin-auth-pam.so ]]; then
    apt-get install --reinstall openvpn -y
fi

systemctl enable openvpn@server-udp-1194
systemctl enable openvpn@server-tcp-443
systemctl enable openvpn@server-udp-53
systemctl enable openvpn@server-tcp-80

systemctl restart openvpn@server-udp-1194
systemctl restart openvpn@server-tcp-443
systemctl restart openvpn@server-udp-53
systemctl restart openvpn@server-tcp-80

touch /var/log/ssh-users.log
touch /var/log/xray-users.log
touch /var/log/ovpn-users.log
chmod 600 /var/log/ssh-users.log
chmod 600 /var/log/xray-users.log
chmod 600 /var/log/ovpn-users.log

# --- PATCH: Generate DEFAULT .ovpn CLIENT CONFIGS for web download ---
echo -e "${GREEN}---> Generating default OVPN client configs in /var/www/html ...${RESET}"
mkdir -p /var/www/html
for MODE in udp1194 tcp1443 udp2053 tcp8080; do
  if [[ $MODE == "udp1194" ]]; then
      PORT=1194; PROTO=udp
  elif [[ $MODE == "tcp1443" ]]; then
      PORT=1443; PROTO=tcp
  elif [[ $MODE == "udp2053" ]]; then
      PORT=2053; PROTO=udp
  elif [[ $MODE == "tcp8080" ]]; then
      PORT=8080; PROTO=tcp
  fi
  cat > /var/www/html/client-default-${MODE}.ovpn <<-END
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
$(cat /etc/openvpn/ca.crt)
</ca>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
key-direction 1
END
done
chmod 644 /var/www/html/client-default-*.ovpn
chown www-data:www-data /var/www/html/client-default-*.ovpn

# --- Install & Configure SlowDNS ---
echo -e "${GREEN}---> Installing SlowDNS...${RESET}"
apt update -y
rm -rf /etc/slowdns
mkdir -m 777 /etc/slowdns

read -rp "Enter SlowDNS NS domain (e.g., ns1.domain.com): " sldomain
echo "$sldomain" > /etc/nsdomain

wget -qO- -O /etc/ssh/sshd_config https://raw.githubusercontent.com/MajSpace/MAJSPACESCRIPT/refs/heads/main/sshd_config
systemctl restart sshd

wget -q -O /etc/slowdns/server.key "https://raw.githubusercontent.com/MajSpace/MAJSPACESCRIPT/refs/heads/main//server.key"
wget -q -O /etc/slowdns/server.pub "https://raw.githubusercontent.com/MajSpace/MAJSPACESCRIPT/refs/heads/main//server.pub"
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/MajSpace/MAJSPACESCRIPT/refs/heads/main//sldns-server"
wget -q -O /etc/slowdns/sldns-client "https://raw.githubusercontent.com/MajSpace/MAJSPACESCRIPT/refs/heads/main//sldns-client"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server /etc/slowdns/sldns-client

cat > /etc/systemd/system/client-sldns.service << END
[Unit]
Description=Client SlowDNS By SL
Documentation=https://majspace.works
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/sldns-client -udp 8.8.8.8:53 --pubkey-file /etc/slowdns/server.pub $sldomain 127.0.0.1:3369
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS By SL
Documentation=https://majspace.works
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $sldomain 127.0.0.1:2269
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

chmod +x /etc/systemd/system/client-sldns.service /etc/systemd/system/server-sldns.service

systemctl daemon-reload
systemctl stop client-sldns server-sldns
systemctl enable client-sldns server-sldns
systemctl start client-sldns server-sldns
systemctl restart client-sldns server-sldns

echo -e "${GREEN}---> Configuring firewall and routing...${RESET}"

# UFW: allow forwarding and NAT automatically
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sed -i 's/^#*net\/ipv4\/ip_forward=.*/net\/ipv4\/ip_forward=1/' /etc/ufw/sysctl.conf

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 444/tcp
ufw allow 777/tcp
ufw allow 992/tcp

ufw allow 1194/udp
ufw allow 1443/tcp
ufw allow 2053/udp
ufw allow 8080/tcp

for port in {7100..7900..100}; do ufw allow $port/udp; done
ufw allow 5300/udp

# Add NAT masquerade in /etc/ufw/before.rules if not present
if ! grep -q "OpenVPN MASQUERADE" /etc/ufw/before.rules; then
    NET_IF=$(ip route | awk '/default/ { print $5 ; exit }')
    sed -i '1s/^/*nat\n:POSTROUTING ACCEPT [0:0]\n# OpenVPN MASQUERADE\n-A POSTROUTING -s 10.8.0.0\/8 -o '"$NET_IF"' -j MASQUERADE\nCOMMIT\n\n/' /etc/ufw/before.rules
fi

ufw --force enable
ufw reload

sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

iptables -I INPUT -p udp --dport 1194 -j ACCEPT
iptables -I INPUT -p tcp --dport 1443 -j ACCEPT
iptables -I INPUT -p udp --dport 2053 -j ACCEPT
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

NET_IF=$(ip route | awk '/default/ { print $5 ; exit }')
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NET_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o $NET_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o $NET_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.11.0.0/24 -o $NET_IF -j MASQUERADE

iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# === SSH WebSocket Python Proxy ===
echo -e "${GREEN}---> Menginstall Python WebSocket Proxy (HTTP Custom, Armod, HTTP Injector compatible)...${RESET}"

PROXY_PORT=8880
PROXY_PATH="/root/proxy.py"
SERVICE_PATH="/etc/systemd/system/ws-python-proxy.service"

# Install python2 jika belum ada
if ! command -v python2 >/dev/null 2>&1; then
    apt update
    apt install -y python2
fi

# Buat file proxy.py
cat > "$PROXY_PATH" <<'EOF'
#!/usr/bin/python2
import socket, threading, select, sys, getopt, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 8880
PASS = ''
DEFAULT_HOST = '127.0.0.1:22'
RESPONSE = 'HTTP/1.1 101 <b><u><font color="#0effc2">MAJ SPACE SCRIPT t.me/majspace</font></b>\r\n\r\n\r\n\r\nContent-Length: 104857600000\r\n\r\n'
BUFLEN = 4096 * 4
TIMEOUT = 60

def print_usage():
    print 'Usage: proxy.py -p <port>'
    print '       proxy.py -b <bindAddr> -p <port>'
    print '       proxy.py -b 0.0.0.0 -p 80'

def parse_args(argv):
    global LISTENING_ADDR
    global LISTENING_PORT
    try:
        opts, args = getopt.getopt(argv,"hb:p:",["bind=","port="])
    except getopt.GetoptError:
        print_usage()
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print_usage()
            sys.exit()
        elif opt in ("-b", "--bind"):
            LISTENING_ADDR = arg
        elif opt in ("-p", "--port"):
            LISTENING_PORT = int(arg)

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        intport = int(self.port)
        self.soc.bind((self.host, intport))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        self.logLock.acquire()
        print log
        self.logLock.release()

    def addConn(self, conn):
        try:
            self.threadsLock.acquire()
            if self.running:
                self.threads.append(conn)
        finally:
            self.threadsLock.release()

    def removeConn(self, conn):
        try:
            self.threadsLock.acquire()
            self.threads.remove(conn)
        finally:
            self.threadsLock.release()

    def close(self):
        try:
            self.running = False
            self.threadsLock.acquire()
            threads = list(self.threads)
            for c in threads:
                c.close()
        finally:
            self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = ''
        self.server = server
        self.log = 'Connection: ' + str(addr)

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except:
            pass
        finally:
            self.clientClosed = True

        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            if hostPort == '':
                hostPort = DEFAULT_HOST
            split = self.findHeader(self.client_buffer, 'X-Split')
            if split != '':
                self.client.recv(BUFLEN)
            if hostPort != '':
                passwd = self.findHeader(self.client_buffer, 'X-Pass')
                if len(PASS) != 0 and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send('HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith('127.0.0.1') or hostPort.startswith('localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send('HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                print '- No X-Real-Host!'
                self.client.send('HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            try:
                self.log += ' - error: ' + str(e)
                self.server.printLog(self.log)
            except:
                pass
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(header + ': ')
        if aux == -1:
            return ''
        aux = head.find(':', aux)
        head = head[aux+2:]
        aux = head.find('\r\n')
        if aux == -1:
            return ''
        return head[:aux];

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i+1:])
            host = host[:i]
        else:
            port = 22
        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]
        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.log += ' - CONNECT ' + path
        self.connect_target(path)
        self.client.sendall(RESPONSE)
        self.client_buffer = ''
        self.server.printLog(self.log)
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            break
                    except:
                        error = True
                        break
            if count == TIMEOUT:
                error = True
            if error:
                break

if __name__ == '__main__':
    parse_args(sys.argv[1:])
    print "\n:-------PythonProxy-------:\n"
    print "Listening addr: " + LISTENING_ADDR
    print "Listening port: " + str(LISTENING_PORT) + "\n"
    print ":-------------------------:\n"
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    while True:
        try:
            time.sleep(2)
        except KeyboardInterrupt:
            print 'Stopping...'
            server.close()
            break
EOF

chmod +x "$PROXY_PATH"

# Buat systemd service
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Simple Python WS Proxy (untuk SSH WebSocket Android, HTTP Custom, HTTP Injector, dll)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python2 $PROXY_PATH -b 0.0.0.0 -p $PROXY_PORT
Restart=always
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ws-python-proxy
systemctl restart ws-python-proxy

# Firewall
ufw allow $PROXY_PORT/tcp
iptables -I INPUT -p tcp --dport $PROXY_PORT -j ACCEPT

echo -e "${GREEN}---> Python WebSocket Proxy aktif di port $PROXY_PORT (support armod, HTTP Custom, HTTP Injector)!${RESET}"

# --- Install & Configure Hysteria2 ---
echo -e "${GREEN}---> Installing Hysteria2...${RESET}"

# Get latest Hysteria2 version dynamically
echo -e "${YELLOW}Getting latest Hysteria2 version...${RESET}"
HYSTERIA_VERSION=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

if [[ -z "$HYSTERIA_VERSION" ]]; then
    echo -e "${YELLOW}Failed to get latest version, using fallback version...${RESET}"
    HYSTERIA_VERSION="v2.4.5"  # Fallback ke versi yang stabil
fi

echo -e "${GREEN}Installing Hysteria2 version: $HYSTERIA_VERSION${RESET}"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64) HYSTERIA_ARCH="amd64" ;;
  aarch64) HYSTERIA_ARCH="arm64" ;;
  armv7l) HYSTERIA_ARCH="armv7" ;;
  *) echo -e "${RED}Unsupported architecture: $ARCH${RESET}"; exit 1 ;;
esac

# Try different download methods
HYSTERIA_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA_VERSION}/hysteria-linux-${HYSTERIA_ARCH}"

echo -e "${YELLOW}Downloading Hysteria2 binary...${RESET}"
if wget -O /usr/local/bin/hysteria2 "$HYSTERIA_URL"; then
    echo -e "${GREEN}Downloaded successfully using direct binary${RESET}"
else
    echo -e "${YELLOW}Direct binary failed, trying alternative method...${RESET}"
    # Alternative: use install script
    if curl -fsSL https://get.hy2.sh/ | bash; then
        echo -e "${GREEN}Installed using official install script${RESET}"
        # Move binary to expected location if needed
        if [[ -f /usr/local/bin/hysteria ]]; then
            mv /usr/local/bin/hysteria /usr/local/bin/hysteria2
        fi
    else
        echo -e "${RED}Failed to install Hysteria2. Trying manual compilation...${RESET}"
        # Last resort: compile from source (simplified)
        echo -e "${YELLOW}Installing Go and compiling from source...${RESET}"
        apt update
        apt install -y golang-go git
        
        cd /tmp
        git clone https://github.com/apernet/hysteria.git
        cd hysteria
        go build -o hysteria2 ./app/cmd
        mv hysteria2 /usr/local/bin/
        cd /
        rm -rf /tmp/hysteria
        
        if [[ ! -f /usr/local/bin/hysteria2 ]]; then
            echo -e "${RED}All installation methods failed. Skipping Hysteria2...${RESET}"
            return 1
        fi
    fi
fi

chmod +x /usr/local/bin/hysteria2

# Verify installation
if /usr/local/bin/hysteria2 version >/dev/null 2>&1; then
    echo -e "${GREEN}Hysteria2 installed successfully!${RESET}"
    /usr/local/bin/hysteria2 version
else
    echo -e "${RED}Hysteria2 installation verification failed${RESET}"
    return 1
fi

# Create Hysteria2 directories
mkdir -p /etc/hysteria
mkdir -p /var/log/hysteria

# Generate Hysteria2 configuration
cat > /etc/hysteria/hysteria2.yaml <<EOF
listen: :8443

tls:
  cert: /etc/xray/xray.crt
  key: /etc/xray/xray.key

auth:
  type: password
  password: "defaultpass123"

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  keepAlivePeriod: 10s
  disablePathMTUDiscovery: false

bandwidth:
  up: 1 gbps
  down: 1 gbps

ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s

resolver:
  type: https
  https:
    addr: 8.8.8.8:443
    timeout: 10s

outbounds:
  - name: direct
    type: direct

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

log:
  level: info
  output: /var/log/hysteria/hysteria2.log
EOF

# Create systemd service for Hysteria2
cat > /etc/systemd/system/hysteria2.service <<EOF
[Unit]
Description=Hysteria2 Server
Documentation=https://hysteria.network
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria2 server -c /etc/hysteria/hysteria2.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# Create log files and set permissions
touch /var/log/hysteria-users.log
touch /var/log/hysteria/hysteria2.log
chmod 600 /var/log/hysteria-users.log
chmod 644 /var/log/hysteria/hysteria2.log

# Enable and start Hysteria2
systemctl daemon-reload
systemctl enable hysteria2

# Start Hysteria2 service
systemctl start hysteria2

# Check if service started successfully
sleep 3
if systemctl is-active hysteria2 >/dev/null; then
    echo -e "${GREEN}Hysteria2 service started successfully${RESET}"
else
    echo -e "${RED}Hysteria2 service failed to start, checking logs...${RESET}"
    journalctl -u hysteria2 --no-pager -l -n 10
fi

# Add UFW rules for Hysteria2
ufw allow 8443/udp

# Add iptables rules for Hysteria2
iptables -I INPUT -p udp --dport 8443 -j ACCEPT
iptables-save > /etc/iptables.up.rules
netfilter-persistent save

echo -e "${GREEN}---> Hysteria2 installation completed!${RESET}"

# --- Download Menu Scripts ---
echo -e "${GREEN}---> Downloading menu scripts...${RESET}"

# GANTI URL INI DENGAN URL REPOSITORI GITHUB ANDA YANG SEBENARNYA
BASE_MENU_URL="https://raw.githubusercontent.com/MajSpace/zz/refs/heads/main"

# Download utils.sh (file utilitas global)
wget -O /usr/local/bin/utils.sh "$BASE_MENU_URL/utils.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/utils.sh

# Download menu utama
wget -O /usr/local/bin/menu "$BASE_MENU_URL/menu.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menu
ln -sf /usr/local/bin/menu /usr/bin/menu

# Download sub-menu SSH & OpenVPN
wget -O /usr/local/bin/menussh "$BASE_MENU_URL/menussh.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menussh
ln -sf /usr/local/bin/menussh /usr/bin/menussh

# Download sub-menu VMess
wget -O /usr/local/bin/menuvmess "$BASE_MENU_URL/menuvmess.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menuvmess
ln -sf /usr/local/bin/menuvmess /usr/bin/menuvmess

# Download sub-menu VLESS
wget -O /usr/local/bin/menuvless "$BASE_MENU_URL/menuvless.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menuvless
ln -sf /usr/local/bin/menuvless /usr/bin/menuvless

# Download sub-menu Hysteria2
wget -O /usr/local/bin/menuhysteria "$BASE_MENU_URL/menuhysteria.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menuhysteria
ln -sf /usr/local/bin/menuhysteria /usr/bin/menuhysteria

# Download sub-menu backup
wget -O /usr/local/bin/menubackup "$BASE_MENU_URL/menubackup.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menubackup
ln -sf /usr/local/bin/menubackup /usr/bin/menubackup

# Download file bot.py...
wget -O /usr/local/bin/bot.py "$BASE_MENU_URL/bot.py" >/dev/null 2>&1
chmod +x /usr/local/bin/bot.py

# Menambahkan menu menubot ke /usr/local/bin/menubot"
wget -O /usr/local/bin/menubot "$BASE_MENU_URL/menubot.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/menubot
ln -sf /usr/local/bin/menubot /usr/bin/menubot

touch /etc/menubot.conf

# Download Auto Delete User Expired
wget -O /usr/local/bin/autodel.sh "$BASE_MENU_URL/autodel.sh" >/dev/null 2>&1
chmod +x /usr/local/bin/autodel.sh
if ! grep -q "/usr/local/bin/autodel.sh" /etc/crontab; then
    echo "0 5 * * * root /usr/local/bin/autodel.sh >/var/log/autodel.log 2>&1" >> /etc/crontab
fi

echo -e "${GREEN}---> All menu scripts downloaded successfully!${RESET}"

echo -e "${GREEN}\n==== Installation Complete! ====${RESET}"
echo "Domain: $DOMAIN"
echo "IP: $SERVER_IP"
echo ""
echo "=== SSH/Tunneling Services ==="
echo "OpenSSH: 22"
echo "Dropbear: 109, 143"
echo "Stunnel4: 444, 777, 992"
echo "BadVPN-UDPGW: 7100-7900 UDP"
echo ""
echo "=== SSH WebSocket Python Proxy ==="
echo "SSH WS (Python Proxy): 8880"
echo "Contoh Payload (SSH WS):"
echo "GET / HTTP/1.1[crlf]Host: $DOMAIN[crlf]Connection: Keep-Alive[crlf][crlf]"
echo ""
echo "=== Xray-core Services ==="
echo "HTTPS TLS: 443 (VLESS/VMess WS+gRPC via nginx proxy)"
echo "HTTP nTLS: 80 (VLESS/VMess WS non-TLS via nginx proxy)"
echo ""
echo "=== OpenVPN Multi-Port Services ==="
echo "UDP Standard: 1194"
echo "TCP HTTPS Bypass: 1443"
echo "UDP DNS Bypass: 2053"
echo "TCP HTTP Bypass: 8080"
echo ""
echo "=== Hysteria2 Service ==="
echo "Hysteria2: 8443 UDP (QUIC/HTTP3 Protocol)"
echo "Features: High-speed, Low-latency, BBR Congestion Control"
echo ""
echo "=== SlowDNS Service ==="
echo "SlowDNS: 5300 UDP (NS: $sldomain, Public Key: $(cat /etc/slowdns/server.pub | head -n1))"
echo ""
echo "=== Download Default OVPN Configs ==="
echo "UDP 1194   : http://$SERVER_IP/client-default-udp1194.ovpn"
echo "TCP 1443   : http://$SERVER_IP/client-default-tcp1443.ovpn"
echo "UDP 2053   : http://$SERVER_IP/client-default-udp2053.ovpn"
echo "TCP 8080   : http://$SERVER_IP/client-default-tcp8080.ovpn"
echo ""
echo "=== Available Commands ==="
echo "menu         - Main menu"
echo "menussh      - SSH & OpenVPN management"
echo "menuvmess    - VMess management"
echo "menuvless    - VLESS management"
echo "menuhysteria - Hysteria2 management"
echo ""
echo -e "${YELLOW}Use 'menu' command to start managing your VPN services!${RESET}"

menu