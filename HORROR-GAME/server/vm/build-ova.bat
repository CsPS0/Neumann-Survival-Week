@echo off
rem Builds server\vm\output\TheEmptySchoolServer.ova.
rem Usage: server\vm\build-ova.bat [memory in MB]
setlocal enabledelayedexpansion

if "%~1"=="-h" goto help
if "%~1"=="--help" goto help

set "VM_DIR=%~dp0"
if "%VM_DIR:~-1%"=="\" set "VM_DIR=%VM_DIR:~0,-1%"
set "GAME_DIR=%VM_DIR%\..\.."
set "MEMORY=%~1"
if "%MEMORY%"=="" set "MEMORY=1024"

rem Find VirtualBox
where VBoxManage >nul 2>nul
if errorlevel 1 (
	if exist "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" (
		set "PATH=C:\Program Files\Oracle\VirtualBox;!PATH!"
	) else if defined VBOX_MSI_INSTALL_PATH (
		set "PATH=%VBOX_MSI_INSTALL_PATH%;!PATH!"
	)
)

rem Find Packer
where packer >nul 2>nul
if errorlevel 1 (
	if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\packer.exe" (
		set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Links;!PATH!"
	)
)

where packer >nul 2>nul
if errorlevel 1 (
	echo packer was not found. Please install Packer (e.g. winget install Hashicorp.Packer).
	exit /b 1
)

where VBoxManage >nul 2>nul
if errorlevel 1 (
	echo VBoxManage was not found. Please install VirtualBox.
	exit /b 1
)

where tar >nul 2>nul
if errorlevel 1 (
	echo tar was not found. Windows 10/11 tar.exe is required.
	exit /b 1
)

set "TEMP_DIR=%TEMP%\empty-school-vm-%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul
set "CONTEXT=%TEMP_DIR%\game-context.tar"

echo Creating game context archive at %CONTEXT%...
tar -C "%GAME_DIR%" --exclude=./.godot --exclude=./build --exclude=./docs --exclude=./server/vm/output --exclude=./scripts/staff.gd -cf "%CONTEXT%" .
if errorlevel 1 (
	echo Failed to create game context archive.
	del /f /q "%CONTEXT%" 2>nul
	rmdir "%TEMP_DIR%" 2>nul
	exit /b 1
)

if exist "%VM_DIR%\output" rmdir /s /q "%VM_DIR%\output"
cd /d "%VM_DIR%"

echo Initializing Packer plugins...
packer init neumann-vm.pkr.hcl
if errorlevel 1 (
	del /f /q "%CONTEXT%" 2>nul
	rmdir "%TEMP_DIR%" 2>nul
	exit /b %errorlevel%
)

echo Building VM image (this may take 20-40 minutes)...
packer build -var "game_context=%CONTEXT%" -var "memory_mb=%MEMORY%" neumann-vm.pkr.hcl
set "BUILD_STATUS=%errorlevel%"

del /f /q "%CONTEXT%" 2>nul
rmdir "%TEMP_DIR%" 2>nul

if %BUILD_STATUS% equ 0 (
	for %%F in ("%VM_DIR%\output\*.ova") do (
		if not "%%~nxF"=="TheEmptySchoolServer.ova" (
			move /y "%%F" "%VM_DIR%\output\TheEmptySchoolServer.ova" >nul 2>nul
		)
	)
	echo Done: %VM_DIR%\output\TheEmptySchoolServer.ova
) else (
	echo Packer build failed with exit code %BUILD_STATUS%.
	exit /b %BUILD_STATUS%
)
goto :eof

:help
echo Usage: %~nx0 [memory in MB]
exit /b 0
