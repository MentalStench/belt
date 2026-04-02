#Requires -Version 7.0
#Requires -PSEdition Core

<#
.SYNOPSIS
    Belt — PowerShell 7+ WPF tool launcher.

.DESCRIPTION
    Reads .ps1 tool scripts from configured folders, displays each as a button
    in a wrapping grid, and launches them as isolated pwsh.exe processes on click.

.NOTES
    Requires Windows (WPF). Run with pwsh.exe (PowerShell 7+).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# WPF assembly loading — must happen before any WPF types are referenced
# ---------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$script:ScriptRoot   = $PSScriptRoot
$script:ConfigPath   = Join-Path $script:ScriptRoot 'belt.json'

$script:DefaultConfig = [ordered]@{
    toolPaths = @()
}

# ---------------------------------------------------------------------------
# Configuration helpers
# ---------------------------------------------------------------------------
function Read-Config {
    if (-not (Test-Path $script:ConfigPath)) {
        Write-Config $script:DefaultConfig
    }

    try {
        $raw = Get-Content -Raw -Path $script:ConfigPath -Encoding UTF8
        $obj = $raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Warning "belt.json is malformed; reverting to defaults. ($_)"
        $obj = $script:DefaultConfig
    }

    # Ensure required keys exist (forward-compat: file may lack newer keys)
    if (-not $obj.ContainsKey('toolPaths') -or $null -eq $obj['toolPaths']) {
        $obj['toolPaths'] = @()
    }

    return $obj
}

function Write-Config {
    param([hashtable]$Config)
    try {
        $Config | ConvertTo-Json -Depth 5 | Set-Content -Path $script:ConfigPath -Encoding UTF8 -Force
    }
    catch {
        Write-Warning "Could not save belt.json: $_"
    }
}

# ---------------------------------------------------------------------------
# Tool script metadata parsing
# ---------------------------------------------------------------------------
function ConvertTo-TitleCase {
    param([string]$Input)
    # PascalCase / kebab-case / snake_case → "Title Case With Spaces"
    # 1. Replace hyphens/underscores with spaces
    $s = $Input -replace '[-_]', ' '
    # 2. Insert space before capital letters that follow a lowercase letter (PascalCase)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, '([a-z])([A-Z])', '$1 $2')
    # 3. Title-case each word
    $words = $s -split '\s+' | Where-Object { $_ -ne '' } | ForEach-Object {
        if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
    }
    return $words -join ' '
}

function Read-ToolMetadata {
    param([string]$FilePath)

    $meta = @{
        FilePath    = $FilePath
        Name        = ''
        Description = ''
        Icon        = ''
        Category    = ''
        Type        = 'gui'
        HasMetadata = $false
    }

    # Derive fallback name from filename (strip extension)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $meta.Name = ConvertTo-TitleCase $baseName

    try {
        $lines = Get-Content -Path $FilePath -TotalCount 50 -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        return [pscustomobject]$meta
    }

    $foundAny = $false

    foreach ($line in $lines) {
        # Stop at first non-comment, non-blank line
        if ($line -match '^\s*$') { continue }
        if ($line -notmatch '^\s*#') { break }

        if ($line -match '^\s*#\s*TOOL_NAME\s*:\s*(.+)$') {
            $meta.Name        = $Matches[1].Trim()
            $foundAny         = $true
        }
        elseif ($line -match '^\s*#\s*TOOL_DESC\s*:\s*(.+)$') {
            $meta.Description = $Matches[1].Trim()
            $foundAny         = $true
        }
        elseif ($line -match '^\s*#\s*TOOL_ICON\s*:\s*(.+)$') {
            $meta.Icon        = $Matches[1].Trim()
            $foundAny         = $true
        }
        elseif ($line -match '^\s*#\s*TOOL_CATEGORY\s*:\s*(.+)$') {
            $meta.Category    = $Matches[1].Trim()
            $foundAny         = $true
        }
        elseif ($line -match '^\s*#\s*TOOL_TYPE\s*:\s*(gui|console)\s*$') {
            $meta.Type        = $Matches[1].Trim().ToLower()
            $foundAny         = $true
        }
    }

    $meta.HasMetadata = $foundAny
    return [pscustomobject]$meta
}

