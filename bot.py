import json
import datetime
import logging
import os
from Crypto.Hash import keccak, MD5
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters

# 配置日志记录
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# 读取配置文件
with open("config.json", "r", encoding="utf-8") as f:
    config = json.load(f)

TOKEN = config.get("TOKEN")
ADMIN_ID = config.get("ADMIN_ID")  # 确保 ADMIN_ID 是 int
BLACKLIST = set(config.get("BLACKLIST", []))
usage_data = config.get("usage_data", {})
violation_attempts = config.get("violation_attempts", {})

# 统计数据结构
stats_data = {
    "total_users_today": 0,
    "banned_users": 0,
    "unbanned_users": 0,
    "usage_details": {}  # 用于详细记录每个用户的使用次数
}

# 计算 MD5 哈希
def md5(msg):
    hash_obj = MD5.new(msg)
    return hash_obj.hexdigest()

# 计算 Keccak-384 哈希
def keccak384(msg):
    hash_obj = keccak.new(data=msg, digest_bits=384)
    return hash_obj.hexdigest()

# 生成激活码
def generate_activation_codes(code):
    # 旧版激活码计算
    old_pro = md5(f'61305{code}8552'.encode())[8:24]
    old_professional = md5(f'2356{code}13593'.encode())[8:24]
    # 新版激活码计算
    new_pro = keccak384(f'{code}hSf(78cvVlS5E'.encode())[12:28]
    new_professional = keccak384(f'{code}FF3Go(*Xvbb5s2'.encode())[12:28]

    # Markdown 格式输出
    response = (
        "*版本号 < 3.9.6 (旧版)*\n"
        f"🔹 _高级版_: `{old_pro}`\n"
        f"🔸 _专业版_: `{old_professional}`\n\n"
        "*版本号 >= 3.9.6 (新版)*\n"
        f"🔹 _高级版_: `{new_pro}`\n"
        f"🔸 _专业版_: `{new_professional}`"
    )
    return response

# 获取当前日期，用于文件名
def get_log_filename():
    today = datetime.date.today().isoformat()
    return f"log_{today}.txt"

# 欢迎命令 /start
async def start_command(update: Update, _):
    welcome_text = (
        "🎉 _欢迎使用 FinalShell 离线激活码生成工具_ 🎉\n"
        "📌 _请确认 FinalShell 版本最高为 4.3.10_\n\n"
        "⚠ _请按照规定合理使用，严禁倒卖行为_ ⚠\n"
        "🚨 _如果发现滥用行为，将立刻停止你的使用权限_ 🚨\n\n"
        "🔹 _请发送你的机器码，我会帮你计算激活码！_"
    )
    await update.message.reply_text(welcome_text, parse_mode="Markdown")

# 获取帮助信息 /help
async def help_command(update: Update, _):
    help_text = (
        "📚 _帮助信息_:\n"
        "➡ `/start` - 显示欢迎信息\n"
        "➡ `/help` - 获取帮助信息\n"
        "➡ `/stats` - 查看统计数据\n"
        "➡ `/ban <用户ID>` - 拉黑用户\n"
        "➡ `/unban <用户ID>` - 解除拉黑\n"
        "➡ `/clear` - 清除所有计数器数据\n"
        "➡ `/cleanup` - 清除日志文件\n"
        "🔹 _请遵守使用规范，合理使用该服务。_"
    )
    await update.message.reply_text(help_text, parse_mode="Markdown")

# 查看统计数据 /stats
async def stats_command(update: Update, _):
    user_id = update.message.from_user.id
    if user_id != ADMIN_ID:
        await update.message.reply_text("⚠ 你没有权限查看统计数据。")
        return

    # 获取今日日期
    today = datetime.date.today().isoformat()

    # 拉黑和解封用户的数量
    banned_users = stats_data.get("banned_users", 0)
    unbanned_users = stats_data.get("unbanned_users", 0)

    usage_details = "\n".join([
        f"用户 ID: {user} - 使用次数: {count}"
        for user, count in stats_data["usage_details"].items()
    ]) or "暂无使用记录"

    stats_text = (
        "*统计数据*:\n"
        f"🔹 今日使用用户数: {stats_data['total_users_today']}\n"
        f"🔸 拉黑用户总数: {banned_users}\n"
        f"🔹 解封用户总数: {unbanned_users}\n\n"
        f"🔍 使用详情:\n{usage_details}"
    )

    await update.message.reply_text(stats_text, parse_mode="Markdown")

    # 将统计数据保存到带日期的 log 文件中
    log_filename = get_log_filename()
    with open(log_filename, "a", encoding="utf-8") as log_file:
        log_entry = (
            f"日期: {today}\n"
            f"今日使用用户数: {stats_data['total_users_today']}\n"
            f"拉黑用户总数: {banned_users}\n"
            f"解封用户总数: {unbanned_users}\n"
            f"使用详情:\n{usage_details}\n"
            "----------------------\n"
        )
        log_file.write(log_entry)
        logging.info(f"统计数据已保存到 {log_filename}: {log_entry}")  # 记录日志

