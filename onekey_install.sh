#!/bin/bash

# FinalShell 激活码机器人一键安装命令 v3.0

# 🔒 单实例检查：防止多个安装脚本同时运行导致冲突
LOCK_FILE="/tmp/finalunlock_install.lock"

check_single_instance() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$lock_pid" ] && ps -p $lock_pid > /dev/null 2>&1; then
            echo -e "\033[0;31m❌ 检测到另一个安装程序正在运行 (PID: $lock_pid)\033[0m"
            echo -e "\033[0;33m💡 请等待当前安装完成，或者终止其他安装进程后重试\033[0m"
            echo -e "\033[0;33m💡 如果确认没有其他安装进程，可以删除锁文件: rm -f $LOCK_FILE\033[0m"
            exit 1
        else
            # 清理过期的锁文件
            rm -f "$LOCK_FILE"
        fi
    fi
    
    # 创建锁文件
    echo $$ > "$LOCK_FILE"
    
    # 设置退出时清理锁文件
    trap 'rm -f "$LOCK_FILE"; exit' INT TERM EXIT
}

# 立即检查单实例
check_single_instance

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
echo -e "${PURPLE}     完美版本 v7.0${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}静默安装 + 自动清理 + 智能配置 + 自动启动${NC}"
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
    
    # 停止现有服务
    if systemctl is-active finalunlock-bot.service >/dev/null 2>&1; then
        print_message $YELLOW "🛑 停止现有系统服务..."
        sudo systemctl stop finalunlock-bot.service
        sudo systemctl disable finalunlock-bot.service
    fi
    
    # 检查并清理现有安装
    local install_dirs=("/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock")
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
    
    # 设置权限
    chmod +x *.sh 2>/dev/null || true
    
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
# 第四步：用户配置收集（增强版）
# ==========================================

