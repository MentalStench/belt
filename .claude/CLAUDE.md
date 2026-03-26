# Belt — Project Guide

## What Is This
Belt is a PowerShell 7+ WPF tool launcher. It reads `.ps1` scripts from configured folders, displays each as a button in a GUI grid, and launches them as isolated `pwsh.exe` processes.

## Tech Stack
- **PowerShell 7+ (Core)** on **Windows only** — do not suggest cross-platform approaches
- **WPF (XAML)** loaded via `Add-Type -AssemblyName PresentationFramework`
- WPF requires STA thread — `belt.ps1` has an entry-point guard that re-launches on STA if needed

## File Structure
- `src/belt.ps1` — main launcher script
- `src/tools/` — default tool scripts folder (scanned recursively)
- `belt.json` — runtime config, auto-created next to `belt.ps1` on first launch
- `PRD.MD` — full product requirements
- `REVISIONS-PRD.MD` — tracks changes made after the original PRD

## Tool Metadata Contract
Every tool script can embed metadata as comments at the top:
```
# TOOL_NAME: Display Name
# TOOL_DESC: Short description
# TOOL_ICON: emoji
# TOOL_CATEGORY: Category
# TOOL_TYPE: gui|console
```
Parsing stops at the first non-comment, non-blank line. Scripts without metadata still get a button (name derived from filename) with a visual warning indicator.

## Key Architecture Decisions
- **Separate process per tool** — each tool runs as its own `pwsh.exe`. No runspaces, no in-process execution.
- **Recursive folder scanning** — the original PRD said top-level only, but this was changed to `-Recurse`. Do not revert.
- **`UseShellExecute` must be explicit** — PS7 Core defaults `UseShellExecute` to `false`. Any `Start-Process` or `ProcessStartInfo` that opens files by association (e.g., opening `belt.json` in an editor) must set `UseShellExecute = $true` with a Notepad fallback.

## PowerShell WPF Gotcha
WPF event handler script blocks in PowerShell do **not** capture local variables as closures. Use the `$button.Tag` property to store data and access it via `$sender.Tag` in the handler, combined with `.GetNewClosure()`. Do not use bare `$localVar` inside `Add_Click({})` blocks — it will fail at runtime.
