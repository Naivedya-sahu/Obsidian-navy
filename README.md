# Obsidian Context Menu

Open **any folder** as an Obsidian vault directly from Windows Explorer's right-click menu — no vault picker, no GUI. Either bare, or pre-loaded with a full plugin and theme set.

---

## What It Does

Right-clicking a folder shows an **Obsidian** submenu with two entries:

| Entry | Result |
|-------|--------|
| **Open as plain vault** | A bare vault — empty `.obsidian`, stock Obsidian, no community plugins |
| **Open as vault with plugins** | Same, but `.obsidian` is seeded from a bundled template: 15 community plugins, 3 themes, and the appearance settings |

Both entries then do the same four things:

1. Create a `.obsidian` config directory inside the folder (required by Obsidian)
2. Register the folder as a vault in `obsidian.json` (if not already there)
3. Set `"open": true` on that vault so Obsidian skips the vault picker on launch
4. Kill any running Obsidian instance, then relaunch it directly into the chosen folder

The vault entry is **permanent** — it stays in Obsidian's vault list afterward, same as any vault you'd add manually.

---

## The Plugin Template

"Open as vault with plugins" copies a bundled seed vault into the target folder's `.obsidian`.

**What ships:**

| | Contents |
|---|---|
| Plugins (15) | `calendar`, `cmdr`, `dataview`, `folder-notes`, `homepage`, `obsidian-git`, `obsidian-icon-folder`, `obsidian-kanban`, `obsidian-latex-suite`, `obsidian-tasks-plugin`, `obsidian-tikzjax`, `periodic-notes`, `table-editor-obsidian`, `templater-obsidian`, `voice` |
| Themes (3) | Typewriter (active), Minimal, Obsidian Nord |
| Config | `appearance.json` (Typewriter + Times New Roman interface font), `core-plugins.json`, `community-plugins.json` — all 15 plugins listed as enabled |

All plugins ship **without** `data.json`, so each new vault gets them at stock defaults — no personal plugin settings leak into a seeded folder.

**The seed never overwrites.** Files are copied only where nothing exists at that path. Consequences worth knowing:

- Pointing it at an **existing** vault tops up what's missing and leaves your own `appearance.json`, plugin settings, and already-installed plugins untouched — it's an "add what I don't have" action, not a reset.
- It also means the seed **won't update** a plugin you already have. To take a newer bundled version, delete that plugin's folder from the vault's `.obsidian\plugins\` first, then re-run the menu entry.

`workspace.json` and `workspaces.json` are deliberately **excluded** from the template — those are window layout and open tabs, vault-specific state that would be wrong to stamp onto someone else's folder. Obsidian regenerates them.

The template is ~21 MB on disk (13 MB of that is `obsidian-tikzjax` alone), which is most of the installer's download size. Drop plugin folders from `Default\.obsidian\plugins\` before building if you want a leaner one — also remove their IDs from `Default\.obsidian\community-plugins.json`, or Obsidian will list them as enabled-but-missing.

---

## Requirements

| Requirement | Detail |
|-------------|--------|
| OS | Windows 10 or Windows 11 |
| Obsidian | Any version using `%APPDATA%\obsidian\obsidian.json` (v1.x+) |
| Admin rights | Required once during install (writes to `HKEY_CLASSES_ROOT`) |

---

## Installation

1. Download `ObsidianContextMenu-Setup.exe` from [Releases](../../releases)
2. Run it, accept the UAC prompt
3. **If Obsidian isn't found automatically** — a page lets you either browse for `Obsidian.exe` manually, or click "Download && Install Latest Obsidian" to fetch it straight from Obsidian's official GitHub releases and install it inline
4. Done — right-click any folder to test

Unsigned installer, personal tool with no code-signing cert — Windows SmartScreen will show "Windows protected your PC" on first run. Click **More info → Run anyway**.

### Uninstall

Use **Add/Remove Programs** — "Obsidian Context Menu". Cleanly removes the registry entry and the installed script. Your vaults, notes, and Obsidian itself are never touched.

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