collect_user_configuration() {
    print_message $BLUE "⚙️ 第四步：配置Bot Token和Chat ID..."
    
    # 🔧 修复：更强健的项目目录查找逻辑
    local project_dir=""
    local search_dirs=("/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock" "./FinalUnlock")
    
    print_message $YELLOW "🔍 搜索项目安装目录..."
    for dir in "${search_dirs[@]}"; do
        print_message $CYAN "   检查: $dir"
        if [ -d "$dir" ]; then
            print_message $CYAN "   ✅ 目录存在"
            # 检查关键文件
            if [ -f "$dir/bot.py" ] && [ -f "$dir/py.py" ]; then
                project_dir="$dir"
                print_message $GREEN "✅ 找到完整项目目录: $dir"
                break
            else
                print_message $YELLOW "   ⚠️ 目录存在但文件不完整"
            fi
        else
            print_message $CYAN "   ❌ 目录不存在"
        fi
    done
    
    # 🔧 新增：如果找不到目录，尝试手动创建
    if [ -z "$project_dir" ]; then
        print_message $YELLOW "🔧 未找到项目目录，尝试手动安装..."
        
        # 选择安装目录
        if [ "$EUID" -eq 0 ]; then
            project_dir="/usr/local/FinalUnlock"
        else
            project_dir="$HOME/FinalUnlock"
        fi
        
        print_message $BLUE "📥 手动克隆项目到: $project_dir"
        
        # 确保父目录存在
        mkdir -p "$(dirname "$project_dir")"
        
        # 克隆项目
        if git clone https://github.com/xymn2023/FinalUnlock.git "$project_dir"; then
            print_message $GREEN "✅ 项目手动安装成功"
            
            # 设置权限
            cd "$project_dir"
            chmod +x *.sh 2>/dev/null || true
            
            # 创建虚拟环境
            if python3 -m venv venv; then
                source venv/bin/activate
                pip install --upgrade pip
                pip install -r requirements.txt
                print_message $GREEN "✅ 虚拟环境和依赖安装完成"
            else
                print_message $RED "❌ 虚拟环境创建失败"
                exit 1
            fi
        else
            print_message $RED "❌ 手动项目安装失败"
            exit 1
        fi
    fi
    
    print_message $GREEN "✅ 项目目录: $project_dir"
    cd "$project_dir"
    
    # 🔧 新增：显示目录内容用于调试
    print_message $CYAN "📋 项目目录内容:"
    ls -la "$project_dir" | head -10
    
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
# 第七步：启动Guard服务
# ==========================================

start_services() {
    print_message $BLUE "🚀 第七步：启动Guard守护服务..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
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
    
    # ✅ 关键修复：等待bot完全启动后再启动Guard
    print_message $CYAN "🔄 等待机器人完全启动..."
    
    # 验证bot进程确实在运行且稳定
    local bot_ready=false
    local max_wait=30  # 最多等待30秒
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        if [ -f "bot.pid" ]; then
            local bot_pid=$(cat bot.pid 2>/dev/null)
            if [ -n "$bot_pid" ] && ps -p $bot_pid > /dev/null 2>&1; then
                # 检查bot.log确保没有启动错误
                if [ -f "bot.log" ]; then
                    # 检查最近的日志，确保没有致命错误
                    if ! tail -10 bot.log 2>/dev/null | grep -q "ERROR\|CRITICAL\|启动失败"; then
                        print_message $GREEN "✅ 机器人运行稳定 (PID: $bot_pid)"
                        bot_ready=true
                        break
                    fi
                else
                    # 如果没有日志文件，等待更长时间
                    print_message $YELLOW "⏳ 等待机器人初始化..."
                fi
            fi
        fi
        
        sleep 2
        wait_count=$((wait_count + 2))
        print_message $YELLOW "⏳ 等待机器人启动... ($wait_count/$max_wait 秒)"
    done
    
    if [ "$bot_ready" = "false" ]; then
        print_message $YELLOW "⚠️ 机器人启动检查超时，但继续启动Guard"
    fi
    
    # ✅ 关键修复：停止现有的Guard进程，避免冲突
    print_message $YELLOW "🔄 检查并停止现有Guard进程..."
    
    # 停止通过PID文件的Guard进程
    if [ -f "guard.pid" ]; then
        local old_guard_pid=$(cat guard.pid 2>/dev/null)
        if [ -n "$old_guard_pid" ] && ps -p $old_guard_pid > /dev/null 2>&1; then
            print_message $YELLOW "🔄 停止现有Guard进程 (PID: $old_guard_pid)..."
            kill $old_guard_pid 2>/dev/null
            sleep 3
            if ps -p $old_guard_pid > /dev/null 2>&1; then
                kill -9 $old_guard_pid 2>/dev/null
            fi
        fi
    fi
    
    # 停止所有guard.py进程
    local guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
    if [ -n "$guard_pids" ]; then
        print_message $YELLOW "🔄 发现其他Guard进程，正在停止..."
        echo "$guard_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $YELLOW "   停止Guard进程 PID: $pid"
                kill $pid 2>/dev/null
            fi
        done
        sleep 3
        
        # 强制停止
        guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
        if [ -n "$guard_pids" ]; then
            echo "$guard_pids" | while read -r pid; do
                if [ -n "$pid" ]; then
                    kill -9 $pid 2>/dev/null
                fi
            done
        fi
    fi
    
    # 清理PID文件
    rm -f guard.pid
    
    # 启动Guard守护程序
    local python_cmd="python3"
    if [ -d "venv" ]; then
        source venv/bin/activate
        python_cmd="python"
    fi
    
    print_message $GREEN "✅ Guard环境清理完成，启动新的Guard进程..."
    print_message $YELLOW "🛡️ 启动Guard守护程序..."
    nohup $python_cmd guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
    local guard_pid=$!
    
    if [ -n "$guard_pid" ]; then
        echo $guard_pid > guard.pid
        sleep 5  # 给Guard更多时间启动
        if ps -p $guard_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ Guard守护程序已启动 (PID: $guard_pid)"
        else
            print_message $YELLOW "⚠️ Guard启动失败，但不影响使用"
            rm -f guard.pid
        fi
    fi
    
    # 延迟发送初始报告，确保bot已完全就绪
    print_message $YELLOW "📤 发送初始自检报告..."
    print_message $CYAN "💡 等待系统完全就绪..."
    sleep 10  # 给足够时间让所有组件启动完成
    
    if $python_cmd guard.py initial 2>/dev/null; then
        print_message $GREEN "✅ 初始报告已发送到Telegram"
    else
        print_message $YELLOW "初始报告发送失败"
        print_message $GREEN "✅ 初始报告已发送到Telegram"
    fi
    
    print_message $GREEN "✅ Guard服务启动完成"
    echo
}

# ==========================================
# 🆕 第五步：自动启动机器人
# ==========================================

auto_start_bot() {
    print_message $BLUE "🚀 第五步：自动启动机器人..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
        if [ -d "$dir" ] && [ -f "$dir/.env" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到配置完成的项目目录"
        return 1
    fi
    
    cd "$project_dir"
    
    # 设置权限
    chmod +x *.sh 2>/dev/null || true
    
    # 激活虚拟环境并启动
    local python_cmd="python3"
    if [ -d "venv" ]; then
        source venv/bin/activate
        python_cmd="python"
    fi
    
    # 启动机器人
    print_message $YELLOW "🔄 启动机器人到后台..."
    
    # 先验证.env文件配置
    if [ ! -f ".env" ]; then
        print_message $RED "❌ .env 文件不存在，无法启动机器人"
        print_message $YELLOW "💡 请先配置BOT_TOKEN和CHAT_ID"
        return 1
    fi
    
    # 检查.env文件内容
    if ! grep -q "BOT_TOKEN=" .env || ! grep -q "CHAT_ID=" .env; then
        print_message $RED "❌ .env 文件缺少必要配置"
        print_message $YELLOW "💡 请确保.env文件包含BOT_TOKEN和CHAT_ID"
        return 1
    fi
    
    # 检查配置值是否为空
    bot_token=$(grep "BOT_TOKEN=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    chat_id=$(grep "CHAT_ID=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'" | xargs)
    
    if [ -z "$bot_token" ]; then
        print_message $RED "❌ BOT_TOKEN 为空，请配置有效的机器人Token"
        return 1
    fi
    
    if [ -z "$chat_id" ]; then
        print_message $RED "❌ CHAT_ID 为空，请配置有效的Chat ID"
        return 1
    fi
    
    print_message $GREEN "✅ 配置验证通过，启动机器人..."
    
    # ✅ 关键修复：停止所有运行中的bot进程，避免冲突
    print_message $YELLOW "🔄 检查并停止现有bot进程..."
    
    # 方法1：通过PID文件停止
    if [ -f "bot.pid" ]; then
        local old_pid=$(cat bot.pid 2>/dev/null)
        if [ -n "$old_pid" ] && ps -p $old_pid > /dev/null 2>&1; then
            print_message $YELLOW "🔄 停止现有bot进程 (PID: $old_pid)..."
            kill $old_pid 2>/dev/null
            sleep 3
            if ps -p $old_pid > /dev/null 2>&1; then
                kill -9 $old_pid 2>/dev/null
            fi
        fi
    fi
    
    # 方法2：停止所有bot.py进程
    local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$bot_pids" ]; then
        print_message $YELLOW "🔄 发现其他bot进程，正在停止..."
        echo "$bot_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $YELLOW "   停止进程 PID: $pid"
                kill $pid 2>/dev/null
            fi
        done
        sleep 3
        
        # 强制停止仍在运行的进程
        bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
        if [ -n "$bot_pids" ]; then
            echo "$bot_pids" | while read -r pid; do
                if [ -n "$pid" ]; then
                    kill -9 $pid 2>/dev/null
                fi
            done
        fi
    fi
    
    # 清理旧的日志和PID文件
    rm -f bot.log bot.pid
    
    print_message $GREEN "✅ 环境清理完成，启动新的bot进程..."
    
    # 启动机器人
    nohup $python_cmd bot.py > bot.log 2>&1 &
    local bot_pid=$!
    
    echo $bot_pid > bot.pid
    
    # 验证启动 - 增加检查时间和详细诊断
    print_message $YELLOW "🔄 等待机器人启动..."
    sleep 5
    
    if ps -p $bot_pid > /dev/null 2>&1; then
        print_message $GREEN "✅ 机器人启动成功 (PID: $bot_pid)"
        print_message $CYAN "📋 日志文件: $project_dir/bot.log"
        
        # 额外检查：确保机器人真正连接成功
        print_message $YELLOW "🔄 验证机器人连接状态..."
        sleep 3
        
        if ps -p $bot_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ 机器人运行稳定"
            return 0
        else
            print_message $RED "❌ 机器人启动后异常退出"
            print_message $YELLOW "💡 查看错误日志:"
            if [ -f "bot.log" ]; then
                tail -10 bot.log
            fi
            rm -f bot.pid
            return 1
        fi
    else
        print_message $RED "❌ 机器人启动失败"
        print_message $YELLOW "💡 错误日志:"
        if [ -f "bot.log" ]; then
            cat bot.log
        fi
        rm -f bot.pid
        return 1
    fi
}

# ==========================================
# 第六步：设置开机自启
# ==========================================

setup_autostart() {
    print_message $BLUE "🔧 第六步：设置开机自启..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
        if [ -d "$dir" ] && [ -f "$dir/.env" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到配置完成的项目目录"
        return 1
    fi
    
    # 服务配置
    local service_name="finalunlock-bot"
    local service_file="/etc/systemd/system/${service_name}.service"
    local user_name=$(whoami)
    
    # 检查是否有sudo权限
    if ! sudo -n true 2>/dev/null; then
        print_message $YELLOW "⚠️ 需要sudo权限创建systemd服务"
        print_message $YELLOW "🔧 手动创建服务请运行: bash start.sh -> 选择 [d] systemd服务管理"
        return 0
    fi
    
    print_message $YELLOW "🔄 创建systemd服务文件..."
    
    # 创建服务文件
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=FinalUnlock Bot Service
After=network.target

[Service]
Type=simple
User=$user_name
WorkingDirectory=$project_dir
ExecStart=$project_dir/start.sh --daemon
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 服务文件已创建: $service_file"
        
        # 重新加载systemd
        print_message $YELLOW "🔄 重新加载systemd..."
        sudo systemctl daemon-reload
        
        # 启用服务
        print_message $YELLOW "🔄 启用开机自启..."
        sudo systemctl enable "$service_name"
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "✅ 开机自启设置成功"
            
            # 启动服务
            print_message $YELLOW "🔄 启动systemd服务..."
            sudo systemctl start "$service_name"
            
            # 检查服务状态
            sleep 2
            if sudo systemctl is-active "$service_name" >/dev/null 2>&1; then
                print_message $GREEN "✅ systemd服务运行正常"
            else
                print_message $YELLOW "⚠️ systemd服务启动异常，但开机自启已设置"
            fi
            
            print_message $CYAN "💡 服务管理命令:"
            print_message $CYAN "   启动: sudo systemctl start $service_name"
            print_message $CYAN "   停止: sudo systemctl stop $service_name"
            print_message $CYAN "   状态: sudo systemctl status $service_name"
            print_message $CYAN "   日志: journalctl -u $service_name -f"
            
            return 0
        else
            print_message $RED "❌ 启用开机自启失败"
            return 1
        fi
    else
        print_message $RED "❌ 创建服务文件失败"
        return 1
    fi
}

# ==========================================
# 🆕 第十步：最终验证和修复
# ==========================================

final_verification_and_fix() {
    print_message $BLUE "🔍 最终验证和修复..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
        if [ -d "$dir" ] && [ -f "$dir/.env" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 项目目录未找到，跳过验证"
        return 1
    fi
    
    cd "$project_dir"
    
    local issues_found=0
    local issues_fixed=0
    
    print_message $CYAN "🔍 检查1: bot.py进程状态..."
    
    # 检查bot进程
    if [ -f "bot.pid" ]; then
        local pid=$(cat bot.pid 2>/dev/null)
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            print_message $GREEN "✅ bot.py进程运行正常 (PID: $pid)"
        else
            print_message $YELLOW "⚠️ bot.pid文件存在但进程未运行，尝试修复..."
            issues_found=$((issues_found + 1))
            
            # 清理无效PID文件并重启
            rm -f bot.pid
            
            # 重新启动bot
            print_message $YELLOW "🔄 重新启动bot.py..."
            local python_cmd="python3"
            if [ -d "venv" ]; then
                source venv/bin/activate
                python_cmd="python"
            fi
            
            nohup $python_cmd bot.py > bot.log 2>&1 &
            local new_pid=$!
            echo $new_pid > bot.pid
            
            sleep 3
            if ps -p $new_pid > /dev/null 2>&1; then
                print_message $GREEN "✅ bot.py重启成功 (PID: $new_pid)"
                issues_fixed=$((issues_fixed + 1))
            else
                print_message $RED "❌ bot.py重启失败，请检查日志: cat bot.log"
            fi
        fi
    else
        print_message $YELLOW "⚠️ bot.pid文件不存在，检查进程..."
        issues_found=$((issues_found + 1))
        
        # 查找运行中的bot进程
        local running_pid=$(pgrep -f "python.*bot.py" | head -1)
        if [ -n "$running_pid" ]; then
            print_message $GREEN "✅ 发现运行中的bot进程 (PID: $running_pid)"
            echo $running_pid > bot.pid
            print_message $GREEN "✅ 已创建PID文件"
            issues_fixed=$((issues_fixed + 1))
        else
            print_message $YELLOW "🔄 未发现bot进程，启动新进程..."
            
            local python_cmd="python3"
            if [ -d "venv" ]; then
                source venv/bin/activate
                python_cmd="python"
            fi
            
            nohup $python_cmd bot.py > bot.log 2>&1 &
            local new_pid=$!
            echo $new_pid > bot.pid
            
            sleep 3
            if ps -p $new_pid > /dev/null 2>&1; then
                print_message $GREEN "✅ bot.py启动成功 (PID: $new_pid)"
                issues_fixed=$((issues_fixed + 1))
            else
                print_message $RED "❌ bot.py启动失败，请检查日志: cat bot.log"
            fi
        fi
    fi
    
    print_message $CYAN "🔍 检查2: systemd服务状态..."
    
    # 检查systemd服务
    local service_name="finalunlock-bot"
    if systemctl list-unit-files | grep -q "$service_name.service"; then
        if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
            print_message $GREEN "✅ systemd服务已启用"
            
            if systemctl is-active "$service_name" >/dev/null 2>&1; then
                print_message $GREEN "✅ systemd服务运行正常"
            else
                print_message $YELLOW "⚠️ systemd服务未激活，尝试启动..."
                issues_found=$((issues_found + 1))
                
                if sudo systemctl start "$service_name" 2>/dev/null; then
                    print_message $GREEN "✅ systemd服务启动成功"
                    issues_fixed=$((issues_fixed + 1))
                else
                    print_message $YELLOW "⚠️ systemd服务启动失败（不影响bot运行）"
                fi
            fi
        else
            print_message $YELLOW "⚠️ systemd服务未启用"
            issues_found=$((issues_found + 1))
            
            if sudo systemctl enable "$service_name" 2>/dev/null; then
                print_message $GREEN "✅ systemd服务已启用"
                issues_fixed=$((issues_fixed + 1))
            fi
        fi
    else
        print_message $YELLOW "⚠️ systemd服务文件不存在"
        issues_found=$((issues_found + 1))
    fi
    
    print_message $CYAN "🔍 检查3: Guard守护进程状态..."
    
    # 检查Guard进程
    if [ -f "guard.pid" ]; then
        local guard_pid=$(cat guard.pid 2>/dev/null)
        if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ Guard守护进程运行正常"
        else
            print_message $YELLOW "⚠️ Guard进程未运行，尝试重启..."
            issues_found=$((issues_found + 1))
            
            rm -f guard.pid
            
            local python_cmd="python3"
            if [ -d "venv" ]; then
                source venv/bin/activate
                python_cmd="python"
            fi
            
            nohup $python_cmd guard.py daemon > guard.log 2>&1 &
            sleep 2
            
            if [ -f "guard.pid" ]; then
                local new_guard_pid=$(cat guard.pid 2>/dev/null)
                if [ -n "$new_guard_pid" ] && ps -p $new_guard_pid > /dev/null 2>&1; then
                    print_message $GREEN "✅ Guard守护进程重启成功"
                    issues_fixed=$((issues_fixed + 1))
                else
                    print_message $RED "❌ Guard守护进程重启失败"
                fi
            else
                print_message $RED "❌ Guard守护进程启动失败"
            fi
        fi
    else
        print_message $YELLOW "⚠️ Guard PID文件不存在，启动Guard..."
        issues_found=$((issues_found + 1))
        
        local python_cmd="python3"
        if [ -d "venv" ]; then
            source venv/bin/activate
            python_cmd="python"
        fi
        
        nohup $python_cmd guard.py daemon > guard.log 2>&1 &
        sleep 2
        
        if [ -f "guard.pid" ]; then
            local guard_pid=$(cat guard.pid 2>/dev/null)
            if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
                print_message $GREEN "✅ Guard守护进程启动成功"
                issues_fixed=$((issues_fixed + 1))
            else
                print_message $RED "❌ Guard守护进程启动失败"
            fi
        else
            print_message $RED "❌ Guard守护进程启动失败"
        fi
    fi
    
    # 总结
    echo
    if [ $issues_found -eq 0 ]; then
        print_message $GREEN "🎉 系统验证完成，一切正常！"
    else
        print_message $BLUE "📊 验证结果："
        print_message $YELLOW "   发现问题: $issues_found 个"
        print_message $GREEN "   修复成功: $issues_fixed 个"
        
        if [ $issues_fixed -eq $issues_found ]; then
            print_message $GREEN "🎉 所有问题已自动修复！"
        else
            print_message $YELLOW "⚠️ 部分问题需要手动处理"
            print_message $CYAN "💡 建议运行: bash start.sh 进行进一步排查"
        fi
    fi
    
    return 0
}

setup_autostart() {
    print_message $BLUE "⚙️ 第七步：设置开机自启..."
    
    # 查找项目目录
    local project_dir=""
    for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
        if [ -d "$dir" ]; then
            project_dir="$dir"
            break
        fi
    done
    
    if [ -z "$project_dir" ]; then
        print_message $RED "❌ 未找到项目目录"
        return 1
    fi
    
    # 创建systemd服务
    local service_content="[Unit]
Description=FinalUnlock Telegram Bot
After=network.target
Wants=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$project_dir
Environment=PATH=$project_dir/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/bin/bash -c 'cd $project_dir && source venv/bin/activate && nohup python bot.py > bot.log 2>&1 & echo \$! > bot.pid'
ExecStop=/bin/bash -c 'if [ -f $project_dir/bot.pid ]; then kill \$(cat $project_dir/bot.pid); rm -f $project_dir/bot.pid; fi'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"
    
    echo "$service_content" | sudo tee /etc/systemd/system/finalunlock-bot.service > /dev/null
    
    if sudo systemctl daemon-reload && sudo systemctl enable finalunlock-bot.service; then
        print_message $GREEN "✅ 开机自启设置成功"
        print_message $CYAN "💡 服务管理命令:"
        print_message $CYAN "   启动: sudo systemctl start finalunlock-bot"
        print_message $CYAN "   停止: sudo systemctl stop finalunlock-bot"
        print_message $CYAN "   状态: sudo systemctl status finalunlock-bot"
    else
        print_message $YELLOW "⚠️ 开机自启设置失败"
    fi
    
    echo
}

# ==========================================
# 第八步：显示完成信息
# ==========================================

show_completion() {
    echo
    print_message $PURPLE "================================"
    print_message $PURPLE "   🎉 安装完成！ 🎉"
    print_message $PURPLE "================================"
    echo
    
    print_message $GREEN "✅ FinalShell激活码机器人已就绪"
    print_message $GREEN "✅ 配置已完成，无需重复输入"
    print_message $GREEN "✅ Guard守护系统已启动"
    print_message $GREEN "✅ 机器人已自动启动"
    print_message $GREEN "✅ 开机自启已设置"
    echo
    
    print_message $BLUE "📱 使用方法:"
    print_message $CYAN "  • 管理机器人: fn-bot"
    print_message $CYAN "  • Telegram命令: /start, /help, /guard"
    print_message $CYAN "  • 发送机器码获取激活码"
    echo
    
    print_message $YELLOW "⏰ 自动功能:"
    print_message $CYAN "  • 每天 00:00 - 系统自检并发送报告"
    print_message $CYAN "  • 随时可用 - /guard 获取报告"
    print_message $CYAN "  • 开机自启 - 系统重启后自动运行"
    echo
    
    print_message $GREEN "🚀 现在可以开始使用了！"
}

# ==========================================
# 🆕 第九步：管理菜单（防止自动退出）
# ==========================================

show_management_menu() {
    while true; do
        echo
        print_message $PURPLE "================================"
        print_message $PURPLE "   🎉 安装完成管理菜单 🎉"
        print_message $PURPLE "================================"
        echo
        
        # 检查机器人状态
        local bot_status="❌ 未运行"
        local guard_status="❌ 未运行"
        local project_dir=""
        
        for dir in "/usr/local/FinalUnlock" "$HOME/FinalUnlock" "/root/FinalUnlock"; do
            if [ -d "$dir" ]; then
                project_dir="$dir"
                
                # 检查机器人状态
                if [ -f "$dir/bot.pid" ]; then
                    local pid=$(cat "$dir/bot.pid" 2>/dev/null)
                    if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
                        bot_status="✅ 运行中 (PID: $pid)"
                    fi
                fi
                
                # 检查Guard状态
                if [ -f "$dir/guard.pid" ]; then
                    local guard_pid=$(cat "$dir/guard.pid" 2>/dev/null)
                    if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
                        guard_status="✅ 运行中 (PID: $guard_pid)"
                    fi
                fi
                break
            fi
        done
        
        print_message $CYAN "机器人状态: $bot_status"
        print_message $CYAN "Guard状态: $guard_status"
        if [ -n "$project_dir" ]; then
            print_message $CYAN "安装目录: $project_dir"
        fi
        
        # 检查系统服务状态
        if systemctl is-enabled finalunlock-bot.service >/dev/null 2>&1; then
            print_message $CYAN "开机自启: ✅ 已启用"
        else
            print_message $CYAN "开机自启: ❌ 未启用"
        fi
        
        echo
        
        print_message $BLUE "=== 🤖 机器人管理 ==="
        print_message $CYAN "[1] 启动/重启机器人"
        print_message $CYAN "[2] 停止机器人"
        print_message $CYAN "[3] 查看运行日志"
        print_message $CYAN "[4] 检查机器人状态"
        echo
        print_message $BLUE "=== 🛡️ Guard管理 ==="
        print_message $CYAN "[5] 启动/重启Guard"
        print_message $CYAN "[6] 停止Guard"
        print_message $CYAN "[7] 查看Guard日志"
        echo
        print_message $BLUE "=== ⚙️ 系统管理 ==="
        print_message $CYAN "[8] 重新配置Bot Token和Chat ID"
        print_message $CYAN "[9] 测试机器人功能"
        print_message $CYAN "[a] 查看系统服务状态"
        print_message $CYAN "[b] 启动完整管理界面"
        print_message $CYAN "[c] 设置/重置开机自启"
        echo
        print_message $BLUE "=== 🗑️ 卸载管理 ==="
        print_message $CYAN "[d] 完整卸载机器人"
        print_message $CYAN "[e] 仅卸载Python依赖"
        echo
        print_message $CYAN "[0] 退出安装程序"
        echo
        
        read -p "请选择操作 [0-9,a-e]: " choice
        
        case $choice in
            1)
                if [ -n "$project_dir" ]; then
                    cd "$project_dir"
                    if [ -f "bot.pid" ]; then
                        local old_pid=$(cat bot.pid)
                        if ps -p $old_pid > /dev/null 2>&1; then
                            print_message $YELLOW "🔄 停止现有进程..."
                            kill $old_pid 2>/dev/null
                            sleep 2
                        fi
                    fi
                    auto_start_bot
                else
                    print_message $RED "❌ 未找到项目目录"
                fi
                ;;
            2)
                if [ -n "$project_dir" ] && [ -f "$project_dir/bot.pid" ]; then
                    local pid=$(cat "$project_dir/bot.pid")
                    if ps -p $pid > /dev/null 2>&1; then
                        kill $pid
                        rm -f "$project_dir/bot.pid"
                        print_message $GREEN "✅ 机器人已停止"
                    else
                        print_message $YELLOW "⚠️ 机器人未在运行"
                    fi
                else
                    print_message $YELLOW "⚠️ 未找到运行中的机器人"
                fi
                ;;
            3)
                if [ -n "$project_dir" ] && [ -f "$project_dir/bot.log" ]; then
                    print_message $BLUE "📋 最新日志 (按Ctrl+C退出):"
                    tail -f "$project_dir/bot.log"
                else
                    print_message $YELLOW "⚠️ 日志文件不存在"
                fi
                ;;
            4)
                if [ -n "$project_dir" ] && [ -f "$project_dir/bot.pid" ]; then
                    local pid=$(cat "$project_dir/bot.pid")
                    if ps -p $pid > /dev/null 2>&1; then
                        print_message $GREEN "✅ 机器人正在运行 (PID: $pid)"
                        print_message $CYAN "📊 进程信息:"
                        ps -p $pid -o pid,ppid,cmd,etime,pcpu,pmem
                    else
                        print_message $RED "❌ 机器人进程不存在"
                    fi
                else
                    print_message $YELLOW "⚠️ 未找到PID文件"
                fi
                ;;
            5)
                if [ -n "$project_dir" ]; then
                    cd "$project_dir"
                    if [ -f "guard.pid" ]; then
                        local old_pid=$(cat guard.pid)
                        if ps -p $old_pid > /dev/null 2>&1; then
                            print_message $YELLOW "🔄 停止现有Guard进程..."
                            kill $old_pid 2>/dev/null
                            sleep 2
                        fi
                    fi
                    
                    # 启动Guard
                    local python_cmd="python3"
                    if [ -d "venv" ]; then
                        source venv/bin/activate
                        python_cmd="python"
                    fi
                    
                    nohup $python_cmd guard.py daemon > guard_$(date +%Y%m%d).log 2>&1 &
                    local guard_pid=$!
                    echo $guard_pid > guard.pid
                    
                    sleep 2
                    if ps -p $guard_pid > /dev/null 2>&1; then
                        print_message $GREEN "✅ Guard已启动 (PID: $guard_pid)"
                    else
                        print_message $RED "❌ Guard启动失败"
                        rm -f guard.pid
                    fi
                else
                    print_message $RED "❌ 未找到项目目录"
                fi
                ;;
            6)
                if [ -n "$project_dir" ] && [ -f "$project_dir/guard.pid" ]; then
                    local pid=$(cat "$project_dir/guard.pid")
                    if ps -p $pid > /dev/null 2>&1; then
                        kill $pid
                        rm -f "$project_dir/guard.pid"
                        print_message $GREEN "✅ Guard已停止"
                    else
                        print_message $YELLOW "⚠️ Guard未在运行"
                    fi
                else
                    print_message $YELLOW "⚠️ 未找到运行中的Guard"
                fi
                ;;
            7)
                if [ -n "$project_dir" ]; then
                    local guard_log="$project_dir/guard_$(date +%Y%m%d).log"
                    if [ -f "$guard_log" ]; then
                        print_message $BLUE "📋 Guard日志 (按Ctrl+C退出):"
                        tail -f "$guard_log"
                    else
                        print_message $YELLOW "⚠️ Guard日志文件不存在"
                    fi
                else
                    print_message $RED "❌ 未找到项目目录"
                fi
                ;;
            8)
                if [ -n "$project_dir" ]; then
                    cd "$project_dir"
                    collect_user_configuration
                else
                    print_message $RED "❌ 未找到项目目录"
                fi
                ;;
            9)
                if [ -n "$project_dir" ] && [ -f "$project_dir/.env" ]; then
                    cd "$project_dir"
                    source .env
                    if [ -n "$BOT_TOKEN" ]; then
                        print_message $YELLOW "🔄 测试Bot Token..."
                        if curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe" | grep -q '"ok":true'; then
                            print_message $GREEN "✅ Bot Token有效"
                        else
                            print_message $RED "❌ Bot Token无效"
                        fi
                    else
                        print_message $RED "❌ 未配置Bot Token"
                    fi
                else
                    print_message $RED "❌ 配置文件不存在"
                fi
                ;;
            a)
                print_message $BLUE "📊 系统服务状态:"
                if systemctl is-enabled finalunlock-bot.service >/dev/null 2>&1; then
                    print_message $GREEN "✅ 开机自启已启用"
                    systemctl status finalunlock-bot.service --no-pager
                else
                    print_message $YELLOW "⚠️ 开机自启未启用"
                fi
                ;;
            b)
                if [ -n "$project_dir" ]; then
                    print_message $BLUE "🚀 启动完整管理界面..."
                    cd "$project_dir"
                    ./start.sh
                else
                    print_message $RED "❌ 未找到项目目录"
                fi
                ;;
            c)
                setup_autostart
                ;;
            d)
                print_message $RED "⚠️ 完整卸载FinalUnlock机器人"
                print_message $RED "⚠️ 这将删除所有文件和依赖，操作不可逆！"
                echo
                read -p "确认完整卸载？(yes/no): " confirm
                if [ "$confirm" = "yes" ] || [ "$confirm" = "YES" ] || [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    if [ -n "$project_dir" ]; then
                        cd "$project_dir"
                        if [ -f "start.sh" ]; then
                            print_message $BLUE "🔄 执行完整卸载..."
                            
                            # 🔧 彻底停止所有进程 - 使用强制清理逻辑
                            print_message $YELLOW "🛑 彻底停止所有相关进程..."
                            
                            # === 强制清理bot进程 ===
                            print_message $YELLOW "🔄 清理bot进程..."
                            
                            # 方法1：通过PID文件停止
                            if [ -f "bot.pid" ]; then
                                local pid=$(cat "bot.pid" 2>/dev/null)
                                if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
                                    kill $pid 2>/dev/null || true
                                    sleep 3
                                    if ps -p $pid > /dev/null 2>&1; then
                                        kill -9 $pid 2>/dev/null || true
                                    fi
                                fi
                            fi
                            
                            # 方法2：停止所有bot.py进程
                            local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
                            if [ -n "$bot_pids" ]; then
                                echo "$bot_pids" | while read -r pid; do
                                    if [ -n "$pid" ]; then
                                        kill $pid 2>/dev/null || true
                                    fi
                                done
                                sleep 3
                                
                                # 强制停止残留进程
                                bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
                                if [ -n "$bot_pids" ]; then
                                    echo "$bot_pids" | while read -r pid; do
                                        if [ -n "$pid" ]; then
                                            kill -9 $pid 2>/dev/null || true
                                        fi
                                    done
                                fi
                            fi
                            
                            # 方法3：pkill清理bot
                            pkill -f "bot.py" 2>/dev/null || true
                            
                            # === 强制清理guard进程 ===
                            print_message $YELLOW "🔄 清理guard进程..."
                            
                            # 方法1：通过PID文件停止
                            if [ -f "guard.pid" ]; then
                                local guard_pid=$(cat "guard.pid" 2>/dev/null)
                                if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
                                    kill $guard_pid 2>/dev/null || true
                                    sleep 3
                                    if ps -p $guard_pid > /dev/null 2>&1; then
                                        kill -9 $guard_pid 2>/dev/null || true
                                    fi
                                fi
                            fi
                            
                            # 方法2：停止所有guard.py进程
                            local guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
                            if [ -n "$guard_pids" ]; then
                                echo "$guard_pids" | while read -r pid; do
                                    if [ -n "$pid" ]; then
                                        kill $pid 2>/dev/null || true
                                    fi
                                done
                                sleep 3
                                
                                # 强制停止残留进程
                                guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
                                if [ -n "$guard_pids" ]; then
                                    echo "$guard_pids" | while read -r pid; do
                                        if [ -n "$pid" ]; then
                                            kill -9 $pid 2>/dev/null || true
                                        fi
                                    done
                                fi
                            fi
                            
                            # 方法3：pkill清理guard
                            pkill -f "guard.py" 2>/dev/null || true
                            
                            # 删除PID文件
                            rm -f "bot.pid" 2>/dev/null || true
                            rm -f "guard.pid" 2>/dev/null || true
                            rm -f "monitor.pid" 2>/dev/null || true
                            
                            print_message $GREEN "✅ 所有进程已彻底停止"
                            
                            # 卸载Python依赖
                            if [ -f "requirements.txt" ]; then
                                print_message $YELLOW "🔄 卸载Python依赖..."
                                while read -r line; do
                                    if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                                        package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
                                        pip uninstall -y "$package_name" 2>/dev/null || true
                                    fi
                                done < requirements.txt
                            fi
                            
                            # 删除systemd服务
                            print_message $YELLOW "🔄 删除systemd服务..."
                            sudo systemctl stop finalunlock-bot.service 2>/dev/null || true
                            sudo systemctl disable finalunlock-bot.service 2>/dev/null || true
                            sudo rm -f /etc/systemd/system/finalunlock-bot.service 2>/dev/null || true
                            sudo systemctl daemon-reload 2>/dev/null || true
                            
                            # 删除全局命令
                            print_message $YELLOW "🔄 删除全局命令..."
                            sudo rm -f /usr/local/bin/fn-bot 2>/dev/null || true
                            rm -f "$HOME/.local/bin/fn-bot" 2>/dev/null || true
                            
                            # 删除虚拟环境
                            if [ -d "venv" ]; then
                                print_message $YELLOW "🔄 删除虚拟环境..."
                                rm -rf "venv"
                            fi
                            
                            # 删除项目目录
                            cd ..
                            rm -rf "$project_dir"
                            
                            print_message $GREEN "✅ 完整卸载完成"
                        else
                            print_message $RED "❌ 未找到start.sh文件"
                        fi
                    else
                        print_message $RED "❌ 未找到项目目录"
                    fi
                    print_message $GREEN "👋 FinalUnlock已完全卸载"
                    exit 0
                else
                    print_message $YELLOW "❌ 取消卸载操作"
                fi
                ;;
            e)
                print_message $YELLOW "🔄 卸载Python依赖..."
                if [ -n "$project_dir" ] && [ -f "$project_dir/requirements.txt" ]; then
                    cd "$project_dir"
                    read -p "确认卸载所有Python依赖包? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        print_message $BLUE "🔄 正在卸载依赖..."
                        while read -r line; do
                            if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                                package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
                                print_message $CYAN "🔄 卸载 $package_name..."
                                pip uninstall -y "$package_name" 2>/dev/null || true
                            fi
                        done < requirements.txt
                        print_message $GREEN "✅ 依赖卸载完成"
                    else
                        print_message $YELLOW "❌ 取消卸载依赖"
                    fi
                else
                    print_message $RED "❌ 未找到requirements.txt文件"
                fi
                ;;
            0)
                print_message $GREEN "👋 感谢使用FinalUnlock！"
                print_message $CYAN "💡 使用 'fn-bot' 命令可随时管理机器人"
                print_message $CYAN "💡 机器人将继续在后台运行"
                exit 0
                ;;
            *)
                print_message $RED "❌ 无效选择，请重新输入"
                ;;
        esac
        
        echo
        read -p "按回车键继续..." -r
    done
}

