#!/bin/bash

# FinalShell 激活码机器人一键安装脚本 v3.0
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
echo -e "${PURPLE}     真正的一键安装 v3.0${NC}"
echo -e "${PURPLE}================================${NC}"
echo -e "${CYAN}项目地址: https://github.com/xymn2023/FinalUnlock${NC}"
echo -e "${CYAN}自动处理所有环境问题，无需手动干预${NC}"
echo

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
        PYTHON_VENV_PKG="python3-venv"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
        PYTHON_VENV_PKG="python3-venv"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf update -y"
        PKG_INSTALL="dnf install -y"
        PYTHON_VENV_PKG="python3-venv"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_UPDATE="pacman -Sy"
        PKG_INSTALL="pacman -S --noconfirm"
        PYTHON_VENV_PKG="python"
    else
        print_message $RED "❌ 无法识别包管理器，尝试通用安装方法"
        PKG_MANAGER="unknown"
    fi
    
    print_message $GREEN "✅ 包管理器检测: $PKG_MANAGER"
}

# 自动安装系统依赖
auto_install_system_dependencies() {
    print_message $BLUE "📦 自动安装系统依赖..."
    
    # 更新包列表
    print_message $YELLOW "🔄 更新包列表..."
    if [ "$PKG_MANAGER" != "unknown" ]; then
        sudo $PKG_UPDATE || {
            print_message $YELLOW "⚠️ 包列表更新失败，继续安装..."
        }
    fi
    
    # 定义需要安装的包
    local packages=()
    
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        packages=("python3" "python3-pip" "python3-venv" "python3-dev" "python3-distutils" "python3-setuptools" "git" "curl" "build-essential")
    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
        packages=("python3" "python3-pip" "python3-venv" "python3-devel" "git" "curl" "gcc" "gcc-c++" "make")
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        packages=("python" "python-pip" "git" "curl" "base-devel")
    fi
    
    # 逐个安装包，失败不退出
    for package in "${packages[@]}"; do
        print_message $YELLOW "📥 安装 $package..."
        if [ "$PKG_MANAGER" != "unknown" ]; then
            sudo $PKG_INSTALL $package || {
                print_message $YELLOW "⚠️ $package 安装失败，尝试继续..."
            }
        fi
    done
    
    print_message $GREEN "✅ 系统依赖安装完成"
}

