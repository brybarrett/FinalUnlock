#!/bin/bash
# FinalUnlock 一键管理脚本

set -e

# 基本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="FinalUnlock"
INSTALL_DIR="/usr/local/$PROJECT_NAME"
SERVICE_NAME="finalunlock-bot"
PYTHON_CMD="python3"
PID_FILE="$INSTALL_DIR/bot.pid"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 消息函数
msg() { echo -e "${2:-$GREEN}$1$NC"; }
error() { msg "$1" "$RED"; }
warn() { msg "$1" "$YELLOW"; }
info() { msg "$1" "$BLUE"; }

# Ctrl+C处理函数
handle_ctrl_c() {
    echo ""
    warn "⚠️ Ctrl+C已被屏蔽！请按任意键返回主菜单或使用菜单选项 [0] 退出程序"
}

# 检查权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检测系统环境
detect_system() {
    info "检测系统环境..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "无法识别操作系统"
        exit 1
    fi
    
    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update -qq"
        PKG_INSTALL="apt install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y -q"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf update -y -q"
        PKG_INSTALL="dnf install -y"
    else
        error "不支持的包管理器"
        exit 1
    fi
    
    msg "✅ 系统检测完成: $OS"
}

# 检测并安装Python
check_install_python() {
    info "检查Python环境..."
    
    local need_install=false
    
    if command -v python3 &> /dev/null; then
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        msg "✅ Python已安装: $py_version"
        
        # 检查版本是否足够新 (>= 3.7)
        local major=$(echo $py_version | cut -d. -f1)
        local minor=$(echo $py_version | cut -d. -f2)
        if [[ $major -lt 3 ]] || [[ $major -eq 3 && $minor -lt 7 ]]; then
            warn "⚠️ Python版本过低，需要 >= 3.7"
            need_install=true
        fi
    else
        warn "❌ Python未安装"
        need_install=true
    fi
    
    # 检查pip
    if ! command -v pip3 &> /dev/null; then
        warn "❌ pip3未安装"
        need_install=true
    fi
    
    # 检查venv - 通过实际创建测试目录来检测
    local test_venv="/tmp/test_venv_$$"
    if ! python3 -m venv "$test_venv" &> /dev/null; then
        warn "❌ python3-venv未安装或不可用"
        need_install=true
        rm -rf "$test_venv" 2>/dev/null || true
    else
        rm -rf "$test_venv" 2>/dev/null || true
    fi
    
    # 如果需要安装，执行安装
    if [[ "$need_install" == "true" ]]; then
        install_python
        
        # 安装后再次检查venv
        if ! python3 -m venv --help &> /dev/null 2>&1; then
            error "❌ venv安装失败，尝试修复..."
            fix_python_venv
        fi
    fi
}

# 修复Python venv问题
fix_python_venv() {
    info "修复Python venv环境..."
    
    # 获取Python版本
    local py_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d. -f1,2)
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # Ubuntu/Debian需要安装对应版本的venv包
        info "安装python${py_version}-venv..."
        $PKG_UPDATE
        $PKG_INSTALL python${py_version}-venv python3-venv
        
        # 如果还是失败，尝试通用包
        if ! python3 -m venv --help &> /dev/null 2>&1; then
            warn "尝试安装通用venv包..."
            $PKG_INSTALL python3-virtualenv
            # 使用virtualenv替代venv
            if command -v virtualenv &> /dev/null; then
                msg "✅ 将使用virtualenv替代venv"
                export USE_VIRTUALENV=1
            fi
        fi
    elif [[ "$PKG_MANAGER" == "yum" ]] || [[ "$PKG_MANAGER" == "dnf" ]]; then
        # CentOS/RHEL/Fedora
        $PKG_INSTALL python3-virtualenv
        export USE_VIRTUALENV=1
    fi
    
    # 最终检查
    if ! python3 -m venv --help &> /dev/null 2>&1 && ! command -v virtualenv &> /dev/null; then
        error "❌ 无法安装Python虚拟环境工具"
        error "请手动运行: $PKG_INSTALL python3-venv python3-virtualenv"
        exit 1
    fi
    
    msg "✅ Python venv环境修复完成"
}

