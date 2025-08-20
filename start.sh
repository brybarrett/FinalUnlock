#!/bin/bash

# FinalShell 激活码机器人管理脚本
# 作者: AI Assistant
# 版本: 1.0
# 项目地址: https://github.com/xymn2023/FinalUnlock

# 屏蔽 Ctrl+C 信号
trap '' SIGINT SIGTERM

# 安全退出函数
safe_exit() {
    print_message $YELLOW "🔄 正在安全退出..."
    print_message $CYAN "💡 如果机器人正在运行，它会继续在后台运行"
    print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
    sleep 2
    exit 0
}

# 紧急退出函数（用于卸载等操作）
emergency_exit() {
    print_message $RED "🛑 紧急退出..."
    exit 1
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目配置
GITHUB_REPO="https://github.com/xymn2023/FinalUnlock.git"
PROJECT_NAME="FinalUnlock"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$PROJECT_DIR/bot.pid"
LOG_FILE="$PROJECT_DIR/bot.log"
ENV_FILE="$PROJECT_DIR/.env"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查并下载项目
download_project() {
    print_message $BLUE "📥 检查项目文件..."
    
    # 检查是否在正确的项目目录
    if [ -f "$PROJECT_DIR/bot.py" ] && [ -f "$PROJECT_DIR/py.py" ]; then
        print_message $GREEN "✅ 项目文件已存在"
        return 0
    fi
    
    print_message $YELLOW "🔄 项目文件不完整，正在从GitHub下载..."
    
    # 检查git是否安装
    if ! command -v git &> /dev/null; then
        print_message $RED "❌ 未找到git，请先安装git"
        print_message $YELLOW "Ubuntu/Debian: sudo apt-get install git"
        print_message $YELLOW "CentOS/RHEL: sudo yum install git"
        exit 1
    fi
    
    # 备份当前目录（如果存在）
    if [ -d "$PROJECT_DIR" ] && [ "$(ls -A $PROJECT_DIR)" ]; then
        local backup_dir="$PROJECT_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        print_message $YELLOW "🔄 备份现有文件到: $backup_dir"
        mv "$PROJECT_DIR" "$backup_dir"
    fi
    
    # 创建新的项目目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 克隆仓库
    print_message $BLUE "🔄 正在克隆仓库: $GITHUB_REPO"
    git clone "$GITHUB_REPO" .
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 项目下载完成"
        
        # 确保脚本有执行权限
        chmod +x start.sh
        
        return 0
    else
        print_message $RED "❌ 项目下载失败"
        return 1
    fi
}

# 注册全局命令
register_global_command() {
    print_message $BLUE "🔧 注册全局命令 fn-bot..."
    
    # 获取脚本的绝对路径
    local script_path="$PROJECT_DIR/start.sh"
    
    # 检查脚本是否存在
    if [ ! -f "$script_path" ]; then
        print_message $RED "❌ 脚本文件不存在: $script_path"
        return 1
    fi
    
    # 确保脚本有执行权限
    chmod +x "$script_path"
    
    # 创建全局命令
    local bin_dir="/usr/local/bin"
    local command_path="$bin_dir/fn-bot"
    
    # 检查是否有权限写入 /usr/local/bin
    if [ ! -w "$bin_dir" ]; then
        print_message $YELLOW "⚠️ 没有权限写入 $bin_dir，尝试使用 sudo..."
        sudo tee "$command_path" > /dev/null << EOF
#!/bin/bash
"$script_path" "\$@"
EOF
        sudo chmod +x "$command_path"
    else
        # 直接创建命令
        tee "$command_path" > /dev/null << EOF
#!/bin/bash
"$script_path" "\$@"
EOF
        chmod +x "$command_path"
    fi
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 全局命令 fn-bot 注册成功"
        print_message $CYAN "现在可以在任意目录使用 'fn-bot' 命令启动机器人管理脚本"
    else
        print_message $RED "❌ 全局命令注册失败"
        return 1
    fi
}

# 检查全局命令是否已注册
check_global_command() {
    if command -v fn-bot &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查Python3环境
check_python() {
    print_message $BLUE "🔍 检查Python3环境..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        print_message $GREEN "✅ 找到 python3"
    else
        print_message $YELLOW "⚠️ 未找到python3，尝试自动安装..."
        # 自动安装python3
        if command -v apt-get &> /dev/null; then
            print_message $YELLOW "🔄 使用apt-get安装python3..."
            sudo apt-get update
            sudo apt-get install -y python3
        elif command -v yum &> /dev/null; then
            print_message $YELLOW "🔄 使用yum安装python3..."
            sudo yum install -y python3
        elif command -v dnf &> /dev/null; then
            print_message $YELLOW "🔄 使用dnf安装python3..."
            sudo dnf install -y python3
        else
            print_message $RED "❌ 无法识别系统包管理器，无法自动安装python3"
            print_message $YELLOW "请手动安装python3后重试"
            exit 1
        fi
        # 安装后再次检测
        if command -v python3 &> /dev/null; then
            PYTHON_CMD="python3"
            print_message $GREEN "✅ python3安装成功"
        else
            print_message $RED "❌ python3安装失败，请手动安装后重试"
            exit 1
        fi
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
    
    # 检查pip
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
        print_message $GREEN "✅ 找到 pip3"
    else
        print_message $YELLOW "⚠️ 未找到pip3，尝试使用python3 -m pip..."
        if $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
            print_message $GREEN "✅ 找到 python3 -m pip"
        else
            print_message $YELLOW "⚠️ 未找到pip3，尝试安装..."
            install_pip
        fi
    fi
}

# 安装pip
install_pip() {
    print_message $BLUE "📦 正在安装pip..."
    
    # 尝试使用get-pip.py安装
    if command -v curl &> /dev/null; then
        print_message $YELLOW "🔄 使用curl下载get-pip.py..."
        curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    elif command -v wget &> /dev/null; then
        print_message $YELLOW "🔄 使用wget下载get-pip.py..."
        wget -q https://bootstrap.pypa.io/get-pip.py -O get-pip.py
    else
        print_message $RED "❌ 未找到curl或wget，无法下载pip"
        print_message $YELLOW "尝试使用系统包管理器安装pip..."
        install_pip_system
        return
    fi
    
    if [ -f "get-pip.py" ]; then
        print_message $YELLOW "🔄 安装pip..."
        $PYTHON_CMD get-pip.py --user
        rm -f get-pip.py
        
        # 检查安装结果
        if $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
            print_message $GREEN "✅ pip安装成功"
        else
            print_message $YELLOW "⚠️ pip安装失败，尝试使用系统包管理器..."
            install_pip_system
        fi
    else
        print_message $RED "❌ 下载get-pip.py失败"
        print_message $YELLOW "尝试使用系统包管理器安装pip..."
        install_pip_system
    fi
}

# 使用系统包管理器安装pip
install_pip_system() {
    print_message $BLUE "🔧 尝试使用系统包管理器安装pip..."
    
    if command -v apt-get &> /dev/null; then
        print_message $YELLOW "🔄 使用apt-get安装python3-pip..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
    elif command -v yum &> /dev/null; then
        print_message $YELLOW "🔄 使用yum安装python3-pip..."
        sudo yum install -y python3-pip
    elif command -v dnf &> /dev/null; then
        print_message $YELLOW "🔄 使用dnf安装python3-pip..."
        sudo dnf install -y python3-pip
    else
        print_message $RED "❌ 无法识别系统包管理器"
        print_message $YELLOW "请手动安装pip:"
        print_message $CYAN "  Ubuntu/Debian: sudo apt-get install python3-pip"
        print_message $CYAN "  CentOS/RHEL: sudo yum install python3-pip"
        exit 1
    fi
    
    # 检查安装结果
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
        print_message $GREEN "✅ pip3安装成功"
    elif command -v pip &> /dev/null; then
        PIP_CMD="pip"
        print_message $GREEN "✅ pip安装成功"
    elif $PYTHON_CMD -m pip --version &> /dev/null; then
        PIP_CMD="$PYTHON_CMD -m pip"
        print_message $GREEN "✅ python -m pip可用"
    else
        print_message $RED "❌ pip安装失败"
        print_message $YELLOW "请手动安装pip后重试"
        exit 1
    fi
}

# 检查并安装依赖
install_dependencies() {
    print_message $BLUE "📦 检查并安装依赖..."
    
    # 检查requirements.txt是否存在
    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        print_message $RED "❌ requirements.txt 文件不存在"
        exit 1
    fi
    
    # 确保pip命令可用
    if [ -z "$PIP_CMD" ]; then
        print_message $YELLOW "⚠️ pip命令未设置，重新检测..."
        check_python
    fi
    
    # 升级pip
    print_message $YELLOW "🔄 升级pip..."
    $PIP_CMD install --upgrade pip --user
    
    # 安装依赖
    print_message $YELLOW "📥 安装项目依赖..."
    $PIP_CMD install -r "$PROJECT_DIR/requirements.txt" --user
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 依赖安装完成"
    else
        print_message $RED "❌ 依赖安装失败"
        print_message $YELLOW "尝试使用系统包管理器安装..."
        install_dependencies_system
    fi
}

# 使用系统包管理器安装依赖
install_dependencies_system() {
    print_message $BLUE "🔧 尝试使用系统包管理器安装依赖..."
    
    if command -v apt-get &> /dev/null; then
        print_message $YELLOW "🔄 使用apt-get安装依赖..."
        sudo apt-get update
        
        # 尝试安装系统包
        if sudo apt-get install -y python3-telegram-bot python3-dotenv python3-cryptodome 2>/dev/null; then
            print_message $GREEN "✅ 系统包安装成功"
            return 0
        else
            print_message $YELLOW "⚠️ 系统包安装失败，尝试使用pip安装..."
        fi
        
        # 如果系统包安装失败，尝试使用pip安装
        if command -v pip3 &> /dev/null; then
            PIP_CMD="pip3"
        elif command -v pip &> /dev/null; then
            PIP_CMD="pip"
        elif $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
        else
            print_message $RED "❌ 无法找到可用的pip"
            print_message $YELLOW "请手动安装依赖:"
            print_message $CYAN "  pip install python-telegram-bot python-dotenv pycryptodome"
            exit 1
        fi
        
        # 尝试使用--break-system-packages标志
        print_message $YELLOW "🔄 尝试使用--break-system-packages标志安装..."
        $PIP_CMD install --break-system-packages -r "$PROJECT_DIR/requirements.txt"
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "✅ 依赖安装完成"
            return 0
        else
            print_message $YELLOW "⚠️ --break-system-packages安装失败，尝试创建虚拟环境..."
            install_dependencies_venv
        fi
        
    elif command -v yum &> /dev/null; then
        print_message $YELLOW "🔄 使用yum安装依赖..."
        sudo yum install -y python3-pip python3-telegram-bot python3-dotenv python3-cryptodome
    elif command -v dnf &> /dev/null; then
        print_message $YELLOW "🔄 使用dnf安装依赖..."
        sudo dnf install -y python3-pip python3-telegram-bot python3-dotenv python3-cryptodome
    else
        print_message $RED "❌ 无法识别系统包管理器"
        print_message $YELLOW "请手动安装以下依赖:"
        print_message $CYAN "  python-telegram-bot"
        print_message $CYAN "  python-dotenv"
        print_message $CYAN "  pycryptodome"
        exit 1
    fi
    
    # 再次尝试pip安装
    print_message $YELLOW "🔄 再次尝试pip安装..."
    $PIP_CMD install -r "$PROJECT_DIR/requirements.txt" --user
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 依赖安装完成"
    else
        print_message $RED "❌ 依赖安装仍然失败"
        print_message $YELLOW "请检查网络连接或手动安装依赖"
        exit 1
    fi
}

# 使用虚拟环境安装依赖
install_dependencies_venv() {
    print_message $BLUE "🐍 创建虚拟环境安装依赖..."
    
    # 检查是否支持虚拟环境
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        print_message $RED "❌ 系统不支持虚拟环境"
        print_message $YELLOW "请安装python3-venv: sudo apt-get install python3-venv"
        exit 1
    fi
    
    # 创建虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    print_message $YELLOW "🔄 创建虚拟环境: $venv_dir"
    $PYTHON_CMD -m venv "$venv_dir"
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 虚拟环境创建失败"
        exit 1
    fi
    
    # 激活虚拟环境
    print_message $YELLOW "🔄 激活虚拟环境..."
    source "$venv_dir/bin/activate"
    
    # 升级pip
    print_message $YELLOW "🔄 升级虚拟环境中的pip..."
    pip install --upgrade pip
    
    # 安装依赖
    print_message $YELLOW "📥 在虚拟环境中安装依赖..."
    pip install -r "$PROJECT_DIR/requirements.txt"
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 虚拟环境依赖安装完成"
        print_message $CYAN "💡 虚拟环境路径: $venv_dir"
        print_message $CYAN "💡 激活命令: source $venv_dir/bin/activate"
        
        # 更新PYTHON_CMD为虚拟环境中的Python
        PYTHON_CMD="$venv_dir/bin/python"
        PIP_CMD="$venv_dir/bin/pip"
        
        return 0
    else
        print_message $RED "❌ 虚拟环境依赖安装失败"
        exit 1
    fi
}

# 强制配置环境变量（首次运行）
force_setup_environment() {
    print_message $BLUE "⚙️ 配置环境变量..."
    
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
    cat > "$ENV_FILE" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    return 0
}

# 配置环境变量（菜单选项）
setup_environment() {
    print_message $BLUE "⚙️ 配置环境变量..."
    
    # 检查.env文件是否存在
    if [ -f "$ENV_FILE" ]; then
        print_message $YELLOW "⚠️ 发现已存在的.env文件"
        read -p "是否要重新配置? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ 使用现有配置"
            return 0
        fi
    fi
    
    # 配置Bot Token
    while true; do
        echo
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
        fi
    done
    
    # 配置Chat ID
    while true; do
        echo
        print_message $CYAN "请输入管理员的Chat ID (可通过 @userinfobot 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @userinfobot，发送任意消息获取ID"
        
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
        fi
    done
    
    # 最终确认
    echo
    print_message $BLUE "📋 配置信息确认:"
    print_message $CYAN "Bot Token: $BOT_TOKEN"
    print_message $CYAN "Chat ID: $CHAT_ID"
    echo
    read -p "确认保存配置吗? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $YELLOW "⚠️ 配置已取消"
        return 1
    fi
    
    # 创建.env文件
    cat > "$ENV_FILE" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    return 0
}

# 检查机器人状态
check_bot_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            # 使用多种方法检查进程是否存在
            if ps -p $pid > /dev/null 2>&1; then
                echo "running"
                return 0
            elif kill -0 $pid 2>/dev/null; then
                echo "running"
                return 0
            else
                echo "stopped"
                return 0
            fi
        else
            echo "stopped"
            return 0
        fi
    else
        echo "stopped"
        return 0
    fi
}

# 启动机器人
start_bot() {
    print_message $BLUE "🚀 启动机器人..."
    
    # 检查配置是否完成
    if [ ! -f "$ENV_FILE" ]; then
        print_message $RED "❌ 请先配置Bot Token和Chat ID"
        print_message $YELLOW "请选择选项 [c] 进行配置"
        return 1
    fi
    
    # 检查机器人是否已经在运行
    local status=$(check_bot_status)
    if [ "$status" = "running" ]; then
        local pid=$(cat "$PID_FILE")
        print_message $YELLOW "🔄 检测到机器人正在运行 (PID: $pid)，正在重启..."
        
        # 强制停止现有机器人
        print_message $BLUE "🛑 正在停止现有机器人..."
        stop_bot
        sleep 2
    else
        print_message $GREEN "✅ 机器人未在运行，正在启动..."
    fi
    
    # 强制停止所有可能的bot进程
    print_message $BLUE "🔍 检查并清理可能的冲突进程..."
    pkill -f "bot.py" 2>/dev/null
    sleep 1
    
    # 切换到项目目录
    cd "$PROJECT_DIR"
    
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    if [ -d "$venv_dir" ]; then
        print_message $BLUE "🐍 检测到虚拟环境，正在激活..."
        source "$venv_dir/bin/activate"
        PYTHON_CMD="$venv_dir/bin/python"
        print_message $GREEN "✅ 虚拟环境已激活"
    fi
    
    # 检查依赖
    print_message $YELLOW "🔄 检查依赖..."
    if ! $PYTHON_CMD -c "import telegram, dotenv, Crypto" 2>/dev/null; then
        print_message $YELLOW "⚠️ 依赖不完整，正在重新安装..."
        install_dependencies
    else
        print_message $GREEN "✅ 依赖检查通过"
    fi
    
    # 创建日志目录（如果不存在）
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # 启动机器人（后台运行，脱离终端，实时日志记录）
    print_message $YELLOW "🔄 正在启动机器人到后台..."
    print_message $CYAN "💡 日志将实时记录到: $LOG_FILE"
    
    # 使用nohup启动，并实时记录日志
    nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # 保存PID
    echo $pid > "$PID_FILE"
    
    # 等待一下检查是否启动成功
    sleep 3
    if ps -p $pid > /dev/null 2>&1; then
        print_message $GREEN "✅ 机器人启动成功 (PID: $pid)"
        print_message $CYAN "💡 机器人已在后台运行，即使退出脚本也会继续运行"
        print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
        print_message $CYAN "📋 实时日志文件: $LOG_FILE"
        
        # 显示启动日志
        echo
        print_message $CYAN "启动日志预览:"
        if [ -f "$LOG_FILE" ]; then
            tail -n 5 "$LOG_FILE" 2>/dev/null || print_message $YELLOW "暂无日志"
        else
            print_message $YELLOW "日志文件尚未创建"
        fi
        
        # 提示用户如何查看实时日志
        echo
        print_message $YELLOW "💡 查看实时日志的方法:"
        print_message $CYAN "  1. 使用菜单选项 [3] 查看实时日志"
        print_message $CYAN "  2. 直接运行: tail -f $LOG_FILE"
        print_message $CYAN "  3. 查看错误: grep -i error $LOG_FILE"
        
    else
        print_message $RED "❌ 机器人启动失败"
        print_message $YELLOW "请检查日志文件: $LOG_FILE"
        rm -f "$PID_FILE"
        
        # 显示错误日志
        if [ -f "$LOG_FILE" ]; then
            echo
            print_message $RED "错误日志:"
            tail -n 10 "$LOG_FILE"
        fi
        
        # 提供故障排除建议
        echo
        print_message $YELLOW "🔧 故障排除建议:"
        print_message $CYAN "  1. 检查Bot Token和Chat ID是否正确"
        print_message $CYAN "  2. 检查网络连接是否正常"
        print_message $CYAN "  3. 检查依赖是否完整安装"
        print_message $CYAN "  4. 查看完整日志: cat $LOG_FILE"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 停止机器人
stop_bot() {
    print_message $BLUE "🛑 停止机器人..."
    
    local status=$(check_bot_status)
    if [ "$status" = "stopped" ]; then
        print_message $YELLOW "⚠️ 机器人未在运行"
        return
    fi
    
    local pid=$(cat "$PID_FILE")
    print_message $YELLOW "🔄 正在停止进程 (PID: $pid)..."
    
    # 先尝试优雅停止
    kill $pid 2>/dev/null
    
    # 等待进程结束
    local count=0
    while ps -p $pid > /dev/null 2>&1 && [ $count -lt 5 ]; do
        sleep 1
        ((count++))
    done
    
    # 如果还在运行，强制停止
    if ps -p $pid > /dev/null 2>&1; then
        print_message $YELLOW "🔄 强制停止进程..."
        kill -9 $pid 2>/dev/null
        sleep 1
    fi
    
    # 清理所有可能的bot进程
    pkill -f "bot.py" 2>/dev/null
    
    if ps -p $pid > /dev/null 2>&1; then
        print_message $RED "❌ 无法停止机器人进程"
    else
        print_message $GREEN "✅ 机器人已停止"
        rm -f "$PID_FILE"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 查看实时日志
view_logs() {
    print_message $BLUE "📋 日志查看选项..."
    
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ 日志文件不存在"
        return
    fi
    
    echo
    print_message $CYAN "请选择日志查看方式:"
    echo -e "${CYAN}[1] 实时日志 (tail -f)${NC}"
    echo -e "${CYAN}[2] 查看最后50行${NC}"
    echo -e "${CYAN}[3] 查看最后100行${NC}"
    echo -e "${CYAN}[4] 查看全部日志${NC}"
    echo -e "${CYAN}[5] 搜索错误日志${NC}"
    echo -e "${CYAN}[0] 返回${NC}"
    echo
    
    read -p "请选择 [0-5]: " log_choice
    
    case $log_choice in
        1)
            print_message $BLUE "📋 实时日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示实时日志，按任意键返回主菜单..."
            echo
            # 使用更可靠的方法：先显示一些日志，然后等待按键
            tail -n 10 "$LOG_FILE" 2>/dev/null
            echo
            print_message $CYAN "=== 实时日志开始 ==="
            print_message $YELLOW "按任意键返回主菜单..."
            # 启动tail -f在后台，但限制输出行数避免阻塞
            timeout 30 tail -f "$LOG_FILE" 2>/dev/null &
            TAIL_PID=$!
            # 等待用户按键
            read -n 1 -s
            # 立即停止tail进程
            kill $TAIL_PID 2>/dev/null
            wait $TAIL_PID 2>/dev/null
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        2)
            print_message $BLUE "📋 最后50行日志（任意键返回主菜单）..."
            tail -n 50 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        3)
            print_message $BLUE "📋 最后100行日志（任意键返回主菜单）..."
            tail -n 100 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        4)
            print_message $BLUE "📋 全部日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示全部日志，按任意键返回主菜单..."
            echo
            # 使用less或more来分页显示，但提供退出选项
            if command -v less &> /dev/null; then
                less -R "$LOG_FILE"
            elif command -v more &> /dev/null; then
                more "$LOG_FILE"
            else
                cat "$LOG_FILE" 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
            fi
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        5)
            print_message $BLUE "📋 搜索错误日志（任意键返回主菜单）..."
            echo -e "${RED}错误信息:${NC}"
            grep -i "error\|exception\|traceback\|failed\|critical" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        6)
            print_message $BLUE "📋 搜索警告日志（任意键返回主菜单）..."
            echo -e "${YELLOW}警告信息:${NC}"
            grep -i "warning\|warn" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        7)
            print_message $BLUE "📋 搜索特定关键词（任意键返回主菜单）..."
            read -p "请输入搜索关键词: " keyword
            if [ -n "$keyword" ]; then
                print_message $BLUE "📋 搜索结果:"
                echo
                grep -i "$keyword" "$LOG_FILE" | tail -n 20 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
                echo
                print_message $CYAN "已返回主菜单"
            else
                print_message $RED "❌ 关键词不能为空"
                sleep 1
            fi
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
    esac
}