# 拉黑用户 /ban <用户ID>
async def ban_command(update: Update, context):
    user_id = update.message.from_user.id
    if user_id != ADMIN_ID:
        await update.message.reply_text("⚠ 你没有权限执行此命令。")
        return
    if len(context.args) != 1:
        await update.message.reply_text("使用方法: `/ban <用户ID>`")
        return
    user_to_ban = context.args[0]
    BLACKLIST.add(user_to_ban)
    config["BLACKLIST"] = list(BLACKLIST)
    # 更新统计数据
    stats_data["banned_users"] += 1
    await update.message.reply_text(f"用户 `{user_to_ban}` 已被拉黑。")
    logging.info(f"用户 {user_to_ban} 被拉黑。")  # 记录日志
    # 保存配置
    with open("config.json", "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4)

# 解除拉黑 /unban <用户ID>
async def unban_command(update: Update, context):
    user_id = update.message.from_user.id
    if user_id != ADMIN_ID:
        await update.message.reply_text("⚠ 你没有权限执行此命令。")
        return
    if len(context.args) != 1:
        await update.message.reply_text("使用方法: `/unban <用户ID>`")
        return
    user_to_unban = context.args[0]
    if user_to_unban in BLACKLIST:
        BLACKLIST.remove(user_to_unban)
        config["BLACKLIST"] = list(BLACKLIST)
        # 更新统计数据
        stats_data["unbanned_users"] += 1
        await update.message.reply_text(f"用户 `{user_to_unban}` 已被解除拉黑。")
        logging.info(f"用户 {user_to_unban} 被解除拉黑。")  # 记录日志
        # 保存配置
        with open("config.json", "w", encoding="utf-8") as f:
            json.dump(config, f, indent=4)
    else:
        await update.message.reply_text(f"用户 `{user_to_unban}` 不在黑名单中。")

# 清除计数器数据 /clear
async def clear_command(update: Update, _):
    user_id = update.message.from_user.id
    if user_id != ADMIN_ID:
        await update.message.reply_text("⚠ 你没有权限执行此命令。")
        return
    global violation_attempts, BLACKLIST, stats_data  # 声明使用全局变量
    # 清空违规尝试计数器和黑名单
    violation_attempts = {}
    BLACKLIST.clear()
    stats_data = {"total_users_today": 0, "banned_users": 0, "unbanned_users": 0, "usage_details": {}}  # 清零统计数据
    config["violation_attempts"] = violation_attempts
    config["BLACKLIST"] = list(BLACKLIST)
    config["stats_data"] = stats_data  # 更新统计数据
    await update.message.reply_text("✅ 所有计数器和黑名单数据已被清除。")
    logging.info("所有计数器和黑名单数据已被清除。")  # 记录日志
    # 更新配置文件
    with open("config.json", "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4)

# 清除日志文件 /cleanup
async def cleanup_command(update: Update, _):
    user_id = update.message.from_user.id
    if user_id != ADMIN_ID:
        await update.message.reply_text("⚠ 你没有权限执行此命令。")
        return

    # 查找所有以 log_ 开头的文件并删除
    log_deleted = False
    for filename in os.listdir("."):
        if filename.startswith("log_") and filename.endswith(".txt"):
            os.remove(filename)
            log_deleted = True
            logging.info(f"日志文件 {filename} 已被删除。")

    if log_deleted:
        await update.message.reply_text("✅ 所有日志文件已被清除。")
    else:
        await update.message.reply_text("⚠ 没有找到日志文件。")

# 处理用户输入机器码
async def handle_message(update: Update, _):
    user_id = update.message.from_user.id
    if str(user_id) in BLACKLIST:
        await update.message.reply_text("🚫 你已被禁止使用此服务，请联系管理员。")
        return

    # 增加今日用户使用统计
    stats_data["total_users_today"] += 1
    stats_data["usage_details"][user_id] = stats_data["usage_details"].get(user_id, 0) + 1
    logging.info(f"用户 {user_id} 输入了机器码，当前使用人数: {stats_data['total_users_today']}")

    code = update.message.text.strip()
    activation_codes = generate_activation_codes(code)
    await update.message.reply_text(activation_codes, parse_mode="Markdown")

# 运行 bot
def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("stats", stats_command))
    app.add_handler(CommandHandler("ban", ban_command))
    app.add_handler(CommandHandler("unban", unban_command))
    app.add_handler(CommandHandler("clear", clear_command))
    app.add_handler(CommandHandler("cleanup", cleanup_command))  # 添加清除日志文件的命令
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))  # 处理消息
    logging.info("✅ Bot 正在运行...")  # 记录日志
    app.run_polling()

if __name__ == "__main__":
    main()
