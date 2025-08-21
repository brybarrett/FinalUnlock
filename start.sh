#!/bin/bash

# FinalShell 激活码机器人管理脚本
# 作者: AI Assistant
# 版本: 3.0
# 项目地址: https://github.com/xymn2023/FinalUnlock

# 屏蔽 Ctrl+C 信号
trap '' SIGINT SIGTERM

# 自动清理bot实例函数（无需确认）
execute_auto_cleanup() {
    print_message $BLUE "🔥 开始自动清理bot实例..."
    echo
    
    # 使用自动清理脚本
    if [ -f "fix_conflict.sh" ]; then
        print_message $CYAN "使用专用自动清理脚本..."
        bash fix_conflict.sh
    else
        print_message $YELLOW "⚠️ 自动清理脚本不存在，使用内置清理逻辑..."
        internal_cleanup_logic
    fi
    
    echo
    print_message $BLUE "💡 自动清理完成，现在可以安全启动机器人了"
    print_message $CYAN "建议使用选项 [1] 启动机器人"
}

# 手动清理bot实例函数（需要确认）
execute_manual_cleanup() {
    print_message $BLUE "📋 开始手动清理bot实例..."
    echo
    
    # 使用手动清理脚本
    if [ -f "fix_conflict_manual.sh" ]; then
        print_message $CYAN "使用专用手动清理脚本..."
        bash fix_conflict_manual.sh
    else
        print_message $YELLOW "⚠️ 手动清理脚本不存在，使用内置清理逻辑..."
        internal_cleanup_logic
    fi
    
    echo
    print_message $BLUE "💡 手动清理完成，现在可以安全启动机器人了"
    print_message $CYAN "建议使用选项 [1] 启动机器人"
}

# 内置清理逻辑（共用）
internal_cleanup_logic() {
    print_message $BLUE "🔍 开始原子化清理流程..."
    
    # 创建清理锁，防止其他脚本干涉
    local cleanup_lock="/tmp/finalunlock_internal_cleanup.lock"
    echo $$ > "$cleanup_lock"
    
    # 获取当前脚本PID
    local current_pid=$$
    
    # 阶段1：发现所有需要清理的进程
    print_message $BLUE "🔍 阶段1：扫描所有相关进程..."
    local all_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    local finalunlock_pids=$(pgrep -f "FinalUnlock" 2>/dev/null || true)
    local combined_pids="$all_pids $finalunlock_pids"
    
    # 去重并过滤当前PID
    local unique_pids=$(echo "$combined_pids" | tr ' ' '\n' | sort -u | grep -E '^[0-9]+$' | grep -v "^$current_pid\$" || true)
    
    # 阶段2：强制终止所有目标进程
    if [ -n "$unique_pids" ]; then
        local process_count=$(echo "$unique_pids" | wc -w)
        print_message $YELLOW "💥 阶段2：强制终止 $process_count 个进程..."
        
        echo "$unique_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                local process_info=$(ps -p $pid -o pid,cmd --no-headers 2>/dev/null || echo "$pid [进程信息获取失败]")
                print_message $CYAN "   目标进程: $process_info"
            fi
        done
        
        # 发送KILL -9信号
        echo "$unique_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "   💥 发送KILL信号给 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
        
        # 阶段3：等待并验证进程完全退出
        print_message $BLUE "⏳ 阶段3：等待进程完全退出..."
        local max_wait=8
        local wait_time=0
        
        while [ $wait_time -lt $max_wait ]; do
            local remaining_pids=$(pgrep -f "python.*bot\.py|FinalUnlock" 2>/dev/null | grep -v "^$current_pid\$" || true)
            
            if [ -z "$remaining_pids" ]; then
                print_message $GREEN "✅ 所有目标进程已完全退出 (耗时: $((wait_time + 1))秒)"
                break
            fi
            
            if [ $wait_time -lt $((max_wait - 1)) ]; then
                local remaining_count=$(echo "$remaining_pids" | wc -w)
                print_message $YELLOW "⏳ 仍有 $remaining_count 个进程未退出，继续等待... ($((wait_time + 1))/$max_wait)"
                sleep 1
                wait_time=$((wait_time + 1))
            else
                print_message $RED "⚠️ 超时！仍有进程未完全退出，进行最后清理..."
                echo "$remaining_pids" | while read -r rpid; do
                    kill -9 $rpid 2>/dev/null || true
                done
                sleep 1
                break
            fi
        done
        
        print_message $GREEN "🎯 清理阶段完成"
    else
        print_message $GREEN "✅ 未发现需要清理的进程"
    fi
    
    # 清理PID文件
    print_message $BLUE "🧹 清理相关文件..."
    find . -name "*.pid" -delete 2>/dev/null || true
    
    # 清理systemd服务
    if systemctl is-active finalunlock 2>/dev/null | grep -q "active"; then
        print_message $BLUE "🔧 停止systemd服务..."
        systemctl stop finalunlock 2>/dev/null || true
    fi
    
    # 释放清理锁
    rm -f "$cleanup_lock"
    
    print_message $GREEN "✅ 原子化清理完成"
}

# 启动前自动清理函数（静默模式）
auto_cleanup_before_start() {
    # 静默检查并清理冲突进程，不显示详细信息
    local current_pid=$$
    local all_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    local finalunlock_pids=$(pgrep -f "FinalUnlock" 2>/dev/null || true)
    local combined_pids="$all_pids $finalunlock_pids"
    local unique_pids=$(echo "$combined_pids" | tr ' ' '\n' | sort -u | grep -E '^[0-9]+$' || true)
    
    # 过滤掉当前脚本的PID
    local filtered_pids=""
    for pid in $unique_pids; do
        if [ -n "$pid" ] && [ "$pid" != "$current_pid" ]; then
            filtered_pids="$filtered_pids $pid"
        fi
    done
    
    if [ -n "$filtered_pids" ]; then
        print_message $YELLOW "⚠️ 检测到 $(echo $filtered_pids | wc -w) 个冲突进程，正在自动清理..."
        
        # 直接使用kill -9强制清理，不等待
        for pid in $filtered_pids; do
            kill -9 $pid 2>/dev/null || true
        done
        
        # 清理PID文件
        find . -name "*.pid" -delete 2>/dev/null || true
        
        print_message $GREEN "✅ 冲突进程已清理"
    else
        print_message $GREEN "✅ 未发现冲突进程"
    fi
}

# 启动或重启机器人函数
start_or_restart_bot() {
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    if [ -d "$venv_dir" ]; then
        source "$venv_dir/bin/activate"
        # 验证并设置正确的Python命令
        if [ -x "$venv_dir/bin/python" ]; then
            PYTHON_CMD="$venv_dir/bin/python"
        elif [ -x "$venv_dir/bin/python3" ]; then
            PYTHON_CMD="$venv_dir/bin/python3"
        elif command -v python &> /dev/null; then
            PYTHON_CMD="python"
        else
            PYTHON_CMD="python3"
        fi
    fi
    
    # 创建日志目录（如果不存在）
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # 创建启动锁文件，防止其他脚本干涉
    local startup_lock="/tmp/finalunlock_startup.lock"
    if [ -f "$startup_lock" ]; then
        print_message $YELLOW "⚠️ 检测到其他启动进程正在执行，等待完成..."
        local wait_count=0
        while [ -f "$startup_lock" ] && [ $wait_count -lt 30 ]; do
            sleep 1
            wait_count=$((wait_count + 1))
        done
        if [ -f "$startup_lock" ]; then
            print_message $RED "⚠️ 启动锁超时，强制清除锁文件"
            rm -f "$startup_lock"
        fi
    fi
    
    # 获取启动锁
    echo $$ > "$startup_lock"
    print_message $BLUE "🔒 已获取启动锁，开始原子化启动流程..."
    
    # 阶段1：发现所有冲突进程
    print_message $BLUE "🔍 阶段1：扫描所有冲突进程..."
    local conflicting_pids1=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    local conflicting_pids2=$(ps aux | grep -E "python.*bot\.py" | grep -v grep | awk '{print $2}' 2>/dev/null || true)
    local all_conflicting_pids="$conflicting_pids1 $conflicting_pids2"
    
    # 去重并过滤当前脚本PID
    local unique_pids=$(echo "$all_conflicting_pids" | tr ' ' '\n' | sort -u | grep -v '^$' | grep -v "^$$\$" || true)
    
    # 阶段2：强制终止所有冲突进程
    if [ -n "$unique_pids" ]; then
        local pid_count=$(echo "$unique_pids" | wc -l)
        print_message $YELLOW "💥 阶段2：强制终止 $pid_count 个冲突进程..."
        
        echo "$unique_pids" | while read -r cpid; do
            if [ -n "$cpid" ] && [ "$cpid" != "$$" ]; then
                print_message $CYAN "   💥 发送KILL信号给 PID: $cpid"
                kill -9 $cpid 2>/dev/null || true
            fi
        done
        
        # 阶段3：等待并验证所有进程完全退出
        print_message $BLUE "⏳ 阶段3：等待所有进程完全退出..."
        local max_wait=10
        local wait_time=0
        
        while [ $wait_time -lt $max_wait ]; do
            local remaining_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
            if [ -z "$remaining_pids" ]; then
                print_message $GREEN "✅ 所有冲突进程已完全退出 (耗时: $((wait_time + 1))秒)"
                break
            fi
            
            if [ $wait_time -lt $((max_wait - 1)) ]; then
                local remaining_count=$(echo "$remaining_pids" | wc -w)
                print_message $YELLOW "⏳ 仍有 $remaining_count 个进程未退出，继续等待... ($((wait_time + 1))/$max_wait)"
                sleep 1
                wait_time=$((wait_time + 1))
            else
                print_message $RED "⚠️ 超时！仍有进程未完全退出: $remaining_pids"
                # 最后一次强制清理
                echo "$remaining_pids" | while read -r rpid; do
                    kill -9 $rpid 2>/dev/null || true
                done
                sleep 1
                break
            fi
        done
        
        print_message $GREEN "🎯 清理阶段完成，确保所有冲突进程已终止"
    else
        print_message $GREEN "✅ 未发现冲突进程"
    fi
    
    # 阶段4：最终验证无残留进程
    print_message $BLUE "🔍 阶段4：最终验证..."
    local final_check=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    if [ -n "$final_check" ]; then
        print_message $RED "❌ 发现残留进程: $final_check"
        print_message $RED "❌ 启动中止，请手动清理后重试"
        rm -f "$startup_lock"
        return 1
    fi
    
    print_message $GREEN "✅ 验证通过：无残留进程，可以安全启动"
    
    # 阶段5：启动新的机器人实例
    print_message $BLUE "🚀 阶段5：启动新的机器人实例..."
    print_message $CYAN "💡 日志将实时记录到: $LOG_FILE"
    nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # 保存PID
    echo $pid > "$PID_FILE"
    
    # 等待一下检查是否启动成功
    sleep 3
    if ps -p $pid > /dev/null 2>&1; then
        print_message $GREEN "✅ 机器人启动成功 (PID: $pid)"
        print_message $CYAN "💡 机器人已在后台运行，即使退出脚本也会继续运行"
        print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
        print_message $CYAN "📋 实时日志文件: $LOG_FILE"
        
        # 释放启动锁
        rm -f "$startup_lock"
        print_message $BLUE "🔓 已释放启动锁"
        
        # 显示启动日志
        echo
        print_message $BLUE "📋 最新启动日志："
        tail -n 5 "$LOG_FILE" 2>/dev/null || echo "日志文件暂时为空"
        return 0
    else
        print_message $RED "❌ 机器人启动失败"
        print_message $YELLOW "💡 可能原因："
        print_message $CYAN "   • Bot Token 或 Chat ID 配置错误"
        print_message $CYAN "   • 网络连接问题"
        print_message $CYAN "   • Python依赖包缺失"
        
        echo
        print_message $BLUE "📋 错误日志："
        tail -n 10 "$LOG_FILE" 2>/dev/null || echo "无法读取日志文件"
        
        # 启动失败时的二次尝试（自动清理后重试）
        echo
        print_message $YELLOW "🔄 即将进行二次启动尝试..."
        
        # 保持启动锁，防止其他脚本干涉
        print_message $CYAN "🔒 保持启动锁，执行更彻底的清理..."
        sleep 2
        
        # 执行更彻底的清理
        execute_thorough_cleanup
        
        # 额外的冲突进程清理（原子化操作）
        print_message $BLUE "🔍 二次清理：扫描残留进程..."
        local extra_pids=$(pgrep -f "bot\.py" 2>/dev/null || true)
        if [ -n "$extra_pids" ]; then
            print_message $YELLOW "💥 二次清理：发现 $(echo $extra_pids | wc -w) 个残留进程"
            echo "$extra_pids" | while read -r epid; do
                print_message $CYAN "   💥 强制终止残留进程 PID: $epid"
                kill -9 $epid 2>/dev/null || true
            done
            
            # 等待残留进程完全退出
            print_message $BLUE "⏳ 等待残留进程完全退出..."
            sleep 3
            
            # 最终验证
            local final_remaining=$(pgrep -f "bot\.py" 2>/dev/null || true)
            if [ -n "$final_remaining" ]; then
                print_message $RED "⚠️ 仍有残留进程无法清理: $final_remaining"
            else
                print_message $GREEN "✅ 所有残留进程已清理完成"
            fi
        fi
        
        print_message $BLUE "⏳ 等待系统状态完全稳定..."
        sleep 5
        
        print_message $BLUE "🔄 二次启动尝试..."
        nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
        local retry_pid=$!
        echo $retry_pid > "$PID_FILE"
        
        sleep 3
        if ps -p $retry_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ 二次启动成功 (PID: $retry_pid)"
            # 释放启动锁
            rm -f "$startup_lock"
            print_message $BLUE "🔓 已释放启动锁"
            return 0
        else
            print_message $RED "❌ 二次启动也失败"
            print_message $YELLOW "💡 建议检查配置或查看详细日志"
            rm -f "$PID_FILE"
            # 释放启动锁
            rm -f "$startup_lock"
            print_message $BLUE "🔓 已释放启动锁"
            return 1
        fi
    fi
}

# 彻底清理函数（用于二次启动前）
execute_thorough_cleanup() {
    print_message $BLUE "🔥 执行彻底清理..."
    
    # 停止所有可能的服务
    if systemctl is-active finalunlock 2>/dev/null | grep -q "active"; then
        systemctl stop finalunlock 2>/dev/null || true
    fi
    
    # 查找并终止所有相关进程
    local all_processes=$(ps aux | grep -E "(python.*bot\.py|FinalUnlock)" | grep -v grep | awk '{print $2}' || true)
    
    if [ -n "$all_processes" ]; then
        echo "$all_processes" | while read -r pid; do
            if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 清理所有PID和锁文件
    find . -name "*.pid" -delete 2>/dev/null || true
    find . -name "*.lock" -delete 2>/dev/null || true
    find /tmp -name "*finalunlock*" -delete 2>/dev/null || true
    
    # 清理可能的套接字文件
    find /tmp -name "*bot*" -type s -delete 2>/dev/null || true
    
    sleep 2
    print_message $GREEN "✅ 彻底清理完成"
}

# 停止机器人并自动清理函数
stop_bot_with_cleanup() {
    print_message $BLUE "🛑 正在停止机器人并清理相关进程..."
    
    # 方法1：通过PID文件停止
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            if ps -p $pid > /dev/null 2>&1; then
                print_message $CYAN "发现运行中的机器人 (PID: $pid)，正在强制停止..."
                kill -9 $pid 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # 方法2：停止所有bot.py进程（自动清理冲突进程）
    local bot_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    if [ -n "$bot_pids" ]; then
        print_message $CYAN "发现其他bot进程，正在清理..."
        echo "$bot_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "   强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 方法3：停止systemd服务
    if systemctl is-active finalunlock 2>/dev/null | grep -q "active"; then
        print_message $CYAN "停止systemd服务..."
        systemctl stop finalunlock 2>/dev/null || true
    fi
    
    # 清理相关文件
    print_message $CYAN "清理相关文件..."
    find . -name "*.pid" -delete 2>/dev/null || true
    find . -name "*.lock" -delete 2>/dev/null || true
    
    # 最终验证
    local remaining_pids=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    if [ -z "$remaining_pids" ]; then
        print_message $GREEN "✅ 机器人已完全停止"
    else
        print_message $YELLOW "⚠️ 仍有残留进程："
        echo "$remaining_pids" | while read -r pid; do
            if ps -p $pid > /dev/null 2>&1; then
                local cmd=$(ps -p $pid -o cmd --no-headers 2>/dev/null)
                print_message $CYAN "   PID $pid: $cmd"
            fi
        done
        print_message $YELLOW "💡 建议运行强力清理：选择菜单选项 [k] 或 [K]"
    fi
}

