import os
import logging
import subprocess
import json
import datetime
import time
import re

from telegram import Update, ForceReply
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
import html

# Konfigurasi Logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Ambil token dan admin ID dari environment variables
TOKEN = os.environ.get('TELEGRAM_BOT_TOKEN')
ADMIN_ID = os.environ.get('TELEGRAM_ADMIN_ID')

# Path ke skrip shell dan file konfigurasi
XRAY_CONFIG = "/usr/local/etc/xray/config.json"
HYSTERIA_CONFIG = "/etc/hysteria/hysteria2.yaml"
DOMAIN_FILE = "/etc/xray/domain.conf"
IP_CMD = "curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}'"
LOG_SSH_USERS = "/var/log/ssh-users.log"
LOG_OVPN_USERS = "/var/log/ovpn-users.log"
LOG_XRAY_USERS = "/var/log/xray-users.log"
LOG_HYSTERIA_USERS = "/var/log/hysteria-users.log"
NSDOMAIN_FILE = "/etc/nsdomain"
SERVER_PUB_FILE = "/etc/slowdns/server.pub"

# Fungsi pembantu untuk menjalankan perintah shell
def run_shell_command(command):
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logger.error(f"Perintah gagal: {command}\nStdout: {e.stdout}\nStderr: {e.stderr}")
        return f"Ralat: {e.stderr.strip()}"
    except Exception as e:
        logger.error(f"Ralat tak terduga saat menjalankan perintah: {command}\nError: {e}")
        return f"Ralat tak terduga: {e}"

# Fungsi untuk memvalidasi username (sesuai utils.sh)
def validate_username(username):
    if not username or not re.match(r"^[a-zA-Z0-9_-]+$", username):
        return False, "Nama pengguna hanya boleh mengandungi huruf, nombor, tanda hubung, atau garis bawah."
    return True, ""

# Fungsi untuk memvalidasi hari (sesuai utils.sh)
def validate_days(days_str):
    try:
        days = int(days_str)
        if days <= 0:
            return False, "Sila masukkan bilangan hari yang sah (nombor positif)."
        return True, ""
    except ValueError:
        return False, "Sila masukkan bilangan hari yang sah (nombor positif)."

# Fungsi untuk menghasilkan password (sesuai utils.sh)
def generate_password(length=12):
    return run_shell_command(f"openssl rand -base64 {length} | tr -d \"=+ /\" | cut -c1-{length}")

# Fungsi untuk mendapatkan domain dan IP
def get_domain_ip():
    domain = "Tidak Tersedia"
    if os.path.exists(DOMAIN_FILE):
        with open(DOMAIN_FILE, 'r') as f:
            domain = f.read().strip()
    ip = run_shell_command(IP_CMD)
    return domain, ip

# Fungsi untuk mendapatkan info SlowDNS
def get_slowdns_info():
    sldomain = "Tidak Tersedia"
    if os.path.exists(NSDOMAIN_FILE):
        with open(NSDOMAIN_FILE, 'r') as f:
            sldomain = f.read().strip()
    slpubkey = "Tidak Tersedia"
    if os.path.exists(SERVER_PUB_FILE):
        slpubkey = run_shell_command(f"head -n 1 {SERVER_PUB_FILE}")
    return sldomain, slpubkey

# --- Command Handlers ---

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /start is issued."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        logger.warning(f"Akses tidak dibenarkan dari ID: {update.effective_user.id}")
        return

    user = update.effective_user
    await update.message.reply_html(
        rf"Salam {user.mention_html()}! Saya adalah bot pengurusan VPN anda. "
        "Sila gunakan arahan berikut:\n\n"
        "/create_ssh <username> <hari> - Cipta akaun SSH\n"
        "/create_ovpn <username> <hari> - Cipta akaun OpenVPN\n"
        "/create_vmess <username> <hari> - Cipta akaun Xray VMess\n"
        "/create_vless <username> <hari> - Cipta akaun Xray VLESS\n"
        "/create_hysteria <username> <hari> - Cipta akaun Hysteria2\n"
        "/info - Papar maklumat server\n"
        "/status - Papar status perkhidmatan\n"
        "/help - Papar arahan ini semula",
        reply_markup=ForceReply(selective=True),
    )

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send a message when the command /help is issued."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return
    await start(update, context) # Re-use start message for help

