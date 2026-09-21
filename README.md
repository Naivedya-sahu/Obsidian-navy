# Obsidian Context Menu

Open **any folder** as an Obsidian vault directly from Windows Explorer's right-click menu — no vault picker, no GUI. Either bare, or pre-loaded with a full plugin and theme set.

---

## What It Does

Right-clicking a folder shows an **Obsidian** submenu with two entries:

| Entry | Result |
|-------|--------|
| **Open as plain vault** | A bare vault — empty `.obsidian`, stock Obsidian, no community plugins |
| **Open as vault with plugins** | Same, but `.obsidian` is seeded from a bundled template: 14 community plugins, 3 themes, and the appearance settings |

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
| Plugins (14) | `calendar`, `cmdr`, `dataview`, `folder-notes`, `homepage`, `obsidian-icon-folder`, `obsidian-kanban`, `obsidian-latex-suite`, `obsidian-tasks-plugin`, `obsidian-tikzjax`, `table-editor-obsidian`, `templater-obsidian`, `voice` — plus `obsidian-git`, shipped but **not** enabled |
| Themes (3) | Typewriter (active), Minimal, Obsidian Nord |
| Config | `appearance.json` (Typewriter + Times New Roman interface font), `core-plugins.json`, `community-plugins.json` — 13 of the 14 listed as enabled |

`obsidian-git` ships but stays **off**: it errors on every vault that isn't a git repo, which is most of them. Turn it on per-vault in Settings → Community plugins when the folder actually is a repo.

Daily notes come from Obsidian's **core** daily-notes plugin, not `periodic-notes`. One consequence: `calendar`'s weekly-note feature needs `periodic-notes` and is therefore inactive — daily notes work fine.

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

This matters more for **Open as vault with plugins**: the seeded plugins stay dormant until you accept that prompt. Decline it and you get a plain vault with 14 plugins sitting on disk, switched off. There's no supported way to pre-trust a vault from outside Obsidian — the prompt exists precisely to stop third-party tools from doing that.

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

#### The edit-and-reship loop

