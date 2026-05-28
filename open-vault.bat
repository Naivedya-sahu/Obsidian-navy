@echo off
:: open-vault.bat — NO BACKUP VERSION
:: Opens any folder as an Obsidian vault via right-click context menu.
:: Registry command: "C:\Users\%USERNAME%\AppData\Roaming\obsidian\open-vault.bat" "%1"
:: Place this file in %APPDATA%\obsidian\ alongside obsidian.json.

set "VAULT=%~1"
set "JSON=%~dp0obsidian.json"
set "OBS=C:\Program Files\Obsidian\Obsidian.exe"
set "TMP=%TEMP%\open_vault_%RANDOM%.ps1"

if "%VAULT%"=="" exit /b 1

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

start "" "%OBS%"
