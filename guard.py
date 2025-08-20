#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FinalUnlock Guard 守护程序 v2.0
自动系统自检和报告发送
作者: AI Assistant
版本: 2.0
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

# 配置
PROJECT_DIR = Path(__file__).parent.absolute()
PID_FILE = PROJECT_DIR / "bot.pid"
BOT_LOG_FILE = PROJECT_DIR / "bot.log"

# 时区设置
SHANGHAI_TZ = timezone(timedelta(hours=8))

# 动态日志文件名（按日期）
def get_log_files():
    current_date = datetime.now(SHANGHAI_TZ).strftime('%Y%m%d')
    return {
        'guard_log': PROJECT_DIR / f"guard_{current_date}.log",
        'report_file': PROJECT_DIR / f"daily_report_{current_date}.json"
    }

# 删除第323-340行的错误代码：
# 这些行包含重复的class定义和错误的缩进

# 确保SystemGuard类的完整性，包含以下方法：
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
                    else:
                        result['details'] = f'PID {pid} 不是bot.py进程'
                else:
                    result['details'] = f'PID {pid} 进程不存在'
            else:
                result['details'] = 'PID文件不存在'
                
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
                    asyncio.run(self.bot.get_me())
                    result['telegram_api'] = True
                except:
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
        """执行每日自检 - 报告文件永久保存"""
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
        
        # 保存报告 - 按日期命名，永久保存
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

## 📊 **报告概览**

| 项目 | 值 |
|------|----|
| 📅 **检查日期** | `{report['date']}` |
| ⏰ **检查时间** | `{report['time']} ({report['timezone']})` |
| 🎯 **整体状态** | {report['overall_health']} **{report['overall_status'].upper()}** |
| 🔄 **报告版本** | `Guard v2.0` |

---

## 🔍 **详细检查结果**

"""
        
        # 机器人进程检查
        bot_check = report['checks']['bot_process']
        md += f"""### 🤖 **机器人进程状态**

| 检查项 | 状态 | 详情 |
|--------|------|------|
| **运行状态** | {bot_check['health']} `{bot_check['status']}` | {bot_check['details']} |
"""
        
        if bot_check['status'] == 'running':
            md += f"""
CPU: {report['checks']['bot_process']['cpu_percent']}%
内存: {report['checks']['bot_process']['memory_mb']} MB
运行时间: {report['checks']['bot_process']['uptime']}"""
        
        md += "\n---\n\n"
        
        # 系统资源检查
        sys_res = report['checks']['system_resources']
        if 'error' not in sys_res:
            md += f"""### 💻 **系统资源监控**

| 资源类型 | 使用情况 | 状态 | 详细信息 |
|----------|----------|------|----------|
| **CPU** | `{sys_res['cpu_percent']}%` | {sys_res['health']} | 处理器负载 |
| **内存** | `{sys_res['memory_percent']}%` | {sys_res['health']} | `{sys_res['memory_available_gb']} GB` / `{sys_res['memory_total_gb']} GB` 可用 |
| **磁盘** | `{sys_res['disk_percent']}%` | {sys_res['health']} | `{sys_res['disk_free_gb']} GB` / `{sys_res['disk_total_gb']} GB` 可用 |

"""
        else:
            md += f"""### 💻 **系统资源监控**

❌ **检查失败**: {sys_res.get('error', '未知错误')}

"""
        
        md += "---\n\n"
        
        # 日志文件检查
        log_check = report['checks']['log_files']
        md += f"""### 📋 **日志文件分析**

#### 🤖 Bot 日志
| 项目 | 值 | 状态 |
|------|----|----- |
| **文件存在** | {'✅ 是' if log_check['bot_log']['exists'] else '❌ 否'} | {log_check['health']} |
| **文件大小** | `{log_check['bot_log']['size_mb']} MB` | - |
| **最后更新** | `{log_check['bot_log']['last_modified'] or '未知'}` | - |
| **错误数量** | `{log_check['bot_log']['error_count']}` | {'⚠️ 需关注' if log_check['bot_log']['error_count'] > 10 else '✅ 正常'} |
| **警告数量** | `{log_check['bot_log']['warning_count']}` | {'⚠️ 需关注' if log_check['bot_log']['warning_count'] > 20 else '✅ 正常'} |

