@echo off
start "Ameba LED Control" powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0ui\Led-Control.ps1"
