# TOOL_NAME: Ping Tool
# TOOL_DESC: Ping a host and display round-trip latency and packet statistics
# TOOL_ICON: 📡
# TOOL_CATEGORY: Network
# TOOL_TYPE: console

<#
.SYNOPSIS
    Console-based ping utility using Test-Connection.
.DESCRIPTION
    Prompts for a hostname or IP address, sends ICMP echo requests, and
    displays per-reply latency along with a summary of packet statistics.
    Designed to run inside a Belt toolbox console pane.
#>

function Write-Header {
    param([string]$Text)
    $line = '-' * 48
    Write-Host ""
    Write-Host $line                        -ForegroundColor DarkCyan
    Write-Host "  $Text"                    -ForegroundColor Cyan
    Write-Host $line                        -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Result {
    param(
        [string]$Label,
        [string]$Value,
        [System.ConsoleColor]$Color = 'White'
    )
    Write-Host ("  {0,-20} " -f ($Label + ':')) -NoNewline -ForegroundColor Gray
    Write-Host $Value -ForegroundColor $Color
}

# ─── Banner ───────────────────────────────────────────────────────────────────
Clear-Host
Write-Header 'Belt Toolbox  |  Ping Tool'

# ─── Input ────────────────────────────────────────────────────────────────────
$hostname = Read-Host '  Enter hostname or IP address'

if ([string]::IsNullOrWhiteSpace($hostname)) {
    Write-Host "`n  No hostname provided. Exiting." -ForegroundColor Yellow
    Read-Host "`nPress Enter to close"
    exit 0
}

$countInput = Read-Host '  Number of pings [default: 4]'
$count      = if ($countInput -match '^\d+$' -and [int]$countInput -gt 0) {
    [int]$countInput
} else {
    4
}

Write-Host ""
Write-Host "  Pinging '$hostname' ($count requests) ..." -ForegroundColor Gray
Write-Host ""

# ─── Ping ─────────────────────────────────────────────────────────────────────
$sent     = 0
$received = 0
$latencies = [System.Collections.Generic.List[long]]::new()

for ($i = 1; $i -le $count; $i++) {
    $sent++
    try {
        $result = Test-Connection -TargetName $hostname -Count 1 -ErrorAction Stop

        $latency = $result.Latency
        $address = $result.Address ?? $result.Destination

        $latencies.Add($latency)
        $received++

        $color = switch ($true) {
            { $latency -lt 20  } { 'Green'  }
            { $latency -lt 100 } { 'Yellow' }
            default               { 'Red'    }
        }

        Write-Host ("  [{0}/{1}]  Reply from {2,-18}  Latency: {3} ms" -f `
            $i, $count, $address, $latency) -ForegroundColor $color
    }
    catch {
        $msg = $_.Exception.Message -replace '\s+', ' '
        Write-Host ("  [{0}/{1}]  Request timed out / failed  ({2})" -f `
            $i, $count, $msg) -ForegroundColor Red
    }

    if ($i -lt $count) { Start-Sleep -Milliseconds 500 }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
$lost       = $sent - $received
$lossPercent = [math]::Round(($lost / $sent) * 100, 0)

Write-Host ""
Write-Host "  ── Statistics ──────────────────────────────" -ForegroundColor DarkCyan
Write-Result 'Packets Sent'     "$sent"
Write-Result 'Packets Received' "$received" -Color $(if ($received -eq $sent) { 'Green' } else { 'Yellow' })
Write-Result 'Packets Lost'     "$lost ($lossPercent%)" -Color $(if ($lost -gt 0) { 'Red' } else { 'Green' })

if ($latencies.Count -gt 0) {
    $min = ($latencies | Measure-Object -Minimum).Minimum
    $max = ($latencies | Measure-Object -Maximum).Maximum
    $avg = [math]::Round(($latencies | Measure-Object -Average).Average, 1)

    Write-Result 'Min Latency'     "$min ms"
    Write-Result 'Max Latency'     "$max ms"
    Write-Result 'Avg Latency'     "$avg ms"
} else {
    Write-Host ""
    Write-Host "  All requests failed. Check host reachability." -ForegroundColor Red
}

Write-Host ""

# ─── Keep console open ────────────────────────────────────────────────────────
Read-Host 'Press Enter to close'
