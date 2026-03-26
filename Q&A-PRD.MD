# Belt — Interview Q&A Log

This document captures all design decisions made during the requirements interview for the Belt project.

---

## Round 1: Core Architecture

**Q: How should the toolbox discover metadata about each script (button label, description, icon)?**
A: **Embedded in script** — Each script contains a structured comment block at the top (e.g., `# TOOL_NAME: DNS Lookup`) that the toolbox parses.

**Q: When a user clicks a tool button, should the toolbox allow multiple instances of the same tool to run simultaneously?**
A: **Multiple allowed** — Each click spawns a new independent instance.

**Q: Should the toolbox detect when scripts are added/removed from the folder at runtime, or only scan on startup?**
A: **Manual refresh** — A refresh button re-scans the folder on demand.

**Q: Should tool scripts run in-process or as separate processes?**
A: **Separate process** — Each tool runs as its own `pwsh.exe` process. Full isolation.

---

## Round 2: UX & Window Behavior

**Q: What should the toolbox window's behavior be when tool windows are open?**
A: **Normal window** — Behaves like any other window. Can be minimized, sent behind others.

**Q: How should buttons be laid out as the number of tools grows?**
A: **Wrapping grid** — Buttons flow left-to-right and wrap to new rows. Window can be resized.

**Q: What should happen if a tool script has a syntax error or crashes on launch?**
A: **Error dialog** — Pop up a modal dialog with the error details and stderr output.

**Q: Should the toolbox remember its window position/size between sessions?**
A: **Yes, save state** — Persist window position, size to config file. Restore on next launch.

---

## Round 3: Metadata & Configuration

**Q: What fields should the embedded metadata comment block support?**
A: **Name + Description + Icon + Category** — Four fields, with category for forward-compatible grouping.

**Q: What format should the embedded metadata use inside the script?**
A: **Key-value comments** — Simple `# TOOL_NAME: value` format, one field per line.

**Q: For the icon field, what type of icons do you want to support?**
A: **Emoji only** — Use emoji characters as icons. Zero dependencies.

**Q: Where should the tools folder path be configured?**
A: **Config file** — A `belt.json` file specifies tool folder paths.

---

## Round 4: Config & Exit Behavior

**Q: Should the config file support multiple tool folder paths?**
A: **Yes, multiple paths** — Config lists an array of folder paths. Toolbox merges all scripts.

**Q: What should the config file format be?**
A: **JSON** — Standard, easy to parse with `ConvertFrom-Json`.

**Q: Should the toolbox have a title bar / header area beyond just buttons?**
A: **Toolbar with actions + Status bar** — Both a toolbar (refresh, open folder, settings) and a status bar (tool counts, last refresh).

**Q: When the toolbox is closed, should it kill all running tool processes?**
A: **Prompt to close all** — If tools are still running, show a confirmation dialog.

---

## Round 5: Edge Cases & Defaults

**Q: What should happen when a script has NO metadata comment block?**
A: **Show with warning** — Show the button (name derived from filename) with a visual indicator that metadata is missing.

**Q: Should buttons be uniform or variable sized?**
A: **Uniform buttons** — All buttons same size. Label truncates if too long.

**Q: Should the config file also store window state (position, etc.)?**
A: **All in one file** — Single `belt.json` for paths, settings, and window state.

**Q: Should the toolbox support keyboard shortcuts for launching tools?**
A: **No keyboard nav** — Mouse-only interaction.

---

## Round 6: Framework & Launch

**Q: Visual theme or color scheme?**
A: **System default** — Standard WPF controls with the OS theme.

**Q: Which GUI framework?**
A: **WPF (XAML)** — Modern, flexible, supports data binding.

**Q: Status bar detail level?**
A: **Just counts** — `12 tools loaded | 3 running | Last refresh: 2:30 PM`

**Q: Target PowerShell version?**
A: **PowerShell 7+ (Core)** — Modern .NET, future-proof. Windows-only for WPF is acceptable.

---

## Round 7: Platform & Launch Details

**Q: WPF on PowerShell 7 is Windows-only — acceptable?**
A: **Yes, WPF Windows-only is fine** — Use `Add-Type -AssemblyName PresentationFramework`.

**Q: How should tool scripts be launched as separate processes?**
A: **Configurable per-tool** — Metadata includes a `type` field: `gui` (hidden console) or `console` (visible console).

**Q: Should the toolbox provide a way to open the tools folder from the UI?**
A: **Button in toolbar** — A toolbar button opens the tools folder(s) in File Explorer.

**Q: What should the toolbox window title be?**
A: **Belt** — Short, memorable, matches the project name.

---

## Round 8: Multi-Monitor & First Run

**Q: Should window state remember which monitor?**
A: **Yes, full coordinates** — Save absolute screen coordinates. Fall back to primary monitor if saved monitor is unavailable.

**Q: Should metadata support tool types beyond gui and console?**
A: **Just gui and console** — Two types are sufficient. Keep it simple.

**Q: What if belt.json doesn't exist on first launch?**
A: **Auto-create default** — Generate a default `belt.json` pointing to `./tools/`. Create the subfolder if needed.

---

## Round 9: Final Details

**Q: Should the refresh button re-read metadata from ALL scripts or only detect new/removed files?**
A: **Full re-scan** — Re-read every script and rebuild all buttons. Catches metadata edits too.

**Q: Should paths resolve relative to the script location or working directory?**
A: **Relative to script location** — Use `$PSScriptRoot`. Works with shortcuts and pinned launches.

**Q: Additional toolbar buttons beyond Refresh and Open Tools Folder?**
A: **Settings button** — Opens `belt.json` in the default editor.
