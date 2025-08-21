#!/usr/bin/env python3
"""
FinalUnlock Telegram Bot 
功能：FinalShell激活码自动生成机器人
"""

import os
import sys
import json
import logging
import asyncio
from datetime import datetime
from pathlib import Path

from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from telegram.error import TelegramError
from dotenv import load_dotenv

# 导入核心算法
from py import show_activation_codes

# 基础配置
BASE_DIR = Path(__file__).parent
PID_FILE = BASE_DIR / 'bot.pid'
LOG_FILE = BASE_DIR / 'bot.log'
DATA_DIR = BASE_DIR / 'data'
DATA_DIR.mkdir(exist_ok=True)

# 加载环境变量
load_dotenv(BASE_DIR / '.env')
BOT_TOKEN = os.getenv('BOT_TOKEN')
CHAT_ID = os.getenv('CHAT_ID')

if not BOT_TOKEN or not CHAT_ID:
    print("错误：请先配置 .env 文件中的 BOT_TOKEN 和 CHAT_ID")
    sys.exit(1)

# 日志配置
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 数据管理
class DataManager:
    def __init__(self):
        self.stats_file = DATA_DIR / 'stats.json'
        self.users_file = DATA_DIR / 'users.json'
        self.banned_file = DATA_DIR / 'banned.json'
        
    def load_json(self, file_path, default=None):
        if default is None:
            default = {}
        try:
            if file_path.exists():
                with open(file_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except:
            pass
        return default
    
    def save_json(self, file_path, data):
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存数据失败: {e}")
    
    def get_stats(self):
        return self.load_json(self.stats_file, {})
    
    def save_stats(self, stats):
        self.save_json(self.stats_file, stats)
    
    def get_users(self):
        return self.load_json(self.users_file, {})
    
    def save_users(self, users):
        self.save_json(self.users_file, users)
    
    def get_banned(self):
        return set(self.load_json(self.banned_file, []))
    
    def save_banned(self, banned_set):
        self.save_json(self.banned_file, list(banned_set))

# 全局数据管理器
dm = DataManager()

# 管理员检查
def is_admin(user_id):
    return str(user_id) == CHAT_ID

# 命令处理器
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "🎉 欢迎使用 FinalShell 激活码生成机器人！\n\n"
        "📝 使用方法：直接发送你的机器码即可获取激活码\n"
        "💡 支持 FinalShell 全版本（包括最新 4.6.5）\n\n"
        "🚀 请合理使用 滥用拉黑永久不解！"
    )

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    help_text = "🤖 FinalShell 激活码机器人使用帮助\n\n"
    help_text += "👤 用户命令：\n"
    help_text += "/start - 开始使用\n"
    help_text += "/help - 显示帮助\n"
    help_text += "直接发送机器码 - 生成激活码\n\n"
    
    if is_admin(update.effective_user.id):
        help_text += "👑 管理员命令：\n"
        help_text += "/stats - 查看统计\n"
        help_text += "/users - 用户列表\n"
        help_text += "/ban <用户ID> - 拉黑用户\n"
        help_text += "/unban <用户ID> - 解除拉黑\n"
        help_text += "/say <消息> - 广播消息\n"
    
    await update.message.reply_text(help_text)

async def stats_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ 仅管理员可用")
        return
    
    stats = dm.get_stats()
    users = dm.get_users()
    banned = dm.get_banned()
    
    text = f"📊 机器人统计信息\n\n"
    text += f"👥 总用户数：{len(users)}\n"
    text += f"🚫 被拉黑用户：{len(banned)}\n"
    text += f"📈 总请求数：{sum(user.get('count', 0) for user in stats.values())}\n"
    text += f"📅 统计时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    
    await update.message.reply_text(text)

async def users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ 仅管理员可用")
        return
    
    users = dm.get_users()
    if not users:
        await update.message.reply_text("📭 暂无用户数据")
        return
    
    text = "👥 用户列表（最近10个）：\n\n"
    for i, (uid, info) in enumerate(list(users.items())[-10:], 1):
        name = info.get('first_name', '未知')
        count = info.get('total_requests', 0)
        banned = '🚫' if info.get('is_banned', False) else '✅'
        text += f"{i}. {name} ({uid})\n   请求：{count}次 状态：{banned}\n\n"
    
    await update.message.reply_text(text)

async def ban_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ 仅管理员可用")
        return
    
    if not context.args:
        await update.message.reply_text("用法：/ban <用户ID>")
        return
    
    user_id = context.args[0]
    banned = dm.get_banned()
    banned.add(user_id)
    dm.save_banned(banned)
    
    await update.message.reply_text(f"✅ 已拉黑用户 {user_id}")

