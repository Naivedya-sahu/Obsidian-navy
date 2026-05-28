@echo off
:: Launcher — runs install.ps1 with elevation prompt.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
