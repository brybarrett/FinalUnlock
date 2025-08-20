import os
import signal
import sys
import time
import asyncio
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes
from telegram.error import TelegramError, NetworkError, TimedOut, RetryAfter
from dotenv import load_dotenv
import importlib.util
import json
import logging
from datetime import datetime

# 全局变量用于优雅关闭
shutdown_flag = False
app = None

# PID文件管理
PID_FILE = os.path.join(os.path.dirname(__file__), 'bot.pid')

# 配置更详细的日志
logging.basicConfig(
    filename='bot.log',
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# 添加控制台日志处理器
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

# 全局异常处理器
def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return
    logger.critical("未捕获的异常", exc_info=(exc_type, exc_value, exc_traceback))

sys.excepthook = handle_exception

# PID文件管理函数
def create_pid_file():
    """创建PID文件"""
    try:
        with open(PID_FILE, 'w') as f:
            f.write(str(os.getpid()))
        logger.info(f'PID文件已创建: {PID_FILE}')
    except Exception as e:
        logger.error(f'创建PID文件失败: {e}')

def remove_pid_file():
    """删除PID文件"""
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
            logger.info(f'PID文件已删除: {PID_FILE}')
    except Exception as e:
        logger.error(f'删除PID文件失败: {e}')

# 信号处理器
def signal_handler(signum, frame):
    global shutdown_flag, app
    logger.info(f'收到信号 {signum}，开始优雅关闭...')
    shutdown_flag = True
    if app:
        app.stop_running()
    remove_pid_file()  # 清理PID文件
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# 加载 .env 文件
load_dotenv()
BOT_TOKEN = os.getenv('BOT_TOKEN')
CHAT_ID = os.getenv('CHAT_ID')

# 验证配置
if not BOT_TOKEN:
    logger.error("BOT_TOKEN 未配置，请检查 .env 文件")
    logger.error("当前工作目录: " + os.getcwd())
    logger.error("环境文件路径: " + os.path.join(os.getcwd(), '.env'))
    if os.path.exists('.env'):
        logger.error(".env 文件存在，但BOT_TOKEN为空")
        with open('.env', 'r') as f:
            content = f.read()
            logger.error(f".env 内容长度: {len(content)} 字符")
            if 'BOT_TOKEN' in content:
                logger.error("BOT_TOKEN 行存在但值为空")
            else:
                logger.error("BOT_TOKEN 行不存在")
    else:
        logger.error(".env 文件不存在")
    sys.exit(1)

if not CHAT_ID:
    logger.error("CHAT_ID 未配置，请检查 .env 文件")
    logger.error("当前工作目录: " + os.getcwd())
    logger.error("环境文件路径: " + os.path.join(os.getcwd(), '.env'))
    if os.path.exists('.env'):
        logger.error(".env 文件存在，但CHAT_ID为空")
        with open('.env', 'r') as f:
            content = f.read()
            logger.error(f".env 内容长度: {len(content)} 字符")
            if 'CHAT_ID' in content:
                logger.error("CHAT_ID 行存在但值为空")
            else:
                logger.error("CHAT_ID 行不存在")
    else:
        logger.error(".env 文件不存在")
    sys.exit(1)

def today_str():
    return datetime.now().strftime('%Y%m%d')

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
            '➡️ /guard - 获取系统自检报告\n'
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

async def users_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """查看用户列表（管理员命令）"""
    user_id = str(update.effective_user.id)
    
    # 检查是否为管理员
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    
    try:
        if not users:
            await update.message.reply_text('📋 用户列表为空')
            return
        
        # 构建用户列表消息
        user_list = []
        total_users = len(users)
        banned_users = sum(1 for u in users.values() if u.get('is_banned', False))
        active_users = total_users - banned_users
        
        user_list.append(f'📊 用户统计: 总计 {total_users} 人，活跃 {active_users} 人，已封禁 {banned_users} 人\n')
        
        # 按最后使用时间排序
        sorted_users = sorted(users.items(), 
                            key=lambda x: x[1].get('last_seen', ''), 
                            reverse=True)
        
        # 限制显示前50个用户，避免消息过长
        display_count = min(50, len(sorted_users))
        user_list.append(f'📋 最近活跃用户 (显示前{display_count}个):\n')
        
        for i, (uid, info) in enumerate(sorted_users[:display_count], 1):
            username = info.get('username', '无')
            first_name = info.get('first_name', '无')
            last_seen = info.get('last_seen', '未知')
            total_requests = info.get('total_requests', 0)
            is_banned = info.get('is_banned', False)
            
            status = '🚫' if is_banned else '✅'
            user_info = f'{i}. {status} ID: {uid}\n'
            user_info += f'   👤 {first_name} (@{username})\n'
            user_info += f'   📅 最后活跃: {last_seen}\n'
            user_info += f'   📊 请求次数: {total_requests}\n'
            
            user_list.append(user_info)
        
        if len(sorted_users) > display_count:
            user_list.append(f'\n... 还有 {len(sorted_users) - display_count} 个用户未显示')
        
        message = '\n'.join(user_list)
        
        # 如果消息太长，分段发送
        if len(message) > 4000:
            chunks = [message[i:i+4000] for i in range(0, len(message), 4000)]
            for i, chunk in enumerate(chunks):
                await update.message.reply_text(f'用户列表 (第{i+1}部分):\n{chunk}')
        else:
            await update.message.reply_text(message)
            
        logger.info(f'管理员 {user_id} 查看了用户列表')
        
    except Exception as e:
        await update.message.reply_text(f'❌ 获取用户列表失败: {str(e)[:100]}')
        logger.error(f'获取用户列表时出错: {e}')

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
# 改进的消息处理函数，添加重试机制
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = str(update.effective_user.id)
    max_retries = 3
    retry_delay = 1
    
    try:
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
        
        # 验证机器码格式
        if not machine_id or len(machine_id) < 5:
            await update.message.reply_text('请输入有效的机器码')
            return
            
        # 捕获输出并添加重试机制
        import io, sys
        buf = io.StringIO()
        sys_stdout = sys.stdout
        sys.stdout = buf
        
        for attempt in range(max_retries):
            try:
                show_activation_codes(machine_id)
                break
            except Exception as e:
                logger.warning(f"生成激活码失败，尝试 {attempt + 1}/{max_retries}: {e}")
                if attempt == max_retries - 1:
                    sys.stdout = sys_stdout
                    await update.message.reply_text(f'生成激活码失败，请稍后重试。错误: {str(e)[:100]}')
                    logger.error(f"用户{user_id}生成激活码最终失败: {e}")
                    return
                await asyncio.sleep(retry_delay)
                retry_delay *= 2
        
        sys.stdout = sys_stdout
        result = buf.getvalue()
        
        if not result.strip():
            await update.message.reply_text('生成激活码失败，请检查机器码格式')
            return
            
        # 分段发送长消息
        if len(result) > 4000:
            chunks = [result[i:i+4000] for i in range(0, len(result), 4000)]
            for i, chunk in enumerate(chunks):
                await update.message.reply_text(f"激活码 (第{i+1}部分):\n{chunk}")
        else:
            await update.message.reply_text(result)
            
        logger.info(f"用户{user_id}成功获取激活码，机器码: {machine_id[:10]}...")
        
    except NetworkError as e:
        logger.error(f"网络错误: {e}")
        try:
            await update.message.reply_text('网络连接异常，请稍后重试')
        except:
            pass
    except TimedOut as e:
        logger.error(f"请求超时: {e}")
        try:
            await update.message.reply_text('请求超时，请稍后重试')
        except:
            pass
    except RetryAfter as e:
        logger.warning(f"触发速率限制，等待 {e.retry_after} 秒")
        try:
            await update.message.reply_text(f'请求过于频繁，请等待 {e.retry_after} 秒后重试')
        except:
            pass
    except Exception as e:
        logger.error(f"处理消息时发生未知错误: {e}", exc_info=True)
        try:
            await update.message.reply_text('服务暂时不可用，请稍后重试')
        except:
            pass

# 改进的广播函数
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
    
    # 添加进度反馈
    total_users = len([uid for uid in stats if not uid.startswith('start_')])
    progress_msg = await update.message.reply_text(f'开始广播到 {total_users} 个用户...')
    
    for i, uid in enumerate(stats):
        if uid.startswith('start_'):
            continue
            
        try:
            await context.bot.send_message(chat_id=uid, text=msg)
            sent += 1
        except TelegramError as e:
            failed += 1
            logger.warning(f"向用户 {uid} 发送广播失败: {e}")
        except Exception as e:
            failed += 1
            logger.error(f"向用户 {uid} 发送广播时发生未知错误: {e}")
            
        # 每10个用户更新一次进度
        if (i + 1) % 10 == 0:
            try:
                await progress_msg.edit_text(f'广播进度: {i + 1}/{total_users}, 成功: {sent}, 失败: {failed}')
            except:
                pass
                
        # 避免触发速率限制
        await asyncio.sleep(0.1)
    
    final_msg = f'广播完成！成功：{sent}，失败：{failed}'
    try:
        await progress_msg.edit_text(final_msg)
    except:
        await update.message.reply_text(final_msg)
    
    logger.info(f"管理员 {user_id} 完成广播: 成功 {sent}, 失败 {failed}")

async def guard_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """获取最新的自检报告"""
    user_id = str(update.effective_user.id)
    
    # 检查是否为管理员
    if not is_admin(user_id):
        if handle_admin_try(user_id):
            await update.message.reply_text('你多次尝试管理员命令，已被拉黑。')
        else:
            await update.message.reply_text('你不是管理员，无权使用此命令。')
        return
    
    try:
        # 查找最新的报告文件
        from datetime import datetime, timezone, timedelta
        shanghai_tz = timezone(timedelta(hours=8))
        current_date = datetime.now(shanghai_tz).strftime('%Y%m%d')
        report_file = f'daily_report_{current_date}.json'
        
        if os.path.exists(report_file):
            # 运行guard.py发送报告
            import subprocess
            result = subprocess.run([sys.executable, 'guard.py', 'report'], 
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                await update.message.reply_text('✅ 最新自检报告已发送！')
                logger.info(f"管理员 {user_id} 请求自检报告成功")
            else:
                await update.message.reply_text('❌ 发送自检报告失败，请检查Guard程序状态。')
                logger.error(f"发送自检报告失败: {result.stderr}")
        else:
            await update.message.reply_text('⚠️ 今日尚未生成自检报告，正在生成...')
            
            # 执行自检并发送报告
            result = subprocess.run([sys.executable, 'guard.py', 'check'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                result = subprocess.run([sys.executable, 'guard.py', 'report'], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    await update.message.reply_text('✅ 自检报告已生成并发送！')
                else:
                    await update.message.reply_text('❌ 生成报告成功但发送失败。')
            else:
                await update.message.reply_text('❌ 生成自检报告失败，请检查系统状态。')
                
    except Exception as e:
        await update.message.reply_text(f'❌ 处理自检报告请求时出错: {str(e)[:100]}')
        logger.error(f"处理guard命令时出错: {e}")

# 主程序
# 修复第600-610行的run_polling调用
def cleanup_existing_instances():
    """清理可能存在的其他机器人实例"""
    import psutil
    
    current_pid = os.getpid()
    current_script = os.path.abspath(__file__)
    
    try:
        # 查找所有运行bot.py的进程
        for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if proc.info['pid'] == current_pid:
                    continue
                    
                cmdline = ' '.join(proc.info['cmdline'] or [])
                if 'bot.py' in cmdline and current_script in cmdline:
                    logger.warning(f"发现其他bot实例 (PID: {proc.info['pid']})，正在终止...")
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                        logger.info(f"已终止重复实例 (PID: {proc.info['pid']})")
                    except psutil.TimeoutExpired:
                        proc.kill()
                        logger.info(f"强制终止重复实例 (PID: {proc.info['pid']})")
                        
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
                
    except Exception as e:
        logger.warning(f"清理其他实例时出错: {e}")

if __name__ == '__main__':
    try:
        logger.info("FinalShell 激活码机器人启动中...")
        
        # 清理可能存在的其他实例
        cleanup_existing_instances()
        
        app = ApplicationBuilder().token(BOT_TOKEN).build()
        
        # 创建PID文件
        create_pid_file()
        
        # 错误处理器
        async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
            logger.error(f"更新处理出错: {context.error}", exc_info=context.error)
            if update and hasattr(update, 'effective_chat') and update.effective_chat:
                try:
                    await context.bot.send_message(
                        chat_id=update.effective_chat.id,
                        text="抱歉，处理您的请求时出现了错误，请稍后重试。"
                    )
                except Exception as e:
                    logger.error(f"发送错误消息失败: {e}")
        
        app.add_error_handler(error_handler)
        
        # 添加命令处理器
        app.add_handler(CommandHandler('start', start))
        app.add_handler(CommandHandler('help', help_cmd))
        app.add_handler(CommandHandler('stats', stats_cmd))
        app.add_handler(CommandHandler('users', users_cmd))
        app.add_handler(CommandHandler('ban', ban_cmd))
        app.add_handler(CommandHandler('unban', unban_cmd))
        app.add_handler(CommandHandler('clear', clear_cmd))
        app.add_handler(CommandHandler('cleanup', cleanup_cmd))
        app.add_handler(CommandHandler('say', say_cmd))
        app.add_handler(CommandHandler('guard', guard_cmd))
        app.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), handle_message))
        
        logger.info('机器人启动成功，开始轮询...')
        print('Bot 运行中...')
        
        # 🔧 修复：使用兼容v20.0+的参数，增加冲突处理
        app.run_polling(
            drop_pending_updates=True,
            timeout=30,
            bootstrap_retries=3,
            close_loop=False  # 避免事件循环冲突
        )
        
    except KeyboardInterrupt:
        logger.info("收到键盘中断，正在关闭...")
        remove_pid_file()
    except Exception as e:
        logger.critical(f"机器人启动失败: {e}", exc_info=True)
        remove_pid_file()
        sys.exit(1)
    finally:
        # 确保PID文件被清理
        remove_pid_file()
        logger.info("机器人已关闭")