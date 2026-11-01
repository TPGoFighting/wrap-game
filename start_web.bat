@echo off
chcp 65001 >nul
title WRAP 星际远征 Web版 本地服务

echo =================================================
echo    WRAP · 星际远征 v0.9.0 - Web 浏览器启动脚本
echo =================================================

cd /d "%~dp0"

where node >nul 2>nul
if %errorlevel% equ 0 (
    echo 使用 Node.js 启动服务...
    start "" /b node server.js
    goto launch
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    echo 使用 Python 启动服务...
    start "" /b python server.py
    goto launch
)

where python3 >nul 2>nul
if %errorlevel% equ 0 (
    echo 使用 Python3 启动服务...
    start "" /b python3 server.py
    goto launch
)

echo 错误: 未检测到 Node.js 或 Python 环境。
echo 请安装 Node.js 或 Python 后重新运行此脚本。
pause
exit /b 1

:launch
timeout /t 2 /nobreak >nul
echo 正在打开默认浏览器 (推荐 Chrome)...
start http://localhost:8080

echo.
echo 服务正在运行中...
echo 浏览器中输入: http://localhost:8080
echo 如需关闭服务，直接关闭此窗口即可。
pause >nul
