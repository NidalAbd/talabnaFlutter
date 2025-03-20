@echo off
REM This script builds the Android project while skipping tests

echo Building Android project (skipping tests)...
cd android
call ./gradlew assembleDebug -x test -x testDebugUnitTest -x testReleaseUnitTest --no-daemon

if %ERRORLEVEL% EQU 0 (
  echo Build completed successfully!
) else (
  echo Build failed with error code: %ERRORLEVEL%
)

pause