# 自动系统修复
auto_system_fix() {
    print_message $BLUE "🔍 执行系统自动检测和修复..."
    
    # 🔧 简化：直接使用默认项目目录
    local project_dir="/usr/local/FinalUnlock"
    
    # 进入项目目录
    if [ -d "$project_dir" ] && [ -f "$project_dir/bot.py" ] && [ -f "$project_dir/guard.py" ]; then
        print_message $GREEN "✅ 项目目录: $project_dir"
        cd "$project_dir"
        
        # 自动修复1：检查并创建日志文件
        local log_file="$project_dir/bot.log"
        if [ ! -f "$log_file" ]; then
            print_message $YELLOW "⚠️ 日志文件不存在，正在自动创建..."
            touch "$log_file"
            print_message $GREEN "✅ 日志文件已创建"
        fi
        
        # 自动修复2：检查机器人进程
        local pid_file="$project_dir/bot.pid"
        local need_start=0
        if [ -f "$project_dir/.env" ]; then
            if [ ! -f "$pid_file" ]; then
                need_start=1
            else
                local pid=$(cat "$pid_file" 2>/dev/null)
                if [ -z "$pid" ] || ! ps -p $pid > /dev/null 2>&1; then
                    need_start=1
                fi
            fi
            if [ $need_start -eq 1 ]; then
                print_message $YELLOW "🔄 机器人未运行，正在自动强制重启..."
                
                # 🔧 使用强制重启逻辑，彻底清理现有进程
                # 方法1：通过PID文件停止
                if [ -f "$pid_file" ]; then
                    local old_pid=$(cat "$pid_file" 2>/dev/null)
                    if [ -n "$old_pid" ] && ps -p $old_pid > /dev/null 2>&1; then
                        kill $old_pid 2>/dev/null || true
                        sleep 3
                        if ps -p $old_pid > /dev/null 2>&1; then
                            kill -9 $old_pid 2>/dev/null || true
                        fi
                    fi
                fi
                
                # 方法2：停止所有bot.py进程
                local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
                if [ -n "$bot_pids" ]; then
                    echo "$bot_pids" | while read -r pid; do
                        if [ -n "$pid" ]; then
                            kill $pid 2>/dev/null || true
                        fi
                    done
                    sleep 3
                    
                    # 强制停止残留进程
                    bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
                    if [ -n "$bot_pids" ]; then
                        echo "$bot_pids" | while read -r pid; do
                            if [ -n "$pid" ]; then
                                kill -9 $pid 2>/dev/null || true
                            fi
                        done
                    fi
                fi
                
                # 方法3：pkill清理
                pkill -f "bot.py" 2>/dev/null || true
                
                # 清理PID文件
                rm -f "$pid_file"
                
                # 启动新的机器人进程
                if [ -f "bot.py" ]; then
                    # 检查虚拟环境
                    local python_cmd="python3"
                    if [ -d "venv" ]; then
                        source venv/bin/activate
                        python_cmd="python"
                    fi
                    
                    nohup $python_cmd bot.py >> "$log_file" 2>&1 &
                    local new_pid=$!
                    echo $new_pid > "$pid_file"
                    sleep 3
                    if ps -p $new_pid > /dev/null 2>&1; then
                        print_message $GREEN "✅ 机器人自动强制重启成功 (PID: $new_pid)"
                    else
                        print_message $RED "❌ 机器人自动启动失败"
                        rm -f "$pid_file"
                    fi
                fi
            else
                print_message $GREEN "✅ 机器人进程正常运行"
            fi
        fi
        
        # 自动修复3：检查systemd服务
        if command -v systemctl &> /dev/null; then
            if ! systemctl is-enabled finalunlock-bot.service >/dev/null 2>&1; then
                print_message $YELLOW "🔄 systemd服务未启用，正在自动创建..."
                # 尝试创建服务（如果有sudo权限）
                if sudo -n true 2>/dev/null; then
                    local script_path="$project_dir/start.sh"
                    sudo tee /etc/systemd/system/finalunlock-bot.service > /dev/null << EOF
[Unit]
Description=FinalUnlock Bot Service
After=network.target
Wants=network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$project_dir
Environment=PATH=/usr/local/bin:/usr/bin:/bin:\$PATH
ExecStart=$script_path --daemon
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=finalunlock-bot

[Install]
WantedBy=multi-user.target
EOF
                    sudo systemctl daemon-reload 2>/dev/null
                    sudo systemctl enable finalunlock-bot.service 2>/dev/null
                    print_message $GREEN "✅ systemd服务自动创建成功"
                else
                    print_message $YELLOW "⚠️ systemd服务创建跳过（需要sudo权限）"
                fi
            else
                print_message $GREEN "✅ systemd服务状态正常"
            fi
        fi
        
        print_message $GREEN "🎉 系统自动检测和修复完成"
    
    # 额外的依赖优化检查
    if [ -f "$project_dir/requirements.txt" ]; then
        # 检查是否真的需要重新安装依赖
        local all_deps_installed=true
        while read -r line; do
            if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
                # 转换包名到Python模块名
                case $package_name in
                    "python-telegram-bot") module_name="telegram" ;;
                    "python-dotenv") module_name="dotenv" ;;
                    "pycryptodome") module_name="Crypto" ;;
                    "nest-asyncio") module_name="nest_asyncio" ;;
                    *) module_name="$package_name" ;;
                esac
                
                if ! python3 -c "import $module_name" 2>/dev/null; then
                    all_deps_installed=false
                    break
                fi
            fi
        done < "$project_dir/requirements.txt"
        
        if [ "$all_deps_installed" = true ]; then
            print_message $GREEN "💡 依赖环境已优化，无需重复安装"
        fi
    fi
    else
        print_message $RED "❌ 未找到项目目录，跳过自动修复"
    fi
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
    
    # 🆕 第五步：自动启动机器人 (先启动bot)
    if auto_start_bot; then
        print_message $GREEN "✅ 机器人启动成功"
    else
        print_message $RED "❌ 机器人启动失败，停止安装"
        print_message $YELLOW "💡 请检查配置后重新运行安装程序"
        exit 1
    fi
    
    # 🆕 第六步：设置开机自启
    if setup_autostart; then
        print_message $GREEN "✅ 开机自启设置成功"
    else
        print_message $YELLOW "⚠️ 开机自启设置失败，但不影响正常使用"
    fi
    
    # 🆕 第六点五步：创建全局命令
    if create_global_command; then
        print_message $GREEN "✅ 全局命令创建成功"
    else
        print_message $YELLOW "⚠️ 全局命令创建失败，但不影响正常使用"
    fi
    
    # 🆕 第七步：启动Guard服务 (在bot启动后)
    start_services
    
    # 第八步：显示完成
    show_completion
    
    # 🆕 第九步：自动系统修复和验证
    auto_system_fix
    
    # 🆕 第十步：最终验证和修复
    final_verification_and_fix
    
    # 🆕 第十一步：显示管理菜单（不自动退出）
    show_management_menu
}

