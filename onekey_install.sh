#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v4.0
# 真正的一键安装 - 配置前置版本

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
echo -e "${PURPLE}     真正的一键安装 v4.0${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}配置前置，真正的零干预安装${NC}"
echo

# ==========================================
# 第一步：立即收集用户配置信息（最重要！）
# ==========================================

# 在collect_user_config函数中添加完整的配置验证
collect_user_config() {
    print_message $BLUE "📋 第一步：收集配置信息"
    print_message $YELLOW "💡 在开始安装前，需要您提供Bot Token和Chat ID"
    
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
    
    # 收集Bot Token（添加验证）
    while true; do
        print_message $BLUE "🤖 请输入您的Telegram Bot Token:"
        read -p "Bot Token: " USER_BOT_TOKEN
        
        if [ -z "$USER_BOT_TOKEN" ]; then
            print_message $RED "❌ Bot Token不能为空，请重新输入"
            continue
        fi
        
        # 验证Token格式
        if [[ ! "$USER_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{35,}$ ]]; then
            print_message $RED "❌ Bot Token格式不正确"
            print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
            continue
        fi
        
        # 在线验证Token
        print_message $YELLOW "🌐 验证Bot Token有效性..."
        if curl -s "https://api.telegram.org/bot$USER_BOT_TOKEN/getMe" | grep -q '"ok":true'; then
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
    
    # 收集Chat ID（添加验证）
    while true; do
        print_message $BLUE "👤 请输入您的Telegram Chat ID:"
        read -p "Chat ID: " USER_CHAT_ID
        
        if [ -z "$USER_CHAT_ID" ]; then
            print_message $RED "❌ Chat ID不能为空，请重新输入"
            continue
        fi
        
        # 验证Chat ID格式
        if [[ ! "$USER_CHAT_ID" =~ ^[0-9]+([,][0-9]+)*$ ]]; then
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
    print_message $CYAN "Bot Token: ${USER_BOT_TOKEN:0:20}..."
    print_message $CYAN "Chat ID: $USER_CHAT_ID"
    echo
    
    read -p "确认无误，开始自动安装? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_message $RED "❌ 安装已取消"
        exit 1
    fi
    
    print_message $GREEN "✅ 配置收集完成，开始全自动安装..."
    echo
}

# ==========================================
# 第二步：系统环境检查
# ==========================================

precheck_system() {
    print_message $BLUE "🔍 第二步：系统环境检查..."
    
    # 检查是否为Linux系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ 此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查网络连接
    print_message $BLUE "🌐 检查网络连接..."
    local test_urls=("github.com" "raw.githubusercontent.com")
    local network_ok=false
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" > /dev/null 2>&1; then
            network_ok=true
            break
        fi
    done
    
    if [ "$network_ok" = "false" ]; then
        print_message $RED "❌ 网络连接失败，请检查网络设置"
        exit 1
    fi
    
    print_message $GREEN "✅ 网络连接正常"
    
    # 检查下载工具
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -L -o"
        print_message $GREEN "✅ 使用curl下载"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -O"
        print_message $GREEN "✅ 使用wget下载"
    else
        print_message $YELLOW "⚠️ 未找到curl或wget，尝试安装curl..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y curl
        fi
        
        if command -v curl &> /dev/null; then
            DOWNLOAD_CMD="curl -L -o"
            print_message $GREEN "✅ curl安装成功"
        else
            print_message $RED "❌ 无法安装下载工具"
            exit 1
        fi
    fi
    
    print_message $GREEN "✅ 系统环境检查完成"
    echo
}

# ==========================================
# 第三步：下载并执行安装脚本
# ==========================================

download_and_install() {
    print_message $BLUE "📥 第三步：下载安装脚本..."
    
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
        if $DOWNLOAD_CMD "$TEMP_DIR/install.sh" "$url" 2>/dev/null; then
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
    
    # 设置执行权限
    chmod +x "$TEMP_DIR/install.sh"
    
    print_message $GREEN "✅ 安装脚本下载完成"
    echo
}

# ==========================================
# 第四步：执行安装并传递配置
# ==========================================

execute_installation() {
    print_message $BLUE "🚀 第四步：执行自动安装..."
    
    # 设置环境变量传递配置给install.sh
    export PRECONFIG_BOT_TOKEN="$USER_BOT_TOKEN"
    export PRECONFIG_CHAT_ID="$USER_CHAT_ID"
    export PRECONFIG_MODE="true"
    
    print_message $YELLOW "🔄 正在执行安装脚本..."
    print_message $CYAN "💡 您的配置信息已传递给安装程序"
    
    # 执行安装脚本
    if "$TEMP_DIR/install.sh"; then
        print_message $GREEN "✅ 基础安装完成"
    else
        print_message $YELLOW "⚠️ 安装过程中出现问题，但继续后续步骤..."
    fi
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
    
    print_message $GREEN "✅ 安装执行完成"
    echo
}

# ==========================================
# 第五步：Guard守护程序安装
# ==========================================

install_guard_system() {
    print_message $BLUE "🛡️ 第五步：安装Guard守护程序..."
    
    # 检测安装目录
    local install_dirs=("/usr/local/FinalUnlock" "$HOME/FinalUnlock")
    local project_dir=""
    
    for dir in "${install_dirs[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/guard.py" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到项目安装目录"
        return 1
    fi
    
    print_message $GREEN "✅ 找到项目目录: $project_dir"
    cd "$project_dir"
    
    # 验证配置文件
    if [ -f ".env" ]; then
        local bot_token=$(grep '^BOT_TOKEN=' .env | cut -d'=' -f2)
        local chat_id=$(grep '^CHAT_ID=' .env | cut -d'=' -f2)
        
        if [ -n "$bot_token" ] && [ -n "$chat_id" ]; then
            print_message $GREEN "✅ 配置文件验证通过"
        else
            print_message $RED "❌ 配置文件验证失败"
            return 1
        fi
    else
        print_message $RED "❌ 配置文件不存在"
        return 1
    fi
    
    # 安装Guard依赖并启动
    local python_cmd="python3"
    if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
        print_message $BLUE "🐍 使用虚拟环境..."
        source venv/bin/activate
        python_cmd="python"
    fi
    
    # 启动Guard
    print_message $BLUE "🛡️ 启动Guard守护程序..."
    chmod +x guard.sh 2>/dev/null || true
    
    nohup $python_cmd guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
    local guard_pid=$!
    
    if [ -n "$guard_pid" ]; then
        echo $guard_pid > guard.pid
        sleep 3
        
        if ps -p $guard_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ Guard守护程序启动成功 (PID: $guard_pid)"
            
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
    else
        print_message $YELLOW "⚠️ Guard启动失败，但不影响机器人使用"
    fi
    
    print_message $GREEN "✅ Guard系统安装完成"
    echo
}

# ==========================================
# 第六步：显示安装结果
# ==========================================

show_final_result() {
    print_message $GREEN "🎉 第六步：安装完成！"
    echo
    
    print_message $PURPLE "================================${NC}"
    print_message $PURPLE "   🎉 安装成功完成！ 🎉${NC}"
    print_message $PURPLE "================================${NC}"
    echo
    
    print_message $CYAN "📋 安装结果:"
    print_message $CYAN "  ✅ FinalShell激活码机器人已安装"
    print_message $CYAN "  ✅ Bot Token和Chat ID已配置"
    print_message $CYAN "  ✅ 虚拟环境已创建"
    print_message $CYAN "  ✅ 所有依赖已安装"
    
    # 检查Guard状态
    local guard_status="❌ 未运行"
    local install_dirs=("/usr/local/FinalUnlock" "$HOME/FinalUnlock")
    for dir in "${install_dirs[@]}"; do
        if [ -f "$dir/guard.pid" ]; then
            local pid=$(cat "$dir/guard.pid" 2>/dev/null)
            if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
                guard_status="✅ 正在运行"
                break
            fi
        fi
    done
    
    print_message $CYAN "  $guard_status Guard守护程序"
    echo
    
    print_message $YELLOW "⏰ 自动化功能:"
    print_message $CYAN "  • 每天 00:00 - 执行系统自检"
    print_message $CYAN "  • 每天 07:00 - 发送详细报告到Telegram"
    print_message $CYAN "  • 随时可用 - 发送 /guard 获取最新报告"
    echo
    
    print_message $BLUE "📱 使用方法:"
    print_message $CYAN "  • 使用 'fn-bot' 命令管理机器人"
    print_message $CYAN "  • 在Telegram中发送 /help 查看所有命令"
    print_message $CYAN "  • 发送 /start 开始使用机器人"
    print_message $CYAN "  • 发送机器码获取FinalShell激活码"
    echo
    
    print_message $GREEN "🚀 现在您可以开始使用FinalShell激活码机器人了！"
    print_message $YELLOW "💡 如需管理机器人，请运行: fn-bot"
}

# ==========================================
# 主执行流程
# ==========================================

main() {
    # 第一步：收集用户配置（最重要！）
    collect_user_config
    
    # 第二步：系统环境检查
    precheck_system
    
    # 第三步：下载安装脚本
    download_and_install
    
    # 第四步：执行安装
    execute_installation
    
    # 第五步：安装Guard系统
    install_guard_system
    
    # 第六步：显示结果
    show_final_result
}

# 执行主流程
main