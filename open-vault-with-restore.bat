@echo off
:: open-vault-with-restore.bat — BACKUP + AUTO-RESTORE VERSION
:: Opens any folder as Obsidian vault via context menu.
:: Backs up obsidian.json before modifying it.
:: Spawns a hidden background watcher that restores the backup after Obsidian closes.
:: Result: context-menu vault session is ephemeral — original vault list restored on exit.
::
:: Registry command: "C:\Users\%USERNAME%\AppData\Roaming\obsidian\open-vault-with-restore.bat" "%1"
:: Place this file in %APPDATA%\obsidian\ alongside obsidian.json.

set "VAULT=%~1"
set "JSON=%~dp0obsidian.json"
set "OBS=C:\Program Files\Obsidian\Obsidian.exe"
set "TMP=%TEMP%\open_vault_%RANDOM%.ps1"
set "RST=%TEMP%\obs_restore_%RANDOM%.ps1"

if "%VAULT%"=="" exit /b 1

:: Backup current obsidian.json ONLY if no backup already exists.
:: Guard prevents a second context-menu invoke from overwriting the original backup
:: with an already-modified JSON (which would permanently lose the real original state).
if not exist "%JSON%.bak" copy "%JSON%" "%JSON%.bak" >nul 2>&1

:: Create .obsidian dir so Obsidian recognises this folder as a vault
if not exist "%VAULT%\.obsidian\" mkdir "%VAULT%\.obsidian"

:: Kill Obsidian — must stop before editing JSON or it overwrites changes on exit
taskkill /F /IM Obsidian.exe >nul 2>&1
timeout /t 1 /nobreak >nul

:: Write PowerShell logic to temp file.
:: Paths travel via env vars (VAULT, JSON) — zero quoting issues across the shell boundary.
:: ^| escapes CMD pipe — written as | in the PS file.
echo $vp = $env:VAULT.TrimEnd('\')                                                         > "%TMP%"
echo $jp = $env:JSON                                                                       >> "%TMP%"
echo $c  = Get-Content $jp -Raw ^| ConvertFrom-Json                                       >> "%TMP%"
echo if ('vaults' -notin $c.PSObject.Properties.Name) {                                   >> "%TMP%"
echo   $c ^| Add-Member NoteProperty 'vaults' ([PSCustomObject]@{})                       >> "%TMP%"
echo }                                                                                     >> "%TMP%"
echo $tid = $null                                                                          >> "%TMP%"
echo foreach ($id in $c.vaults.PSObject.Properties.Name) {                                >> "%TMP%"
echo   $v = $c.vaults.$id                                                                  >> "%TMP%"
echo   if (('path' -in $v.PSObject.Properties.Name) -and                                  >> "%TMP%"
echo       ($v.path.TrimEnd('\') -ieq $vp)) { $tid = $id; break }                        >> "%TMP%"
echo }                                                                                     >> "%TMP%"
echo if (-not $tid) {                                                                      >> "%TMP%"
echo   $b = New-Object byte[] 8                                                            >> "%TMP%"
echo   [Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($b)               >> "%TMP%"
echo   $tid = ([BitConverter]::ToString($b) -replace '-').ToLower()                       >> "%TMP%"
echo   $e = [PSCustomObject]@{                                                             >> "%TMP%"
echo     path = $vp                                                                        >> "%TMP%"
echo     ts   = [double][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()                 >> "%TMP%"
echo   }                                                                                   >> "%TMP%"
echo   $c.vaults ^| Add-Member NoteProperty $tid $e                                       >> "%TMP%"
echo }                                                                                     >> "%TMP%"
echo foreach ($id in $c.vaults.PSObject.Properties.Name) {                                >> "%TMP%"
echo   $v = $c.vaults.$id                                                                  >> "%TMP%"
echo   if ($id -eq $tid) {                                                                 >> "%TMP%"
echo     if ('open' -in $v.PSObject.Properties.Name) { $v.open = $true }                  >> "%TMP%"
echo     else { $v ^| Add-Member NoteProperty 'open' $true }                              >> "%TMP%"
echo   } else {                                                                            >> "%TMP%"
echo     if ('open' -in $v.PSObject.Properties.Name) {                                    >> "%TMP%"
echo       $v.PSObject.Properties.Remove('open')                                          >> "%TMP%"
echo     }                                                                                 >> "%TMP%"
echo   }                                                                                   >> "%TMP%"
echo }                                                                                     >> "%TMP%"
echo [IO.File]::WriteAllText($jp, ($c ^| ConvertTo-Json -Depth 10 -Compress), [Text.UTF8Encoding]::new($false)) >> "%TMP%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP%"
del "%TMP%" >nul 2>&1

:: Launch Obsidian
start "" "%OBS%"

:: Write background restore watcher to temp file, then launch it hidden.
:: Watcher polls until no Obsidian process remains, then restores the backup.
:: Uses WriteAllBytes (raw copy) — no encoding layer, byte-identical restore.
echo $jp  = $env:JSON                                                                      > "%RST%"
echo $bak = $jp + '.bak'                                                                   >> "%RST%"
echo while (Get-Process -Name 'Obsidian' -ErrorAction SilentlyContinue) {                 >> "%RST%"
echo   Start-Sleep -Seconds 2                                                              >> "%RST%"
echo }                                                                                     >> "%RST%"
echo Start-Sleep -Seconds 1                                                                >> "%RST%"
echo if (Test-Path $bak) {                                                                 >> "%RST%"
echo   [IO.File]::WriteAllBytes($jp, [IO.File]::ReadAllBytes($bak))                       >> "%RST%"
echo   Remove-Item $bak -Force                                                             >> "%RST%"
echo }                                                                                     >> "%RST%"
echo Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue        >> "%RST%"

start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%RST%"
