# FinalShell 离线激活码生成工具

该项目是一个 Telegram Bot，旨在提供 FinalShell 的离线激活码生成工具。用户可以通过输入机器码来获取相应的激活码。
# FinalShell最高支持版本4.3.10

 Demo：@FinalUnlock_bot
 
## 特性

- 用户可以输入机器码生成激活码。
- 管理员可以管理用户，包括拉黑和解封用户。
- 提供统计数据追踪功能，包括今日使用的用户数、拉黑用户数、解封用户数等。
- 日志记录功能，将统计信息保存到文件，便于日后查看。

## 功能命令

- `/start` - 显示欢迎信息
- `/help` - 获取帮助信息
- `/stats` - 查看统计数据
- `/ban <用户ID>` - 拉黑用户
- `/unban <用户ID>` - 解除拉黑
- `/clear` - 清除所有计数器数据

## 安装与运行

### 环境要求

- Python 3.6 或更高版本
- 依赖库: `python-telegram-bot, pycryptodome`

### 安装依赖库

1. **创建 Python 虚拟环境**:

   ```bash
   python3 -m venv venv
   source venv/bin/activate  # 激活虚拟环境
   ```

​     

2.安装所需的依赖 

```
 pip install python-telegram-bot==20.8 pycryptodome==3.20.0
```



###  配置

​     在项目目录下创建 `config.json` 文件，内容示例如下：

```
{
   "TOKEN": "YOUR_TELEGRAM_BOT_TOKEN",
   "ADMIN_ID": Telegram ID,  // 管理员的 Telegram ID
   "BLACKLIST": [],
   "usage_data": {},
   "violation_attempts": {},
   "stats_data": {
      "total_users_today": 0,
      "banned_users": 0,
      "unbanned_users": 0
   }
}
```



请确保将 `YOUR_TELEGRAM_BOT_TOKEN` 替换为您创建的 Telegram Bot 的令牌



### 运行项目



**在虚拟环境中启动程序** 

```
python bot.py
```



后台运行

```
nohup python bot.py &
```





### 日志

- 统计数据将保存到以日期命名的 `log_YYYY-MM-DD.txt` 文件中（例如：`log_2023-09-15.txt`），每次调用 `/stats` 命令时追加统计信息。

## 项目结构

.

```
├── bot.py             # 主应用文件
├── config.json        # 配置文件
└── log_YYYY-MM-DD.txt # 每日统计日志文件
```



## 贡献

欢迎对项目进行贡献！如果您有建议或发现问题，您可以提交问题或拉取请求。

## 许可证

该项目根据 MIT 许可证提供。今天的代码和相关文件仅用于学习和研究目的，请遵循相应的软件协议。
