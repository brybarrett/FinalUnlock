#!/bin/bash

# FinalShell 激活码机器人一键安装脚本 v3.0
# 强制虚拟环境安装
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

# 配置Bot Token和Chat ID
configure_bot() {
    print_message $BLUE "⚙️ 配置Bot Token和Chat ID..."
    
    # 等待用户确认开始配置
    print_message $YELLOW "💡 即将开始配置Bot Token和Chat ID"
    print_message $CYAN "📋 请确保您已经准备好Bot Token和Chat ID"
    echo
    read -p "按回车键开始配置..." -r
    echo
    
    # 配置Bot Token
    while true; do
        print_message $BLUE "📝 第一步：配置Bot Token"
        print_message $CYAN "请输入您的Bot Token (从 @BotFather 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @BotFather，发送 /newbot 创建机器人"
        
        # 获取Bot Token
        while true; do
            read -p "Bot Token: " BOT_TOKEN
            
            if [ -n "$BOT_TOKEN" ]; then
                # 简单验证Bot Token格式
                if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
                    print_message $GREEN "✅ Bot Token格式正确"
                    break
                else
                    print_message $RED "❌ Bot Token格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
                fi
            else
                print_message $RED "❌ Bot Token不能为空"
            fi
        done
        
        # 确认Bot Token
        echo
        print_message $BLUE "📋 您输入的Bot Token: $BOT_TOKEN"
        read -p "确认Bot Token正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Bot Token已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Bot Token"
            echo
        fi
    done
    
    echo
    
    # 配置Chat ID
    while true; do
        print_message $BLUE "📝 第二步：配置Chat ID"
        print_message $CYAN "请输入管理员的Chat ID (可通过 @userinfobot 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @userinfobot，发送任意消息获取ID"
        echo
        read -p "准备好Chat ID后按回车键继续..." -r
        echo
        
        # 获取Chat ID
        while true; do
            read -p "Chat ID: " CHAT_ID
            
            if [ -n "$CHAT_ID" ]; then
                # 简单验证Chat ID格式
                if [[ "$CHAT_ID" =~ ^[0-9]+$ ]] || [[ "$CHAT_ID" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
                    print_message $GREEN "✅ Chat ID格式正确"
                    break
                else
                    print_message $RED "❌ Chat ID格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
                fi
            else
                print_message $RED "❌ Chat ID不能为空"
            fi
        done
        
        # 确认Chat ID
        echo
        print_message $BLUE "📋 您输入的Chat ID: $CHAT_ID"
        read -p "确认Chat ID正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Chat ID已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Chat ID"
            echo
        fi
    done
    
    echo
    
    # 最终确认
    while true; do
        print_message $BLUE "📋 配置信息确认:"
        print_message $CYAN "Bot Token: $BOT_TOKEN"
        print_message $CYAN "Chat ID: $CHAT_ID"
        echo
        read -p "确认保存配置吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        else
            print_message $YELLOW "⚠️ 配置已取消，请重新开始"
            return 1
        fi
    done
    
    # 创建.env文件
    ENV_FILE="$INSTALL_DIR/.env"
    cat > "$ENV_FILE" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    return 0
}

print_message $GREEN "✅ 安装完成！"
echo
print_message $CYAN "🚀 正在配置Bot Token和Chat ID..."
print_message $YELLOW "💡 这是启动机器人必需的配置"
print_message $BLUE "📋 请按提示完成配置"

# 配置Bot Token和Chat ID
while true; do
    configure_bot
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 配置完成！"
        break
    else
        print_message $YELLOW "⚠️ 配置未完成，请重新配置"
        echo
        read -p "按回车键重新开始配置..." -r
        echo
    fi
done

echo
print_message $CYAN "🚀 正在启动机器人管理界面..."
print_message $GREEN "✅ 所有配置已完成，机器人已准备就绪！"
print_message $BLUE "📋 您可以在管理界面中启动机器人"
print_message $CYAN "⏳ 脚本将等待您完成配置..."
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

# 在项目下载完成后，添加虚拟环境创建流程

print_message $GREEN "✅ 项目下载完成！"
echo

# 检查Python和虚拟环境支持
check_python_and_venv() {
    print_message $BLUE "🐍 检查Python环境和虚拟环境支持..."
    
    # 检查Python3
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        print_message $GREEN "✅ 找到 python3"
    else
        print_message $RED "❌ 未找到python3，正在安装..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3 python3-venv python3-pip
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3 python3-venv python3-pip
        else
            print_message $RED "❌ 无法自动安装Python3，请手动安装"
            exit 1
        fi
        PYTHON_CMD="python3"
    fi
    
    # 检查Python版本
    local version=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 7 ]); then
        print_message $RED "❌ Python版本过低，需要Python 3.7+，当前版本: $version"
        exit 1
    fi
    
    print_message $GREEN "✅ Python版本检查通过: $version"
    
    # 检查虚拟环境支持
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        print_message $RED "❌ Python不支持虚拟环境，正在安装python3-venv..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y python3-venv
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3-venv
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3-venv
        else
            print_message $RED "❌ 无法安装python3-venv，请手动安装"
            exit 1
        fi
        
        if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
            print_message $RED "❌ 虚拟环境支持安装失败"
            exit 1
        fi
    fi
    
    print_message $GREEN "✅ 虚拟环境支持检查通过"
}

