#!/usr/bin/env bash
cd "$(dirname "$0")"

echo "================================================="
echo "   WRAP · 星际远征 v0.9.0 - Web 浏览器启动脚本"
echo "================================================="

PORT=8080

if command -v node >/dev/null 2>&1; then
    echo "使用 Node.js 高性能服务器启动..."
    node server.js &
elif command -v python3 >/dev/null 2>&1; then
    echo "使用 Python3 服务器启动..."
    python3 server.py &
else
    echo "错误: 未找到 Node.js 或 Python3，请先安装其中任意一个环境。"
    exit 1
fi

SERVER_PID=$!
sleep 1

URL="http://localhost:$PORT"
echo "正在打开 Chrome 浏览器游玩: $URL"

if [ "$(uname)" = "Darwin" ]; then
    open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL"
else
    google-chrome "$URL" 2>/dev/null || xdg-open "$URL" 2>/dev/null
fi

echo "提示: 按 Ctrl+C 停止本地服务。"
wait $SERVER_PID
