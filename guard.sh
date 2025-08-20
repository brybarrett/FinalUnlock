#!/bin/bash

# 检查是否从主菜单调用
FROM_MAIN_MENU=${GUARD_RETURN_TO_MAIN:-"false"}
MAIN_SCRIPT=${MAIN_MENU_PATH:-""}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_PID_FILE="$PROJECT_DIR/guard.pid"
GUARD_LOG_FILE="$PROJECT_DIR/guard.log"
PYTHON_CMD="python3"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 安全退出函数
safe_exit() {
    if [ "$FROM_MAIN_MENU" = "true" ]; then
        print_message $CYAN "🔙 返回主菜单..."
        return 0  # 返回到调用脚本
    else
        print_message $GREEN "👋 再见！"
        exit 0
    fi
}

# 检查Guard进程状态
check_guard_status() {
    if [ -f "$GUARD_PID_FILE" ]; then
        local pid=$(cat "$GUARD_PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p $pid > /dev/null 2>&1; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "stopped"
    fi
}

# 启动Guard守护进程
start_guard() {
    print_message $BLUE "🛡️ 启动 Guard 守护进程..."
    
    local status=$(check_guard_status)
    if [ "$status" = "running" ]; then
        local pid=$(cat "$GUARD_PID_FILE")
        print_message $YELLOW "⚠️ Guard 守护进程已在运行 (PID: $pid)"
        return 0
    fi
    
    # 检查依赖
    if ! $PYTHON_CMD -c "import schedule, psutil" 2>/dev/null; then
        print_message $YELLOW "📦 安装必要依赖..."
        pip3 install schedule psutil --user
    fi
    
    # 启动守护进程
    cd "$PROJECT_DIR"
    nohup $PYTHON_CMD guard.py daemon > "$GUARD_LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$GUARD_PID_FILE"
    
    # 检查启动是否成功
    sleep 3
    if ps -p $pid > /dev/null 2>&1; then
        print_message $GREEN "✅ Guard 守护进程启动成功 (PID: $pid)"
        print_message $CYAN "📋 日志文件: $GUARD_LOG_FILE"
        print_message $CYAN "⏰ 自检时间: 每天 00:00 (Asia/Shanghai)"
        print_message $CYAN "📤 报告时间: 每天 08:00 (Asia/Shanghai)"
    else
        print_message $RED "❌ Guard 守护进程启动失败"
        rm -f "$GUARD_PID_FILE"
        return 1
    fi
}

# 停止Guard守护进程
stop_guard() {
    print_message $BLUE "🛑 停止 Guard 守护进程..."
    
    local status=$(check_guard_status)
    if [ "$status" = "stopped" ]; then
        print_message $YELLOW "⚠️ Guard 守护进程未在运行"
        return 0
    fi
    
    local pid=$(cat "$GUARD_PID_FILE")
    print_message $YELLOW "🔄 正在停止进程 (PID: $pid)..."
    
    # 优雅停止
    kill $pid 2>/dev/null
    
    # 等待进程结束
    local count=0
    while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
        sleep 1
        ((count++))
    done
    
    # 强制停止
    if ps -p $pid > /dev/null 2>&1; then
        kill -9 $pid 2>/dev/null
    fi
    
    rm -f "$GUARD_PID_FILE"
    print_message $GREEN "✅ Guard 守护进程已停止"
}

# 手动执行自检
manual_check() {
    print_message $BLUE "🔍 执行手动自检..."
    cd "$PROJECT_DIR"
    $PYTHON_CMD guard.py check
}

# 手动发送报告
manual_report() {
    print_message $BLUE "📤 手动发送报告..."
    cd "$PROJECT_DIR"
    $PYTHON_CMD guard.py report
}

# 查看Guard状态
show_status() {
    print_message $BLUE "📊 Guard 守护进程状态"
    echo
    
    local status=$(check_guard_status)
    if [ "$status" = "running" ]; then
        local pid=$(cat "$GUARD_PID_FILE")
        print_message $GREEN "🛡️ Guard 状态: ✅ 运行中 (PID: $pid)"
        
        # 显示进程信息
        if command -v ps &> /dev/null; then
            local process_info=$(ps -p $pid -o pid,ppid,cmd,etime,pcpu,pmem --no-headers 2>/dev/null)
            if [ -n "$process_info" ]; then
                print_message $CYAN "📋 进程信息: $process_info"
            fi
        fi
    else
        print_message $RED "🛡️ Guard 状态: ❌ 未运行"
    fi
    
    # 显示日志文件信息
    if [ -f "$GUARD_LOG_FILE" ]; then
        local log_size=$(du -h "$GUARD_LOG_FILE" 2>/dev/null | cut -f1 || echo "未知")
        print_message $CYAN "📋 日志文件: $GUARD_LOG_FILE ($log_size)"
    fi
    
    # 显示最近的报告
    if [ -f "$PROJECT_DIR/daily_report.json" ]; then
        local report_time=$(stat -c %y "$PROJECT_DIR/daily_report.json" 2>/dev/null | cut -d'.' -f1 || echo "未知")
        print_message $CYAN "📊 最近报告: $report_time"
    fi
    
    echo
}

# 显示菜单
show_menu() {
    clear
    echo -e "${PURPLE}================================${NC}"
    if [ "$FROM_MAIN_MENU" = "true" ]; then
        echo -e "${PURPLE}    Guard 守护程序管理菜单${NC}"
        echo -e "${PURPLE}   (从主菜单调用)${NC}"
    else
        echo -e "${PURPLE}    Guard 守护程序管理菜单${NC}"
    fi
    echo -e "${PURPLE}================================${NC}"
    echo
    
    show_status
    
    echo -e "${BLUE}=== 🛡️ Guard 进程管理 ===${NC}"
    echo -e "${CYAN}[1] 启动 Guard 守护进程${NC}"
    echo -e "${CYAN}[2] 停止 Guard 守护进程${NC}"
    echo -e "${CYAN}[3] 重启 Guard 守护进程${NC}"
    echo
    echo -e "${BLUE}=== 🔍 自检功能 ===${NC}"
    echo -e "${CYAN}[4] 手动执行自检${NC}"
    echo -e "${CYAN}[5] 手动发送报告${NC}"
    echo
    echo -e "${BLUE}=== 📋 日志管理 ===${NC}"
    echo -e "${CYAN}[6] 查看当前日志${NC}"
    echo -e "${CYAN}[7] 查看最新报告${NC}"
    echo -e "${CYAN}[8] 日志文件列表${NC}"
    echo -e "${CYAN}[9] 查看指定日期日志${NC}"
    echo -e "${CYAN}[c] 手动清理日志${NC}"
    echo
    
    if [ "$FROM_MAIN_MENU" = "true" ]; then
        echo -e "${CYAN}[0] 返回主菜单${NC}"
    else
        echo -e "${CYAN}[0] 退出${NC}"
    fi
    echo
    
    print_message $YELLOW "💡 提示: Guard日志文件永久保存，不会自动删除"
    if [ "$FROM_MAIN_MENU" = "true" ]; then
        print_message $CYAN "💡 提示: 子菜单操作完成后会返回Guard菜单"
    fi
    echo
}

# 通用返回函数
return_to_menu() {
    if [ "$FROM_MAIN_MENU" = "true" ]; then
        read -p "按回车键返回Guard菜单..." -r
    else
        read -p "按回车键继续..." -r
    fi
}

# 主菜单循环
while true; do
    show_menu
    read -p "请选择操作 [0-9c]: " choice
    
    case $choice in
        1)
            start_guard
            return_to_menu
            ;;
        2)
            stop_guard
            return_to_menu
            ;;
        3)
            stop_guard
            sleep 2
            start_guard
            return_to_menu
            ;;
        4)
            manual_check
            return_to_menu
            ;;
        5)
            manual_report
            return_to_menu
            ;;
        6)
            if [ -f "$GUARD_LOG_FILE" ]; then
                print_message $BLUE "📋 当前Guard日志 (最后50行):"
                tail -n 50 "$GUARD_LOG_FILE"
            else
                print_message $YELLOW "⚠️ 日志文件不存在"
            fi
            return_to_menu
            ;;
        7)
            if [ -f "$PROJECT_DIR/daily_report_$(date +%Y%m%d).json" ]; then
                print_message $BLUE "📊 今日自检报告:"
                cat "$PROJECT_DIR/daily_report_$(date +%Y%m%d).json" | python3 -m json.tool 2>/dev/null || cat "$PROJECT_DIR/daily_report_$(date +%Y%m%d).json"
            else
                print_message $YELLOW "⚠️ 今日报告文件不存在"
            fi
            return_to_menu
            ;;
        8)
            list_log_files
            return_to_menu
            ;;
        9)
            view_date_log
            return_to_menu
            ;;
        c|C)
            manual_cleanup_logs
            return_to_menu
            ;;
        0)
            safe_exit
            break
            ;;
        *)
            print_message $RED "❌ 无效选择"
            sleep 1
            ;;
    esac
