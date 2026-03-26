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
