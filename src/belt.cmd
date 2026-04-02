@echo off

where pwsh.exe >nul 2>&1
if %errorlevel% neq 0 (
    powershell.exe -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('PowerShell 7 is required to run Belt but was not found on this machine. Click OK to open the install page in your browser.', 'Belt — Missing Prerequisite', 'OK', 'Warning'); Start-Process 'https://aka.ms/install-powershell'"
    exit /b 1
)

set "BELT_SRC=%~dp0"
powershell.exe -WindowStyle Hidden -Command "& { $src = $env:BELT_SRC.TrimEnd('\'); $temp = Join-Path $env:TEMP 'Belt'; New-Item $temp -ItemType Directory -Force | Out-Null; $destPs1 = Join-Path $temp 'belt.ps1'; try { $srcPs1 = Join-Path $src 'belt.ps1'; if (-not (Test-Path $destPs1) -or (Get-Item $srcPs1).LastWriteTime -gt (Get-Item $destPs1).LastWriteTime) { Copy-Item $srcPs1 $destPs1 -Force }; $json = Get-Content (Join-Path $src 'belt.json') -Raw | ConvertFrom-Json; $toolPaths = @($json.toolPaths); $localPaths = @(); foreach ($tp in $toolPaths) { if (-not [System.IO.Path]::IsPathRooted($tp)) { $tp = Join-Path $src $tp }; $leafName = Split-Path $tp -Leaf; $destFolder = Join-Path $temp $leafName; robocopy $tp $destFolder /MIR /XO /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null; $localPaths += './' + $leafName }; [pscustomobject]@{ toolPaths = $localPaths } | ConvertTo-Json | Set-Content (Join-Path $temp 'belt.json') -Encoding UTF8 } catch { } ; if (Test-Path $destPs1) { Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',\"`\"$destPs1`\"\" -WindowStyle Hidden } }"