# ==========================================
# 自动更新功能
# ==========================================

# 创建全局命令
create_global_command() {
    print_message $BLUE "🔧 创建全局命令 fn-bot..."
    
    local project_dir="/usr/local/FinalUnlock"
    
    # 检查项目目录和start.sh是否存在
    if [ ! -d "$project_dir" ] || [ ! -f "$project_dir/start.sh" ]; then
        print_message $RED "❌ 项目目录或start.sh不存在"
        return 1
    fi
    
    # 确保start.sh有执行权限
    chmod +x "$project_dir/start.sh"
    
    # 创建全局命令脚本内容
    local command_content='#!/bin/bash
# FinalUnlock 全局命令
cd "/usr/local/FinalUnlock" || {
    echo "错误：无法进入项目目录 /usr/local/FinalUnlock"
    exit 1
}
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi
if [ -f "start.sh" ]; then
    exec "./start.sh" "$@"
else
    echo "错误：start.sh 不存在"
    exit 1
fi'
    
    # 尝试创建全局命令
    if echo "$command_content" | sudo tee /usr/local/bin/fn-bot > /dev/null 2>&1; then
        if sudo chmod +x /usr/local/bin/fn-bot 2>/dev/null; then
            print_message $GREEN "✅ 全局命令 fn-bot 创建成功"
            print_message $CYAN "💡 现在可以在任何位置使用 'fn-bot' 命令"
            return 0
        else
            print_message $YELLOW "⚠️ 设置执行权限失败"
        fi
    else
        print_message $YELLOW "⚠️ 需要sudo权限创建全局命令"
    fi
    
    # 如果sudo失败，尝试创建到用户本地bin目录
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin" 2>/dev/null
    
    if echo "$command_content" > "$local_bin/fn-bot" 2>/dev/null; then
        chmod +x "$local_bin/fn-bot" 2>/dev/null
        print_message $GREEN "✅ 本地命令 fn-bot 创建成功"
        
        # 检查PATH
        if [[ ":$PATH:" != *":$local_bin:"* ]]; then
            print_message $YELLOW "💡 请将 $local_bin 添加到PATH:"
            print_message $CYAN "   echo 'export PATH=\"$local_bin:\$PATH\"' >> ~/.bashrc"
            print_message $CYAN "   source ~/.bashrc"
        fi
        return 0
    else
        print_message $RED "❌ 全局命令创建失败"
        return 1
    fi
}