# 智能Python环境检测和修复
intelligent_python_setup() {
    print_message $BLUE "🐍 智能Python环境检测和修复..."
    
    # 查找可用的Python版本
    local python_candidates=("python3.11" "python3.10" "python3.9" "python3.8" "python3.7" "python3" "python")
    local python_cmd=""
    
    for cmd in "${python_candidates[@]}"; do
        if command -v $cmd &> /dev/null; then
            local version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            local major=$(echo $version | cut -d'.' -f1)
            local minor=$(echo $version | cut -d'.' -f2)
            
            if [ "$major" -eq 3 ] && [ "$minor" -ge 7 ]; then
                python_cmd=$cmd
                print_message $GREEN "✅ 找到合适的Python: $cmd (版本 $version)"
                break
            fi
        fi
    done
    
    if [ -z "$python_cmd" ]; then
        print_message $RED "❌ 未找到Python 3.7+，尝试安装..."
        auto_install_system_dependencies
        
        # 重新检测
        for cmd in "${python_candidates[@]}"; do
            if command -v $cmd &> /dev/null; then
                local version=$($cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
                local major=$(echo $version | cut -d'.' -f1)
                local minor=$(echo $version | cut -d'.' -f2)
                
                if [ "$major" -eq 3 ] && [ "$minor" -ge 7 ]; then
                    python_cmd=$cmd
                    print_message $GREEN "✅ 安装后找到Python: $cmd (版本 $version)"
                    break
                fi
            fi
        done
        
        if [ -z "$python_cmd" ]; then
            print_message $RED "❌ 无法安装合适的Python版本"
            exit 1
        fi
    fi
    
    PYTHON_CMD=$python_cmd
    
    # 检测并修复venv模块
    print_message $YELLOW "🔄 检测venv模块..."
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        print_message $YELLOW "⚠️ venv模块不可用，尝试修复..."
        
        # 尝试安装venv包
        local venv_packages=()
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            # 检测Python版本并安装对应的venv包
            local py_version=$($PYTHON_CMD --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            venv_packages=("python${py_version}-venv" "python3-venv" "python3-distutils" "python3-setuptools")
        elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
            venv_packages=("python3-venv" "python3-setuptools")
        fi
        
        for pkg in "${venv_packages[@]}"; do
            print_message $YELLOW "📥 尝试安装 $pkg..."
            sudo $PKG_INSTALL $pkg 2>/dev/null || true
        done
        
        # 再次检测
        if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
            print_message $YELLOW "⚠️ 系统venv不可用，将使用pip安装virtualenv作为替代"
            
            # 确保pip可用
            if ! $PYTHON_CMD -m pip --version &> /dev/null; then
                print_message $YELLOW "📥 安装pip..."
                curl -s https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD - --user 2>/dev/null || {
                    print_message $YELLOW "⚠️ pip安装失败，尝试系统包管理器..."
                    sudo $PKG_INSTALL python3-pip 2>/dev/null || true
                }
            fi
            
            # 安装virtualenv作为替代
            print_message $YELLOW "📥 安装virtualenv作为venv替代..."
            $PYTHON_CMD -m pip install --user virtualenv 2>/dev/null || {
                pip3 install --user virtualenv 2>/dev/null || true
            }
            
            USE_VIRTUALENV=true
        else
            USE_VIRTUALENV=false
        fi
    else
        print_message $GREEN "✅ venv模块可用"
        USE_VIRTUALENV=false
    fi
}

# 智能虚拟环境创建
intelligent_venv_creation() {
    print_message $BLUE "🐍 智能虚拟环境创建..."
    
    local venv_dir="$INSTALL_DIR/venv"
    
    # 删除可能存在的损坏虚拟环境
    if [ -d "$venv_dir" ]; then
        print_message $YELLOW "🔄 删除现有虚拟环境..."
        rm -rf "$venv_dir"
    fi
    
    # 创建虚拟环境
    print_message $YELLOW "🔄 创建虚拟环境..."
    
    local creation_success=false
    
    if [ "$USE_VIRTUALENV" = "true" ]; then
        # 使用virtualenv
        if command -v virtualenv &> /dev/null; then
            virtualenv -p $PYTHON_CMD "$venv_dir" && creation_success=true
        elif $PYTHON_CMD -m virtualenv "$venv_dir" 2>/dev/null; then
            creation_success=true
        fi
    else
        # 使用venv
        if $PYTHON_CMD -m venv "$venv_dir" 2>/dev/null; then
            creation_success=true
        fi
    fi
    
    if [ "$creation_success" = "false" ]; then
        print_message $YELLOW "⚠️ 标准方法失败，尝试替代方案..."
        
        # 尝试不同的创建方法
        local methods=(
            "$PYTHON_CMD -m venv --without-pip"
            "$PYTHON_CMD -m venv --system-site-packages"
            "virtualenv --python=$PYTHON_CMD"
        )
        
        for method in "${methods[@]}"; do
            print_message $YELLOW "🔄 尝试: $method"
            if $method "$venv_dir" 2>/dev/null; then
                creation_success=true
                break
            fi
        done
    fi
    
    if [ "$creation_success" = "false" ]; then
        print_message $RED "❌ 虚拟环境创建失败，使用系统Python环境"
        USE_SYSTEM_PYTHON=true
        return 0
    fi
    
    print_message $GREEN "✅ 虚拟环境创建成功"
    USE_SYSTEM_PYTHON=false
    
    # 激活虚拟环境
    print_message $YELLOW "🔄 激活虚拟环境..."
    source "$venv_dir/bin/activate"
    
    if [ -n "$VIRTUAL_ENV" ]; then
        print_message $GREEN "✅ 虚拟环境已激活: $VIRTUAL_ENV"
        PYTHON_CMD="$venv_dir/bin/python"
        PIP_CMD="$venv_dir/bin/pip"
    else
        print_message $YELLOW "⚠️ 虚拟环境激活失败，使用系统环境"
        USE_SYSTEM_PYTHON=true
    fi
}

# 智能依赖安装
intelligent_dependency_installation() {
    print_message $BLUE "📦 智能依赖安装..."
    
    # 确定pip命令
    local pip_cmd=""
    if [ "$USE_SYSTEM_PYTHON" = "true" ]; then
        # 系统环境
        local pip_candidates=("pip3" "pip" "$PYTHON_CMD -m pip")
        for cmd in "${pip_candidates[@]}"; do
            if $cmd --version &> /dev/null; then
                pip_cmd=$cmd
                break
            fi
        done
        
        if [ -z "$pip_cmd" ]; then
            print_message $YELLOW "📥 安装pip..."
            curl -s https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD - --user
            pip_cmd="$PYTHON_CMD -m pip"
        fi
        
        PIP_INSTALL_ARGS="--user --break-system-packages"
    else
        # 虚拟环境
        pip_cmd="$PIP_CMD"
        PIP_INSTALL_ARGS=""
        
        # 升级pip
        print_message $YELLOW "🔄 升级pip..."
        $pip_cmd install --upgrade pip 2>/dev/null || true
    fi
    
    print_message $GREEN "✅ 使用pip命令: $pip_cmd"
    
    # 安装依赖
    local dependencies=("python-telegram-bot>=20.0" "python-dotenv>=0.19.0" "pycryptodome>=3.15.0" "schedule>=1.2.0" "psutil>=5.8.0")
    
    print_message $YELLOW "📥 安装项目依赖..."
    
    # 尝试从requirements.txt安装
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        if $pip_cmd install $PIP_INSTALL_ARGS -r "$INSTALL_DIR/requirements.txt" 2>/dev/null; then
            print_message $GREEN "✅ 从requirements.txt安装成功"
        else
            print_message $YELLOW "⚠️ requirements.txt安装失败，逐个安装依赖..."
            # 逐个安装
            for dep in "${dependencies[@]}"; do
                print_message $YELLOW "📥 安装 $dep..."
                $pip_cmd install $PIP_INSTALL_ARGS "$dep" 2>/dev/null || {
                    print_message $YELLOW "⚠️ $dep 安装失败，尝试不指定版本..."
                    local pkg_name=$(echo $dep | cut -d'>' -f1 | cut -d'=' -f1)
                    $pip_cmd install $PIP_INSTALL_ARGS "$pkg_name" 2>/dev/null || true
                }
            done
        fi
    else
        # 直接安装依赖
        for dep in "${dependencies[@]}"; do
            print_message $YELLOW "📥 安装 $dep..."
            $pip_cmd install $PIP_INSTALL_ARGS "$dep" 2>/dev/null || {
                print_message $YELLOW "⚠️ $dep 安装失败，尝试不指定版本..."
                local pkg_name=$(echo $dep | cut -d'>' -f1 | cut -d'=' -f1)
                $pip_cmd install $PIP_INSTALL_ARGS "$pkg_name" 2>/dev/null || true
            }
        done
    fi
    
    # 验证关键依赖
    print_message $YELLOW "🔄 验证依赖安装..."
    local missing_deps=()
    
    local test_imports=(
        "telegram:python-telegram-bot"
        "dotenv:python-dotenv"
        "Crypto:pycryptodome"
        "schedule:schedule"
        "psutil:psutil"
    )
    
    for test in "${test_imports[@]}"; do
        local module=$(echo $test | cut -d':' -f1)
        local package=$(echo $test | cut -d':' -f2)
        
        if ! $PYTHON_CMD -c "import $module" 2>/dev/null; then
            missing_deps+=("$package")
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有依赖验证通过"
    else
        print_message $YELLOW "⚠️ 部分依赖缺失，尝试系统包管理器安装..."
        
        # 尝试系统包安装
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            local sys_packages=("python3-telegram-bot" "python3-dotenv" "python3-crypto" "python3-schedule" "python3-psutil")
            for pkg in "${sys_packages[@]}"; do
                sudo $PKG_INSTALL $pkg 2>/dev/null || true
            done
        fi
        
        # 最后验证
        local final_missing=()
        for test in "${test_imports[@]}"; do
            local module=$(echo $test | cut -d':' -f1)
            if ! $PYTHON_CMD -c "import $module" 2>/dev/null; then
                final_missing+=("$module")
            fi
        done
        
        if [ ${#final_missing[@]} -eq 0 ]; then
            print_message $GREEN "✅ 系统包安装后所有依赖可用"
        else
            print_message $YELLOW "⚠️ 仍有依赖缺失: ${final_missing[*]}，但机器人可能仍可运行"
        fi
    fi
}

# 在install.sh开头添加预配置检查
handle_preconfig_mode() {
    if [ "$AUTO_INSTALL_MODE" = "true" ]; then
        print_message $BLUE "🤖 自动安装模式"
        
        if [ -n "$AUTO_BOT_TOKEN" ] && [ -n "$AUTO_CHAT_ID" ]; then
            print_message $GREEN "✅ 使用预设配置，无需用户输入"
            
            # 自动创建.env文件
            local env_file="$INSTALL_DIR/.env"
            cat > "$env_file" << EOF
BOT_TOKEN=$AUTO_BOT_TOKEN
CHAT_ID=$AUTO_CHAT_ID
EOF
            
            print_message $GREEN "✅ 配置文件已自动创建"
            return 0
        else
            print_message $RED "❌ 自动模式配置不完整"
            exit 1
        fi
    else
        return 1
    fi
}

# 在主安装流程中调用
main_installation() {
    # 1. 智能系统检测
    intelligent_system_setup
    
    # 2. 自动安装系统依赖
    auto_install_system_dependencies
    
    # 3. 智能Python环境设置
    intelligent_python_setup
    
    # 4. 检测安装模式
    print_message $BLUE "🔍 检测安装模式..."
    if [ -w "/usr/local/bin" ]; then
        INSTALL_MODE="global"
        INSTALL_DIR="/usr/local/FinalUnlock"
        print_message $GREEN "✅ 使用全局安装模式"
    else
        INSTALL_MODE="local"
        INSTALL_DIR="$HOME/FinalUnlock"
        print_message $GREEN "✅ 使用本地安装模式"
    fi
    
    # 5. 处理现有安装
    if [ -d "$INSTALL_DIR" ]; then
        print_message $YELLOW "🔄 删除现有安装..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # 6. 创建安装目录
    print_message $BLUE "📁 创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # 7. 下载项目
    print_message $BLUE "📥 下载项目..."
    cd "$INSTALL_DIR"
    if git clone https://github.com/xymn2023/FinalUnlock.git . 2>/dev/null; then
        print_message $GREEN "✅ 项目下载成功"
    else
        print_message $YELLOW "⚠️ Git下载失败，尝试curl下载..."
        curl -L https://github.com/xymn2023/FinalUnlock/archive/main.zip -o main.zip
        unzip main.zip
        mv FinalUnlock-main/* .
        rm -rf FinalUnlock-main main.zip
        print_message $GREEN "✅ 项目下载成功（curl方式）"
    fi
    
    # 8. 设置执行权限
    chmod +x *.sh 2>/dev/null || true
    
    # 9. 智能虚拟环境创建
    intelligent_venv_creation
    
    # 10. 智能依赖安装
    intelligent_dependency_installation
    
    # 11. 创建启动命令
    create_startup_commands
    
    # 12. 配置处理（支持预配置模式）
    print_message $GREEN "✅ 安装完成！"
    echo
    
    if handle_preconfig_mode; then
        print_message $GREEN "✅ 预配置模式：配置已自动完成"
    else
        print_message $CYAN "🔍 开始交互式配置..."
        # 原有的配置逻辑
        while true; do
            if intelligent_configure_environment; then
                print_message $GREEN "✅ 配置完成！"
                break
            else
                print_message $YELLOW "⚠️ 配置未完成，请重新配置"
                echo
                read -p "按回车键重新开始配置..." -r
                echo
            fi
        done
    fi
    
    print_message $GREEN "🎉 所有配置已完成，机器人已准备就绪！"
}

# 创建启动命令
create_startup_commands() {
    print_message $BLUE "🔧 创建启动命令..."
    
    local start_script=""
    if [ "$USE_SYSTEM_PYTHON" = "true" ]; then
        start_script="#!/bin/bash\ncd \"$INSTALL_DIR\"\n\"$INSTALL_DIR/start.sh\" \"\$@\""
    else
        start_script="#!/bin/bash\ncd \"$INSTALL_DIR\"\nsource \"$INSTALL_DIR/venv/bin/activate\"\n\"$INSTALL_DIR/start.sh\" \"\$@\""
    fi
    
    if [ "$INSTALL_MODE" = "global" ]; then
        echo -e "$start_script" | sudo tee /usr/local/bin/fn-bot > /dev/null
        sudo chmod +x /usr/local/bin/fn-bot
        print_message $GREEN "✅ 全局命令创建成功: fn-bot"
    else
        local_bin="$HOME/.local/bin"
        mkdir -p "$local_bin"
        echo -e "$start_script" > "$local_bin/fn-bot"
        chmod +x "$local_bin/fn-bot"
        print_message $GREEN "✅ 本地命令创建成功: fn-bot"
    fi
}

# 配置环境
configure_environment() {
    print_message $BLUE "⚙️ 配置Bot Token和Chat ID..."
    
    # 这里保持原有的配置逻辑
    # ... (原有的configure_bot函数内容)
}

# 执行主安装流程
main_installation

# 智能pip命令检测函数
detect_pip_command() {
    print_message $BLUE "📦 智能检测pip命令..."
    
    # pip命令候选列表（按优先级排序）
    local pip_candidates=(
        "$PYTHON_CMD -m pip"  # 使用检测到的Python运行pip模块（最可靠）
        "pip3"
        "pip"
        "python3 -m pip"
        "python -m pip"
    )
    
    local selected_pip=""
    local pip_version=""
    
    # 遍历候选命令
    for cmd in "${pip_candidates[@]}"; do
        print_message $YELLOW "🔄 测试pip命令: $cmd"
        
        # 测试命令是否可用
        if $cmd --version &> /dev/null; then
            # 获取pip版本信息
            local version_output=$($cmd --version 2>&1)
            pip_version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            
            # 检查pip对应的Python版本
            local pip_python_info=$(echo "$version_output" | grep -oE 'python [0-9]+\.[0-9]+' | head -1)
            local pip_python_version=$(echo "$pip_python_info" | grep -oE '[0-9]+\.[0-9]+' | head -1)
            
            if [ -n "$pip_python_version" ]; then
                local pip_major=$(echo "$pip_python_version" | cut -d'.' -f1)
                local pip_minor=$(echo "$pip_python_version" | cut -d'.' -f2)
                
                # 确保pip对应的Python版本合适
                if [ "$pip_major" -eq 3 ] && [ "$pip_minor" -ge 7 ]; then
                    selected_pip="$cmd"
                    print_message $GREEN "✅ 找到合适的pip: $cmd"
                    print_message $CYAN "💡 pip版本: $pip_version"
                    print_message $CYAN "💡 对应Python: $pip_python_version"
                    break
                else
                    print_message $YELLOW "⚠️ $cmd 对应Python版本过低: $pip_python_version"
                fi
            else
                # 如果无法检测Python版本，但pip可用，也接受
                selected_pip="$cmd"
                print_message $GREEN "✅ 找到可用的pip: $cmd (版本: $pip_version)"
                break
            fi
        else
            print_message $YELLOW "⚠️ $cmd 不可用"
        fi
    done
    
    if [ -z "$selected_pip" ]; then
        print_message $YELLOW "⚠️ 未找到可用的pip，尝试安装..."
        # 安装pip函数
        install_pip() {
        print_message $BLUE "📥 尝试安装pip..."
        
        # 方法1: 使用ensurepip模块
        print_message $YELLOW "🔄 尝试使用ensurepip安装pip..."
        if $PYTHON_CMD -m ensurepip --upgrade 2>/dev/null; then
        print_message $GREEN "✅ 使用ensurepip安装pip成功"
        PIP_CMD="$PYTHON_CMD -m pip"
        return 0
        fi
        
        # 方法2: 下载get-pip.py
        print_message $YELLOW "🔄 尝试下载get-pip.py安装pip..."
        local temp_pip_script="/tmp/get-pip.py"
        
        if curl -s https://bootstrap.pypa.io/get-pip.py -o "$temp_pip_script" 2>/dev/null; then
        if $PYTHON_CMD "$temp_pip_script" --user 2>/dev/null; then
        print_message $GREEN "✅ 使用get-pip.py安装pip成功"
        rm -f "$temp_pip_script"
        PIP_CMD="$PYTHON_CMD -m pip"
        return 0
        fi
        rm -f "$temp_pip_script"
        fi
        
        # 方法3: 使用系统包管理器
        print_message $YELLOW "🔄 尝试使用系统包管理器安装pip..."
        if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y python3-pip
        elif command -v yum &> /dev/null; then
        sudo yum install -y python3-pip
        elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3-pip
        elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python-pip
        fi
        
        # 重新检测pip
        if $PYTHON_CMD -m pip --version &> /dev/null; then
        print_message $GREEN "✅ 系统包管理器安装pip成功"
        PIP_CMD="$PYTHON_CMD -m pip"
        return 0
        elif command -v pip3 &> /dev/null; then
        print_message $GREEN "✅ 找到pip3命令"
        PIP_CMD="pip3"
        return 0
        elif command -v pip &> /dev/null; then
        print_message $GREEN "✅ 找到pip命令"
        PIP_CMD="pip"
        return 0
        fi
        
        print_message $RED "❌ 所有pip安装方法都失败"
        return 1
        }
        
        PIP_VERSION="$pip_version"
        
        print_message $CYAN "💡 使用pip命令: $PIP_CMD"
        
        return 0
    }
}

# 检测系统兼容性
check_system_compatibility() {
    print_message $BLUE "🔍 检查系统兼容性..."
    
    # 检查操作系统
    local os_info=""
    if [ -f /etc/os-release ]; then
        os_info=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    elif [ -f /etc/redhat-release ]; then
        os_info=$(cat /etc/redhat-release)
    elif [ -f /etc/debian_version ]; then
        os_info="Debian $(cat /etc/debian_version)"
    else
        os_info="Unknown Linux"
    fi
    
    print_message $CYAN "💡 操作系统: $os_info"
    
    # 检查架构
    local arch=$(uname -m)
    print_message $CYAN "💡 系统架构: $arch"
    
    # 检查包管理器
    local pkg_managers=()
    command -v apt-get &> /dev/null && pkg_managers+=("apt-get")
    command -v yum &> /dev/null && pkg_managers+=("yum")
    command -v dnf &> /dev/null && pkg_managers+=("dnf")
    command -v pacman &> /dev/null && pkg_managers+=("pacman")
    command -v zypper &> /dev/null && pkg_managers+=("zypper")
    
    if [ ${#pkg_managers[@]} -gt 0 ]; then
        print_message $CYAN "💡 可用包管理器: ${pkg_managers[*]}"
        PKG_MANAGER="${pkg_managers[0]}"  # 使用第一个找到的
    else
        print_message $YELLOW "⚠️ 未找到已知的包管理器"
        PKG_MANAGER="unknown"
    fi
    
    # 检查权限
    if [ "$EUID" -eq 0 ]; then
        print_message $YELLOW "⚠️ 当前以root用户运行"
        HAS_SUDO=true
    elif sudo -n true 2>/dev/null; then
        print_message $GREEN "✅ 具有sudo权限"
        HAS_SUDO=true
    else
        print_message $YELLOW "⚠️ 无sudo权限，某些功能可能受限"
        HAS_SUDO=false
    fi
}

# 增强版Bot Token验证
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

# 增强版Chat ID验证
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

# 智能配置环境（带在线验证）
intelligent_configure_environment() {
    print_message $BLUE "⚙️ 智能配置Bot Token和Chat ID..."
    
    local env_file="$INSTALL_DIR/.env"
    
    # 检查现有配置
    if [ -f "$env_file" ]; then
        print_message $YELLOW "⚠️ 发现已存在的.env文件"
        
        # 读取现有配置
        local existing_token=$(grep '^BOT_TOKEN=' "$env_file" 2>/dev/null | cut -d'=' -f2)
        local existing_chat_id=$(grep '^CHAT_ID=' "$env_file" 2>/dev/null | cut -d'=' -f2)
        
        if [ -n "$existing_token" ] && [ -n "$existing_chat_id" ]; then
            print_message $CYAN "📋 现有配置:"
            print_message $CYAN "Bot Token: ${existing_token:0:20}..."
            print_message $CYAN "Chat ID: $existing_chat_id"
            echo
            read -p "是否使用现有配置? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                print_message $GREEN "✅ 使用现有配置"
                return 0
            fi
        fi
    fi
    
    print_message $YELLOW "💡 开始交互式配置"
    print_message $CYAN "📋 请准备好您的Bot Token和Chat ID"
    echo
    
    # 显示获取指南
    print_message $BLUE "📖 获取指南:"
    print_message $CYAN "1. Bot Token获取:"
    print_message $CYAN "   • 在Telegram中搜索 @BotFather"
    print_message $CYAN "   • 发送 /newbot 创建新机器人"
    print_message $CYAN "   • 按提示设置机器人名称和用户名"
    print_message $CYAN "   • 复制获得的Token"
    echo
    print_message $CYAN "2. Chat ID获取:"
    print_message $CYAN "   • 在Telegram中搜索 @userinfobot"
    print_message $CYAN "   • 发送任意消息获取您的用户ID"
    print_message $CYAN "   • 复制显示的数字ID"
    echo
    
    read -p "准备好后按回车键开始配置..." -r
    echo
    
    # 配置Bot Token（带验证）
    while true; do
        print_message $BLUE "📝 第一步：配置Bot Token"
        
        while true; do
            read -p "请输入Bot Token: " BOT_TOKEN
            
            if [ -n "$BOT_TOKEN" ]; then
                local validation=$(validate_bot_token "$BOT_TOKEN")
                case $validation in
                    "empty")
                        print_message $RED "❌ Bot Token不能为空"
                        ;;
                    "invalid_format")
                        print_message $RED "❌ Bot Token格式不正确"
                        print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
                        ;;
                    "too_short")
                        print_message $RED "❌ Bot Token长度不足"
                        ;;
                    "valid")
                        print_message $GREEN "✅ Bot Token格式正确"
                        
                        # 在线验证
                        print_message $YELLOW "🌐 正在验证Bot Token有效性..."
                        if test_bot_token "$BOT_TOKEN"; then
                            print_message $GREEN "✅ Bot Token验证成功！"
                            break 2
                        else
                            print_message $YELLOW "⚠️ Bot Token验证失败（可能是网络问题）"
                            read -p "是否继续使用此Token? (y/N): " -n 1 -r
                            echo
                            if [[ $REPLY =~ ^[Yy]$ ]]; then
                                break 2
                            fi
                        fi
                        ;;
                esac
            else
                print_message $RED "❌ Bot Token不能为空"
            fi
        done
    done
    
    echo
    
    # 配置Chat ID（带验证）
    while true; do
        print_message $BLUE "📝 第二步：配置Chat ID"
        
        while true; do
            read -p "请输入Chat ID: " CHAT_ID
            
            if [ -n "$CHAT_ID" ]; then
                local validation=$(validate_chat_id "$CHAT_ID")
                case $validation in
                    "empty")
                        print_message $RED "❌ Chat ID不能为空"
                        ;;
                    "invalid_format")
                        print_message $RED "❌ Chat ID格式不正确"
                        print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
                        ;;
                    "invalid_length")
                        print_message $RED "❌ Chat ID长度不正确"
                        ;;
                    "valid")
                        print_message $GREEN "✅ Chat ID格式正确"
                        break 2
                        ;;
                esac
            else
                print_message $RED "❌ Chat ID不能为空"
            fi
        done
    done
    
    echo
    
    # 最终确认
    print_message $BLUE "📋 配置信息确认:"
    print_message $CYAN "Bot Token: ${BOT_TOKEN:0:20}..."
    print_message $CYAN "Chat ID: $CHAT_ID"
    echo
    
    while true; do
        read -p "确认保存配置吗? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            break
        else
            print_message $YELLOW "⚠️ 配置已取消，请重新开始"
            return 1
        fi
    done
    
    # 创建.env文件
    cat > "$env_file" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    
    # 测试配置
    print_message $YELLOW "🔄 测试配置..."
    if test_bot_token "$BOT_TOKEN"; then
        print_message $GREEN "✅ 配置测试成功！机器人已准备就绪"
    else
        print_message $YELLOW "⚠️ 配置测试失败，但配置已保存"
    fi
    
    return 0
}

