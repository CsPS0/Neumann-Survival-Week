@echo off
rem Builds The Empty School on Windows.
rem Usage: tools\build.bat [--install-templates] [--release] [target ...]
rem Targets: linux windows windows-vr macos android quest. Groups: desktop (default) and all.
rem Set GODOT to the Godot 4.7 console binary, for example C:\Godot\Godot_v4.7.2-stable_win64_console.exe
rem For --release set GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD.
rem Output goes to build\<platform>\ and is never committed.
setlocal EnableDelayedExpansion

set "PROJECT=%~dp0.."
for %%I in ("%PROJECT%") do set "PROJECT=%%~fI"
set "PRESETS=%PROJECT%\export_presets.cfg"
set "CIPRESETS=%PROJECT%\..\.github\godot\export_presets.ci.cfg"
set "INSTALL=0"
set "RELEASE=0"
set "TARGETS="

:args
if "%~1"=="" goto argsdone
if /i "%~1"=="--install-templates" ( set "INSTALL=1" & shift & goto args )
if /i "%~1"=="--release" ( set "RELEASE=1" & shift & goto args )
if /i "%~1"=="desktop" ( set "TARGETS=!TARGETS! linux windows windows-vr" & shift & goto args )
if /i "%~1"=="all" ( set "TARGETS=!TARGETS! linux windows windows-vr macos android quest" & shift & goto args )
for %%T in (linux windows windows-vr macos android quest) do if /i "%~1"=="%%T" set "TARGETS=!TARGETS! %%T"
echo %TARGETS% | findstr /i /c:"%~1" >nul || ( echo Unknown argument: %~1 & exit /b 2 )
shift
goto args
:argsdone
if "%TARGETS%"=="" set "TARGETS=linux windows windows-vr"

rem 1. Find Godot.
if defined GODOT goto havegodot
for %%G in (godot.exe godot_console.exe) do if not defined GODOT for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GODOT set "GODOT=%%P"
if not defined GODOT for %%D in ("%USERPROFILE%\Godot" "C:\Godot" "%USERPROFILE%\Downloads") do if not defined GODOT for %%P in ("%%~D\Godot_v4.7*_win64_console.exe") do if exist "%%~P" set "GODOT=%%~P"
:havegodot
if not defined GODOT ( echo ERROR: Godot was not found. Install Godot 4.7.x or set GODOT to its console binary. & exit /b 1 )
if not exist "%GODOT%" ( echo ERROR: GODOT points to a missing file: %GODOT% & exit /b 1 )
set "FULLVER="
for /f "delims=" %%V in ('"%GODOT%" --version') do if not defined FULLVER set "FULLVER=%%V"
for /f "tokens=1-4 delims=." %%a in ("%FULLVER%") do (
  if /i "%%c"=="stable" ( set "VERSION=%%a.%%b.%%c" ) else set "VERSION=%%a.%%b.%%c.%%d"
)
if not "%VERSION:~0,3%"=="4.7" ( echo ERROR: Godot 4.7.x is required. Found: %FULLVER% & exit /b 1 )
echo Godot: %GODOT% (%FULLVER%)

rem 2. Check the export templates.
set "TPL=%APPDATA%\Godot\export_templates\%VERSION%"
if exist "%TPL%\version.txt" goto havetpl
for /f "tokens=1-3 delims=." %%a in ("%VERSION%") do (
  if /i "%%c"=="stable" ( set "TAG=%%a.%%b-stable" ) else set "TAG=%%a.%%b.%%c-stable"
)
set "URL=https://github.com/godotengine/godot-builds/releases/download/%TAG%/Godot_v%TAG%_export_templates.tpz"
if "%INSTALL%"=="0" (
  echo ERROR: Export templates for %VERSION% are missing.
  echo Run again with --install-templates, or download %URL% and unpack its templates folder into %TPL%
  exit /b 1
)
echo Downloading export templates, about 1.2 GB, from %URL%
set "TMPD=%TEMP%\tes_templates"
rmdir /s /q "%TMPD%" 2>nul
mkdir "%TMPD%"
curl -fL -o "%TMPD%\templates.zip" "%URL%" || ( echo ERROR: Template download failed. Use Editor, Manage Export Templates. & exit /b 1 )
tar -xf "%TMPD%\templates.zip" -C "%TMPD%" || ( echo ERROR: Could not unpack the templates. & exit /b 1 )
mkdir "%TPL%" 2>nul
xcopy /e /i /y /q "%TMPD%\templates\*" "%TPL%\" >nul
rmdir /s /q "%TMPD%"
:havetpl
echo Templates: %TPL%

rem 3. Make sure the presets file exists.
if not exist "%PRESETS%" (
  if not exist "%CIPRESETS%" ( echo ERROR: Neither %PRESETS% nor %CIPRESETS% exists. & exit /b 1 )
  copy /y "%CIPRESETS%" "%PRESETS%" >nul
  echo Copied the CI presets to HORROR-GAME\export_presets.cfg, which is gitignored.
)
echo %TARGETS% | findstr /i /c:"macos" >nul && (
  findstr /c:"name=\"macOS\"" "%PRESETS%" >nul || echo NOTE: no macOS preset in export_presets.cfg. The macos target will fail. Use tools/build.sh on a Linux or macOS machine, which adds it.
)

