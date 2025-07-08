import os
import subprocess
from telegram import (
    Update,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
    ReplyKeyboardRemove,
)
from telegram.ext import (
    ApplicationBuilder,
    CommandHandler,
    ContextTypes,
    CallbackQueryHandler,
    ConversationHandler,
    MessageHandler,
    filters,
)

# Path config bot
CONFIG_PATH = "/etc/backup.conf"

def load_bot_config():
    data = {}
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    data[k.strip()] = v.strip().replace('"', "")
    return data

def is_admin(chat_id):
    config = load_bot_config()
    return str(chat_id) == config.get("TELEGRAM_CHAT_ID", "")

# State
SELECT_PROTOCOL, INPUT_USERNAME, INPUT_PASSWORD, INPUT_DAYS = range(4)
PROTOCOLS = [
    ("SSH", "ssh"),
    ("OpenVPN", "ovpn"),
    ("VMess", "vmess"),
    ("VLESS", "vless"),
    ("Hysteria2", "hysteria2"),
]

# Start command
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    text = (
        f"👋 Hai {user.first_name or 'Pengguna'}!\n\n"
        "Selamat datang ke *Bot Pengurusan VPN (MajSpace)*\n"
        "Sila pilih menu di bawah untuk mula mencipta akaun:\n\n"
        "Tekan butang di bawah ⬇️"
    )
    keyboard = [
        [InlineKeyboardButton("➕ Cipta Akaun VPN", callback_data="create_acc")],
        [InlineKeyboardButton("ℹ️ Bantuan", callback_data="help")],
    ]
    await update.message.reply_text(
        text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode="Markdown"
    )

# Help command
async def help_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = (
        "📌 *Bantuan Bot VPN*\n"
        "- Bot ini membolehkan anda mencipta akaun VPN untuk semua protokol yang disokong MajSpace script.\n"
        "- Hanya admin yang didaftarkan boleh cipta akaun.\n"
        "- Pilih protokol, masukkan nama pengguna, kata laluan (atau auto), dan tempoh sah akaun.\n"
        "- Bot akan hantar config dan maklumat akaun secara automatik.\n"
        "—\n"
        "⚠️ Untuk set admin & token, sila guna menu Pengurusan Bot Telegram di server."
    )
    if update.callback_query:
        await update.callback_query.edit_message_text(text, parse_mode="Markdown")
    else:
        await update.message.reply_text(text, parse_mode="Markdown")

# Main menu button handler
async def menu_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if query.data == "create_acc":
        # Check admin
        if not is_admin(query.from_user.id):
            await query.edit_message_text("❌ Anda bukan admin yang berdaftar!")
            return ConversationHandler.END
        # Show protocol menu
        keyboard = [
            [InlineKeyboardButton(p[0], callback_data=f"protocol_{p[1]}")] for p in PROTOCOLS
        ]
        keyboard.append([InlineKeyboardButton("❌ Batal", callback_data="cancel")])
        await query.edit_message_text(
            "Sila pilih protokol akaun yang ingin dicipta:", reply_markup=InlineKeyboardMarkup(keyboard)
        )
        return SELECT_PROTOCOL
    elif query.data == "help":
        await help_menu(update, context)
        return ConversationHandler.END
    elif query.data == "cancel":
        await query.edit_message_text("Dibatalkan.")
        return ConversationHandler.END
    elif query.data.startswith("protocol_"):
        context.user_data["protocol"] = query.data.split("_", 1)[1]
        await query.edit_message_text("Masukkan nama pengguna yang dikehendaki:")
        return INPUT_USERNAME

# Dapatkan username
async def username_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    username = update.message.text.strip()
    context.user_data["username"] = username
    await update.message.reply_text("Masukkan kata laluan (atau balas 'auto' untuk auto generate):")
    return INPUT_PASSWORD

# Dapatkan password
async def password_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    password = update.message.text.strip()
    if password.lower() == "auto":
        password = ""
    context.user_data["password"] = password
    await update.message.reply_text("Berapa hari tempoh sah akaun?")
    return INPUT_DAYS

# Dapatkan tempoh hari
async def days_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    days = update.message.text.strip()
    protocol = context.user_data["protocol"]
    username = context.user_data["username"]
    password = context.user_data["password"]
    try:
        days_int = int(days)
        if days_int <= 0:
            raise ValueError
    except ValueError:
        await update.message.reply_text("❌ Masukkan bilangan hari yang sah (1 atau lebih).")
        return INPUT_DAYS

    # Panggil skrip bash untuk cipta akaun
    await update.message.reply_text("🚀 Sedang mencipta akaun...")

    # Mapping protokol ke command
    cmd = ""
    if protocol == "ssh":
        cmd = f"/usr/local/bin/menu create_ssh {username} {password} {days}"
    elif protocol == "ovpn":
        cmd = f"/usr/local/bin/menu create_ovpn {username} {password} {days}"
    elif protocol == "vmess":
        cmd = f"/usr/local/bin/menu create_vmess {username} {days}"
    elif protocol == "vless":
        cmd = f"/usr/local/bin/menu create_vless {username} {days}"
    elif protocol == "hysteria2":
        cmd = f"/usr/local/bin/menu create_hysteria {username} {password} {days}"

    # Jalankan command
    try:
        result = subprocess.check_output(cmd, shell=True, text=True, timeout=30)
    except Exception as e:
        await update.message.reply_text(f"❌ Ralat: Gagal cipta akaun!\n{str(e)}")
        return ConversationHandler.END

    # Hantar result kepada user
    msg = f"✅ *Akaun {protocol.upper()} berjaya dicipta!*\n\n" + f"{result}"
    await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=ReplyKeyboardRemove())

    return ConversationHandler.END

# Cancel handler
async def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Operasi dibatalkan.", reply_markup=ReplyKeyboardRemove())
    return ConversationHandler.END

def main():
    config = load_bot_config()
    token = config.get("TELEGRAM_BOT_TOKEN", "")
    if not token:
        print("Sila set token Telegram pada /etc/backup.conf")
        return

    app = ApplicationBuilder().token(token).build()

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler("start", start)],
        states={
            SELECT_PROTOCOL: [CallbackQueryHandler(menu_button)],
            INPUT_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, username_input)],
            INPUT_PASSWORD: [MessageHandler(filters.TEXT & ~filters.COMMAND, password_input)],
            INPUT_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, days_input)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True,
    )

    app.add_handler(conv_handler)
    app.add_handler(CallbackQueryHandler(menu_button))
    app.add_handler(CommandHandler("help", help_menu))

    print("Bot VPN Telegram telah bermula...")
    app.run_polling()

if __name__ == "__main__":
    main()