# 卸载机器人并清理所有相关进程函数
uninstall_bot_with_cleanup() {
    print_message $RED "🗑️ 开始卸载机器人并清理所有相关进程..."
    echo
    
    # 首先停止所有相关进程（最彻底的清理）
    print_message $BLUE "🛑 第一步：停止所有运行中的进程..."
    
    # 🔥 停止主进程（使用kill -9）
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            print_message $CYAN "💥 强制停止主进程 (PID: $pid)..."
            kill -9 $pid 2>/dev/null || true
        fi
    fi
    
    # 🔥 强制停止所有bot和guard进程（使用kill -9）
    print_message $CYAN "🔄 强制清理bot进程..."
    local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$bot_pids" ]; then
        print_message $CYAN "发现bot进程，正在强制清理..."
        echo "$bot_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "   💥 强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    print_message $CYAN "🔄 强制清理guard进程..."
    local guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
    if [ -n "$guard_pids" ]; then
        print_message $CYAN "发现guard进程，正在强制清理..."
        echo "$guard_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "   💥 强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 通用清理所有相关进程
    local all_pids=$(ps aux | grep -E "(python.*(bot|guard)\.py|FinalUnlock)" | grep -v grep | awk '{print $2}' || true)
    if [ -n "$all_pids" ]; then
        print_message $CYAN "发现其他相关进程，正在清理..."
        echo "$all_pids" | while read -r pid; do
            if [ -n "$pid" ] && [ "$pid" != "$$" ]; then
                print_message $CYAN "   💥 强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 停止系统服务
    if systemctl is-active finalunlock 2>/dev/null | grep -q "active"; then
        print_message $CYAN "停止systemd服务..."
        systemctl stop finalunlock 2>/dev/null || true
        systemctl disable finalunlock 2>/dev/null || true
    fi
    
    # 清理服务文件
    if [ -f "/etc/systemd/system/finalunlock.service" ]; then
        print_message $CYAN "删除systemd服务文件..."
        sudo rm -f /etc/systemd/system/finalunlock.service 2>/dev/null || true
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
    
    print_message $GREEN "✅ 所有进程已停止"
    
    # 第二步：清理文件和目录
    print_message $BLUE "🧹 第二步：清理文件和目录..."
    
    # 清理PID和锁文件
    find . -name "*.pid" -delete 2>/dev/null || true
    find . -name "*.lock" -delete 2>/dev/null || true
    find /tmp -name "*finalunlock*" -delete 2>/dev/null || true
    find /tmp -name "*bot*" -type s -delete 2>/dev/null || true
    
    # 清理日志文件
    if [ -f "$LOG_FILE" ]; then
        print_message $CYAN "清理日志文件..."
        rm -f "$LOG_FILE" 2>/dev/null || true
    fi
    
    # 清理配置文件
    if [ -f "$ENV_FILE" ]; then
        read -p "是否删除配置文件 (.env)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$ENV_FILE"
            print_message $CYAN "✅ 配置文件已删除"
        else
            print_message $YELLOW "⚠️ 保留配置文件"
        fi
    fi
    
    # 第三步：询问是否删除项目文件
    echo
    print_message $YELLOW "⚠️ 是否删除整个项目目录?"
    print_message $RED "警告：这将删除所有项目文件，包括脚本和虚拟环境"
    read -p "确认删除项目目录? (输入 'DELETE' 确认): " confirm
    
    if [ "$confirm" = "DELETE" ]; then
        print_message $RED "🗑️ 删除项目目录..."
        cd ..
        rm -rf "$PROJECT_DIR"
        print_message $GREEN "✅ 项目已完全卸载"
        
        # 清理全局命令
        if command -v fn-bot &> /dev/null; then
            print_message $CYAN "清理全局命令..."
            sudo rm -f /usr/local/bin/fn-bot 2>/dev/null || true
            sudo rm -f /usr/bin/fn-bot 2>/dev/null || true
        fi
        
        print_message $BLUE "👋 FinalUnlock 已完全卸载"
        sleep 1
        clear
        exit 0
    else
        print_message $YELLOW "⚠️ 保留项目文件，仅清理了运行进程"
        print_message $CYAN "💡 如需重新安装，可运行 ./start.sh"
    fi
    
    print_message $GREEN "✅ 卸载和清理完成"
}

# 安全退出函数
safe_exit() {
    print_message $YELLOW "🔄 正在安全退出..."
    print_message $CYAN "💡 如果机器人正在运行，它会继续在后台运行"
    print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
    sleep 2
    clear
    exit 0
}

# 紧急退出函数（用于卸载等操作）
emergency_exit() {
    print_message $RED "🛑 紧急退出..."
    exit 1
}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局进程管理器 - 确保只有一个主控程序
GLOBAL_MANAGER_LOCK="/tmp/finalunlock_global_manager.lock"

acquire_global_control() {
    local script_name="$1"
    local timeout=30
    local wait_time=0
    
    # 检查是否有其他主控程序在运行
    if [ -f "$GLOBAL_MANAGER_LOCK" ]; then
        local existing_controller=$(cat "$GLOBAL_MANAGER_LOCK" 2>/dev/null || echo "unknown")
        print_message $YELLOW "⚠️ 检测到其他主控程序正在运行: $existing_controller"
        print_message $YELLOW "⏳ 等待其他主控程序完成..."
        
        while [ -f "$GLOBAL_MANAGER_LOCK" ] && [ $wait_time -lt $timeout ]; do
            sleep 1
            wait_time=$((wait_time + 1))
            if [ $((wait_time % 5)) -eq 0 ]; then
                print_message $YELLOW "⏳ 等待中... ($wait_time/$timeout 秒)"
            fi
        done
        
        if [ -f "$GLOBAL_MANAGER_LOCK" ]; then
            print_message $RED "⚠️ 等待超时，强制获取控制权"
            rm -f "$GLOBAL_MANAGER_LOCK"
        fi
    fi
    
    # 获取全局控制权
    echo "$script_name (PID: $$)" > "$GLOBAL_MANAGER_LOCK"
    print_message $BLUE "🔒 已获取全局控制权: $script_name"
}

release_global_control() {
    if [ -f "$GLOBAL_MANAGER_LOCK" ]; then
        rm -f "$GLOBAL_MANAGER_LOCK"
        print_message $BLUE "🔓 已释放全局控制权"
    fi
}

# 项目配置
GITHUB_REPO="https://github.com/xymn2023/FinalUnlock.git"
PROJECT_NAME="FinalUnlock"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$PROJECT_DIR/bot.pid"
LOG_FILE="$PROJECT_DIR/bot.log"
ENV_FILE="$PROJECT_DIR/.env"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 检查并下载项目
download_project() {
    print_message $BLUE "📥 检查项目文件..."
    
    # 检查是否在正确的项目目录
    if [ -f "$PROJECT_DIR/bot.py" ] && [ -f "$PROJECT_DIR/py.py" ]; then
        print_message $GREEN "✅ 项目文件已存在"
        return 0
    fi
    
    print_message $YELLOW "🔄 项目文件不完整，正在从GitHub下载..."
    
    # 检查git是否安装
    if ! command -v git &> /dev/null; then
        print_message $RED "❌ 未找到git，请先安装git"
        print_message $YELLOW "Ubuntu/Debian: sudo apt-get install git"
        print_message $YELLOW "CentOS/RHEL: sudo yum install git"
        exit 1
    fi
    
    # 备份当前目录（如果存在）
    if [ -d "$PROJECT_DIR" ] && [ "$(ls -A $PROJECT_DIR)" ]; then
        local backup_dir="$PROJECT_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        print_message $YELLOW "🔄 备份现有文件到: $backup_dir"
        mv "$PROJECT_DIR" "$backup_dir"
    fi
    
    # 创建新的项目目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 克隆仓库
    print_message $BLUE "🔄 正在克隆仓库: $GITHUB_REPO"
    git clone "$GITHUB_REPO" .
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 项目下载完成"
        
        # 确保脚本有执行权限
        chmod +x start.sh
        
        return 0
    else
        print_message $RED "❌ 项目下载失败"
        return 1
    fi
}

# 注册全局命令
register_global_command() {
    print_message $BLUE "🔧 注册全局命令 fn-bot..."
    
    # 检查操作系统
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OS" == "Windows_NT" ]]; then
        print_message $YELLOW "⚠️ 检测到Windows环境"
        print_message $YELLOW "💡 此项目设计为在Linux系统上运行"
        print_message $CYAN "📋 在Linux系统上，fn-bot命令将自动注册到 /usr/local/bin/"
        print_message $CYAN "📋 当前可以直接使用: bash start.sh"
        return 1
    fi
    
    # 获取脚本的绝对路径
    local script_path="$PROJECT_DIR/start.sh"
    
    # 检查脚本是否存在
    if [ ! -f "$script_path" ]; then
        print_message $RED "❌ 脚本文件不存在: $script_path"
        return 1
    fi
    
    # 确保脚本有执行权限
    chmod +x "$script_path"
    
    # 尝试多个可能的bin目录
    local bin_dirs=("/usr/local/bin" "$HOME/.local/bin" "/usr/bin")
    local command_name="fn-bot"
    local success=false
    
    for bin_dir in "${bin_dirs[@]}"; do
        local command_path="$bin_dir/$command_name"
        
        # 确保目录存在
        if [ "$bin_dir" = "$HOME/.local/bin" ]; then
            mkdir -p "$bin_dir" 2>/dev/null
        fi
        
        # 检查目录是否存在且可写
        if [ -d "$bin_dir" ]; then
            if [ -w "$bin_dir" ]; then
        # 直接创建命令
                print_message $CYAN "📝 在 $bin_dir 创建全局命令..."
        tee "$command_path" > /dev/null << EOF
#!/bin/bash
"$script_path" "\$@"
EOF
        chmod +x "$command_path"
    
    if [ $? -eq 0 ]; then
                    print_message $GREEN "✅ 全局命令 fn-bot 注册成功: $command_path"
                    success=true
                    break
                fi
            elif [ "$bin_dir" = "/usr/local/bin" ] || [ "$bin_dir" = "/usr/bin" ]; then
                # 需要sudo权限的目录
                print_message $YELLOW "⚠️ 没有权限写入 $bin_dir，尝试使用 sudo..."
                if sudo tee "$command_path" > /dev/null << EOF
#!/bin/bash
"$script_path" "\$@"
EOF
                then
                    sudo chmod +x "$command_path"
                    if [ $? -eq 0 ]; then
                        print_message $GREEN "✅ 全局命令 fn-bot 注册成功: $command_path"
                        success=true
                        break
                    fi
                fi
            fi
        fi
    done
    
    if [ "$success" = true ]; then
        print_message $CYAN "现在可以在任意目录使用 'fn-bot' 命令启动机器人管理脚本"
        
        # 检查PATH中是否包含安装目录
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && [ -f "$HOME/.local/bin/$command_name" ]; then
            print_message $YELLOW "💡 提示：请将 $HOME/.local/bin 添加到PATH环境变量"
            print_message $CYAN "执行：echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc && source ~/.bashrc"
        fi
        
        return 0
    else
        print_message $RED "❌ 全局命令注册失败"
        print_message $YELLOW "💡 您仍然可以使用完整路径运行脚本："
        print_message $CYAN "   bash $script_path"
        return 1
    fi
}

# 检查全局命令是否已注册
check_global_command() {
    # 在Windows环境下始终返回失败，因为不支持全局命令
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OS" == "Windows_NT" ]]; then
        return 1
    fi
    
    if command -v fn-bot &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查Python3环境
check_python() {
    print_message $BLUE "🔍 检查Python3环境..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        print_message $GREEN "✅ 找到 python3"
    else
        print_message $YELLOW "⚠️ 未找到python3，尝试自动安装..."
        # 自动安装python3
        if command -v apt-get &> /dev/null; then
            print_message $YELLOW "🔄 使用apt-get安装python3..."
            sudo apt-get update
            sudo apt-get install -y python3
        elif command -v yum &> /dev/null; then
            print_message $YELLOW "🔄 使用yum安装python3..."
            sudo yum install -y python3
        elif command -v dnf &> /dev/null; then
            print_message $YELLOW "🔄 使用dnf安装python3..."
            sudo dnf install -y python3
        else
            print_message $RED "❌ 无法识别系统包管理器，无法自动安装python3"
            print_message $YELLOW "请手动安装python3后重试"
            exit 1
        fi
        # 安装后再次检测
        if command -v python3 &> /dev/null; then
            PYTHON_CMD="python3"
            print_message $GREEN "✅ python3安装成功"
        else
            print_message $RED "❌ python3安装失败，请手动安装后重试"
            exit 1
        fi
    fi
    
    # 检查Python版本
    local version=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 7 ]); then
        print_message $RED "❌ Python版本过低，需要Python 3.7+，当前版本: $version"
        exit 1
    fi
    
    print_message $GREEN "✅ Python版本检查通过: $version"
    
    # 检查pip
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
        print_message $GREEN "✅ 找到 pip3"
    else
        print_message $YELLOW "⚠️ 未找到pip3，尝试使用python3 -m pip..."
        if $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
            print_message $GREEN "✅ 找到 python3 -m pip"
        else
            print_message $YELLOW "⚠️ 未找到pip3，尝试安装..."
            install_pip
        fi
    fi
}

# 安装pip
install_pip() {
    print_message $BLUE "📦 正在安装pip..."
    
    # 尝试使用get-pip.py安装
    if command -v curl &> /dev/null; then
        print_message $YELLOW "🔄 使用curl下载get-pip.py..."
        curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    elif command -v wget &> /dev/null; then
        print_message $YELLOW "🔄 使用wget下载get-pip.py..."
        wget -q https://bootstrap.pypa.io/get-pip.py -O get-pip.py
    else
        print_message $RED "❌ 未找到curl或wget，无法下载pip"
        print_message $YELLOW "尝试使用系统包管理器安装pip..."
        install_pip_system
        return
    fi
    
    if [ -f "get-pip.py" ]; then
        print_message $YELLOW "🔄 安装pip..."
        $PYTHON_CMD get-pip.py --user
        rm -f get-pip.py
        
        # 检查安装结果
        if $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
            print_message $GREEN "✅ pip安装成功"
        else
            print_message $YELLOW "⚠️ pip安装失败，尝试使用系统包管理器..."
            install_pip_system
        fi
    else
        print_message $RED "❌ 下载get-pip.py失败"
        print_message $YELLOW "尝试使用系统包管理器安装pip..."
        install_pip_system
    fi
}

# 使用系统包管理器安装pip
install_pip_system() {
    print_message $BLUE "🔧 尝试使用系统包管理器安装pip..."
    
    if command -v apt-get &> /dev/null; then
        print_message $YELLOW "🔄 使用apt-get安装python3-pip..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
    elif command -v yum &> /dev/null; then
        print_message $YELLOW "🔄 使用yum安装python3-pip..."
        sudo yum install -y python3-pip
    elif command -v dnf &> /dev/null; then
        print_message $YELLOW "🔄 使用dnf安装python3-pip..."
        sudo dnf install -y python3-pip
    else
        print_message $RED "❌ 无法识别系统包管理器"
        print_message $YELLOW "请手动安装pip:"
        print_message $CYAN "  Ubuntu/Debian: sudo apt-get install python3-pip"
        print_message $CYAN "  CentOS/RHEL: sudo yum install python3-pip"
        exit 1
    fi
    
    # 检查安装结果
    if command -v pip3 &> /dev/null; then
        PIP_CMD="pip3"
        print_message $GREEN "✅ pip3安装成功"
    elif command -v pip &> /dev/null; then
        PIP_CMD="pip"
        print_message $GREEN "✅ pip安装成功"
    elif $PYTHON_CMD -m pip --version &> /dev/null; then
        PIP_CMD="$PYTHON_CMD -m pip"
        print_message $GREEN "✅ python -m pip可用"
    else
        print_message $RED "❌ pip安装失败"
        print_message $YELLOW "请手动安装pip后重试"
        exit 1
    fi
}

# 检查并安装依赖
install_dependencies() {
    print_message $BLUE "📦 检查并安装依赖..."
    
    # 检查requirements.txt是否存在
    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        print_message $RED "❌ requirements.txt 文件不存在"
        exit 1
    fi
    
    # 确保pip命令可用
    if [ -z "$PIP_CMD" ]; then
        print_message $YELLOW "⚠️ pip命令未设置，重新检测..."
        check_python
    fi
    
    # 升级pip
    print_message $YELLOW "🔄 升级pip..."
    $PIP_CMD install --upgrade pip --user
    
    # 安装依赖
    print_message $YELLOW "📥 安装项目依赖..."
    $PIP_CMD install -r "$PROJECT_DIR/requirements.txt" --user
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 依赖安装完成"
    else
        print_message $RED "❌ 依赖安装失败"
        print_message $YELLOW "尝试使用系统包管理器安装..."
        install_dependencies_system
    fi
}

# 使用系统包管理器安装依赖
install_dependencies_system() {
    print_message $BLUE "🔧 尝试使用系统包管理器安装依赖..."
    
    if command -v apt-get &> /dev/null; then
        print_message $YELLOW "🔄 使用apt-get安装依赖..."
        sudo apt-get update
        
        # 尝试安装系统包
        if sudo apt-get install -y python3-telegram-bot python3-dotenv python3-cryptodome 2>/dev/null; then
            print_message $GREEN "✅ 系统包安装成功"
            return 0
        else
            print_message $YELLOW "⚠️ 系统包安装失败，尝试使用pip安装..."
        fi
        
        # 如果系统包安装失败，尝试使用pip安装
        if command -v pip3 &> /dev/null; then
            PIP_CMD="pip3"
        elif command -v pip &> /dev/null; then
            PIP_CMD="pip"
        elif $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
        else
            print_message $RED "❌ 无法找到可用的pip"
            print_message $YELLOW "请手动安装依赖:"
            print_message $CYAN "  pip install python-telegram-bot python-dotenv pycryptodome"
            exit 1
        fi
        
        # 尝试使用--break-system-packages标志
        print_message $YELLOW "🔄 尝试使用--break-system-packages标志安装..."
        $PIP_CMD install --break-system-packages -r "$PROJECT_DIR/requirements.txt"
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "✅ 依赖安装完成"
            return 0
        else
            print_message $YELLOW "⚠️ --break-system-packages安装失败，尝试创建虚拟环境..."
            install_dependencies_venv
        fi
        
    elif command -v yum &> /dev/null; then
        print_message $YELLOW "🔄 使用yum安装依赖..."
        sudo yum install -y python3-pip python3-telegram-bot python3-dotenv python3-cryptodome
    elif command -v dnf &> /dev/null; then
        print_message $YELLOW "🔄 使用dnf安装依赖..."
        sudo dnf install -y python3-pip python3-telegram-bot python3-dotenv python3-cryptodome
    else
        print_message $RED "❌ 无法识别系统包管理器"
        print_message $YELLOW "请手动安装以下依赖:"
        print_message $CYAN "  python-telegram-bot"
        print_message $CYAN "  python-dotenv"
        print_message $CYAN "  pycryptodome"
        exit 1
    fi
    
    # 再次尝试pip安装
    print_message $YELLOW "🔄 再次尝试pip安装..."
    $PIP_CMD install -r "$PROJECT_DIR/requirements.txt" --user
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 依赖安装完成"
    else
        print_message $RED "❌ 依赖安装仍然失败"
        print_message $YELLOW "请检查网络连接或手动安装依赖"
        exit 1
    fi
}