done

# 日志文件列表函数
list_log_files() {
    print_message $BLUE "📋 Guard 日志文件列表"
    echo
    
    # 列出所有Guard日志文件
    if ls "$PROJECT_DIR"/guard_*.log 1> /dev/null 2>&1; then
        print_message $CYAN "🛡️ Guard 日志文件:"
        for log_file in "$PROJECT_DIR"/guard_*.log; do
            if [ -f "$log_file" ]; then
                local size=$(du -h "$log_file" 2>/dev/null | cut -f1 || echo "未知")
                local date=$(basename "$log_file" .log | sed 's/guard_//')
                local formatted_date=$(echo $date | sed 's/\(.\{4\}\)\(.\{2\}\)\(.\{2\}\)/\1-\2-\3/')
                print_message $WHITE "  📄 $formatted_date: $(basename "$log_file") ($size)"
            fi
        done
    else
        print_message $YELLOW "⚠️ 未找到Guard日志文件"
    fi
    
    echo
    
    # 列出所有报告文件
    if ls "$PROJECT_DIR"/daily_report_*.json 1> /dev/null 2>&1; then
        print_message $CYAN "📊 自检报告文件:"
        for report_file in "$PROJECT_DIR"/daily_report_*.json; do
            if [ -f "$report_file" ]; then
                local size=$(du -h "$report_file" 2>/dev/null | cut -f1 || echo "未知")
                local date=$(basename "$report_file" .json | sed 's/daily_report_//')
                local formatted_date=$(echo $date | sed 's/\(.\{4\}\)\(.\{2\}\)\(.\{2\}\)/\1-\2-\3/')
                print_message $WHITE "  📊 $formatted_date: $(basename "$report_file") ($size)"
            fi
        done
    else
        print_message $YELLOW "⚠️ 未找到自检报告文件"
    fi
    
    echo
}