# 检查进程状态
check_process() {
    print_message $BLUE "🔍 检查进程状态..."
    
    # 直接测试状态检测函数
    print_message $CYAN "=== 状态检测调试信息 ==="
    local status=$(check_bot_status)
    print_message $CYAN "check_bot_status() 返回值: '$status'"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        print_message $CYAN "PID文件内容: '$pid'"
        
        if [ -n "$pid" ]; then
            print_message $CYAN "检查进程 $pid 是否存在..."
            
            # 使用多种方法检查进程
            if ps -p $pid > /dev/null 2>&1; then
                print_message $GREEN "✅ ps -p 检测到进程存在"
            else
                print_message $YELLOW "⚠️ ps -p 未检测到进程"
            fi
            
            if kill -0 $pid 2>/dev/null; then
                print_message $GREEN "✅ kill -0 检测到进程存在"
            else
                print_message $YELLOW "⚠️ kill -0 未检测到进程"
            fi
            
            # 显示进程详细信息
            echo
            print_message $CYAN "进程详细信息:"
            ps -p $pid -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || print_message $YELLOW "无法获取进程信息"
        else
            print_message $YELLOW "⚠️ PID文件为空"
        fi
    else
        print_message $YELLOW "⚠️ PID文件不存在"
    fi
    
    # 检查所有python进程
    echo
    print_message $CYAN "所有Python进程:"
    ps aux | grep python | grep -v grep || print_message $YELLOW "未找到Python进程"
    
    # 根据状态检测结果显示最终结论
    echo
    print_message $CYAN "=== 最终状态结论 ==="
    if [ "$status" = "running" ]; then
        print_message $GREEN "✅ 机器人状态: 正在运行"
    else
        print_message $YELLOW "⚠️ 机器人状态: 未运行"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 检查更新
check_updates() {
    print_message $BLUE "🔄 检查更新..."
    
    # 检查是否为Git仓库
    if [ ! -d ".git" ]; then
        print_message $YELLOW "⚠️ 当前目录不是Git仓库，正在重新克隆..."
        cd "$PROJECT_DIR"
        
        # 备份配置文件
        local env_backup=""
        if [ -f "$ENV_FILE" ]; then
            env_backup="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            print_message $BLUE "🔄 备份配置文件: $env_backup"
            cp "$ENV_FILE" "$env_backup"
        fi
        
        # 备份现有文件
        if [ -f "bot.py" ] || [ -f "py.py" ]; then
            local backup_dir="$PROJECT_DIR.backup.$(date +%Y%m%d_%H%M%S)"
            print_message $YELLOW "🔄 备份现有文件到: $backup_dir"
            mkdir -p "$backup_dir"
            cp -r * "$backup_dir/" 2>/dev/null || true
        fi
        
        # 重新克隆仓库
        print_message $BLUE "🔄 正在重新克隆仓库..."
        rm -rf .git 2>/dev/null || true
        git init
        git remote add origin "$GITHUB_REPO"
        git fetch origin
        
        # 尝试检测默认分支
        local default_branch="main"
        if git ls-remote --heads origin main | grep -q main; then
            default_branch="main"
        elif git ls-remote --heads origin master | grep -q master; then
            default_branch="master"
        else
            # 获取默认分支
            default_branch=$(git ls-remote --symref origin HEAD | head -n1 | cut -d/ -f3)
        fi
        
        print_message $CYAN "检测到默认分支: $default_branch"
        git checkout -f origin/$default_branch
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "✅ 仓库同步完成"
            
            # 恢复配置文件
            if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                print_message $BLUE "🔄 恢复配置文件..."
                cp "$env_backup" "$ENV_FILE"
                print_message $GREEN "✅ 配置文件已恢复"
                rm -f "$env_backup"
            fi
            
            chmod +x start.sh
            return 0
        else
            print_message $RED "❌ 仓库同步失败"
            
            # 恢复配置文件（即使同步失败）
            if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                print_message $BLUE "🔄 恢复配置文件..."
                cp "$env_backup" "$ENV_FILE"
                print_message $GREEN "✅ 配置文件已恢复"
                rm -f "$env_backup"
            fi
            
            return 1
        fi
    fi
    
    # 检查网络连接
    print_message $BLUE "🌐 检查网络连接..."
    if ! ping -c 1 github.com > /dev/null 2>&1; then
        print_message $RED "❌ 无法连接到GitHub，请检查网络连接"
        return 1
    fi
    print_message $GREEN "✅ 网络连接正常"
    
    # 获取远程更新
    print_message $BLUE "📡 正在连接GitHub获取更新信息..."
    git fetch origin
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 无法获取远程更新"
        return 1
    fi
    print_message $GREEN "✅ 成功连接到GitHub"
    
    # 检测当前分支和远程分支
    local current_branch=$(git branch --show-current)
    local remote_branch=""
    
    # 尝试检测远程分支
    if git ls-remote --heads origin main | grep -q main; then
        remote_branch="main"
    elif git ls-remote --heads origin master | grep -q master; then
        remote_branch="master"
    else
        remote_branch="main"  # 默认使用main
    fi
    
    print_message $CYAN "当前分支: $current_branch"
    print_message $CYAN "远程分支: $remote_branch"
    
    # 检查是否有更新
    print_message $BLUE "🔍 正在检测GitHub文件更新..."
    local behind=$(git rev-list HEAD..origin/$remote_branch --count 2>/dev/null || echo "0")
    local ahead=$(git rev-list origin/$remote_branch..HEAD --count 2>/dev/null || echo "0")
    
    print_message $CYAN "本地落后远程: $behind 个提交"
    print_message $CYAN "本地领先远程: $ahead 个提交"
    
    if [ "$behind" -gt 0 ]; then
        print_message $YELLOW "🆕 检测到GitHub有更新！"
        print_message $CYAN "发现 $behind 个新提交"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $CYAN "最新版本: $(git rev-parse --short origin/$remote_branch)"
        
        # 显示更新内容
        echo
        print_message $CYAN "📋 更新内容预览:"
        git log --oneline HEAD..origin/$remote_branch --max-count=5
        
        echo
        print_message $YELLOW "⚠️ 注意：更新操作需要用户手动确认"
        read -p "是否下载并安装更新? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 再次确认
            print_message $RED "⚠️ 确认更新操作"
            read -p "此操作将覆盖本地文件，确认继续? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_message $YELLOW "⏭️ 跳过更新"
                return
            fi
            
            # 停止机器人（如果正在运行）
            local status=$(check_bot_status)
            if [ "$status" = "running" ]; then
                print_message $YELLOW "🔄 正在停止机器人以进行更新..."
                stop_bot
                sleep 2
            fi
            
            # 备份配置文件
            local env_backup=""
            if [ -f "$ENV_FILE" ]; then
                env_backup="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
                print_message $BLUE "🔄 备份配置文件: $env_backup"
                cp "$ENV_FILE" "$env_backup"
            fi
            
            # 执行更新
            print_message $BLUE "📥 正在下载更新文件..."
            
            # 获取更新前的文件状态
            local updated_files=$(git diff --name-only HEAD origin/$remote_branch 2>/dev/null || echo "")
            
            git reset --hard origin/$remote_branch
            
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 更新文件下载完成"
                print_message $GREEN "✅ 更新安装完成"
                
                # 显示更新的文件列表
                if [ -n "$updated_files" ]; then
                    echo
                    print_message $CYAN "📋 此次更新内容:"
                    echo "$updated_files" | while read -r file; do
                        if [ -n "$file" ]; then
                            print_message $WHITE "  • $file"
                        fi
                    done
                else
                    print_message $CYAN "📋 此次更新内容: 所有文件已同步到最新版本"
                fi
                
                # 恢复配置文件
                if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                    print_message $BLUE "🔄 恢复配置文件..."
                    cp "$env_backup" "$ENV_FILE"
                    print_message $GREEN "✅ 配置文件已恢复"
                    
                    # 清理备份文件
                    rm -f "$env_backup"
                fi
                
                # 重新安装依赖（以防requirements.txt有更新）
                print_message $YELLOW "🔄 检查依赖更新..."
                install_dependencies
                
                # 如果机器人之前在运行，询问是否重启
                if [ "$status" = "running" ]; then
                    echo
                    read -p "是否重启机器人? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        start_bot
                    fi
                fi
            else
                print_message $RED "❌ 更新下载失败"
                
                # 恢复配置文件（即使更新失败）
                if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                    print_message $BLUE "🔄 恢复配置文件..."
                    cp "$env_backup" "$ENV_FILE"
                    print_message $GREEN "✅ 配置文件已恢复"
                    rm -f "$env_backup"
                fi
                
                return 1
            fi
        else
            print_message $YELLOW "⏭️ 跳过更新"
        fi
    elif [ "$ahead" -gt 0 ]; then
        print_message $YELLOW "⚠️ 本地版本领先远程版本 $ahead 个提交"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $CYAN "远程版本: $(git rev-parse --short origin/$remote_branch)"
        print_message $BLUE "💡 提示：本地版本比GitHub版本更新"
        echo
        read -p "按任意键返回..." -n 1 -r
        echo
    else
        print_message $GREEN "✅ 未检测到更新"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $BLUE "💡 提示：本地文件已是最新版本"
        echo
        read -p "按任意键返回..." -n 1 -r
        echo
    fi
}

# 验证Bot Token格式
validate_bot_token() {
    local token="$1"
    
    # 检查是否为空
    if [ -z "$token" ]; then
        echo "empty"
        return 1
    fi
    
    # 检查基本格式：数字:字母数字字符
    if [[ ! "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        echo "invalid_format"
        return 1
    fi
    
    # 检查长度（Telegram Bot Token通常很长）
    if [ ${#token} -lt 35 ]; then
        echo "too_short"
        return 1
    fi
    
    echo "valid"
    return 0
}

# 验证Chat ID格式
validate_chat_id() {
    local chat_id="$1"
    
    # 检查是否为空
    if [ -z "$chat_id" ]; then
        echo "empty"
        return 1
    fi
    
    # 检查格式：单个数字或逗号分隔的数字
    if [[ ! "$chat_id" =~ ^[0-9]+([,][0-9]+)*$ ]]; then
        echo "invalid_format"
        return 1
    fi
    
    # 检查每个ID的长度
    IFS=',' read -ra IDS <<< "$chat_id"
    for id in "${IDS[@]}"; do
        if [ ${#id} -lt 5 ] || [ ${#id} -gt 15 ]; then
            echo "invalid_length"
            return 1
        fi
    done
    
    echo "valid"
    return 0
}

# 测试Bot Token有效性
test_bot_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    # 使用curl测试Token
    if command -v curl &> /dev/null; then
        local response=$(curl -s "https://api.telegram.org/bot$token/getMe" 2>/dev/null)
        if echo "$response" | grep -q '"ok":true'; then
            return 0
        fi
    fi
    
    return 1
}

# 完整的配置验证函数
validate_configuration() {
    local config_valid=true
    local validation_log="$PROJECT_DIR/config_validation.log"
    
    print_message $BLUE "🔍 验证配置文件..."
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Starting configuration validation" > "$validation_log"
    
    # 检查.env文件是否存在
    if [ ! -f "$ENV_FILE" ]; then
        print_message $RED "❌ .env 文件不存在"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): .env file not found" >> "$validation_log"
        return 1
    fi
    
    # 读取配置
    source "$ENV_FILE"
    
    # 验证Bot Token
    print_message $YELLOW "🔑 验证 Bot Token..."
    local token_validation=$(validate_bot_token "$BOT_TOKEN")
    case $token_validation in
        "empty")
            print_message $RED "❌ Bot Token 为空"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token is empty" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_format")
            print_message $RED "❌ Bot Token 格式无效"
            print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token format invalid" >> "$validation_log"
            config_valid=false
            ;;
        "too_short")
            print_message $RED "❌ Bot Token 长度过短"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token too short" >> "$validation_log"
            config_valid=false
            ;;
        "valid")
            print_message $GREEN "✅ Bot Token 格式正确"
            
            # 测试Token有效性
            print_message $YELLOW "🌐 测试 Bot Token 连接..."
            if test_bot_token "$BOT_TOKEN"; then
                print_message $GREEN "✅ Bot Token 连接测试成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token connection test passed" >> "$validation_log"
            else
                print_message $YELLOW "⚠️ Bot Token 连接测试失败（可能是网络问题）"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token connection test failed" >> "$validation_log"
            fi
            ;;
    esac
    
    # 验证Chat ID
    print_message $YELLOW "👤 验证 Chat ID..."
    local chat_id_validation=$(validate_chat_id "$CHAT_ID")
    case $chat_id_validation in
        "empty")
            print_message $RED "❌ Chat ID 为空"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID is empty" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_format")
            print_message $RED "❌ Chat ID 格式无效"
            print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID format invalid" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_length")
            print_message $RED "❌ Chat ID 长度无效"
            print_message $YELLOW "💡 Chat ID 应该是5-15位数字"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID length invalid" >> "$validation_log"
            config_valid=false
            ;;
        "valid")
            print_message $GREEN "✅ Chat ID 格式正确"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID format valid" >> "$validation_log"
            
            # 显示管理员数量
            IFS=',' read -ra IDS <<< "$CHAT_ID"
            local admin_count=${#IDS[@]}
            print_message $CYAN "👥 配置了 $admin_count 个管理员"
            ;;
    esac
    
    # 检查Python环境
    print_message $YELLOW "🐍 验证 Python 环境..."
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_message $GREEN "✅ Python 版本: $python_version"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Python version: $python_version" >> "$validation_log"
    else
        print_message $RED "❌ Python3 未安装"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Python3 not found" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查依赖包
    print_message $YELLOW "📦 验证依赖包..."
    local missing_deps=()
    
    if ! python3 -c "import telegram" 2>/dev/null; then
        missing_deps+=("python-telegram-bot")
    fi
    
    if ! python3 -c "import dotenv" 2>/dev/null; then
        missing_deps+=("python-dotenv")
    fi
    
    if ! python3 -c "import Crypto" 2>/dev/null; then
        missing_deps+=("pycryptodome")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有依赖包已安装"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): All dependencies installed" >> "$validation_log"
    else
        print_message $RED "❌ 缺少依赖包: ${missing_deps[*]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Missing dependencies: ${missing_deps[*]}" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查核心文件
    print_message $YELLOW "📁 验证核心文件..."
    local missing_files=()
    
    if [ ! -f "$PROJECT_DIR/bot.py" ]; then
        missing_files+=("bot.py")
    fi
    
    if [ ! -f "$PROJECT_DIR/py.py" ]; then
        missing_files+=("py.py")
    fi
    
    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        missing_files+=("requirements.txt")
    fi
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有核心文件存在"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): All core files present" >> "$validation_log"
    else
        print_message $RED "❌ 缺少核心文件: ${missing_files[*]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Missing core files: ${missing_files[*]}" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查权限
    print_message $YELLOW "🔐 验证文件权限..."
    if [ -r "$PROJECT_DIR/bot.py" ] && [ -r "$PROJECT_DIR/py.py" ]; then
        print_message $GREEN "✅ 文件权限正常"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): File permissions OK" >> "$validation_log"
    else
        print_message $RED "❌ 文件权限不足"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Insufficient file permissions" >> "$validation_log"
        config_valid=false
    fi
    
    # 最终结果
    echo
    if [ "$config_valid" = true ]; then
        print_message $GREEN "🎉 配置验证通过！"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Configuration validation passed" >> "$validation_log"
        return 0
    else
        print_message $RED "❌ 配置验证失败，请修复上述问题"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Configuration validation failed" >> "$validation_log"
        return 1
    fi
}

