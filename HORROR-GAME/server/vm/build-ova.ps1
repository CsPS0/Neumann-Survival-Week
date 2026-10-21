<#
.SYNOPSIS
Builds server/vm/output/TheEmptySchoolServer.ova using Packer and VirtualBox.

.PARAMETER Memory
RAM allocated to the VM in MB. Default is 1024.

.EXAMPLE
.\build-ova.ps1
.\build-ova.ps1 -Memory 2048
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [int]$Memory = 1024
)

$ErrorActionPreference = "Stop"

$vmDir = $PSScriptRoot
$gameDir = (Resolve-Path "$vmDir/../..").Path

# Locate VirtualBox and Packer in common Windows paths if missing from PATH
if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe") {
        $env:Path = "C:\Program Files\Oracle\VirtualBox;" + $env:Path
    } elseif ($env:VBOX_MSI_INSTALL_PATH -and (Test-Path "$env:VBOX_MSI_INSTALL_PATH\VBoxManage.exe")) {
        $env:Path = "$env:VBOX_MSI_INSTALL_PATH;" + $env:Path
    }
}

if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
    if (Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Links\packer.exe") {
        $env:Path = "$env:LOCALAPPDATA\Microsoft\WinGet\Links;" + $env:Path
    }
}

foreach ($tool in @("packer", "VBoxManage", "tar")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "$tool was not found. Please ensure it is installed and in your PATH."
        exit 1
    }
}

$tempDir = Join-Path $env:TEMP ("empty-school-vm-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$context = Join-Path $tempDir "game-context.tar"

try {
    Write-Host "Creating game context archive at $context..." -ForegroundColor Cyan
    & tar -C "$gameDir" --exclude=./.godot --exclude=./build --exclude=./docs --exclude=./server/vm/output --exclude=./scripts/staff.gd -cf "$context" .
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create game context archive."
    }

    $outputDir = Join-Path $vmDir "output"
    if (Test-Path $outputDir) {
        Remove-Item -Path $outputDir -Recurse -Force
    }

    Push-Location $vmDir
    try {
        Write-Host "Initializing Packer plugins..." -ForegroundColor Cyan
        & packer init neumann-vm.pkr.hcl
        if ($LASTEXITCODE -ne 0) {
            throw "packer init failed."
        }

        Write-Host "Building VM image with $Memory MB RAM (this may take 20-40 minutes)..." -ForegroundColor Cyan
        & packer build -var "game_context=$context" -var "memory_mb=$Memory" neumann-vm.pkr.hcl
        if ($LASTEXITCODE -ne 0) {
            throw "packer build failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }

    $targetOva = Join-Path $outputDir "TheEmptySchoolServer.ova"
    $ovaFiles = Get-ChildItem -Path $outputDir -Filter "*.ova" -ErrorAction SilentlyContinue
    foreach ($file in $ovaFiles) {
        if ($file.FullName -ne $targetOva) {
            Move-Item -Path $file.FullName -Destination $targetOva -Force
        }
    }

    Write-Host "Done: $targetOva" -ForegroundColor Green
} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
