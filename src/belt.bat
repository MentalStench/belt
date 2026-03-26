@echo off
powershell.exe -WindowStyle Hidden -Command "Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0belt.ps1' -WindowStyle Hidden"