`open-vault.exe` enforces exactly one `"open": true` at a time: sets it on the target vault, and **removes** the property (not `false`) from every other vault.

There's no supported native way around this file — Obsidian's own URI scheme (`obsidian://open?path=...`) can only open a vault that's *already* registered in `obsidian.json`; it can't register a brand-new folder. Editing the JSON directly is the only way to do what this tool does.

### Vault ID generation

Obsidian identifies vaults by a **16-character hex ID** (8 random bytes), used purely as an opaque dictionary key — there's no `name` field in the schema; the display name in Obsidian's UI is just the folder's basename. The script generates a cryptographically random ID matching this format when registering a new folder. If the folder is already registered (matched by path, case-insensitive), the existing ID is reused — only the `"open"` flag changes.

### JSON format requirements

- Must be **compact** (single line) — Obsidian's parser rejects pretty-printed multi-line JSON
- Must be **UTF-8 without BOM** — PowerShell's default `Set-Content -Encoding UTF8` adds a BOM; the script uses `[IO.File]::WriteAllText` with an explicit no-BOM encoder

### Why it kills Obsidian first

Obsidian rewrites `obsidian.json` with its own in-memory state when it exits. Editing the file while Obsidian is still running gets silently overwritten. The script force-kills `Obsidian.exe`, then **polls** for the process to actually disappear (up to 10s) before touching the JSON — a fixed sleep isn't reliable on a slow machine. This also means: if you have other vaults open in other Obsidian windows, they all get closed. Obsidian's single-instance lock makes this unavoidable — there's no supported way to open a second vault window without going through the same process.

### First-time trust prompt

Every genuinely new vault triggers Obsidian's own "Do you trust the author of this vault?" security dialog on first open — that's Obsidian's plugin-safety gate, not something this tool can or should skip. One extra click, once per folder.

This matters more for **Open as vault with plugins**: the seeded plugins stay dormant until you accept that prompt. Decline it and you get a plain vault with 15 plugins sitting on disk, switched off. There's no supported way to pre-trust a vault from outside Obsidian — the prompt exists precisely to stop third-party tools from doing that.

---

## File Structure

```
obsidian-context-menu/
├── installer.iss          # Inno Setup script — the whole installer
├── open-vault.cs          # runtime payload source — compiled to open-vault.exe
├── seed-test.cs           # test for the template copy's no-clobber rule
├── Default/.obsidian/     # the seed vault shipped as the plugin template
├── open-vault.exe         # build artifact, gitignored (compile from open-vault.cs)
├── .gitignore
└── README.md
```

Installed layout:

```
%ProgramFiles%\ObsidianContextMenu\
├── open-vault.exe
└── Template\              # copy of Default\.obsidian, minus workspace*.json
```

Plus the registry tree under `HKCR\Directory\shell\Obsidian`:

| Key / value | Purpose |
|-------------|---------|
| `Obsidian` → `MUIVerb` | Submenu label |
| `Obsidian` → `subcommands` (empty string) | Marks it as a cascading menu |
| `Obsidian` → `Icon` | Detected `Obsidian.exe` path — read back at runtime by `open-vault.exe`, so the path is defined in exactly one place |
| `Obsidian\shell\01plain\command` | `open-vault.exe "%1"` |
| `Obsidian\shell\02full\command` | `open-vault.exe --template "%1"` |

Submenu entries are ordered by subkey name, hence the `01`/`02` prefixes.

> **Upgrading from v1.0:** that version put the command directly on `Obsidian\command`. The shell honours a `\command` subkey over `subcommands`, so the installer explicitly deletes it — otherwise an upgrade silently keeps the old single-action menu.

### Why a compiled exe, not a script

The first version of this tool used a `.ps1` invoked via `powershell.exe -File`. On at least one target machine, PowerShell's module autoloading was broken badly enough that even built-in cmdlets (`Test-Path`, `Get-Process`, ...) failed to resolve in a freshly spawned process — not something this tool can fix or work around reliably, and not something worth depending on for a context-menu action that has to just work on click. `open-vault.exe` is a real native binary (compiled via `csc.exe`, ships with every Windows .NET Framework install) — no script host, no execution policy, no module system involved at runtime.

