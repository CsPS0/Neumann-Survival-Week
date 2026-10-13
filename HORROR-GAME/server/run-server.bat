@echo off
rem Starts the headless co-op server on Windows.
rem Usage: server\run-server.bat [--port 7777] [--max-players 4] [--public-host 203.0.113.5]
rem Set GODOT to the Godot 4.7 executable when it is not on the PATH.
setlocal
set "PROJECT_DIR=%~dp0.."
if "%GODOT%"=="" set "GODOT=godot"

where "%GODOT%" >nul 2>nul
if errorlevel 1 (
	if not exist "%GODOT%" (
		echo Godot was not found. Install Godot 4.7 or set GODOT to its path.
		exit /b 1
	)
)

"%GODOT%" --headless --path "%PROJECT_DIR%" res://scenes/dedicated_server.tscn -- %*
endlocal
