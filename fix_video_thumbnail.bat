@echo off
REM This script fixes the video_thumbnail plugin by editing its AndroidManifest.xml

SET PLUGIN_PATH=C:\Users\USER\AppData\Local\Pub\Cache\hosted\pub.dev\video_thumbnail-0.5.3\android

REM Path to the AndroidManifest.xml
SET MANIFEST_PATH=%PLUGIN_PATH%\src\main\AndroidManifest.xml

REM Check if the file exists
IF NOT EXIST "%MANIFEST_PATH%" (
  echo Error: Could not find AndroidManifest.xml at %MANIFEST_PATH%
  exit /b 1
)

REM Create a backup of the original file
copy "%MANIFEST_PATH%" "%MANIFEST_PATH%.bak"

REM Use PowerShell to modify the file
powershell -Command "(Get-Content '%MANIFEST_PATH%') -replace 'package=\"xyz.justsoft.video_thumbnail\"', '' | Set-Content '%MANIFEST_PATH%'"

REM Add namespace to build.gradle
powershell -Command "(Get-Content '%PLUGIN_PATH%\build.gradle') -replace 'android {', 'android { namespace \"xyz.justsoft.video_thumbnail\"' | Set-Content '%PLUGIN_PATH%\build.gradle'"

echo Finished modifying the AndroidManifest.xml and build.gradle
echo Now try building again with:
echo ./gradlew assembleDebug -x test