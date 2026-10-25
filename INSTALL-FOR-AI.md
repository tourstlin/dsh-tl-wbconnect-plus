# INSTALL FOR AN AI AGENT — dsh-connect-workbuddy 5.3.0-wb1

You are installing a **patched build of a DeepSeek Harness (DSH) plugin** on a
Windows machine. Read this whole file before running anything.

The human you are working for has **never installed this plugin**. Everything
needed is inside this archive. There is **no git, no npm, no pnpm, and no
network access required** — do not try to install any of them.

---

## 0. What this package is

| | |
|---|---|
| Package | `dsh-connect-workbuddy` |
| Upstream base | 5.3.0 (MIT, © 2026 LaoDing) |
| This build | `5.3.0-wb1` — the base plus six local patches (listed in `PATCHES.md`) |
| Host app | DeepSeek Harness (Electron). **Not** the WorkBuddy desktop app. |
| Platform | Windows 10/11, PowerShell 5.1 or 7+ |

The plugin connects the WorkBuddy accounts already signed in on this machine to
DSH as a model provider.

**The archive contains:**

```
dsh-connect-workbuddy-5.3.0-wb1/
  INSTALL-FOR-AI.md          <- you are reading it
  README-同事必读.md          <- the same instructions, for the human
  PATCHES.md                 <- what was changed and where
  install.ps1                <- does the work
  uninstall.ps1              <- rolls it back
  verify.ps1                 <- read-only check, run this after installing
  payload/dsh-connect-workbuddy/   <- the plugin itself
  deps/                            <- three runtime dependencies a bare DSH may lack
```

---

## 1. Decide the target directory — do NOT guess

DSH's home directory is **not** always `%USERPROFILE%\.dsh`. On this machine it
is often a junction pointing at another drive. Resolve it from the environment
first, in this order:

1. If `$env:DSH_HOME` is set and non-empty → use it.
2. Otherwise `%USERPROFILE%\.dsh`.
3. Verify by checking that `<DSH_HOME>\profiles\<PROFILE>\package.json` exists.

`<PROFILE>` comes from `$env:DSH_PROFILE`, defaulting to `desktop`.

Run this and read the output **before** installing:

```powershell
"DSH_HOME    = $env:DSH_HOME"
"DSH_PROFILE = $env:DSH_PROFILE"
$h = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$p = if ($env:DSH_PROFILE) { $env:DSH_PROFILE } else { 'desktop' }
$m = Join-Path $h "profiles\$p\package.json"
"manifest    = $m"
"exists      = $(Test-Path $m)"
Get-Item $h -Force | Select-Object FullName, LinkType, Target
```

**Stop and ask the human if `exists` is `False`.** That means DSH has never been
started on this machine, or the profile is named something else. Do not create
directories to work around it.

---

## 2. Pre-flight checks

```powershell
# a) Is DSH actually installed / running?
Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue | Select-Object Id, StartTime

# b) Is the plugin already there? (if yes, install.ps1 will back it up)
$live = Join-Path $h "profiles\$p\node_modules\dsh-connect-workbuddy"
"already installed = $(Test-Path $live)"

# c) Is the archive fully extracted? (must be True)
"payload ok = $(Test-Path (Join-Path $PSScriptRoot 'payload\dsh-connect-workbuddy\package.json'))"
```

If `payload ok` is `False`, the human opened `install.ps1` from inside the zip
without extracting. **Stop** and ask them to extract the whole archive first.

---

## 3. Ask the human to quit DSH first

The plugin's files are read at startup. Overwriting them while DSH runs is
harmless (the install will still succeed) but the new code will not load until
a restart, and a half-written file could make the next start fail.

Ask them to fully quit: window closed **and** tray icon exited. Then confirm:

```powershell
$running = Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue
if ($running) { "STILL RUNNING: $($running.Id -join ', ')" } else { "not running - good" }
```

If processes remain, tell the human; do not kill them yourself unless they say so.

---

## 4. Run the installer

