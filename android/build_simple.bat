@echo off
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
set ANDROID_HOME=C:\Users\Administrator\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\Administrator\AppData\Local\Android\Sdk

cd /d E:\AI-PRJ\shangdaren-game\android
call gradlew.bat assembleRelease

if exist "app\build\outputs\apk\release\app-release.apk" (
    echo BUILD SUCCESS
    copy "app\build\outputs\apk\release\app-release.apk" "E:\AI-PRJ\shangdaren-game\shangdaren.apk"
) else (
    echo BUILD FAILED
)
pause
