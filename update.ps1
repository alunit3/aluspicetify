#Requires -Version 7
<#
.SYNOPSIS
  One-command update for the all-in-one Spicetify fork.

.DESCRIPTION
  Re-syncs your fork with the latest upstream spicetify/cli, then
  regenerates all bundled assets (Marketplace + rxri extensions)
  and recompiles the binary.

  What it does, in order:
    1. Saves your Go/manifest source modifications as a patch.
    2. Resets tracked files to upstream state (new files are untouched).
    3. Pulls the latest spicetify/cli.
    4. Re-applies your source patch (3-way merge on conflict).
    5. Rebuilds Marketplace + extensions via build-allinone.
    6. Runs go vet + tests to verify.

  Usage:  .\update.ps1
          .\update.ps1 -SkipAssetBuild    # skip marketplace/extension rebuild
          .\update.ps1 -Upstream origin -Branch main
#>

[CmdletBinding()]
param(
    [string] $Upstream = "origin",
    [string] $Branch   = "main",
    [switch] $SkipAssetBuild,
    [switch] $NoVerify
)

$ErrorActionPreference = "Stop"
$RepoRoot  = $PSScriptRoot
$PatchFile = Join-Path $RepoRoot "alus-source.patch"

# Tracked upstream files we modify (new untracked files like bundle.go
# are NOT listed here — they survive git checkout/pull automatically).
$SourceFiles = @(
    "src/utils/config.go",
    "src/cmd/apply.go",
    "src/cmd/watch.go",
    "manifest.json"
)

function Write-Step([string]$m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok([string]$m)   { Write-Host "    OK  $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "    WARN $m" -ForegroundColor Yellow }
function Write-Err([string]$m)  { Write-Host "    ERR $m" -ForegroundColor Red; exit 1 }

Push-Location $RepoRoot
try {
    # -----------------------------------------------------------------------
    # 1. Save current source modifications as a patch.
    # -----------------------------------------------------------------------
    Write-Step "Saving source modifications"
    $dirty = $false
    foreach ($f in $SourceFiles) {
        if (git status --porcelain -- $f 2>$null) { $dirty = $true; break }
    }

    if ($dirty) {
        # Diff against HEAD so staged + unstaged changes are both captured.
        git diff HEAD -- $SourceFiles > $PatchFile 2>$null
        $size = (Get-Item $PatchFile -ErrorAction SilentlyContinue).Length
        if ($size -gt 0) {
            Write-Ok "patch saved ($size bytes): $PatchFile"
        } else {
            Write-Warn "source files modified but patch is empty — check git status"
        }
    } elseif (Test-Path $PatchFile) {
        Write-Ok "no uncommitted source changes; reusing existing patch ($((Get-Item $PatchFile).Length) bytes)"
    } else {
        Write-Err "no source changes to save and no existing patch at $PatchFile"
    }

    # -----------------------------------------------------------------------
    # 2. Reset tracked files to upstream state.
    #    Untracked files (bundle.go, build scripts, assets) are untouched.
    # -----------------------------------------------------------------------
    Write-Step "Resetting tracked files to upstream"
    git reset HEAD -- . 2>$null
    git checkout -- . 2>$null
    Write-Ok "tracked files reset"

    # -----------------------------------------------------------------------
    # 3. Pull latest upstream.
    # -----------------------------------------------------------------------
    Write-Step "Fetching latest upstream ($Upstream/$Branch)"
    git fetch $Upstream $Branch 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Err "git fetch failed" }

    Write-Step "Merging $Upstream/$Branch"
    git merge $Upstream/$Branch 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "merge produced conflicts — resolve them, then re-run with -SkipAssetBuild"
        exit 1
    }
    $latestCommit = git log --oneline -1 2>$null
    Write-Ok "now at: $latestCommit"

    # -----------------------------------------------------------------------
    # 4. Re-apply source modifications (3-way merge for conflict safety).
    # -----------------------------------------------------------------------
    Write-Step "Re-applying source modifications"
    if (-not (Test-Path $PatchFile)) {
        Write-Warn "no patch file found — skipping (source mods not applied)"
    } else {
        git apply --3way $PatchFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "patch did not apply cleanly. Conflicts to resolve:"
            git status --short 2>&1 | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
            Write-Host ""
            Write-Host "    Resolve the conflicts in the files above, then:" -ForegroundColor White
            Write-Host "      .\update.ps1 -SkipAssetBuild" -ForegroundColor White
            exit 1
        }
        Write-Ok "source modifications re-applied"
    }

    # -----------------------------------------------------------------------
    # 5. Rebuild assets + binary.
    # -----------------------------------------------------------------------
    if (-not $SkipAssetBuild) {
        $buildScript = Join-Path $RepoRoot "build-allinone.ps1"
        if (Test-Path $buildScript) {
            Write-Step "Rebuilding assets and binary"
            & $buildScript -SkipFetch:$false
            if ($LASTEXITCODE -ne 0) { Write-Err "build-allinone failed" }
        } else {
            Write-Warn "build-allinone.ps1 not found — skipping asset rebuild"
            Write-Warn "run it manually to regenerate Marketplace + extensions"
        }
    }

    # -----------------------------------------------------------------------
    # 6. Verify.
    # -----------------------------------------------------------------------
    if (-not $NoVerify) {
        Write-Step "Verifying"
        go vet ./... 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Err "go vet failed" }

        go test ./src/apply/ 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Err "tests failed" }
        Write-Ok "verification passed"
    }

    Write-Step "Update complete"
    Write-Host "    Run: spicetify backup apply" -ForegroundColor Green

} finally {
    Pop-Location
}
