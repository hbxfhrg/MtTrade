@echo off
echo 正在启动订单和成交记录读取器...
echo.
cd /d "%~dp0"
dist\ReadReport.exe
echo.
echo 程序已退出。
pause