# 配置修复建议
show_config_fix_suggestions() {
    print_message $BLUE "🔧 配置修复建议:"
    echo
    
    print_message $YELLOW "1. Bot Token 问题:"
    print_message $CYAN "   • 访问 @BotFather 创建新机器人"
    print_message $CYAN "   • 发送 /newbot 命令"
    print_message $CYAN "   • 按提示设置机器人名称"
    print_message $CYAN "   • 复制获得的 Token"
    echo
    
    print_message $YELLOW "2. Chat ID 问题:"
    print_message $CYAN "   • 访问 @userinfobot"
    print_message $CYAN "   • 发送任意消息获取您的 Chat ID"
    print_message $CYAN "   • 多个管理员用逗号分隔"
    echo
    
    print_message $YELLOW "3. 依赖包问题:"
    print_message $CYAN "   • 运行: pip install -r requirements.txt"
    print_message $CYAN "   • 或使用菜单选项 [6] 检查依赖"
    echo
    
    print_message $YELLOW "4. 文件权限问题:"
    print_message $CYAN "   • 运行: chmod +x start.sh"
    print_message $CYAN "   • 确保有读取权限: chmod 644 *.py"
    echo
}

# 自动修复配置
auto_fix_config() {
    print_message $BLUE "🔧 尝试自动修复配置..."
    
    # 修复文件权限
    print_message $YELLOW "🔐 修复文件权限..."
    chmod +x "$PROJECT_DIR/start.sh" 2>/dev/null
    chmod 644 "$PROJECT_DIR"/*.py 2>/dev/null
    chmod 644 "$PROJECT_DIR"/*.txt 2>/dev/null
    print_message $GREEN "✅ 文件权限已修复"
    
    # 尝试安装缺少的依赖
    print_message $YELLOW "📦 检查并安装依赖..."
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        if command -v pip3 &> /dev/null; then
            pip3 install -r "$PROJECT_DIR/requirements.txt" --user
            print_message $GREEN "✅ 依赖安装完成"
        else
            print_message $YELLOW "⚠️ pip3 未找到，请手动安装依赖"
        fi
    fi
    
    # 创建必要的目录
    mkdir -p "$PROJECT_DIR/logs" 2>/dev/null
    mkdir -p "$PROJECT_DIR/backups" 2>/dev/null
    
    print_message $GREEN "✅ 自动修复完成"
}

# 检查依赖
check_dependencies() {
    print_message $BLUE "🔍 检查依赖..."
    
    local missing_deps=()
    local version_info=()
    
    # 检查主要依赖
    if ! $PYTHON_CMD -c "import telegram" 2>/dev/null; then
        missing_deps+=("python-telegram-bot")
    else
        local version=$($PYTHON_CMD -c "import telegram; print(telegram.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("python-telegram-bot: $version")
    fi
    
    if ! $PYTHON_CMD -c "import dotenv" 2>/dev/null; then
        missing_deps+=("python-dotenv")
    else
        local version=$($PYTHON_CMD -c "import dotenv; print(dotenv.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("python-dotenv: $version")
    fi
    
    if ! $PYTHON_CMD -c "import Crypto" 2>/dev/null; then
        missing_deps+=("pycryptodome")
    else
        local version=$($PYTHON_CMD -c "import Crypto; print(Crypto.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("pycryptodome: $version")
    fi
    
    # 显示检查结果
    echo
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有依赖已安装"
        echo
        print_message $CYAN "已安装的依赖版本:"
        for info in "${version_info[@]}"; do
            echo -e "  ${CYAN}• $info${NC}"
        done
    else
        print_message $YELLOW "⚠️ 发现缺失依赖: ${missing_deps[*]}"
        echo
        print_message $CYAN "已安装的依赖版本:"
        for info in "${version_info[@]}"; do
            echo -e "  ${CYAN}• $info${NC}"
        done
        echo
        print_message $YELLOW "缺失的依赖:"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}• $dep${NC}"
        done
        echo
        read -p "是否安装缺失的依赖? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_dependencies
        fi
    fi
    
    # 检查Python版本
    echo
    print_message $CYAN "Python环境信息:"
    echo -e "  ${CYAN}• Python版本: $($PYTHON_CMD --version)${NC}"
    echo -e "  ${CYAN}• Python路径: $(which $PYTHON_CMD)${NC}"
    echo -e "  ${CYAN}• pip版本: $($PIP_CMD --version)${NC}"
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 重新安装依赖
reinstall_dependencies() {
    print_message $BLUE "🔄 重新安装依赖..."
    
    print_message $YELLOW "⚠️ 这将卸载并重新安装所有依赖"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    # 卸载现有依赖
    print_message $YELLOW "🔄 卸载现有依赖..."
    $PIP_CMD uninstall -y python-telegram-bot python-dotenv pycryptodome
    
    # 重新安装
    install_dependencies
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 检查虚拟环境
check_venv() {
    print_message $BLUE "🔍 检查虚拟环境..."
    
    echo
    if [ -n "$VIRTUAL_ENV" ]; then
        print_message $GREEN "✅ 正在使用虚拟环境"
        echo -e "  ${CYAN}• 虚拟环境路径: $VIRTUAL_ENV${NC}"
        echo -e "  ${CYAN}• 虚拟环境名称: $(basename "$VIRTUAL_ENV")${NC}"
    else
        print_message $YELLOW "⚠️ 未使用虚拟环境"
        echo -e "  ${YELLOW}• 当前使用系统Python${NC}"
    fi
    
    # 检查是否有虚拟环境目录
    if [ -d "venv" ]; then
        echo
        print_message $CYAN "发现本地虚拟环境目录: venv/"
        read -p "是否激活本地虚拟环境? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $BLUE "🔄 激活虚拟环境..."
            source venv/bin/activate
            print_message $GREEN "✅ 虚拟环境已激活"
            print_message $CYAN "请重新运行脚本以使用虚拟环境"
            return
        fi
    fi
    
    echo
    print_message $CYAN "虚拟环境选项:"
    echo -e "${CYAN}[1] 创建新的虚拟环境${NC}"
    echo -e "${CYAN}[2] 删除现有虚拟环境${NC}"
    echo -e "${CYAN}[3] 重新创建虚拟环境${NC}"
    echo -e "${CYAN}[0] 返回${NC}"
    echo
    
    read -p "请选择 [0-3]: " venv_choice
    
    case $venv_choice in
        1)
            if [ -d "venv" ]; then
                print_message $YELLOW "⚠️ 虚拟环境已存在"
                read -p "是否覆盖? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return
                fi
                rm -rf venv
            fi
            print_message $BLUE "🔄 创建虚拟环境..."
            $PYTHON_CMD -m venv venv
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 虚拟环境创建成功"
                print_message $CYAN "激活命令: source venv/bin/activate"
            else
                print_message $RED "❌ 虚拟环境创建失败"
            fi
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
        2)
            if [ -d "venv" ]; then
                print_message $YELLOW "⚠️ 确认删除虚拟环境?"
                read -p "此操作不可逆 (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf venv
                    print_message $GREEN "✅ 虚拟环境已删除"
                fi
            else
                print_message $YELLOW "⚠️ 虚拟环境不存在"
            fi
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
        3)
            print_message $BLUE "🔄 重新创建虚拟环境..."
            rm -rf venv 2>/dev/null || true
            $PYTHON_CMD -m venv venv
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 虚拟环境重新创建成功"
                print_message $CYAN "激活命令: source venv/bin/activate"
            else
                print_message $RED "❌ 虚拟环境创建失败"
            fi
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
    esac
}

# 卸载机器人
uninstall_bot() {
    print_message $BLUE "🗑️ 卸载机器人..."
    
    print_message $RED "⚠️ 这将停止机器人并强制删除所有 FinalUnlock 相关目录及文件"
    print_message $RED "⚠️ 包括: FinalUnlock, FinalUnlock.backup.* 等所有相关目录"
    print_message $RED "⚠️ 此操作不可逆，请谨慎操作！"
    echo
    read -p "请输入 'yes' 确认删除: " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_message $YELLOW "❌ 取消卸载操作"
        return
    fi
    
    # 停止机器人
    stop_bot
    
    # 删除全局命令
    print_message $YELLOW "🔄 正在删除全局命令 fn-bot..."
    local command_path="/usr/local/bin/fn-bot"
    if [ -f "$command_path" ]; then
        if [ -w "$command_path" ]; then
            rm -f "$command_path"
        else
            sudo rm -f "$command_path"
        fi
        print_message $GREEN "✅ 全局命令 fn-bot 已删除"
    fi
    
    # 删除本地命令
    local local_bin="$HOME/.local/bin"
    if [ -f "$local_bin/fn-bot" ]; then
        print_message $YELLOW "🔄 正在删除本地命令 fn-bot..."
        rm -f "$local_bin/fn-bot"
        print_message $GREEN "✅ 本地命令 fn-bot 已删除"
    fi
    
    # 删除桌面快捷方式
    local desktop_file="$HOME/.local/share/applications/finalshell-bot.desktop"
    if [ -f "$desktop_file" ]; then
        print_message $YELLOW "🔄 正在删除桌面快捷方式..."
        rm -f "$desktop_file"
        print_message $GREEN "✅ 桌面快捷方式已删除"
    fi
    
    # 获取项目目录的父目录
    local parent_dir=$(dirname "$PROJECT_DIR")
    local project_name=$(basename "$PROJECT_DIR")
    
    # 切换到父目录
    cd "$parent_dir"
    
    # 删除所有FinalUnlock相关目录
    print_message $YELLOW "🔄 正在删除所有 FinalUnlock 相关目录..."
    
    # 删除主目录
    if [ -d "$project_name" ]; then
        rm -rf "$project_name"
        print_message $GREEN "✅ FinalUnlock 主目录已删除"
    fi
    
    # 删除所有备份目录
    for backup_dir in "$project_name".backup.*; do
        if [ -d "$backup_dir" ]; then
            rm -rf "$backup_dir"
            print_message $GREEN "✅ 备份目录 $backup_dir 已删除"
        fi
    done
    
    # 删除可能的其他相关目录
    for related_dir in *FinalUnlock*; do
        if [ -d "$related_dir" ] && [ "$related_dir" != "$project_name" ]; then
            rm -rf "$related_dir"
            print_message $GREEN "✅ 相关目录 $related_dir 已删除"
        fi
    done
    
    print_message $GREEN "✅ 所有 FinalUnlock 相关目录已完全删除"
    print_message $YELLOW "脚本将在3秒后退出..."
    sleep 3
    emergency_exit
}

# 健康检查函数
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
        # 检查进程是否响应（检查日志文件是否在更新）
        if [ -f "$LOG_FILE" ]; then
            local last_log_time=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_log_time))
            
            # 如果日志文件超过5分钟没有更新，认为可能有问题
            if [ $time_diff -gt 300 ]; then
                echo "unresponsive"
            else
                echo "healthy"
            fi
        else
            echo "no_log"
        fi
    else
        echo "stopped"
    fi
}

# 检查网络连接
check_network() {
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

# 自动重启函数
auto_restart_bot() {
    local max_restart_attempts=3
    local restart_count=0
    local restart_interval=60  # 重启间隔60秒
    local restart_log="$PROJECT_DIR/restart.log"
    
    while [ $restart_count -lt $max_restart_attempts ]; do
        local health=$(health_check)
        local network=$(check_network)
        
        case $health in
            "stopped"|"unresponsive")
                print_message $YELLOW "🔄 检测到机器人异常 ($health)，正在重启... (尝试 $((restart_count + 1))/$max_restart_attempts)"
                
                # 记录重启日志
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Auto-restart triggered - Status: $health, Network: $network" >> "$restart_log"
                
                # 如果网络断开，等待网络恢复
                if [ "$network" = "disconnected" ]; then
                    print_message $YELLOW "⚠️ 网络连接异常，等待网络恢复..."
                    local network_wait=0
                    while [ $network_wait -lt 10 ]; do
                        sleep 30
                        network=$(check_network)
                        if [ "$network" = "connected" ]; then
                            print_message $GREEN "✅ 网络连接已恢复"
                            break
                        fi
                        ((network_wait++))
                    done
                fi
                
                # 停止现有进程
                stop_bot_silent
                sleep 5
                
                # 重新启动
                if start_bot_silent; then
                    print_message $GREEN "✅ 机器人重启成功"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Restart successful" >> "$restart_log"
                    return 0
                else
                    print_message $RED "❌ 机器人重启失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Restart failed" >> "$restart_log"
                    ((restart_count++))
                    if [ $restart_count -lt $max_restart_attempts ]; then
                        print_message $YELLOW "⏳ 等待 $restart_interval 秒后重试..."
                        sleep $restart_interval
                    fi
                fi
                ;;
            "healthy")
                return 0
                ;;
            "no_log")
                print_message $YELLOW "⚠️ 日志文件不存在，但进程正在运行"
                return 0
                ;;
        esac
    done
    
    print_message $RED "❌ 达到最大重启次数 ($max_restart_attempts)，请手动检查"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Max restart attempts reached" >> "$restart_log"
    
    # 发送告警（如果配置了）
    send_alert "FinalShell Bot 重启失败，需要手动干预"
    
    return 1
}

# 静默启动函数（用于自动重启）
start_bot_silent() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    if [ -d "$venv_dir" ]; then
        source "$venv_dir/bin/activate"
        PYTHON_CMD="$venv_dir/bin/python"
    fi
    
    # 清理旧进程
    pkill -f "bot.py" 2>/dev/null
    sleep 2
    
    # 启动机器人
    nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    # 检查启动是否成功
    sleep 5
    if ps -p $pid > /dev/null 2>&1; then
        return 0
    else
        rm -f "$PID_FILE"
        return 1
    fi
}

# 静默停止函数
stop_bot_silent() {
    local status=$(check_bot_status)
    if [ "$status" = "stopped" ]; then
        return 0
    fi
    
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ]; then
        # 先尝试优雅停止
        kill $pid 2>/dev/null
        
        # 等待进程结束
        local count=0
        while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
            sleep 1
            ((count++))
        done
        
        # 如果还在运行，强制停止
        if ps -p $pid > /dev/null 2>&1; then
            kill -9 $pid 2>/dev/null
            sleep 1
        fi
    fi
    
    # 清理所有可能的bot进程
    pkill -f "bot.py" 2>/dev/null
    rm -f "$PID_FILE"
    
    return 0
}

# 日志轮转函数
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local max_size=10485760  # 10MB
        
        if [ "$log_size" -gt "$max_size" ]; then
            local backup_name="$LOG_FILE.$(date +%Y%m%d_%H%M%S)"
            
            # 备份当前日志
            cp "$LOG_FILE" "$backup_name"
            
            # 清空当前日志（保持文件句柄）
            > "$LOG_FILE"
            
            # 压缩备份
            gzip "$backup_name" &
            
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Log rotated to $backup_name.gz" >> "$LOG_FILE"
            
            # 清理超过7天的日志备份
            find "$(dirname "$LOG_FILE")" -name "bot.log.*.gz" -mtime +7 -delete 2>/dev/null
        fi
    fi
}

# 系统资源检查
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    # 检查资源使用率是否过高
    if [ "${cpu_usage%.*}" -gt 80 ] || [ "${memory_usage%.*}" -gt 90 ] || [ "$disk_usage" -gt 90 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): High resource usage - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%" >> "$PROJECT_DIR/resource.log"
        return 1
    fi
    
    return 0
}

# 发送告警函数（可扩展）
send_alert() {
    local message="$1"
    local alert_log="$PROJECT_DIR/alert.log"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ALERT - $message" >> "$alert_log"
    
    # 这里可以添加更多告警方式，如邮件、webhook等
    # 例如：curl -X POST "$WEBHOOK_URL" -d "{\"text\":\"$message\"}"
}

# 监控守护进程
start_monitor_daemon() {
    print_message $BLUE "🔍 启动监控守护进程..."
    
    # 检查是否已经在运行
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local existing_pid=$(cat "$monitor_pid_file")
        if [ -n "$existing_pid" ] && ps -p $existing_pid > /dev/null 2>&1; then
            print_message $YELLOW "⚠️ 监控守护进程已在运行 (PID: $existing_pid)"
            return 0
        else
            rm -f "$monitor_pid_file"
        fi
    fi
    
    # 创建监控脚本
    local monitor_script="$PROJECT_DIR/monitor.sh"
    cat > "$monitor_script" << 'EOF'
#!/bin/bash

# 获取项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入主脚本的函数
source "$PROJECT_DIR/start.sh"

# 监控循环
while true; do
    # 健康检查和自动重启
    if ! auto_restart_bot; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Auto restart failed, sleeping for 5 minutes" >> "$PROJECT_DIR/monitor.log"
        sleep 300  # 失败后等待5分钟
        continue
    fi
    
    # 日志轮转
    rotate_logs
    
    # 系统资源检查
    if ! check_system_resources; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): High resource usage detected" >> "$PROJECT_DIR/monitor.log"
    fi
    
    # 清理临时文件
    find "$PROJECT_DIR" -name "*.tmp" -mtime +1 -delete 2>/dev/null
    
    # 等待60秒
    sleep 60
done
EOF
    
    chmod +x "$monitor_script"
    
    # 启动监控进程
    nohup "$monitor_script" > "$PROJECT_DIR/monitor.log" 2>&1 &
    local monitor_pid=$!
    echo $monitor_pid > "$monitor_pid_file"
    
    print_message $GREEN "✅ 监控守护进程已启动 (PID: $monitor_pid)"
    print_message $CYAN "📋 监控日志: $PROJECT_DIR/monitor.log"
}

# 停止监控守护进程
stop_monitor_daemon() {
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            kill $monitor_pid 2>/dev/null
            
            # 等待进程结束
            local count=0
            while ps -p $monitor_pid > /dev/null 2>&1 && [ $count -lt 5 ]; do
                sleep 1
                ((count++))
            done
            
            # 强制停止
            if ps -p $monitor_pid > /dev/null 2>&1; then
                kill -9 $monitor_pid 2>/dev/null
            fi
            
            rm -f "$monitor_pid_file"
            print_message $GREEN "✅ 监控守护进程已停止"
        else
            rm -f "$monitor_pid_file"
            print_message $YELLOW "⚠️ 监控守护进程未在运行"
        fi
    else
        print_message $YELLOW "⚠️ 监控守护进程未在运行"
    fi
}

# 检查监控守护进程状态
check_monitor_status() {
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "stopped"
    fi
}

# 显示系统状态
show_system_status() {
    print_message $BLUE "📊 系统状态报告"
    echo
    
    # 机器人状态
    local bot_status=$(check_bot_status)
    if [ "$bot_status" = "running" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        print_message $GREEN "🤖 机器人状态: ✅ 运行中 (PID: $pid)"
    else
        print_message $RED "🤖 机器人状态: ❌ 未运行"
    fi
    
    # 监控守护进程状态
    local monitor_status=$(check_monitor_status)
    if [ "$monitor_status" = "running" ]; then
        local monitor_pid=$(cat "$PROJECT_DIR/monitor.pid" 2>/dev/null)
        print_message $GREEN "🔍 监控守护进程: ✅ 运行中 (PID: $monitor_pid)"
    else
        print_message $RED "🔍 监控守护进程: ❌ 未运行"
    fi
    
    # 网络状态
    local network=$(check_network)
    if [ "$network" = "connected" ]; then
        print_message $GREEN "🌐 网络连接: ✅ 正常"
    else
        print_message $RED "🌐 网络连接: ❌ 异常"
    fi
    
    # 系统资源
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    
    print_message $CYAN "💻 CPU 使用率: ${cpu_usage}%"
    print_message $CYAN "🧠 内存使用率: ${memory_usage}%"
    print_message $CYAN "💾 磁盘使用率: ${disk_usage}"
    
    # 日志文件大小
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        print_message $CYAN "📋 日志文件大小: $log_size"
    fi
    
    echo
}

# 日志管理功能
manage_logs() {
    print_message $BLUE "📋 日志管理..."
    
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ 日志文件不存在"
        return
    fi
    
    # 获取日志文件信息
    local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
    local log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null | echo "0")
    local last_modified=$(stat -c %y "$LOG_FILE" 2>/dev/null | cut -d' ' -f1,2 || echo "未知")
    
    echo
    print_message $CYAN "日志文件信息:"
    echo -e "  ${CYAN}• 文件路径: $LOG_FILE${NC}"
    echo -e "  ${CYAN}• 文件大小: $log_size${NC}"
    echo -e "  ${CYAN}• 行数: $log_lines${NC}"
    echo -e "  ${CYAN}• 最后修改: $last_modified${NC}"
    echo
    
    print_message $CYAN "日志管理选项:"
    echo -e "${CYAN}[1] 查看实时日志${NC}"
    echo -e "${CYAN}[2] 查看最后50行${NC}"
    echo -e "${CYAN}[3] 查看最后100行${NC}"
    echo -e "${CYAN}[4] 查看全部日志${NC}"
    echo -e "${CYAN}[5] 搜索错误日志${NC}"
    echo -e "${CYAN}[6] 搜索警告日志${NC}"
    echo -e "${CYAN}[7] 搜索特定关键词${NC}"
    echo -e "${CYAN}[8] 清空日志文件${NC}"
    echo -e "${CYAN}[9] 压缩日志文件${NC}"
    echo -e "${CYAN}[0] 返回${NC}"
    echo
    
    read -p "请选择 [0-9]: " log_choice
    
    case $log_choice in
        1)
            print_message $BLUE "📋 实时日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示实时日志，按任意键返回主菜单..."
            echo
            # 先显示一些日志
            tail -n 10 "$LOG_FILE" 2>/dev/null
            echo
            print_message $CYAN "=== 实时日志开始 ==="
            print_message $YELLOW "按任意键返回主菜单..."
            
            # 使用timeout确保不会无限等待
            timeout 60 tail -f "$LOG_FILE" 2>/dev/null &
            TAIL_PID=$!
            
            # 强制等待用户按键，使用更可靠的方法
            while true; do
                if read -t 1 -n 1 -s; then
                    break
                fi
                # 检查tail进程是否还在运行
                if ! kill -0 $TAIL_PID 2>/dev/null; then
                    break
                fi
            done
            
            # 立即停止tail进程
            kill $TAIL_PID 2>/dev/null
            wait $TAIL_PID 2>/dev/null
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        2)
            print_message $BLUE "📋 最后50行日志（任意键返回主菜单）..."
            tail -n 50 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        3)
            print_message $BLUE "📋 最后100行日志（任意键返回主菜单）..."
            tail -n 100 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        4)
            print_message $BLUE "📋 全部日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示全部日志，按任意键返回主菜单..."
            echo
            
            # 使用分页显示，但强制提供退出选项
            if command -v less &> /dev/null; then
                # 使用less但设置环境变量强制退出
                LESS_IS_MORE=1 less -R "$LOG_FILE"
            elif command -v more &> /dev/null; then
                more "$LOG_FILE"
            else
                # 如果没有分页工具，使用cat但强制等待按键
                cat "$LOG_FILE" 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
            fi
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        5)
            print_message $BLUE "📋 搜索错误日志（任意键返回主菜单）..."
            echo -e "${RED}错误信息:${NC}"
            grep -i "error\|exception\|traceback\|failed\|critical" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        6)
            print_message $BLUE "📋 搜索警告日志（任意键返回主菜单）..."
            echo -e "${YELLOW}警告信息:${NC}"
            grep -i "warning\|warn" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        7)
            print_message $BLUE "📋 搜索特定关键词（任意键返回主菜单）..."
            read -p "请输入搜索关键词: " keyword
            if [ -n "$keyword" ]; then
                print_message $BLUE "📋 搜索结果:"
                echo
                grep -i "$keyword" "$LOG_FILE" | tail -n 20 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
                echo
                print_message $CYAN "已返回主菜单"
            else
                print_message $RED "❌ 关键词不能为空"
                sleep 1
            fi
            ;;
        8)
            print_message $RED "⚠️ 确认清空日志文件?"
            read -p "此操作不可逆 (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                > "$LOG_FILE"
                print_message $GREEN "✅ 日志文件已清空"
            else
                print_message $YELLOW "❌ 取消清空操作"
            fi
            sleep 1
            ;;
        9)
            print_message $BLUE "📋 压缩日志文件..."
            local backup_log="$LOG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$LOG_FILE" "$backup_log"
            gzip "$backup_log"
            print_message $GREEN "✅ 日志已备份并压缩: $backup_log.gz"
            sleep 1
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            sleep 1
            ;;
    esac
}

# 显示菜单
show_menu() {
    local status=$(check_bot_status)
    local status_text="❌ 未运行"
    local pid_info=""
    
    if [ "$status" = "running" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            status_text="✅ 正在运行"
            pid_info=" (PID: $pid)"
        else
            status_text="❌ 未运行"
        fi
    fi
    
    clear
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    FinalShell 机器人管理菜单${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo -e "当前状态: ${status_text}${pid_info}"
    
    # 显示系统信息
    echo -e "${CYAN}Python版本: $($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)${NC}"
    echo -e "${CYAN}项目路径: $PROJECT_DIR${NC}"
    
    # 显示环境配置状态
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}配置状态: ✅ 已配置${NC}"
    else
        echo -e "${RED}配置状态: ❌ 未配置${NC}"
    fi
    
    # 显示Guard状态
    local guard_status="❌ 未运行"
    if [ -f "$PROJECT_DIR/guard.pid" ]; then
        local guard_pid=$(cat "$PROJECT_DIR/guard.pid" 2>/dev/null)
        if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
            guard_status="✅ 正在运行"
        fi
    fi
    echo -e "${CYAN}Guard状态: $guard_status${NC}"
    
    # 显示日志文件状态
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        echo -e "${CYAN}日志文件: $LOG_FILE (${log_size})${NC}"
    else
        echo -e "${YELLOW}日志文件: 不存在${NC}"
    fi
    
    echo
    echo -e "${BLUE}=== 🤖 机器人管理 ===${NC}"
    echo -e "${CYAN}[1] 启动/重启机器人${NC}"
    echo -e "${CYAN}[2] 停止机器人${NC}"
    echo -e "${CYAN}[3] 日志管理${NC}"
    echo -e "${CYAN}[4] 检查进程状态${NC}"
    echo -e "${CYAN}[5] 检查并安装更新${NC}"
    echo -e "${CYAN}[6] 检查/修复依赖${NC}"
    echo -e "${CYAN}[7] 重新安装依赖${NC}"
    echo -e "${CYAN}[8] 检查/修复虚拟环境${NC}"
    echo -e "${CYAN}[9] 卸载机器人${NC}"
    echo
    echo -e "${BLUE}=== 🛡️ 守护进程管理 ===${NC}"
    echo -e "${CYAN}[g] Guard 守护进程管理${NC}"
    echo
    echo -e "${BLUE}=== ⚙️ 系统配置 ===${NC}"
    echo -e "${CYAN}[c] 配置Bot Token和Chat ID${NC}"
    echo -e "${CYAN}[m] 启动/停止监控守护进程${NC}"
    echo -e "${CYAN}[s] 显示系统状态${NC}"
    echo -e "${CYAN}[r] 手动重启机器人${NC}"
    echo -e "${CYAN}[v] 验证配置${NC}"
    echo -e "${CYAN}[f] 修复配置${NC}"
    echo
    echo -e "${CYAN}[0] 退出${NC}"
    echo
    
    # 根据配置状态显示不同提示
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}💡 提示: 配置已完成，可以启动机器人${NC}"
    else
        echo -e "${RED}💡 提示: 请先配置Bot Token和Chat ID${NC}"
    fi
    echo -e "${YELLOW}💡 提示: 使用 [g] 进入Guard守护进程管理${NC}"
    echo
}

# 快速检查依赖（不安装）
quick_check_dependencies() {
    # 检查主要依赖是否已安装
    if $PYTHON_CMD -c "import telegram, dotenv, Crypto" 2>/dev/null; then
        return 0  # 所有依赖都已安装
    else
        return 1  # 有依赖缺失
    fi
}

# 检查并激活虚拟环境
check_and_activate_venv() {
    local venv_dir="$PROJECT_DIR/venv"
    
    if [ -d "$venv_dir" ]; then
        if [ -z "$VIRTUAL_ENV" ]; then
            print_message $BLUE "🐍 激活虚拟环境..."
            source "$venv_dir/bin/activate"
            
            if [ -n "$VIRTUAL_ENV" ]; then
                print_message $GREEN "✅ 虚拟环境已激活: $(basename "$VIRTUAL_ENV")"
                # 更新Python命令
                PYTHON_CMD="$venv_dir/bin/python"
                PIP_CMD="$venv_dir/bin/pip"
            else
                print_message $RED "❌ 虚拟环境激活失败"
                exit 1
            fi
        else
            print_message $GREEN "✅ 虚拟环境已激活: $(basename "$VIRTUAL_ENV")"
        fi
    else
        print_message $RED "❌ 虚拟环境不存在: $venv_dir"
        print_message $YELLOW "请重新运行安装脚本或手动创建虚拟环境"
        exit 1
    fi
}

# 主函数
main() {
    # 检查并激活虚拟环境
    check_and_activate_venv
    
    # 显示欢迎信息
    clear
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  FinalShell 激活码机器人管理器${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo -e "${CYAN}项目地址: ${GITHUB_REPO}${NC}"
    echo -e "${CYAN}版本: 1.0${NC}"
    echo
    
    # 检查并下载项目
    print_message $BLUE "🔍 检查项目文件..."
    download_project
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 项目下载失败，请检查网络连接"
        print_message $YELLOW "请确保网络连接正常，并且可以访问GitHub"
        exit 1
    fi
    
    # 检查是否在项目目录
    if [ ! -f "$PROJECT_DIR/bot.py" ]; then
        print_message $RED "❌ 项目文件不完整，请重新运行脚本"
        exit 1
    fi
    
    # 检查并注册全局命令
    if ! check_global_command; then
        print_message $YELLOW "🔧 检测到首次运行，正在注册全局命令..."
        register_global_command
        if [ $? -ne 0 ]; then
            print_message $YELLOW "⚠️ 全局命令注册失败，但脚本仍可正常使用"
        fi
    else
        print_message $GREEN "✅ 全局命令 fn-bot 已注册"
    fi
    
    # 初始化检查
    print_message $BLUE "🔍 开始环境初始化..."
    check_python
    if [ $? -ne 0 ]; then
        print_message $RED "❌ Python环境检查失败"
        exit 1
    fi
    
    # 快速检查依赖，只在缺失时才安装
    if ! quick_check_dependencies; then
        print_message $YELLOW "⚠️ 检测到缺失依赖，正在安装..."
        install_dependencies
        if [ $? -ne 0 ]; then
            print_message $RED "❌ 依赖安装失败"
            exit 1
        fi
    else
        print_message $GREEN "✅ 依赖检查通过"
    fi
    
    # 检查环境配置
    if [ ! -f "$ENV_FILE" ]; then
        print_message $BLUE "⚙️ 首次运行，需要配置Bot Token和Chat ID..."
        print_message $YELLOW "💡 请按提示完成配置，配置完成后即可启动机器人"
        print_message $CYAN "📋 配置完成后即可启动机器人"
        echo
        
        # 强制配置，不提供跳过选项
        while true; do
            force_setup_environment
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 配置完成！现在可以启动机器人了"
                break
            else
                print_message $YELLOW "⚠️ 配置未完成，请重新配置"
                echo
                read -p "按回车键重新开始配置..." -r
                echo
            fi
        done
        echo
        
        # 配置完成后询问是否立即启动机器人
        print_message $BLUE "🚀 配置已完成！"
        read -p "是否立即启动机器人? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_bot
            echo
            read -p "按回车键进入管理界面..." -r
        fi
    else
        print_message $GREEN "✅ 环境配置已存在"
    fi
    
    # ====== 新增：自动检测并后台启动bot ======
    local need_start=0
    if [ -f "$ENV_FILE" ]; then
        if [ ! -f "$PID_FILE" ]; then
            need_start=1
        else
            local pid=$(cat "$PID_FILE" 2>/dev/null)
            if [ -z "$pid" ] || ! ps -p $pid > /dev/null 2>&1; then
                need_start=1
            fi
        fi
        if [ $need_start -eq 1 ]; then
            print_message $YELLOW "检测到机器人未在后台运行，正在自动启动..."
            start_bot
        fi
    fi
    # ====== 新增结束 ======
    print_message $GREEN "✅ 初始化完成！"
    print_message $CYAN "💡 提示：现在可以在任意目录使用 'fn-bot' 命令启动此脚本"
    print_message $YELLOW "⚠️ 注意：Ctrl+C 已被屏蔽，请使用菜单选项退出"
    
    # 根据配置状态显示不同信息
    if [ -f "$ENV_FILE" ]; then
        print_message $GREEN "🚀 配置已完成，可以启动机器人了！"
    else
        print_message $YELLOW "⚙️ 请先配置Bot Token和Chat ID"
    fi
    
    print_message $BLUE "📋 正在启动管理界面..."
    sleep 2
    
    # 主菜单循环
    while true; do
        show_menu
        read -p "请选择操作 [0-9cgmsvrf]: " choice
        
        case $choice in
            1)
                # 检查配置是否完成
                if [ ! -f "$ENV_FILE" ]; then
                    print_message $RED "❌ 请先配置Bot Token和Chat ID"
                    print_message $YELLOW "请选择选项 [c] 进行配置"
                    read -p "按回车键继续..."
                    continue
                fi
                start_bot
                ;;
            2)
                stop_bot
                ;;
            3)
                manage_logs
                ;;
            4)
                check_process
                ;;
            5)
                check_updates
                ;;
            6)
                check_dependencies
                ;;
            7)
                reinstall_dependencies
                ;;
            8)
                check_venv
                ;;
            9)
                uninstall_bot
                ;;
            g|G)
                open_guard_menu
                ;;
            c|C)
                print_message $BLUE "⚙️ 配置Bot Token和Chat ID..."
                setup_environment
                if [ $? -eq 0 ]; then
                    print_message $GREEN "✅ 配置完成！现在可以启动机器人了"
                fi
                ;;
            m|M)
                local monitor_status=$(check_monitor_status)
                if [ "$monitor_status" = "running" ]; then
                    print_message $YELLOW "监控守护进程正在运行，是否停止？"
                    read -p "停止监控守护进程? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        stop_monitor_daemon
                    fi
                else
                    print_message $BLUE "启动监控守护进程..."
                    start_monitor_daemon
                fi
                ;;
            s|S)
                show_system_status
                read -p "按回车键继续..." -r
                ;;
            r|R)
                print_message $BLUE "手动重启机器人..."
                if auto_restart_bot; then
                    print_message $GREEN "✅ 机器人重启成功"
                else
                    print_message $RED "❌ 机器人重启失败"
                fi
                read -p "按回车键继续..." -r
                ;;
            v|V)
                echo
                if validate_configuration; then
                    print_message $GREEN "🎉 配置验证通过，可以启动机器人！"
                else
                    echo
                    show_config_fix_suggestions
                    echo
                    read -p "是否尝试自动修复? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        auto_fix_config
                        echo
                        print_message $BLUE "请重新验证配置"
                    fi
                fi
                read -p "按回车键继续..." -r
                ;;
            f|F)
                print_message $BLUE "🔧 开始自动修复配置..."
                auto_fix_config
                echo
                print_message $BLUE "修复完成，建议重新验证配置"
                read -p "按回车键继续..." -r
                ;;
            0)
                safe_exit
                ;;
            *)
                print_message $RED "❌ 无效选择，请输入 0-9、g、c、m、s、v、r 或 f"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# Guard菜单调用函数
open_guard_menu() {
    print_message $BLUE "🛡️ 进入Guard守护进程管理..."
    
    # 检查guard.sh是否存在
    if [ ! -f "$PROJECT_DIR/guard.sh" ]; then
        print_message $RED "❌ guard.sh文件不存在"
        print_message $YELLOW "请确保Guard守护程序已正确安装"
        read -p "按回车键返回主菜单..." -r
        return
    fi
    
    # 设置返回标志
    export GUARD_RETURN_TO_MAIN="true"
    export MAIN_MENU_PATH="$PROJECT_DIR/start.sh"
    
    # 调用guard.sh菜单
    cd "$PROJECT_DIR"
    bash guard.sh
    
    # 清除返回标志
    unset GUARD_RETURN_TO_MAIN
    unset MAIN_MENU_PATH
    
    print_message $CYAN "🔙 已返回主菜单"
}

# 监控管理菜单
monitor_menu() {
    while true; do
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}        监控管理菜单${NC}"
        echo -e "${PURPLE}================================${NC}"
        
        # 检查监控状态
        local monitor_pid_file="$PROJECT_DIR/monitor.pid"
        local monitor_status="❌ 未运行"
        if [ -f "$monitor_pid_file" ]; then
            local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null)
            if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
                monitor_status="✅ 正在运行 (PID: $monitor_pid)"
            else
                monitor_status="❌ 未运行"
                rm -f "$monitor_pid_file"
            fi
        fi
        
        echo -e "监控状态: ${monitor_status}"
        
        # 显示健康检查结果
        local health=$(health_check)
        local health_text=""
        case $health in
            "healthy")
                health_text="✅ 健康"
                ;;
            "stopped")
                health_text="❌ 已停止"
                ;;
            "unresponsive")
                health_text="⚠️ 无响应"
                ;;
            "no_log")
                health_text="⚠️ 无日志"
                ;;
        esac
        echo -e "机器人健康: ${health_text}"
        
        echo
        echo -e "${CYAN}[1] 启动监控守护进程${NC}"
        echo -e "${CYAN}[2] 停止监控守护进程${NC}"
        echo -e "${CYAN}[3] 手动健康检查${NC}"
        echo -e "${CYAN}[4] 手动重启机器人${NC}"
        echo -e "${CYAN}[5] 查看监控日志${NC}"
        echo -e "${CYAN}[6] 查看重启日志${NC}"
        echo -e "${CYAN}[7] 手动日志轮转${NC}"
        echo -e "${CYAN}[0] 返回主菜单${NC}"
        echo
        
        read -p "请选择操作 [0-7]: " monitor_choice
        
        case $monitor_choice in
            1)
                if [ -f "$monitor_pid_file" ]; then
                    local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null)
                    if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
                        print_message $YELLOW "⚠️ 监控守护进程已在运行"
                    else
                        start_monitor_daemon
                    fi
                else
                    start_monitor_daemon
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            2)
                stop_monitor_daemon
                read -p "按任意键继续..." -n 1 -r
                ;;
            3)
                print_message $BLUE "🔍 执行健康检查..."
                local health=$(health_check)
                case $health in
                    "healthy")
                        print_message $GREEN "✅ 机器人运行正常"
                        ;;
                    "stopped")
                        print_message $RED "❌ 机器人已停止"
                        ;;
                    "unresponsive")
                        print_message $YELLOW "⚠️ 机器人可能无响应（日志超过5分钟未更新）"
                        ;;
                    "no_log")
                        print_message $YELLOW "⚠️ 进程运行但无日志文件"
                        ;;
                esac
                read -p "按任意键继续..." -n 1 -r
                ;;
            4)
                print_message $BLUE "🔄 手动重启机器人..."
                auto_restart_bot
                read -p "按任意键继续..." -n 1 -r
                ;;
            5)
                if [ -f "$PROJECT_DIR/monitor.log" ]; then
                    print_message $BLUE "📋 监控日志（最后50行）:"
                    tail -n 50 "$PROJECT_DIR/monitor.log"
                else
                    print_message $YELLOW "⚠️ 监控日志文件不存在"
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            6)
                if [ -f "$LOG_FILE.restart" ]; then
                    print_message $BLUE "📋 重启日志:"
                    cat "$LOG_FILE.restart"
                else
                    print_message $YELLOW "⚠️ 重启日志文件不存在"
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            7)
                print_message $BLUE "🔄 执行日志轮转..."
                rotate_logs
                read -p "按任意键继续..." -n 1 -r
                ;;
            0)
                return
                ;;
            *)
                print_message $RED "❌ 无效选择"
                read -p "按任意键继续..." -n 1 -r
                ;;
        esac
    done
}

# 运行主函数
main