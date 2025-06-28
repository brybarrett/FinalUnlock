# FinalShell 激活码 Telegram 机器人

## 项目简介

本项目是一个基于 Python 的 Telegram 机器人，支持自动生成 FinalShell 各版本激活码，并提供用户管理、统计、广播等功能。适用于个人或团队自动化分发激活码、用户管理等场景。

## 最高支持4.6.5版本，请合理使用 滥用拉黑。
Demo：[@FinalUnlock_bot](https://t.me/FinalUnlock_bot)

#### 特色 ####  傻瓜式全自动安装，安装方式新颖简单方便

## 功能列表
- 支持 FinalShell 多版本激活码自动生成
- 支持 Telegram 机器人常用指令
- 管理员权限控制与黑名单机制
- 用户使用次数限制与自动拉黑
- 统计数据、黑名单、操作日志本地持久化，按天分文件
- 管理员可向所有用户广播消息

## 推荐一键安装--不需要提前输入Bot Token和Chat ID

## 🚀 一键安装命令--全自动

```bash
bash <(curl -s https://raw.githubusercontent.com/xymn2023/FinalUnlock/main/onekey_install.sh)
```


## 手动安装

## 依赖安装

请确保已安装 Python 3.7 及以上版本。

安装依赖：

```bash
pip install python-telegram-bot python-dotenv pycryptodome
```

或使用 requirements.txt：

```bash
pip install -r requirements.txt
```

## 环境配置

在项目根目录下新建 `.env` 文件，内容如下：

```
BOT_TOKEN=你的bot token
CHAT_ID=管理员的Telegram用户ID（多个用英文逗号分隔）
```

- `BOT_TOKEN`：在 @BotFather 创建机器人后获得
- `CHAT_ID`：管理员的 Telegram 用户ID，可通过 @userinfobot 获取

## 运行方法

1. 启动 bot：
   ```bash
   python bot.py
   ```
2. 用户在 Telegram 中与 bot 对话，发送 `/start` 或机器码即可使用。

## 主要命令说明

- `/start`  首次欢迎信息，后续提示直接输入机器码
- `/help`   获取帮助信息
- `/stats`  查看统计数据（仅管理员）
- `/ban <用户ID>`   拉黑用户（仅管理员）
- `/unban <用户ID>`  解除拉黑（仅管理员）
- `/clear`  清除所有计数器数据（仅管理员）
- `/cleanup`  清除日志文件（仅管理员）
- `/say <内容>`  向所有用过 bot 的用户广播信息（仅管理员）

## 数据文件说明

- `stats_YYYYMMDD.json`：统计数据，记录每个用户的使用次数和最后一次使用时间
- `ban_YYYYMMDD.json`：黑名单数据，记录被拉黑的用户ID
- `try_YYYYMMDD.json`：普通用户尝试管理员命令的计数
- `bot.log`：操作日志

## 更新说明

## 更新时间 ## 2025-06-28 13:34:53 
- 1.添加一键安装命令傻瓜式操作，只需要在安装时配置好Bot Token和Chat ID，脚本会自动保存信息与.env文件
- 2.添加全局快捷命令fn--bot 即可唤醒bot管理界面
- 3.完善bot管理菜单的各项功能，默认bot启动于后台运行 退出脚本依然运行
- 4.定义bot管理界面所有命令必须由用户决定是否执行，本身不存在自动执行任意指令，定义卸载命令删除有关FinalUnlock、FinalUnlock.backup等所有文件不会留下任意垃圾
- 5.重定义自动更新功能直接关联项目仓库
- 6.定义查看日志界面任意键返回bot管理界面，默认在脚本页面自动屏蔽ctrl+c快捷键，推荐通过脚本自带的退出功能，避免莫名其妙的bug
- 7.重点说明：脚本所需命令只适用于项目必备的环境依赖，那些基础的依赖需要自行安装
- 8.后续更新方向：无. 有可能继续更新无聊的功能，有可能项目就这样。   全看心情

## 注意事项

- 只有管理员（.env 配置的 CHAT_ID）可使用管理类命令
- 普通用户每个ID最多只能生成三次激活码，超限自动拉黑
- 管理员不受次数限制
- 只有和 bot 聊天过的用户才能收到广播
- 统计、黑名单等数据每日自动分文件保存，便于管理和追溯

## 贡献与反馈

如有建议或问题，欢迎提交 issue 或 PR。 