async def unban_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ 仅管理员可用")
        return
    
    if not context.args:
        await update.message.reply_text("用法：/unban <用户ID>")
        return
    
    user_id = context.args[0]
    banned = dm.get_banned()
    banned.discard(user_id)
    dm.save_banned(banned)
    
    await update.message.reply_text(f"✅ 已解除拉黑用户 {user_id}")

async def say_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("❌ 仅管理员可用")
        return
    
    if not context.args:
        await update.message.reply_text("用法：/say <要广播的消息>")
        return
    
    message = ' '.join(context.args)
    users = dm.get_users()
    
    sent = failed = 0
    for uid in users:
        try:
            await context.bot.send_message(chat_id=uid, text=message)
            sent += 1
        except:
            failed += 1
    
    await update.message.reply_text(f"📢 广播完成\n✅ 成功：{sent}\n❌ 失败：{failed}")

# 主要消息处理
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    user_info = update.effective_user
    machine_id = update.message.text.strip()
    
    # 检查拉黑
    banned = dm.get_banned()
    if user_id in banned:
        await update.message.reply_text("❌ 你已被拉黑，无法使用此服务")
        return
    
    # 更新用户信息
    users = dm.get_users()
    users[user_id] = {
        'first_name': user_info.first_name or '',
        'last_name': user_info.last_name or '',
        'username': user_info.username or '',
        'first_seen': users.get(user_id, {}).get('first_seen', datetime.now().isoformat()),
        'last_seen': datetime.now().isoformat(),
        'total_requests': users.get(user_id, {}).get('total_requests', 0) + 1,
        'is_banned': False
    }
    dm.save_users(users)
    
    # 统计使用次数（不限制使用）
    stats = dm.get_stats()
    today = datetime.now().strftime('%Y-%m-%d')
    user_stats = stats.get(user_id, {})
    
    if user_stats.get('date') != today:
        user_stats = {'date': today, 'count': 0}
    
    user_stats['count'] += 1
    stats[user_id] = user_stats
    dm.save_stats(stats)
    
    # 验证机器码
    if not machine_id or len(machine_id) < 5:
        await update.message.reply_text("❌ 请输入有效的机器码")
        return
    
    # 生成激活码
    try:
        import io
        old_stdout = sys.stdout
        sys.stdout = buffer = io.StringIO()
        
        show_activation_codes(machine_id)
        
        sys.stdout = old_stdout
        result = buffer.getvalue()
        
        if result:
            await update.message.reply_text(f"🎉 激活码生成成功：\n\n{result}")
            logger.info(f"用户 {user_id} 生成激活码成功")
        else:
            await update.message.reply_text("❌ 生成激活码失败，请检查机器码格式")
            
    except Exception as e:
        logger.error(f"生成激活码出错: {e}")
        await update.message.reply_text("❌ 服务暂时不可用，请稍后重试")

# 错误处理
async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"更新处理出错: {context.error}")

# PID管理
def create_pid():
    try:
        # 确保目录存在
        PID_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        # 写入当前进程PID
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        
        logger.info(f"PID文件已创建: {PID_FILE} (PID: {os.getpid()})")
    except Exception as e:
        logger.error(f"创建PID文件失败: {e}")
        # PID文件创建失败不应该阻止程序运行

def remove_pid():
    try:
        if PID_FILE.exists():
            PID_FILE.unlink()
            logger.info("PID文件已删除")
    except Exception as e:
        logger.error(f"删除PID文件失败: {e}")

# 主函数
def main():
    logger.info("FinalUnlock Bot 启动中...")
    
    # 立即创建PID文件
    create_pid()
    logger.info("PID文件已创建")
    
    try:
        # 创建应用
        app = Application.builder().token(BOT_TOKEN).build()
        
        # 添加处理器
        app.add_handler(CommandHandler('start', start))
        app.add_handler(CommandHandler('help', help_cmd))
        app.add_handler(CommandHandler('stats', stats_cmd))
        app.add_handler(CommandHandler('users', users_cmd))
        app.add_handler(CommandHandler('ban', ban_cmd))
        app.add_handler(CommandHandler('unban', unban_cmd))
        app.add_handler(CommandHandler('say', say_cmd))
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        app.add_error_handler(error_handler)
        
        logger.info("Bot 启动成功，开始轮询...")
        
        # 运行
        app.run_polling(drop_pending_updates=True)
        
    except KeyboardInterrupt:
        logger.info("收到停止信号")
    except Exception as e:
        logger.error(f"Bot运行出错: {e}")
    finally:
        remove_pid()

if __name__ == '__main__':
    main()