# 使用虚拟环境安装依赖
install_dependencies_venv() {
    print_message $BLUE "🐍 创建虚拟环境安装依赖..."
    
    # 检查是否支持虚拟环境
    if ! $PYTHON_CMD -c "import venv" 2>/dev/null; then
        print_message $RED "❌ 系统不支持虚拟环境"
        print_message $YELLOW "请安装python3-venv: sudo apt-get install python3-venv"
        exit 1
    fi
    
    # 创建虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    print_message $YELLOW "🔄 创建虚拟环境: $venv_dir"
    $PYTHON_CMD -m venv "$venv_dir"
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 虚拟环境创建失败"
        exit 1
    fi
    
    # 激活虚拟环境
    print_message $YELLOW "🔄 激活虚拟环境..."
    source "$venv_dir/bin/activate"
    
    # 升级pip
    print_message $YELLOW "🔄 升级虚拟环境中的pip..."
    pip install --upgrade pip
    
    # 安装依赖
    print_message $YELLOW "📥 在虚拟环境中安装依赖..."
    pip install -r "$PROJECT_DIR/requirements.txt"
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 虚拟环境依赖安装完成"
        print_message $CYAN "💡 虚拟环境路径: $venv_dir"
        print_message $CYAN "💡 激活命令: source $venv_dir/bin/activate"
        
        # 更新PYTHON_CMD为虚拟环境中的Python，但先验证文件是否存在
        if [ -x "$venv_dir/bin/python" ]; then
            PYTHON_CMD="$venv_dir/bin/python"
        elif [ -x "$venv_dir/bin/python3" ]; then
            PYTHON_CMD="$venv_dir/bin/python3"
        else
            print_message $YELLOW "⚠️ 虚拟环境Python不存在，使用系统Python"
            PYTHON_CMD="python3"
        fi
        
        if [ -x "$venv_dir/bin/pip" ]; then
            PIP_CMD="$venv_dir/bin/pip"
        else
            PIP_CMD="$PYTHON_CMD -m pip"
        fi
        
        return 0
    else
        print_message $RED "❌ 虚拟环境依赖安装失败"
        exit 1
    fi
}

# 强制配置环境变量（首次运行）
force_setup_environment() {
    print_message $BLUE "⚙️ 配置环境变量..."
    
    # 等待用户确认开始配置
    print_message $YELLOW "💡 即将开始配置Bot Token和Chat ID"
    print_message $CYAN "📋 请确保您已经准备好Bot Token和Chat ID"
    echo
    read -p "按回车键开始配置..." -r
    echo
    
    # 配置Bot Token
    while true; do
        print_message $BLUE "📝 第一步：配置Bot Token"
        print_message $CYAN "请输入您的Bot Token (从 @BotFather 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @BotFather，发送 /newbot 创建机器人"
        
        # 获取Bot Token
        while true; do
            read -p "Bot Token: " BOT_TOKEN
            
            if [ -n "$BOT_TOKEN" ]; then
                # 简单验证Bot Token格式
                if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
                    print_message $GREEN "✅ Bot Token格式正确"
                    break
                else
                    print_message $RED "❌ Bot Token格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
                fi
            else
                print_message $RED "❌ Bot Token不能为空"
            fi
        done
        
        # 确认Bot Token
        echo
        print_message $BLUE "📋 您输入的Bot Token: $BOT_TOKEN"
        read -p "确认Bot Token正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Bot Token已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Bot Token"
            echo
        fi
    done
    
    echo
    
    # 配置Chat ID
    while true; do
        print_message $BLUE "📝 第二步：配置Chat ID"
        print_message $CYAN "请输入管理员的Chat ID (可通过 @userinfobot 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @userinfobot，发送任意消息获取ID"
        echo
        read -p "准备好Chat ID后按回车键继续..." -r
        echo
        
        # 获取Chat ID
        while true; do
            read -p "Chat ID: " CHAT_ID
            
            if [ -n "$CHAT_ID" ]; then
                # 简单验证Chat ID格式
                if [[ "$CHAT_ID" =~ ^[0-9]+$ ]] || [[ "$CHAT_ID" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
                    print_message $GREEN "✅ Chat ID格式正确"
                    break
                else
                    print_message $RED "❌ Chat ID格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
                fi
            else
                print_message $RED "❌ Chat ID不能为空"
            fi
        done
        
        # 确认Chat ID
        echo
        print_message $BLUE "📋 您输入的Chat ID: $CHAT_ID"
        read -p "确认Chat ID正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Chat ID已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Chat ID"
            echo
        fi
    done
    
    echo
    
    # 最终确认
    while true; do
        print_message $BLUE "📋 配置信息确认:"
        print_message $CYAN "Bot Token: $BOT_TOKEN"
        print_message $CYAN "Chat ID: $CHAT_ID"
        echo
        read -p "确认保存配置吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        else
            print_message $YELLOW "⚠️ 配置已取消，请重新开始"
            return 1
        fi
    done
    
    # 创建.env文件
    cat > "$ENV_FILE" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    return 0
}

# 配置环境变量（菜单选项）
setup_environment() {
    print_message $BLUE "⚙️ 配置环境变量..."
    
    # 检查.env文件是否存在
    if [ -f "$ENV_FILE" ]; then
        print_message $YELLOW "⚠️ 发现已存在的.env文件"
        read -p "是否要重新配置? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ 使用现有配置"
            return 0
        fi
    fi
    
    # 配置Bot Token
    while true; do
        echo
        print_message $CYAN "请输入您的Bot Token (从 @BotFather 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @BotFather，发送 /newbot 创建机器人"
        
        # 获取Bot Token
        while true; do
            read -p "Bot Token: " BOT_TOKEN
            
            if [ -n "$BOT_TOKEN" ]; then
                # 简单验证Bot Token格式
                if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
                    print_message $GREEN "✅ Bot Token格式正确"
                    break
                else
                    print_message $RED "❌ Bot Token格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
                fi
            else
                print_message $RED "❌ Bot Token不能为空"
            fi
        done
        
        # 确认Bot Token
        echo
        print_message $BLUE "📋 您输入的Bot Token: $BOT_TOKEN"
        read -p "确认Bot Token正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Bot Token已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Bot Token"
        fi
    done
    
    # 配置Chat ID
    while true; do
        echo
        print_message $CYAN "请输入管理员的Chat ID (可通过 @userinfobot 获取):"
        print_message $YELLOW "💡 提示: 在Telegram中搜索 @userinfobot，发送任意消息获取ID"
        
        # 获取Chat ID
        while true; do
            read -p "Chat ID: " CHAT_ID
            
            if [ -n "$CHAT_ID" ]; then
                # 简单验证Chat ID格式
                if [[ "$CHAT_ID" =~ ^[0-9]+$ ]] || [[ "$CHAT_ID" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
                    print_message $GREEN "✅ Chat ID格式正确"
                    break
                else
                    print_message $RED "❌ Chat ID格式不正确，请检查后重新输入"
                    print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
                fi
            else
                print_message $RED "❌ Chat ID不能为空"
            fi
        done
        
        # 确认Chat ID
        echo
        print_message $BLUE "📋 您输入的Chat ID: $CHAT_ID"
        read -p "确认Chat ID正确吗? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $GREEN "✅ Chat ID已确认"
            break
        else
            print_message $YELLOW "⚠️ 请重新输入Chat ID"
        fi
    done
    
    # 最终确认
    echo
    print_message $BLUE "📋 配置信息确认:"
    print_message $CYAN "Bot Token: $BOT_TOKEN"
    print_message $CYAN "Chat ID: $CHAT_ID"
    echo
    read -p "确认保存配置吗? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $YELLOW "⚠️ 配置已取消"
        return 1
    fi
    
    # 创建.env文件
    cat > "$ENV_FILE" << EOF
BOT_TOKEN=$BOT_TOKEN
CHAT_ID=$CHAT_ID
EOF
    
    print_message $GREEN "✅ 环境配置已保存到 .env 文件"
    return 0
}

# 检查机器人状态（智能检测）
check_bot_status() {
    # 🔧 智能状态检测：优先检查实际运行的进程
    local running_bots=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    if [ -n "$running_bots" ]; then
        # 有bot进程在运行，同步PID文件
        local first_pid=$(echo "$running_bots" | head -1)
        echo "$first_pid" > "$PID_FILE" 2>/dev/null || true
        echo "running"
        return 0
    fi
    
    # 如果没有实际进程，检查PID文件
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            # 使用多种方法检查进程是否存在
            if ps -p $pid > /dev/null 2>&1; then
                echo "running"
                return 0
            elif kill -0 $pid 2>/dev/null; then
                echo "running"
                return 0
            else
                # PID文件中的进程已不存在，清理无效文件
                rm -f "$PID_FILE" 2>/dev/null || true
                echo "stopped"
                return 0
            fi
        else
            echo "stopped"
            return 0
        fi
    else
        echo "stopped"
        return 0
    fi
}

# 🎯 智能启动机器人（不强制重启已运行的实例）
start_bot() {
    start_bot_with_mode "smart"
    return $?
}

# 🔄 强制启动机器人（会重启已运行的实例）
force_start_bot() {
    start_bot_with_mode "force"
    return $?
}

# 🔧 核心启动函数，支持不同模式
# 模式说明：
# - smart: 智能启动，如果已有机器人运行则不重启（用于菜单[1]、fn-bot进入、自动检测修复）
# - force: 强制启动，会杀死已有机器人进程（用于重启操作、自动监控重启、故障修复）
start_bot_with_mode() {
    local mode="${1:-smart}"  # smart | force
    
    print_message $BLUE "🚀 启动机器人..."
    
    # 检查配置是否完成
    if [ ! -f "$ENV_FILE" ]; then
        print_message $RED "❌ 请先配置Bot Token和Chat ID"
        print_message $YELLOW "请选择选项 [c] 进行配置"
        return 1
    fi
    
    # 检查是否有机器人在运行
    local running_bots=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
    
    if [ -n "$running_bots" ]; then
        case $mode in
            "smart")
                print_message $GREEN "✅ 检测到机器人已在运行 (PID: $running_bots)"
                
                # 验证PID文件是否与实际进程一致
                local first_pid=$(echo "$running_bots" | head -1)
                echo "$first_pid" > "$PID_FILE"
                
                print_message $CYAN "💡 机器人已在后台运行，无需重复启动"
                print_message $CYAN "💡 如需重启机器人，请使用选项 [r] 重启"
                return 0
                ;;
            "force")
                print_message $YELLOW "🔄 强制重启模式：停止现有进程..."
                
                # 强制清理现有进程
                echo "$running_bots" | while read -r pid; do
                    if [ -n "$pid" ]; then
                        print_message $CYAN "   💥 停止进程 PID: $pid"
                        kill $pid 2>/dev/null || true
                    fi
                done
                sleep 3
                
                # 强制清理残留进程
                local remaining_bots=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
                if [ -n "$remaining_bots" ]; then
                    print_message $YELLOW "🔄 强制清理残留进程..."
                    echo "$remaining_bots" | while read -r pid; do
                        if [ -n "$pid" ]; then
                            kill -9 $pid 2>/dev/null || true
                        fi
                    done
                fi
                
                # 清理文件
                rm -f "$PID_FILE"
                print_message $GREEN "✅ 进程清理完成"
                ;;
        esac
    fi
    
    # 启动新的机器人实例
    print_message $YELLOW "🔄 正在启动新的机器人实例..."
    
    # 清理可能存在的无效PID文件
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$old_pid" ] && ! ps -p $old_pid > /dev/null 2>&1; then
            print_message $YELLOW "🧹 清理无效的PID文件..."
            rm -f "$PID_FILE"
        fi
    fi
    sleep 2
    
    # 切换到项目目录
    cd "$PROJECT_DIR"
    
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    if [ -d "$venv_dir" ]; then
        print_message $BLUE "🐍 检测到虚拟环境，正在激活..."
        source "$venv_dir/bin/activate"
        # 验证并设置正确的Python命令
        if [ -x "$venv_dir/bin/python" ]; then
            PYTHON_CMD="$venv_dir/bin/python"
        elif [ -x "$venv_dir/bin/python3" ]; then
            PYTHON_CMD="$venv_dir/bin/python3"
        elif command -v python &> /dev/null; then
            PYTHON_CMD="python"
        else
            PYTHON_CMD="python3"
        fi
        print_message $GREEN "✅ 虚拟环境已激活，Python命令: $PYTHON_CMD"
    fi
    
    # 检查依赖
    print_message $YELLOW "🔄 检查依赖..."
    if ! $PYTHON_CMD -c "import telegram, dotenv, Crypto" 2>/dev/null; then
        print_message $YELLOW "⚠️ 依赖不完整，正在重新安装..."
        install_dependencies
    else
        print_message $GREEN "✅ 依赖检查通过"
    fi
    
    # 创建日志目录（如果不存在）
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # 启动机器人（后台运行，脱离终端，实时日志记录）
    print_message $YELLOW "🔄 正在启动机器人到后台..."
    print_message $CYAN "💡 日志将实时记录到: $LOG_FILE"
    
    # 启动前最后检查是否有冲突进程
    local conflicting_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$conflicting_pids" ]; then
        print_message $YELLOW "⚠️ 启动前发现冲突进程，正在清理..."
        echo "$conflicting_pids" | while read -r cpid; do
            if [ -n "$cpid" ]; then
                kill -9 $cpid 2>/dev/null || true
            fi
        done
        sleep 2
    fi
    
    # 使用nohup启动，并实时记录日志
    nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # 保存PID
    echo $pid > "$PID_FILE"
    
    # 等待一下检查是否启动成功
    sleep 3
    if ps -p $pid > /dev/null 2>&1; then
        print_message $GREEN "✅ 机器人启动成功 (PID: $pid)"
        print_message $CYAN "💡 机器人已在后台运行，即使退出脚本也会继续运行"
        print_message $CYAN "💡 使用 'fn-bot' 命令可以随时管理机器人"
        print_message $CYAN "📋 实时日志文件: $LOG_FILE"
        
        # 显示启动日志
        echo
        print_message $CYAN "启动日志预览:"
        if [ -f "$LOG_FILE" ]; then
            tail -n 5 "$LOG_FILE" 2>/dev/null || print_message $YELLOW "暂无日志"
        else
            print_message $YELLOW "日志文件尚未创建"
        fi
        
        # 提示用户如何查看实时日志
        echo
        print_message $YELLOW "💡 查看实时日志的方法:"
        print_message $CYAN "  1. 使用菜单选项 [3] 查看实时日志"
        print_message $CYAN "  2. 直接运行: tail -f $LOG_FILE"
        print_message $CYAN "  3. 查看错误: grep -i error $LOG_FILE"
        
    else
        print_message $RED "❌ 机器人启动失败"
        print_message $YELLOW "请检查日志文件: $LOG_FILE"
        rm -f "$PID_FILE"
        
        # 显示错误日志
        if [ -f "$LOG_FILE" ]; then
            echo
            print_message $RED "错误日志:"
            tail -n 10 "$LOG_FILE"
        fi
        
        # 提供故障排除建议
        echo
        print_message $YELLOW "🔧 故障排除建议:"
        print_message $CYAN "  1. 检查Bot Token和Chat ID是否正确"
        print_message $CYAN "  2. 检查网络连接是否正常"
        print_message $CYAN "  3. 检查依赖是否完整安装"
        print_message $CYAN "  4. 查看完整日志: cat $LOG_FILE"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 停止机器人
# 🔄 重启机器人（推荐方式：先停止再启动）
restart_bot() {
    print_message $BLUE "🔄 重启机器人..."
    
    # 先停止现有进程
    print_message $YELLOW "🛑 停止现有机器人进程..."
    stop_bot_with_cleanup
    
    # 等待一下确保进程完全停止
    sleep 2
    
    # 然后智能启动新进程
    start_bot
}

# 🔧 强制重启函数：彻底清理所有bot进程，避免多实例冲突
force_restart_bot() {
    print_message $BLUE "🔄 强制重启机器人..."
    force_start_bot
}

stop_bot() {
    print_message $BLUE "🛑 停止机器人..."
    
    # 🔧 使用强化的停止逻辑
    print_message $YELLOW "🔄 强制停止所有bot进程..."
    
    # 方法1：通过PID文件停止
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            print_message $YELLOW "🔄 停止PID文件中的进程 (PID: $pid)..."
            kill $pid 2>/dev/null || true
            sleep 3
            if ps -p $pid > /dev/null 2>&1; then
                print_message $YELLOW "🔄 强制停止进程 (PID: $pid)..."
                kill -9 $pid 2>/dev/null || true
            fi
        fi
    fi
    
    # 方法2：停止所有bot.py进程
    local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$bot_pids" ]; then
        print_message $YELLOW "🔄 清理所有bot相关进程..."
        echo "$bot_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $YELLOW "   停止进程 PID: $pid"
                kill $pid 2>/dev/null || true
            fi
        done
        sleep 3
        
        # 强制停止残留进程
        bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
        if [ -n "$bot_pids" ]; then
            print_message $YELLOW "🔄 强制停止残留进程..."
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
        rm -f "$PID_FILE"
    
    # 验证是否完全停止
    local remaining_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$remaining_pids" ]; then
        print_message $RED "❌ 仍有进程未停止"
        print_message $YELLOW "残留进程: $remaining_pids"
    else
        print_message $GREEN "✅ 所有bot进程已停止"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 查看实时日志
view_logs() {
    print_message $BLUE "📋 日志查看选项..."
    
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ 日志文件不存在"
        return
    fi
    
    echo
    print_message $CYAN "请选择日志查看方式:"
    echo -e "${CYAN}[1] 实时日志 (tail -f)${NC}"
    echo -e "${CYAN}[2] 查看最后50行${NC}"
    echo -e "${CYAN}[3] 查看最后100行${NC}"
    echo -e "${CYAN}[4] 查看全部日志${NC}"
    echo -e "${CYAN}[5] 搜索错误日志${NC}"
    echo -e "${CYAN}[0] 返回${NC}"
    echo
    
    read -p "请选择 [0-5]: " log_choice
    
    case $log_choice in
        1)
            print_message $BLUE "📋 实时日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示实时日志，按任意键返回主菜单..."
            echo
            # 使用更可靠的方法：先显示一些日志，然后等待按键
            tail -n 10 "$LOG_FILE" 2>/dev/null
            echo
            print_message $CYAN "=== 实时日志开始 ==="
            print_message $YELLOW "按任意键返回主菜单..."
            # 启动tail -f在后台，但限制输出行数避免阻塞
            timeout 30 tail -f "$LOG_FILE" 2>/dev/null &
            TAIL_PID=$!
            # 等待用户按键
            read -n 1 -s
            # 立即停止tail进程
            kill $TAIL_PID 2>/dev/null
            wait $TAIL_PID 2>/dev/null
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        2)
            print_message $BLUE "📋 最后50行日志（任意键返回主菜单）..."
            tail -n 50 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        3)
            print_message $BLUE "📋 最后100行日志（任意键返回主菜单）..."
            tail -n 100 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        4)
            print_message $BLUE "📋 全部日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示全部日志，按任意键返回主菜单..."
            echo
            # 使用less或more来分页显示，但提供退出选项
            if command -v less &> /dev/null; then
                less -R "$LOG_FILE"
            elif command -v more &> /dev/null; then
                more "$LOG_FILE"
            else
                cat "$LOG_FILE" 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
            fi
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        5)
            print_message $BLUE "📋 搜索错误日志（任意键返回主菜单）..."
            echo -e "${RED}错误信息:${NC}"
            grep -i "error\|exception\|traceback\|failed\|critical" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        6)
            print_message $BLUE "📋 搜索警告日志（任意键返回主菜单）..."
            echo -e "${YELLOW}警告信息:${NC}"
            grep -i "warning\|warn" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        7)
            print_message $BLUE "📋 搜索特定关键词（任意键返回主菜单）..."
            read -p "请输入搜索关键词: " keyword
            if [ -n "$keyword" ]; then
                print_message $BLUE "📋 搜索结果:"
                echo
                grep -i "$keyword" "$LOG_FILE" | tail -n 20 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
                echo
                print_message $CYAN "已返回主菜单"
            else
                print_message $RED "❌ 关键词不能为空"
                read -p "按任意键继续..." -n 1 -r
                echo
            fi
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
    esac
}

