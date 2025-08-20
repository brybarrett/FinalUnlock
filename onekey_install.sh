#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v6.1
# 完美版本 - 静默安装 + 自动清理 + 用户配置 + 修复版

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
echo -e "${PURPLE}  FinalShell 激活码机器人一键安装${NC}"
echo -e "${PURPLE}     完美版本 v6.1${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}静默安装 + 自动清理 + 智能配置${NC}"
echo

# ==========================================
# 第一步：预检查和清理
# ==========================================

precheck_and_cleanup() {
    print_message $BLUE "🔍 第一步：系统预检查和清理..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ 此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查网络连接
    print_message $YELLOW "🌐 检查网络连接..."
    if ! ping -c 1 -W 3 github.com > /dev/null 2>&1; then
        print_message $RED "❌ 网络连接失败，请检查网络设置"
        exit 1
    fi
    print_message $GREEN "✅ 网络连接正常"
    
    # 检查并清理现有安装
    local install_dirs=("/usr/local/FinalUnlock" "$HOME/FinalUnlock")
    for dir in "${install_dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_message $YELLOW "🗑️ 检测到现有安装目录: $dir"
            print_message $BLUE "🔄 自动清理现有安装..."
            
            # 停止可能运行的进程
            if [ -f "$dir/bot.pid" ]; then
                local pid=$(cat "$dir/bot.pid" 2>/dev/null)
                if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
                    print_message $YELLOW "⏹️ 停止运行中的机器人..."
                    kill $pid 2>/dev/null
                    sleep 2
                fi
            fi
            
            if [ -f "$dir/guard.pid" ]; then
                local guard_pid=$(cat "$dir/guard.pid" 2>/dev/null)
                if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
                    print_message $YELLOW "⏹️ 停止运行中的Guard..."
                    kill $guard_pid 2>/dev/null
                    sleep 2
                fi
            fi
            
            # 删除目录
            rm -rf "$dir"
            print_message $GREEN "✅ 已清理: $dir"
        fi
    done
    
    # 清理全局命令
    if [ -f "/usr/local/bin/fn-bot" ]; then
        print_message $YELLOW "🗑️ 清理现有全局命令..."
        sudo rm -f /usr/local/bin/fn-bot
        print_message $GREEN "✅ 已清理全局命令"
    fi
    
    print_message $GREEN "✅ 预检查和清理完成"
    echo
}

# ==========================================
# 第二步：静默安装系统依赖
# ==========================================

silent_install_dependencies() {
    print_message $BLUE "📦 第二步：检查系统依赖..."
    
    # 检查必要工具
    local missing_tools=()
    local tools=("curl" "git" "python3" "pip3")
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    # 检查Python模块
    if ! python3 -c "import venv" 2>/dev/null; then
        missing_tools+=("python3-venv")
    fi
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有系统依赖已满足"
    else
        print_message $YELLOW "📥 安装缺失的依赖: ${missing_tools[*]}"
        
        # 静默安装缺失的依赖
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq > /dev/null 2>&1
            for tool in "${missing_tools[@]}"; do
                case $tool in
                    "pip3") sudo apt-get install -qq -y python3-pip > /dev/null 2>&1 ;;
                    "python3-venv") sudo apt-get install -qq -y python3-venv > /dev/null 2>&1 ;;
                    *) sudo apt-get install -qq -y $tool > /dev/null 2>&1 ;;
                esac
            done
        elif command -v yum &> /dev/null; then
            for tool in "${missing_tools[@]}"; do
                sudo yum install -y $tool > /dev/null 2>&1
            done
        fi
        
        print_message $GREEN "✅ 依赖安装完成"
    fi
    
    echo
}

# 添加详细的系统诊断函数
detailed_system_check() {
    print_message $BLUE "🔍 详细系统诊断..."
    
    # 检查磁盘空间
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_message $RED "❌ 磁盘空间不足: ${disk_usage}%"
        return 1
    else
        print_message $GREEN "✅ 磁盘空间充足: ${disk_usage}%"
    fi
    
    # 检查内存
    local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$mem_usage" -gt 95 ]; then
        print_message $YELLOW "⚠️ 内存使用率较高: ${mem_usage}%"
    else
        print_message $GREEN "✅ 内存使用正常: ${mem_usage}%"
    fi
    
    # 检查sudo权限
    if sudo -n true 2>/dev/null; then
        print_message $GREEN "✅ sudo权限正常"
    else
        print_message $YELLOW "⚠️ 需要sudo权限，请确保当前用户有sudo权限"
    fi
    
    # 检查Python环境
    if python3 --version > /dev/null 2>&1; then
        local py_version=$(python3 --version 2>&1)
        print_message $GREEN "✅ Python环境: $py_version"
    else
        print_message $RED "❌ Python3未安装或不可用"
        return 1
    fi
    
    # 检查git
    if git --version > /dev/null 2>&1; then
        print_message $GREEN "✅ Git已安装"
    else
        print_message $RED "❌ Git未安装"
        return 1
    fi
    
    return 0
}

