# Belt — Product Requirements Document

## Overview

**Belt** is a PowerShell 7+ WPF application that serves as a dynamic tool launcher. It reads PowerShell scripts from configured folders, displays each as a button in a wrapping grid, and launches them as separate processes when clicked. Think of it as a customizable tool belt where dropping a `.ps1` file into a folder automatically makes it accessible from a GUI.

## Architecture

- **Runtime:** PowerShell 7+ (`pwsh.exe`) on Windows
- **GUI Framework:** WPF (XAML), loaded via `Add-Type -AssemblyName PresentationFramework`
- **Process Model:** Each tool runs as a separate `pwsh.exe` process (full isolation)
- **Path Resolution:** All paths resolve relative to `$PSScriptRoot` (supports pinned shortcuts)

## File Structure

```
belt/
├── belt.ps1              # Main toolbox launcher script
├── belt.json             # Configuration file (auto-created on first run)
├── tools/                # Default tools folder (auto-created on first run)
│   ├── example-tool.ps1
│   └── ...
└── PRD.MD
```

## Configuration — `belt.json`

A single JSON file stores all configuration and transient state. Auto-created on first launch with sensible defaults.

### Schema

```json
{
  "toolPaths": [
    "./tools"
  ],
  "window": {
    "left": 100,
    "top": 100,
    "width": 600,
    "height": 400
  }
}
```

### Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `toolPaths` | `string[]` | `["./tools"]` | Array of folder paths to scan for tool scripts. Relative paths resolve from `$PSScriptRoot`. |
| `window.left` | `number` | `100` | Window X position (absolute screen coordinates). |
| `window.top` | `number` | `100` | Window Y position (absolute screen coordinates). |
| `window.width` | `number` | `600` | Window width in pixels. |
| `window.height` | `number` | `400` | Window height in pixels. |

### Multi-Monitor

Window position is saved as absolute screen coordinates. On restore, validate that the saved position is on a currently connected monitor. If the monitor is no longer available, fall back to the primary monitor at the default position.

### First Run Behavior

If `belt.json` does not exist when the toolbox launches:
1. Create `belt.json` with default values
2. Create `./tools/` subfolder if it doesn't exist
3. Launch normally with an empty tool grid

## Tool Script Metadata Format

Each tool script embeds metadata as key-value comment lines at the top of the file. The toolbox parses these before displaying buttons.

### Supported Fields

| Key | Required | Description |
|-----|----------|-------------|
| `TOOL_NAME` | No | Display name on the button. Falls back to filename if missing. |
| `TOOL_DESC` | No | Short description shown as a tooltip. |
| `TOOL_ICON` | No | Single emoji character displayed on the button. |
| `TOOL_CATEGORY` | No | Category string (reserved for future grouping support). |
| `TOOL_TYPE` | No | `gui` (default) or `console`. Controls how the process is launched. |

### Format

```powershell
# TOOL_NAME: DNS Lookup
# TOOL_DESC: Resolve hostnames to IP addresses
# TOOL_ICON: 🔍
# TOOL_CATEGORY: Network
# TOOL_TYPE: gui

# --- Script code below ---
param()
# ...
```

- Lines must start with `# TOOL_` followed by the key name, a colon, and the value.
- Metadata lines can appear anywhere in the file but are conventionally placed at the top.
- Parsing stops reading metadata after encountering the first non-comment, non-blank line (for performance on large scripts).

### Scripts Without Metadata

If a `.ps1` file has no `TOOL_*` metadata lines:
- A button is still shown
- The label is derived from the filename: `Get-DnsRecord.ps1` → `Get Dns Record`
- A visual warning indicator (e.g., muted styling or small badge) signals that metadata is missing
- Default icon: none (text-only button)
- Default type: `gui`

## UI Layout

### Window

- **Title:** `Belt`
- **Behavior:** Normal window (not always-on-top, not system tray)
- **Theme:** System default (respects Windows light/dark mode)
- **State persistence:** Position, size saved to `belt.json` on close and restored on launch

### Structure (top to bottom)

```
┌─────────────────────────────────────────────┐
│ Toolbar: [🔄 Refresh] [📂 Open Folder] [⚙ Settings] │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐   │
│  │ 🔍   │  │ 📡   │  │ ⚙️   │  │ 📋   │   │
│  │ DNS  │  │ Ping │  │ Svcs │  │ Clip │   │
│  └──────┘  └──────┘  └──────┘  └──────┘   │
│  ┌──────┐  ┌──────┐                        │
│  │ 🔑   │  │ ⚠️   │  ← warning style      │
│  │ Keys │  │ foo  │    (no metadata)       │
│  └──────┘  └──────┘                        │
│                                             │
├─────────────────────────────────────────────┤
│ Status: 6 tools loaded | 2 running | Refreshed: 2:30 PM │
└─────────────────────────────────────────────┘
```