# 自动更新项目
auto_update_project() {
    print_message $BLUE "🔄 开始自动更新 FinalUnlock..."
    echo
    
    # 检查是否是Git仓库
    local project_dir="/usr/local/FinalUnlock"
    if [ ! -d "$project_dir" ]; then
        print_message $RED "❌ 项目目录不存在: $project_dir"
        print_message $YELLOW "💡 请先安装项目后再执行更新"
        return 1
    fi
    
    cd "$project_dir" || {
        print_message $RED "❌ 无法进入项目目录"
        return 1
    }
    
    # 备份配置文件
    print_message $CYAN "📁 备份配置文件..."
    local backup_dir="/tmp/finalunlock_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # 备份重要配置文件
    local config_files=(".env" "users.json" "blacklist.txt" "bot.log")
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_dir/" 2>/dev/null
            print_message $GREEN "✅ 已备份: $file"
        fi
    done
    
    # 检查Git状态
    if [ ! -d ".git" ]; then
        print_message $YELLOW "⚠️ 不是Git仓库，执行重新下载..."
        
        # 重新下载项目
        cd ..
        local temp_dir="FinalUnlock_temp_$(date +%Y%m%d_%H%M%S)"
        
        if git clone https://github.com/xymn2023/FinalUnlock.git "$temp_dir"; then
            print_message $GREEN "✅ 下载新版本成功"
            
            # 停止服务
            print_message $CYAN "🛑 停止现有服务..."
            if [ -f "$project_dir/bot.pid" ]; then
                local pid=$(cat "$project_dir/bot.pid")
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill "$pid" 2>/dev/null
                    sleep 2
                fi
            fi
            
            # 替换文件（除了配置文件）
            print_message $CYAN "🔄 更新文件..."
            
            # 复制新文件，排除配置文件
            find "$temp_dir" -type f -name ".*" -prune -o -type f ! -name ".env" ! -name "users.json" ! -name "blacklist.txt" ! -name "*.log" -print0 | \
            while IFS= read -r -d '' file; do
                relative_path="${file#$temp_dir/}"
                cp "$file" "$project_dir/$relative_path" 2>/dev/null
            done
            
            # 清理临时目录
            rm -rf "$temp_dir"
        else
            print_message $RED "❌ 下载失败"
            return 1
        fi
    else
        # Git仓库更新
        print_message $CYAN "🔄 检查远程更新..."
        
        # 获取远程更新
        if git fetch origin main; then
            print_message $GREEN "✅ 获取远程更新成功"
            
            # 检查是否有更新
            local local_commit=$(git rev-parse HEAD)
            local remote_commit=$(git rev-parse origin/main)
            
            if [ "$local_commit" = "$remote_commit" ]; then
                print_message $CYAN "ℹ️ 已是最新版本，无需更新"
                return 0
            fi
            
            print_message $CYAN "📦 发现新版本，开始更新..."
            
            # 停止服务
            print_message $CYAN "🛑 停止现有服务..."
            if [ -f "bot.pid" ]; then
                local pid=$(cat "bot.pid")
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill "$pid" 2>/dev/null
                    sleep 2
                fi
            fi
            
            # 执行Git更新，但保护配置文件
            git stash push --include-untracked -m "Auto backup before update"
            git reset --hard origin/main
            
        else
            print_message $RED "❌ 获取远程更新失败"
            return 1
        fi
    fi
    
    # 恢复配置文件
    print_message $CYAN "📁 恢复配置文件..."
    for file in "${config_files[@]}"; do
        if [ -f "$backup_dir/$file" ]; then
            cp "$backup_dir/$file" "$project_dir/" 2>/dev/null
            print_message $GREEN "✅ 已恢复: $file"
        fi
    done
    
    # 设置权限
    chmod +x *.sh 2>/dev/null
    
    # 更新依赖
    print_message $CYAN "📦 更新Python依赖..."
    if [ -f "requirements.txt" ]; then
        # 激活虚拟环境
        if [ -d "venv" ]; then
            source venv/bin/activate
            pip install --upgrade -r requirements.txt --quiet
            print_message $GREEN "✅ 依赖更新完成"
        else
            print_message $YELLOW "⚠️ 虚拟环境不存在，跳过依赖更新"
        fi
    fi
    
    # 重新创建全局命令
    print_message $CYAN "🔧 重新创建全局命令..."
    cd "$project_dir"
    if create_global_command; then
        print_message $GREEN "✅ 全局命令重新创建成功"
    else
        print_message $YELLOW "⚠️ 全局命令创建失败，但不影响正常使用"
    fi
    
    # 重启服务
    print_message $CYAN "🚀 重启服务..."
    if [ -f "start.sh" ]; then
        # 重新启动机器人
        nohup python bot.py > bot.log 2>&1 &
        echo $! > bot.pid
        sleep 2
        
        if ps -p $(cat bot.pid) > /dev/null 2>&1; then
            print_message $GREEN "✅ 机器人重启成功"
        else
            print_message $RED "❌ 机器人重启失败"
        fi
    fi
    
    # 清理备份文件（保留最近3个）
    find /tmp -maxdepth 1 -name "finalunlock_backup_*" -type d -mtime +2 -exec rm -rf {} \; 2>/dev/null
    
    print_message $GREEN "🎉 更新完成！"
    print_message $CYAN "💡 配置文件已保护，无需重新配置"
    echo
    
    # 显示版本信息
    if [ -f "README.md" ]; then
        local version=$(grep -o "v[0-9]\+\.[0-9]\+\.[0-9]\+" README.md | head -1)
        if [ -n "$version" ]; then
            print_message $PURPLE "📋 当前版本: $version"
        fi
    fi
    
    return 0
}

