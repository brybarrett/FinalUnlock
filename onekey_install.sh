#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v5.0
# 修复逻辑

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
echo -e "${PURPLE}     修复版本 v5.0${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}先下载项目，再配置信息${NC}"
echo

# ==========================================
# 第一步：系统环境检查
# ==========================================

check_system() {
    print_message $BLUE "🔍 第一步：系统环境检查..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ 此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查网络连接
    if ! ping -c 1 -W 3 github.com > /dev/null 2>&1; then
        print_message $RED "❌ 网络连接失败，请检查网络设置"
        exit 1
    fi
    
    # 确保有下载工具
    if ! command -v curl &> /dev/null; then
        print_message $YELLOW "⚠️ 安装curl..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        fi
    fi
    
    print_message $GREEN "✅ 系统检查通过"
    echo
}

# ==========================================
# 第二步：下载并执行安装脚本
# ==========================================

download_and_install() {
    print_message $BLUE "📥 第二步：下载安装脚本..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    print_message $BLUE "📁 创建临时目录: $TEMP_DIR"
    
    # 下载install.sh
    local download_urls=(
        "https://raw.githubusercontent.com/xymn2023/FinalUnlock/main/install.sh"
        "https://github.com/xymn2023/FinalUnlock/raw/main/install.sh"
    )
    
    local download_success=false
    for url in "${download_urls[@]}"; do
        print_message $YELLOW "🔄 尝试从 $url 下载..."
        if curl -s -L "$url" -o "$TEMP_DIR/install.sh" 2>/dev/null; then
            if [ -f "$TEMP_DIR/install.sh" ] && [ -s "$TEMP_DIR/install.sh" ]; then
                download_success=true
                print_message $GREEN "✅ 下载成功"
                break
            fi
        fi
        print_message $YELLOW "⚠️ 下载失败，尝试下一个源..."
    done
    
    if [ "$download_success" = "false" ]; then
        print_message $RED "❌ 所有下载源都失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    chmod +x "$TEMP_DIR/install.sh"
    print_message $GREEN "✅ 安装脚本下载完成"
    echo
}

# ==========================================
# 第三步：执行安装（项目会被下载）
# ==========================================

execute_installation() {
    print_message $BLUE "🚀 第三步：执行项目安装..."
    print_message $YELLOW "💡 项目将被自动下载到系统中"
    
    # 执行安装脚本（这会下载项目）
    if "$TEMP_DIR/install.sh"; then
        print_message $GREEN "✅ 项目安装完成"
    else
        print_message $RED "❌ 项目安装失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    rm -rf "$TEMP_DIR"
    print_message $GREEN "✅ 安装脚本执行完成"
    echo
}

# ==========================================
# 第四步：配置Bot Token和Chat ID
# ==========================================

configure_bot_credentials() {
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
    
    print_message $GREEN "✅ 找到项目目录: $project_dir"
    cd "$project_dir"
    
    # 现在可以安全地配置，因为项目已经下载
    print_message $YELLOW "💡 现在开始配置Bot Token和Chat ID"
    print_message $CYAN "📖 如果您还没有准备好，请按以下步骤获取："
    echo
    
    print_message $CYAN "🤖 获取Bot Token:"
    print_message $CYAN "   1. 在Telegram中搜索 @BotFather"
    print_message $CYAN "   2. 发送 /newbot 创建新机器人"
    print_message $CYAN "   3. 按提示设置机器人名称和用户名"
    print_message $CYAN "   4. 复制获得的Token（格式: 123456789:ABCdefGHI...）"
    echo
    
    print_message $CYAN "👤 获取Chat ID:"
    print_message $CYAN "   1. 在Telegram中搜索 @userinfobot"
    print_message $CYAN "   2. 发送任意消息获取您的用户ID"
    print_message $CYAN "   3. 复制显示的数字ID"
    echo
    
    read -p "准备好后按回车键开始配置..." -r
    echo
    
    # 收集Bot Token
    local bot_token=""
    while true; do
        print_message $BLUE "🤖 请输入您的Telegram Bot Token:"
        read -p "Bot Token: " bot_token
        
        if [ -z "$bot_token" ]; then
            print_message $RED "❌ Bot Token不能为空，请重新输入"
            continue
        fi
        
        # 验证Token格式
        if [[ ! "$bot_token" =~ ^[0-9]+:[A-Za-z0-9_-]{35,}$ ]]; then
            print_message $RED "❌ Bot Token格式不正确"
            print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
            continue
        fi
        
        print_message $GREEN "✅ Bot Token格式正确"
        
        # 在线验证Token
        print_message $YELLOW "🌐 验证Bot Token有效性..."
        if curl -s "https://api.telegram.org/bot$bot_token/getMe" | grep -q '"ok":true'; then
            print_message $GREEN "✅ Bot Token验证成功！"
            break
        else
            print_message $YELLOW "⚠️ Bot Token验证失败"
            read -p "是否继续使用此Token? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    done
    
    # 收集Chat ID
    local chat_id=""
    while true; do
        print_message $BLUE "👤 请输入您的Telegram Chat ID:"
        read -p "Chat ID: " chat_id
        
        if [ -z "$chat_id" ]; then
            print_message $RED "❌ Chat ID不能为空，请重新输入"
            continue
        fi
        
        # 验证Chat ID格式
        if [[ ! "$chat_id" =~ ^[0-9]+([,][0-9]+)*$ ]]; then
            print_message $RED "❌ Chat ID格式不正确"
            print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
            continue
        fi
        
        print_message $GREEN "✅ Chat ID格式正确"
        break
    done
    
    # 最终确认
    echo
    print_message $BLUE "📋 配置信息确认:"
    print_message $CYAN "Bot Token: ${bot_token:0:20}..."
    print_message $CYAN "Chat ID: $chat_id"
    echo
    
    read -p "确认保存配置? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_message $RED "❌ 配置已取消"
        exit 1
    fi
    
    # 保存配置到.env文件（现在项目已存在）
    local env_file="$project_dir/.env"
    cat > "$env_file" << EOF
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
EOF
    
    print_message $GREEN "✅ 配置已保存到 $env_file"
    echo
}