# 添加手动安装备选方案
manual_installation_fallback() {
    print_message $YELLOW "🔧 尝试手动安装备选方案..."
    
    # 直接克隆项目
    local install_dir="/usr/local/FinalUnlock"
    
    print_message $BLUE "📥 直接克隆项目..."
    if git clone https://github.com/xymn2023/FinalUnlock.git "$install_dir"; then
        print_message $GREEN "✅ 项目克隆成功"
    else
        print_message $RED "❌ 项目克隆失败"
        return 1
    fi
    
    cd "$install_dir"
    
    # 创建虚拟环境
    print_message $BLUE "🐍 创建虚拟环境..."
    if python3 -m venv venv; then
        print_message $GREEN "✅ 虚拟环境创建成功"
    else
        print_message $RED "❌ 虚拟环境创建失败"
        return 1
    fi
    
    # 激活虚拟环境并安装依赖
    print_message $BLUE "📦 安装依赖..."
    source venv/bin/activate
    
    if pip install --upgrade pip && pip install -r requirements.txt; then
        print_message $GREEN "✅ 依赖安装成功"
    else
        print_message $RED "❌ 依赖安装失败"
        return 1
    fi
    
    # 创建全局命令
    print_message $BLUE "🔧 创建全局命令..."
    local start_script="#!/bin/bash\ncd \"$install_dir\"\nsource \"$install_dir/venv/bin/activate\"\n\"$install_dir/start.sh\" \"\$@\""
    
    echo -e "$start_script" | sudo tee /usr/local/bin/fn-bot > /dev/null
    sudo chmod +x /usr/local/bin/fn-bot
    
    print_message $GREEN "✅ 手动安装完成"
    return 0
}

# ==========================================
# 第三步：下载并执行安装（修复版）
# ==========================================

download_and_install() {
    print_message $BLUE "📥 第三步：下载最新版本并安装..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    
    # 下载最新的install.sh
    print_message $YELLOW "🔄 下载最新安装脚本..."
    if ! curl -s -L "https://raw.githubusercontent.com/xymn2023/FinalUnlock/main/install.sh" -o "$TEMP_DIR/install.sh"; then
        print_message $RED "❌ 下载失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    chmod +x "$TEMP_DIR/install.sh"
    print_message $GREEN "✅ 最新安装脚本下载完成"
    
    # 执行安装（显示详细错误）
    print_message $YELLOW "🚀 执行项目安装..."
    print_message $CYAN "💡 如果出现错误，将显示详细信息"
    
    # 不再静默执行，显示错误信息
    if "$TEMP_DIR/install.sh"; then
        print_message $GREEN "✅ 项目安装完成"
        rm -rf "$TEMP_DIR"
    else
        local exit_code=$?
        print_message $RED "❌ 项目安装失败 (退出码: $exit_code)"
        print_message $YELLOW "🔍 可能的原因:"
        print_message $CYAN "  • install.sh脚本存在问题"
        print_message $CYAN "  • 权限不足"
        print_message $CYAN "  • 系统环境问题"
        print_message $CYAN "  • 网络连接问题"
        
        print_message $BLUE "🛠️ 建议解决方案:"
        print_message $CYAN "  1. 检查系统权限: sudo权限是否正常"
        print_message $CYAN "  2. 手动执行: 下载install.sh手动运行查看错误"
        print_message $CYAN "  3. 检查磁盘空间: df -h"
        print_message $CYAN "  4. 检查网络: ping github.com"
        
        rm -rf "$TEMP_DIR"
        
        print_message $YELLOW "🔄 尝试备选安装方案..."
        if manual_installation_fallback; then
            print_message $GREEN "✅ 备选方案安装成功"
        else
            print_message $RED "❌ 所有安装方案都失败"
            exit 1
        fi
    fi
    
    echo
}

# ==========================================
# 第四步：用户配置收集
# ==========================================