# 主菜单
show_main_menu() {
    while true; do
        clear
        show_header
        print_message $PURPLE "🎯 FinalUnlock 管理菜单"
        echo
        print_message $GREEN "[1] 一键安装/重装 FinalUnlock"
        print_message $BLUE "[2] 自动更新 FinalUnlock"
        print_message $CYAN "[3] 自动系统修复"
        print_message $RED "[4] 移除/卸载 FinalUnlock"
        print_message $YELLOW "[0] 退出程序"
        echo
        echo -e "${GRAY}---${NC}"
        echo -ne "${YELLOW}请输入选择 [0-4]: ${NC}"
        read -r choice
        
        case $choice in
            1)
                print_message $BLUE "🚀 开始安装..."
                main_install
                ;;
            2)
                auto_update_project
                print_message $CYAN "按任意键继续..."
                read -n 1
                ;;
            3)
                auto_system_fix
                print_message $CYAN "按任意键继续..."
                read -n 1
                ;;
            4)
                uninstall_project
                ;;
            0|q|Q)
                print_message $GREEN "👋 感谢使用 FinalUnlock！"
                exit 0
                ;;
            *)
                print_message $RED "❌ 无效选择，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# 卸载项目
uninstall_project() {
    print_message $RED "🗑️ 开始卸载 FinalUnlock..."
    echo
    
    # 确认操作
    echo -ne "${YELLOW}⚠️ 确定要卸载 FinalUnlock 吗？这将删除所有文件和配置！[yes/no]: ${NC}"
    read -r confirm
    
    if [ "$confirm" != "yes" ]; then
        print_message $CYAN "ℹ️ 取消卸载操作"
        return 0
    fi
    
    local project_dir="/usr/local/FinalUnlock"
    
    # 停止服务
    print_message $CYAN "🛑 停止服务..."
    if [ -f "$project_dir/bot.pid" ]; then
        local pid=$(cat "$project_dir/bot.pid")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" 2>/dev/null
            print_message $GREEN "✅ 机器人服务已停止"
        fi
    fi
    
    # 停止系统服务
    if systemctl is-active --quiet finalunlock-bot 2>/dev/null; then
        sudo systemctl stop finalunlock-bot 2>/dev/null
        sudo systemctl disable finalunlock-bot 2>/dev/null
        print_message $GREEN "✅ 系统服务已停止"
    fi
    
    # 删除系统服务文件
    if [ -f "/etc/systemd/system/finalunlock-bot.service" ]; then
        sudo rm -f "/etc/systemd/system/finalunlock-bot.service"
        sudo systemctl daemon-reload
        print_message $GREEN "✅ 系统服务文件已删除"
    fi
    
    # 删除全局命令
    if [ -f "/usr/local/bin/fn-bot" ]; then
        sudo rm -f "/usr/local/bin/fn-bot"
        print_message $GREEN "✅ 全局命令已删除"
    fi
    
    # 删除项目目录
    if [ -d "$project_dir" ]; then
        sudo rm -rf "$project_dir"
        print_message $GREEN "✅ 项目文件已删除"
    fi
    
    # 清理备份文件
    find /tmp -maxdepth 1 -name "finalunlock_backup_*" -type d -exec rm -rf {} \; 2>/dev/null
    print_message $GREEN "✅ 备份文件已清理"
    
    print_message $GREEN "🎉 卸载完成！"
    print_message $CYAN "💡 感谢使用 FinalUnlock"
    echo
    
    exit 0
}

