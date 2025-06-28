#!/bin/bash

# FinalShell 激活码机器人一键安装命令
# 自动下载并执行安装脚本

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
print_message $CYAN "💡 管理界面已启动，请按提示配置Bot Token和Chat ID"
print_message $YELLOW "📋 配置完成后即可启动机器人" 