async def info_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Display server information."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    domain, ip = get_domain_ip()
    sldomain, slpubkey = get_slowdns_info()
    uptime = run_shell_command("uptime -p")
    load_avg = run_shell_command("uptime | awk -F'load average:' '{print $2}'")
    mem_usage = run_shell_command("free -h | awk 'NR==2{printf \"%.1f%%\", $3*100/$2}'")
    disk_usage = run_shell_command("df -h / | awk 'NR==2{print $5}'")

    message = (
        f"<b>Maklumat Server VPN:</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"🌐 Domain: <code>{html.escape(domain)}</code>\n"
        f"IP: <code>{html.escape(ip)}</code>\n"
        f"⏰ Masa Aktif: {html.escape(uptime)}\n"
        f"📈 Load Average: {html.escape(load_avg)}\n"
        f"💾 Memori: {html.escape(mem_usage)}\n"
        f"💽 Disk: {html.escape(disk_usage)}\n\n"
        f"<b>Port Perkhidmatan:</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"SSH: 22\n"
        f"Dropbear: 109, 143\n"
        f"Stunnel4: 444, 777, 992\n"
        f"BadVPN-UDPGW: 7100-7900 UDP\n"
        f"SSH WS Proxy: 8880\n"
        f"Xray TLS: 443 (WS, gRPC)\n"
        f"Xray nTLS: 80 (WS)\n"
        f"OpenVPN UDP: 1194, 2053\n"
        f"OpenVPN TCP: 1443, 8080\n"
        f"Hysteria2: 8443 UDP\n"
        f"SlowDNS: 5300 UDP (NS: {html.escape(sldomain)}, Key: {html.escape(slpubkey)})\n\n"
        f"<b>Pautan Konfigurasi OVPN (Default):</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"UDP 1194: http://{html.escape(ip)}/client-default-udp1194.ovpn\n"
        f"TCP 1443: http://{html.escape(ip)}/client-default-tcp1443.ovpn\n"
        f"UDP 2053: http://{html.escape(ip)}/client-default-udp2053.ovpn\n"
        f"TCP 8080: http://{html.escape(ip)}/client-default-tcp8080.ovpn\n"
    )
    await update.message.reply_html(message)

async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Display service status."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    services = {
        "nginx": "Nginx Web Server",
        "xray": "Xray-core",
        "dropbear": "Dropbear SSH",
        "stunnel4": "Stunnel4",
        "badvpn-udpgw": "BadVPN UDPGW",
        "ssh": "OpenSSH",
        "server-sldns": "SlowDNS Server",
        "hysteria2": "Hysteria2",
        "openvpn@server-udp-1194": "OpenVPN UDP 1194",
        "openvpn@server-tcp-443": "OpenVPN TCP 1443",
        "openvpn@server-udp-53": "OpenVPN UDP 2053",
        "openvpn@server-tcp-80": "OpenVPN TCP 8080",
        "vpn_telegram_bot": "Telegram Bot" # Add bot's own status
    }
    
    status_messages = []
    for svc, desc in services.items():
        status = run_shell_command(f"systemctl is-active {svc} 2>/dev/null")
        if status == "active":
            status_messages.append(f"🟢 {desc}: Aktif")
        elif status == "inactive":
            status_messages.append(f"🔴 {desc}: Tidak Aktif")
        elif status == "failed":
            status_messages.append(f"🟠 {desc}: Gagal")
        else:
            status_messages.append(f"⚪ {desc}: {status}")
    
    message = "<b>Status Perkhidmatan:</b>\n━━━━━━━━━━━━━━━━━━━━\n" + "\n".join(status_messages)
    await update.message.reply_html(message)