From the **extracted** folder (the one containing `install.ps1`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Pass `-DshHome` / `-Profile` explicitly when step 1 showed a non-default home:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -DshHome "D:\DSH\.dsh" -Profile "desktop"
```

### What it does, in order

1. Backs up `<profile>\package.json` to `package.json.bak-wb-<timestamp>`.
2. Copies the plugin to `<profile>\vendor\dsh-connect-workbuddy\`.
3. Sets `"dsh-connect-workbuddy": "file:vendor/dsh-connect-workbuddy"` in
   `dependencies` and appends the id to `dsh.profile.bundles`.
   **It uses a `file:` spec on purpose** — a future `pnpm install` then re-links
   this patched copy instead of pulling pristine 5.3.0 from the registry.
4. Copies the plugin to `<profile>\node_modules\dsh-connect-workbuddy\`, moving
   any previous install to `…bak-wb-<timestamp>` first.
5. Copies the three runtime dependencies into `<profile>\node_modules\`
   **only if absent** — it never overwrites an existing copy, because DSH ships
   its own and other plugins share it.
6. Verifies that every patch marker is present in the installed files.

Expected tail of the output:

```
[wb-install] all patch markers present
[wb-install] DONE. Next steps:
```

If you see `ERROR:` instead, go to section 7.

---

## 5. Verify

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
```

Expected:

```
[wb-verify] RESULT: OK - the patched build is installed and parses.
```

It checks seven patch markers, that the credit multiplier is no longer appended
to the model label, that the check-in button is not region-gated, and that both
bundle files pass `node --check`. It is read-only.

---

## 6. Start DSH and confirm with the human

1. Start DeepSeek Harness.
2. The plugin loads automatically; there is nothing to enable in the UI.
3. Ask the human to confirm these, in this order:
   - Settings → Plugins lists **DSH Connect WorkBuddy**.
   - The model selector shows WorkBuddy models, and the
     `DeepSeek-V4.1-Flash` chip carries a small **1017** badge and **no**
     `· x0.11` multiplier.
   - Clicking the credits chip in the composer opens a panel containing a
     **100-credit progress meter** and a **check-in** button.

If DSH starts but the plugin is missing from Settings → Plugins, the bundle id
is not being picked up — go to section 7, case B.

---

## 7. Troubleshooting

### A. `ERROR: no package.json at …`
Wrong DSH home or profile. Re-run step 1 and pass `-DshHome` / `-Profile`
explicitly. Do not create the file by hand.

### B. Installed, but the plugin does not appear in DSH
Check the manifest is valid JSON and lists the bundle:

```powershell
$m = Join-Path $h "profiles\$p\package.json"
$j = Get-Content $m -Raw -Encoding UTF8 | ConvertFrom-Json
$j.dependencies.'dsh-connect-workbuddy'
$j.dsh.profile.bundles
```

Both must mention `dsh-connect-workbuddy`. If the file no longer parses, restore
the newest `package.json.bak-wb-*` next to it and re-run the installer.

### C. DSH starts but the provider errors with "Cannot find package"
A runtime dependency is missing. Check:

```powershell
foreach ($d in '@deepseek-ai\schemastery','@deepseek-ai\cosmokit','@standard-schema\spec') {
  "$d = $(Test-Path (Join-Path $h "profiles\$p\node_modules\$d"))"
}
```

Re-run `install.ps1` (it skips dependencies that already exist) or copy the
missing folder from `deps\` into `<profile>\node_modules\` by hand.

### D. `verify.ps1` reports `patch MISSING`
The wrong build got installed — most likely an older `node_modules` copy
survived. Re-run `install.ps1`; it moves the old directory aside. If it still
fails, compare `lib\index.js` against `payload\dsh-connect-workbuddy\lib\index.js`
(they must be byte-identical).

### E. Rollback
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```
It restores the previous `node_modules` copy, removes the vendored copy, and
strips the dependency + bundle entries from `package.json`.

---

## 8. Rules for you, the agent

- **Never** edit files under `node_modules\dsh-connect-workbuddy\` by hand after
  installing. Change `payload\` and re-run `install.ps1` instead.
- **Never** run `pnpm install`, `npm install`, or `pnpm update` to "fix" this.
  The `file:` spec is deliberate; a registry install would silently replace the
  patched build with pristine 5.3.0.
- **Never** delete `package.json.bak-wb-*` files. They are the rollback path.
- Do not add the plugin id to `cordis.patch.yml`. The upstream package ships its
  own `cordis.patch.yml` with the `insert:` block; duplicating it there causes a
  duplicate-registration error.
- Report to the human what `verify.ps1` printed, verbatim. Do not summarise it
  into "it worked" without showing the RESULT line.

---

## 9. What the six patches do

See `PATCHES.md` for the exact anchors. In short:

1. The model chip no longer appends the credit multiplier (`· x0.11`).
2. `DeepSeek-V4.1-Flash` renders a small `1017` badge, pure CSS, so the official
   `ui-deepseek-model-label-1017` contribution keeps working untouched.
3. The composer credits panel gained a one-tap **check-in for every account**.
4. The panel shows a **100-credit meter** for the currently selected account.
5. When that account has spent 100 credits, the panel **hands over** to the
   other account automatically, and the counter resets for the new stint.
6. The check-in button is shown in the **global** region too. Note: the
   international gateway currently answers `code 10001 / "check-in activity is
   not active"`, so on global accounts the button reports that no campaign is
   running rather than hiding itself. That is an upstream seasonal state, not a
   bug in this build.