# ---------------------------------------------------------------------------
# Folder scanning
# ---------------------------------------------------------------------------
function Get-ToolList {
    param([string[]]$ToolPaths)

    # Use ordered hashtable for last-wins dedup by base filename
    $seen = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($rawPath in $ToolPaths) {
        # Resolve relative paths from $PSScriptRoot
        if (-not [System.IO.Path]::IsPathRooted($rawPath)) {
            $resolvedPath = Join-Path $script:ScriptRoot $rawPath
        }
        else {
            $resolvedPath = $rawPath
        }

        if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
            continue   # skip silently
        }

        $scripts = Get-ChildItem -LiteralPath $resolvedPath -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $scripts) {
            $seen[$file.Name] = $file.FullName
        }
    }

    $tools = @(foreach ($filePath in $seen.Values) {
        Read-ToolMetadata -FilePath $filePath
    })

    if ($tools.Count -eq 0) { return @() }

    # Sort alphabetically by display name
    return @($tools | Sort-Object Name)
}

# ---------------------------------------------------------------------------
# Process tracking
# ---------------------------------------------------------------------------
$script:RunningProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Add-TrackedProcess {
    param([System.Diagnostics.Process]$Process)
    $script:RunningProcesses.Add($Process)
}

function Get-RunningCount {
    # Prune exited processes and return live count
    $alive = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
    foreach ($p in $script:RunningProcesses) {
        try {
            if (-not $p.HasExited) { $alive.Add($p) }
        }
        catch {
            # Process handle may be invalid; treat as exited
        }
    }
    $script:RunningProcesses = $alive
    return $script:RunningProcesses.Count
}

function Stop-AllTrackedProcesses {
    foreach ($p in $script:RunningProcesses) {
        try {
            if (-not $p.HasExited) { $p.Kill() }
        }
        catch { }
    }
    $script:RunningProcesses.Clear()
}