#### 🛡️ Guard 日志
| 项目 | 值 |
|------|----|  
| **文件存在** | {'✅ 是' if log_check['guard_log']['exists'] else '❌ 否'} |
| **文件大小** | `{log_check['guard_log']['size_mb']} MB` |
| **最后更新** | `{log_check['guard_log']['last_modified'] or '未知'}` |

"""
        
        md += "---\n\n"
        
        # 配置检查
        config_check = report['checks']['configuration']
        md += f"""### ⚙️ **配置文件检查**

#### 📄 环境配置
| 项目 | 状态 | 说明 |
|------|------|------|
| **`.env` 文件** | {'✅ 存在' if config_check['env_file']['exists'] else '❌ 缺失'} | 环境变量配置文件 |
| **配置有效性** | {'✅ 有效' if config_check['env_file']['valid'] else '❌ 无效'} | Bot Token 和 Chat ID 配置 |

#### 📁 核心文件
| 文件名 | 状态 | 说明 |
|--------|------|------|
| **`bot.py`** | {'✅ 存在' if config_check['core_files']['bot_py'] else '❌ 缺失'} | 主机器人程序 |
| **`py.py`** | {'✅ 存在' if config_check['core_files']['py_py'] else '❌ 缺失'} | 核心算法模块 |
| **`guard.py`** | {'✅ 存在' if config_check['core_files']['guard_py'] else '❌ 缺失'} | 守护进程程序 |
| **`requirements.txt`** | {'✅ 存在' if config_check['core_files']['requirements_txt'] else '❌ 缺失'} | 依赖包列表 |

#### 📦 依赖包状态
| 状态 | 包列表 |
|------|--------|
| **✅ 已安装** | `{', '.join(config_check['dependencies']['installed']) if config_check['dependencies']['installed'] else '无'}` |
| **❌ 缺失** | `{', '.join(config_check['dependencies']['missing']) if config_check['dependencies']['missing'] else '无'}` |

"""
        
        md += "---\n\n"
        
        # 网络连接检查
        network_check = report['checks']['network']
        md += f"""### 🌐 **网络连接检查**

| 连接类型 | 状态 | 响应时间 | 说明 |
|----------|------|----------|------|
| **互联网连接** | {'✅ 正常' if network_check['internet'] else '❌ 异常'} | `{network_check.get('response_time', 0)} ms` | 基础网络连通性 |
| **Telegram API** | {'✅ 正常' if network_check['telegram_api'] else '❌ 异常'} | - | Bot API 连接状态 |
| **整体网络** | {network_check['health']} `{network_check['status']}` | - | 综合网络状态 |

"""
        
        # 报告尾部
        current_time = self.get_current_time()
        md += f"""---

## 📈 **系统建议**

"""
        
        # 根据检查结果生成建议
        suggestions = []
        
        if bot_check['status'] != 'running':
            suggestions.append("🔴 **紧急**: 机器人进程未运行，请立即检查并重启")
        
        if sys_res.get('cpu_percent', 0) > 80:
            suggestions.append("🟡 **注意**: CPU使用率较高，建议检查系统负载")
        
        if sys_res.get('memory_percent', 0) > 90:
            suggestions.append("🟡 **注意**: 内存使用率较高，建议释放内存或增加内存")
        
        if sys_res.get('disk_percent', 0) > 90:
            suggestions.append("🟡 **注意**: 磁盘空间不足，建议清理日志或扩展存储")
        
        if log_check['bot_log']['error_count'] > 10:
            suggestions.append("🟡 **注意**: Bot日志中错误数量较多，建议检查错误原因")
        
        if config_check['dependencies']['missing']:
            suggestions.append(f"🔴 **紧急**: 缺少依赖包 `{', '.join(config_check['dependencies']['missing'])}`，请安装")
        
        if not network_check['internet'] or not network_check['telegram_api']:
            suggestions.append("🔴 **紧急**: 网络连接异常，请检查网络配置")
        
        if not suggestions:
            suggestions.append("✅ **良好**: 系统运行正常，无需特别关注")
        
        for suggestion in suggestions:
            md += f"- {suggestion}\n"
        
        md += f"""\n---