collect_user_configuration() {
    print_message $BLUE "⚙️ 第四步：配置Bot Token和Chat ID..."
    
    # 查找项目安装目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock"; do
        if [ -d "$dir" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到项目安装目录"
        exit 1
    fi
    
    print_message $GREEN "✅ 项目目录: $project_dir"
    cd "$project_dir"
    
    # 显示配置指南
    print_message $CYAN "📖 配置指南:"
    echo
    print_message $CYAN "🤖 Bot Token获取:"
    print_message $CYAN "   1. Telegram搜索 @BotFather → 发送 /newbot"
    print_message $CYAN "   2. 设置机器人名称 → 复制Token"
    print_message $CYAN "   3. 格式: 123456789:ABCdefGHI..."
    echo
    print_message $CYAN "👤 Chat ID获取:"
    print_message $CYAN "   1. Telegram搜索 @userinfobot → 发送消息"
    print_message $CYAN "   2. 复制显示的数字ID"
    print_message $CYAN "   3. 格式: 123456789"
    echo
    
    read -p "准备好后按回车键开始配置..." -r
    echo
    
    # 收集Bot Token
    local bot_token=""
    while true; do
        print_message $BLUE "🤖 请输入Telegram Bot Token:"
        read -p "Bot Token: " bot_token
        
        if [ -z "$bot_token" ]; then
            print_message $RED "❌ 不能为空，请重新输入"
            continue
        fi
        
        # 验证格式
        if [[ ! "$bot_token" =~ ^[0-9]+:[A-Za-z0-9_-]{35,}$ ]]; then
            print_message $RED "❌ 格式不正确"
            print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHI..."
            continue
        fi
        
        # 在线验证
        print_message $YELLOW "🌐 验证Token有效性..."
        if curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q '"ok":true'; then
            print_message $GREEN "✅ Token验证成功！"
            break
        else
            print_message $YELLOW "⚠️ Token验证失败"
            read -p "是否继续使用? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done
    
    # 收集Chat ID
    local chat_id=""
    while true; do
        print_message $BLUE "👤 请输入Telegram Chat ID:"
        read -p "Chat ID: " chat_id
        
        if [ -z "$chat_id" ]; then
            print_message $RED "❌ 不能为空，请重新输入"
            continue
        fi
        
        # 验证格式
        if [[ ! "$chat_id" =~ ^[0-9]+([,][0-9]+)*$ ]]; then
            print_message $RED "❌ 格式不正确"
            print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
            continue
        fi
        
        print_message $GREEN "✅ Chat ID格式正确"
        break
    done
    
    # 确认配置
    echo
    print_message $BLUE "📋 配置确认:"
    print_message $CYAN "Bot Token: ${bot_token:0:20}..."
    print_message $CYAN "Chat ID: $chat_id"
    echo
    
    read -p "确认保存配置? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_message $RED "❌ 配置已取消"
        exit 1
    fi
    
    # 保存配置
    cat > "$project_dir/.env" << EOF
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
EOF
    
    print_message $GREEN "✅ 配置已保存"
    echo
}

# ==========================================
# 第五步：启动服务
# ==========================================

start_services() {
    print_message $BLUE "🚀 第五步：启动服务..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock"; do
        if [ -d "$dir" ] && [ -f "$dir/.env" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到配置完成的项目目录"
        exit 1
    fi
    
    cd "$project_dir"
    
    # 启动Guard守护程序
    local python_cmd="python3"
    if [ -d "venv" ]; then
        source venv/bin/activate
        python_cmd="python"
    fi
    
    print_message $YELLOW "🛡️ 启动Guard守护程序..."
    nohup $python_cmd guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
    local guard_pid=$!
    
    if [ -n "$guard_pid" ]; then
        echo $guard_pid > guard.pid
        sleep 3
        if ps -p $guard_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ Guard守护程序已启动 (PID: $guard_pid)"
        else
            print_message $YELLOW "⚠️ Guard启动失败，但不影响使用"
            rm -f guard.pid
        fi
    fi
    
    # 发送初始报告
    print_message $YELLOW "📤 发送初始自检报告..."
    sleep 5
    if $python_cmd guard.py initial 2>/dev/null; then
        print_message $GREEN "✅ 初始报告已发送到Telegram"
    else
        print_message $YELLOW "⚠️ 初始报告发送失败"
    fi
    
    print_message $GREEN "✅ 服务启动完成"
    echo
}

# ==========================================
# 第六步：显示完成信息
# ==========================================

show_completion() {
    echo
    print_message $PURPLE "================================${NC}"
    print_message $PURPLE "   🎉 安装完成！ 🎉${NC}"
    print_message $PURPLE "================================${NC}"
    echo
    
    print_message $GREEN "✅ FinalShell激活码机器人已就绪"
    print_message $GREEN "✅ 配置已完成，无需重复输入"
    print_message $GREEN "✅ Guard守护系统已启动"
    echo
    
    print_message $BLUE "📱 使用方法:"
    print_message $CYAN "  • 管理机器人: fn-bot"
    print_message $CYAN "  • Telegram命令: /start, /help, /guard"
    print_message $CYAN "  • 发送机器码获取激活码"
    echo
    
    print_message $YELLOW "⏰ 自动功能:"
    print_message $CYAN "  • 每天 00:00 - 系统自检"
    print_message $CYAN "  • 每天 07:00 - 发送报告"
    print_message $CYAN "  • 随时可用 - /guard 获取报告"
    echo
    
    print_message $GREEN "🚀 现在可以开始使用了！"
}

# ==========================================
# 主执行流程
# ==========================================

main() {
    # 第一步：预检查和清理
    precheck_and_cleanup
    
    # 第二步：静默安装依赖
    silent_install_dependencies
    
    # 新增：详细系统诊断
    if ! detailed_system_check; then
        print_message $RED "❌ 系统诊断发现问题，请解决后重试"
        exit 1
    fi
    
    # 第三步：下载并安装
    download_and_install
    
    # 第四步：用户配置
    collect_user_configuration
    
    # 第五步：启动服务
    start_services
    
    # 第六步：显示完成
    show_completion
}

# 执行主流程
main