# =====================================================================
#  dsh-connect-workbuddy 5.3.0-wb1  -  installer
#  ASCII only on purpose: Windows PowerShell 5.1 mis-reads UTF-8 without
#  a BOM, and this script must never fail because of a Chinese character.
#  The Chinese explanation lives in INSTALL-FOR-AI.md / README-<cn>.md.
# =====================================================================
[CmdletBinding()]
param(
    [string]$DshHome = $env:DSH_HOME,
    [string]$Profile = $env:DSH_PROFILE,
    [switch]$SkipDeps
)

$ErrorActionPreference = 'Stop'
$PackageVersion = '5.3.0-wb1'
$PackageName    = 'dsh-connect-workbuddy'

function Say($msg) { Write-Host "[wb-install] $msg" }
function Fail($msg) { Write-Host "[wb-install] ERROR: $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- locate DSH
if ([string]::IsNullOrWhiteSpace($DshHome)) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
if ([string]::IsNullOrWhiteSpace($Profile)) { $Profile = 'desktop' }

$DshHome    = [System.IO.Path]::GetFullPath($DshHome)
$profileDir = Join-Path $DshHome (Join-Path 'profiles' $Profile)
$manifest   = Join-Path $profileDir 'package.json'

Say "DSH home : $DshHome"
Say "profile  : $Profile"
Say "target   : $profileDir"

if (-not (Test-Path $manifest)) {
    Fail "no package.json at $manifest - is DSH installed and has it been started once?"
}

# ------------------------------------------------------------ sanity: files
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $here 'payload\dsh-connect-workbuddy'
$depsDir = Join-Path $here 'deps'

if (-not (Test-Path (Join-Path $payload 'package.json'))) {
    Fail "payload is missing - unzip the WHOLE archive and run install.ps1 from inside it"
}

# ------------------------------------------------------------- read manifest
# Parse BEFORE touching anything: a corrupt manifest must leave the machine
# exactly as it was found.
$raw  = Get-Content $manifest -Raw -Encoding UTF8
try {
    $json = $raw | ConvertFrom-Json
} catch {
    Fail "package.json is not valid JSON - fix or restore it before installing. Nothing was changed. ($($_.Exception.Message))"
}

# ------------------------------------------------------- backup the manifest
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$manifest.bak-wb-$stamp"
Copy-Item $manifest $backup -Force
Say "backed up package.json -> $(Split-Path -Leaf $backup)"

if ($null -eq $json.dependencies) {
    $json | Add-Member -NotePropertyName dependencies -NotePropertyValue ([pscustomobject]@{}) -Force
}

# Keep the patched copy inside the profile and reference it by path, so a
# future `pnpm install` re-links OUR copy instead of pulling the pristine
# 5.3.0 from the registry (which would silently drop every patch).
$vendorRel = "vendor/$PackageName"
$vendorAbs = Join-Path $profileDir ($vendorRel -replace '/', '\')

if (Test-Path $vendorAbs) { Remove-Item $vendorAbs -Recurse -Force }
New-Item -ItemType Directory -Path $vendorAbs -Force | Out-Null
Copy-Item (Join-Path $payload '*') $vendorAbs -Recurse -Force
Say "vendored plugin -> $vendorAbs"

# --------------------------------------------------- register in package.json
$spec = "file:$vendorRel"
$json.dependencies | Add-Member -NotePropertyName $PackageName -NotePropertyValue $spec -Force

if ($null -eq $json.dsh -or $null -eq $json.dsh.profile -or $null -eq $json.dsh.profile.bundles) {
    Fail "package.json has no dsh.profile.bundles array - refusing to guess"
}
$bundles = @($json.dsh.profile.bundles)
if ($bundles -notcontains $PackageName) {
    $bundles += $PackageName
    $json.dsh.profile.bundles = $bundles
    Say "added to dsh.profile.bundles"
} else {
    Say "already listed in dsh.profile.bundles"
}

$json | ConvertTo-Json -Depth 32 | Set-Content $manifest -Encoding UTF8
Say "package.json updated (dependency spec: $spec)"

# --------------------------------------------- place the plugin where DSH looks
$liveDir = Join-Path $profileDir "node_modules\$PackageName"
if (Test-Path $liveDir) {
    $liveBackup = "$liveDir.bak-wb-$stamp"
    Move-Item $liveDir $liveBackup -Force
    Say "previous install moved aside -> $(Split-Path -Leaf $liveBackup)"
}
New-Item -ItemType Directory -Path $liveDir -Force | Out-Null
Copy-Item (Join-Path $vendorAbs '*') $liveDir -Recurse -Force
Say "plugin installed -> $liveDir"

# --------------------------------------------------------- runtime dependencies
# Only the ones the bundle imports and a bare profile may not already carry.
# Never overwrite an existing copy: DSH ships its own and other plugins share it.
if (-not $SkipDeps) {
    $depList = @(
        '@deepseek-ai\schemastery',
        '@deepseek-ai\cosmokit',
        '@standard-schema\spec'
    )
    $nm = Join-Path $profileDir 'node_modules'
    foreach ($rel in $depList) {
        $src = Join-Path $depsDir $rel
        $dst = Join-Path $nm    $rel
        if (-not (Test-Path $src)) { Say "dependency not bundled, skipped: $rel"; continue }
        if (Test-Path $dst) { Say "dependency already present, kept: $rel"; continue }
        $parent = Split-Path -Parent $dst
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $src $dst -Recurse -Force
        Say "dependency installed: $rel"
    }
}

# ------------------------------------------------------------------- checksum
$indexJs = Join-Path $liveDir 'lib\index.js'
$clientJs = Join-Path $liveDir 'lib\client.js'
foreach ($f in @($indexJs, $clientJs)) {
    if (-not (Test-Path $f)) { Fail "install incomplete, missing: $f" }
}

$markers = @{
    'ledger (100-credit meter)'   = 'foldCreditLedger'
    'batch check-in route'        = 'checkin-all'
    'meter UI'                    = 'dsm-workbuddy-composer-panel-meter'
    'global check-in button'      = 'composer.checkinInactive'
}
$indexText  = Get-Content $indexJs  -Raw
$clientText = Get-Content $clientJs -Raw
$allOk = $true
foreach ($k in $markers.Keys) {
    $hit = $indexText.Contains($markers[$k]) -or $clientText.Contains($markers[$k])
    if (-not $hit) { $allOk = $false; Say "MISSING patch marker: $k" }
}
if ($allOk) { Say "all patch markers present" } else { Fail "the installed files are NOT the patched build" }

Say ''
Say 'DONE. Next steps:'
Say '  1. Fully quit DeepSeek Harness (tray icon too) and start it again.'
Say '  2. Open Settings -> Plugins and confirm "DSH Connect WorkBuddy" is listed.'
Say '  3. The composer credits chip should show a "100-credit" meter when clicked.'
Say ''
Say "Rollback: run uninstall.ps1 -DshHome `"$DshHome`" -Profile `"$Profile`""
