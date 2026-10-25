# =====================================================================
#  dsh-connect-workbuddy 5.3.0-wb1  -  uninstaller
#  Restores whatever was installed before install.ps1 ran, or removes the
#  plugin cleanly when there was nothing before it.
#  ASCII only (see install.ps1 for why).
# =====================================================================
[CmdletBinding()]
param(
    [string]$DshHome = $env:DSH_HOME,
    [string]$Profile = $env:DSH_PROFILE
)

$ErrorActionPreference = 'Stop'
$PackageName = 'dsh-connect-workbuddy'

function Say($msg) { Write-Host "[wb-uninstall] $msg" }
function Fail($msg) { Write-Host "[wb-uninstall] ERROR: $msg" -ForegroundColor Red; exit 1 }

if ([string]::IsNullOrWhiteSpace($DshHome)) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
if ([string]::IsNullOrWhiteSpace($Profile)) { $Profile = 'desktop' }

$DshHome    = [System.IO.Path]::GetFullPath($DshHome)
$profileDir = Join-Path $DshHome (Join-Path 'profiles' $Profile)
$manifest   = Join-Path $profileDir 'package.json'

if (-not (Test-Path $manifest)) { Fail "no package.json at $manifest" }
Say "profile: $profileDir"

# ------------------------------------------------------- remove the live copy
$liveDir = Join-Path $profileDir "node_modules\$PackageName"
if (Test-Path $liveDir) {
    Remove-Item $liveDir -Recurse -Force
    Say "removed $liveDir"
}

# --------------------------------------------------- restore the newest backup
$backups = @(Get-ChildItem $profileDir -Filter 'node_modules\dsh-connect-workbuddy.bak-wb-*' -Directory -ErrorAction SilentlyContinue)
if ($backups.Count -gt 0) {
    $newest = $backups | Sort-Object Name -Descending | Select-Object -First 1
    Move-Item $newest.FullName $liveDir -Force
    Say "restored previous install from $($newest.Name)"
} else {
    Say "no previous install to restore"
}

# ------------------------------------------------------------ drop the vendor
$vendorAbs = Join-Path $profileDir "vendor\$PackageName"
if (Test-Path $vendorAbs) {
    Remove-Item $vendorAbs -Recurse -Force
    Say "removed vendored copy"
}

# --------------------------------------------------- clean up package.json
$raw  = Get-Content $manifest -Raw -Encoding UTF8
$json = $raw | ConvertFrom-Json
$changed = $false

if ($null -ne $json.dependencies -and $null -ne $json.dependencies.PSObject.Properties[$PackageName]) {
    $json.dependencies.PSObject.Properties.Remove($PackageName)
    $changed = $true
    Say "removed dependency entry"
}

if ($null -ne $json.dsh -and $null -ne $json.dsh.profile -and $null -ne $json.dsh.profile.bundles) {
    $bundles = @($json.dsh.profile.bundles) | Where-Object { $_ -ne $PackageName }
    $json.dsh.profile.bundles = $bundles
    $changed = $true
    Say "removed from dsh.profile.bundles"
}

if ($changed) {
    $json | ConvertTo-Json -Depth 32 | Set-Content $manifest -Encoding UTF8
    Say "package.json updated"
}

# ------------------------------------------- point at the newest full backup
$manifestBackups = @(Get-ChildItem $profileDir -Filter 'package.json.bak-wb-*' -File -ErrorAction SilentlyContinue)
if ($manifestBackups.Count -gt 0) {
    Say ''
    Say "A package.json backup exists: $($manifestBackups[-1].Name)"
    Say "If anything looks wrong, copy it back over package.json."
}

Say ''
Say 'DONE. Restart DeepSeek Harness.'