async def create_ssh(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Create SSH user."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    if len(context.args) != 2:
        await update.message.reply_text("Penggunaan: /create_ssh <username> <hari>")
        return

    username = context.args[0]
    days_str = context.args[1]

    valid_user, user_msg = validate_username(username)
    if not valid_user:
        await update.message.reply_text(f"Ralat nama pengguna: {user_msg}")
        return
    
    valid_days, days_msg = validate_days(days_str)
    if not valid_days:
        await update.message.reply_text(f"Ralat hari: {days_msg}")
        return

    # Cek apakah username sudah ada di sistem
    if run_shell_command(f"id {username} &>/dev/null; echo $?").strip() == "0":
        await update.message.reply_text(f"Ralat: Nama pengguna '{html.escape(username)}' sudah wujud.")
        return

    password = generate_password()
    expiry_date = (datetime.date.today() + datetime.timedelta(days=int(days_str))).strftime("%Y-%m-%d")

    await update.message.reply_text(f"Sedang mencipta pengguna SSH '{html.escape(username)}'...")

    cmd = f"useradd -e {expiry_date} -m -s /bin/bash {username} && echo '{username}:{password}' | chpasswd"
    result = run_shell_command(cmd)

    if "Ralat" in result or "gagal" in result.lower():
        await update.message.reply_text(f"Gagal mencipta pengguna SSH: {html.escape(result)}")
    else:
        run_shell_command(f"echo '{username} | {password} | Exp: {expiry_date}' >> {LOG_SSH_USERS}")
        domain, ip = get_domain_ip()
        sldomain, slpubkey = get_slowdns_info()
        
        message = (
            f"<b>✔ Pengguna SSH berjaya dicipta!</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"👤 Nama Pengguna: <code>{html.escape(username)}</code>\n"
            f"🔑 Kata Laluan: <code>{html.escape(password)}</code>\n"
            f"🗓 Tamat Tempoh: <code>{html.escape(expiry_date)}</code>\n\n"
            f"<b>Maklumat Sambungan:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 Domain: <code>{html.escape(domain)}</code>\n"
            f"IP: <code>{html.escape(ip)}</code>\n"
            f"Port SSH: 22\n"
            f"Port Dropbear: 109, 143\n"
            f"Port Stunnel4: 444, 777\n"
            f"Port SSH WS Proxy: 8880\n"
            f"Port SlowDNS: 5300 (NS: {html.escape(sldomain)}, Key: {html.escape(slpubkey)})\n"
            f"Port UDPGW: 7100-7900\n\n"
            f"<i>Gunakan aplikasi SSH/HTTP Custom/HTTP Injector.</i>"
        )
        await update.message.reply_html(message)

async def create_ovpn(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Create OpenVPN user."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    if len(context.args) != 2:
        await update.message.reply_text("Penggunaan: /create_ovpn <username> <hari>")
        return

    username = context.args[0]
    days_str = context.args[1]

    valid_user, user_msg = validate_username(username)
    if not valid_user:
        await update.message.reply_text(f"Ralat nama pengguna: {user_msg}")
        return
    
    valid_days, days_msg = validate_days(days_str)
    if not valid_days:
        await update.message.reply_text(f"Ralat hari: {days_msg}")
        return

    # Cek apakah username sudah ada di sistem
    if run_shell_command(f"id {username} &>/dev/null; echo $?").strip() == "0":
        await update.message.reply_text(f"Ralat: Nama pengguna '{html.escape(username)}' sudah wujud.")
        return

    password = generate_password()
    expiry_date = (datetime.date.today() + datetime.timedelta(days=int(days_str))).strftime("%Y-%m-%d")

    await update.message.reply_text(f"Sedang mencipta pengguna OpenVPN '{html.escape(username)}'...")

    cmd = f"useradd -e {expiry_date} -m -s /bin/bash {username} && echo '{username}:{password}' | chpasswd"
    result = run_shell_command(cmd)

    if "Ralat" in result or "gagal" in result.lower():
        await update.message.reply_text(f"Gagal mencipta pengguna OpenVPN: {html.escape(result)}")
    else:
        run_shell_command(f"echo '{username} | {password} | Exp: {expiry_date}' >> {LOG_OVPN_USERS}")
        domain, ip = get_domain_ip()

        # Generate OVPN client configs (replicate logic from menussh.sh)
        ovpn_webdir = "/var/www/html"
        run_shell_command(f"mkdir -p {ovpn_webdir}")
        
        ca_cert = run_shell_command("cat /etc/openvpn/ca.crt 2>/dev/null")
        ta_key = run_shell_command("cat /etc/openvpn/ta.key 2>/dev/null")

        modes = {
            "udp1194": {"port": 1194, "proto": "udp"},
            "tcp1443": {"port": 1443, "proto": "tcp"},
            "udp2053": {"port": 2053, "proto": "udp"},
            "tcp8080": {"port": 8080, "proto": "tcp"},
        }

        ovpn_links = []
        for mode_name, mode_info in modes.items():
            port = mode_info["port"]
            proto = mode_info["proto"]
            config_content = f"""client
dev tun
proto {proto}
remote {domain} {port}
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
{ca_html_escaped if (ca_html_escaped := html.escape(ca_cert)) else ''}
</ca>
<tls-auth>
{ta_html_escaped if (ta_html_escaped := html.escape(ta_key)) else ''}
</tls-auth>
key-direction 1
"""
            config_file_path = f"{ovpn_webdir}/client-{username}-{mode_name}.ovpn"
            with open(config_file_path, "w") as f:
                f.write(config_content)
            ovpn_links.append(f"{mode_name.upper()}: http://{html.escape(ip)}/client-{html.escape(username)}-{mode_name}.ovpn")

        message = (
            f"<b>✔ Pengguna OpenVPN berjaya dicipta!</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"👤 Nama Pengguna: <code>{html.escape(username)}</code>\n"
            f"🔑 Kata Laluan: <code>{html.escape(password)}</code>\n"
            f"🗓 Tamat Tempoh: <code>{html.escape(expiry_date)}</code>\n\n"
            f"<b>Pautan Konfigurasi OVPN:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            + "\n".join(ovpn_links) + "\n\n"
            f"<i>Gunakan aplikasi OpenVPN Connect.</i>"
        )
        await update.message.reply_html(message)

async def create_vmess(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Create Xray VMess user."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    if len(context.args) != 2:
        await update.message.reply_text("Penggunaan: /create_vmess <username> <hari>")
        return

    username = context.args[0]
    days_str = context.args[1]

    valid_user, user_msg = validate_username(username)
    if not valid_user:
        await update.message.reply_text(f"Ralat nama pengguna: {user_msg}")
        return
    
    valid_days, days_msg = validate_days(days_str)
    if not valid_days:
        await update.message.reply_text(f"Ralat hari: {days_msg}")
        return

    # Cek apakah username sudah ada di Xray config
    xray_users_json = run_shell_command(f"jq -r '.inbounds[].settings.clients[]? | select(.email != null) | .email' {XRAY_CONFIG} 2>/dev/null")
    if username in xray_users_json.splitlines():
        await update.message.reply_text(f"Ralat: Nama pengguna '{html.escape(username)}' sudah wujud untuk Xray.")
        return

    await update.message.reply_text(f"Sedang mencipta pengguna Xray VMess '{html.escape(username)}'...")

    uuid = run_shell_command("cat /proc/sys/kernel/random/uuid")
    expiry_date = (datetime.date.today() + datetime.timedelta(days=int(days_str))).strftime("%Y-%m-%d")

    # Update Xray config
    try:
        with open(XRAY_CONFIG, 'r') as f:
            config_data = json.load(f)
        
        for inbound in config_data.get('inbounds', []):
            if inbound.get('protocol') == 'vmess' and 'clients' in inbound.get('settings', {}):
                inbound['settings']['clients'].append({"id": uuid, "alterId": 0, "email": username})
        
        with open(XRAY_CONFIG, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        run_shell_command("systemctl restart xray")
        run_shell_command(f"echo '{username} | {uuid} | vmess | Exp: {expiry_date}' >> {LOG_XRAY_USERS}")

        domain, _ = get_domain_ip()

        vmess_json_tls = {
            "v": "2", "ps": username, "add": domain, "port": "443", "id": uuid, "aid": "0",
            "net": "ws", "path": "/vmess", "type": "none", "host": "", "tls": "tls"
        }
        vmesslink1 = f"vmess://{base66_encode(json.dumps(vmess_json_tls))}"

        vmess_json_ntls = {
            "v": "2", "ps": username, "add": domain, "port": "80", "id": uuid, "aid": "0",
            "net": "ws", "path": "/vmess", "type": "none", "host": "", "tls": "none"
        }
        vmesslink2 = f"vmess://{base66_encode(json.dumps(vmess_json_ntls))}"

        vmess_json_grpc = {
            "v": "2", "ps": username, "add": domain, "port": "443", "id": uuid, "aid": "0",
            "net": "grpc", "path": "vmess-grpc", "type": "none", "host": "", "tls": "tls"
        }
        vmesslink3 = f"vmess://{base66_encode(json.dumps(vmess_json_grpc))}"

        message = (
            f"<b>✔ Pengguna Xray VMess berjaya dicipta!</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"👤 Nama Pengguna: <code>{html.escape(username)}</code>\n"
            f"🔑 UUID: <code>{html.escape(uuid)}</code>\n"
            f"🗓 Tamat Tempoh: <code>{html.escape(expiry_date)}</code>\n\n"
            f"<b>Pautan Konfigurasi:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"VMess WS TLS: <code>{html.escape(vmesslink1)}</code>\n\n"
            f"VMess WS nTLS: <code>{html.escape(vmesslink2)}</code>\n\n"
            f"VMess gRPC: <code>{html.escape(vmesslink3)}</code>\n\n"
            f"<i>Gunakan aplikasi V2RayNG, NekoBox, atau sejenisnya.</i>"
        )
        await update.message.reply_html(message)

    except Exception as e:
        await update.message.reply_text(f"Gagal mencipta pengguna Xray VMess: {html.escape(str(e))}")
        logger.error(f"Error creating VMess user: {e}")

async def create_vless(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Create Xray VLESS user."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    if len(context.args) != 2:
        await update.message.reply_text("Penggunaan: /create_vless <username> <hari>")
        return

    username = context.args[0]
    days_str = context.args[1]

    valid_user, user_msg = validate_username(username)
    if not valid_user:
        await update.message.reply_text(f"Ralat nama pengguna: {user_msg}")
        return
    
    valid_days, days_msg = validate_days(days_str)
    if not valid_days:
        await update.message.reply_text(f"Ralat hari: {days_msg}")
        return

    # Cek apakah username sudah ada di Xray config
    xray_users_json = run_shell_command(f"jq -r '.inbounds[].settings.clients[]? | select(.email != null) | .email' {XRAY_CONFIG} 2>/dev/null")
    if username in xray_users_json.splitlines():
        await update.message.reply_text(f"Ralat: Nama pengguna '{html.escape(username)}' sudah wujud untuk Xray.")
        return

    await update.message.reply_text(f"Sedang mencipta pengguna Xray VLESS '{html.escape(username)}'...")

    uuid = run_shell_command("cat /proc/sys/kernel/random/uuid")
    expiry_date = (datetime.date.today() + datetime.timedelta(days=int(days_str))).strftime("%Y-%m-%d")

    # Update Xray config
    try:
        with open(XRAY_CONFIG, 'r') as f:
            config_data = json.load(f)
        
        for inbound in config_data.get('inbounds', []):
            if inbound.get('protocol') == 'vless' and 'clients' in inbound.get('settings', {}):
                inbound['settings']['clients'].append({"id": uuid, "email": username})
        
        with open(XRAY_CONFIG, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        run_shell_command("systemctl restart xray")
        run_shell_command(f"echo '{username} | {uuid} | vless | Exp: {expiry_date}' >> {LOG_XRAY_USERS}")

        domain, _ = get_domain_ip()

        vlesslink1 = f"vless://{uuid}@{domain}:443?path=/vless&security=tls&encryption=none&type=ws#{username}"
        vlesslink2 = f"vless://{uuid}@{domain}:80?path=/vless&encryption=none&type=ws#{username}"
        vlesslink3 = f"vless://{uuid}@{domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni={domain}#{username}"

        message = (
            f"<b>✔ Pengguna Xray VLESS berjaya dicipta!</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"👤 Nama Pengguna: <code>{html.escape(username)}</code>\n"
            f"🔑 UUID: <code>{html.escape(uuid)}</code>\n"
            f"🗓 Tamat Tempoh: <code>{html.escape(expiry_date)}</code>\n\n"
            f"<b>Pautan Konfigurasi:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"VLESS WS TLS: <code>{html.escape(vlesslink1)}</code>\n\n"
            f"VLESS WS nTLS: <code>{html.escape(vlesslink2)}</code>\n\n"
            f"VLESS gRPC: <code>{html.escape(vlesslink3)}</code>\n\n"
            f"<i>Gunakan aplikasi V2RayNG, NekoBox, atau sejenisnya.</i>"
        )
        await update.message.reply_html(message)

    except Exception as e:
        await update.message.reply_text(f"Gagal mencipta pengguna Xray VLESS: {html.escape(str(e))}")
        logger.error(f"Error creating VLESS user: {e}")

async def create_hysteria(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Create Hysteria2 user."""
    if str(update.effective_user.id) != ADMIN_ID:
        await update.message.reply_text("Anda tidak dibenarkan menggunakan bot ini.")
        return

    if len(context.args) != 2:
        await update.message.reply_text("Penggunaan: /create_hysteria <username> <hari>")
        return

    username = context.args[0]
    days_str = context.args[1]

    valid_user, user_msg = validate_username(username)
    if not valid_user:
        await update.message.reply_text(f"Ralat nama pengguna: {user_msg}")
        return
    
    valid_days, days_msg = validate_days(days_str)
    if not valid_days:
        await update.message.reply_text(f"Ralat hari: {days_msg}")
        return

    # Cek apakah username sudah ada di log Hysteria
    if run_shell_command(f"grep -q '^{username}|' {LOG_HYSTERIA_USERS} 2>/dev/null; echo $?").strip() == "0":
        await update.message.reply_text(f"Ralat: Nama pengguna '{html.escape(username)}' sudah wujud untuk Hysteria2.")
        return

    await update.message.reply_text(f"Sedang mencipta pengguna Hysteria2 '{html.escape(username)}'...")

    password = generate_password()
    expiry_date = (datetime.date.today() + datetime.timedelta(days=int(days_str))).strftime("%Y-%m-%d")
    bandwidth = "unlimited" # Bot tidak meminta bandwidth, set default unlimited

    try:
        # Update Hysteria config (single password approach)
        # Note: This will change the password for ALL Hysteria2 users if using single password mode.
        # If you want per-user passwords, Hysteria2 config needs to be adjusted to use 'users' array.
        # For now, we assume single password as per your install.sh
        run_shell_command(f"sed -i 's/password: .*/password: \"{password}\"/' {HYSTERIA_CONFIG}")
        
        run_shell_command(f"echo '{username} | {password} | {bandwidth} | Exp: {expiry_date}' >> {LOG_HYSTERIA_USERS}")
        run_shell_command("systemctl restart hysteria2")

        domain, ip = get_domain_ip()
        
        # Generate client config file
        config_file_path = f"/var/www/html/hysteria-{username}.yaml"
        config_content = f"""server: {domain}:8443
auth: {password}

bandwidth:
  up: 100 mbps
  down: 100 mbps

tls:
  sni: {domain}
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
"""
        with open(config_file_path, "w") as f:
            f.write(config_content)
        run_shell_command(f"chmod 644 {config_file_path}")

        message = (
            f"<b>✔ Pengguna Hysteria2 berjaya dicipta!</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"👤 Nama Pengguna: <code>{html.escape(username)}</code>\n"
            f"🔑 Kata Laluan: <code>{html.escape(password)}</code>\n"
            f"🗓 Tamat Tempoh: <code>{html.escape(expiry_date)}</code>\n"
            f"📊 Bandwidth: {html.escape(bandwidth)}\n\n"
            f"<b>Maklumat Sambungan:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"🌐 Server: <code>{html.escape(domain)}:8443</code>\n"
            f"Protokol: Hysteria2\n"
            f"TLS SNI: <code>{html.escape(domain)}</code>\n"
            f"Obfuscation: Salamander\n\n"
            f"<b>Pautan Konfigurasi:</b>\n"
            f"━━━━━━━━━━━━━━━━━━━━\n"
            f"YAML Config: http://{html.escape(ip)}/hysteria-{html.escape(username)}.yaml\n\n"
            f"<i>Gunakan aplikasi Hysteria2 Client.</i>"
        )
        await update.message.reply_html(message)

    except Exception as e:
        await update.message.reply_text(f"Gagal mencipta pengguna Hysteria2: {html.escape(str(e))}")
        logger.error(f"Error creating Hysteria2 user: {e}")

# Fungsi untuk encode base64 (untuk VMess)
def base66_encode(text):
    return run_shell_command(f"echo -n '{text}' | base64 -w 0")

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Echo the user message."""
    if str(update.effective_user.id) != ADMIN_ID:
        return
    await update.message.reply_text(f"Maaf, saya tidak faham arahan anda. Sila gunakan /help untuk senarai arahan.")

def main() -> None:
    """Start the bot."""
    if not TOKEN or not ADMIN_ID:
        logger.error("TELEGRAM_BOT_TOKEN atau TELEGRAM_ADMIN_ID tidak ditetapkan. Bot tidak dapat dimulai.")
        print("TELEGRAM_BOT_TOKEN atau TELEGRAM_ADMIN_ID tidak ditetapkan. Bot tidak dapat dimulai.")
        return

    application = Application.builder().token(TOKEN).build()

    # Command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_command))
    application.add_handler(CommandHandler("info", info_command))
    application.add_handler(CommandHandler("status", status_command))
    application.add_handler(CommandHandler("create_ssh", create_ssh))
    application.add_handler(CommandHandler("create_ovpn", create_ovpn))
    application.add_handler(CommandHandler("create_vmess", create_vmess))
    application.add_handler(CommandHandler("create_vless", create_vless))
    application.add_handler(CommandHandler("create_hysteria", create_hysteria))

    # Message handler for all other messages
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))

    # Run the bot until the user presses Ctrl-C
    logger.info("Bot sedang berjalan...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