# 安装Python和相关工具
install_python() {
    info "安装Python环境..."
    
    $PKG_UPDATE
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # 获取Python版本号
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d. -f1,2)
        info "安装Python ${py_version}相关包..."
        
        # 安装基础包和版本特定的venv包
        $PKG_INSTALL python3 python3-pip python3-dev build-essential
        $PKG_INSTALL python3-venv python${py_version}-venv python3-virtualenv
        
    elif [[ "$PKG_MANAGER" == "yum" ]]; then
        $PKG_INSTALL python3 python3-pip python3-devel gcc python3-virtualenv
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        $PKG_INSTALL python3 python3-pip python3-devel gcc python3-virtualenv
    fi
    
    msg "✅ Python环境安装完成"
}

# 检测并安装系统工具
check_install_tools() {
    info "检查系统工具..."
    
    local missing_tools=()
    
    # 检查必需工具
    for tool in git curl systemctl; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "缺少工具: ${missing_tools[*]}"
        install_tools "${missing_tools[@]}"
    else
        msg "✅ 系统工具完整"
    fi
}

# 安装系统工具
install_tools() {
    local tools=("$@")
    info "安装系统工具: ${tools[*]}"
    
    $PKG_UPDATE
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        $PKG_INSTALL git curl systemd
    elif [[ "$PKG_MANAGER" == "yum" ]] || [[ "$PKG_MANAGER" == "dnf" ]]; then
        $PKG_INSTALL git curl systemd
    fi
    
    msg "✅ 系统工具安装完成"
}

# 安装系统依赖（整合函数）
install_deps() {
    info "🔍 开始环境检测和依赖安装..."
    
    detect_system
    check_install_python
    check_install_tools
    
    msg "✅ 所有依赖安装完成"
}

# 创建项目目录和虚拟环境
setup_project() {
    info "设置项目环境..."
    
    # 停止现有服务
    systemctl stop $SERVICE_NAME 2>/dev/null || true
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 复制文件
    if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
        cp -f "$SCRIPT_DIR"/{bot.py,py.py,requirements.txt,manage.sh} "$INSTALL_DIR/"
        cp -f "$SCRIPT_DIR/.env" "$INSTALL_DIR/" 2>/dev/null || true
    fi
    
    # 删除旧的虚拟环境
    rm -rf venv
    
    # 创建虚拟环境
    info "创建Python虚拟环境..."
    
    # 先尝试创建，如果失败则自动修复
    if ! $PYTHON_CMD -m venv venv 2>/dev/null; then
        warn "⚠️ venv创建失败，自动修复中..."
        
        # 获取Python版本并安装对应的venv包
        local py_version=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d. -f1,2)
        info "安装python${py_version}-venv..."
        
        $PKG_UPDATE
        $PKG_INSTALL python${py_version}-venv python3-venv python3-virtualenv
        
        # 再次尝试创建venv
        if ! $PYTHON_CMD -m venv venv 2>/dev/null; then
            info "venv仍然失败，使用virtualenv..."
            if command -v virtualenv &> /dev/null; then
                virtualenv -p python3 venv
            else
                error "❌ 无法创建虚拟环境"
                exit 1
            fi
        fi
    fi
    
    # 检查虚拟环境是否创建成功
    if [[ ! -f "venv/bin/activate" ]]; then
        error "❌ 虚拟环境创建失败"
        exit 1
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装Python依赖
    info "安装Python依赖包..."
    pip install --upgrade pip -q
    pip install -r requirements.txt -q
    
    msg "✅ 项目环境设置完成"
}

