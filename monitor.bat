@echo off
title 上大人 - 日志监听
echo ========================================
echo   上大人游戏 - BlueStacks 日志监听
echo ========================================
echo.
echo 用法: monitor [过滤标签] [日志级别]
echo.
echo 示例:
echo   monitor           监听所有游戏日志
echo   monitor ZHAO      只看招牌相关日志
echo   monitor RESP      只看响应按钮相关日志
echo   monitor SDR ERROR 只看错误日志
echo.

if "%~1"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0monitor-logs.ps1" -SaveToFile
) else if "%~2"=="" (
    powershell -ExecutionPolicy Bypass -File "%~dp0monitor-logs.ps1" -Filter %1 -SaveToFile
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0monitor-logs.ps1" -Filter %1 -Level %2 -SaveToFile
)
pause
