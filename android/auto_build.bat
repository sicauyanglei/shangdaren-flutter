@echo off
chcp 65001
title 上大人游戏 APK 自动构建
color 0A

echo ========================================
echo    上大人游戏 APK 自动构建工具
echo ========================================
echo.

REM 设置环境变量
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
set ANDROID_HOME=C:\Users\Administrator\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\Administrator\AppData\Local\Android\Sdk
set GRADLE_USER_HOME=C:\Users\Administrator\.gradle
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\build-tools\34.0.0;%PATH%

echo [步骤 1/5] 检测 Java 环境...
if exist "%JAVA_HOME%\bin\java.exe" (
    echo Java 路径: %JAVA_HOME%
    "%JAVA_HOME%\bin\java.exe" -version 2>&1 | findstr "version"
    echo Java: OK
) else (
    echo 错误: Java 未找到
    echo 请确认 Java 安装在: %JAVA_HOME%
    pause
    exit /b 1
)

echo.
echo [步骤 2/5] 检测 Android SDK...
if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    echo Android SDK: %ANDROID_HOME%
    echo Android SDK: OK
) else (
    echo 错误: Android SDK 未找到
    echo 请确认 Android SDK 安装在: %ANDROID_HOME%
    pause
    exit /b 1
)

echo.
echo [步骤 3/5] 检测 Gradle...
if exist "%GRADLE_USER_HOME%\wrapper\dists\gradle-8.14-all" (
    echo Gradle 8.14 已下载
    echo Gradle: OK
) else (
    echo 警告: Gradle 8.14 未找到，可能需要下载
)

echo.
echo [步骤 4/5] 进入项目目录...
cd /d E:\AI-PRJ\shangdaren-game\android
echo 当前目录: %CD%

echo.
echo [步骤 5/5] 开始构建 APK...
echo 这可能需要几分钟，请耐心等待...
echo.

call .\gradlew.bat assembleRelease --no-daemon -q 2>&1

echo.
echo ========================================
if exist "app\build\outputs\apk\release\app-release.apk" (
    color 0A
    echo.
    echo          构建成功!
    echo.
    for %%I in ("app\build\outputs\apk\release\app-release.apk") do echo APK 大小: %%~zI 字节
    echo.
    echo APK 位置:
    echo E:\AI-PRJ\shangdaren-game\android\app\build\outputs\apk\release\app-release.apk
    
    copy /Y "app\build\outputs\apk\release\app-release.apk" "E:\AI-PRJ\shangdaren-game\shangdaren.apk" >nul 2>&1
    echo.
    echo 已复制到: E:\AI-PRJ\shangdaren-game\shangdaren.apk
    echo.
) else (
    color 0C
    echo.
    echo          构建失败
    echo.
    echo 请检查以下可能的问题:
    echo 1. Gradle 是否正确下载
    echo 2. Android SDK 是否完整
    echo 3. 网络连接是否正常
    echo.
    echo 尝试不带 --offline 参数重新运行...
    call .\gradlew.bat assembleRelease --no-daemon 2>&1
    
    if exist "app\build\outputs\apk\release\app-release.apk" (
        color 0A
        echo.
        echo          第二次构建成功!
        copy /Y "app\build\outputs\apk\release\app-release.apk" "E:\AI-PRJ\shangdaren-game\shangdaren.apk" >nul 2>&1
        echo 已复制到: E:\AI-PRJ\shangdaren-game\shangdaren.apk
    )
)
echo ========================================
echo.
echo 按任意键退出...
pause >nul
