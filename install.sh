#!/bin/bash

# FinalShell 激活码机器人一键安装脚本 v3.1
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
echo -e "${PURPLE}     修复版本 v3.1${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}自动处理所有环境问题，无需手动干预${NC}"
echo

# 全局变量
INSTALL_DIR="/usr/local/FinalUnlock"
PYTHON_CMD="python3"
PIP_CMD="pip3"
USE_SYSTEM_PYTHON=false

# 智能系统检测和自动修复
intelligent_system_setup() {
    print_message $BLUE "🔍 智能系统环境检测和自动修复..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_message $RED "❌ 此脚本仅支持Linux系统"
        exit 1
    fi
    
    print_message $GREEN "✅ Linux系统检测通过"
    
    # 检测包管理器
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="apt-get update"
        PKG_INSTALL="apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
    else
        print_message $RED "❌ 无法识别包管理器"
        exit 1
    fi
    
    print_message $GREEN "✅ 包管理器检测: $PKG_MANAGER"
}

# 自动安装系统依赖
auto_install_system_dependencies() {
    print_message $BLUE "📦 检查系统依赖..."
    
    # 检查缺失的包
    local missing_packages=()
    local packages=("python3" "python3-pip" "python3-venv" "python3-dev" "git" "curl")
    
    for package in "${packages[@]}"; do
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            if ! dpkg -l | grep -q "^ii  $package "; then
                missing_packages+=("$package")
            fi
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有系统依赖已满足"
    else
        print_message $YELLOW "📥 安装缺失依赖: ${missing_packages[*]}"
        
        # 静默更新包列表
        sudo $PKG_UPDATE > /dev/null 2>&1
        
        # 静默安装缺失的包
        for package in "${missing_packages[@]}"; do
            sudo $PKG_INSTALL $package > /dev/null 2>&1
        done
        
        print_message $GREEN "✅ 依赖安装完成"
    fi
}

# 检查Python和虚拟环境支持
check_python_and_venv() {
    print_message $BLUE "🐍 检查Python和虚拟环境支持..."
    
    # 查找可用的Python版本
    local python_candidates=("python3.11" "python3.10" "python3.9" "python3.8" "python3.7" "python3")
    
    for cmd in "${python_candidates[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            local major=$(echo $version | cut -d'.' -f1)
            local minor=$(echo $version | cut -d'.' -f2)
            
            if [ "$major" -eq 3 ] && [ "$minor" -ge 7 ]; then
                PYTHON_CMD=$cmd
                print_message $GREEN "✅ 找到合适的Python: $cmd (版本 $version)"
                break
            fi
        fi
    done
    
    # 检查venv模块
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        print_message $YELLOW "⚠️ venv模块不可用，尝试安装..."
        sudo $PKG_INSTALL python3-venv > /dev/null 2>&1
        
        if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
            print_message $RED "❌ 无法安装venv模块"
            exit 1
        fi
    fi
    
    print_message $GREEN "✅ Python和venv检查通过"
}