# 查看指定日期的日志
view_date_log() {
    print_message $BLUE "📋 查看指定日期日志"
    echo
    
    read -p "请输入日期 (格式: YYYYMMDD, 如: 20241220): " date_input
    
    if [[ ! "$date_input" =~ ^[0-9]{8}$ ]]; then
        print_message $RED "❌ 日期格式错误，请使用 YYYYMMDD 格式"
        return 1
    fi
    
    local log_file="$PROJECT_DIR/guard_${date_input}.log"
    local report_file="$PROJECT_DIR/daily_report_${date_input}.json"
    
    if [ -f "$log_file" ]; then
        print_message $GREEN "📄 Guard日志 ($date_input):"
        echo "----------------------------------------"
        cat "$log_file"
        echo "----------------------------------------"
    else
        print_message $YELLOW "⚠️ 未找到日期 $date_input 的Guard日志"
    fi
    
    echo
    
    if [ -f "$report_file" ]; then
        print_message $GREEN "📊 自检报告 ($date_input):"
        echo "----------------------------------------"
        cat "$report_file" | python3 -m json.tool 2>/dev/null || cat "$report_file"
        echo "----------------------------------------"
    else
        print_message $YELLOW "⚠️ 未找到日期 $date_input 的自检报告"
    fi
}