rem 4. Android prerequisites.
set "ANDROID_OK=1"
echo %TARGETS% | findstr /i /r /c:"android" /c:"quest" >nul && (
  set "SDK=%ANDROID_SDK_ROOT%"
  if not defined SDK set "SDK=%ANDROID_HOME%"
  if not defined SDK if exist "%LOCALAPPDATA%\Android\Sdk" set "SDK=%LOCALAPPDATA%\Android\Sdk"
  if not defined SDK ( echo SKIP android/quest: Android SDK not found. Set ANDROID_HOME. & set "ANDROID_OK=0" )
  if not defined JAVA_HOME ( echo SKIP android/quest: JDK 17 not found. Set JAVA_HOME. & set "ANDROID_OK=0" )
  set "SETTINGS=%APPDATA%\Godot\editor_settings-4.tres"
  if "!ANDROID_OK!"=="1" if "%RELEASE%"=="1" (
    if not defined GODOT_ANDROID_KEYSTORE_RELEASE_PATH ( echo SKIP android/quest: GODOT_ANDROID_KEYSTORE_RELEASE_PATH is not set. & set "ANDROID_OK=0" )
    if not defined GODOT_ANDROID_KEYSTORE_RELEASE_USER ( echo SKIP android/quest: GODOT_ANDROID_KEYSTORE_RELEASE_USER is not set. & set "ANDROID_OK=0" )
    if not defined GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD ( echo SKIP android/quest: GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD is not set. & set "ANDROID_OK=0" )
  )
  if "!ANDROID_OK!"=="1" if "%RELEASE%"=="0" (
    set "DK=%USERPROFILE%\.android\debug.keystore"
    if not exist "!DK!" (
      mkdir "%USERPROFILE%\.android" 2>nul
      "%JAVA_HOME%\bin\keytool" -genkey -v -keystore "!DK!" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >nul 2>&1 || ( echo SKIP android/quest: could not create the debug keystore. & set "ANDROID_OK=0" )
    )
    set "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=!DK!"
    set "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
    set "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
  )
  if "!ANDROID_OK!"=="1" if not exist "!SETTINGS!" (
    mkdir "%APPDATA%\Godot" 2>nul
    set "JH=%JAVA_HOME:\=/%"
    set "SD=!SDK:\=/!"
    set "DKF=%USERPROFILE:\=/%/.android/debug.keystore"
    (
      echo [gd_resource type="EditorSettings" format=3]
      echo.
      echo [resource]
      echo export/android/java_sdk_path = "!JH!"
      echo export/android/android_sdk_path = "!SD!"
      echo export/android/debug_keystore = "!DKF!"
      echo export/android/debug_keystore_user = "androiddebugkey"
      echo export/android/debug_keystore_pass = "android"
    ) > "!SETTINGS!"
    echo Wrote the Android paths to !SETTINGS!
  ) else if "!ANDROID_OK!"=="1" (
    findstr /c:"android_sdk_path" "!SETTINGS!" >nul || ( echo SKIP android/quest: !SETTINGS! has no Android SDK path. Set it in Editor Settings, Export, Android. & set "ANDROID_OK=0" )
  )
)

rem 5. Import, then export.
cd /d "%PROJECT%"
if not exist ".godot" (
  echo Importing the project, first run.
  "%GODOT%" --headless --path . --import >nul 2>&1
)
set "BUILT="
set "FAILED="
set "SKIPPED="
set "AKIND=--export-debug"
if "%RELEASE%"=="1" set "AKIND=--export-release"
for %%T in (%TARGETS%) do (
  if /i "%%T"=="linux" call :export linux "Linux/X11" build/linux/TheEmptySchool.x86_64 --export-release
  if /i "%%T"=="windows" call :export windows "Windows Desktop" build/windows/TheEmptySchool.exe --export-release
  if /i "%%T"=="windows-vr" call :export windows-vr "Windows VR" build/vr/TheEmptySchool_VR.exe --export-release
  if /i "%%T"=="macos" call :export macos "macOS" build/macos/TheEmptySchool.zip --export-release
  if /i "%%T"=="android" if "!ANDROID_OK!"=="1" ( call :export android "Android" build/mobile/TheEmptySchool.apk !AKIND! ) else set "SKIPPED=!SKIPPED! android"
  if /i "%%T"=="quest" if "!ANDROID_OK!"=="1" ( call :export quest "Android VR (Quest)" build/vr/TheEmptySchool_Quest.apk !AKIND! ) else set "SKIPPED=!SKIPPED! quest"
)
echo.
echo Built:  !BUILT!
echo Skipped:!SKIPPED!
echo Failed: !FAILED!
if defined FAILED exit /b 1
exit /b 0

:export
findstr /c:"name=\"%~2\"" "%PRESETS%" >nul || ( echo ERROR: preset %~2 is missing from export_presets.cfg. Delete HORROR-GAME\export_presets.cfg and run again. & set "FAILED=!FAILED! %~1" & exit /b 0 )
set "OUTFILE=%~3"
set "OUTDIR=%OUTFILE:/=\%"
for %%F in ("%OUTDIR%") do if not exist "%%~dpF" mkdir "%%~dpF"
del "%OUTDIR%" 2>nul
echo == %~1
"%GODOT%" --headless --path . %4 "%~2" "%~3"
if errorlevel 1 ( set "FAILED=!FAILED! %~1" & exit /b 0 )
if exist "%OUTDIR%" ( set "BUILT=!BUILT! %~1" ) else set "FAILED=!FAILED! %~1"
exit /b 0
