@echo off
where pwsh.exe >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('PowerShell 7 is required to run Belt but was not found on this machine. Click OK to open the install page in your browser.', 'Belt — Missing Prerequisite', 'OK', 'Warning'); Start-Process 'https://aka.ms/install-powershell'"
    exit /b 1
)
set pathToBelt="%~dp0belt.ps1"
echo %pathToBelt%
powershell.exe -WindowStyle Hidden -Command "Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%pathToBelt%' -WindowStyle Hidden"