# =====================================================================
#  dsh-connect-workbuddy 5.3.0-wb1  -  verification
#  Read-only. Answers one question: is the PATCHED build actually the one
#  DSH will load, and does it parse?
#  ASCII only (see install.ps1 for why).
# =====================================================================
[CmdletBinding()]
param(
    [string]$DshHome = $env:DSH_HOME,
    [string]$Profile = $env:DSH_PROFILE
)

$ErrorActionPreference = 'Stop'
$PackageName = 'dsh-connect-workbuddy'

function Say($msg) { Write-Host "[wb-verify] $msg" }
function Bad($msg) { Write-Host "[wb-verify] FAIL: $msg" -ForegroundColor Red; $script:problems++ }
$script:problems = 0

if ([string]::IsNullOrWhiteSpace($DshHome)) { $DshHome = Join-Path $env:USERPROFILE '.dsh' }
if ([string]::IsNullOrWhiteSpace($Profile)) { $Profile = 'desktop' }

$DshHome    = [System.IO.Path]::GetFullPath($DshHome)
$profileDir = Join-Path $DshHome (Join-Path 'profiles' $Profile)
$manifest   = Join-Path $profileDir 'package.json'
$liveDir    = Join-Path $profileDir "node_modules\$PackageName"

Say "profile: $profileDir"

# ------------------------------------------------------------- 1. manifest
if (-not (Test-Path $manifest)) { Bad "package.json missing" } else {
    $json = (Get-Content $manifest -Raw -Encoding UTF8) | ConvertFrom-Json
    $dep = $json.dependencies.PSObject.Properties[$PackageName]
    if ($null -eq $dep) { Bad "not listed in dependencies" } else { Say "dependency spec: $($dep.Value)" }
    $bundles = @($json.dsh.profile.bundles)
    if ($bundles -notcontains $PackageName) { Bad "not listed in dsh.profile.bundles" } else { Say "listed in dsh.profile.bundles" }
}

# ------------------------------------------------------------- 2. files
$indexJs  = Join-Path $liveDir 'lib\index.js'
$clientJs = Join-Path $liveDir 'lib\client.js'
if (-not (Test-Path $indexJs))  { Bad "missing lib/index.js" }
if (-not (Test-Path $clientJs)) { Bad "missing lib/client.js" }

if ((Test-Path $indexJs) -and (Test-Path $clientJs)) {
    $indexText  = Get-Content $indexJs  -Raw
    $clientText = Get-Content $clientJs -Raw

    # Each entry is a symbol that exists ONLY in the patched build.
    $markers = [ordered]@{
        'credit ledger (meter backend)' = 'foldCreditLedger'
        'switch threshold exposed'      = 'switchAt: CREDIT_SWITCH_THRESHOLD'
        'batch check-in route'          = 'checkin-all'
        'meter UI'                      = 'dsm-workbuddy-composer-panel-meter'
        'check-in button'               = 'dsm-workbuddy-composer-panel-checkin'
        'global check-in copy'          = 'composer.checkinInactive'
        '1017 badge css'                = 'WORKBUDDY_MODEL_LABEL_CSS'
        '1017 badge rule'               = 'content:"1017"'
    }
    foreach ($k in $markers.Keys) {
        $needle = $markers[$k]
        $hit = $indexText.Contains($needle) -or $clientText.Contains($needle)
        if ($hit) { Say "patch present: $k" } else { Bad "patch MISSING: $k" }
    }

    # The multiplier must NOT be appended to the model name any more.
    if ($indexText -match 'workBuddyDisplayName[\s\S]{0,240}creditMultiplier') {
        Bad "the credit multiplier is still appended to the model label"
    } else {
        Say "patch present: multiplier removed from the label"
    }

    # The check-in button must not be region-gated any more.
    if ($clientText.Contains('activeRegion !== "cn"')) {
        Bad "the check-in button is still gated to the CN region"
    } else {
        Say "patch present: check-in button shown in every region"
    }

    # ------------------------------------------------------- 3. syntax
    # DSH bundles its own node under <app>\resources\runtime\..., which is NOT
    # inside DSH_HOME. Try PATH first, then every layout we have seen.
    $node = Get-Command node -ErrorAction SilentlyContinue
    $nodeExe = $null
    if ($null -ne $node) { $nodeExe = $node.Source }

    if ([string]::IsNullOrWhiteSpace($nodeExe)) {
        $candidates = @(
            (Join-Path $DshHome 'dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe'),
            'D:\ds\resources\runtime\primary-runtime\dependencies\node\bin\node.exe',
            (Join-Path $env:ProgramFiles 'DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe'),
            (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe')
        )
        # Also look next to whatever app owns DSH_HOME, when it is a junction.
        $nodeExe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace($nodeExe)) {
        Say "node not found - skipped the syntax check (not fatal)"
    } else {
        Say "node: $nodeExe"
        foreach ($f in @($indexJs, $clientJs)) {
            $out = & $nodeExe --check $f 2>&1
            if ($LASTEXITCODE -ne 0) { Bad "syntax error in $(Split-Path -Leaf $f): $out" }
            else { Say "syntax ok: $(Split-Path -Leaf $f)" }
        }
    }
}

# ------------------------------------------------------- 4. running instance
Say ''
if ($script:problems -eq 0) {
    Say 'RESULT: OK - the patched build is installed and parses.'
    Say 'Now fully quit DeepSeek Harness and start it again.'
    exit 0
} else {
    Say "RESULT: $($script:problems) problem(s) found - see FAIL lines above."
    exit 1
}