The installer's optional "Download && Install Latest Obsidian" button (only shown if auto-detection fails) still shells out to `powershell.exe` for the GitHub API call — that's an install-time, rarely-hit convenience with a working manual "Browse..." fallback right next to it, so it wasn't worth hand-rolling JSON parsing in Inno's Pascal Script to remove. If that button turns out to be flaky too, it's the one remaining PowerShell dependency to replace.

---

## Build From Source

If you don't want to run the prebuilt release, or you're curious how it's put together:

1. Compile the runtime handler (any Windows machine with .NET Framework has `csc.exe` — no install needed):
   ```
   csc.exe /target:winexe /out:open-vault.exe /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll open-vault.cs
   ```
2. Optional — run the test for the template copy's no-clobber rule. It compiles the shipping source and picks the test's entry point, so it exercises the real function, not a copy:
   ```
   csc.exe /target:exe /main:SeedTest /out:seed-test.exe /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll open-vault.cs seed-test.cs
   ```
   then run `seed-test.exe` — it prints `PASS` and exits 0, or names the failing assertion and exits 1.
3. Install [Inno Setup](https://jrsoftware.org/isinfo.php) (or `winget install JRSoftware.InnoSetup`)
4. Compile the installer: open `installer.iss` in the Inno Setup Compiler, or run `ISCC.exe installer.iss` from a shell
5. Compiled output lands in `Output\ObsidianContextMenu-Setup.exe`, run it like any release build

Everything the installer does is in two source files: `installer.iss` (registry keys, Obsidian-detection logic, the fallback browse/download page) and `open-vault.cs` (the vault-registration and template-seeding logic that runs on every right-click). Its one data dependency is `Default\.obsidian\` — the seed vault, bundled verbatim. No dependencies beyond what's already on a stock Windows box plus Inno Setup.

### Changing what the template ships

`Default\.obsidian\` **is** the template — edit it directly and rebuild the installer. To add a plugin, drop its folder in `Default\.obsidian\plugins\` and add its manifest `id` to `Default\.obsidian\community-plugins.json`. Folder name and plugin `id` match for every plugin currently bundled, but that's a convention, not a guarantee — read the `id` out of the plugin's own `manifest.json` rather than assuming.

An ID listed in `community-plugins.json` with no matching folder shows up in Obsidian as a broken enabled plugin; a folder with no listed ID installs but stays switched off.

---

## Troubleshooting

**Context menu item doesn't appear**
- Confirm the registry key exists: open `regedit` and check `HKEY_CLASSES_ROOT\Directory\shell\Obsidian`
- Make sure you right-click on a **folder icon**, not inside a folder's background
- On Windows 11, third-party verbs live under **Show more options** (or Shift+F10)

**Menu shows one "Obsidian" entry instead of the submenu**
- Left over from v1.0. Check `HKEY_CLASSES_ROOT\Directory\shell\Obsidian\command` — if that key exists, the shell uses it and ignores the submenu. Reinstalling removes it; deleting that one key by hand also works.

**Plugins were copied but none of them are on**
- You declined Obsidian's "Do you trust the author of this vault?" prompt. Re-enable them in **Settings → Community plugins** (turn off Restricted mode).

**"Open as vault with plugins" didn't add a plugin I expected**
- The seed never overwrites. If a plugin folder of that name already exists in the vault, it's left exactly as-is. Delete it from the vault's `.obsidian\plugins\` and run the menu entry again.

**Obsidian opens the vault picker instead of the folder**
- Obsidian may have re-written `obsidian.json` after being killed slower than expected — this should be rare since the script polls for full process exit, but if it happens, try again
- Check `Icon` value under the registry key above still points to a real `Obsidian.exe` — if Obsidian was reinstalled to a new location, reinstall this tool too

**"Obsidian.exe not found" popup when right-clicking**
- Obsidian was moved or uninstalled after this tool was installed. Reinstall Obsidian Context Menu so it re-detects the current path.