1. Edit `Default\.obsidian\` — `appearance.json`, `core-plugins.json`, `community-plugins.json`, plugin folders, themes.
2. Bump `MyAppVersion` in `installer.iss`, so Add/Remove Programs tells you which template generation is installed.
3. Rebuild, then run the installer from `Output\`. Inno Setup's compiler is wherever you installed it — per-user installs land under `%LOCALAPPDATA%\Programs\Inno Setup 6\`, winget installs under `%ProgramFiles(x86)%\Inno Setup 6\`:
   ```
   ISCC.exe installer.iss
   ```

Nothing else needs recompiling — `open-vault.exe` only changes if `open-vault.cs` does. The template is data.

#### What your change actually reaches

| Target | Result |
|---|---|
| Vaults you seed **after** reinstalling | Get the new template. This is the normal case and it just works. |
| Vaults already seeded **before** | Unchanged. The seed never overwrites, so every file it would write is already there. |

To push a change into an already-seeded vault, delete the specific file or plugin folder from that vault's `.obsidian\`, then run **Open as vault with plugins** again — it refills only what's missing. There is deliberately no "reset this vault to template" action; that would mean overwriting config you may have tuned by hand.

**Removals don't propagate on an over-install.** Inno installs the files it's given; it doesn't prune the destination. Drop a plugin from `Default\` and reinstall over the top, and the old folder survives in `{app}\Template\plugins\`. Uninstall first, then install, whenever you remove something.

#### Capturing tweaks from a live vault

Root-level config (`appearance.json`, `app.json`, `core-plugins.json`, `community-plugins.json`) copies across directly. Per-plugin settings live in `.obsidian\plugins\<id>\data.json` — no bundled plugin ships one today, which is why every seeded vault starts at stock defaults.

> **Read any `data.json` before you commit it.** This repo is public. Plugin settings files routinely carry API keys, git remote URLs with tokens, absolute paths from your own machine, and vault-specific folder names. `obsidian-git` and `voice` are the likely offenders. A seed is meant to be generic — if a setting only makes sense on your laptop, it does not belong in the template.

`workspace.json` and `workspaces.json` are excluded from the build, so editing them changes nothing.

#### Shipping more than one profile

There is **one** template today. `Default\.obsidian\` → `{app}\Template` → one `--template` flag → one submenu entry. That is deliberate: two verbs cover both real cases (bare vault, seeded vault), and a profile you don't yet have a use for is a profile you'll maintain for nothing.

If a second genuinely earns its place — say an academic profile and a writing profile — this is what it costs:

| Change | Detail |
|---|---|
| Source layout | `profiles\<name>\.obsidian\` instead of the single `Default\` |
| `installer.iss` `[Files]` | One `Source:` line per profile → `{app}\Template\<name>` |
| `open-vault.cs` | `--template` takes a value; resolve `Template\<name>` instead of `Template` |
| `installer.iss` `[Registry]` | One `Obsidian\shell\NN<name>` verb + `\command` per profile |

**The trap is size.** Profiles duplicate plugin binaries — two profiles sharing fourteen plugins still ship both copies, so a second profile costs another ~21 MB of installer, not the few KB of config that actually differs. If profiles ever land, the layout worth building is shared `plugins\` + `themes\` seeded for every profile, with per-profile `*.json` config layered on top. That's a two-source merge in `SeedMissing`, not a second template — and it's the only version of this feature worth the code.

Until then: one template, edited in place.

---

## Releasing

The installer is a build artifact — `Output\` is gitignored, so the binary lives on GitHub Releases, not in the repo. A release is what the Installation section's download link points at.

**Order matters: commit and push first.** `gh release create` tags whatever is at the branch head, so a release cut before pushing points at a commit nobody else can fetch.

1. **Bump the version.** `MyAppVersion` in `installer.iss` is the single source — it drives Add/Remove Programs, and the git tag should match it.

2. **Rebuild.** The setup binary is regenerated from the `[Files]` list each compile, so nothing needs clearing here.
   ```
   ISCC.exe installer.iss
   ```
   Pruning only bites at *install* time: if you removed anything from the template, uninstall the previous version before installing the new one, or the dropped files survive in `{app}\Template`.

3. **Commit and push** the source changes (`installer.iss`, `Default\`, `README.md`).

4. **Cut the release**, attaching the compiled setup:
   ```
   gh release create v1.1 Output\ObsidianContextMenu-Setup.exe --title "v1.1" --notes "..."
   ```
   `gh` creates the tag at the current branch head if it doesn't exist. Use `--generate-notes` instead of `--notes` to build notes from the commit log, or `--draft` to review before it goes public.

**Verify** the asset actually uploaded — a release with no binary is the common failure:

```
gh release view v1.1 --json assets --jq '.assets[].name'
```

### What ships and what doesn't

| | |
|---|---|
| In the release | `ObsidianContextMenu-Setup.exe` — installer, template and all, ~11 MB |
| In the repo | Sources plus `Default\.obsidian\` (21 MB uncompressed) |
| In neither | `open-vault.exe`, `seed-test.exe`, `Output\` — all gitignored build artifacts |

The asset keeps the product name (`ObsidianContextMenu-Setup.exe`) rather than the repo name. Renaming it is cosmetic; `AppId` is what Windows matches on for upgrades, and that must never change.

Releases are **unsigned**. Every download hits SmartScreen's "Windows protected your PC" — expected, and worth saying in the release notes so it doesn't read as a broken build.

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

---

## Template Baseline

What the template carries, so future-you can tell how stale it has become. Versions captured **2026-09-21** from Obsidian **1.12.7** on Windows 11.

| Plugin | Version | | Plugin | Version |
|---|---|---|---|---|
| `calendar` | 1.5.10 | | `obsidian-kanban` | 2.0.51 |
| `cmdr` | 0.5.12 | | `obsidian-latex-suite` | 1.13.1 |
| `dataview` | 0.5.68 | | `obsidian-tasks-plugin` | 8.4.0 |
| `folder-notes` | 1.8.26 | | `obsidian-tikzjax` | 0.5.2 |
| `homepage` | 4.5.0 | | `table-editor-obsidian` | 0.23.2 |
| `obsidian-git` † | 2.40.0 | | `templater-obsidian` | 2.25.1 |
| `obsidian-icon-folder` | 2.14.7 | | `voice` | 1.19.0 |

† shipped but not enabled.

Themes: Typewriter (active), Minimal, Obsidian Nord. Interface font: Times New Roman.

No plugin ships a `data.json`, so every seeded vault starts at stock defaults.

**Removed in v1.2:** `periodic-notes` (was 0.0.17) — uninstalled outright, not just disabled. Daily notes are handled by Obsidian's core plugin instead.

---

## Known Gaps

Ordered by how much they actually cost.

### Resolved in v1.2

| Was | Now |
|---|---|
| `obsidian-git` enabled → error notice on every seeded vault that isn't a git repo | Dropped from `community-plugins.json`. Folder still ships, so it's one toggle away per vault. |
| Core `daily-notes` **and** `periodic-notes` both claiming the daily-note action, with `periodic-notes` stuck at an unmaintained v0.0.17 | `periodic-notes` removed from the template entirely. Core daily-notes handles it. |

### 1. Minimal theme ships without Style Settings

Minimal is built to be driven by Style Settings; without that plugin you get half a theme for 261 KB. Typewriter is the active theme regardless, so nothing is broken — Minimal is just sitting there under-powered.

**Deliberately left in place** so the alternatives stay available for a future appearance pass. Two ways out when that happens: bundle Style Settings (~50 KB) and keep Minimal usable, or drop Minimal and ship only what's active. Decide it alongside whatever theme change prompts it, not before.

### 2. Plugin updates are permanent repo weight

`obsidian-tikzjax` is 12.6 MB (`main.js` 7.9 MB + `styles.css` 4.8 MB). Every version bump commits another full copy that never leaves history. Three updates ≈ 50 MB. Still far inside GitHub's limits, but refresh bundled plugins deliberately, in batches, not casually.

### 3. Core-plugin IDs are coupled to Obsidian's version

`core-plugins.json` lists `bases`, `webviewer` and `slash-command` — core plugins from Obsidian 1.12.x. If upstream renames or drops one, the template silently carries a dead key. Re-capture `core-plugins.json` from a current vault when you next touch the template.

### Deliberately not doing

Named here so they don't get re-litigated: **code signing** (costs money; SmartScreen warning is documented and acceptable for a personal tool), **CI** (`seed-test.cs` is a manual command and that is proportionate for a dormant tool), **Git LFS** (ceremony at this size), **multiple profiles** (see *Shipping more than one profile* — the only version worth building is shared plugins plus layered config, and nothing yet needs it).
