@echo off
echo Using local Gradle 8.14...

set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
set ANDROID_HOME=C:\Users\Administrator\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\Administrator\AppData\Local\Android\Sdk
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%

set GRADLE_HOME=C:\Users\Administrator\.gradle\wrapper\dists\gradle-8.14-all\8mguqc37c200i71ledpgw8n5m\gradle-8.14
set PATH=%GRADLE_HOME%\bin;%PATH%

cd /d E:\AI-PRJ\shangdaren-game\android

echo Running Gradle build...
call "%GRADLE_HOME%\bin\gradle.bat" assembleRelease --no-daemon

if exist "app\build\outputs\apk\release\app-release.apk" (
    echo.
    echo BUILD SUCCESS!
    copy "app\build\outputs\apk\release\app-release.apk" "E:\AI-PRJ\shangdaren-game\shangdaren.apk"
    echo APK: E:\AI-PRJ\shangdaren-game\shangdaren.apk
) else (
    echo BUILD FAILED
)
pause
