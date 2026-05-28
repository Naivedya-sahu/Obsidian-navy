# install.ps1 — Obsidian Context Menu Installer / Uninstaller
# Requires Administrator (writes to HKEY_CLASSES_ROOT).

# ── Self-elevate if not running as admin ──────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal]
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$src    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dest   = Join-Path $env:APPDATA 'obsidian'
$obsExe = 'C:\Program Files\Obsidian\Obsidian.exe'
$regPath = 'Directory\shell\Obsidian'

function Write-Header {
    Clear-Host
    Write-Host ''
    Write-Host '  Obsidian Context Menu' -ForegroundColor Cyan
    Write-Host '  ─────────────────────' -ForegroundColor DarkGray
    Write-Host ''
}

# ── Main menu ─────────────────────────────────────────────────────────────────
Write-Header
Write-Host '  [1]  Install  -  Basic version'
Write-Host '         Vault stays in Obsidian list permanently after session.'
Write-Host ''
Write-Host '  [2]  Install  -  With Auto-Restore version'
Write-Host '         Vault entry auto-removed from list after Obsidian closes.'
Write-Host '         Original vault state (GUI-configured) is preserved.'
Write-Host ''
Write-Host '  [3]  Uninstall context menu'
Write-Host ''
$choice = Read-Host '  Enter choice (1/2/3)'

# ── Uninstall ─────────────────────────────────────────────────────────────────
if ($choice -eq '3') {
    try {
        [Microsoft.Win32.Registry]::ClassesRoot.DeleteSubKeyTree($regPath, $false)
        Write-Host ''
        Write-Host '  Uninstalled successfully.' -ForegroundColor Yellow
    } catch {
        Write-Host ''
        Write-Host "  Not installed or already removed." -ForegroundColor DarkGray
    }
    Write-Host ''
    Read-Host '  Press Enter to exit'
    exit
}

# ── Install ───────────────────────────────────────────────────────────────────
$batSrc = switch ($choice) {
    '1' { Join-Path $src 'open-vault.bat' }
    '2' { Join-Path $src 'open-vault-with-restore.bat' }
    default {
        Write-Host '  Invalid choice.' -ForegroundColor Red
        Read-Host '  Press Enter to exit'
        exit 1
    }
}

if (-not (Test-Path $batSrc)) {
    Write-Host ''
    Write-Host "  ERROR: $([IO.Path]::GetFileName($batSrc)) not found next to install.ps1." -ForegroundColor Red
    Write-Host '  Make sure all repo files are in the same folder.' -ForegroundColor DarkGray
    Write-Host ''
    Read-Host '  Press Enter to exit'
    exit 1
}

# Copy BAT to %APPDATA%\obsidian\ (same folder as obsidian.json)
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
$batDest = Join-Path $dest 'open-vault.bat'
Copy-Item $batSrc $batDest -Force

# Write registry keys using .NET API — no quoting issues with spaces or %1
$verbKey = [Microsoft.Win32.Registry]::ClassesRoot.CreateSubKey($regPath)
$verbKey.SetValue('', 'Obsidian', [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.SetValue('Icon', $obsExe, [Microsoft.Win32.RegistryValueKind]::String)
$verbKey.Close()

$cmdKey = [Microsoft.Win32.Registry]::ClassesRoot.CreateSubKey("$regPath\command")
$cmdKey.SetValue('', "`"$batDest`" `"%1`"", [Microsoft.Win32.RegistryValueKind]::String)
$cmdKey.Close()

Write-Host ''
Write-Host '  Installed successfully!' -ForegroundColor Green
Write-Host "  BAT  ->  $batDest" -ForegroundColor DarkGray
Write-Host "  HKCR ->  $regPath" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Right-click any folder in Explorer to see "Obsidian".' -ForegroundColor Cyan
Write-Host ''
Read-Host '  Press Enter to exit'