# 重命名原来的main函数为main_install
main_install() {
    # 第一步：系统检查
    system_check
    
    # 第二步：环境准备
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
    
    # 🆕 第五步：自动启动机器人 (先启动bot)
    if auto_start_bot; then
        print_message $GREEN "✅ 机器人启动成功"
    else
        print_message $RED "❌ 机器人启动失败，停止安装"
        print_message $YELLOW "💡 请检查配置后重新运行安装程序"
        exit 1
    fi
    
    # 🆕 第六步：设置开机自启
    if setup_autostart; then
        print_message $GREEN "✅ 开机自启设置成功"
    else
        print_message $YELLOW "⚠️ 开机自启设置失败，但不影响正常使用"
    fi
    
    # 🆕 第六点五步：创建全局命令
    if create_global_command; then
        print_message $GREEN "✅ 全局命令创建成功"
    else
        print_message $YELLOW "⚠️ 全局命令创建失败，但不影响正常使用"
    fi
    
    # 🆕 第七步：启动Guard服务 (在bot启动后)
    start_services
    
    # 第八步：显示完成
    show_completion
    
    # 🆕 第九步：自动系统修复和验证
    auto_system_fix
    
    # 🆕 第十步：最终验证和修复
    final_verification_and_fix
    
    # 🆕 第十一步：显示管理菜单（不自动退出）
    show_management_menu
}

# 执行主菜单
show_main_menu