## 📞 **联系信息**

- 🤖 **获取最新报告**: 发送 `/guard` 命令
- ⏰ **自动报告时间**: 每天 `07:00` (Asia/Shanghai)
- 🔍 **自检执行时间**: 每天 `00:00` (Asia/Shanghai)
- 📋 **报告生成时间**: `{current_time.strftime('%Y-%m-%d %H:%M:%S')} (Asia/Shanghai)`

---

*🛡️ 本报告由 FinalUnlock Guard v2.0 自动生成*
"""
        
        return md
    
    async def send_report(self, report: Dict[str, Any] = None, is_initial: bool = False):
        """发送报告到Telegram"""
        if report is None:
            # 查找最新的报告文件
            current_date = datetime.now(SHANGHAI_TZ).strftime('%Y%m%d')
            report_file = PROJECT_DIR / f"daily_report_{current_date}.json"
            
            if report_file.exists():
                with open(report_file, 'r', encoding='utf-8') as f:
                    report = json.load(f)
            else:
                self.logger.error("没有找到今日报告文件")
                return
        
        # 生成Markdown报告
        message = self.generate_markdown_report(report)
        
        # 添加初始安装提示
        if is_initial:
            initial_msg = """🎉 **FinalUnlock 项目安装完成！**

✅ 系统已成功安装并配置完成
✅ Guard 守护程序已启动
✅ 自动自检功能已激活

📋 **自动化时间表**:
- 🕛 **每天 00:00**: 执行全面系统自检
- 🕖 **每天 07:00**: 自动发送详细报告
- 🤖 **随时可用**: 发送 `/guard` 获取最新报告

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
    
    def schedule_tasks(self):
        """安排定时任务"""
        # 每天0点执行自检
        schedule.every().day.at("00:00").do(self.perform_daily_check)
        
        # 每天7点发送报告
        schedule.every().day.at("07:00").do(lambda: asyncio.run(self.send_report()))
        
        self.logger.info("定时任务已安排: 0点自检，7点发送报告")
    
    def run_daemon(self):
        """运行守护进程"""
        self.logger.info("Guard 守护进程启动")
        
        # 安排定时任务
        self.schedule_tasks()
        
        # 启动时执行一次自检（如果是首次运行）
        current_date = datetime.now(SHANGHAI_TZ).strftime('%Y%m%d')
        report_file = PROJECT_DIR / f"daily_report_{current_date}.json"
        if not report_file.exists():
            self.logger.info("首次运行，执行初始自检")
            self.perform_daily_check()
        
        # 主循环
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)  # 每分钟检查一次
        except KeyboardInterrupt:
            self.logger.info("收到中断信号，Guard 守护进程停止")
        except Exception as e:
            self.logger.error(f"Guard 守护进程异常: {e}")
            raise

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
            success = asyncio.run(guard.send_report())
            print("报告发送完成" if success else "报告发送失败")
            
        elif command == "initial":
            # 初始安装后发送报告
            report = guard.perform_daily_check()
            success = asyncio.run(guard.send_report(report, is_initial=True))
            print("初始报告发送完成" if success else "初始报告发送失败")
            
        elif command == "daemon":
            # 运行守护进程
            guard.run_daemon()
            
        else:
            print("用法: python guard.py [check|report|initial|daemon]")
            print("  check   - 执行自检")
            print("  report  - 发送报告")
            print("  initial - 发送初始安装报告")
            print("  daemon  - 运行守护进程")
    else:
        # 默认运行守护进程
        guard = SystemGuard()
        guard.run_daemon()

if __name__ == "__main__":
    main()

# 在guard.py中找到发送报告的函数，添加事件循环处理
import asyncio
import nest_asyncio

# 在发送报告函数开始处添加
def send_report_to_telegram(report_content, chat_ids):
    try:
        # 修复事件循环问题
        try:
            loop = asyncio.get_event_loop()
            if loop.is_closed():
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        # 使用nest_asyncio允许嵌套事件循环
        nest_asyncio.apply()
        
        # 其余发送逻辑...
        
    except Exception as e:
        logger.error(f"发送报告失败: {e}")