#!/bin/bash
# FinalUnlock 一键安装脚本


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/manage.sh" ]]; then
    echo "错误: 找不到 manage.sh 文件"
    exit 1
fi

chmod +x "$SCRIPT_DIR/manage.sh"
exec "$SCRIPT_DIR/manage.sh" install