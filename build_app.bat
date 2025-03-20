@echo off
REM This script builds the Android app with optimized settings

echo Stopping any running Gradle daemons...
cd android
call ./gradlew --stop

echo Cleaning project...
call ./gradlew clean

echo Building the app...
call ./gradlew assembleDebug --no-daemon -x lint -x test -Pkotlin.daemon.enabled=false

if %ERRORLEVEL% EQU 0 (
  echo Build completed successfully!
  echo APK should be available at android/app/build/outputs/apk/debug/app-debug.apk
) else (
  echo Build failed with error code: %ERRORLEVEL%
)

pause