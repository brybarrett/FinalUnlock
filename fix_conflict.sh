#!/bin/bash

# FinalUnlock - 快速修复多实例冲突问题
# 一键解决 "terminated by other getUpdates request" 错误

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message $BLUE "🔧 FinalUnlock - 自动冲突修复工具"
print_message $YELLOW "自动解决 Telegram Bot 多实例冲突问题（无需确认）"
echo

# 检查是否在正确目录
if [ ! -f "bot.py" ] || [ ! -f "start.sh" ]; then
    print_message $RED "❌ 请在FinalUnlock项目目录中运行此脚本"
    print_message $CYAN "💡 正确路径示例: cd /usr/local/FinalUnlock && bash fix_conflict.sh"
    exit 1
fi

print_message $BLUE "🔍 正在检查运行中的bot进程..."

# 查找所有相关进程
find_processes() {
    local pids=""
    
    # 方法1：查找python bot.py
    local bot_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    
    # 方法2：查找FinalUnlock相关进程
    local fu_pids=$(pgrep -f "FinalUnlock" 2>/dev/null || true)
    
    # 方法3：详细搜索
    local detail_pids=$(ps aux | grep -E "(python.*bot\.py|FinalUnlock)" | grep -v grep | awk '{print $2}' 2>/dev/null || true)
    
    # 合并并去重
    pids=$(echo "$bot_pids $fu_pids $detail_pids" | tr ' ' '\n' | sort -u | grep -E '^[0-9]+$' || true)
    echo "$pids"
}

current_pid=$$
all_pids=$(find_processes)

# 过滤掉当前脚本的PID
filtered_pids=""
for pid in $all_pids; do
    if [ -n "$pid" ] && [ "$pid" != "$current_pid" ]; then
        filtered_pids="$filtered_pids $pid"
    fi
done

if [ -z "$filtered_pids" ]; then
    print_message $GREEN "✅ 未发现冲突的bot进程"
    print_message $BLUE "💡 现在可以安全启动机器人："
    print_message $CYAN "   ./start.sh"
    print_message $CYAN "   或者: python3 bot.py"
    exit 0
fi

print_message $YELLOW "⚠️ 发现以下可能冲突的进程："
for pid in $filtered_pids; do
    if ps -p $pid > /dev/null 2>&1; then
        local cmd=$(ps -p $pid -o cmd --no-headers 2>/dev/null | cut -c1-80)
        print_message $CYAN "   PID $pid: $cmd"
    fi
done

echo
print_message $RED "🔥 开始清理冲突进程..."

# 直接强制终止
print_message $BLUE "💥 强制终止所有冲突进程..."
for pid in $filtered_pids; do
    if ps -p $pid > /dev/null 2>&1; then
        print_message $CYAN "   强制终止进程 $pid"
        kill -9 $pid 2>/dev/null || true
    fi
done

sleep 1

# 清理PID文件
print_message $BLUE "🧹 步骤2: 清理PID文件..."
find . -name "*.pid" -delete 2>/dev/null || true

# 最终检查
final_check=$(find_processes)
final_filtered=""
for pid in $final_check; do
    if [ -n "$pid" ] && [ "$pid" != "$current_pid" ]; then
        final_filtered="$final_filtered $pid"
    fi
done

if [ -z "$final_filtered" ]; then
    print_message $GREEN "🎉 冲突清理完成！"
    echo
    print_message $BLUE "💡 现在可以安全启动机器人："
    print_message $CYAN "   ./start.sh"
    print_message $CYAN "   或者: python3 bot.py"
    echo
    print_message $YELLOW "🔒 避免再次冲突的建议："
    print_message $CYAN "   1. 自动清理: bash fix_conflict.sh"
    print_message $CYAN "   2. 手动清理: bash fix_conflict_manual.sh"
    print_message $CYAN "   3. 在start.sh菜单中: [k]自动清理 [K]手动清理"
    print_message $CYAN "   4. 优先使用: ./start.sh 启动机器人"
    print_message $CYAN "   5. 避免同时在多个终端启动"
else
    print_message $RED "❌ 仍有残留进程，可能需要重启系统"
    print_message $YELLOW "残留进程:"
    for pid in $final_filtered; do
        if ps -p $pid > /dev/null 2>&1; then
            local cmd=$(ps -p $pid -o cmd --no-headers 2>/dev/null)
            print_message $CYAN "   PID $pid: $cmd"
        fi
    done
fi
