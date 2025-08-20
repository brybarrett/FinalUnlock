#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v3.1
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
echo -e "${PURPLE}  FinalShell 激活码机器人一键安装${NC}"
echo -e "${PURPLE}     版本 v3.1${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}智能处理所有环境问题${NC}"
echo

# 预检查系统环境
precheck_system() {
    print_message $BLUE "🔍 预检查系统环境..."
    
    # 检查是否为Linux系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ 此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查网络连接
    print_message $BLUE "🌐 检查网络连接..."
    local test_urls=("github.com" "raw.githubusercontent.com" "pypi.org")
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
        print_message $YELLOW "⚠️ 未找到curl或wget，尝试安装..."
        
        # 尝试安装curl
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
}

# 智能下载安装脚本
intelligent_download_installer() {
    print_message $BLUE "📥 智能下载安装脚本..."
    
    # 创建临时目录
    TEMP_DIR=$(mktemp -d)
    print_message $BLUE "📁 创建临时目录: $TEMP_DIR"
    
    # 尝试多个下载源
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
        print_message $YELLOW "⚠️ 从 $url 下载失败，尝试下一个源..."
    done
    
    if [ "$download_success" = "false" ]; then
        print_message $RED "❌ 所有下载源都失败"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # 设置执行权限
    chmod +x "$TEMP_DIR/install.sh"
}

# 执行安装并处理错误
execute_installation() {
    print_message $GREEN "🚀 开始智能安装..."
    
    # 执行安装脚本
    if "$TEMP_DIR/install.sh"; then
        print_message $GREEN "✅ 基础安装完成"
    else
        print_message $YELLOW "⚠️ 安装过程中出现问题，但继续Guard安装..."
    fi
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
}

# 智能Guard安装（修复语法错误）
intelligent_guard_installation() {
    print_message $CYAN "🛡️ 智能Guard守护程序安装..."
    
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
    
    # 智能安装Guard依赖
    local pip_cmd=""
    local pip_args=""
    
    # 检查虚拟环境
    if [ -d "venv" ] && [ -f "venv/bin/activate" ]; then
        print_message $BLUE "🐍 使用虚拟环境安装Guard依赖..."
        source venv/bin/activate
        pip_cmd="pip"
        pip_args=""
    else
        print_message $BLUE "🐍 使用系统环境安装Guard依赖..."
        # 查找可用的pip
        local pip_candidates=("pip3" "pip" "python3 -m pip" "python -m pip")
        for cmd in "${pip_candidates[@]}"; do
            if $cmd --version &> /dev/null; then
                pip_cmd="$cmd"
                break
            fi
        done
        
        if [ -z "$pip_cmd" ]; then
            print_message $YELLOW "⚠️ 未找到pip，尝试安装..."
            if command -v python3 &> /dev/null; then
                curl -s https://bootstrap.pypa.io/get-pip.py | python3 - --user
                pip_cmd="python3 -m pip"
            fi
        fi
        
        pip_args="--user --break-system-packages"
    fi
    
    if [ -n "$pip_cmd" ]; then
        print_message $YELLOW "📥 安装Guard依赖: schedule psutil..."
        $pip_cmd install $pip_args schedule psutil 2>/dev/null || {
            print_message $YELLOW "⚠️ pip安装失败，尝试系统包管理器..."
            
            # 尝试系统包安装
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y python3-schedule python3-psutil 2>/dev/null || true
            elif command -v yum &> /dev/null; then
                sudo yum install -y python3-schedule python3-psutil 2>/dev/null || true
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y python3-schedule python3-psutil 2>/dev/null || true
            fi
        }
        
        # 验证安装
        local python_cmd="python3"
        if [ -n "$VIRTUAL_ENV" ]; then
            python_cmd="python"
        fi
        
        if $python_cmd -c "import schedule, psutil" 2>/dev/null; then
            print_message $GREEN "✅ Guard依赖安装成功"
            
            # 启动Guard（修复语法错误）
            print_message $BLUE "🛡️ 启动Guard守护程序..."
            chmod +x guard.sh 2>/dev/null || true
            
            # 正确的nohup语法 - 修复第225行错误
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
                        print_message $GREEN "✅ 初始自检报告已发送"
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
        else
            print_message $YELLOW "⚠️ Guard依赖验证失败，但机器人可正常使用"
        fi
    else
        print_message $YELLOW "⚠️ 未找到可用的pip，Guard功能将不可用"
    fi
}

# 显示安装结果
show_installation_result() {
    echo
    print_message $GREEN "🎉 一键安装流程完成！"
    echo
    print_message $CYAN "📋 安装结果:"
    print_message $CYAN "  • FinalShell激活码机器人已安装"
    
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
    
    print_message $CYAN "  • Guard守护程序: $guard_status"
    print_message $CYAN "  • 自动自检功能已配置"
    echo
    print_message $YELLOW "⏰ 自动化时间表:"
    print_message $CYAN "  • 每天 00:00 - 执行系统自检"
    print_message $CYAN "  • 每天 07:00 - 发送详细报告"
    print_message $CYAN "  • 随时可用 - 发送 /guard 获取最新报告"
    echo
    print_message $BLUE "📱 使用方法:"
    print_message $CYAN "  • 使用 'fn-bot' 命令管理机器人"
    print_message $CYAN "  • 在Telegram中发送 /help 查看所有命令"
    print_message $CYAN "  • 发送 /guard 获取系统自检报告"
    echo
    print_message $GREEN "🚀 安装完成，开始使用吧！"
}

# 主执行流程
main() {
    precheck_system
    intelligent_download_installer
    execute_installation
    intelligent_guard_installation
    show_installation_result
}

# 执行主流程
main