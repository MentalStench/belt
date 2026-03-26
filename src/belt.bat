@echo off
powershell.exe -WindowStyle Hidden -Command "Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','belt.ps1' -WindowStyle Hidden"