# 强制创建虚拟环境
create_virtual_environment() {
    print_message $BLUE "🐍 创建项目虚拟环境..."
    
    local venv_dir="$INSTALL_DIR/venv"
    
    # 如果虚拟环境已存在，删除重建
    if [ -d "$venv_dir" ]; then
        print_message $YELLOW "🔄 删除现有虚拟环境..."
        rm -rf "$venv_dir"
    fi
    
    # 创建虚拟环境
    print_message $YELLOW "🔄 创建虚拟环境: $venv_dir"
    $PYTHON_CMD -m venv "$venv_dir"
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 虚拟环境创建失败"
        exit 1
    fi
    
    print_message $GREEN "✅ 虚拟环境创建成功"
}

# 激活虚拟环境并安装依赖
install_dependencies_in_venv() {
    print_message $BLUE "📦 在虚拟环境中安装依赖..."
    
    local venv_dir="$INSTALL_DIR/venv"
    
    # 激活虚拟环境
    print_message $YELLOW "🔄 激活虚拟环境..."
    source "$venv_dir/bin/activate"
    
    if [ -z "$VIRTUAL_ENV" ]; then
        print_message $RED "❌ 虚拟环境激活失败"
        exit 1
    fi
    
    print_message $GREEN "✅ 虚拟环境已激活: $VIRTUAL_ENV"
    
    # 更新pip
    print_message $YELLOW "🔄 升级pip..."
    pip install --upgrade pip
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ pip升级失败"
        exit 1
    fi
    
    # 检查requirements.txt
    if [ ! -f "$INSTALL_DIR/requirements.txt" ]; then
        print_message $RED "❌ requirements.txt 文件不存在"
        exit 1
    fi
    
    # 安装项目依赖
    print_message $YELLOW "📥 安装项目依赖..."
    pip install -r "$INSTALL_DIR/requirements.txt"
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 依赖安装失败"
        exit 1
    fi
    
    # 安装Guard依赖
    print_message $YELLOW "📥 安装Guard守护程序依赖..."
    pip install schedule psutil
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ Guard依赖安装失败"
        exit 1
    fi
    
    print_message $GREEN "✅ 所有依赖安装完成"
    
    # 验证依赖
    print_message $YELLOW "🔄 验证依赖安装..."
    if python -c "import telegram, dotenv, Crypto, schedule, psutil" 2>/dev/null; then
        print_message $GREEN "✅ 所有依赖验证通过"
    else
        print_message $RED "❌ 依赖验证失败"
        exit 1
    fi
}

# 在主安装流程中调用这些函数
# 1. 检查Python和虚拟环境支持
check_python_and_venv

# 2. 强制创建虚拟环境
create_virtual_environment

# 3. 在虚拟环境中安装依赖
install_dependencies_in_venv

# 4. 修改全局命令创建（使用虚拟环境）
if [ "$INSTALL_MODE" = "global" ]; then
    print_message $BLUE "🔧 创建全局命令..."
    
    sudo tee /usr/local/bin/fn-bot > /dev/null << EOF
#!/bin/bash
# 激活虚拟环境并运行
source "$INSTALL_DIR/venv/bin/activate"
"$INSTALL_DIR/start.sh" "\$@"
EOF
    sudo chmod +x /usr/local/bin/fn-bot
    
    print_message $GREEN "✅ 全局命令创建成功: fn-bot (使用虚拟环境)"
else
    print_message $BLUE "🔧 创建本地命令..."
    
    local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    
    tee "$local_bin/fn-bot" > /dev/null << EOF
#!/bin/bash
# 激活虚拟环境并运行
source "$INSTALL_DIR/venv/bin/activate"
"$INSTALL_DIR/start.sh" "\$@"
EOF
    chmod +x "$local_bin/fn-bot"
    
    print_message $GREEN "✅ 本地命令创建成功: fn-bot (使用虚拟环境)"
fi

