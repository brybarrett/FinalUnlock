#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v2.0
# 集成Guard守护程序自动安装

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

# 检查网络连接
print_message $BLUE "🌐 检查网络连接..."
if ! ping -c 1 github.com > /dev/null 2>&1; then
    print_message $RED "❌ 无法连接到GitHub，请检查网络连接"
    exit 1
fi

# 检查curl或wget
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -L -o"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -O"
else
    print_message $RED "❌ 未找到curl或wget，请先安装"
    exit 1
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
print_message $BLUE "📁 创建临时目录: $TEMP_DIR"

# 下载安装脚本
print_message $BLUE "📥 下载安装脚本..."
$DOWNLOAD_CMD "$TEMP_DIR/install.sh" "https://raw.githubusercontent.com/xymn2023/FinalUnlock/main/install.sh"

if [ $? -ne 0 ]; then
    print_message $RED "❌ 下载安装脚本失败"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 设置执行权限
chmod +x "$TEMP_DIR/install.sh"

# 执行安装脚本
print_message $GREEN "🚀 开始安装..."
"$TEMP_DIR/install.sh"

# 清理临时文件
rm -rf "$TEMP_DIR"

print_message $GREEN "✅ 一键安装完成！"
print_message $CYAN "💡 安装过程中已配置Bot Token和Chat ID"
print_message $YELLOW "📋 机器人已准备就绪，可以在管理界面中启动"
print_message $BLUE "⏳ 管理界面已启动，您可以开始使用机器人..."

# 在安装完成后添加Guard安装和配置

# 安装Guard依赖
install_guard_dependencies() {
    print_message $BLUE "📦 在虚拟环境中安装Guard守护程序依赖..."
    
    # 确保在项目目录中
    cd "$INSTALL_DIR"
    
    # 激活虚拟环境
    if [ -d "venv" ]; then
        source venv/bin/activate
        
        if [ -n "$VIRTUAL_ENV" ]; then
            print_message $GREEN "✅ 虚拟环境已激活"
            
            # 在虚拟环境中安装Guard依赖
            pip install schedule psutil
            
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ Guard依赖安装完成"
                return 0
            else
                print_message $RED "❌ Guard依赖安装失败"
                return 1
            fi
        else
            print_message $RED "❌ 虚拟环境激活失败"
            return 1
        fi
    else
        print_message $RED "❌ 虚拟环境不存在"
        return 1
    fi
}

# 修改Guard启动函数
start_guard_daemon() {
    print_message $BLUE "🛡️ 启动Guard守护程序..."
    
    cd "$INSTALL_DIR"
    
    # 检查Guard文件是否存在
    if [ ! -f "guard.py" ]; then
        print_message $RED "❌ guard.py文件不存在"
        return 1
    fi
    
    # 激活虚拟环境并启动
    if [ -d "venv" ]; then
        source venv/bin/activate
        
        if [ -n "$VIRTUAL_ENV" ]; then
            # 设置执行权限
            chmod +x guard.sh 2>/dev/null
            
            # 使用虚拟环境中的Python启动Guard守护进程
            nohup python guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
            local guard_pid=$!
            echo $guard_pid > guard.pid
            
            # 检查启动是否成功
            sleep 3
            if ps -p $guard_pid > /dev/null 2>&1; then
                print_message $GREEN "✅ Guard守护程序启动成功 (PID: $guard_pid)"
                return 0
            else
                print_message $RED "❌ Guard守护程序启动失败"
                rm -f guard.pid
                return 1
            fi
        else
            print_message $RED "❌ 虚拟环境激活失败"
            return 1
        fi
    else
        print_message $RED "❌ 虚拟环境不存在"
        return 1
    fi
}

# 发送初始自检报告
send_initial_report() {
    print_message $BLUE "📤 发送初始自检报告..."
    
    cd "$INSTALL_DIR"
    
    # 等待一下确保Guard程序完全启动
    sleep 5
    
    # 执行初始自检并发送报告
    if python3 guard.py initial; then
        print_message $GREEN "✅ 初始自检报告已发送到Telegram"
        return 0
    else
        print_message $YELLOW "⚠️ 初始自检报告发送失败，但不影响正常使用"
        return 1
    fi
}

# 在原有安装流程的最后添加Guard安装

print_message $GREEN "✅ 基础安装完成！"
echo
print_message $CYAN "🛡️ 正在安装Guard守护程序..."

# 安装Guard依赖
if install_guard_dependencies; then
    # 启动Guard守护程序
    if start_guard_daemon; then
        # 发送初始自检报告
        send_initial_report
        
        echo
        print_message $GREEN "🎉 完整安装成功！"
        print_message $CYAN "📋 系统功能:"
        print_message $CYAN "  • FinalShell激活码机器人已启动"
        print_message $CYAN "  • Guard守护程序已启动"
        print_message $CYAN "  • 自动自检功能已激活"
        echo
        print_message $YELLOW "⏰ 自动化时间表:"
        print_message $CYAN "  • 每天 00:00 - 执行系统自检"
        print_message $CYAN "  • 每天 07:00 - 发送详细报告"
        print_message $CYAN "  • 随时可用 - 发送 /guard 获取最新报告"
        echo
        print_message $BLUE "📱 Telegram命令:"
        print_message $CYAN "  • /guard - 获取最新自检报告"
        print_message $CYAN "  • /help - 查看所有可用命令"
        
    else
        print_message $YELLOW "⚠️ Guard守护程序启动失败，但机器人可正常使用"
        print_message $CYAN "💡 可稍后手动启动: ./guard.sh"
    fi
else
    print_message $YELLOW "⚠️ Guard依赖安装失败，但机器人可正常使用"
    print_message $CYAN "💡 可稍后手动安装: pip install schedule psutil"
fi

echo
print_message $GREEN "🚀 安装流程全部完成！"
print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
print_message $CYAN "💡 使用 './guard.sh' 命令可以管理Guard守护程序"

# 继续原有的启动管理脚本逻辑...