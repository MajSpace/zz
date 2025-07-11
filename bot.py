#!/usr/bin/env python3
# Telegram Bot: MajSpace VPN (Melayu, Interaktif + Tombol Hari & Konfirmasi + Menu Menarik)
# Untuk python-telegram-bot==13.15 dan server Ubuntu dengan script MajSpace
# Jalankan dengan: python3 bot_vpn_melayu_interaktif_btn.py

import logging
import subprocess
import os
import re
from functools import wraps
from telegram import (
    ParseMode, ReplyKeyboardMarkup, ReplyKeyboardRemove, KeyboardButton
)
from telegram.ext import (
    Updater, CommandHandler, ConversationHandler, MessageHandler, Filters
)
import configparser   # <--- Tambahkan ini

def load_bot_config():
    config = configparser.ConfigParser()
    config.read('/etc/menubot.conf')
    token = config.get('DEFAULT', 'TELEGRAM_BOT_TOKEN', fallback='')
    ids = config.get('DEFAULT', 'ALLOWED_CHAT_IDS', fallback='').split(',')
    ids = [int(i.strip()) for i in ids if i.strip().isdigit()]
    return token, ids

# Gantikan variabel manual dengan ini:
TELEGRAM_BOT_TOKEN, ALLOWED_CHAT_IDS = load_bot_config()
# ===================== KONFIGURASI =====================
SUDO_CMD = ""  # Gunakan '' jika bot dijalankan sebagai root
# =======================================================

logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO
)
logger = logging.getLogger(__name__)

(PILIH_PROTOCOL, MASUKKAN_USERNAME, MASUKKAN_PASSWORD, MASUKKAN_HARI, SAHKAN_CIPTA,
    PILIH_PADAM_PROTOCOL, PILIH_PADAM_USER, SAHKAN_PADAM_USER) = range(8)

protocols = [
    ("SSH", "ssh"),
    ("OpenVPN", "openvpn"),
    ("Xray VMess", "vmess"),
    ("Xray VLESS", "vless"),
    ("Hysteria2", "hysteria2"),
]
protocol_dict = {v: k for k, v in protocols}

def restricted(func):
    @wraps(func)
    def wrapped(update, context, *args, **kwargs):
        user_id = update.effective_chat.id
        if ALLOWED_CHAT_IDS and user_id not in ALLOWED_CHAT_IDS:
            update.message.reply_text("⛔️ Akses ditolak. Sila hubungi admin.")
            return
        return func(update, context, *args, **kwargs)
    return wrapped

def run_bash(command):
    try:
        output = subprocess.check_output(
            command, shell=True, stderr=subprocess.STDOUT, universal_newlines=True, timeout=30
        )
        return output
    except subprocess.CalledProcessError as e:
        return e.output

def is_valid_username(username):
    return bool(re.match(r'^[a-zA-Z0-9_-]{2,32}$', username))

def is_valid_days(days):
    return days.isdigit() and 1 <= int(days) <= 365

# =============== Start/Menu/Bantuan ================
@restricted
def start(update, context):
    menu(update, context)

@restricted
def menu(update, context):
    msg = (
        "══════════════\n"
        "   👑 *Sistem Pengurusan VPN MajSpace* 👑\n"
        "══════════════\n"
        "• /buatuser - 🛡️ Cipta akaun VPN baru\n"
        "• /padamuser - 🗑️ Padam akaun user\n"
        "• /senarai  - 👥 Senarai pengguna aktif\n"
        "• /status   - 🏢 Status perkhidmatan server\n"
        "• /bantuan  - 📖 Manual penggunaan bot\n"
        "══════════════\n"
        "\n*Selamat datang! Sila pilih arahan di atas untuk bermula.*"
    )
    update.message.reply_text(
        msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove()
    )

@restricted
def bantuan(update, context):
    msg = (
        "📖 *Manual Bot MajSpace:*\n"
        "• /buatuser — Cipta akaun VPN (semua protokol)\n"
        "• /padamuser — Padam akaun user (dengan konfirmasi)\n"
        "• /senarai — Lihat semua pengguna aktif\n"
        "• /status — Status perkhidmatan server\n"
    )
    update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

