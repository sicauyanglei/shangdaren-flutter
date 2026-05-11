@echo off
chcp 65001

echo ========================================
echo    Shangdaren Game APK Build Tool
echo ========================================
echo.

set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
set ANDROID_HOME=C:\Users\Administrator\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\Administrator\AppData\Local\Android\Sdk
set GRADLE_USER_HOME=C:\Users\Administrator\.gradle
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\build-tools\34.0.0;%PATH%

echo [1/5] Checking Java...
if exist "%JAVA_HOME%\bin\java.exe" (
    echo Java: OK
) else (
    echo ERROR: Java not found
    pause
    exit /b 1
)

echo.
echo [2/5] Checking Android SDK...
if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    echo Android SDK: OK
) else (
    echo ERROR: Android SDK not found
    pause
    exit /b 1
)

echo.
echo [3/5] Checking Gradle...
if exist "%GRADLE_USER_HOME%\wrapper\dists\gradle-8.14-all" (
    echo Gradle 8.14: OK
) else (
    echo WARNING: Gradle 8.14 not found
)

echo.
echo [4/5] Entering project directory...
cd /d E:\AI-PRJ\shangdaren-game\android
echo Current directory: %CD%

echo.
echo [5/5] Building APK...
echo Please wait...
echo.

call .\gradlew.bat assembleRelease --no-daemon 2>&1

echo.
echo ========================================
if exist "app\build\outputs\apk\release\app-release.apk" (
    echo.
    echo BUILD SUCCESS!
    echo.
    echo APK Location:
    echo E:\AI-PRJ\shangdaren-game\android\app\build\outputs\apk\release\app-release.apk
    
    copy /Y "app\build\outputs\apk\release\app-release.apk" "E:\AI-PRJ\shangdaren-game\shangdaren.apk" >nul 2>&1
    echo.
    echo Copied to: E:\AI-PRJ\shangdaren-game\shangdaren.apk
    echo.
) else (
    echo.
    echo BUILD FAILED
    echo.
)
echo ========================================
echo.
pause