# 检查进程状态
check_process() {
    print_message $BLUE "🔍 检查进程状态..."
    
    # 直接测试状态检测函数
    print_message $CYAN "=== 状态检测调试信息 ==="
    local status=$(check_bot_status)
    print_message $CYAN "check_bot_status() 返回值: '$status'"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        print_message $CYAN "PID文件内容: '$pid'"
        
        if [ -n "$pid" ]; then
            print_message $CYAN "检查进程 $pid 是否存在..."
            
            # 使用多种方法检查进程
            if ps -p $pid > /dev/null 2>&1; then
                print_message $GREEN "✅ ps -p 检测到进程存在"
            else
                print_message $YELLOW "⚠️ ps -p 未检测到进程"
            fi
            
            if kill -0 $pid 2>/dev/null; then
                print_message $GREEN "✅ kill -0 检测到进程存在"
            else
                print_message $YELLOW "⚠️ kill -0 未检测到进程"
            fi
            
            # 显示进程详细信息
            echo
            print_message $CYAN "进程详细信息:"
            ps -p $pid -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || print_message $YELLOW "无法获取进程信息"
        else
            print_message $YELLOW "⚠️ PID文件为空"
        fi
    else
        print_message $YELLOW "⚠️ PID文件不存在"
    fi
    
    # 检查所有python进程
    echo
    print_message $CYAN "所有Python进程:"
    ps aux | grep python | grep -v grep || print_message $YELLOW "未找到Python进程"
    
    # 根据状态检测结果显示最终结论
    echo
    print_message $CYAN "=== 最终状态结论 ==="
    if [ "$status" = "running" ]; then
        print_message $GREEN "✅ 机器人状态: 正在运行"
    else
        print_message $YELLOW "⚠️ 机器人状态: 未运行"
    fi
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 检查更新
check_updates() {
    print_message $BLUE "🔄 检查更新..."
    
    # 检查是否为Git仓库
    if [ ! -d ".git" ]; then
        print_message $YELLOW "⚠️ 当前目录不是Git仓库，正在重新克隆..."
        cd "$PROJECT_DIR"
        
        # 备份配置文件
        local env_backup=""
        if [ -f "$ENV_FILE" ]; then
            env_backup="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            print_message $BLUE "🔄 备份配置文件: $env_backup"
            cp "$ENV_FILE" "$env_backup"
        fi
        
        # 备份现有文件
        if [ -f "bot.py" ] || [ -f "py.py" ]; then
            local backup_dir="$PROJECT_DIR.backup.$(date +%Y%m%d_%H%M%S)"
            print_message $YELLOW "🔄 备份现有文件到: $backup_dir"
            mkdir -p "$backup_dir"
            cp -r * "$backup_dir/" 2>/dev/null || true
        fi
        
        # 重新克隆仓库
        print_message $BLUE "🔄 正在重新克隆仓库..."
        rm -rf .git 2>/dev/null || true
        git init
        git remote add origin "$GITHUB_REPO"
        git fetch origin
        
        # 尝试检测默认分支
        local default_branch="main"
        if git ls-remote --heads origin main | grep -q main; then
            default_branch="main"
        elif git ls-remote --heads origin master | grep -q master; then
            default_branch="master"
        else
            # 获取默认分支
            default_branch=$(git ls-remote --symref origin HEAD | head -n1 | cut -d/ -f3)
        fi
        
        print_message $CYAN "检测到默认分支: $default_branch"
        git checkout -f origin/$default_branch
        
        if [ $? -eq 0 ]; then
            print_message $GREEN "✅ 仓库同步完成"
            
            # 恢复配置文件
            if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                print_message $BLUE "🔄 恢复配置文件..."
                cp "$env_backup" "$ENV_FILE"
                print_message $GREEN "✅ 配置文件已恢复"
                rm -f "$env_backup"
            fi
            
            chmod +x start.sh
            return 0
        else
            print_message $RED "❌ 仓库同步失败"
            
            # 恢复配置文件（即使同步失败）
            if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                print_message $BLUE "🔄 恢复配置文件..."
                cp "$env_backup" "$ENV_FILE"
                print_message $GREEN "✅ 配置文件已恢复"
                rm -f "$env_backup"
            fi
            
            return 1
        fi
    fi
    
    # 检查网络连接
    print_message $BLUE "🌐 检查网络连接..."
    if ! ping -c 1 github.com > /dev/null 2>&1; then
        print_message $RED "❌ 无法连接到GitHub，请检查网络连接"
        return 1
    fi
    print_message $GREEN "✅ 网络连接正常"
    
    # 获取远程更新
    print_message $BLUE "📡 正在连接GitHub获取更新信息..."
    git fetch origin
    
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 无法获取远程更新"
        return 1
    fi
    print_message $GREEN "✅ 成功连接到GitHub"
    
    # 检测当前分支和远程分支
    local current_branch=$(git branch --show-current)
    local remote_branch=""
    
    # 尝试检测远程分支
    if git ls-remote --heads origin main | grep -q main; then
        remote_branch="main"
    elif git ls-remote --heads origin master | grep -q master; then
        remote_branch="master"
    else
        remote_branch="main"  # 默认使用main
    fi
    
    print_message $CYAN "当前分支: $current_branch"
    print_message $CYAN "远程分支: $remote_branch"
    
    # 检查是否有更新
    print_message $BLUE "🔍 正在检测GitHub文件更新..."
    local behind=$(git rev-list HEAD..origin/$remote_branch --count 2>/dev/null || echo "0")
    local ahead=$(git rev-list origin/$remote_branch..HEAD --count 2>/dev/null || echo "0")
    
    print_message $CYAN "本地落后远程: $behind 个提交"
    print_message $CYAN "本地领先远程: $ahead 个提交"
    
    if [ "$behind" -gt 0 ]; then
        print_message $YELLOW "🆕 检测到GitHub有更新！"
        print_message $CYAN "发现 $behind 个新提交"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $CYAN "最新版本: $(git rev-parse --short origin/$remote_branch)"
        
        # 显示更新内容
        echo
        print_message $CYAN "📋 更新内容预览:"
        git log --oneline HEAD..origin/$remote_branch --max-count=5
        
        echo
        print_message $YELLOW "⚠️ 注意：更新操作需要用户手动确认"
        read -p "是否下载并安装更新? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 再次确认
            print_message $RED "⚠️ 确认更新操作"
            read -p "此操作将覆盖本地文件，确认继续? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_message $YELLOW "⏭️ 跳过更新"
                read -p "按任意键返回..." -n 1 -r
                echo
                return
            fi
            
            # 停止机器人（如果正在运行）
            local status=$(check_bot_status)
            if [ "$status" = "running" ]; then
                print_message $YELLOW "🔄 正在停止机器人以进行更新..."
                stop_bot
                sleep 2
            fi
            
            # 备份配置文件
            local env_backup=""
            if [ -f "$ENV_FILE" ]; then
                env_backup="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
                print_message $BLUE "🔄 备份配置文件: $env_backup"
                cp "$ENV_FILE" "$env_backup"
            fi
            
            # 执行更新
            print_message $BLUE "📥 正在下载更新文件..."
            
            # 获取更新前的文件状态
            local updated_files=$(git diff --name-only HEAD origin/$remote_branch 2>/dev/null || echo "")
            
            git reset --hard origin/$remote_branch
            
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 更新文件下载完成"
                print_message $GREEN "✅ 更新安装完成"
                
                # 显示更新的文件列表
                if [ -n "$updated_files" ]; then
                    echo
                    print_message $CYAN "📋 此次更新内容:"
                    echo "$updated_files" | while read -r file; do
                        if [ -n "$file" ]; then
                            print_message $WHITE "  • $file"
                        fi
                    done
                else
                    print_message $CYAN "📋 此次更新内容: 所有文件已同步到最新版本"
                fi
                
                # 恢复配置文件
                if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                    print_message $BLUE "🔄 恢复配置文件..."
                    cp "$env_backup" "$ENV_FILE"
                    print_message $GREEN "✅ 配置文件已恢复"
                    
                    # 清理备份文件
                    rm -f "$env_backup"
                fi
                
                # 重新安装依赖（以防requirements.txt有更新）
                print_message $YELLOW "🔄 检查依赖更新..."
                install_dependencies
                
                # 如果机器人之前在运行，询问是否重启
                if [ "$status" = "running" ]; then
                    echo
                    read -p "是否重启机器人? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        start_bot
                    fi
                fi
            else
                print_message $RED "❌ 更新下载失败"
                
                # 恢复配置文件（即使更新失败）
                if [ -n "$env_backup" ] && [ -f "$env_backup" ]; then
                    print_message $BLUE "🔄 恢复配置文件..."
                    cp "$env_backup" "$ENV_FILE"
                    print_message $GREEN "✅ 配置文件已恢复"
                    rm -f "$env_backup"
                fi
                
                return 1
            fi
        else
            print_message $YELLOW "⏭️ 跳过更新"
            read -p "按任意键返回..." -n 1 -r
            echo
        fi
    elif [ "$ahead" -gt 0 ]; then
        print_message $YELLOW "⚠️ 本地版本领先远程版本 $ahead 个提交"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $CYAN "远程版本: $(git rev-parse --short origin/$remote_branch)"
        print_message $BLUE "💡 提示：本地版本比GitHub版本更新"
        echo
        read -p "按任意键返回..." -n 1 -r
        echo
    else
        print_message $GREEN "✅ 未检测到更新"
        print_message $CYAN "当前版本: $(git rev-parse --short HEAD)"
        print_message $BLUE "💡 提示：本地文件已是最新版本"
        echo
        read -p "按任意键返回..." -n 1 -r
        echo
    fi
}

# 验证Bot Token格式
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

# 验证Chat ID格式
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

# 发送测试消息到指定Chat ID
send_test_message() {
    local token="$1"
    local chat_id="$2"
    
    if [ -z "$token" ] || [ -z "$chat_id" ]; then
        return 1
    fi
    
    # 生成测试消息
    local test_time=$(date '+%Y-%m-%d %H:%M:%S')
    local test_message="🧪 **FinalUnlock 配置测试**

✅ Bot Token: 验证成功
✅ Chat ID: 验证成功
⏰ 测试时间: $test_time

🎉 恭喜！机器人配置正确，可以正常接收和发送消息。

💡 如果您收到这条消息，说明：
• Bot Token 有效且可以连接到 Telegram API
• Chat ID 正确且可以接收消息
• 网络连接正常

🚀 现在可以启动机器人开始使用了！"
    
    # 使用curl发送测试消息
    if command -v curl &> /dev/null; then
        local response=$(curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{
                \"chat_id\": \"$chat_id\",
                \"text\": \"$test_message\",
                \"parse_mode\": \"Markdown\"
            }" 2>/dev/null)
        
        if echo "$response" | grep -q '"ok":true'; then
            return 0
        else
            # 如果Markdown解析失败，尝试纯文本
            local simple_message="🧪 FinalUnlock 配置测试

✅ Bot Token 和 Chat ID 验证成功！
⏰ 测试时间: $test_time

🎉 恭喜！机器人配置正确，可以正常收发消息。
🚀 现在可以启动机器人开始使用了！"
            
            local response2=$(curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
                -H "Content-Type: application/json" \
                -d "{
                    \"chat_id\": \"$chat_id\",
                    \"text\": \"$simple_message\"
                }" 2>/dev/null)
            
            if echo "$response2" | grep -q '"ok":true'; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# 完整的配置验证函数
validate_configuration() {
    local config_valid=true
    local validation_log="$PROJECT_DIR/config_validation.log"
    
    print_message $BLUE "🔍 验证配置文件..."
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Starting configuration validation" > "$validation_log"
    
    # 检查.env文件是否存在
    if [ ! -f "$ENV_FILE" ]; then
        print_message $RED "❌ .env 文件不存在"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): .env file not found" >> "$validation_log"
        return 1
    fi
    
    # 安全地读取配置，避免执行任何命令
    BOT_TOKEN=$(grep "^BOT_TOKEN=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^["'\'']//' | sed 's/["'\'']$//' | tr -d '\n' | tr -d '\r')
    CHAT_ID=$(grep "^CHAT_ID=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed 's/^["'\'']//' | sed 's/["'\'']$//' | tr -d '\n' | tr -d '\r')
    
    # 验证Bot Token
    print_message $YELLOW "🔑 验证 Bot Token..."
    local token_validation=$(validate_bot_token "$BOT_TOKEN")
    case $token_validation in
        "empty")
            print_message $RED "❌ Bot Token 为空"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token is empty" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_format")
            print_message $RED "❌ Bot Token 格式无效"
            print_message $YELLOW "💡 正确格式: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token format invalid" >> "$validation_log"
            config_valid=false
            ;;
        "too_short")
            print_message $RED "❌ Bot Token 长度过短"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token too short" >> "$validation_log"
            config_valid=false
            ;;
        "valid")
            print_message $GREEN "✅ Bot Token 格式正确"
            
            # 测试Token有效性
            print_message $YELLOW "🌐 测试 Bot Token 连接..."
            if test_bot_token "$BOT_TOKEN"; then
                print_message $GREEN "✅ Bot Token 连接测试成功"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token connection test passed" >> "$validation_log"
            else
                print_message $YELLOW "⚠️ Bot Token 连接测试失败（可能是网络问题）"
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Bot Token connection test failed" >> "$validation_log"
            fi
            ;;
    esac
    
    # 验证Chat ID
    print_message $YELLOW "👤 验证 Chat ID..."
    local chat_id_validation=$(validate_chat_id "$CHAT_ID")
    case $chat_id_validation in
        "empty")
            print_message $RED "❌ Chat ID 为空"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID is empty" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_format")
            print_message $RED "❌ Chat ID 格式无效"
            print_message $YELLOW "💡 正确格式: 123456789 或 123456789,987654321"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID format invalid" >> "$validation_log"
            config_valid=false
            ;;
        "invalid_length")
            print_message $RED "❌ Chat ID 长度无效"
            print_message $YELLOW "💡 Chat ID 应该是5-15位数字"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID length invalid" >> "$validation_log"
            config_valid=false
            ;;
        "valid")
            print_message $GREEN "✅ Chat ID 格式正确"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Chat ID format valid" >> "$validation_log"
            
            # 显示管理员数量
            IFS=',' read -ra IDS <<< "$CHAT_ID"
            local admin_count=${#IDS[@]}
            print_message $CYAN "👥 配置了 $admin_count 个管理员"
            ;;
    esac
    
    # 实际发送测试消息验证
    if [ "$config_valid" = true ]; then
        echo
        print_message $BLUE "📤 发送实际测试消息..."
        print_message $CYAN "💡 重要提醒：请确保您已经与机器人进行过至少一次对话"
        print_message $YELLOW "💡 请检查您的Telegram以确认收到测试消息"
        
        # 获取第一个Chat ID进行测试
        local first_chat_id=$(echo "$CHAT_ID" | cut -d',' -f1)
        
        if send_test_message "$BOT_TOKEN" "$first_chat_id"; then
            print_message $GREEN "✅ 测试消息发送成功！"
            print_message $CYAN "📱 请检查您的Telegram应用，应该收到了一条测试消息"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Test message sent successfully to $first_chat_id" >> "$validation_log"
            
            # 如果有多个管理员，提示
            if [ $admin_count -gt 1 ]; then
                print_message $CYAN "💡 测试消息已发送到第一个管理员 ($first_chat_id)"
                print_message $CYAN "💡 启动机器人后，所有 $admin_count 个管理员都将能够使用"
            fi
        else
            print_message $RED "❌ 测试消息发送失败"
            print_message $YELLOW "💡 最常见原因："
            print_message $RED "   🔴 您还没有与机器人开始过对话！"
            print_message $YELLOW "💡 其他可能原因："
            print_message $CYAN "   • Chat ID 不正确"
            print_message $CYAN "   • 网络连接问题"
            print_message $CYAN "   • Bot Token 权限不足"
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Test message failed to $first_chat_id" >> "$validation_log"
            
            # 提供解决建议
            echo
            print_message $BLUE "🔧 解决步骤："
            print_message $CYAN "1. 在Telegram中搜索您的机器人用户名"
            print_message $CYAN "2. 点击机器人，然后点击 'START' 按钮"
            print_message $CYAN "3. 或者直接发送 /start 命令给机器人"
            print_message $CYAN "4. 然后重新运行此配置验证"
        fi
        echo
    fi
    
    # 检查Python环境
    print_message $YELLOW "🐍 验证 Python 环境..."
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        print_message $GREEN "✅ Python 版本: $python_version"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Python version: $python_version" >> "$validation_log"
    else
        print_message $RED "❌ Python3 未安装"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Python3 not found" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查依赖包
    print_message $YELLOW "📦 验证依赖包..."
    local missing_deps=()
    
    if ! python3 -c "import telegram" 2>/dev/null; then
        missing_deps+=("python-telegram-bot")
    fi
    
    if ! python3 -c "import dotenv" 2>/dev/null; then
        missing_deps+=("python-dotenv")
    fi
    
    if ! python3 -c "import Crypto" 2>/dev/null; then
        missing_deps+=("pycryptodome")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有依赖包已安装"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): All dependencies installed" >> "$validation_log"
    else
        print_message $RED "❌ 缺少依赖包: ${missing_deps[*]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Missing dependencies: ${missing_deps[*]}" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查核心文件
    print_message $YELLOW "📁 验证核心文件..."
    local missing_files=()
    
    if [ ! -f "$PROJECT_DIR/bot.py" ]; then
        missing_files+=("bot.py")
    fi
    
    if [ ! -f "$PROJECT_DIR/py.py" ]; then
        missing_files+=("py.py")
    fi
    
    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        missing_files+=("requirements.txt")
    fi
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有核心文件存在"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): All core files present" >> "$validation_log"
    else
        print_message $RED "❌ 缺少核心文件: ${missing_files[*]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Missing core files: ${missing_files[*]}" >> "$validation_log"
        config_valid=false
    fi
    
    # 检查权限
    print_message $YELLOW "🔐 验证文件权限..."
    if [ -r "$PROJECT_DIR/bot.py" ] && [ -r "$PROJECT_DIR/py.py" ]; then
        print_message $GREEN "✅ 文件权限正常"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): File permissions OK" >> "$validation_log"
    else
        print_message $RED "❌ 文件权限不足"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Insufficient file permissions" >> "$validation_log"
        config_valid=false
    fi
    
    # 最终结果
    echo
    if [ "$config_valid" = true ]; then
        print_message $GREEN "🎉 配置验证通过！"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Configuration validation passed" >> "$validation_log"
        return 0
    else
        print_message $RED "❌ 配置验证失败，请修复上述问题"
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Configuration validation failed" >> "$validation_log"
        return 1
    fi
}