# =============== Flow Cipta User Interaktif ================
@restricted
def buatuser(update, context):
    reply_keyboard = [[k] for k, v in protocols]
    update.message.reply_text(
        "🛡️ *Sila pilih protokol akaun yang ingin dicipta:*\n"
        "━━━━━━━━━━━━━━━\n"
        " SSH, OpenVPN, VMess, VLESS, Hysteria2 \n"
        "━━━━━━━━━━━━━━━",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return PILIH_PROTOCOL

def pilih_protocol(update, context):
    pilihan = update.message.text.strip()
    proto = None
    for name, value in protocols:
        if pilihan.lower() == name.lower():
            proto = value
            break
    if not proto:
        update.message.reply_text("⛔️ Pilihan tidak sah. Sila pilih menggunakan butang yang tersedia.")
        return PILIH_PROTOCOL
    context.user_data['protocol'] = proto
    update.message.reply_text("✍️ Masukkan nama pengguna (2-32 huruf):", reply_markup=ReplyKeyboardRemove())
    return MASUKKAN_USERNAME

def masukkan_username(update, context):
    username = update.message.text.strip()
    if not is_valid_username(username):
        update.message.reply_text("⛔️ Nama pengguna tidak sah. Gunakan (2-32 huruf).")
        return MASUKKAN_USERNAME

    proto = context.user_data['protocol']

    # --- Validasi user sudah ada ---
    user_exists = False
    if proto == 'ssh':
        # Cek di /etc/passwd
        userlist = run_bash("awk -F: '($3>=1000)&&($7==\"/bin/bash\"){print $1}' /etc/passwd").split('\n')
        user_exists = username in [u.strip() for u in userlist if u.strip()]
    elif proto == 'openvpn':
        # Cek di log openvpn
        userlist = run_bash("awk -F'|' '{print $1}' /var/log/ovpn-users.log 2>/dev/null").split('\n')
        user_exists = username in [u.strip() for u in userlist if u.strip()]
    elif proto in ('vmess', 'vless'):
        json_path = '/usr/local/etc/xray/config.json' if os.path.exists('/usr/local/etc/xray/config.json') else '/etc/xray/config.json'
        userlist = run_bash(f"jq -r '.inbounds[] | select(.protocol==\"{proto}\") | .settings.clients[]?.email' {json_path} 2>/dev/null").split('\n')
        user_exists = username in [u.strip() for u in userlist if u.strip()]
    elif proto == 'hysteria2':
        userlist = run_bash("awk -F'|' '{print $1}' /var/log/hysteria-users.log 2>/dev/null").split('\n')
        user_exists = username in [u.strip() for u in userlist if u.strip()]

    if user_exists:
        update.message.reply_text(f"⛔️ Nama pengguna `{username}` sudah wujud untuk protokol {protocol_dict[proto]}. Sila masukkan nama lain.", parse_mode=ParseMode.MARKDOWN)
        return MASUKKAN_USERNAME
    # --- End validasi ---

    context.user_data['username'] = username
    if proto in ('ssh', 'openvpn', 'hysteria2'):
        update.message.reply_text("🔒 Masukkan kata laluan :")
        return MASUKKAN_PASSWORD
    else:
        context.user_data['password'] = '-'
        return tanya_hari(update, context)

def masukkan_password(update, context):
    passwd = update.message.text.strip()
    if passwd == '-' or len(passwd) >= 2:
        context.user_data['password'] = passwd
        return tanya_hari(update, context)
    else:
        update.message.reply_text("⛔️ Kata laluan minimum 2 huruf.")
        return MASUKKAN_PASSWORD

def tanya_hari(update, context):
    reply_keyboard = [[KeyboardButton("30 hari")], [KeyboardButton("60 hari")]]
    update.message.reply_text(
        "🗓️ Tempoh akaun aktif? (hari, 1-365):\n\n"
        "Sila pilih salah satu atau taip sendiri bilangan hari.",
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return MASUKKAN_HARI

def masukkan_hari(update, context):
    days = update.message.text.strip()
    if days.lower() == "30 hari":
        days = "30"
    elif days.lower() == "60 hari":
        days = "60"
    if not is_valid_days(days):
        update.message.reply_text("⛔️ Sila masukkan bilangan hari (1-365) atau pilih dari butang.")
        return MASUKKAN_HARI
    context.user_data['days'] = days

    proto = context.user_data['protocol']
    username = context.user_data['username']
    password = context.user_data['password']
    days = context.user_data['days']

    reply_keyboard = [["✅ YA", "❌ BATAL"]]
    msg = (
        f"💾 *Sila Sahkan Maklumat Akaun:*\n"
        f"┏━━━━━━━━━━\n"
        f"┣ Protokol : {protocol_dict[proto]}\n"
        f"┣ Nama Pengguna : `{username}`\n"
        f"┣ Kata Laluan : {'(Rawak)' if password == '-' else password}\n"
        f"┣ Tempoh Aktif : {days} hari\n"
        f"┗━━━━━━━━━━\n\n"
        "Tekan *YA* untuk cipta, *BATAL* untuk batal."
    )
    update.message.reply_text(
        msg, parse_mode=ParseMode.MARKDOWN,
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return SAHKAN_CIPTA

def sahkan_cipta(update, context):
    answer = update.message.text.strip().lower()
    if answer in ('❌ batal', 'batal', 'tidak', 'no'):
        update.message.reply_text("❌ Proses dibatalkan.", reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END
    if answer not in ('✅ ya', 'ya', 'y', 'yes'):
        update.message.reply_text("⛔️ Sila tekan YA untuk cipta atau BATAL untuk batal.")
        return SAHKAN_CIPTA

    proto = context.user_data['protocol']
    username = context.user_data['username']
    password = context.user_data['password']
    days = context.user_data['days']

    IP = run_bash("curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}'").strip()
    DOMAIN = run_bash("cat /etc/xray/domain.conf 2>/dev/null").strip()

    # SSH
    if proto == 'ssh':
        passwd_arg = password if password != '-' else run_bash('openssl rand -base64 12 | tr -d "=+/" | cut -c1-12').strip()
        exp_date = run_bash(f'date -d "{days} days" +"%Y-%m-%d"').strip()
        cmd = f'{SUDO_CMD} useradd -e $(date -d "{days} days" +"%Y-%m-%d") -m -s /bin/bash {username} && echo "{username}:{passwd_arg}" | {SUDO_CMD} chpasswd'
        run_bash(cmd)
        msg = (
            "✅ *Pengguna SSH berjaya dicipta!*\n"
            "━━━━━━━━━━━━━━━\n"
            f"👤 *Nama Pengguna:* `{username}`\n"
            f"🔑 *Kata Laluan:* `{passwd_arg}`\n"
            f"⏳ *Tamat Tempoh:* `{exp_date}`\n"
            "━━━━━━━━━━━━━━━\n"
            f"🌐 *Alamat IP:* `{IP}`\n"
            f"🌍 *Domain:* `{DOMAIN}`\n"
            f"🔒 *SSL/TLS:* `444, 777`\n"
            f"🟢 *UDPGW:* `7100-7900`\n"
            f"🟣 *SSH WS PROXY:* `8880`\n"
            "\nContoh payload SSH WS:\n"
            f"`GET /cdn-cgi/trace HTTP/1.1[crlf]Host: [host][crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: Websocket[crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]`\n"
        )
        update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END

    # OpenVPN
    elif proto == 'openvpn':
        passwd_arg = password if password != '-' else run_bash('openssl rand -base64 12 | tr -d "=+/" | cut -c1-12').strip()
        exp_date = run_bash(f'date -d "{days} days" +"%Y-%m-%d"').strip()
        cmd = f'{SUDO_CMD} useradd -e $(date -d "{days} days" +"%Y-%m-%d") -m -s /bin/bash {username} && echo "{username}:{passwd_arg}" | {SUDO_CMD} chpasswd'
        run_bash(cmd)
        run_bash(f'echo "{username} | {passwd_arg} | Exp: {exp_date}" >> /var/log/ovpn-users.log')
        config_urls = []
        for mode, port, proto_str in [
            ('udp1194', 1194, 'udp'),
            ('tcp1443', 1443, 'tcp'),
            ('udp2053', 2053, 'udp'),
            ('tcp8080', 8080, 'tcp')
        ]:
            ovpn_dir = '/var/www/html'
            ca = run_bash("cat /etc/openvpn/ca.crt 2>/dev/null")
            ta = run_bash("cat /etc/openvpn/ta.key 2>/dev/null")
            cfg_path = f"{ovpn_dir}/client-{username}-{mode}.ovpn"
            with open(cfg_path, "w") as f:
                f.write(f"""client
dev tun
proto {proto_str}
remote {DOMAIN} {port}
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
{ca}</ca>
<tls-auth>
{ta}</tls-auth>
key-direction 1
""")
            config_urls.append(f"http://{IP}/client-{username}-{mode}.ovpn")
        msg = (
            "✅ *Pengguna OpenVPN berjaya dicipta!*\n"
            "━━━━━━━━━━━━━━━\n"
            f"👤 *Nama Pengguna:* `{username}`\n"
            f"🔑 *Kata Laluan:* `{passwd_arg}`\n"
            f"⏳ *Tamat Tempoh:* `{exp_date}`\n"
            "━━━━━━━━━━━━━━━\n"
            f"🌐 *Alamat IP:* `{IP}`\n"
            f"🌍 *Domain:* `{DOMAIN}`\n"
            "\n*Link config OVPN:*\n"
        )
        for url in config_urls:
            msg += f"- `{url}`\n"
        update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END

    # VMess & VLESS
    elif proto in ('vmess', 'vless'):
        uuid = run_bash('cat /proc/sys/kernel/random/uuid').strip()
        exp_date = run_bash(f'date -d "{days} days" +"%Y-%m-%d"').strip()
        json_path = '/usr/local/etc/xray/config.json' if os.path.exists('/usr/local/etc/xray/config.json') else '/etc/xray/config.json'
        if proto == 'vmess':
            jq_cmd = f'''jq --arg uuid "{uuid}" --arg user "{username}" '.inbounds |= map(if .protocol == "vmess" then .settings.clients += [{{"id":$uuid,"alterId":0,"email":$user}}] else . end)' {json_path} > /tmp/xray_config.json && mv /tmp/xray_config.json {json_path}'''
        else:
            jq_cmd = f'''jq --arg uuid "{uuid}" --arg user "{username}" '.inbounds |= map(if .protocol == "vless" then .settings.clients += [{{"id":$uuid,"email":$user}}] else . end)' {json_path} > /tmp/xray_config.json && mv /tmp/xray_config.json {json_path}'''
        run_bash(f"{SUDO_CMD} {jq_cmd}")
        run_bash(f"{SUDO_CMD} systemctl restart xray")
        if proto == 'vmess':
            vmess_json_tls = f"""{{
  "v": "2",
  "ps": "{username}",
  "add": "{DOMAIN}",
  "port": "443",
  "id": "{uuid}",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "",
  "tls": "tls"
}}"""
            vmess_tls = "vmess://" + run_bash(f"echo -n '{vmess_json_tls}' | base64 -w 0").strip()

            vmess_json_ntls = f"""{{
  "v": "2",
  "ps": "{username}",
  "add": "{DOMAIN}",
  "port": "80",
  "id": "{uuid}",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "",
  "tls": "none"
}}"""
            vmess_ntls = "vmess://" + run_bash(f"echo -n '{vmess_json_ntls}' | base64 -w 0").strip()

            vmess_json_grpc = f"""{{
  "v": "2",
  "ps": "{username}",
  "add": "{DOMAIN}",
  "port": "443",
  "id": "{uuid}",
  "aid": "0",
  "net": "grpc",
  "path": "vmess-grpc",
  "type": "none",
  "host": "",
  "tls": "tls"
}}"""
            vmess_grpc = "vmess://" + run_bash(f"echo -n '{vmess_json_grpc}' | base64 -w 0").strip()

            msg = (
                "✅ *Akaun VMess berjaya dicipta!*\n"
                "━━━━━━━━━━━━━━━\n"
                f"👤 *Nama Pengguna:* `{username}`\n"
                f"🆔 *UUID:* `{uuid}`\n"
                f"⏳ *Tamat Tempoh:* `{exp_date}`\n"
                "━━━━━━━━━━━━━━━\n"
                f"🌍 *Domain:* `{DOMAIN}`\n"
                f"🌐 *IP:* `{IP}`\n"
                "━━━━━━━━━━━━━━━\n"
                "*Link VMess:*\n"
                f"• TLS (443 WS):\n`{vmess_tls}`\n"
                f"• nTLS (80 WS):\n`{vmess_ntls}`\n"
                f"• gRPC (443):\n`{vmess_grpc}`\n"
            )
            update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
            return ConversationHandler.END

        else:
            vless_tls = f"vless://{uuid}@{DOMAIN}:443?path=/vless&security=tls&encryption=none&type=ws#{username}"
            vless_ntls = f"vless://{uuid}@{DOMAIN}:80?path=/vless&encryption=none&type=ws#{username}"
            vless_grpc = f"vless://{uuid}@{DOMAIN}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni={DOMAIN}#{username}"
            msg = (
                "✅ *Akaun VLESS berjaya dicipta!*\n"
                "━━━━━━━━━━━━━━━\n"
                f"👤 *Nama Pengguna:* `{username}`\n"
                f"🆔 *UUID:* `{uuid}`\n"
                f"⏳ *Tamat Tempoh:* `{exp_date}`\n"
                "━━━━━━━━━━━━━━━\n"
                f"🌍 *Domain:* `{DOMAIN}`\n"
                f"🌐 *IP:* `{IP}`\n"
                "━━━━━━━━━━━━━━━\n"
                "*Link VLESS:*\n"
                f"• TLS (443 WS):\n`{vless_tls}`\n"
                f"• nTLS (80 WS):\n`{vless_ntls}`\n"
                f"• gRPC (443):\n`{vless_grpc}`\n"
            )
            update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
            return ConversationHandler.END

    # Hysteria2
    elif proto == 'hysteria2':
        passwd_arg = password if password != '-' else run_bash('openssl rand -base64 12 | tr -d "=+/" | cut -c1-12').strip()
        exp_date = run_bash(f'date -d "{days} days" +"%Y-%m-%d"').strip()
        hyst_conf = '/etc/hysteria/hysteria2.yaml'
        run_bash(f'''{SUDO_CMD} sed -i 's/password: .*/password: "{passwd_arg}"/' {hyst_conf}''')
        run_bash(f'''echo "{username} | {passwd_arg} | unlimited | Exp: {exp_date}" | {SUDO_CMD} tee -a /var/log/hysteria-users.log''')
        run_bash(f"{SUDO_CMD} systemctl restart hysteria2")
        link = f"hysteria2://{username}:{passwd_arg}@{DOMAIN}:8443"
        msg = (
            "✅ *Akaun Hysteria2 berjaya dicipta!*\n"
            "━━━━━━━━━━━━━━━\n"
            f"👤 *Nama Pengguna:* `{username}`\n"
            f"🔑 *Kata Laluan:* `{passwd_arg}`\n"
            f"⏳ *Tamat Tempoh:* `{exp_date}`\n"
            "━━━━━━━━━━━━━━━\n"
            f"🌍 *Domain:* `{DOMAIN}`\n"
            f"🌐 *IP:* `{IP}`\n"
            "━━━━━━━━━━━━━━━\n"
            f"*Link Hysteria2:*\n`{link}`\n"
        )
        update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END

    else:
        update.message.reply_text("⛔️ Protokol tidak dikenali.", reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END

# =============== PADAM USER via BOT ================
@restricted
def padamuser(update, context):
    reply_keyboard = [[k] for k, v in protocols]
    update.message.reply_text(
        "🗑️ *Padam User* ─ Sila pilih protokol user:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return PILIH_PADAM_PROTOCOL

def pilih_padam_protocol(update, context):
    pilihan = update.message.text.strip()
    proto = None
    proto_label = None
    for name, value in protocols:
        if pilihan.lower() == name.lower():
            proto = value
            proto_label = name
            break
    if not proto:
        update.message.reply_text("⛔️ Pilihan tidak sah. Sila pilih menggunakan butang yang tersedia.")
        return PILIH_PADAM_PROTOCOL
    context.user_data['padam_proto'] = proto
    context.user_data['padam_proto_label'] = proto_label

    # Dapatkan senarai user mengikut protokol
    if proto == 'ssh':
        userlist = run_bash("awk -F: '($3>=1000)&&($7==\"/bin/bash\"){print $1}' /etc/passwd").strip().split('\n')
    elif proto == 'openvpn':
        userlist = run_bash("awk -F'|' '{print $1}' /var/log/ovpn-users.log 2>/dev/null").strip().split('\n')
    elif proto in ('vmess', 'vless'):
        json_path = '/usr/local/etc/xray/config.json' if os.path.exists('/usr/local/etc/xray/config.json') else '/etc/xray/config.json'
        userlist = run_bash(f"jq -r '.inbounds[] | select(.protocol==\"{proto}\") | .settings.clients[]?.email' {json_path}").strip().split('\n')
    elif proto == 'hysteria2':
        userlist = run_bash("awk -F'|' '{print $1}' /var/log/hysteria-users.log 2>/dev/null").strip().split('\n')
    else:
        userlist = []

    userlist = [u.strip() for u in userlist if u.strip()]
    if not userlist:
        update.message.reply_text(f"Tiada user {proto_label} untuk dipadam.", reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END

    context.user_data['padam_userlist'] = userlist
    reply_keyboard = [[u] for u in userlist]
    update.message.reply_text(
        f"Pilih user {proto_label} untuk dipadam:",
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return PILIH_PADAM_USER

def pilih_padam_user(update, context):
    user = update.message.text.strip()
    userlist = context.user_data.get('padam_userlist', [])
    if user not in userlist:
        update.message.reply_text("⛔️ Pilihan user tidak sah. Sila pilih dari senarai.")
        return PILIH_PADAM_USER
    context.user_data['padam_user'] = user

    reply_keyboard = [["✅ YA", "❌ BATAL"]]
    update.message.reply_text(
        f"Anda pasti mahu padam user `{user}` ({context.user_data['padam_proto_label']})?\n"
        "Tindakan ini tidak boleh dikembalikan.",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=ReplyKeyboardMarkup(reply_keyboard, one_time_keyboard=True, resize_keyboard=True)
    )
    return SAHKAN_PADAM_USER

def sahkan_padam_user(update, context):
    answer = update.message.text.strip().lower()
    if answer in ('❌ batal', 'batal', 'tidak', 'no'):
        update.message.reply_text("❌ Proses padam dibatalkan.", reply_markup=ReplyKeyboardRemove())
        return ConversationHandler.END
    if answer not in ('✅ ya', 'ya', 'y', 'yes'):
        update.message.reply_text("⛔️ Sila tekan YA untuk padam atau BATAL untuk batal.")
        return SAHKAN_PADAM_USER

    proto = context.user_data['padam_proto']
    user = context.user_data['padam_user']
    msg = ""

    if proto == 'ssh' or proto == 'openvpn':
        run_bash(f"userdel -r {user}")
        if proto == 'openvpn':
            run_bash(f"sed -i '/^{user} |/d' /var/log/ovpn-users.log")
        if proto == 'ssh':
            run_bash(f"sed -i '/^{user} |/d' /var/log/ssh-users.log")
        msg = f"✅ User `{user}` ({proto.upper()}) berjaya dipadam."
    elif proto in ('vmess', 'vless'):
        json_path = '/usr/local/etc/xray/config.json' if os.path.exists('/usr/local/etc/xray/config.json') else '/etc/xray/config.json'
        proto_filter = proto
        run_bash(
            f"jq '(.inbounds[] | select(.protocol==\"{proto_filter}\") | .settings.clients) |= map(select(.email!=\"{user}\"))' {json_path} > /tmp/xray_config.json && mv /tmp/xray_config.json {json_path}"
        )
        run_bash("systemctl restart xray")
        run_bash(f"sed -i '/^{user} |/d' /var/log/xray-users.log")
        msg = f"✅ User `{user}` ({proto.upper()}) berjaya dipadam."
    elif proto == 'hysteria2':
        run_bash(f"sed -i '/^{user} |/d' /var/log/hysteria-users.log")
        run_bash(f"rm -f /var/www/html/hysteria-{user}.yaml")
        run_bash("systemctl restart hysteria2")
        msg = f"✅ User `{user}` (Hysteria2) berjaya dipadam."
    else:
        msg = "⛔️ Protokol tidak dikenali."

    update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN, reply_markup=ReplyKeyboardRemove())
    return ConversationHandler.END

@restricted
def senarai(update, context):
    msg = (
        "👥 *Senarai Pengguna Aktif:*\n"
        "━━━━━━━━━━━━━━━\n"
    )
    ssh_users = run_bash("awk -F: '($3>=1000)&&($7==\"/bin/bash\"){print $1}' /etc/passwd")
    msg += f"*SSH:*\n{ssh_users or 'Tiada'}"
    ovpn = run_bash("awk -F'|' '{print $1}' /var/log/ovpn-users.log 2>/dev/null")
    msg += f"\n\n*OpenVPN:*\n{ovpn or 'Tiada'}"
    xray = run_bash("jq -r '.inbounds[].settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null | sort | uniq")
    msg += f"\n\n*Xray (VMess/VLESS):*\n{xray or 'Tiada'}"
    hy2 = run_bash("awk -F'|' '{print $1}' /var/log/hysteria-users.log 2>/dev/null")
    msg += f"\n\n*Hysteria2:*\n{hy2 or 'Tiada'}"
    update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

@restricted
def status(update, context):
    nama = {
        "nginx": "Nginx Web Server",
        "xray": "Xray-core",
        "dropbear": "Dropbear SSH",
        "stunnel4": "Stunnel4",
        "badvpn-udpgw": "BadVPN UDPGW",
        "ssh": "OpenSSH",
        "hysteria2": "Hysteria2",
        "openvpn@server-udp-1194": "OpenVPN UDP 1194",
        "openvpn@server-tcp-443": "OpenVPN TCP 1443",
        "openvpn@server-udp-53": "OpenVPN UDP 2053",
        "openvpn@server-tcp-80": "OpenVPN TCP 8080",
    }
    cmd = "systemctl is-active " + " ".join(nama.keys())
    out = run_bash(cmd)
    msg = (
        "🏢 *Status Perkhidmatan:*\n"
        "━━━━━━━━━━━━━━━\n"
    )
    lines = out.strip().split('\n')
    for idx, svc in enumerate(nama.keys()):
        status = lines[idx] if idx < len(lines) else "unknown"
        status_emoji = "✅" if status == "active" else "❌"
        msg += f"{status_emoji} {nama[svc]}: {status}\n"
    update.message.reply_text(msg, parse_mode=ParseMode.MARKDOWN)

def batal(update, context):
    update.message.reply_text("❌ Proses dibatalkan.", reply_markup=ReplyKeyboardRemove())
    return ConversationHandler.END

def error(update, context):
    logger.warning('Update "%s" caused error "%s"', update, context.error)

def main():
    updater = Updater(TELEGRAM_BOT_TOKEN, use_context=True)
    dp = updater.dispatcher

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler('buatuser', buatuser)],
        states={
            PILIH_PROTOCOL: [MessageHandler(Filters.text & ~Filters.command, pilih_protocol)],
            MASUKKAN_USERNAME: [MessageHandler(Filters.text & ~Filters.command, masukkan_username)],
            MASUKKAN_PASSWORD: [MessageHandler(Filters.text & ~Filters.command, masukkan_password)],
            MASUKKAN_HARI: [MessageHandler(Filters.text & ~Filters.command, masukkan_hari)],
            SAHKAN_CIPTA: [MessageHandler(Filters.text & ~Filters.command, sahkan_cipta)],
        },
        fallbacks=[CommandHandler('batal', batal)],
    )

    conv_handler_padam = ConversationHandler(
        entry_points=[CommandHandler('padamuser', padamuser)],
        states={
            PILIH_PADAM_PROTOCOL: [MessageHandler(Filters.text & ~Filters.command, pilih_padam_protocol)],
            PILIH_PADAM_USER: [MessageHandler(Filters.text & ~Filters.command, pilih_padam_user)],
            SAHKAN_PADAM_USER: [MessageHandler(Filters.text & ~Filters.command, sahkan_padam_user)],
        },
        fallbacks=[CommandHandler('batal', batal)],
    )

    dp.add_handler(CommandHandler('start', start))
    dp.add_handler(CommandHandler('menu', menu))
    dp.add_handler(CommandHandler('bantuan', bantuan))
    dp.add_handler(CommandHandler('senarai', senarai))
    dp.add_handler(CommandHandler('status', status))
    dp.add_handler(conv_handler)
    dp.add_handler(conv_handler_padam)
    dp.add_error_handler(error)

    print("Bot VPN MajSpace (Melayu, Interaktif & Padam User) sedang berjalan...")
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()