# 手动清理日志（用户确认）
manual_cleanup_logs() {
    print_message $BLUE "🗑️ 手动清理日志文件"
    echo
    
    # 显示当前日志文件
    list_log_files
    
    print_message $RED "⚠️ 警告: 此操作将永久删除选定的日志文件！"
    print_message $YELLOW "💡 建议: 在删除前先备份重要的日志文件"
    echo
    
    print_message $CYAN "请选择清理方式:"
    echo -e "${CYAN}[1] 清理指定日期的日志${NC}"
    echo -e "${CYAN}[2] 清理7天前的日志${NC}"
    echo -e "${CYAN}[3] 清理30天前的日志${NC}"
    echo -e "${CYAN}[4] 清理所有日志 (危险操作)${NC}"
    echo -e "${CYAN}[0] 取消${NC}"
    echo
    
    read -p "请选择 [0-4]: " cleanup_choice
    
    case $cleanup_choice in
        1)
            read -p "请输入要删除的日期 (YYYYMMDD): " date_input
            if [[ "$date_input" =~ ^[0-9]{8}$ ]]; then
                local log_file="$PROJECT_DIR/guard_${date_input}.log"
                local report_file="$PROJECT_DIR/daily_report_${date_input}.json"
                
                print_message $YELLOW "将删除以下文件:"
                [ -f "$log_file" ] && print_message $WHITE "  - $(basename "$log_file")"
                [ -f "$report_file" ] && print_message $WHITE "  - $(basename "$report_file")"
                
                read -p "确认删除? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    [ -f "$log_file" ] && rm -f "$log_file" && print_message $GREEN "✅ 已删除 $(basename "$log_file")"
                    [ -f "$report_file" ] && rm -f "$report_file" && print_message $GREEN "✅ 已删除 $(basename "$report_file")"
                else
                    print_message $YELLOW "❌ 取消删除"
                fi
            else
                print_message $RED "❌ 日期格式错误"
            fi
            ;;
        2)
            print_message $YELLOW "🔍 查找7天前的日志文件..."
            local old_files=$(find "$PROJECT_DIR" -name "guard_*.log" -o -name "daily_report_*.json" | xargs ls -la 2>/dev/null | awk '$6 " " $7 " " $8 < "'$(date -d '7 days ago' '+%b %d %H:%M')'" {print $9}' 2>/dev/null)
            
            if [ -n "$old_files" ]; then
                print_message $YELLOW "将删除以下7天前的文件:"
                echo "$old_files" | while read file; do
                    [ -n "$file" ] && print_message $WHITE "  - $(basename "$file")"
                done
                
                read -p "确认删除? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "$old_files" | while read file; do
                        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" && print_message $GREEN "✅ 已删除 $(basename "$file")"
                    done
                else
                    print_message $YELLOW "❌ 取消删除"
                fi
            else
                print_message $GREEN "✅ 没有找到7天前的日志文件"
            fi
            ;;
        3)
            print_message $YELLOW "🔍 查找30天前的日志文件..."
            local old_files=$(find "$PROJECT_DIR" -name "guard_*.log" -o -name "daily_report_*.json" | xargs ls -la 2>/dev/null | awk '$6 " " $7 " " $8 < "'$(date -d '30 days ago' '+%b %d %H:%M')'" {print $9}' 2>/dev/null)
            
            if [ -n "$old_files" ]; then
                print_message $YELLOW "将删除以下30天前的文件:"
                echo "$old_files" | while read file; do
                    [ -n "$file" ] && print_message $WHITE "  - $(basename "$file")"
                done
                
                read -p "确认删除? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "$old_files" | while read file; do
                        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" && print_message $GREEN "✅ 已删除 $(basename "$file")"
                    done
                else
                    print_message $YELLOW "❌ 取消删除"
                fi
            else
                print_message $GREEN "✅ 没有找到30天前的日志文件"
            fi
            ;;
        4)
            print_message $RED "🚨 危险操作: 将删除所有Guard日志和报告文件！"
            read -p "请输入 'DELETE ALL' 确认删除所有日志: " confirm_input
            
            if [ "$confirm_input" = "DELETE ALL" ]; then
                rm -f "$PROJECT_DIR"/guard_*.log
                rm -f "$PROJECT_DIR"/daily_report_*.json
                print_message $GREEN "✅ 所有日志文件已删除"
            else
                print_message $YELLOW "❌ 确认文本不正确，取消删除"
            fi
            ;;
        0)
            print_message $YELLOW "❌ 取消清理操作"
            ;;
        *)
            print_message $RED "❌ 无效选择"
            ;;
    esac
}