# 验证配置文件
validate_env() {
    local env_file="$1"
    local debug="${2:-false}"
    
    if [[ "$debug" == "true" ]]; then
        echo "调试: 检查文件 $env_file"
    fi
    
    if [[ ! -f "$env_file" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "调试: 文件不存在"
        fi
        return 1
    fi
    
    # 检查必需的配置项 - 支持前面有空格的格式
    local bot_token=$(grep -E "^[[:space:]]*BOT_TOKEN" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"'"'")
    local chat_id=$(grep -E "^[[:space:]]*CHAT_ID" "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"'"'")
    
    if [[ "$debug" == "true" ]]; then
        echo "调试: BOT_TOKEN=[${bot_token:0:20}...] CHAT_ID=[$chat_id]"
    fi
    
    if [[ -z "$bot_token" ]] || [[ "$bot_token" == "your_bot_token_here" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "调试: BOT_TOKEN无效"
        fi
        return 1
    fi
    
    if [[ -z "$chat_id" ]] || [[ "$chat_id" == "your_chat_id_here" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "调试: CHAT_ID无效"
        fi
        return 1
    fi
    
    return 0
}

# 自动检测和配置环境变量
config_env() {
    info "检查配置文件..."
    
    # 先检查安装目录
    if validate_env "$INSTALL_DIR/.env"; then
        msg "✅ 配置文件已存在且有效"
        return
    fi
    
    # 检查脚本目录
    if validate_env "$SCRIPT_DIR/.env"; then
        info "发现脚本目录中的配置文件，复制中..."
        cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/.env"
        msg "✅ 配置文件复制成功"
        return
    fi
    
    # 创建示例配置文件
    warn "未找到有效配置文件，创建模板..."
    cat > "$INSTALL_DIR/.env" << 'EOF'
BOT_TOKEN=your_bot_token_here
CHAT_ID=your_chat_id_here
EOF
    
    error "❌ 请先配置 .env 文件！"
    msg ""
    msg "📋 获取Bot Token步骤："
    msg "1. 在Telegram搜索 @BotFather"
    msg "2. 发送 /newbot 创建机器人"
    msg "3. 复制返回的Token"
    msg ""
    msg "📋 获取Chat ID步骤："
    msg "1. 在Telegram搜索 @userinfobot"
    msg "2. 发送任意消息"
    msg "3. 复制返回的数字ID"
    msg ""
    msg "📝 编辑配置文件："
    msg "nano $INSTALL_DIR/.env"
    msg ""
    msg "💡 配置完成后重新运行: fn-bot start"
    exit 1
}

# 创建systemd服务
create_service() {
    info "创建系统服务..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=FinalUnlock Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/bot.py
Restart=always
RestartSec=10
StandardOutput=append:$INSTALL_DIR/bot.log
StandardError=append:$INSTALL_DIR/bot.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    
    msg "✅ 系统服务创建完成"
}

# 创建全局命令
create_global_cmd() {
    cat > "/usr/local/bin/fn-bot" << 'EOF'
#!/bin/bash
exec /usr/local/FinalUnlock/manage.sh "$@"
EOF
    chmod +x /usr/local/bin/fn-bot
    msg "✅ 全局命令 fn-bot 创建完成"
}

# 启动服务
start_service() {
    info "启动机器人服务..."
    
    # 检查配置文件
    if ! validate_env "$INSTALL_DIR/.env"; then
        error "❌ 配置文件无效或不存在"
        msg "请先配置 $INSTALL_DIR/.env 文件"
        msg "然后运行: fn-bot start"
        return 1
    fi
    
    # 杀死可能存在的进程
    pkill -f "python.*bot.py" 2>/dev/null || true
    sleep 2
    
    systemctl start $SERVICE_NAME
    sleep 3
    
    if systemctl is-active $SERVICE_NAME &>/dev/null; then
        msg "✅ 机器人启动成功"
        show_status
    else
        error "❌ 机器人启动失败"
        msg ""
        msg "🔍 错误诊断："
        
        # 检查日志文件
        if [[ -f "$INSTALL_DIR/bot.log" ]]; then
            msg "📋 最新错误日志："
            tail -10 "$INSTALL_DIR/bot.log" | while IFS= read -r line; do
                echo "  $line"
            done
        fi
        
        msg ""
        msg "🛠️ 解决方案："
        msg "1. 查看完整日志: fn-bot logs"
        msg "2. 检查配置文件: cat /usr/local/FinalUnlock/.env"
        msg "3. 手动测试: cd /usr/local/FinalUnlock && source venv/bin/activate && python bot.py"
        msg "4. 查看系统日志: journalctl -u $SERVICE_NAME -f"
        msg ""
    fi
}

# 停止服务
stop_service() {
    info "停止机器人服务..."
    systemctl stop $SERVICE_NAME 2>/dev/null || true
    pkill -f "python.*bot.py" 2>/dev/null || true
    msg "✅ 机器人已停止"
}

# 重启服务
restart_service() {
    info "重启机器人服务..."
    stop_service
    sleep 2
    start_service
}

# 查看状态
show_status() {
    info "机器人状态："
    
    if systemctl is-active $SERVICE_NAME &>/dev/null; then
        msg "🤖 服务状态: ✅ 运行中"
        
        if [[ -f "$PID_FILE" ]]; then
            local pid=$(cat "$PID_FILE" 2>/dev/null)
            if ps -p "$pid" &>/dev/null; then
                msg "📊 进程状态: ✅ PID $pid"
                local uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
                msg "⏱️  运行时间: $uptime"
            fi
        fi
    else
        error "🤖 服务状态: ❌ 未运行"
    fi
    
    msg "📂 安装目录: $INSTALL_DIR"
    msg "📋 日志文件: $INSTALL_DIR/bot.log"
}

# 查看日志
show_logs() {
    clear
    if [[ -f "$INSTALL_DIR/bot.log" ]]; then
        info "📋 实时日志监控"
        msg "🔥 按回车键返回主菜单 (Ctrl+C已屏蔽) 🔥" "$YELLOW"
        echo "================================"
        
        # 确保Ctrl+C被屏蔽，即使在日志页面也不能退出
        trap 'handle_ctrl_c' SIGINT
        
        # 显示最后50行日志，然后等待用户输入
        tail -n 50 "$INSTALL_DIR/bot.log"
        echo ""
        echo "================================"
        
        # 使用简单的 read 命令等待回车键，这在所有环境都能正常工作
        read -p ">>> 按回车键返回主菜单 <<<"
        
        echo ""
        msg "📋 已返回主菜单"
        sleep 1
        
    else
        error "❌ 日志文件不存在: $INSTALL_DIR/bot.log"
        msg ""
        msg "💡 可能原因："
        msg "1. 机器人尚未启动过"
        msg "2. 日志文件路径有误"
        msg "3. 权限不足"
        echo ""
        read -p "按回车返回主菜单..."
    fi
}

# 卸载
uninstall() {
    warn "确认卸载 FinalUnlock？(输入 yes 确认)"
    read -r confirm
    
    if [[ "$confirm" == "yes" ]]; then
        info "卸载中..."
        
        systemctl stop $SERVICE_NAME 2>/dev/null || true
        systemctl disable $SERVICE_NAME 2>/dev/null || true
        rm -f "/etc/systemd/system/$SERVICE_NAME.service"
        rm -f "/usr/local/bin/fn-bot"
        systemctl daemon-reload
        
        pkill -f "python.*bot.py" 2>/dev/null || true
        
        rm -rf "$INSTALL_DIR"
        
        msg "✅ 卸载完成"
    else
        info "✋ 取消卸载，返回主菜单"
    fi
}

# 安装函数
install() {
    msg "🚀 开始安装 FinalUnlock..."
    
    check_root
    install_deps
    setup_project
    
    # 配置检查和处理
    local config_ready=false
    
    info "检查配置文件..."
    
    # 按优先级检查配置文件：优先从脚本所在目录（用户运行的目录）读取
    if validate_env "$SCRIPT_DIR/.env"; then
        info "发现脚本目录配置文件，复制中: $SCRIPT_DIR/.env"
        cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/.env"
        msg "✅ 配置文件已复制"
        config_ready=true
    elif validate_env "$INSTALL_DIR/.env"; then
        msg "✅ 目标目录配置文件有效: $INSTALL_DIR/.env"
        config_ready=true
    else
        # 创建示例配置
        warn "⚠️ 未找到有效的 .env 配置文件"
        msg "检查路径:"
        msg "  - $SCRIPT_DIR/.env (脚本目录)"
        msg "  - $INSTALL_DIR/.env (安装目录)"
        
        # 调试信息
        if [[ -f "$SCRIPT_DIR/.env" ]]; then
            warn "发现 $SCRIPT_DIR/.env 但验证失败，内容检查:"
            validate_env "$SCRIPT_DIR/.env" true
        elif [[ -f "$INSTALL_DIR/.env" ]]; then
            warn "发现 $INSTALL_DIR/.env 但验证失败，内容检查:"
            validate_env "$INSTALL_DIR/.env" true
        fi
        
        cat > "$INSTALL_DIR/.env" << 'EOF'
BOT_TOKEN=your_bot_token_here
CHAT_ID=your_chat_id_here
EOF
        msg "📝 已创建配置模板: $INSTALL_DIR/.env"
        config_ready=false
    fi
    
    create_service
    create_global_cmd
    
    msg "🎉 基础安装完成！"
    msg ""
    
    # 根据配置状态给出不同的提示
    if [[ "$config_ready" == "true" ]]; then
        info "配置文件有效，启动机器人..."
        if start_service; then
            msg "✅ 机器人启动成功！"
        else
            warn "⚠️ 启动失败，请检查配置或日志"
        fi
    else
        msg "📋 下一步：配置机器人"
        msg "1. 获取Bot Token: 在Telegram搜索 @BotFather -> /newbot"
        msg "2. 获取Chat ID: 在Telegram搜索 @userinfobot -> 发送消息"
        msg "3. 编辑配置文件: nano $INSTALL_DIR/.env"
        msg "4. 启动机器人: fn-bot start"
        msg ""
        msg "💡 或者直接运行 'fn-bot' 进入管理界面重新配置"
    fi
    
    msg ""
    msg "💡 管理命令: fn-bot [start|stop|status|logs]"
}

# 显示菜单
show_menu() {
    clear
    msg "================================" "$CYAN"
    msg "    FinalUnlock 管理面板" "$CYAN"
    msg "================================" "$CYAN"
    echo
    
    show_status
    echo
    
    msg "=== 🤖 机器人管理 ===" "$BLUE"
    msg "[1] 启动机器人" "$CYAN"
    msg "[2] 停止机器人" "$CYAN"
    msg "[3] 重启机器人" "$CYAN"
    msg "[4] 查看状态" "$CYAN"
    msg "[5] 查看日志" "$CYAN"
    echo
    msg "=== ⚙️ 系统管理 ===" "$BLUE"
    msg "[6] 重新配置" "$CYAN"
    msg "[7] 更新代码" "$CYAN"
    msg "[8] 卸载程序" "$CYAN"
    msg "[0] 退出程序" "$CYAN"
    echo
    msg "💡 提示：请使用菜单选项退出，Ctrl+C已屏蔽" "$YELLOW"
    echo
}

# 更新代码
update_code() {
    info "更新代码..."
    cd "$INSTALL_DIR" || { error "无法进入安装目录"; return 1; }
    
    # 备份配置和当前代码
    cp .env .env.backup 2>/dev/null || true
    cp bot.py bot.py.backup 2>/dev/null || true
    
    info "正在从GitHub下载最新代码..."
    msg "仓库地址: https://github.com/xymn2023/FinalUnlock"
    
    # 下载文件列表
    local files=("bot.py" "py.py" "requirements.txt" "manage.sh")
    local base_url="https://raw.githubusercontent.com/xymn2023/FinalUnlock/main"
    local download_success=true
    
    # 逐个下载文件
    for file in "${files[@]}"; do
        info "下载 $file..."
        if curl -f -s -L "$base_url/$file" > "${file}.new" 2>/dev/null; then
            if [[ -s "${file}.new" ]]; then
                # 检查文件内容是否有效（不是404页面）
                if ! grep -q "404" "${file}.new" && ! grep -q "Not Found" "${file}.new"; then
                    msg "✅ $file 下载成功"
                else
                    error "❌ $file 下载失败：文件不存在"
                    download_success=false
                fi
            else
                error "❌ $file 下载失败：文件为空"
                download_success=false
            fi
        else
            error "❌ $file 下载失败：网络错误"
            download_success=false
        fi
    done
    
    if [[ "$download_success" == true ]]; then
        # 替换文件
        info "替换文件..."
        for file in "${files[@]}"; do
            if [[ -f "${file}.new" ]]; then
                mv "${file}.new" "$file"
                [[ "$file" == "manage.sh" ]] && chmod +x "$file"
                msg "✅ $file 已更新"
            fi
        done
        
        # 恢复配置文件
        cp .env.backup .env 2>/dev/null || true
        
        # 更新Python依赖
        if [[ -f venv/bin/activate ]]; then
            info "更新Python依赖..."
            source venv/bin/activate
            pip install -r requirements.txt -q
            msg "✅ 依赖更新完成"
        elif [[ -f venv/Scripts/activate ]]; then
            info "更新Python依赖..."
            source venv/Scripts/activate
            pip install -r requirements.txt -q
            msg "✅ 依赖更新完成"
        else
            warn "⚠️ 虚拟环境不存在，跳过依赖更新"
        fi
        
        msg "✅ 代码更新成功！"
        
        # 重启服务
        restart_service
        
    else
        warn "⚠️ 更新失败，恢复备份文件"
        # 清理失败的下载文件
        rm -f *.new 2>/dev/null || true
        # 恢复备份
        cp bot.py.backup bot.py 2>/dev/null || true
        cp .env.backup .env 2>/dev/null || true
        error "❌ 代码更新失败，请检查网络连接或稍后重试"
    fi
    
    msg "✅ 更新完成"
}

# 重新配置
reconfig() {
    info "重新配置机器人..."
    
    # 交互式配置
    echo -n "请输入Bot Token: "
    read -r bot_token
    echo -n "请输入Chat ID: "
    read -r chat_id
    
    # 验证输入
    if [[ -z "$bot_token" ]] || [[ -z "$chat_id" ]]; then
        error "❌ Token和Chat ID不能为空"
        return 1
    fi
    
    # 保存配置
    cat > "$INSTALL_DIR/.env" << EOF
BOT_TOKEN=$bot_token
CHAT_ID=$chat_id
EOF
    
    msg "✅ 配置保存成功"
    
    # 重启服务
    if systemctl is-active $SERVICE_NAME &>/dev/null; then
        restart_service
    else
        msg "💡 运行 fn-bot start 启动机器人"
    fi
}

# 主逻辑
main() {
    case "${1:-}" in
        "install")
            install
            ;;
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "update")
            update_code
            ;;
        "uninstall")
            uninstall
            ;;
        "")
            # 交互模式
            if [[ ! -d "$INSTALL_DIR" ]]; then
                error "FinalUnlock 未安装，请先运行: $0 install"
                exit 1
            fi
            
            # 屏蔽Ctrl+C，只能通过菜单退出
            trap 'handle_ctrl_c' SIGINT
            
            while true; do
                show_menu
                echo -n "请选择操作 [0-8]: "
                read -r choice
                
                case $choice in
                    1) start_service; read -p "按回车继续..." ;;
                    2) stop_service; read -p "按回车继续..." ;;
                    3) restart_service; read -p "按回车继续..." ;;
                    4) show_status; read -p "按回车继续..." ;;
                    5) show_logs ;;
                    6) reconfig; read -p "按回车继续..." ;;
                    7) update_code; read -p "按回车继续..." ;;
                    8) 
                        uninstall
                        clear
                        msg "👋 FinalUnlock 已完全卸载！"
                        # 恢复Ctrl+C功能
                        trap - SIGINT
                        break 
                        ;;
                    0) 
                        clear
                        msg "👋 感谢使用 FinalUnlock 管理脚本！"
                        msg "💡 随时可以运行 'fn-bot' 重新进入管理界面"
                        # 恢复Ctrl+C功能
                        trap - SIGINT
                        break 
                        ;;
                    *) error "无效选择"; read -p "按回车继续..." ;;
                esac
            done
            ;;
        *)
            msg "FinalUnlock 一键管理脚本"
            msg ""
            msg "用法: $0 [命令]"
            msg ""
            msg "命令:"
            msg "  install   - 一键安装"
            msg "  start     - 启动服务"
            msg "  stop      - 停止服务"
            msg "  restart   - 重启服务"
            msg "  status    - 查看状态"
            msg "  logs      - 查看日志"
            msg "  update    - 更新代码"
            msg "  uninstall - 卸载程序"
            msg "  (无参数)  - 进入管理界面"
            ;;
    esac
}

main "$@"