# 配置修复建议
show_config_fix_suggestions() {
    print_message $BLUE "🔧 配置修复建议:"
    echo
    
    print_message $YELLOW "1. Bot Token 问题:"
    print_message $CYAN "   • 访问 @BotFather 创建新机器人"
    print_message $CYAN "   • 发送 /newbot 命令"
    print_message $CYAN "   • 按提示设置机器人名称"
    print_message $CYAN "   • 复制获得的 Token"
    echo
    
    print_message $YELLOW "2. Chat ID 问题:"
    print_message $CYAN "   • 访问 @userinfobot"
    print_message $CYAN "   • 发送任意消息获取您的 Chat ID"
    print_message $CYAN "   • 多个管理员用逗号分隔"
    echo
    
    print_message $YELLOW "3. 依赖包问题:"
    print_message $CYAN "   • 运行: pip install -r requirements.txt"
    print_message $CYAN "   • 或使用菜单选项 [6] 检查依赖"
    echo
    
    print_message $YELLOW "4. 文件权限问题:"
    print_message $CYAN "   • 运行: chmod +x start.sh"
    print_message $CYAN "   • 确保有读取权限: chmod 644 *.py"
    echo
}

# 自动修复配置
auto_fix_config() {
    print_message $BLUE "🔧 尝试自动修复配置..."
    
    # 修复文件权限
    print_message $YELLOW "🔐 修复文件权限..."
    chmod +x "$PROJECT_DIR/start.sh" 2>/dev/null
    chmod 644 "$PROJECT_DIR"/*.py 2>/dev/null
    chmod 644 "$PROJECT_DIR"/*.txt 2>/dev/null
    print_message $GREEN "✅ 文件权限已修复"
    
    # 尝试安装缺少的依赖
    print_message $YELLOW "📦 检查并安装依赖..."
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        if command -v pip3 &> /dev/null; then
            pip3 install -r "$PROJECT_DIR/requirements.txt" --user
            print_message $GREEN "✅ 依赖安装完成"
        else
            print_message $YELLOW "⚠️ pip3 未找到，请手动安装依赖"
        fi
    fi
    
    # 创建必要的目录
    mkdir -p "$PROJECT_DIR/logs" 2>/dev/null
    mkdir -p "$PROJECT_DIR/backups" 2>/dev/null
    
    print_message $GREEN "✅ 自动修复完成"
}

# 检查依赖
check_dependencies() {
    print_message $BLUE "🔍 检查依赖..."
    
    local missing_deps=()
    local version_info=()
    
    # 检查主要依赖
    if ! $PYTHON_CMD -c "import telegram" 2>/dev/null; then
        missing_deps+=("python-telegram-bot")
    else
        local version=$($PYTHON_CMD -c "import telegram; print(telegram.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("python-telegram-bot: $version")
    fi
    
    if ! $PYTHON_CMD -c "import dotenv" 2>/dev/null; then
        missing_deps+=("python-dotenv")
    else
        local version=$($PYTHON_CMD -c "import dotenv; print(dotenv.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("python-dotenv: $version")
    fi
    
    if ! $PYTHON_CMD -c "import Crypto" 2>/dev/null; then
        missing_deps+=("pycryptodome")
    else
        local version=$($PYTHON_CMD -c "import Crypto; print(Crypto.__version__)" 2>/dev/null || echo "未知版本")
        version_info+=("pycryptodome: $version")
    fi
    
    # 显示检查结果
    echo
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 所有依赖已安装"
        echo
        print_message $CYAN "已安装的依赖版本:"
        for info in "${version_info[@]}"; do
            echo -e "  ${CYAN}• $info${NC}"
        done
    else
        print_message $YELLOW "⚠️ 发现缺失依赖: ${missing_deps[*]}"
        echo
        print_message $CYAN "已安装的依赖版本:"
        for info in "${version_info[@]}"; do
            echo -e "  ${CYAN}• $info${NC}"
        done
        echo
        print_message $YELLOW "缺失的依赖:"
        for dep in "${missing_deps[@]}"; do
            echo -e "  ${RED}• $dep${NC}"
        done
        echo
        read -p "是否安装缺失的依赖? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_dependencies
        fi
    fi
    
    # 检查Python版本
    echo
    print_message $CYAN "Python环境信息:"
    echo -e "  ${CYAN}• Python版本: $($PYTHON_CMD --version)${NC}"
    echo -e "  ${CYAN}• Python路径: $(which $PYTHON_CMD)${NC}"
    echo -e "  ${CYAN}• pip版本: $($PIP_CMD --version)${NC}"
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 重新安装依赖
reinstall_dependencies() {
    print_message $BLUE "🔄 重新安装依赖..."
    
    print_message $YELLOW "⚠️ 这将卸载并重新安装所有依赖"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    # 卸载现有依赖
    print_message $YELLOW "🔄 卸载现有依赖..."
    $PIP_CMD uninstall -y python-telegram-bot python-dotenv pycryptodome
    
    # 重新安装
    install_dependencies
    
    echo
    read -p "按任意键返回..." -n 1 -r
    echo
}

# 检查虚拟环境
check_venv() {
    while true; do
    print_message $BLUE "🔍 检查虚拟环境..."
    
    echo
    if [ -n "$VIRTUAL_ENV" ]; then
        print_message $GREEN "✅ 正在使用虚拟环境"
        echo -e "  ${CYAN}• 虚拟环境路径: $VIRTUAL_ENV${NC}"
        echo -e "  ${CYAN}• 虚拟环境名称: $(basename "$VIRTUAL_ENV")${NC}"
    else
        print_message $YELLOW "⚠️ 未使用虚拟环境"
        echo -e "  ${YELLOW}• 当前使用系统Python${NC}"
    fi
    
    # 检查是否有虚拟环境目录
    if [ -d "venv" ]; then
        echo
        print_message $CYAN "发现本地虚拟环境目录: venv/"
        read -p "是否激活本地虚拟环境? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_message $BLUE "🔄 激活虚拟环境..."
            source venv/bin/activate
            print_message $GREEN "✅ 虚拟环境已激活"
            print_message $CYAN "请重新运行脚本以使用虚拟环境"
                read -p "按任意键返回..." -n 1 -r
                echo
            return
        fi
    fi
    
    echo
    print_message $CYAN "虚拟环境选项:"
    echo -e "${CYAN}[1] 创建新的虚拟环境${NC}"
    echo -e "${CYAN}[2] 删除现有虚拟环境${NC}"
    echo -e "${CYAN}[3] 重新创建虚拟环境${NC}"
        echo -e "${CYAN}[0] 返回主菜单${NC}"
    echo
    
    read -p "请选择 [0-3]: " venv_choice
    
    case $venv_choice in
        1)
            if [ -d "venv" ]; then
                print_message $YELLOW "⚠️ 虚拟环境已存在"
                read -p "是否覆盖? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return
                fi
                rm -rf venv
            fi
            print_message $BLUE "🔄 创建虚拟环境..."
            $PYTHON_CMD -m venv venv
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 虚拟环境创建成功"
                print_message $CYAN "激活命令: source venv/bin/activate"
            else
                print_message $RED "❌ 虚拟环境创建失败"
            fi
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
        2)
            if [ -d "venv" ]; then
                print_message $YELLOW "⚠️ 确认删除虚拟环境?"
                read -p "此操作不可逆 (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rm -rf venv
                    print_message $GREEN "✅ 虚拟环境已删除"
                fi
            else
                print_message $YELLOW "⚠️ 虚拟环境不存在"
            fi
            read -p "按任意键返回..." -n 1 -r
            echo
            ;;
        3)
            print_message $BLUE "🔄 重新创建虚拟环境..."
            rm -rf venv 2>/dev/null || true
            $PYTHON_CMD -m venv venv
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 虚拟环境重新创建成功"
                print_message $CYAN "激活命令: source venv/bin/activate"
            else
                print_message $RED "❌ 虚拟环境创建失败"
            fi
            read -p "按任意键继续..." -n 1 -r
            echo
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            read -p "按任意键继续..." -n 1 -r
            echo
            ;;
    esac
    done
}

# 卸载Python依赖
uninstall_dependencies() {
    print_message $BLUE "📦 卸载FinalUnlock项目依赖..."
    
    # 初始化Python命令
    if [ -z "$PYTHON_CMD" ]; then
        if command -v python3 &> /dev/null; then
            PYTHON_CMD="python3"
        elif command -v python &> /dev/null; then
            PYTHON_CMD="python"
        else
            print_message $RED "❌ 未找到Python环境"
            return 1
        fi
    fi
    
    # 读取requirements.txt中的依赖
    if [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
        print_message $YELLOW "⚠️ 未找到requirements.txt文件"
        return 1
    fi
    
    print_message $YELLOW "📋 将要卸载以下依赖包:"
    while read -r line; do
        if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
            # 提取包名（去除版本号）
            package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
            print_message $CYAN "  • $package_name"
        fi
    done < "$PROJECT_DIR/requirements.txt"
    
    echo
    read -p "确认卸载这些依赖包? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_message $YELLOW "❌ 取消卸载依赖"
        return 0
    fi
    
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    local use_venv=false
    
    if [ -d "$venv_dir" ]; then
        print_message $BLUE "🐍 检测到虚拟环境，将从虚拟环境中卸载依赖"
        source "$venv_dir/bin/activate"
        use_venv=true
        PIP_CMD="pip"
    else
        print_message $BLUE "🌐 将从系统Python环境中卸载依赖"
        # 使用系统pip命令
        if command -v pip3 &> /dev/null; then
            PIP_CMD="pip3"
        elif command -v pip &> /dev/null; then
            PIP_CMD="pip"
        elif $PYTHON_CMD -m pip --version &> /dev/null; then
            PIP_CMD="$PYTHON_CMD -m pip"
        else
            print_message $RED "❌ 未找到可用的pip命令"
            return 1
        fi
    fi
    
    # 卸载依赖
    print_message $YELLOW "🔄 正在卸载依赖包..."
    local uninstalled_count=0
    local failed_count=0
    
    while read -r line; do
        if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
            # 提取包名（去除版本号）
            package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
            
            print_message $CYAN "🔄 卸载 $package_name..."
            if $PIP_CMD uninstall -y "$package_name" > /dev/null 2>&1; then
                print_message $GREEN "✅ $package_name 卸载成功"
                ((uninstalled_count++))
            else
                print_message $YELLOW "⚠️ $package_name 卸载失败或未安装"
                ((failed_count++))
            fi
        fi
    done < "$PROJECT_DIR/requirements.txt"
    
    echo
    print_message $BLUE "📊 卸载结果统计:"
    print_message $GREEN "✅ 成功卸载: $uninstalled_count 个包"
    if [ $failed_count -gt 0 ]; then
        print_message $YELLOW "⚠️ 失败/未安装: $failed_count 个包"
    fi
    
    # 如果使用虚拟环境，提示删除虚拟环境
    if [ "$use_venv" = true ]; then
        echo
        read -p "是否同时删除虚拟环境目录? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            deactivate 2>/dev/null || true
            rm -rf "$venv_dir"
            print_message $GREEN "✅ 虚拟环境已删除"
        fi
    fi
    
    print_message $GREEN "✅ 依赖卸载完成"
}

# 完整卸载机器人（包含依赖卸载）
uninstall_bot() {
    print_message $BLUE "🗑️ 完整卸载FinalUnlock机器人..."
    
    print_message $RED "⚠️ 这将执行以下操作:"
    print_message $RED "   • 停止机器人和Guard进程"
    print_message $RED "   • 删除所有FinalUnlock相关目录和文件"
    print_message $RED "   • 卸载requirements.txt中的Python依赖包"
    print_message $RED "   • 删除全局命令和快捷方式"
    print_message $RED "⚠️ 此操作不可逆，请谨慎操作！"
    echo
    
    print_message $YELLOW "请选择卸载方式:"
    print_message $CYAN "[1] 完整卸载（包括Python依赖）"
    print_message $CYAN "[2] 仅删除项目文件（保留Python依赖）"
    print_message $CYAN "[0] 取消卸载"
    echo
    
    read -p "请选择 [0-2]: " uninstall_choice
    
    case $uninstall_choice in
        1)
            print_message $BLUE "🔄 选择完整卸载模式"
            echo
            read -p "确认完整卸载？(yes/no): " confirm
            
            if [ "$confirm" != "yes" ] && [ "$confirm" != "YES" ] && [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_message $YELLOW "❌ 取消卸载操作"
        return
    fi
    
            # 先卸载Python依赖
            uninstall_dependencies
            echo
            
            # 然后删除项目文件
            uninstall_project_files
            
            # 卸载完成后直接退出
            print_message $GREEN "👋 FinalUnlock已完全卸载"
            emergency_exit
            ;;
        2)
            print_message $BLUE "🔄 选择仅删除项目文件模式"
            echo
            read -p "请输入 'DELETE' 确认删除项目文件: " confirm
            
            if [ "$confirm" != "DELETE" ]; then
                print_message $YELLOW "❌ 取消卸载操作"
                return
            fi
            
            # 仅删除项目文件
            uninstall_project_files
            
            # 删除完成后直接退出
            print_message $GREEN "👋 项目文件已删除"
            emergency_exit
            ;;
        0)
            print_message $YELLOW "❌ 取消卸载操作"
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            return
            ;;
    esac
}

# 删除项目文件
uninstall_project_files() {
    print_message $BLUE "🗑️ 删除项目文件..."
    
    # 🔧 彻底停止所有bot和guard进程 - 使用统一的强制清理逻辑
    print_message $YELLOW "🛑 彻底停止所有相关进程..."
    
    # === 🔥 强制清理bot进程（使用kill -9）===
    print_message $YELLOW "🔄 强制清理bot进程..."
    
    # 方法1：通过PID文件强制停止
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            print_message $CYAN "   💥 强制停止PID文件中的进程 (PID: $pid)"
            kill -9 $pid 2>/dev/null || true
        fi
    fi
    
    # 方法2：强制停止所有bot.py进程
    local bot_pids=$(pgrep -f "python.*bot.py" 2>/dev/null || true)
    if [ -n "$bot_pids" ]; then
        print_message $CYAN "   发现bot进程，正在强制清理..."
        echo "$bot_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "     💥 强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 方法3：pkill强制清理
    pkill -9 -f "bot.py" 2>/dev/null || true
    
    # === 🔥 强制清理guard进程（使用kill -9）===
    print_message $YELLOW "🔄 强制清理guard进程..."
    
    # 方法1：通过PID文件强制停止
    if [ -f "$PROJECT_DIR/guard.pid" ]; then
        local guard_pid=$(cat "$PROJECT_DIR/guard.pid" 2>/dev/null)
        if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
            print_message $CYAN "   💥 强制停止guard进程 (PID: $guard_pid)"
            kill -9 $guard_pid 2>/dev/null || true
        fi
    fi
    
    # 方法2：强制停止所有guard.py进程
    local guard_pids=$(pgrep -f "python.*guard.py" 2>/dev/null || true)
    if [ -n "$guard_pids" ]; then
        print_message $CYAN "   发现guard进程，正在强制清理..."
        echo "$guard_pids" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_message $CYAN "     💥 强制停止进程 PID: $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
    fi
    
    # 方法3：pkill强制清理
    pkill -9 -f "guard.py" 2>/dev/null || true
    
    # === 🔥 强制清理监控进程（使用kill -9）===
    if [ -f "$PROJECT_DIR/monitor.pid" ]; then
        local monitor_pid=$(cat "$PROJECT_DIR/monitor.pid" 2>/dev/null)
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            print_message $CYAN "   💥 强制停止监控进程 (PID: $monitor_pid)"
            kill -9 $monitor_pid 2>/dev/null || true
        fi
    fi
    
    # 清理PID文件
    rm -f "$PID_FILE" "$PROJECT_DIR/guard.pid" "$PROJECT_DIR/monitor.pid"
    
    print_message $GREEN "✅ 所有进程已强制停止（使用kill -9）"
    
    # 停止监控守护进程
    if [ -f "$PROJECT_DIR/monitor.pid" ]; then
        local monitor_pid=$(cat "$PROJECT_DIR/monitor.pid" 2>/dev/null)
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            kill $monitor_pid 2>/dev/null
            sleep 2
            print_message $GREEN "✅ 监控进程已停止"
        fi
    fi
    
    # 删除systemd服务
    print_message $YELLOW "🔄 删除系统服务..."
    if systemctl is-enabled finalunlock-bot.service >/dev/null 2>&1; then
        sudo systemctl stop finalunlock-bot.service 2>/dev/null || true
        sudo systemctl disable finalunlock-bot.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/finalunlock-bot.service 2>/dev/null || true
        sudo systemctl daemon-reload 2>/dev/null || true
        print_message $GREEN "✅ 系统服务已删除"
    fi
    
    # 删除全局命令
    print_message $YELLOW "🔄 删除全局命令..."
    local command_paths=("/usr/local/bin/fn-bot" "$HOME/.local/bin/fn-bot")
    for command_path in "${command_paths[@]}"; do
    if [ -f "$command_path" ]; then
        if [ -w "$command_path" ]; then
            rm -f "$command_path"
        else
                sudo rm -f "$command_path" 2>/dev/null || true
            fi
            print_message $GREEN "✅ 已删除: $command_path"
        fi
    done
    
    # 删除桌面快捷方式
    local desktop_file="$HOME/.local/share/applications/finalshell-bot.desktop"
    if [ -f "$desktop_file" ]; then
        rm -f "$desktop_file"
        print_message $GREEN "✅ 桌面快捷方式已删除"
    fi
    
    # 获取项目目录信息
    local parent_dir=$(dirname "$PROJECT_DIR")
    local project_name=$(basename "$PROJECT_DIR")
    
    # 切换到父目录
    cd "$parent_dir" 2>/dev/null || cd "$HOME"
    
    # 删除所有FinalUnlock相关目录
    print_message $YELLOW "🔄 删除所有FinalUnlock相关目录..."
    
    # 删除主目录
    if [ -d "$project_name" ]; then
        rm -rf "$project_name"
        print_message $GREEN "✅ FinalUnlock主目录已删除: $PROJECT_DIR"
    fi
    
    # 删除备份目录
    local backup_count=0
    for backup_dir in "$project_name".backup.*; do
        if [ -d "$backup_dir" ]; then
            rm -rf "$backup_dir"
            print_message $GREEN "✅ 备份目录已删除: $backup_dir"
            ((backup_count++))
        fi
    done
    
    # 删除其他相关目录
    for related_dir in *FinalUnlock*; do
        if [ -d "$related_dir" ] && [ "$related_dir" != "$project_name" ]; then
            rm -rf "$related_dir"
            print_message $GREEN "✅ 相关目录已删除: $related_dir"
        fi
    done
    
    # 清理临时文件
    rm -f /tmp/finalunlock-*.* 2>/dev/null || true
    
    echo
    print_message $GREEN "🎉 项目文件删除完成!"
    print_message $BLUE "📊 清理统计:"
    print_message $CYAN "  • 主目录: 已删除"
    if [ $backup_count -gt 0 ]; then
        print_message $CYAN "  • 备份目录: 已删除 $backup_count 个"
    fi
    print_message $CYAN "  • 系统服务: 已删除"
    print_message $CYAN "  • 全局命令: 已删除"
    
    print_message $YELLOW "💡 提示: 如果需要重新安装，请重新下载项目文件"
    print_message $YELLOW "脚本将在3秒后退出..."
    sleep 3
    emergency_exit
}

# 健康检查函数
health_check() {
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
        # 检查进程是否响应（检查日志文件是否在更新）
        if [ -f "$LOG_FILE" ]; then
            local last_log_time=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_log_time))
            
            # 如果日志文件超过5分钟没有更新，认为可能有问题
            if [ $time_diff -gt 300 ]; then
                echo "unresponsive"
            else
                echo "healthy"
            fi
        else
            echo "no_log"
        fi
    else
        echo "stopped"
    fi
}

# 检查网络连接
check_network() {
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

# 自动重启函数
auto_restart_bot() {
    local max_restart_attempts=3
    local restart_count=0
    local restart_interval=60  # 重启间隔60秒
    local restart_log="$PROJECT_DIR/restart.log"
    
    while [ $restart_count -lt $max_restart_attempts ]; do
        local health=$(health_check)
        local network=$(check_network)
        
        case $health in
            "stopped"|"unresponsive")
                print_message $YELLOW "🔄 检测到机器人异常 ($health)，正在重启... (尝试 $((restart_count + 1))/$max_restart_attempts)"
                
                # 记录重启日志
                echo "$(date '+%Y-%m-%d %H:%M:%S'): Auto-restart triggered - Status: $health, Network: $network" >> "$restart_log"
                
                # 如果网络断开，等待网络恢复
                if [ "$network" = "disconnected" ]; then
                    print_message $YELLOW "⚠️ 网络连接异常，等待网络恢复..."
                    local network_wait=0
                    while [ $network_wait -lt 10 ]; do
                        sleep 30
                        network=$(check_network)
                        if [ "$network" = "connected" ]; then
                            print_message $GREEN "✅ 网络连接已恢复"
                            break
                        fi
                        ((network_wait++))
                    done
                fi
                
                # 🔧 使用强制启动模式进行自动重启
                if force_start_bot; then
                    print_message $GREEN "✅ 机器人重启成功"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Restart successful" >> "$restart_log"
                    return 0
                else
                    print_message $RED "❌ 机器人重启失败"
                    echo "$(date '+%Y-%m-%d %H:%M:%S'): Restart failed" >> "$restart_log"
                    ((restart_count++))
                    if [ $restart_count -lt $max_restart_attempts ]; then
                        print_message $YELLOW "⏳ 等待 $restart_interval 秒后重试..."
                        sleep $restart_interval
                    fi
                fi
                ;;
            "healthy")
                return 0
                ;;
            "no_log")
                print_message $YELLOW "⚠️ 日志文件不存在，但进程正在运行"
                return 0
                ;;
        esac
    done
    
    print_message $RED "❌ 达到最大重启次数 ($max_restart_attempts)，请手动检查"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Max restart attempts reached" >> "$restart_log"
    
    # 发送告警（如果配置了）
    send_alert "FinalShell Bot 重启失败，需要手动干预"
    
    return 1
}

# 静默启动函数（用于自动重启）
start_bot_silent() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # 检查虚拟环境
    local venv_dir="$PROJECT_DIR/venv"
    if [ -d "$venv_dir" ]; then
        source "$venv_dir/bin/activate"
        # 验证并设置正确的Python命令
        if [ -x "$venv_dir/bin/python" ]; then
            PYTHON_CMD="$venv_dir/bin/python"
        elif [ -x "$venv_dir/bin/python3" ]; then
            PYTHON_CMD="$venv_dir/bin/python3"
        elif command -v python &> /dev/null; then
            PYTHON_CMD="python"
        else
            PYTHON_CMD="python3"
        fi
    fi
    
    # 清理旧进程
    pkill -f "bot.py" 2>/dev/null
    sleep 2
    
    # 启动机器人
    nohup $PYTHON_CMD bot.py >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    # 检查启动是否成功
    sleep 5
    if ps -p $pid > /dev/null 2>&1; then
        return 0
    else
        rm -f "$PID_FILE"
        return 1
    fi
}

# 静默停止函数
stop_bot_silent() {
    local status=$(check_bot_status)
    if [ "$status" = "stopped" ]; then
        return 0
    fi
    
    local pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ]; then
        # 先尝试优雅停止
        kill $pid 2>/dev/null
        
        # 等待进程结束
        local count=0
        while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
            sleep 1
            ((count++))
        done
        
        # 如果还在运行，强制停止
        if ps -p $pid > /dev/null 2>&1; then
            kill -9 $pid 2>/dev/null
            sleep 1
        fi
    fi
    
    # 清理所有可能的bot进程
    pkill -f "bot.py" 2>/dev/null
    rm -f "$PID_FILE"
    
    return 0
}

# 日志轮转函数
rotate_logs() {
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        local max_size=10485760  # 10MB
        
        if [ "$log_size" -gt "$max_size" ]; then
            local backup_name="$LOG_FILE.$(date +%Y%m%d_%H%M%S)"
            
            # 备份当前日志
            cp "$LOG_FILE" "$backup_name"
            
            # 清空当前日志（保持文件句柄）
            > "$LOG_FILE"
            
            # 压缩备份
            gzip "$backup_name" &
            
            echo "$(date '+%Y-%m-%d %H:%M:%S'): Log rotated to $backup_name.gz" >> "$LOG_FILE"
            
            # 清理超过7天的日志备份
            find "$(dirname "$LOG_FILE")" -name "bot.log.*.gz" -mtime +7 -delete 2>/dev/null
        fi
    fi
}

# 系统资源检查
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    # 检查资源使用率是否过高
    if [ "${cpu_usage%.*}" -gt 80 ] || [ "${memory_usage%.*}" -gt 90 ] || [ "$disk_usage" -gt 90 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): High resource usage - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%" >> "$PROJECT_DIR/resource.log"
        return 1
    fi
    
    return 0
}

# 发送告警函数（可扩展）
send_alert() {
    local message="$1"
    local alert_log="$PROJECT_DIR/alert.log"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ALERT - $message" >> "$alert_log"
    
    # 这里可以添加更多告警方式，如邮件、webhook等
    # 例如：curl -X POST "$WEBHOOK_URL" -d "{\"text\":\"$message\"}"
}

# 监控守护进程
start_monitor_daemon() {
    print_message $BLUE "🔍 启动监控守护进程..."
    
    # 检查是否已经在运行
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local existing_pid=$(cat "$monitor_pid_file")
        if [ -n "$existing_pid" ] && ps -p $existing_pid > /dev/null 2>&1; then
            print_message $YELLOW "⚠️ 监控守护进程已在运行 (PID: $existing_pid)"
            return 0
        else
            rm -f "$monitor_pid_file"
        fi
    fi
    
    # 创建监控脚本
    local monitor_script="$PROJECT_DIR/monitor.sh"
    cat > "$monitor_script" << 'EOF'
#!/bin/bash

# 获取项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入主脚本的函数
source "$PROJECT_DIR/start.sh"

# 监控循环
while true; do
    # 健康检查和自动重启
    if ! auto_restart_bot; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Auto restart failed, sleeping for 5 minutes" >> "$PROJECT_DIR/monitor.log"
        sleep 300  # 失败后等待5分钟
        continue
    fi
    
    # 日志轮转
    rotate_logs
    
    # 系统资源检查
    if ! check_system_resources; then
        echo "$(date '+%Y-%m-%d %H:%M:%S'): High resource usage detected" >> "$PROJECT_DIR/monitor.log"
    fi
    
    # 清理临时文件
    find "$PROJECT_DIR" -name "*.tmp" -mtime +1 -delete 2>/dev/null
    
    # 等待60秒
    sleep 60
done
EOF
    
    chmod +x "$monitor_script"
    
    # 启动监控进程
    nohup "$monitor_script" > "$PROJECT_DIR/monitor.log" 2>&1 &
    local monitor_pid=$!
    echo $monitor_pid > "$monitor_pid_file"
    
    print_message $GREEN "✅ 监控守护进程已启动 (PID: $monitor_pid)"
    print_message $CYAN "📋 监控日志: $PROJECT_DIR/monitor.log"
}

# 创建systemd服务
create_systemd_service() {
    print_message $BLUE "🔧 创建systemd服务..."
    
    # 检查是否为Linux环境
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OS" == "Windows_NT" ]]; then
        print_message $YELLOW "⚠️ Windows环境不支持systemd服务"
        return 1
    fi
    
    # 检查systemd是否可用
    if ! command -v systemctl &> /dev/null; then
        print_message $YELLOW "⚠️ 系统不支持systemd"
        return 1
    fi
    
    local service_name="finalunlock-bot"
    local service_file="/etc/systemd/system/${service_name}.service"
    local script_path="$PROJECT_DIR/start.sh"
    
    print_message $CYAN "📝 创建服务文件: $service_file"
    
    # 创建systemd服务文件
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=FinalUnlock Bot Service
After=network.target
Wants=network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin:\$PATH
ExecStart=$script_path --daemon
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=finalunlock-bot

[Install]
WantedBy=multi-user.target
EOF
    
    if [ $? -eq 0 ]; then
        print_message $GREEN "✅ 服务文件创建成功"
        
        # 重新加载systemd
        sudo systemctl daemon-reload
        
        # 启用服务
        if sudo systemctl enable "$service_name.service"; then
            print_message $GREEN "✅ 服务已启用（开机自启）"
            
            # 询问是否立即启动服务
            read -p "是否立即启动systemd服务? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if sudo systemctl start "$service_name.service"; then
                    print_message $GREEN "✅ 服务已启动"
                    systemctl status "$service_name.service" --no-pager
                else
                    print_message $RED "❌ 服务启动失败"
                fi
            fi
        else
            print_message $RED "❌ 服务启用失败"
            return 1
        fi
    else
        print_message $RED "❌ 服务文件创建失败"
        return 1
    fi
}

# 创建systemd服务（静默版本，用于自动修复）
create_systemd_service_silent() {
    # 检查是否为Linux环境
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OS" == "Windows_NT" ]]; then
        return 1
    fi
    
    # 检查systemd是否可用
    if ! command -v systemctl &> /dev/null; then
        return 1
    fi
    
    local service_name="finalunlock-bot"
    local service_file="/etc/systemd/system/${service_name}.service"
    local script_path="$PROJECT_DIR/start.sh"
    
    # 创建systemd服务文件（尝试不需要交互）
    if sudo -n true 2>/dev/null; then
        # 有sudo无密码权限
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=FinalUnlock Bot Service
After=network.target
Wants=network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment=PATH=/usr/local/bin:/usr/bin:/bin:\$PATH
ExecStart=$script_path --daemon
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=finalunlock-bot

[Install]
WantedBy=multi-user.target
EOF
        
        if [ $? -eq 0 ]; then
            # 重新加载systemd并启用服务
            sudo systemctl daemon-reload 2>/dev/null
            sudo systemctl enable "$service_name.service" 2>/dev/null
            return 0
        fi
    fi
    
    return 1
}

# 检查systemd服务状态
check_systemd_service() {
    local service_name="finalunlock-bot"
    
    if command -v systemctl &> /dev/null; then
        if systemctl is-enabled "$service_name.service" >/dev/null 2>&1; then
            if systemctl is-active "$service_name.service" >/dev/null 2>&1; then
                echo "running"
            else
                echo "stopped"
            fi
        else
            echo "disabled"
        fi
    else
        echo "unsupported"
    fi
}

# 管理systemd服务
manage_systemd_service() {
    while true; do
        print_message $BLUE "🔧 systemd服务管理"
        
        local service_status=$(check_systemd_service)
        local status_text=""
        case $service_status in
            "running")
                status_text="✅ 运行中并已启用开机自启"
                ;;
            "stopped")
                status_text="⏸️ 已启用但未运行"
                ;;
            "disabled")
                status_text="❌ 未启用开机自启"
                ;;
            "unsupported")
                status_text="❌ 系统不支持systemd"
                ;;
        esac
        
        echo
        print_message $CYAN "当前状态: $status_text"
        echo
        
        print_message $CYAN "服务管理选项:"
        echo -e "${CYAN}[1] 创建并启用服务${NC}"
        echo -e "${CYAN}[2] 启动服务${NC}"
        echo -e "${CYAN}[3] 停止服务${NC}"
        echo -e "${CYAN}[4] 重启服务${NC}"
        echo -e "${CYAN}[5] 查看服务状态${NC}"
        echo -e "${CYAN}[6] 查看服务日志${NC}"
        echo -e "${CYAN}[7] 禁用服务${NC}"
        echo -e "${CYAN}[8] 删除服务${NC}"
        echo -e "${CYAN}[0] 返回主菜单${NC}"
        echo
        
        read -p "请选择 [0-8]: " service_choice
        
        case $service_choice in
            1)
                create_systemd_service
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            2)
                print_message $BLUE "🔄 启动服务..."
                if sudo systemctl start finalunlock-bot.service; then
                    print_message $GREEN "✅ 服务已启动"
                else
                    print_message $RED "❌ 服务启动失败"
                fi
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            3)
                print_message $BLUE "🛑 停止服务..."
                if sudo systemctl stop finalunlock-bot.service; then
                    print_message $GREEN "✅ 服务已停止"
                else
                    print_message $RED "❌ 服务停止失败"
                fi
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            4)
                print_message $BLUE "🔄 重启服务..."
                if sudo systemctl restart finalunlock-bot.service; then
                    print_message $GREEN "✅ 服务已重启"
                else
                    print_message $RED "❌ 服务重启失败"
                fi
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            5)
                print_message $BLUE "📊 服务状态:"
                systemctl status finalunlock-bot.service --no-pager
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            6)
                print_message $BLUE "📋 服务日志 (最后50行):"
                sudo journalctl -u finalunlock-bot.service -n 50 --no-pager
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            7)
                print_message $BLUE "⏸️ 禁用服务..."
                if sudo systemctl disable finalunlock-bot.service; then
                    print_message $GREEN "✅ 服务已禁用"
                else
                    print_message $RED "❌ 服务禁用失败"
                fi
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            8)
                print_message $RED "⚠️ 确认删除systemd服务?"
                read -p "此操作将删除服务文件 (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo systemctl stop finalunlock-bot.service 2>/dev/null || true
                    sudo systemctl disable finalunlock-bot.service 2>/dev/null || true
                    sudo rm -f /etc/systemd/system/finalunlock-bot.service
                    sudo systemctl daemon-reload
                    print_message $GREEN "✅ 服务已删除"
                else
                    print_message $YELLOW "❌ 取消删除操作"
                fi
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
            0)
                return
                ;;
            *)
                print_message $RED "❌ 无效选择"
                read -p "按任意键继续..." -n 1 -r
                echo
                ;;
        esac
    done
}

# 快速诊断和修复
quick_diagnose_and_fix() {
    print_message $BLUE "🔍 快速诊断系统状态..."
    echo
    
    local issues_found=0
    local fixes_applied=0
    
    # 检查机器人进程
    print_message $CYAN "1. 检查机器人进程状态..."
    local bot_status=$(check_bot_status)
    if [ "$bot_status" != "running" ]; then
        print_message $RED "❌ 机器人进程未运行"
        issues_found=$((issues_found + 1))
        
        # 检查配置是否存在
        if [ -f "$ENV_FILE" ]; then
            print_message $YELLOW "🔄 尝试启动机器人..."
            if start_bot; then
                print_message $GREEN "✅ 机器人已启动"
                fixes_applied=$((fixes_applied + 1))
            else
                print_message $RED "❌ 机器人启动失败"
            fi
        else
            print_message $YELLOW "⚠️ 配置文件不存在，请先配置"
        fi
    else
        print_message $GREEN "✅ 机器人进程正常运行"
    fi
    
    # 检查日志文件
    echo
    print_message $CYAN "2. 检查日志文件..."
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ Bot日志文件不存在"
        issues_found=$((issues_found + 1))
        
        # 创建日志目录
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
        print_message $GREEN "✅ 已创建日志文件"
        fixes_applied=$((fixes_applied + 1))
    else
        print_message $GREEN "✅ 日志文件存在"
    fi
    
    # 检查systemd服务
    echo
    print_message $CYAN "3. 检查systemd服务状态..."
    local service_status=$(check_systemd_service)
    case $service_status in
        "disabled"|"unsupported")
            print_message $YELLOW "⚠️ systemd服务未启用"
            issues_found=$((issues_found + 1))
            
            if [ "$service_status" != "unsupported" ]; then
                print_message $BLUE "💡 建议启用systemd服务以实现开机自启"
                read -p "是否现在创建systemd服务? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    if create_systemd_service; then
                        fixes_applied=$((fixes_applied + 1))
                    fi
                fi
            fi
            ;;
        "stopped")
            print_message $YELLOW "⚠️ systemd服务已启用但未运行"
            ;;
        "running")
            print_message $GREEN "✅ systemd服务正常运行"
            ;;
    esac
    
    # 检查依赖包
    echo
    print_message $CYAN "4. 检查Python依赖..."
    if ! $PYTHON_CMD -c "import telegram, dotenv, Crypto, schedule, psutil" 2>/dev/null; then
        print_message $YELLOW "⚠️ 发现缺失的依赖包"
        issues_found=$((issues_found + 1))
        
        read -p "是否现在安装缺失的依赖? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if install_dependencies; then
                print_message $GREEN "✅ 依赖安装完成"
                fixes_applied=$((fixes_applied + 1))
            fi
        fi
    else
        print_message $GREEN "✅ 所有依赖包正常"
    fi
    
    # 检查Guard进程
    echo
    print_message $CYAN "5. 检查Guard守护进程..."
    if [ -f "$PROJECT_DIR/guard.pid" ]; then
        local guard_pid=$(cat "$PROJECT_DIR/guard.pid" 2>/dev/null)
        if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
            print_message $GREEN "✅ Guard进程正常运行"
        else
            print_message $YELLOW "⚠️ Guard PID文件存在但进程未运行"
            rm -f "$PROJECT_DIR/guard.pid"
        fi
    else
        print_message $YELLOW "💡 Guard进程未运行（这是正常的，可选功能）"
    fi
    
    # 总结
    echo
    print_message $BLUE "📊 诊断总结:"
    print_message $CYAN "🔍 发现问题: $issues_found 个"
    print_message $CYAN "🔧 已修复: $fixes_applied 个"
    
    if [ $issues_found -eq 0 ]; then
        print_message $GREEN "🎉 系统状态良好，未发现问题"
    elif [ $fixes_applied -eq $issues_found ]; then
        print_message $GREEN "🎉 所有问题已成功修复"
    else
        print_message $YELLOW "⚠️ 部分问题需要手动处理"
    fi
    
    echo
    read -p "按任意键返回主菜单..." -n 1 -r
    echo
}

# 停止监控守护进程
stop_monitor_daemon() {
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            kill $monitor_pid 2>/dev/null
            
            # 等待进程结束
            local count=0
            while ps -p $monitor_pid > /dev/null 2>&1 && [ $count -lt 5 ]; do
                read -p "按任意键继续..." -n 1 -r
                echo
                ((count++))
            done
            
            # 强制停止
            if ps -p $monitor_pid > /dev/null 2>&1; then
                kill -9 $monitor_pid 2>/dev/null
            fi
            
            rm -f "$monitor_pid_file"
            print_message $GREEN "✅ 监控守护进程已停止"
        else
            rm -f "$monitor_pid_file"
            print_message $YELLOW "⚠️ 监控守护进程未在运行"
        fi
    else
        print_message $YELLOW "⚠️ 监控守护进程未在运行"
    fi
}

# 检查监控守护进程状态
check_monitor_status() {
    local monitor_pid_file="$PROJECT_DIR/monitor.pid"
    if [ -f "$monitor_pid_file" ]; then
        local monitor_pid=$(cat "$monitor_pid_file")
        if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "stopped"
    fi
}

# 显示系统状态
show_system_status() {
    print_message $BLUE "📊 系统状态报告"
    echo
    
    # 机器人状态
    local bot_status=$(check_bot_status)
    if [ "$bot_status" = "running" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        print_message $GREEN "🤖 机器人状态: ✅ 运行中 (PID: $pid)"
    else
        print_message $RED "🤖 机器人状态: ❌ 未运行"
    fi
    
    # 监控守护进程状态
    local monitor_status=$(check_monitor_status)
    if [ "$monitor_status" = "running" ]; then
        local monitor_pid=$(cat "$PROJECT_DIR/monitor.pid" 2>/dev/null)
        print_message $GREEN "🔍 监控守护进程: ✅ 运行中 (PID: $monitor_pid)"
    else
        print_message $RED "🔍 监控守护进程: ❌ 未运行"
    fi
    
    # 网络状态
    local network=$(check_network)
    if [ "$network" = "connected" ]; then
        print_message $GREEN "🌐 网络连接: ✅ 正常"
    else
        print_message $RED "🌐 网络连接: ❌ 异常"
    fi
    
    # 系统资源
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' 2>/dev/null || echo "N/A")
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    
    print_message $CYAN "💻 CPU 使用率: ${cpu_usage}%"
    print_message $CYAN "🧠 内存使用率: ${memory_usage}%"
    print_message $CYAN "💾 磁盘使用率: ${disk_usage}"
    
    # 日志文件大小
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        print_message $CYAN "📋 日志文件大小: $log_size"
    fi
    
    echo
}

# 日志管理功能
manage_logs() {
    while true; do
    print_message $BLUE "📋 日志管理..."
    
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ 日志文件不存在"
            read -p "按任意键返回主菜单..." -n 1 -r
            echo
        return
    fi
    
    # 获取日志文件信息
    local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
    local log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null | echo "0")
    local last_modified=$(stat -c %y "$LOG_FILE" 2>/dev/null | cut -d' ' -f1,2 || echo "未知")
    
    echo
    print_message $CYAN "日志文件信息:"
    echo -e "  ${CYAN}• 文件路径: $LOG_FILE${NC}"
    echo -e "  ${CYAN}• 文件大小: $log_size${NC}"
    echo -e "  ${CYAN}• 行数: $log_lines${NC}"
    echo -e "  ${CYAN}• 最后修改: $last_modified${NC}"
    echo
    
    print_message $CYAN "日志管理选项:"
    echo -e "${CYAN}[1] 查看实时日志${NC}"
    echo -e "${CYAN}[2] 查看最后50行${NC}"
    echo -e "${CYAN}[3] 查看最后100行${NC}"
    echo -e "${CYAN}[4] 查看全部日志${NC}"
    echo -e "${CYAN}[5] 搜索错误日志${NC}"
    echo -e "${CYAN}[6] 搜索警告日志${NC}"
    echo -e "${CYAN}[7] 搜索特定关键词${NC}"
    echo -e "${CYAN}[8] 清空日志文件${NC}"
    echo -e "${CYAN}[9] 压缩日志文件${NC}"
        echo -e "${CYAN}[0] 返回主菜单${NC}"
    echo
    
    read -p "请选择 [0-9]: " log_choice
    
    case $log_choice in
        1)
            print_message $BLUE "📋 实时日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示实时日志，按任意键返回主菜单..."
            echo
            # 先显示一些日志
            tail -n 10 "$LOG_FILE" 2>/dev/null
            echo
            print_message $CYAN "=== 实时日志开始 ==="
            print_message $YELLOW "按任意键返回主菜单..."
            
            # 使用timeout确保不会无限等待
            timeout 60 tail -f "$LOG_FILE" 2>/dev/null &
            TAIL_PID=$!
            
            # 强制等待用户按键，使用更可靠的方法
            while true; do
                if read -t 1 -n 1 -s; then
                    break
                fi
                # 检查tail进程是否还在运行
                if ! kill -0 $TAIL_PID 2>/dev/null; then
                    break
                fi
            done
            
            # 立即停止tail进程
            kill $TAIL_PID 2>/dev/null
            wait $TAIL_PID 2>/dev/null
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        2)
            print_message $BLUE "📋 最后50行日志（任意键返回主菜单）..."
            tail -n 50 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        3)
            print_message $BLUE "📋 最后100行日志（任意键返回主菜单）..."
            tail -n 100 "$LOG_FILE" 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        4)
            print_message $BLUE "📋 全部日志（任意键返回主菜单）..."
            print_message $YELLOW "💡 正在显示全部日志，按任意键返回主菜单..."
            echo
            
            # 使用分页显示，但强制提供退出选项
            if command -v less &> /dev/null; then
                # 使用less但设置环境变量强制退出
                LESS_IS_MORE=1 less -R "$LOG_FILE"
            elif command -v more &> /dev/null; then
                more "$LOG_FILE"
            else
                # 如果没有分页工具，使用cat但强制等待按键
                cat "$LOG_FILE" 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
            fi
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        5)
            print_message $BLUE "📋 搜索错误日志（任意键返回主菜单）..."
            echo -e "${RED}错误信息:${NC}"
            grep -i "error\|exception\|traceback\|failed\|critical" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        6)
            print_message $BLUE "📋 搜索警告日志（任意键返回主菜单）..."
            echo -e "${YELLOW}警告信息:${NC}"
            grep -i "warning\|warn" "$LOG_FILE" | tail -n 20 2>/dev/null
            echo
            print_message $YELLOW "按任意键返回主菜单..."
            read -n 1 -s
            echo
            print_message $CYAN "已返回主菜单"
            ;;
        7)
            print_message $BLUE "📋 搜索特定关键词（任意键返回主菜单）..."
            read -p "请输入搜索关键词: " keyword
            if [ -n "$keyword" ]; then
                print_message $BLUE "📋 搜索结果:"
                echo
                grep -i "$keyword" "$LOG_FILE" | tail -n 20 2>/dev/null
                echo
                print_message $YELLOW "按任意键返回主菜单..."
                read -n 1 -s
                echo
                print_message $CYAN "已返回主菜单"
            else
                print_message $RED "❌ 关键词不能为空"
                read -p "按任意键继续..." -n 1 -r
                echo
            fi
            ;;
        8)
            print_message $RED "⚠️ 确认清空日志文件?"
            read -p "此操作不可逆 (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                > "$LOG_FILE"
                print_message $GREEN "✅ 日志文件已清空"
            else
                print_message $YELLOW "❌ 取消清空操作"
            fi
            read -p "按任意键继续..." -n 1 -r
            echo
            ;;
        9)
            print_message $BLUE "📋 压缩日志文件..."
            local backup_log="$LOG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$LOG_FILE" "$backup_log"
            gzip "$backup_log"
            print_message $GREEN "✅ 日志已备份并压缩: $backup_log.gz"
            read -p "按任意键继续..." -n 1 -r
            echo
            ;;
        0)
            return
            ;;
        *)
            print_message $RED "❌ 无效选择"
            read -p "按任意键继续..." -n 1 -r
            echo
            ;;
    esac
    done
}

# 显示菜单
show_menu() {
    local status=$(check_bot_status)
    local status_text="❌ 未运行"
    local pid_info=""
    
    if [ "$status" = "running" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ]; then
            status_text="✅ 正在运行"
            pid_info=" (PID: $pid)"
        else
            status_text="❌ 未运行"
        fi
    fi
    
    clear
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    FinalShell 机器人管理菜单${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo -e "当前状态: ${status_text}${pid_info}"
    
    # 显示系统信息
    echo -e "${CYAN}Python版本: $($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)${NC}"
    echo -e "${CYAN}项目路径: $PROJECT_DIR${NC}"
    
    # 显示环境配置状态
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}配置状态: ✅ 已配置${NC}"
    else
        echo -e "${RED}配置状态: ❌ 未配置${NC}"
    fi
    
    # 显示Guard状态
    local guard_status="❌ 未运行"
    if [ -f "$PROJECT_DIR/guard.pid" ]; then
        local guard_pid=$(cat "$PROJECT_DIR/guard.pid" 2>/dev/null)
        if [ -n "$guard_pid" ] && ps -p $guard_pid > /dev/null 2>&1; then
            guard_status="✅ 正在运行"
        fi
    fi
    echo -e "${CYAN}Guard状态: $guard_status${NC}"
    
    # 显示日志文件状态
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        echo -e "${CYAN}日志文件: $LOG_FILE (${log_size})${NC}"
    else
        echo -e "${YELLOW}日志文件: 不存在${NC}"
    fi
    
    echo
    echo -e "${BLUE}=== 🤖 机器人管理 ===${NC}"
    echo -e "${CYAN}[1] 启动/重启机器人${NC}"
    echo -e "${CYAN}[2] 停止机器人${NC}"
    echo -e "${CYAN}[3] 日志管理${NC}"
    echo -e "${CYAN}[4] 检查进程状态${NC}"
    echo -e "${CYAN}[5] 检查并安装更新${NC}"
    echo -e "${CYAN}[6] 检查/修复依赖${NC}"
    echo -e "${CYAN}[7] 重新安装依赖${NC}"
    echo -e "${CYAN}[8] 检查/修复虚拟环境${NC}"
    echo -e "${CYAN}[9] 完整卸载机器人${NC}"
    echo
    echo -e "${BLUE}=== 🩺 诊断与修复 ===${NC}"
    echo -e "${CYAN}[q] 快速诊断和修复${NC}"
    echo
    echo -e "${BLUE}=== 🗑️ 卸载管理 ===${NC}"
    echo -e "${CYAN}[u] 仅卸载Python依赖${NC}"
    echo
    echo -e "${BLUE}=== 🛡️ 守护进程管理 ===${NC}"
    echo -e "${CYAN}[g] Guard 守护进程管理${NC}"
    echo
    echo -e "${BLUE}=== ⚙️ 系统配置 ===${NC}"
    echo -e "${CYAN}[c] 配置Bot Token和Chat ID${NC}"
    echo -e "${CYAN}[m] 启动/停止监控守护进程${NC}"
    echo -e "${CYAN}[s] 显示系统状态${NC}"
    echo -e "${CYAN}[r] 重启机器人${NC}"
    echo -e "${CYAN}[v] 验证配置${NC}"
    echo -e "${CYAN}[f] 修复配置${NC}"
    echo -e "${CYAN}[d] systemd服务管理${NC}"
    echo
    echo -e "${BLUE}=== 🔥 故障排除 ===${NC}"
    echo -e "${RED}[k] 🔥 自动清理bot实例 (立即清理)${NC}"
    echo -e "${YELLOW}[K] 📋 手动清理bot实例 (需要确认)${NC}"
    echo
    echo -e "${CYAN}[0] 退出${NC}"
    echo
    
    # 根据配置状态显示不同提示
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}💡 提示: 配置已完成，可以启动机器人${NC}"
    else
        echo -e "${RED}💡 提示: 请先配置Bot Token和Chat ID${NC}"
    fi
    echo -e "${YELLOW}💡 提示: 使用 [g] 进入Guard守护进程管理${NC}"
    echo
}

# 快速检查依赖（不安装）
quick_check_dependencies() {
    # 检查主要依赖是否已安装（更全面的检查）
    local missing_count=0
    
    # 检查核心依赖包
    if ! $PYTHON_CMD -c "import telegram" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    if ! $PYTHON_CMD -c "import dotenv" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    if ! $PYTHON_CMD -c "import Crypto" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    if ! $PYTHON_CMD -c "import schedule" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    if ! $PYTHON_CMD -c "import psutil" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    if ! $PYTHON_CMD -c "import nest_asyncio" 2>/dev/null; then
        missing_count=$((missing_count + 1))
    fi
    
    # 如果缺失依赖数量少于2个，认为环境基本可用（可能只是个别包版本问题）
    if [ $missing_count -eq 0 ]; then
        return 0  # 所有依赖都已安装
    elif [ $missing_count -le 2 ]; then
        # 少量缺失，只安装缺失的
        return 2  # 部分缺失
    else
        return 1  # 大量缺失，需要完整安装
    fi
}

# 只安装缺失的依赖包（精确安装）
install_missing_dependencies_only() {
    local missing_deps=()
    
    # 检查并收集缺失的依赖
    if ! $PYTHON_CMD -c "import telegram" 2>/dev/null; then
        missing_deps+=("python-telegram-bot")
    fi
    
    if ! $PYTHON_CMD -c "import dotenv" 2>/dev/null; then
        missing_deps+=("python-dotenv")
    fi
    
    if ! $PYTHON_CMD -c "import Crypto" 2>/dev/null; then
        missing_deps+=("pycryptodome")
    fi
    
    if ! $PYTHON_CMD -c "import schedule" 2>/dev/null; then
        missing_deps+=("schedule")
    fi
    
    if ! $PYTHON_CMD -c "import psutil" 2>/dev/null; then
        missing_deps+=("psutil")
    fi
    
    if ! $PYTHON_CMD -c "import nest_asyncio" 2>/dev/null; then
        missing_deps+=("nest-asyncio")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        print_message $GREEN "✅ 实际上没有缺失的依赖"
        return 0
    fi
    
    print_message $CYAN "📋 将安装以下缺失的依赖包:"
    for dep in "${missing_deps[@]}"; do
        echo -e "  ${CYAN}• $dep${NC}"
    done
    
    # 确保pip命令可用
    if [ -z "$PIP_CMD" ]; then
        print_message $YELLOW "⚠️ pip命令未设置，重新检测..."
        check_python
    fi
    
    # 逐个安装缺失的依赖
    local success_count=0
    local failed_count=0
    
    for dep in "${missing_deps[@]}"; do
        print_message $CYAN "🔄 安装 $dep..."
        if $PIP_CMD install "$dep" --user 2>/dev/null; then
            print_message $GREEN "✅ $dep 安装成功"
            success_count=$((success_count + 1))
        else
            print_message $YELLOW "⚠️ $dep 安装失败，尝试其他方法..."
            # 尝试不带--user标志
            if $PIP_CMD install "$dep" 2>/dev/null; then
                print_message $GREEN "✅ $dep 安装成功（系统级）"
                success_count=$((success_count + 1))
            else
                print_message $RED "❌ $dep 安装失败"
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    echo
    print_message $BLUE "📊 精确安装结果统计:"
    print_message $GREEN "✅ 成功安装: $success_count 个依赖"
    if [ $failed_count -gt 0 ]; then
        print_message $RED "❌ 安装失败: $failed_count 个依赖"
        print_message $YELLOW "💡 建议使用 [6] 检查/修复依赖 功能进行完整检查"
    fi
    
    return 0
}

# 检查并激活虚拟环境
check_and_activate_venv() {
    local venv_dir="$PROJECT_DIR/venv"
    
    if [ -d "$venv_dir" ]; then
        if [ -z "$VIRTUAL_ENV" ]; then
            print_message $BLUE "🐍 激活虚拟环境..."
            source "$venv_dir/bin/activate"
            
            if [ -n "$VIRTUAL_ENV" ]; then
                print_message $GREEN "✅ 虚拟环境已激活: $(basename "$VIRTUAL_ENV")"
                # 更新Python命令 - 验证文件是否存在
                if [ -x "$venv_dir/bin/python" ]; then
                    PYTHON_CMD="$venv_dir/bin/python"
                elif [ -x "$venv_dir/bin/python3" ]; then
                    PYTHON_CMD="$venv_dir/bin/python3"
                elif command -v python &> /dev/null; then
                    PYTHON_CMD="python"
                else
                    PYTHON_CMD="python3"
                fi
                
                if [ -x "$venv_dir/bin/pip" ]; then
                    PIP_CMD="$venv_dir/bin/pip"
                else
                    PIP_CMD="$PYTHON_CMD -m pip"
                fi
            else
                print_message $RED "❌ 虚拟环境激活失败"
                exit 1
            fi
        else
            print_message $GREEN "✅ 虚拟环境已激活: $(basename "$VIRTUAL_ENV")"
        fi
    else
        print_message $RED "❌ 虚拟环境不存在: $venv_dir"
        print_message $YELLOW "正在尝试创建虚拟环境..."
        
        # 尝试创建虚拟环境
        if command -v python3 &> /dev/null; then
            python3 -m venv "$venv_dir"
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 虚拟环境创建成功"
                source "$venv_dir/bin/activate"
                
                # 安装依赖
                print_message $YELLOW "📥 安装依赖..."
                pip install --upgrade pip
                pip install -r requirements.txt
                pip install schedule psutil
                
                # 验证并设置正确的Python命令
                if [ -x "$venv_dir/bin/python" ]; then
                    PYTHON_CMD="$venv_dir/bin/python"
                elif [ -x "$venv_dir/bin/python3" ]; then
                    PYTHON_CMD="$venv_dir/bin/python3"
                elif command -v python &> /dev/null; then
                    PYTHON_CMD="python"
                else
                    PYTHON_CMD="python3"
                fi
                
                if [ -x "$venv_dir/bin/pip" ]; then
                    PIP_CMD="$venv_dir/bin/pip"
                else
                    PIP_CMD="$PYTHON_CMD -m pip"
                fi
            else
                print_message $RED "❌ 虚拟环境创建失败"
                print_message $YELLOW "请重新运行安装脚本"
                exit 1
            fi
        else
            print_message $RED "❌ 未找到python3，请重新运行安装脚本"
            exit 1
        fi
    fi
}

# 主函数
main() {
    # 检查命令行参数
    if [ "$1" = "--daemon" ]; then

        
        # 守护进程模式，直接启动机器人
        print_message $BLUE "🚀 守护进程模式启动..."
        
        # 检查并激活虚拟环境
        check_and_activate_venv
        
        # 检查配置
        if [ ! -f "$ENV_FILE" ]; then
            print_message $RED "❌ 配置文件不存在，请先运行配置"
            exit 1
        fi
        
        # 启动机器人
        start_bot
        exit 0
    elif [ "$1" = "--uninstall-complete" ]; then
        # 完整卸载模式
        print_message $RED "🗑️ 执行完整卸载..."
        
        # 停止所有进程
        print_message $YELLOW "🛑 停止所有相关进程..."
        pkill -f "bot.py" 2>/dev/null || true
        pkill -f "guard.py" 2>/dev/null || true
        
        # 删除PID文件
        rm -f "$PROJECT_DIR/bot.pid" 2>/dev/null || true
        rm -f "$PROJECT_DIR/guard.pid" 2>/dev/null || true
        rm -f "$PROJECT_DIR/monitor.pid" 2>/dev/null || true
        
        # 卸载Python依赖
        if [ -f "$PROJECT_DIR/requirements.txt" ]; then
            print_message $YELLOW "🔄 卸载Python依赖..."
            while read -r line; do
                if [ -n "$line" ] && [[ ! "$line" =~ ^# ]]; then
                    package_name=$(echo "$line" | sed 's/[>=<].*//' | sed 's/==.*//')
                    pip uninstall -y "$package_name" 2>/dev/null || true
                fi
            done < "$PROJECT_DIR/requirements.txt"
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
        if [ -d "$PROJECT_DIR/venv" ]; then
            print_message $YELLOW "🔄 删除虚拟环境..."
            rm -rf "$PROJECT_DIR/venv"
        fi
        
        print_message $GREEN "✅ 完整卸载完成"
        print_message $GREEN "👋 FinalUnlock已完全卸载"
        exit 0
    fi
    
    # 检查并激活虚拟环境
    check_and_activate_venv
    
    # 显示欢迎信息
    clear
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  FinalShell 激活码机器人管理器${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo -e "${CYAN}项目地址: ${GITHUB_REPO}${NC}"
    echo -e "${CYAN}版本: 1.0${NC}"
    echo
    
    # 检查并下载项目
    print_message $BLUE "🔍 检查项目文件..."
    download_project
    if [ $? -ne 0 ]; then
        print_message $RED "❌ 项目下载失败，请检查网络连接"
        print_message $YELLOW "请确保网络连接正常，并且可以访问GitHub"
        exit 1
    fi
    
    # 检查是否在项目目录
    if [ ! -f "$PROJECT_DIR/bot.py" ]; then
        print_message $RED "❌ 项目文件不完整，请重新运行脚本"
        exit 1
    fi
    
    # 检查并注册全局命令
    if ! check_global_command; then
        print_message $YELLOW "🔧 检测到首次运行，正在注册全局命令..."
        register_global_command
        if [ $? -ne 0 ]; then
            print_message $YELLOW "⚠️ 全局命令注册失败，但脚本仍可正常使用"
        fi
    else
        print_message $GREEN "✅ 全局命令 fn-bot 已注册"
    fi
    
    # 初始化检查
    print_message $BLUE "🔍 开始环境初始化..."
    check_python
    if [ $? -ne 0 ]; then
        print_message $RED "❌ Python环境检查失败"
        exit 1
    fi
    
    # 智能检查依赖，只在必要时才安装
    quick_check_dependencies
    local dep_status=$?
    case $dep_status in
        0)
            print_message $GREEN "✅ 所有依赖包已安装"
            ;;
        1)
            print_message $YELLOW "⚠️ 检测到大量缺失依赖，正在安装..."
        install_dependencies
        if [ $? -ne 0 ]; then
            print_message $RED "❌ 依赖安装失败"
            exit 1
        fi
            ;;
        2)
            print_message $BLUE "🔍 检测到少量缺失依赖，正在精确安装..."
            install_missing_dependencies_only
            ;;
    esac
    
    # 检查环境配置
    if [ ! -f "$ENV_FILE" ]; then
        print_message $BLUE "⚙️ 首次运行，需要配置Bot Token和Chat ID..."
        print_message $YELLOW "💡 请按提示完成配置，配置完成后即可启动机器人"
        print_message $CYAN "📋 配置完成后即可启动机器人"
        echo
        
        # 强制配置，不提供跳过选项
        while true; do
            force_setup_environment
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 配置完成！现在可以启动机器人了"
                break
            else
                print_message $YELLOW "⚠️ 配置未完成，请重新配置"
                echo
                read -p "按回车键重新开始配置..." -r
                echo
            fi
        done
        echo
        
        # 配置完成后询问是否立即启动机器人
        print_message $BLUE "🚀 配置已完成！"
        read -p "是否立即启动机器人? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_bot
            echo
            read -p "按回车键进入管理界面..." -r
        fi
    else
        print_message $GREEN "✅ 环境配置已存在"
    fi
    
    # ====== 自动系统检测和修复 ======
    print_message $BLUE "🔍 执行系统自动检测和修复..."
    
    # 自动修复1：检查并创建日志文件
    if [ ! -f "$LOG_FILE" ]; then
        print_message $YELLOW "⚠️ 日志文件不存在，正在自动创建..."
        mkdir -p "$(dirname "$LOG_FILE")"
        touch "$LOG_FILE"
        print_message $GREEN "✅ 日志文件已创建"
    fi
    
    # 自动修复2：检查并启动机器人（更严格的检查）
    local need_start=0
    if [ -f "$ENV_FILE" ]; then
        # 首先检查是否有任何bot进程在运行
        local running_bots=$(pgrep -f "python.*bot\.py" 2>/dev/null || true)
        
        if [ -n "$running_bots" ]; then
            print_message $GREEN "✅ 检测到机器人进程正在运行 (PID: $running_bots)"
            # 更新PID文件以确保一致性
            echo "$running_bots" | head -1 > "$PID_FILE"
        else
            # 没有运行的bot进程，检查PID文件
            if [ ! -f "$PID_FILE" ]; then
                need_start=1
            else
                local pid=$(cat "$PID_FILE" 2>/dev/null)
                if [ -z "$pid" ] || ! ps -p $pid > /dev/null 2>&1; then
                    need_start=1
                fi
            fi
            
            if [ $need_start -eq 1 ]; then
                print_message $YELLOW "🔄 机器人未运行，正在自动启动..."
                start_bot
                if [ $? -eq 0 ]; then
                    print_message $GREEN "✅ 机器人自动启动成功"
                else
                    print_message $RED "❌ 机器人自动启动失败"
                fi
            fi
        fi
    fi
    
    # 自动修复3：检查并创建systemd服务（非Windows环境）
    if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]] && [[ "$OS" != "Windows_NT" ]]; then
        if command -v systemctl &> /dev/null; then
            local service_status=$(check_systemd_service)
            if [ "$service_status" = "disabled" ] || [ "$service_status" = "unsupported" ]; then
                print_message $YELLOW "🔄 systemd服务未启用，正在自动创建..."
                if create_systemd_service_silent; then
                    print_message $GREEN "✅ systemd服务自动创建成功"
                else
                    print_message $YELLOW "⚠️ systemd服务创建失败（可能需要sudo权限）"
                fi
            else
                print_message $GREEN "✅ systemd服务状态正常"
            fi
        fi
    fi
    
    # 自动修复4：智能检查Python依赖
    quick_check_dependencies
    local auto_dep_status=$?
    case $auto_dep_status in
        0)
            print_message $GREEN "✅ Python依赖检查通过"
            ;;
        1)
            print_message $YELLOW "🔄 检测到大量缺失依赖，正在自动安装..."
            install_dependencies
            if [ $? -eq 0 ]; then
                print_message $GREEN "✅ 依赖自动安装完成"
            else
                print_message $RED "❌ 依赖自动安装失败"
            fi
            ;;
        2)
            print_message $BLUE "🔍 检测到少量缺失依赖，正在精确安装..."
            install_missing_dependencies_only
            ;;
    esac
    
    print_message $GREEN "🎉 系统自动检测和修复完成"
    # ====== 自动修复结束 ======
    print_message $GREEN "✅ 初始化完成！"
    print_message $CYAN "💡 提示：现在可以在任意目录使用 'fn-bot' 命令启动此脚本"
    print_message $YELLOW "⚠️ 注意：Ctrl+C 已被屏蔽，请使用菜单选项退出"
    
    # 根据配置状态显示不同信息
    if [ -f "$ENV_FILE" ]; then
        print_message $GREEN "🚀 配置已完成，可以启动机器人了！"
    else
        print_message $YELLOW "⚙️ 请先配置Bot Token和Chat ID"
    fi
    
    print_message $BLUE "📋 正在启动管理界面..."
    sleep 2
    
    # 主菜单循环
    while true; do
        show_menu
        read -p "请选择操作 [0-9qucgmsvrfdk]: " choice
        
        case $choice in
            1)
                # 检查配置是否完成
                if [ ! -f "$ENV_FILE" ]; then
                    print_message $RED "❌ 请先配置Bot Token和Chat ID"
                    print_message $YELLOW "请选择选项 [c] 进行配置"
                    read -p "按回车键继续..."
                    continue
                fi
                # 智能启动机器人（不强制重启）
                print_message $BLUE "🚀 启动机器人..."
                start_bot
                ;;
            2)
                print_message $BLUE "🛑 停止机器人..."
                stop_bot_with_cleanup
                ;;
            3)
                manage_logs
                ;;
            4)
                check_process
                ;;
            5)
                check_updates
                ;;
            6)
                check_dependencies
                ;;
            7)
                reinstall_dependencies
                ;;
            8)
                check_venv
                ;;
            9)
                print_message $RED "🗑️ 完整卸载机器人..."
                uninstall_bot_with_cleanup
                ;;
            q|Q)
                quick_diagnose_and_fix
                ;;
            u|U)
                print_message $BLUE "🗑️ 卸载Python依赖包..."
                uninstall_dependencies
                read -p "按回车键继续..." -r
                ;;
            g|G)
                open_guard_menu
                ;;
            c|C)
                print_message $BLUE "⚙️ 配置Bot Token和Chat ID..."
                setup_environment
                if [ $? -eq 0 ]; then
                    print_message $GREEN "✅ 配置完成！现在可以启动机器人了"
                fi
                ;;
            m|M)
                local monitor_status=$(check_monitor_status)
                if [ "$monitor_status" = "running" ]; then
                    print_message $YELLOW "监控守护进程正在运行，是否停止？"
                    read -p "停止监控守护进程? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        stop_monitor_daemon
                    fi
                else
                    print_message $BLUE "启动监控守护进程..."
                    start_monitor_daemon
                fi
                ;;
            s|S)
                show_system_status
                read -p "按回车键继续..." -r
                ;;
            r|R)
                print_message $BLUE "🔄 重启机器人..."
                restart_bot
                read -p "按回车键继续..." -r
                ;;
            v|V)
                echo
                if validate_configuration; then
                    print_message $GREEN "🎉 配置验证通过，可以启动机器人！"
                else
                    echo
                    show_config_fix_suggestions
                    echo
                    read -p "是否尝试自动修复? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        auto_fix_config
                        echo
                        print_message $BLUE "请重新验证配置"
                    fi
                fi
                read -p "按回车键继续..." -r
                ;;
            f|F)
                print_message $BLUE "🔧 开始自动修复配置..."
                auto_fix_config
                echo
                print_message $BLUE "修复完成，建议重新验证配置"
                read -p "按回车键继续..." -r
                ;;
            d|D)
                manage_systemd_service
                ;;
            k)
                print_message $RED "🔥 自动清理bot实例"
                print_message $CYAN "正在执行自动清理，无需确认..."
                execute_auto_cleanup
                ;;
            K)
                print_message $YELLOW "📋 手动清理bot实例"
                print_message $YELLOW "⚠️ 这将终止所有运行中的FinalUnlock机器人进程"
                read -p "确认执行清理? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    execute_manual_cleanup
                else
                    print_message $YELLOW "❌ 取消清理操作"
                fi
                ;;
            0)
                safe_exit
                ;;
            *)
                print_message $RED "❌ 无效选择，请输入 0-9、q、u、g、c、m、s、v、r、f、d、k 或 K"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# Guard菜单调用函数
