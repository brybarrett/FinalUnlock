#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FinalUnlock Guard 守护程序 v2.1
自动系统自检和报告发送 + 开机自启管理
作者: AI Assistant
版本: 2.1
"""

import os
import sys
import time
import json
import logging
import asyncio
import schedule
import psutil
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, List, Any

# Telegram相关导入
try:
    from telegram import Bot
    from telegram.error import TelegramError
except ImportError:
    print("请安装python-telegram-bot: pip install python-telegram-bot")
    sys.exit(1)

# 环境变量
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("请安装python-dotenv: pip install python-dotenv")
    sys.exit(1)

# 异步事件循环支持
try:
    import nest_asyncio
    nest_asyncio.apply()
except ImportError:
    print("请安装nest-asyncio: pip install nest-asyncio")
    sys.exit(1)

# 配置
PROJECT_DIR = Path(__file__).parent.absolute()
PID_FILE = PROJECT_DIR / "bot.pid"
GUARD_PID_FILE = PROJECT_DIR / "guard.pid"
BOT_LOG_FILE = PROJECT_DIR / "bot.log"
SERVICE_NAME = "finalunlock-bot"
SERVICE_FILE = f"/etc/systemd/system/{SERVICE_NAME}.service"

# 时区设置
SHANGHAI_TZ = timezone(timedelta(hours=8))

# 动态日志文件名（按日期）
def get_log_files():
    current_date = datetime.now(SHANGHAI_TZ).strftime('%Y%m%d')
    return {
        'guard_log': PROJECT_DIR / f"guard_{current_date}.log",
        'report_file': PROJECT_DIR / f"daily_report_{current_date}.json"
    }

class SystemGuard:
    def __init__(self):
        self.bot_token = os.getenv('BOT_TOKEN')
        self.chat_ids = [id.strip() for id in (os.getenv('CHAT_ID') or '').split(',') if id.strip()]
        self.bot = None
        self.daily_report = {}
        
        # 设置日志
        self.setup_logging()
        
        if not self.bot_token or not self.chat_ids:
            self.logger.error("Bot Token 或 Chat ID 未配置")
            sys.exit(1)
            
        self.bot = Bot(token=self.bot_token)
        self.logger.info("Guard 守护程序初始化完成")
    
    def setup_logging(self):
        """设置日志"""
        log_files = get_log_files()
        log_file = log_files['guard_log']
        
        # 创建logger
        self.logger = logging.getLogger('Guard')
        self.logger.setLevel(logging.INFO)
        
        # 清除现有handlers
        for handler in self.logger.handlers[:]:
            self.logger.removeHandler(handler)
        
        # 文件handler
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.INFO)
        
        # 控制台handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # 格式化
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
    
    def get_current_time(self) -> datetime:
        """获取当前上海时间"""
        return datetime.now(SHANGHAI_TZ)
    
    def check_bot_process(self) -> Dict[str, Any]:
        """检查机器人进程状态"""
        result = {
            'status': 'stopped',
            'pid': None,
            'cpu_percent': 0,
            'memory_mb': 0,
            'uptime': '未运行',
            'details': '进程未运行',
            'health': '❌'
        }
        
        try:
            # 方法1：检查PID文件
            if PID_FILE.exists():
                with open(PID_FILE, 'r') as f:
                    pid = int(f.read().strip())
                
                if psutil.pid_exists(pid):
                    process = psutil.Process(pid)
                    if 'bot.py' in ' '.join(process.cmdline()):
                        uptime_seconds = time.time() - process.create_time()
                        uptime_str = str(timedelta(seconds=int(uptime_seconds)))
                        
                        result.update({
                            'status': 'running',
                            'pid': pid,
                            'cpu_percent': round(process.cpu_percent(), 2),
                            'memory_mb': round(process.memory_info().rss / 1024 / 1024, 2),
                            'uptime': uptime_str,
                            'details': f'进程正常运行，PID: {pid}',
                            'health': '✅'
                        })
                        return result
                    else:
                        result['details'] = f'PID {pid} 不是bot.py进程'
                else:
                    result['details'] = f'PID {pid} 进程不存在'
            
            # 方法2：如果PID文件检查失败，尝试通过进程名查找
            for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'create_time']):
                try:
                    cmdline = ' '.join(proc.info['cmdline'] or [])
                    if 'bot.py' in cmdline and str(PROJECT_DIR) in cmdline:
                        # 找到了运行的bot.py进程
                        process = psutil.Process(proc.info['pid'])
                        uptime_seconds = time.time() - proc.info['create_time']
                        uptime_str = str(timedelta(seconds=int(uptime_seconds)))
                        
                        result.update({
                            'status': 'running',
                            'pid': proc.info['pid'],
                            'cpu_percent': round(process.cpu_percent(), 2),
                            'memory_mb': round(process.memory_info().rss / 1024 / 1024, 2),
                            'uptime': uptime_str,
                            'details': f'进程正常运行，PID: {proc.info["pid"]} (通过进程扫描发现)',
                            'health': '✅'
                        })
                        return result
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            # 如果都没找到，设置最终的错误信息
            if not PID_FILE.exists():
                result['details'] = 'PID文件不存在，且未发现运行中的bot.py进程'
            else:
                result['details'] = 'PID文件存在但进程已停止，且未发现其他运行中的bot.py进程'
                
        except Exception as e:
            result['details'] = f'检查进程时出错: {str(e)}'
            self.logger.error(f"检查机器人进程失败: {e}")
        
        return result
    
    def check_system_resources(self) -> Dict[str, Any]:
        """检查系统资源"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage(str(PROJECT_DIR))
            
            # 健康状态判断
            health = '✅'
            if cpu_percent > 80 or memory.percent > 90 or disk.percent > 90:
                health = '⚠️'
            if cpu_percent > 95 or memory.percent > 95 or disk.percent > 95:
                health = '❌'
            
            return {
                'cpu_percent': round(cpu_percent, 2),
                'memory_percent': round(memory.percent, 2),
                'memory_available_gb': round(memory.available / 1024 / 1024 / 1024, 2),
                'memory_total_gb': round(memory.total / 1024 / 1024 / 1024, 2),
                'disk_percent': round(disk.percent, 2),
                'disk_free_gb': round(disk.free / 1024 / 1024 / 1024, 2),
                'disk_total_gb': round(disk.total / 1024 / 1024 / 1024, 2),
                'status': 'normal' if health == '✅' else ('warning' if health == '⚠️' else 'critical'),
                'health': health
            }
        except Exception as e:
            self.logger.error(f"检查系统资源失败: {e}")
            return {'status': 'error', 'error': str(e), 'health': '❌'}
    
    def check_log_files(self) -> Dict[str, Any]:
        """检查日志文件"""
        result = {
            'bot_log': {'exists': False, 'size_mb': 0, 'last_modified': None, 'error_count': 0, 'warning_count': 0},
            'guard_log': {'exists': False, 'size_mb': 0, 'last_modified': None},
            'status': 'normal',
            'health': '✅'
        }
        
        try:
            # 检查bot.log
            if BOT_LOG_FILE.exists():
                stat = BOT_LOG_FILE.stat()
                result['bot_log'].update({
                    'exists': True,
                    'size_mb': round(stat.st_size / 1024 / 1024, 2),
                    'last_modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
                
                # 统计错误和警告数量
                try:
                    with open(BOT_LOG_FILE, 'r', encoding='utf-8') as f:
                        content = f.read().lower()
                        result['bot_log']['error_count'] = content.count('error') + content.count('critical')
                        result['bot_log']['warning_count'] = content.count('warning')
                except:
                    pass
            
            # 检查guard.log
            log_files = get_log_files()
            guard_log = log_files['guard_log']
            if guard_log.exists():
                stat = guard_log.stat()
                result['guard_log'].update({
                    'exists': True,
                    'size_mb': round(stat.st_size / 1024 / 1024, 2),
                    'last_modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                })
            
            # 判断状态
            if result['bot_log']['error_count'] > 10:
                result['status'] = 'warning'
                result['health'] = '⚠️'
            if result['bot_log']['error_count'] > 50:
                result['status'] = 'critical'
                result['health'] = '❌'
                
        except Exception as e:
            self.logger.error(f"检查日志文件失败: {e}")
            result['status'] = 'error'
            result['error'] = str(e)
            result['health'] = '❌'
        
        return result
    
    def check_configuration(self) -> Dict[str, Any]:
        """检查配置文件"""
        result = {
            'env_file': {'exists': False, 'valid': False},
            'core_files': {'bot_py': False, 'py_py': False, 'requirements_txt': False, 'guard_py': False},
            'dependencies': {'installed': [], 'missing': []},
            'autostart': {'enabled': False, 'service_exists': False},
            'status': 'normal',
            'health': '✅'
        }
        
        try:
            # 检查.env文件
            env_file = PROJECT_DIR / '.env'
            if env_file.exists():
                result['env_file']['exists'] = True
                # 简单验证
                with open(env_file, 'r') as f:
                    content = f.read()
                    if 'BOT_TOKEN=' in content and 'CHAT_ID=' in content:
                        result['env_file']['valid'] = True
            
            # 检查核心文件
            result['core_files']['bot_py'] = (PROJECT_DIR / 'bot.py').exists()
            result['core_files']['py_py'] = (PROJECT_DIR / 'py.py').exists()
            result['core_files']['requirements_txt'] = (PROJECT_DIR / 'requirements.txt').exists()
            result['core_files']['guard_py'] = (PROJECT_DIR / 'guard.py').exists()
            
            # 检查依赖
            required_deps = ['telegram', 'dotenv', 'Crypto', 'schedule', 'psutil']
            for dep in required_deps:
                try:
                    __import__(dep)
                    result['dependencies']['installed'].append(dep)
                except ImportError:
                    result['dependencies']['missing'].append(dep)
            
            # 检查开机自启状态
            result['autostart']['service_exists'] = Path(SERVICE_FILE).exists()
            if result['autostart']['service_exists']:
                try:
                    check_result = subprocess.run(
                        ['systemctl', 'is-enabled', SERVICE_NAME],
                        capture_output=True, text=True
                    )
                    result['autostart']['enabled'] = check_result.returncode == 0
                except:
                    result['autostart']['enabled'] = False
            
            # 判断状态
            if not result['env_file']['valid'] or result['dependencies']['missing'] or not all(result['core_files'].values()):
                result['status'] = 'warning'
                result['health'] = '⚠️'
                
        except Exception as e:
            self.logger.error(f"检查配置失败: {e}")
            result['status'] = 'error'
            result['error'] = str(e)
            result['health'] = '❌'
        
        return result
    
    def check_network_connectivity(self) -> Dict[str, Any]:
        """检查网络连接"""
        result = {
            'telegram_api': False,
            'internet': False,
            'status': 'normal',
            'health': '✅',
            'response_time': 0
        }
        
        try:
            # 检查基本网络连接
            start_time = time.time()
            response = subprocess.run(['ping', '-c', '1', '8.8.8.8'], 
                                    capture_output=True, timeout=10)
            result['internet'] = response.returncode == 0
            result['response_time'] = round((time.time() - start_time) * 1000, 2)
            
            # 检查Telegram API连接
            if self.bot:
                try:
                    loop = asyncio.new_event_loop()
                    asyncio.set_event_loop(loop)
                    loop.run_until_complete(self.bot.get_me())
                    result['telegram_api'] = True
                    loop.close()
                except Exception:
                    result['telegram_api'] = False
            
            if not result['internet'] or not result['telegram_api']:
                result['status'] = 'warning'
                result['health'] = '⚠️'
                
        except Exception as e:
            self.logger.error(f"检查网络连接失败: {e}")
            result['status'] = 'error'
            result['error'] = str(e)
            result['health'] = '❌'
        
        return result
    
    def perform_daily_check(self) -> Dict[str, Any]:
        """执行每日自检"""
        self.logger.info("开始执行每日自检")
        current_time = self.get_current_time()
        
        report = {
            'timestamp': current_time.isoformat(),
            'date': current_time.strftime('%Y-%m-%d'),
            'time': current_time.strftime('%H:%M:%S'),
            'timezone': 'Asia/Shanghai',
            'checks': {
                'bot_process': self.check_bot_process(),
                'system_resources': self.check_system_resources(),
                'log_files': self.check_log_files(),
                'configuration': self.check_configuration(),
                'network': self.check_network_connectivity()
            },
            'overall_status': 'normal',
            'overall_health': '✅'
        }
        
        # 判断整体状态
        warning_count = sum(1 for check in report['checks'].values() 
                          if check.get('status') == 'warning')
        error_count = sum(1 for check in report['checks'].values() 
                        if check.get('status') in ['error', 'critical'])
        
        if error_count > 0:
            report['overall_status'] = 'critical'
            report['overall_health'] = '❌'
        elif warning_count > 0:
            report['overall_status'] = 'warning'
            report['overall_health'] = '⚠️'
        
        # 保存报告
        log_files = get_log_files()
        report_file = log_files['report_file']
        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        self.daily_report = report
        self.logger.info(f"每日自检完成，状态: {report['overall_status']}，报告已保存: {report_file}")
        
        return report
    
    def generate_markdown_report(self, report: Dict[str, Any]) -> str:
        """生成Markdown格式的报告"""
        
        # 报告头部
        md = f"""# 🛡️ FinalUnlock 系统自检报告

---

## 📊 报告概览

| 项目 | 值 |
|------|----|  
| 📅 检查日期 | {report['date']} |
| ⏰ 检查时间 | {report['time']} ({report['timezone']}) |
| 🎯 整体状态 | {report['overall_health']} {report['overall_status'].upper()} |
| 🔄 报告版本 | Guard v2.1 |

---

## 🔍 详细检查结果

"""
        
        # 机器人进程检查
        bot_check = report['checks']['bot_process']
        md += f"""### 🤖 机器人进程状态

| 检查项 | 状态 | 详情 |
|--------|------|------|
| 运行状态 | {bot_check['health']} {bot_check['status']} | {bot_check['details']} |

---

"""
        
        # 系统资源检查
        sys_res = report['checks']['system_resources']
        if 'error' not in sys_res:
            md += f"""### 💻 系统资源监控

| 资源类型 | 使用情况 | 状态 | 详细信息 |
|----------|----------|------|----------|
| CPU | {sys_res['cpu_percent']}% | {sys_res['health']} | 处理器负载 |
| 内存 | {sys_res['memory_percent']}% | {sys_res['health']} | {sys_res['memory_available_gb']} GB / {sys_res['memory_total_gb']} GB 可用 |
| 磁盘 | {sys_res['disk_percent']}% | {sys_res['health']} | {sys_res['disk_free_gb']} GB / {sys_res['disk_total_gb']} GB 可用 |

---

"""
        
        # 日志文件检查
        log_check = report['checks']['log_files']
        md += f"""### 📋 日志文件分析

#### 🤖 Bot 日志
| 项目 | 值 | 状态 |
|------|----|----- |
| 文件存在 | {'✅ 是' if log_check['bot_log']['exists'] else '❌ 否'} | {log_check['health']} |
| 文件大小 | {log_check['bot_log']['size_mb']} MB | - |
| 最后更新 | {log_check['bot_log']['last_modified'] or '未知'} | - |
| 错误数量 | {log_check['bot_log']['error_count']} | {'✅ 正常' if log_check['bot_log']['error_count'] <= 10 else '⚠️ 需关注'} |
| 警告数量 | {log_check['bot_log']['warning_count']} | {'✅ 正常' if log_check['bot_log']['warning_count'] <= 20 else '⚠️ 需关注'} |

#### 🛡️ Guard 日志
| 项目 | 值 |
|------|----|  
| 文件存在 | {'✅ 是' if log_check['guard_log']['exists'] else '❌ 否'} |
| 文件大小 | {log_check['guard_log']['size_mb']} MB |
| 最后更新 | {log_check['guard_log']['last_modified'] or '未知'} |

---

"""
        
        # 配置检查
        config_check = report['checks']['configuration']
        md += f"""### ⚙️ 配置文件检查

#### 📄 环境配置
| 项目 | 状态 | 说明 |
|------|------|------|
| .env 文件 | {'✅ 存在' if config_check['env_file']['exists'] else '❌ 缺失'} | 环境变量配置文件 |
| 配置有效性 | {'✅ 有效' if config_check['env_file']['valid'] else '❌ 无效'} | Bot Token 和 Chat ID 配置 |

#### 📁 核心文件
| 文件名 | 状态 | 说明 |
|--------|------|------|
| bot.py | {'✅ 存在' if config_check['core_files']['bot_py'] else '❌ 缺失'} | 主机器人程序 |
| py.py | {'✅ 存在' if config_check['core_files']['py_py'] else '❌ 缺失'} | 核心算法模块 |
| guard.py | {'✅ 存在' if config_check['core_files']['guard_py'] else '❌ 缺失'} | 守护进程程序 |
| requirements.txt | {'✅ 存在' if config_check['core_files']['requirements_txt'] else '❌ 缺失'} | 依赖包列表 |

#### 📦 依赖包状态
| 状态 | 包列表 |
|------|--------|
| ✅ 已安装 | {', '.join(config_check['dependencies']['installed']) if config_check['dependencies']['installed'] else '无'} |
| ❌ 缺失 | {', '.join(config_check['dependencies']['missing']) if config_check['dependencies']['missing'] else '无'} |

#### 🚀 开机自启状态
| 项目 | 状态 | 说明 |
|------|------|------|
| 服务文件 | {'✅ 存在' if config_check['autostart']['service_exists'] else '❌ 缺失'} | systemd 服务文件 |
| 开机自启 | {'✅ 已启用' if config_check['autostart']['enabled'] else '❌ 未启用'} | Guard 开机自启状态 |

---

"""
        
        # 网络连接检查
        network_check = report['checks']['network']
        md += f"""### 🌐 网络连接检查

| 连接类型 | 状态 | 响应时间 | 说明 |
|----------|------|----------|------|
| 互联网连接 | {'✅ 正常' if network_check['internet'] else '❌ 异常'} | {network_check.get('response_time', 0)} ms | 基础网络连通性 |
| Telegram API | {'✅ 正常' if network_check['telegram_api'] else '❌ 异常'} | - | Bot API 连接状态 |
| 整体网络 | {network_check['health']} {network_check['status']} | - | 综合网络状态 |

---

"""
        
        # 系统建议
        md += """## 📈 系统建议

"""
        
        # 根据检查结果生成建议
        suggestions = []
        
        if bot_check['status'] != 'running':
            suggestions.append("- 🔴 紧急: 机器人进程未运行，请立即检查并重启")
        
        if sys_res.get('cpu_percent', 0) > 80:
            suggestions.append("- 🟡 注意: CPU使用率较高，建议检查系统负载")
        
        if sys_res.get('memory_percent', 0) > 90:
            suggestions.append("- 🟡 注意: 内存使用率较高，建议释放内存")
        
        if sys_res.get('disk_percent', 0) > 90:
            suggestions.append("- 🟡 注意: 磁盘空间不足，建议清理日志")
        
        if log_check['bot_log']['error_count'] > 10:
            suggestions.append("- 🟡 注意: Bot日志中错误较多，建议检查")
        
        if config_check['dependencies']['missing']:
            suggestions.append("- 🟡 注意: 存在缺失的依赖包，建议安装")
        
        if not network_check['telegram_api']:
            suggestions.append("- 🔴 紧急: Telegram API连接异常，请检查网络")
        
        if not config_check['autostart']['enabled']:
            suggestions.append("- 🟡 建议: 启用Guard开机自启，确保系统重启后自动运行")
        
        if not suggestions:
            suggestions.append("- ✅ 系统运行正常，无需特别关注")
        
        md += "\n".join(suggestions)
        
        # 报告尾部
        current_time = self.get_current_time()
        md += f"""

---

## 📞 联系信息

- 🤖 获取最新报告: 发送 /guard 命令
- ⏰ 自动报告时间: 每天 07:00 (Asia/Shanghai)
- 🔍 自检执行时间: 每天 00:00 (Asia/Shanghai)
- 📋 报告生成时间: {current_time.strftime('%Y-%m-%d %H:%M:%S')} (Asia/Shanghai)

---

🛡️ 本报告由 FinalUnlock Guard v2.1 自动生成"""
        
        return md
    
    async def send_report(self, report: Dict[str, Any] = None, is_initial: bool = False):
        """发送报告到Telegram"""
        try:
            if report is None:
                # 查找最新的报告文件
                current_date = datetime.now(SHANGHAI_TZ).strftime('%Y%m%d')
                report_file = PROJECT_DIR / f"daily_report_{current_date}.json"
                
                if report_file.exists():
                    with open(report_file, 'r', encoding='utf-8') as f:
                        report = json.load(f)
                else:
                    self.logger.error("没有找到今日报告文件")
                    return False
            
            # 生成Markdown报告
            message = self.generate_markdown_report(report)
            
            # 添加初始安装提示
            if is_initial:
                initial_msg = """🎉 FinalUnlock 项目安装完成！

✅ 系统已成功安装并配置完成
✅ Guard 守护程序已启动
✅ 自动自检功能已激活
✅ 开机自启功能已配置

📋 自动化时间表:
- 🕛 每天 00:00: 执行全面系统自检
- 🕖 每天 07:00: 自动发送详细报告
- 🤖 随时可用: 发送 /guard 获取最新报告
- 🚀 开机自启: 系统重启后自动运行

---

"""
                message = initial_msg + message
            
            success_count = 0
            for chat_id in self.chat_ids:
                try:
                    await self.bot.send_message(
                        chat_id=chat_id,
                        text=message,
                        parse_mode='Markdown'
                    )
                    success_count += 1
                    self.logger.info(f"报告已发送到 {chat_id}")
                except TelegramError as e:
                    self.logger.error(f"发送报告到 {chat_id} 失败: {e}")
                except Exception as e:
                    self.logger.error(f"发送报告时出现未知错误: {e}")
            
            self.logger.info(f"报告发送完成，成功: {success_count}/{len(self.chat_ids)}")
            return success_count > 0
            
        except Exception as e:
            self.logger.error(f"发送报告过程中出现错误: {e}")
            return False
    
    def send_report_sync(self, report=None, is_initial=False):
        """同步方式发送报告"""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            result = loop.run_until_complete(self.send_report(report, is_initial))
            loop.close()
            return result
        except Exception as e:
            self.logger.error(f"同步发送报告失败: {e}")
            return False
    
    def setup_autostart(self) -> bool:
        """检查并确保开机自启服务存在"""
        try:
            self.logger.info("检查开机自启服务状态...")
            
            # 检查服务是否已存在
            if Path(SERVICE_FILE).exists():
                # 检查是否已启用
                check_enabled = subprocess.run(
                    ['systemctl', 'is-enabled', SERVICE_NAME],
                    capture_output=True, text=True
                )
                
                if check_enabled.returncode == 0:
                    self.logger.info("开机自启服务已存在且已启用")
                    return True
                else:
                    # 存在但未启用，尝试启用
                    try:
                        subprocess.run(['sudo', 'systemctl', 'enable', SERVICE_NAME], check=True)
                        self.logger.info("开机自启服务已启用")
                        return True
                    except subprocess.CalledProcessError:
                        self.logger.error("启用开机自启服务失败")
                        return False
            else:
                self.logger.warning("开机自启服务文件不存在，请使用主管理脚本创建")
                return False
            
        except Exception as e:
            self.logger.error(f"检查开机自启失败: {e}")
            return False
    
    def remove_autostart(self) -> bool:
        """移除开机自启"""
        try:
            self.logger.info("开始移除Guard开机自启...")
            
            # 停止服务
            subprocess.run(['sudo', 'systemctl', 'stop', SERVICE_NAME], check=False)
            
            # 禁用服务
            subprocess.run(['sudo', 'systemctl', 'disable', SERVICE_NAME], check=False)
            
            # 删除服务文件
            if Path(SERVICE_FILE).exists():
                subprocess.run(['sudo', 'rm', SERVICE_FILE], check=True)
            
            # 重新加载systemd
            subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
            
            self.logger.info("Guard开机自启已移除")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"移除开机自启失败 (命令执行错误): {e}")
            return False
        except Exception as e:
            self.logger.error(f"移除开机自启失败: {e}")
            return False
    
    def check_autostart_status(self) -> Dict[str, Any]:
        """检查开机自启状态"""
        result = {
            'service_exists': False,
            'enabled': False,
            'active': False,
            'status': 'unknown'
        }
        
        try:
            # 检查服务文件是否存在
            result['service_exists'] = Path(SERVICE_FILE).exists()
            
            if result['service_exists']:
                # 检查是否启用
                check_enabled = subprocess.run(
                    ['systemctl', 'is-enabled', SERVICE_NAME],
                    capture_output=True, text=True
                )
                result['enabled'] = check_enabled.returncode == 0
                
                # 检查是否活跃
                check_active = subprocess.run(
                    ['systemctl', 'is-active', SERVICE_NAME],
                    capture_output=True, text=True
                )
                result['active'] = check_active.returncode == 0
                
                # 获取状态
                if result['enabled'] and result['active']:
                    result['status'] = 'running'
                elif result['enabled']:
                    result['status'] = 'enabled'
                else:
                    result['status'] = 'disabled'
            else:
                result['status'] = 'not_installed'
                
        except Exception as e:
            self.logger.error(f"检查开机自启状态失败: {e}")
            result['status'] = 'error'
        
        return result
    
    def schedule_tasks(self):
        """安排定时任务"""
        # 每天0点执行自检
        schedule.every().day.at("00:00").do(self.perform_daily_check)
        
        # 每天7点发送报告 - 使用同步方式
        schedule.every().day.at("07:00").do(self.send_report_sync)
        
        self.logger.info("定时任务已安排: 0点自检，7点发送报告")
    
    def run_daemon(self):
        """运行守护进程"""
        try:
            self.logger.info("Guard 守护进程启动")
            
            # 保存PID
            with open(GUARD_PID_FILE, 'w') as f:
                f.write(str(os.getpid()))
            
            # 安排定时任务
            self.schedule_tasks()
            
            # 首次运行时执行自检
            if not any(PROJECT_DIR.glob("daily_report_*.json")):
                self.logger.info("首次运行，执行初始自检")
                self.perform_daily_check()
            
            # 主循环
            while True:
                schedule.run_pending()
                time.sleep(60)  # 每分钟检查一次
                
        except KeyboardInterrupt:
            self.logger.info("收到中断信号，Guard 守护进程停止")
        except Exception as e:
            self.logger.error(f"Guard 守护进程运行出错: {e}")
        finally:
            # 清理PID文件
            if GUARD_PID_FILE.exists():
                GUARD_PID_FILE.unlink()

def main():
    """主函数"""
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        guard = SystemGuard()
        
        if command == "check":
            # 手动执行自检
            report = guard.perform_daily_check()
            print(f"自检完成，状态: {report['overall_status']}")
            
        elif command == "report":
            # 手动发送报告
            success = guard.send_report_sync()
            print("报告发送完成" if success else "报告发送失败")
            
        elif command == "initial":
            # 初始安装后发送报告
            report = guard.perform_daily_check()
            success = guard.send_report_sync(report, is_initial=True)
            print("初始报告发送完成" if success else "初始报告发送失败")
            
        elif command == "daemon":
            # 运行守护进程
            guard.run_daemon()
            
        elif command == "autostart":
            # 设置开机自启
            if guard.setup_autostart():
                print("✅ Guard开机自启设置成功")
                print("💡 服务管理命令:")
                print(f"   启动: sudo systemctl start {SERVICE_NAME}")
                print(f"   停止: sudo systemctl stop {SERVICE_NAME}")
                print(f"   状态: sudo systemctl status {SERVICE_NAME}")
                print(f"   日志: journalctl -u {SERVICE_NAME} -f")
            else:
                print("❌ Guard开机自启设置失败")
                
        elif command == "remove-autostart":
            # 移除开机自启
            if guard.remove_autostart():
                print("✅ Guard开机自启已移除")
            else:
                print("❌ 移除Guard开机自启失败")
                
        elif command == "status":
            # 检查开机自启状态
            status = guard.check_autostart_status()
            print(f"📊 Guard开机自启状态:")
            print(f"   服务文件: {'✅ 存在' if status['service_exists'] else '❌ 不存在'}")
            print(f"   开机自启: {'✅ 已启用' if status['enabled'] else '❌ 未启用'}")
            print(f"   运行状态: {'✅ 运行中' if status['active'] else '❌ 未运行'}")
            print(f"   整体状态: {status['status']}")
            
        elif command == "start":
            # 启动服务
            try:
                subprocess.run(['sudo', 'systemctl', 'start', SERVICE_NAME], check=True)
                print("✅ Guard服务启动成功")
            except subprocess.CalledProcessError:
                print("❌ Guard服务启动失败")
                
        elif command == "stop":
            # 停止服务
            try:
                subprocess.run(['sudo', 'systemctl', 'stop', SERVICE_NAME], check=True)
                print("✅ Guard服务停止成功")
            except subprocess.CalledProcessError:
                print("❌ Guard服务停止失败")
                
        elif command == "restart":
            # 重启服务
            try:
                subprocess.run(['sudo', 'systemctl', 'restart', SERVICE_NAME], check=True)
                print("✅ Guard服务重启成功")
            except subprocess.CalledProcessError:
                print("❌ Guard服务重启失败")
            
        else:
            print("用法: python guard.py [命令]")
            print("")
            print("可用命令:")
            print("  check           - 执行系统自检")
            print("  report          - 发送报告到Telegram")
            print("  initial         - 发送初始安装报告")
            print("  daemon          - 运行守护进程")
            print("")
            print("开机自启管理:")
            print("  autostart       - 设置开机自启")
            print("  remove-autostart - 移除开机自启")
            print("  status          - 检查开机自启状态")
            print("")
            print("服务管理:")
            print("  start           - 启动Guard服务")
            print("  stop            - 停止Guard服务")
            print("  restart         - 重启Guard服务")
            print("")
            print("示例:")
            print("  python guard.py daemon          # 运行守护进程")
            print("  python guard.py autostart       # 设置开机自启")
            print("  python guard.py status          # 查看状态")
    else:
        # 默认运行守护进程
        guard = SystemGuard()
        guard.run_daemon()

if __name__ == "__main__":
    main()