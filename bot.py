import os
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv
import importlib.util
import json
import logging
from datetime import datetime
from telegram.error import TelegramError

# 加载 .env 文件
load_dotenv()
BOT_TOKEN = os.getenv('BOT_TOKEN')
CHAT_ID = os.getenv('CHAT_ID')

def today_str():
    return datetime.now().strftime('%Y%m%d')

# 日志配置
logging.basicConfig(
    filename='bot.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# 数据文件名函数
STATS_FILE = lambda: f'stats_{today_str()}.json'
BAN_FILE = lambda: f'ban_{today_str()}.json'
TRY_FILE = lambda: f'try_{today_str()}.json'
USERS_FILE = 'users.json'  # 用户记录文件

# 加载和保存json

def load_json(filename, default):
    if os.path.exists(filename):
        with open(filename, 'r', encoding='utf-8') as f:
            return json.load(f)
    return default

def save_json(filename, data):
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# 统计、黑名单、尝试次数、用户记录
stats = load_json(STATS_FILE(), {})
ban_list = set(load_json(BAN_FILE(), []))
try_count = load_json(TRY_FILE(), {})
users = load_json(USERS_FILE, {})  # 用户记录

def record_user(user_id, username=None, first_name=None, last_name=None):
    """记录用户信息"""
    user_id = str(user_id)
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    if user_id not in users:
        users[user_id] = {
            'first_seen': now_str,
            'last_seen': now_str,
            'username': username,
            'first_name': first_name,
            'last_name': last_name,
            'total_requests': 0,
            'is_banned': False
        }
    else:
        users[user_id]['last_seen'] = now_str
        if username:
            users[user_id]['username'] = username
        if first_name:
            users[user_id]['first_name'] = first_name
        if last_name:
            users[user_id]['last_name'] = last_name
    
    save_json(USERS_FILE, users)

def update_user_stats(user_id, is_banned=False):
    """更新用户统计信息"""
    user_id = str(user_id)
    if user_id in users:
        users[user_id]['total_requests'] = users[user_id].get('total_requests', 0) + 1
        users[user_id]['is_banned'] = is_banned
        users[user_id]['last_seen'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        save_json(USERS_FILE, users)

def is_admin(user_id):
    admin_ids = [i.strip() for i in (os.getenv('CHAT_ID') or '').split(',') if i.strip()]
    return str(user_id) in admin_ids

def handle_admin_try(user_id):
    user_id = str(user_id)
    try_count[user_id] = try_count.get(user_id, 0) + 1
    save_json(TRY_FILE(), try_count)
    if try_count[user_id] >= 3:
        ban_list.add(user_id)
        save_json(BAN_FILE(), list(ban_list))
        return True  # 已拉黑
    return False

# 动态导入 py.py 的 show_activation_codes 函数
def get_show_activation_codes():
    spec = importlib.util.spec_from_file_location('py', os.path.join(os.path.dirname(__file__), 'py.py'))
    if spec is None or spec.loader is None:
        raise ImportError('无法加载 py.py 模块')
    py = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(py)
    return py.show_activation_codes

show_activation_codes = get_show_activation_codes()

# 指令处理
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    
    # 记录用户信息
    record_user(
        user_id, 
        update.effective_user.username, 
        update.effective_user.first_name, 
        update.effective_user.last_name
    )
    
    if stats.get(f'start_{user_id}', 0) == 0:
        await update.message.reply_text('👋 欢迎使用 FinalShell 激活码机器人，已更新可支持4.6.5版本！\n请输入机器码获取激活码。')
        stats[f'start_{user_id}'] = 1
        save_json(STATS_FILE(), stats)
    else:
        await update.message.reply_text('你已使用过本机器人，直接输入机器码即可获取激活码。')

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    
    # 基础帮助信息
    help_text = (
        '📚 帮助信息:\n'
        '➡️ /start - 欢迎使用\n'
        '➡️ /help - 帮助信息\n'
        '➡️ 直接向我发送机器码\n'
        '➡️ 我会计算并返回激活码\n'
    )
    
    # 如果是管理员，显示管理员命令
    if is_admin(user_id):
        admin_help = (
            '\n🔧 管理员命令:\n'
            '➡️ /stats - 查看统计数据\n'
            '➡️ /users - 查看用户列表\n'
            '➡️ /ban <用户ID> - 拉黑用户\n'
            '➡️ /unban <用户ID> - 解除拉黑\n'
            '➡️ /say <内容> - 广播消息\n'
            '➡️ /clear - 清除统计数据\n'
            '➡️ /cleanup - 清除日志文件\n'
        )
        help_text += admin_help
    
    await update.message.reply_text(help_text)

async def stats_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    msg_lines = []
    for k, v in stats.items():
        if k.startswith('start_'):
            continue
        # v 可能是 int 或 dict
        if isinstance(v, dict):
            count = v.get('count', 0)
            last_time = v.get('last_time', '')
        else:
            count = v
            last_time = ''
        msg_lines.append(f"{k}: {count} {last_time}")
    msg = '\n'.join(msg_lines) or '暂无统计数据。'
    await update.message.reply_text(f'📊 统计数据:\n{msg}')

async def ban_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    if len(context.args) != 1:
        await update.message.reply_text('用法: /ban <用户ID>')
        return
    ban_id = context.args[0]
    ban_list.add(ban_id)
    save_json(BAN_FILE(), list(ban_list))
    await update.message.reply_text(f'已拉黑用户 {ban_id}')

async def unban_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    if len(context.args) != 1:
        await update.message.reply_text('用法: /unban <用户ID>')
        return
    ban_id = context.args[0]
    ban_list.discard(ban_id)
    save_json(BAN_FILE(), list(ban_list))
    await update.message.reply_text(f'已解除拉黑用户 {ban_id}')

async def clear_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    stats.clear()
    save_json(STATS_FILE(), stats)
    await update.message.reply_text('所有计数器数据已清除。')

async def cleanup_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    if os.path.exists('bot.log'):
        os.remove('bot.log')
        await update.message.reply_text('日志文件已清除。')
    else:
        await update.message.reply_text('没有日志文件可清除。')

# 激活码自动生成
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if user_id in ban_list:
        await update.message.reply_text('你已被拉黑，无法使用本服务。')
        update_user_stats(user_id, is_banned=True)
        return
    # 管理员不计数
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    if not is_admin(user_id):
        v = stats.get(user_id, {'count': 0, 'last_time': ''})
        if isinstance(v, int):
            v = {'count': v, 'last_time': ''}
        v['count'] = v.get('count', 0) + 1
        v['last_time'] = now_str
        stats[user_id] = v
        save_json(STATS_FILE(), stats)
        update_user_stats(user_id, is_banned=False)
        if v['count'] > 3:
            ban_list.add(user_id)
            save_json(BAN_FILE(), list(ban_list))
            update_user_stats(user_id, is_banned=True)
            await update.message.reply_text('你已超过免费使用次数，如需继续使用请联系管理员。')
            return
    else:
        # 管理员也记录时间和次数
        v = stats.get(user_id, {'count': 0, 'last_time': ''})
        if isinstance(v, int):
            v = {'count': v, 'last_time': ''}
        v['count'] = v.get('count', 0) + 1
        v['last_time'] = now_str
        stats[user_id] = v
        save_json(STATS_FILE(), stats)
        update_user_stats(user_id, is_banned=False)
    machine_id = update.message.text.strip()
    # 捕获输出
    import io, sys
    buf = io.StringIO()
    sys_stdout = sys.stdout
    sys.stdout = buf
    try:
        show_activation_codes(machine_id)
    except Exception as e:
        await update.message.reply_text(f'生成激活码出错: {e}')
        sys.stdout = sys_stdout
        return
    sys.stdout = sys_stdout
    result = buf.getvalue()
    await update.message.reply_text(result)
    logging.info(f"用户{user_id}请求激活码，机器码: {machine_id}")

async def say_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    if not context.args:
        await update.message.reply_text('用法: /say <要广播的内容>')
        return
    msg = ' '.join(context.args)
    sent = 0
    failed = 0
    for uid in stats:
        if uid.startswith('start_'):
            continue
        try:
            await context.bot.send_message(chat_id=uid, text=msg)
            sent += 1
        except TelegramError:
            failed += 1
    await update.message.reply_text(f'广播完成，成功：{sent}，失败：{failed}')

async def users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """查看用户列表"""
    user_id = str(update.effective_user.id)
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    
    if not users:
        await update.message.reply_text('暂无用户记录。')
        return
    
    # 构建用户列表消息
    msg_lines = ['📋 用户列表:']
    for uid, user_info in users.items():
        username = user_info.get('username', '无用户名')
        first_name = user_info.get('first_name', '')
        last_name = user_info.get('last_name', '')
        first_seen = user_info.get('first_seen', '未知')
        total_requests = user_info.get('total_requests', 0)
        is_banned = user_info.get('is_banned', False)
        
        name = f"{first_name} {last_name}".strip() if first_name or last_name else username
        status = "🚫 已拉黑" if is_banned else "✅ 正常"
        
        msg_lines.append(f"ID: {uid}")
        msg_lines.append(f"  姓名: {name}")
        msg_lines.append(f"  首次使用: {first_seen}")
        msg_lines.append(f"  总请求数: {total_requests}")
        msg_lines.append(f"  状态: {status}")
        msg_lines.append("")
    
    msg = '\n'.join(msg_lines)
    
    # 如果消息太长，分段发送
    if len(msg) > 4000:
        chunks = [msg[i:i+4000] for i in range(0, len(msg), 4000)]
        for i, chunk in enumerate(chunks):
            await update.message.reply_text(f"用户列表 (第{i+1}部分):\n{chunk}")
    else:
        await update.message.reply_text(msg)

if __name__ == '__main__':
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler('start', start))
    app.add_handler(CommandHandler('help', help_cmd))
    app.add_handler(CommandHandler('stats', stats_cmd))
    app.add_handler(CommandHandler('ban', ban_cmd))
    app.add_handler(CommandHandler('unban', unban_cmd))
    app.add_handler(CommandHandler('clear', clear_cmd))
    app.add_handler(CommandHandler('cleanup', cleanup_cmd))
    app.add_handler(CommandHandler('say', say_cmd))
    app.add_handler(CommandHandler('users', users_cmd))
    app.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), handle_message))
    print('Bot 运行ing...')
    app.run_polling() 