# ==========================================
# 第五步：启动Guard守护程序
# ==========================================

setup_guard() {
    print_message $BLUE "🛡️ 第五步：配置Guard守护系统..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock"; do
        if [ -d "$dir" ] && [ -f "$dir/guard.py" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $YELLOW "⚠️ 未找到项目目录，跳过Guard配置"
        return
    fi
    
    cd "$project_dir"
    
    # 启动Guard（配置已存在）
    if [ -f ".env" ]; then
        local python_cmd="python3"
        if [ -d "venv" ]; then
            source venv/bin/activate
            python_cmd="python"
        fi
        
        # 启动Guard守护程序
        print_message $YELLOW "🔄 启动Guard守护程序..."
        nohup $python_cmd guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
        local guard_pid=$!
        
        if [ -n "$guard_pid" ]; then
            echo $guard_pid > guard.pid
            sleep 3
            if ps -p $guard_pid > /dev/null 2>&1; then
                print_message $GREEN "✅ Guard守护程序已启动 (PID: $guard_pid)"
                
                # 发送初始报告
                print_message $BLUE "📤 发送初始自检报告..."
                sleep 5
                if $python_cmd guard.py initial 2>/dev/null; then
                    print_message $GREEN "✅ 初始自检报告已发送到Telegram"
                else
                    print_message $YELLOW "⚠️ 初始报告发送失败，但Guard正常运行"
                fi
            else
                print_message $YELLOW "⚠️ Guard启动失败，但不影响机器人使用"
                rm -f guard.pid
            fi
        fi
    else
        print_message $RED "❌ 配置文件不存在，无法启动Guard"
    fi
    
    print_message $GREEN "✅ Guard系统配置完成"
    echo
}

# ==========================================
# 第六步：显示安装结果
# ==========================================

show_final_result() {
    echo
    print_message $PURPLE "================================${NC}"
    print_message $PURPLE "   🎉 安装完成！ 🎉${NC}"
    print_message $PURPLE "================================${NC}"
    echo
    
    print_message $GREEN "✅ FinalShell激活码机器人已就绪"
    print_message $GREEN "✅ Bot Token和Chat ID已配置"
    print_message $GREEN "✅ Guard守护系统已启动"
    echo
    
    print_message $BLUE "📱 使用方法:"
    print_message $CYAN "  • 管理机器人: fn-bot"
    print_message $CYAN "  • Telegram命令: /start, /help"
    print_message $CYAN "  • 发送机器码获取激活码"
    print_message $CYAN "  • 发送 /guard 获取系统报告"
    echo
    
    print_message $YELLOW "💡 配置已保存，后续无需重复输入！"
    print_message $CYAN "⏰ 自动功能: 每天00:00自检，07:00发送报告"
}

# ==========================================
# 主执行流程
# ==========================================

main() {
    # 第一步：系统环境检查
    check_system
    
    # 第二步：下载安装脚本
    download_and_install
    
    # 第三步：执行安装（下载项目）
    execute_installation
    
    # 第四步：配置Bot凭据（项目已存在）
    configure_bot_credentials
    
    # 第五步：设置Guard系统
    setup_guard
    
    # 第六步：显示结果
    show_final_result
}

# 执行主流程
main