open_guard_menu() {
    print_message $BLUE "🛡️ 进入Guard守护进程管理..."
    
    # 检查guard.sh是否存在
    if [ ! -f "$PROJECT_DIR/guard.sh" ]; then
        print_message $RED "❌ guard.sh文件不存在"
        print_message $YELLOW "请确保Guard守护程序已正确安装"
        read -p "按回车键返回主菜单..." -r
        return
    fi
    
    # 设置返回标志
    export GUARD_RETURN_TO_MAIN="true"
    export MAIN_MENU_PATH="$PROJECT_DIR/start.sh"
    
    # 调用guard.sh菜单
    cd "$PROJECT_DIR"
    bash guard.sh
    
    # 清除返回标志
    unset GUARD_RETURN_TO_MAIN
    unset MAIN_MENU_PATH
    
    print_message $CYAN "🔙 已返回主菜单"
}

# 监控管理菜单
monitor_menu() {
    while true; do
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}        监控管理菜单${NC}"
        echo -e "${PURPLE}================================${NC}"
        
        # 检查监控状态
        local monitor_pid_file="$PROJECT_DIR/monitor.pid"
        local monitor_status="❌ 未运行"
        if [ -f "$monitor_pid_file" ]; then
            local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null)
            if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
                monitor_status="✅ 正在运行 (PID: $monitor_pid)"
            else
                monitor_status="❌ 未运行"
                rm -f "$monitor_pid_file"
            fi
        fi
        
        echo -e "监控状态: ${monitor_status}"
        
        # 显示健康检查结果
        local health=$(health_check)
        local health_text=""
        case $health in
            "healthy")
                health_text="✅ 健康"
                ;;
            "stopped")
                health_text="❌ 已停止"
                ;;
            "unresponsive")
                health_text="⚠️ 无响应"
                ;;
            "no_log")
                health_text="⚠️ 无日志"
                ;;
        esac
        echo -e "机器人健康: ${health_text}"
        
        echo
        echo -e "${CYAN}[1] 启动监控守护进程${NC}"
        echo -e "${CYAN}[2] 停止监控守护进程${NC}"
        echo -e "${CYAN}[3] 手动健康检查${NC}"
        echo -e "${CYAN}[4] 重启机器人${NC}"
        echo -e "${CYAN}[5] 查看监控日志${NC}"
        echo -e "${CYAN}[6] 查看重启日志${NC}"
        echo -e "${CYAN}[7] 手动日志轮转${NC}"
        echo -e "${CYAN}[0] 返回主菜单${NC}"
        echo
        
        read -p "请选择操作 [0-7]: " monitor_choice
        
        case $monitor_choice in
            1)
                if [ -f "$monitor_pid_file" ]; then
                    local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null)
                    if [ -n "$monitor_pid" ] && ps -p $monitor_pid > /dev/null 2>&1; then
                        print_message $YELLOW "⚠️ 监控守护进程已在运行"
                    else
                        start_monitor_daemon
                    fi
                else
                    start_monitor_daemon
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            2)
                stop_monitor_daemon
                read -p "按任意键继续..." -n 1 -r
                ;;
            3)
                print_message $BLUE "🔍 执行健康检查..."
                local health=$(health_check)
                case $health in
                    "healthy")
                        print_message $GREEN "✅ 机器人运行正常"
                        ;;
                    "stopped")
                        print_message $RED "❌ 机器人已停止"
                        ;;
                    "unresponsive")
                        print_message $YELLOW "⚠️ 机器人可能无响应（日志超过5分钟未更新）"
                        ;;
                    "no_log")
                        print_message $YELLOW "⚠️ 进程运行但无日志文件"
                        ;;
                esac
                read -p "按任意键继续..." -n 1 -r
                ;;
            4)
                print_message $BLUE "🔄 重启机器人..."
                restart_bot
                read -p "按任意键继续..." -n 1 -r
                ;;
            5)
                if [ -f "$PROJECT_DIR/monitor.log" ]; then
                    print_message $BLUE "📋 监控日志（最后50行）:"
                    tail -n 50 "$PROJECT_DIR/monitor.log"
                else
                    print_message $YELLOW "⚠️ 监控日志文件不存在"
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            6)
                if [ -f "$LOG_FILE.restart" ]; then
                    print_message $BLUE "📋 重启日志:"
                    cat "$LOG_FILE.restart"
                else
                    print_message $YELLOW "⚠️ 重启日志文件不存在"
                fi
                read -p "按任意键继续..." -n 1 -r
                ;;
            7)
                print_message $BLUE "🔄 执行日志轮转..."
                rotate_logs
                read -p "按任意键继续..." -n 1 -r
                ;;
            0)
                return
                ;;
            *)
                print_message $RED "❌ 无效选择"
                read -p "按任意键继续..." -n 1 -r
                ;;
        esac
    done
}

# 运行主函数
# 获取全局控制权，确保只有一个主控程序
acquire_global_control "start.sh"

# 设置退出时释放全局控制权
trap 'release_global_control; exit' INT TERM EXIT

main