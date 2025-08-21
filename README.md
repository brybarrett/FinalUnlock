# 🚀 FinalUnlock - FinalShell激活码生成机器人

> 一键安装，无限使用，稳定运行的Telegram机器人

## 📋 项目简介

FinalUnlock是一个基于Python的Telegram机器人，专门用于生成FinalShell激活码。采用极简设计，一键安装，开机自启，7×24小时稳定运行。

### ✨ 核心特性

- 🎯 **一键安装** - 自动检测环境，安装依赖，配置服务
- 🔧 **智能管理** - 全局命令`fn-bot`，简单易用
- 🛡️ **稳定运行** - systemd服务管理，自动重启保活
- 🚀 **无限使用** - 移除使用次数限制
- 👑 **管理功能** - 用户统计、拉黑管理、广播消息
- 📊 **数据统计** - 完整的用户使用记录

### 🎮 支持版本

- FinalShell < 3.9.6
- FinalShell ≥ 3.9.6  
- FinalShell 4.5
- FinalShell 4.6.5

## 🔧 安装部署

### 系统要求

- Linux系统（Ubuntu/Debian）
- Python 3.7+
- root权限

### 使用说明

1 .下载

```
git clone https://github.com/xymn2023/FinalUnlock.git
```



2.进入目录

```
cd FinalUnlock
```



```bash
# 3. 创建配置文件
cat > .env << 'EOF'
BOT_TOKEN=你的机器人Token
CHAT_ID=你的ChatID
EOF

# 4. 一键安装
sudo bash install.sh
```

### 获取Token和Chat ID

**Bot Token:**
1. Telegram搜索 @BotFather
2. 发送 `/newbot` 创建机器人
3. 复制返回的Token

**Chat ID:**
1. Telegram搜索 @userinfobot  
2. 发送任意消息
3. 复制返回的数字ID

## 🎮 使用方法

### 管理命令

```bash
fn-bot          # 进入管理界面
fn-bot start    # 启动机器人
fn-bot stop     # 停止机器人
fn-bot restart  # 重启机器人
fn-bot status   # 查看状态
fn-bot logs     # 查看日志
```

### Telegram机器人命令

**用户命令:**
- `/start` - 开始使用机器人
- `/help` - 查看帮助信息
- 直接发送机器码 - 生成激活码

**管理员命令:**
- `/stats` - 查看使用统计
- `/users` - 查看用户列表
- `/ban <用户ID>` - 拉黑用户
- `/unban <用户ID>` - 解除拉黑
- `/say <消息>` - 广播消息

## 📂 项目结构

```
FinalUnlock/
├── bot.py           # 机器人主程序
├── py.py            # 激活码生成核心算法
├── manage.sh        # 一键管理脚本
├── install.sh       # 一键安装脚本
├── requirements.txt # Python依赖
├── .env            # 配置文件
└── README.md       # 项目说明
```

## 🔍 故障排除

### 查看服务状态
```bash
systemctl status finalunlock-bot
```

### 查看实时日志
```bash
fn-bot logs
# 或
journalctl -u finalunlock-bot -f
```

### 重新配置
```bash
fn-bot  # 进入管理界面，选择重新配置
```

### 手动测试
```bash
cd /usr/local/FinalUnlock
source venv/bin/activate
python bot.py
```

## ⚙️ 技术特点

- **systemd服务管理** - 开机自启，自动重启
- **虚拟环境隔离** - 依赖独立，不污染系统
- **智能环境检测** - 自动安装缺失依赖
- **配置文件验证** - 启动前检查配置有效性
- **进程锁机制** - 防止重复启动
- **完整错误处理** - 详细的日志和错误提示

## 📄 开源协议

MIT License - 自由使用，修改和分发

## ⚠️ 使用声明

- 本项目仅供学习交流使用
- 请合理使用，滥用将被拉黑
- 作者不承担任何法律责任

---

**🎉 享受简单高效的FinalShell激活码生成体验！**