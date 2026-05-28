# Obsidian Context Menu

Open **any folder** as an Obsidian vault directly from Windows Explorer's right-click menu — no vault picker, no GUI.

---

## What It Does

Right-clicking a folder shows an **Obsidian** entry in the context menu. Clicking it:

1. Creates a `.obsidian` config directory inside the folder (required by Obsidian)
2. Registers the folder as a vault in `obsidian.json` (if not already there)
3. Sets `"open": true` on that vault so Obsidian skips the vault picker on launch
4. Kills any running Obsidian instance, then relaunches it directly into the chosen folder

---

## Requirements

| Requirement | Detail |
|-------------|--------|
| OS | Windows 10 or Windows 11 |
| Obsidian | Any version using `%APPDATA%\obsidian\obsidian.json` (v1.x+) |
| PowerShell | 5.1 (built into Windows — no install needed) |
| Admin rights | Required once during install (writes to `HKEY_CLASSES_ROOT`) |

---

## Installation

### Option A — Installer script (recommended)

1. Download or clone this repo
2. Double-click **`install.bat`**
3. Accept the UAC elevation prompt
4. Choose version `1` or `2` (see [Versions](#versions) below)
5. Done — right-click any folder to test

### Option B — Manual

1. Copy your chosen BAT file to `%APPDATA%\obsidian\` and rename it `open-vault.bat`
2. Double-click `obsidian.reg` and confirm the import (requires admin)

---

## Versions

### `open-vault.bat` — Basic

Vault entry is **permanent**. After using the context menu on a folder:

- The folder remains in Obsidian's vault list
- Its `"open": true` flag stays, so next normal Obsidian launch opens it again
- Best if you genuinely want to add the folder to your vaults

### `open-vault-with-restore.bat` — With Auto-Restore

Vault entry is **ephemeral**. After using the context menu:

- The folder is added temporarily to `obsidian.json` for the session
- A hidden background process watches for Obsidian to close
- Once Obsidian exits, `obsidian.json` is restored to its pre-session state
- The folder disappears from the vault list
- Your original vault configuration and `"open"` flags are fully preserved

Use this if you want to browse folders in Obsidian without polluting your vault list.

---

## How It Works

Obsidian stores all known vaults in a single JSON file:

```
%APPDATA%\obsidian\obsidian.json
```

**Schema:**
```json
{
  "vaults": {
    "8a9ff96277905832": {
      "path": "D:\\MyNotes",
      "ts": 1716883200000,
      "open": true
    },
    "00e4831fa545730a": {
      "path": "D:\\AnotherVault",
      "ts": 1716800000000
    }
  }
}
```

Key rules Obsidian follows on startup:

| Condition | Behaviour |
|-----------|-----------|
| Exactly one vault has `"open": true` | Opens that vault directly, skips picker |
| No vault has `"open": true` | Shows vault picker GUI |
| Multiple vaults have `"open": true` | Undefined — avoid this state |

The BAT script enforces exactly one `"open": true` at a time by setting it on the target vault and **removing** the property (not setting `false`) from all others.

### Vault ID generation

Obsidian identifies vaults by a **16-character hex ID** (8 random bytes). The script generates a cryptographically random ID matching this format when registering a new folder. If the folder is already registered, the existing ID is reused — only the `"open"` flag is updated.

### JSON format requirements

- Must be **compact** (single line) — Obsidian's parser rejects pretty-printed multi-line JSON
- Must be **UTF-8 without BOM** — PowerShell 5.1's default `Set-Content -Encoding UTF8` adds a BOM; the script uses `[IO.File]::WriteAllText` with an explicit no-BOM encoder

### Auto-restore mechanism (With Restore version only)

After launching Obsidian, a hidden PowerShell process is spawned that:

1. Polls `Get-Process -Name 'Obsidian'` every 2 seconds
2. Once no Obsidian process remains, waits 1 additional second
3. Overwrites `obsidian.json` with the pre-session backup (raw byte copy)
4. Deletes the backup file and self-deletes

Polling is used instead of `Wait-Process` because Electron apps spawn multiple sub-processes; waiting on a single process handle fires too early.

**Double-invoke guard:** if the context menu is used again while Obsidian is already open from a previous context-menu session, the backup is not overwritten — the guard `if not exist .bak` ensures the original (pre-first-session) backup is preserved.

---

## File Structure

```
obsidian-context-menu/
├── open-vault.bat               # Basic version
├── open-vault-with-restore.bat  # Auto-restore version
├── obsidian.reg                 # Registry import (portable, uses %USERNAME%)
├── install.bat                  # Installer launcher
├── install.ps1                  # Installer logic (choose version, copy, register)
└── README.md
```

After install, one file is placed in your Obsidian config folder:

```
%APPDATA%\obsidian\
├── obsidian.json        (existing — managed by Obsidian)
└── open-vault.bat       (added by installer)
```

---

## Uninstall

Run `install.bat` again and choose option `3`, or run manually:

```batch
reg delete "HKEY_CLASSES_ROOT\Directory\shell\Obsidian" /f
del "%APPDATA%\obsidian\open-vault.bat"
```

---

## Troubleshooting

**Context menu item doesn't appear**
- Confirm the registry key exists: open `regedit` and check `HKEY_CLASSES_ROOT\Directory\shell\Obsidian`
- Make sure you right-click on a **folder icon**, not inside a folder's background

**Obsidian opens vault picker instead of the folder**
- Obsidian may have re-written `obsidian.json` after the BAT ran — this can happen if Obsidian wasn't fully killed before the JSON was modified
- Increase the `timeout /t 1` in the BAT to `timeout /t 2` if your machine is slow

**Obsidian.json gets corrupted**
- Restore from backup: if using the restore version, `obsidian.json.bak` in `%APPDATA%\obsidian\` is the pre-session snapshot

**PowerShell execution policy error**
- The installer uses `-ExecutionPolicy Bypass` which overrides local policy for that single run — no permanent policy change is made