### Toolbar Buttons

| Button | Action |
|--------|--------|
| **Refresh** | Full re-scan: re-read all tool folders, re-parse all script metadata, rebuild button grid. |
| **Open Folder** | Opens the first tool folder path in File Explorer. If multiple paths, open all of them. |
| **Settings** | Opens `belt.json` in the system's default editor (e.g., Notepad, VS Code). |

### Button Grid

- **Layout:** `WrapPanel` — buttons flow left-to-right and wrap to new rows on resize
- **Button size:** Uniform (fixed width and height for all buttons)
- **Button content:** Emoji icon (large) above the label text (smaller, truncated with ellipsis if too long)
- **Tooltip:** Shows `TOOL_DESC` on hover (if available)
- **Multiple instances:** Every click spawns a new process. No single-instance restriction.

### Status Bar

Displays at the bottom of the window:
- `{N} tools loaded` — total number of tool buttons currently displayed
- `{N} running` — count of tool processes currently alive (tracked via process handles)
- `Refreshed: {time}` — timestamp of last folder scan

## Tool Launch Behavior

### Launch by Type

| `TOOL_TYPE` | Behavior |
|-------------|----------|
| `gui` (default) | `Start-Process pwsh -ArgumentList '-NoProfile', '-File', '<script>' -WindowStyle Hidden` — console is hidden; script is expected to create its own GUI window. |
| `console` | `Start-Process pwsh -ArgumentList '-NoProfile', '-File', '<script>'` — runs in a visible console window. |

### Process Tracking

- The toolbox stores the `Process` object returned by `Start-Process` for each launched tool.
- The status bar polls or checks `HasExited` to maintain the running count.
- Process references are cleaned up when the process exits.

### Error Handling

If a tool script fails to launch or exits immediately with a non-zero exit code:
- Show a **modal error dialog** with:
  - The tool name
  - The exit code
  - Captured stderr output (if available)
- The button remains functional for retry.

## Exit Behavior

When the user closes the Belt window:
1. Check if any tracked tool processes are still running.
2. If **none running:** close immediately.
3. If **tools are running:** show a confirmation dialog:
   - "N tools are still running. Close them all, or leave them running?"
   - **[Close All]** — terminate all tracked processes, then exit.
   - **[Leave Running]** — detach from processes and exit. Tools continue independently.
   - **[Cancel]** — abort the close, return to Belt.
4. Save window position/size to `belt.json` before exiting (regardless of choice).

## Folder Scanning Rules

- Scan each path in `toolPaths` for files matching `*.ps1`
- Non-recursive (only top-level files in each folder)
- If a configured path doesn't exist, skip it silently (don't error)
- If a configured path is relative, resolve it from `$PSScriptRoot`
- Duplicate filenames across folders: last-wins (later paths in the array override earlier ones)
- Sort buttons alphabetically by `TOOL_NAME` (or derived filename)

## Non-Goals (Explicitly Out of Scope)

- Cross-platform support (Windows only)
- Keyboard navigation / hotkeys for launching tools
- Auto-detection of folder changes (FileSystemWatcher)
- In-process script execution (runspaces)
- Image/icon file support (emoji only)
- Tool grouping/categorization in the UI (category field is stored but not used for layout)
- Drag-and-drop reordering of buttons
- Single-instance enforcement for tools
- Tool-to-tool communication or shared state

## Example Tool Script

```powershell
# TOOL_NAME: DNS Lookup
# TOOL_DESC: Resolve hostnames to IP addresses
# TOOL_ICON: 🔍
# TOOL_CATEGORY: Network
# TOOL_TYPE: gui

Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="DNS Lookup" Height="300" Width="400">
    <StackPanel Margin="10">
        <TextBox Name="HostInput" />
        <Button Name="LookupBtn" Content="Resolve" Margin="0,5,0,5" />
        <TextBox Name="ResultOutput" IsReadOnly="True" Height="150"
                 VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" />
    </StackPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$hostInput = $window.FindName("HostInput")
$lookupBtn = $window.FindName("LookupBtn")
$resultOutput = $window.FindName("ResultOutput")

$lookupBtn.Add_Click({
    $resultOutput.Text = (Resolve-DnsName $hostInput.Text | Out-String)
})

$window.ShowDialog() | Out-Null
```