# 创建虚拟环境
# 在create_virtual_environment函数中，项目下载成功后添加权限设置
create_virtual_environment() {
    print_message $BLUE "🐍 创建虚拟环境..."
    
    # 确定安装目录
    if [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null; then
        INSTALL_DIR="/usr/local/FinalUnlock"
        print_message $CYAN "💡 使用全局安装模式: $INSTALL_DIR"
    else
        INSTALL_DIR="$HOME/FinalUnlock"
        print_message $CYAN "💡 使用用户安装模式: $INSTALL_DIR"
    fi
    
    # 创建安装目录
    if [ -d "$INSTALL_DIR" ]; then
        print_message $YELLOW "🔄 删除现有安装目录..."
        rm -rf "$INSTALL_DIR"
    fi
    
    mkdir -p "$INSTALL_DIR"
    print_message $GREEN "✅ 创建安装目录: $INSTALL_DIR"
    
    # 下载项目
    print_message $BLUE "📥 下载项目..."
    if git clone https://github.com/xymn2023/FinalUnlock.git "$INSTALL_DIR"; then
        print_message $GREEN "✅ 项目下载成功"
    else
        print_message $RED "❌ 项目下载失败"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # 🔧 新增：设置shell脚本执行权限
    print_message $YELLOW "🔐 设置脚本执行权限..."
    chmod +x *.sh 2>/dev/null || true
    print_message $GREEN "✅ 脚本权限设置完成"
    
    # 创建虚拟环境
    local venv_dir="$INSTALL_DIR/venv"
    
    if [ -d "$venv_dir" ]; then
        rm -rf "$venv_dir"
    fi
    
    print_message $YELLOW "🔄 创建虚拟环境..."
    if $PYTHON_CMD -m venv "$venv_dir"; then
        print_message $GREEN "✅ 虚拟环境创建成功"
    else
        print_message $RED "❌ 虚拟环境创建失败"
        exit 1
    fi
    
    # 激活虚拟环境
    source "$venv_dir/bin/activate"
    if [ -n "$VIRTUAL_ENV" ]; then
        print_message $GREEN "✅ 虚拟环境已激活: $VIRTUAL_ENV"
        PYTHON_CMD="$venv_dir/bin/python"
        PIP_CMD="$venv_dir/bin/pip"
    else
        print_message $RED "❌ 虚拟环境激活失败"
        exit 1
    fi
}

# 在虚拟环境中安装依赖
install_dependencies_in_venv() {
    print_message $BLUE "📦 在虚拟环境中安装依赖..."
    
    # 升级pip
    print_message $YELLOW "🔄 升级pip..."
    $PIP_CMD install --upgrade pip
    
    print_message $GREEN "✅ 使用pip命令: $PIP_CMD"
    
    # 安装项目依赖
    print_message $YELLOW "📥 安装项目依赖..."
    
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        if $PIP_CMD install -r "$INSTALL_DIR/requirements.txt"; then
            print_message $GREEN "✅ 从requirements.txt安装成功"
        else
            print_message $RED "❌ 依赖安装失败"
            exit 1
        fi
    else
        print_message $RED "❌ requirements.txt文件不存在"
        exit 1
    fi
    
    # 验证依赖安装
    print_message $YELLOW "🔄 验证依赖安装..."
    local test_imports=("telegram" "dotenv" "Crypto" "schedule" "psutil")
    
    for module in "${test_imports[@]}"; do
        if ! $PYTHON_CMD -c "import $module" 2>/dev/null; then
            print_message $RED "❌ 模块 $module 导入失败"
            exit 1
        fi
    done
    
    print_message $GREEN "✅ 所有依赖验证通过"
}

# 创建激活脚本
create_activation_script() {
    print_message $BLUE "📝 创建激活脚本..."
    
    local activate_script="$INSTALL_DIR/activate_venv.sh"
    
    cat > "$activate_script" << 'EOF'
#!/bin/bash
# 激活FinalUnlock虚拟环境
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/venv/bin/activate"
echo "✅ FinalUnlock虚拟环境已激活"
EOF
    
    chmod +x "$activate_script"
    print_message $GREEN "✅ 激活脚本创建成功: $activate_script"
}

# 创建启动命令
create_startup_commands() {
    print_message $BLUE "🔧 创建启动命令..."
    
    # 创建全局命令
    local start_script="#!/bin/bash\ncd \"$INSTALL_DIR\"\nsource \"$INSTALL_DIR/venv/bin/activate\"\n\"$INSTALL_DIR/start.sh\" \"\$@\""
    
    if [ "$INSTALL_DIR" = "/usr/local/FinalUnlock" ]; then
        echo -e "$start_script" | sudo tee /usr/local/bin/fn-bot > /dev/null
        sudo chmod +x /usr/local/bin/fn-bot
        print_message $GREEN "✅ 全局命令创建成功: fn-bot"
    else
        local local_bin="$HOME/.local/bin"
        mkdir -p "$local_bin"
        echo -e "$start_script" > "$local_bin/fn-bot"
        chmod +x "$local_bin/fn-bot"
        print_message $GREEN "✅ 本地命令创建成功: fn-bot"
        
        # 检查PATH
        if [[ ":$PATH:" != *":$local_bin:"* ]]; then
            print_message $YELLOW "💡 请将 $local_bin 添加到PATH中"
            print_message $CYAN "echo 'export PATH=\"$local_bin:\$PATH\"' >> ~/.bashrc"
        fi
    fi
}

# 主安装流程
main_installation() {
    # 1. 智能系统检测
    intelligent_system_setup
    
    # 2. 安装系统依赖
    auto_install_system_dependencies
    
    # 3. 检查Python和虚拟环境支持
    check_python_and_venv
    
    # 4. 创建虚拟环境
    create_virtual_environment
    
    # 5. 在虚拟环境中安装依赖
    install_dependencies_in_venv
    
    # 6. 创建激活脚本
    create_activation_script
    
    # 7. 创建启动命令
    create_startup_commands
    
    print_message $GREEN "✅ 安装完成！"
    print_message $YELLOW "💡 项目已安装到: $INSTALL_DIR"
    print_message $CYAN "🚀 使用 'fn-bot' 命令管理机器人"
}

# 执行主安装流程
main_installation