# ---------------------------------------------------------------------------
# Tool launching
# ---------------------------------------------------------------------------
function Invoke-Tool {
    param(
        [pscustomobject]$Tool,
        [System.Windows.Window]$OwnerWindow
    )

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($Tool.FilePath)`"")

    $startParams = @{
        FilePath     = 'pwsh.exe'
        ArgumentList = $argList
        PassThru     = $true
        ErrorAction  = 'Stop'
    }

    if ($Tool.Type -eq 'gui') {
        $startParams['WindowStyle'] = 'Hidden'
    }
    # console type: no WindowStyle override (defaults to Normal)

    try {
        $proc = Start-Process @startParams
    }
    catch {
        [System.Windows.MessageBox]::Show(
            $OwnerWindow,
            "Failed to launch '$($Tool.Name)'.`n`nError: $_",
            'Belt — Launch Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
        return
    }

    Add-TrackedProcess -Process $proc

    # Async: check for immediate failure (give script ~1.5 s to start)
    $toolName  = $Tool.Name
    $ownerRef  = $OwnerWindow  # capture for closure
    $procRef   = $proc

    $null = Register-ObjectEvent -InputObject $proc -EventName 'Exited' -Action {
        $exitCode = $procRef.ExitCode
        if ($exitCode -ne 0) {
            # Marshal to UI thread
            $ownerRef.Dispatcher.InvokeAsync({
                [System.Windows.MessageBox]::Show(
                    $ownerRef,
                    "Tool '$toolName' exited with code $exitCode.",
                    'Belt — Tool Error',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                ) | Out-Null
            }) | Out-Null
        }
    } -MessageData @{ proc = $proc; toolName = $toolName; owner = $OwnerWindow }
}

# ---------------------------------------------------------------------------
# XAML UI definition
# ---------------------------------------------------------------------------
[xml]$script:Xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Belt"
    MinWidth="300" MinHeight="200"
    Width="650" Height="300"
    UseLayoutRounding="True"
    TextOptions.TextFormattingMode="Display">

    <Window.Resources>

        <!-- Tool button base style -->
        <Style x:Key="ToolButtonStyle" TargetType="Button">
            <Setter Property="Width"       Value="90"/>
            <Setter Property="Height"      Value="90"/>
            <Setter Property="Margin"      Value="6"/>
            <Setter Property="Padding"     Value="4"/>
            <Setter Property="Cursor"      Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="PART_Border"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6"
                                SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center"
                                              VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="PART_Border" Property="Background"
                                        Value="#1A000000"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="PART_Border" Property="Background"
                                        Value="#33000000"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Warning variant (no metadata) -->
        <Style x:Key="ToolButtonWarningStyle" TargetType="Button"
               BasedOn="{StaticResource ToolButtonStyle}">
            <Setter Property="Opacity"          Value="0.72"/>
            <Setter Property="BorderThickness"  Value="1.5"/>
        </Style>

    </Window.Resources>

    <DockPanel LastChildFill="True">

        <!-- ── Status Bar ── -->
        <StatusBar DockPanel.Dock="Bottom">
            <StatusBarItem>
                <TextBlock Name="TxtStatus" Text="Loading…"/>
            </StatusBarItem>
        </StatusBar>

        <!-- ── Button Grid ── -->
        <ScrollViewer VerticalScrollBarVisibility="Auto"
                      HorizontalScrollBarVisibility="Disabled"
                      Padding="4">
            <WrapPanel Name="ToolPanel" Orientation="Horizontal"
                       Margin="4" AllowDrop="False"/>
        </ScrollViewer>

    </DockPanel>
</Window>
'@

# ---------------------------------------------------------------------------
# UI builder helpers
# ---------------------------------------------------------------------------
function New-ToolButton {
    param([pscustomobject]$Tool)

    $btn = [System.Windows.Controls.Button]::new()

    if ($Tool.HasMetadata) {
        $btn.Style = $script:Window.FindResource('ToolButtonStyle')
        $btn.BorderBrush     = [System.Windows.Media.Brushes]::Transparent
        $btn.BorderThickness = [System.Windows.Thickness]::new(0)
        $btn.Background      = [System.Windows.Media.Brushes]::Transparent
    }
    else {
        $btn.Style = $script:Window.FindResource('ToolButtonWarningStyle')
        # Dashed border as the visual warning cue
        $dashBrush = [System.Windows.Media.SolidColorBrush]::new(
            [System.Windows.Media.Color]::FromArgb(180, 180, 120, 0)
        )
        $btn.BorderBrush     = $dashBrush
        $btn.BorderThickness = [System.Windows.Thickness]::new(1.5)
        $btn.Background      = [System.Windows.Media.Brushes]::Transparent
    }

    # Button content: icon (large) above name (small, ellipsis)
    $panel = [System.Windows.Controls.StackPanel]::new()
    $panel.Orientation          = [System.Windows.Controls.Orientation]::Vertical
    $panel.HorizontalAlignment  = [System.Windows.HorizontalAlignment]::Center
    $panel.VerticalAlignment    = [System.Windows.VerticalAlignment]::Center

    if ($Tool.Icon -ne '') {
        $iconText = [System.Windows.Controls.TextBlock]::new()
        $iconText.Text              = $Tool.Icon
        $iconText.FontSize          = 28
        $iconText.TextAlignment     = [System.Windows.TextAlignment]::Center
        $iconText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $iconText.Margin            = [System.Windows.Thickness]::new(0, 0, 0, 2)
        $panel.Children.Add($iconText) | Out-Null
    }

    $labelText = [System.Windows.Controls.TextBlock]::new()
    $labelText.Text              = $Tool.Name
    $labelText.FontSize          = 11
    $labelText.TextAlignment     = [System.Windows.TextAlignment]::Center
    $labelText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $labelText.TextTrimming      = [System.Windows.TextTrimming]::CharacterEllipsis
    $labelText.TextWrapping      = [System.Windows.TextWrapping]::NoWrap
    $labelText.MaxWidth          = 80
    $panel.Children.Add($labelText) | Out-Null

    $btn.Content = $panel

    # Tooltip
    if ($Tool.Description -ne '') {
        $btn.ToolTip = $Tool.Description
    }
    elseif (-not $Tool.HasMetadata) {
        $btn.ToolTip = "(No metadata — $([System.IO.Path]::GetFileName($Tool.FilePath)))"
    }

    # Click handler — use Tag + GetNewClosure to capture tool reference
    $btn.Tag = $Tool
    $btn.Add_Click({
        param($sender, $e)
        Invoke-Tool -Tool $sender.Tag -OwnerWindow $script:Window
    }.GetNewClosure())

    return $btn
}

function Update-ToolPanel {
    param([pscustomobject[]]$Tools)

    $script:ToolPanel.Children.Clear()
    foreach ($tool in $Tools) {
        $btn = New-ToolButton -Tool $tool
        $script:ToolPanel.Children.Add($btn) | Out-Null
    }
}

function Update-StatusBar {
    param([int]$ToolCount, [int]$RunningCount, [datetime]$RefreshTime)
    $timeStr = $RefreshTime.ToString('h:mm tt')
    $script:TxtStatus.Text = "$ToolCount tools loaded | $RunningCount running | Refreshed: $timeStr"
}

# ---------------------------------------------------------------------------
# Main application
# ---------------------------------------------------------------------------
function Start-BeltApp {

    # Load config
    $config = Read-Config

    # Parse XAML and create window
    $reader = [System.Xml.XmlNodeReader]::new($script:Xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $script:Window = $window

    # Named element references
    $script:ToolPanel  = $window.FindName('ToolPanel')
    $script:TxtStatus  = $window.FindName('TxtStatus')

    # ── Initial tool scan ───────────────────────────────────────────────────
    $toolPaths     = [string[]]$config['toolPaths']
    $script:Tools  = @(Get-ToolList -ToolPaths $toolPaths)
    $script:LastRefreshTime = [datetime]::Now
    Update-ToolPanel -Tools $script:Tools

    $runCount = Get-RunningCount
    Update-StatusBar -ToolCount $script:Tools.Count `
                     -RunningCount $runCount `
                     -RefreshTime $script:LastRefreshTime

    # ── Dispatcher timer (1-second tick) ────────────────────────────────────
    $timer          = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [System.TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $runCount = Get-RunningCount
        $script:TxtStatus.Text = "$($script:Tools.Count) tools loaded | $runCount running | Refreshed: $($script:LastRefreshTime.ToString('h:mm tt'))"
    })
    $timer.Start()

    # ── Window closing ───────────────────────────────────────────────────────
    $window.Add_Closing({
        param($sender, $e)

        $runCount = Get-RunningCount

        if ($runCount -gt 0) {
            $timer.Stop()

            $toolWord = if ($runCount -eq 1) { 'tool is' } else { 'tools are' }
            $result = [System.Windows.MessageBox]::Show(
                $window,
                "$runCount $toolWord still running.`n`nClose them all, leave them running, or cancel?",
                'Belt — Tools Running',
                [System.Windows.MessageBoxButton]::YesNoCancel,
                [System.Windows.MessageBoxImage]::Question
            )

            switch ($result) {
                'Yes' {
                    # [Yes] = Close All
                    Stop-AllTrackedProcesses
                    # proceed — do not cancel
                }
                'No' {
                    # [No] = Leave Running — detach and exit
                    $script:RunningProcesses.Clear()
                    # proceed — do not cancel
                }
                'Cancel' {
                    $e.Cancel = $true
                    $timer.Start()
                    return
                }
            }
        }

        $timer.Stop()
    })

    # ── Show ─────────────────────────────────────────────────────────────────
    $null = $window.ShowDialog()
}

# ---------------------------------------------------------------------------
# Entry point — must run on STA thread (WPF requirement)
# ---------------------------------------------------------------------------
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    # Re-launch on an STA thread
    $staThread = [System.Threading.Thread]::new({
        try   { Start-BeltApp }
        catch { [System.Windows.MessageBox]::Show($_.ToString(), 'Belt — Fatal Error') }
    })
    $staThread.SetApartmentState('STA')
    $staThread.Start()
    $staThread.Join()
}
else {
    try   { Start-BeltApp }
    catch { [System.Windows.MessageBox]::Show($_.ToString(), 'Belt — Fatal Error') }
}
