# Belt — PRD Revisions Log

This document tracks changes made to the original PRD requirements during development, based on user feedback and bug fixes.

---

## Revision 1: Closure Scoping Fix — Tool Button Click Handler

**Issue:** Clicking any tool button caused a fatal error: `The variable '$toolCapture' cannot be retrieved because it has not been set.`

**Root Cause:** PowerShell script blocks don't capture local variables as closures by default. The `$toolCapture` variable was not accessible inside the `Add_Click` handler.

**Fix:** Replaced direct variable capture with WPF `Tag` property pattern — store the tool object on `$btn.Tag` and access it via `$sender.Tag` in the click handler with `.GetNewClosure()`.

---

## Revision 2: Settings Button — UseShellExecute for PS7

**Issue:** The Settings toolbar button appeared to do nothing except push the Belt window to the background.

**Root Cause:** PowerShell 7 (Core) defaults `UseShellExecute` to `false` on `ProcessStartInfo`, unlike Windows PowerShell 5.1 which defaults to `true`. Without shell execution, Windows doesn't know how to open `.json` files with the associated editor.

**Fix:** Use `System.Diagnostics.ProcessStartInfo` with `UseShellExecute = $true` explicitly. Added a `try/catch` fallback to `notepad.exe` in case no default app is associated with `.json` files.

---

## Revision 3: Recursive Tool Folder Scanning

**Original PRD:** "Scan each path in `toolPaths` for files matching `*.ps1` — Non-recursive (only top-level files in each folder)"

**Change:** User requested recursive scanning of child folders within each tool path to pick up scripts nested in subfolders.

**Fix:** Added `-Recurse` flag to the `Get-ChildItem` call in `Get-ToolList`. Duplicate filename deduplication (last-wins) still applies across all discovered scripts.

**PRD Impact:** The "Non-recursive" rule in the Folder Scanning Rules section is now superseded. Tool scripts can be organized in subdirectories within any configured tool path.

---

## Revision 4: Network Share Deployment — Local Temp Copy

**Change:** Belt is now intended to be run from a UNC network share. Tool paths in `belt.json` may also be UNC paths. Running PowerShell scripts directly from UNC paths can cause working-directory issues, and batch files have quoting problems with `%~dp0` on UNC paths.

**Fix:** Replaced `belt.bat` with `belt.cmd`. The launcher now copies `belt.ps1` and all configured tool folders to `%TEMP%\Belt\` before launching, so execution always happens from a local path. Files are only copied when the source is newer than the local copy (timestamp comparison for `belt.ps1`; `robocopy /XO` for tool folders). The `belt.json` written to temp contains updated local-relative tool paths.

---

## Revision 5: Remove Window Position / Size Persistence

**Original PRD:** Belt saves and restores the window position and size across sessions, with multi-monitor validation.

**Change:** Window state persistence removed entirely. Belt is a shared deployment used by multiple people — per-user window state is not appropriate.

**Fix:** Removed `Test-PositionOnScreen`, the `window` key from `belt.json` and `DefaultConfig`, all geometry save/restore code in `Read-Config`, `Start-BeltApp`, and the `Add_Closing` handler. Also removed the `System.Windows.Forms` assembly load which was only used for multi-monitor screen enumeration.

---

## Revision 6: Remove Default `./tools` Folder and Open Folder Button

**Change:** The default `./tools` tool path and the auto-creation of a `tools/` folder on first run have been removed. An empty `toolPaths` list is now valid — Belt simply shows an empty UI. The **Open Folder** toolbar button has also been removed, as it is no longer meaningful when tool paths are managed externally via `belt.json` on a network share.
