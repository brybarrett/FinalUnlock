#!/bin/bash

# FinalShell 激活码机器人一键安装脚本
# 自动适配全局/本地环境
# 项目地址: https://github.com/xymn2023/FinalUnlock

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 显示欢迎信息
clear
echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}  FinalShell 激活码机器人安装器${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}自动适配全局/本地环境${NC}"
echo

# 检查系统
print_message $BLUE "🔍 检查系统环境..."

# 检查是否为Linux系统
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_message $RED "❌ 此脚本仅支持Linux系统"
    exit 1
fi

# 检查是否为root用户
if [[ $EUID -eq 0 ]]; then
    print_message $YELLOW "⚠️ 检测到root用户，建议使用普通用户运行"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 检查git
if ! command -v git &> /dev/null; then
    print_message $RED "❌ 未找到git，正在安装..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    else
        print_message $RED "❌ 无法自动安装git，请手动安装"
        exit 1
    fi
fi

# 检测安装模式
print_message $BLUE "🔍 检测安装模式..."

# 检查是否有写入/usr/local/bin的权限
if [ -w "/usr/local/bin" ]; then
    INSTALL_MODE="global"
    INSTALL_DIR="/usr/local/FinalUnlock"
    print_message $GREEN "✅ 检测到全局安装权限，将进行全局安装"
else
    INSTALL_MODE="local"
    INSTALL_DIR="$HOME/FinalUnlock"
    print_message $YELLOW "⚠️ 无全局安装权限，将进行本地安装"
fi

# 询问用户安装模式
echo
print_message $CYAN "请选择安装模式:"
echo -e "${CYAN}[1] 全局安装 (推荐) - 所有用户可用${NC}"
echo -e "${CYAN}[2] 本地安装 - 仅当前用户可用${NC}"
echo -e "${CYAN}[3] 自动检测 (当前: $INSTALL_MODE)${NC}"
echo

read -p "请选择 [1-3]: " install_choice

case $install_choice in
    1)
        INSTALL_MODE="global"
        INSTALL_DIR="/usr/local/FinalUnlock"
        print_message $GREEN "✅ 选择全局安装模式"
        ;;
    2)
        INSTALL_MODE="local"
        INSTALL_DIR="$HOME/FinalUnlock"
        print_message $GREEN "✅ 选择本地安装模式"
        ;;
    3)
        print_message $GREEN "✅ 使用自动检测模式: $INSTALL_MODE"
        ;;
    *)
        print_message $YELLOW "⚠️ 无效选择，使用自动检测模式: $INSTALL_MODE"
        ;;
esac

# 检查安装目录
if [ -d "$INSTALL_DIR" ]; then
    print_message $YELLOW "⚠️ 目录已存在: $INSTALL_DIR"
    read -p "是否覆盖? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    else
        print_message $YELLOW "❌ 安装取消"
        exit 1
    fi
fi

# 创建安装目录
print_message $BLUE "📁 创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 下载项目
print_message $BLUE "📥 正在下载项目..."
cd "$INSTALL_DIR"
git clone https://github.com/xymn2023/FinalUnlock.git .

if [ $? -ne 0 ]; then
    print_message $RED "❌ 项目下载失败"
    exit 1
fi

# 设置执行权限
chmod +x start.sh
chmod +x install.sh
chmod +x test_functions.sh

# 创建全局命令
if [ "$INSTALL_MODE" = "global" ]; then
    print_message $BLUE "🔧 创建全局命令..."
    
    # 创建全局命令
    sudo tee /usr/local/bin/fn-bot > /dev/null << EOF
#!/bin/bash
"$INSTALL_DIR/start.sh" "\$@"
EOF
    sudo chmod +x /usr/local/bin/fn-bot
    
    print_message $GREEN "✅ 全局命令创建成功: fn-bot"
else
    print_message $BLUE "🔧 创建本地命令..."
    
    # 创建本地命令
    local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    
    tee "$local_bin/fn-bot" > /dev/null << EOF
#!/bin/bash
"$INSTALL_DIR/start.sh" "\$@"
EOF
    chmod +x "$local_bin/fn-bot"
    
    # 检查PATH
    if [[ ":$PATH:" != *":$local_bin:"* ]]; then
        print_message $YELLOW "⚠️ 需要将 $local_bin 添加到PATH"
        echo -e "${CYAN}请将以下行添加到 ~/.bashrc 或 ~/.zshrc:${NC}"
        echo -e "${YELLOW}export PATH=\"\$PATH:$local_bin\"${NC}"
    fi
    
    print_message $GREEN "✅ 本地命令创建成功: fn-bot"
fi

# 创建桌面快捷方式（如果支持）
if command -v xdg-desktop-menu &> /dev/null; then
    print_message $BLUE "🖥️ 创建桌面快捷方式..."
    
    desktop_file="$HOME/.local/share/applications/finalshell-bot.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=FinalShell Bot
Comment=FinalShell 激活码机器人管理器
Exec=$INSTALL_DIR/start.sh
Icon=terminal
Terminal=true
Categories=Utility;
EOF
    
    print_message $GREEN "✅ 桌面快捷方式创建成功"
fi

print_message $GREEN "✅ 安装完成！"
echo
print_message $CYAN "🚀 正在启动机器人管理界面..."
print_message $YELLOW "💡 首次运行需要配置Bot Token和Chat ID"
print_message $BLUE "📋 请按提示完成配置后即可启动机器人"
sleep 2

# 直接启动管理脚本
if [ -f "$INSTALL_DIR/start.sh" ]; then
    cd "$INSTALL_DIR"
    exec "$INSTALL_DIR/start.sh"
else
    print_message $RED "❌ 管理脚本不存在，请手动运行:"
    if [ "$INSTALL_MODE" = "global" ]; then
        print_message $YELLOW "fn-bot"
    else
        print_message $YELLOW "cd $INSTALL_DIR && ./start.sh"
    fi
fi 