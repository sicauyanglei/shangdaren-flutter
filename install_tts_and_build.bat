@echo off
chcp 65001 >nul
echo ========================================
echo 安装 Capacitor TTS 插件并重新构建 APK
echo ========================================

echo.
echo [1/4] 安装 capacitor-tts 插件...
call npm install @capacitor-community/text-to-speech

echo.
echo [2/4] 同步 Capacitor 项目...
call npx cap sync android

echo.
echo [3/4] 复制 web 文件到 Android assets...
xcopy /E /Y /I web android\app\src\main\assets\public

echo.
echo [4/4] 构建 APK...
cd android
call gradlew assembleDebug

echo.
echo ========================================
echo 构建完成！
echo APK 位置: android\app\build\outputs\apk\debug\app-debug.apk
echo ========================================
pause
