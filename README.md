# 🚀 FinalShell 激活码 Telegram 机器人

<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/xymn2023/FinalUnlock?style=flat-square)](https://github.com/xymn2023/FinalUnlock/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/xymn2023/FinalUnlock?style=flat-square)](https://github.com/xymn2023/FinalUnlock/network)
[![GitHub issues](https://img.shields.io/github/issues/xymn2023/FinalUnlock?style=flat-square)](https://github.com/xymn2023/FinalUnlock/issues)
[![GitHub license](https://img.shields.io/github/license/xymn2023/FinalUnlock?style=flat-square)](https://github.com/xymn2023/FinalUnlock/blob/main/LICENSE)

**🎯 一键部署 | 🛡️ 智能守护 | 📊 完整监控 | 🔧 企业级稳定性**

[Demo机器人](https://t.me/FinalUnlock_bot) • [快速开始](#-一键安装) • [功能特性](#-功能特性) 

</div>

---

## 📋 项目简介

**FinalUnlock** 是一个基于 Python 的企业级 Telegram 机器人，专为 FinalShell 激活码自动化分发而设计。项目采用现代化架构，集成了智能守护系统、完整监控体系和自动化运维功能，确保7×24小时稳定运行。

### 🎯 核心优势

- **🚀 一键部署**: 傻瓜式全自动安装，无需复杂配置
- **🛡️ 智能守护**: Guard守护程序自动监控和故障恢复
- **📊 企业级监控**: 实时健康检查、资源监控、自动报告
- **🔧 运维自动化**: 自动重启、日志轮转、配置验证
- **🌐 多版本支持**: 支持FinalShell全版本（最高4.6.5）
- **👥 用户管理**: 完整的权限控制和黑名单机制

---

## ⚡ 一键安装

### 🚀 推荐方式（全自动）

```bash
bash <(curl -s https://raw.githubusercontent.com/xymn2023/FinalUnlock/main/onekey_install.sh)
```

**安装过程完全自动化：**
- ✅ 自动检测系统环境
- ✅ 自动创建虚拟环境
- ✅ 自动安装所有依赖
- ✅ 自动配置Bot Token和Chat ID
- ✅ 自动启动机器人和Guard守护程序
- ✅ 自动发送初始自检报告

### 📱 安装后管理

```bash
# 全局管理命令（安装后可在任意目录使用）
fn-bot

# 或进入项目目录
cd /path/to/FinalUnlock
./start.sh
```

---

## 🌟 功能特性

### 🤖 核心机器人功能

| 功能 | 描述 | 状态 |
|------|------|------|
| **多版本支持** | FinalShell < 3.9.6, ≥ 3.9.6, 4.5, 4.6+ | ✅ |
| **智能激活码生成** | 基于机器码自动生成对应版本激活码 | ✅ |
| **用户权限管理** | 管理员/普通用户权限分离 | ✅ |
| **使用次数限制** | 普通用户3次限制，超限自动拉黑 | ✅ |
| **黑名单机制** | 支持手动和自动拉黑/解封 | ✅ |
| **广播功能** | 管理员可向所有用户发送消息 | ✅ |
| **统计分析** | 详细的使用统计和用户分析 | ✅ |
| **数据持久化** | 按日期分文件存储，便于管理 | ✅ |

### 🛡️ Guard 守护系统

| 功能 | 描述 | 状态 |
|------|------|------|
| **自动自检** | 每天00:00执行全面系统检查 | ✅ |
| **定时报告** | 每天00:00自检后立即发送详细Markdown报告 | ✅ |
| **进程监控** | 实时监控机器人进程状态 | ✅ |
| **资源监控** | CPU、内存、磁盘使用率监控 | ✅ |
| **网络检测** | 互联网和Telegram API连通性检查 | ✅ |
| **日志分析** | 自动分析错误和警告日志 | ✅ |
| **配置验证** | 环境变量和依赖包完整性检查 | ✅ |
| **故障恢复** | 自动重启、网络重连、错误处理 | ✅ |

### ⚙️ 运维管理功能

| 功能 | 描述 | 状态 |
|------|------|------|
| **统一管理界面** | 集成Bot和Guard的管理菜单 | ✅ |
| **虚拟环境管理** | 强制虚拟环境隔离 | ✅ |
| **自动更新** | 一键检查和更新到最新版本 | ✅ |
| **日志轮转** | 自动压缩和清理历史日志 | ✅ |
| **配置验证** | 启动前自动验证所有配置 | ✅ |
| **健康检查** | 实时系统健康状态检查 | ✅ |
| **备份恢复** | 自动备份重要配置和数据 | ✅ |
| **安全卸载** | 完整清理所有相关文件 | ✅ |

---

## 🎮 机器人命令

### 👤 用户命令

| 命令 | 功能 | 示例 |
|------|------|------|
| `/start` | 开始使用机器人 | `/start` |
| `/help` | 获取帮助信息 | `/help` |
| `机器码` | 直接发送机器码生成激活码 | `发送你的机器码` |

### 👑 管理员命令

| 命令 | 功能 | 示例 |
|------|------|------|
| `/stats` | 查看使用统计 | `/stats` |
| `/users` | 查看用户列表 | `/users` |
| `/ban <用户ID>` | 拉黑用户 | `/ban 123456789` |
| `/unban <用户ID>` | 解除拉黑 | `/unban 123456789` |
| `/say <内容>` | 广播消息 | `/say 系统维护通知` |
| `/clear` | 清除统计数据 | `/clear` |
| `/cleanup` | 清理日志文件 | `/cleanup` |
| `/guard` | 获取最新自检报告 | `/guard` |

---

## 🔧 管理界面

### 🤖 机器人管理

# ================================
FinalShell 机器人管理菜单

当前状态: ✅ 正在运行 (PID: 12345)

Guard状态: ✅ 正在运行

=== 🤖 机器人管理 ===

[1] 启动/重启机器人

[2] 停止机器人

[3] 日志管理

[4] 检查进程状态

[5] 检查并安装更新

[6] 检查/修复依赖

[7] 重新安装依赖

[8] 检查/修复虚拟环境

[9] 卸载机器人

=== 🛡️ 守护进程管理 ===

[g] Guard 守护进程管理

=== ⚙️ 系统配置 ===

[c] 配置Bot Token和Chat ID

[m] 启动/停止监控守护进程

[s] 显示系统状态

[r] 手动重启机器人

[v] 验证配置

[f] 修复配置

[0] 退出


### 🛡️ Guard 管理

# ================================

Guard 守护程序管理菜单

Guard状态: ✅ 正在运行 (PID: 67890)

=== 🛡️ Guard 进程管理 ===

[1] 启动 Guard 守护进程

[2] 停止 Guard 守护进程

[3] 重启 Guard 守护进程

=== 🔍 自检功能 ===

[4] 手动执行自检

[5] 手动发送报告

=== 📋 日志管理 ===

[6] 查看当前日志

[7] 查看最新报告

[8] 日志文件列表

[9] 查看指定日期日志

[c] 手动清理日志

[0] 返回主菜单



---

## 📊 自动监控报告

### 📤 自动报告时间表

- **🕛 每天 00:00**: 执行全面系统自检并立即发送详细报告到Telegram
- 
- **🤖 随时可用**: 发送 `/guard` 获取最新报告

### 📋 报告内容示例

```markdown
# 🛡️ FinalUnlock 系统自检报告

## 📊 报告概览

| 项目 | 值 |

|------|----|

| 📅 检查日期 | 2024-01-15 |

| ⏰ 检查时间 | 00:00:00 (Asia/Shanghai) |

| 🎯 整体状态 | ✅ NORMAL |

| 🔄 报告版本 | Guard v2.0 |

## 🔍 详细检查结果

### 🤖 机器人进程状态

| 检查项 | 状态 | 详情 |

|--------|------|------|

| 运行状态 | ✅ running | 进程正常运行，PID: 12345 |

| CPU使用率 | 2.5% | 处理器占用情况 |

| 内存使用 | 45.2 MB | 内存占用情况 |

| 运行时长 | 2 days, 14:30:25 | 连续运行时间 |

### 💻 系统资源监控

| 资源类型 | 使用情况 | 状态 |

|----------|----------|------|

| CPU | 15.3% | ✅ |

| 内存 | 45.2% | ✅ |

| 磁盘 | 23.8% | ✅ |

### 📋 日志文件分析

| 项目 | 值 | 状态 |

|------|----|----- |

| Bot日志 | ✅ 存在 | 2.3 MB |

| 错误数量 | 0 | ✅ 正常 |

| 警告数量 | 2 | ✅ 正常 |

### 🌐 网络连接检查

| 连接类型 | 状态 | 响应时间 |

|----------|------|----------|

| 互联网连接 | ✅ 正常 | 45 ms |

| Telegram API | ✅ 正常 | - |
```

---




---

## 🔧 手动安装

### 📋 系统要求

- **操作系统**: Linux (Ubuntu 18.04+, CentOS 7+, Debian 9+)
- **Python版本**: Python 3.7+
- **内存要求**: 最少512MB RAM
- **磁盘空间**: 最少1GB可用空间
- **网络要求**: 能够访问GitHub和Telegram API

### 🐍 环境准备

```bash
# 更新系统包
sudo apt update && sudo apt upgrade -y

# 安装Python和相关工具
sudo apt install -y python3 python3-pip python3-venv git curl

# 验证Python版本
python3 --version
```

### 📦 克隆项目

```bash
# 克隆项目
git clone https://github.com/xymn2023/FinalUnlock.git
cd FinalUnlock

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements.txt
```

### ⚙️ 配置环境

复制配置模板.env

配置内容：
```env
 BOT_TOKEN=bot_token
 CHAT_ID=chat_id

# 示例格式：
# BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
# CHAT_ID=123456789

```

### 🚀 启动服务

```bash
# 设置执行权限
chmod +x start.sh guard.sh

# 启动管理界面
./start.sh
```

---

## 🔍 故障排除

### 🚨 常见问题

#### 1. 机器人无法启动

**症状**: 机器人启动失败或立即退出

**解决方案**:
```bash
# 检查配置
./start.sh
# 选择 [v] 验证配置

# 查看错误日志
tail -f bot.log

# 手动测试
source venv/bin/activate
python bot.py
```

#### 2. Guard守护程序异常

**症状**: 自检报告未按时发送

**解决方案**:
```bash
# 检查Guard状态
./guard.sh
# 选择 [1] 启动Guard

# 手动执行自检
python guard.py check

# 查看Guard日志
tail -f guard_$(date +%Y%m%d).log
```

#### 3. 依赖包问题

**症状**: 导入模块失败

**解决方案**:
```bash
# 重新安装依赖
./start.sh
# 选择 [7] 重新安装依赖

# 或手动安装
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

#### 4. 权限问题

**症状**: 文件无法创建或修改

**解决方案**:
```bash
# 修复文件权限
chmod +x *.sh
chown -R $USER:$USER .

# 检查磁盘空间
df -h
```

### 📞 获取帮助

1. **查看日志**: 所有操作都有详细日志记录
2. **使用验证功能**: `./start.sh` → `[v]` 验证配置
3. **手动测试**: 在虚拟环境中手动运行各组件
4. **提交Issue**: [GitHub Issues](https://github.com/xymn2023/FinalUnlock/issues)

---

## 🔒 安全说明

### 🛡️ 安全特性

- **权限隔离**: 管理员和普通用户严格分离
- **使用限制**: 普通用户有使用次数限制
- **自动拉黑**: 异常行为自动处理
- **日志记录**: 所有操作完整记录
- **环境隔离**: 强制虚拟环境运行

### ⚠️ 使用须知

1. **合理使用**: 请勿滥用激活码生成功能
2. **Token安全**: 妥善保管Bot Token，避免泄露
3. **定期更新**: 建议定期更新到最新版本
4. **监控日志**: 定期检查运行日志和自检报告
5. **备份数据**: 重要配置和数据请及时备份

---

## 🔄 更新日志

### 🆕 v2.0.0 (2025-08-20)

#### 🎉 重大更新
- ✨ **新增Guard守护系统**: 7×24小时自动监控和故障恢复
- 🚀 **全新管理界面**: 统一的菜单系统，支持Guard集成
- 🐍 **强制虚拟环境**: 确保依赖隔离和环境一致性
- 📊 **企业级监控**: 实时健康检查、资源监控、自动报告
- 🔧 **运维自动化**: 自动重启、日志轮转、配置验证

#### 🛡️ Guard守护系统
- 每天00:00自动执行全面系统自检并立即发送详细Markdown报告
- 实时进程监控和自动重启
- 系统资源监控（CPU、内存、磁盘）
- 网络连接检测和自动恢复
- 日志分析和错误统计
- 配置完整性验证

#### ⚙️ 管理功能增强
- 统一的Bot和Guard管理界面
- 一键配置验证和自动修复
- 智能健康检查和状态报告
- 自动日志轮转和清理
- 完整的系统状态监控

#### 🔧 安装和部署
- 全新的一键安装脚本
- 自动虚拟环境创建和管理
- 智能依赖检测和安装
- 自动配置验证和修复
- 完整的卸载和清理功能

### 📋 v1.x.x 历史版本

<details>
<summary>点击查看历史更新</summary>

#### v1.5.0 (2025-06-28)
- 添加一键安装命令，傻瓜式操作
- 添加全局快捷命令 `fn-bot`
- 完善bot管理菜单的各项功能
- 定义bot管理界面所有命令由用户决定执行
- 重定义自动更新功能直接关联项目仓库
- 定义查看日志界面任意键返回管理界面
- 默认屏蔽Ctrl+C快捷键，推荐使用脚本退出功能

#### v1.0.0 (2025-01-21)
- 初始版本发布
- 支持FinalShell多版本激活码生成
- 基础的Telegram机器人功能
- 用户管理和黑名单机制
- 统计数据和日志记录

</details>

---

## 🤝 贡献指南

### 🎯 如何贡献

1. **Fork项目**: 点击右上角Fork按钮
2. **创建分支**: `git checkout -b feature/your-feature`
3. **提交更改**: `git commit -am 'Add some feature'`
4. **推送分支**: `git push origin feature/your-feature`
5. **创建PR**: 在GitHub上创建Pull Request

### 📝 贡献类型

- 🐛 **Bug修复**: 修复已知问题
- ✨ **新功能**: 添加新的功能特性
- 📖 **文档改进**: 完善文档和说明
- 🎨 **代码优化**: 改进代码质量和性能
- 🧪 **测试添加**: 增加测试用例

### 🔍 代码规范

- 遵循PEP 8 Python代码规范
- 添加适当的注释和文档字符串
- 确保新功能有相应的测试
- 提交信息使用英文，格式清晰

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

### 📋 协议要点

- ✅ **商业使用**: 允许商业使用
- ✅ **修改**: 允许修改代码
- ✅ **分发**: 允许分发
- ✅ **私人使用**: 允许私人使用
- ❗ **责任**: 作者不承担任何责任
- ❗ **保证**: 不提供任何保证

---

## 📞 联系方式

- **GitHub**: [xymn2023/FinalUnlock](https://github.com/xymn2023/FinalUnlock)
- **Issues**: [提交问题](https://github.com/xymn2023/FinalUnlock/issues)
- **Demo Bot**: [@FinalUnlock_bot](https://t.me/FinalUnlock_bot)

---

## ⭐ Star History

<a href="https://www.star-history.com/#xymn2023/FinalUnlock&Timeline">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=xymn2023/FinalUnlock&type=Timeline&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=xymn2023/FinalUnlock&type=Timeline" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=xymn2023/FinalUnlock&type=Timeline" />
 </picture>
</a>

---

<div align="center">

**🎉 感谢使用 FinalUnlock！**

如果这个项目对您有帮助，请考虑给我们一个 ⭐ Star！

[⬆️ 回到顶部](#-finalshell-激活码-telegram-机器人)

</div>


