#Requires -Version 7
<#
.SYNOPSIS
  Unified all-in-one build pipeline for the Spicetify CLI fork.

.DESCRIPTION
  1. Fetches/updates the Marketplace and rxri/spicetify-extensions
     source repositories into a temporary working directory.
  2. Builds the Marketplace TypeScript/SCSS frontend with the
     spicetify-creator toolchain (pnpm).
  3. Syncs the compiled Marketplace CustomApp into CustomApps/marketplace
     and copies the rxri extensions into the native Extensions/ directory.
  4. Compiles the customized Go CLI binary with the bundled assets
     resolved natively at runtime.

  The resulting binary, together with the CustomApps/, Extensions/,
  Themes/ and jsHelper/ folders, can be zipped into a release archive
  using the same layout the official installers expect.
#>

[CmdletBinding()]
param(
    [string] $Version = "v2.39.9-allinone",
    [string] $WorkDir = "",
    [string] $MarketplaceRepo = "https://github.com/spicetify/marketplace.git",
    [string] $ExtensionsRepo = "https://github.com/rxri/spicetify-extensions.git",
    [string] $OutputName = "spicetify-allinone.exe",
    [switch] $SkipFetch,
    [switch] $SkipBuildAssets,
    [switch] $Clean
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($WorkDir)) {
    $WorkDir = Join-Path $env:TEMP "alus-build"
}

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "    ERR $msg" -ForegroundColor Red; exit 1 }

# Map of rxri extension source files (relative to extensions repo) ->
# native Extensions/ destination filenames.
$ExtensionMap = [ordered]@{
    "adblock\adblock.js"                     = "adblock.js"
    "phraseToPlaylist\phraseToPlaylist.js"   = "phraseToPlaylist.js"
    "songstats\songstats.js"                 = "songstats.js"
    "wikify\wikify.js"                       = "wikify.js"
    "writeify\writeify.js"                   = "writeify.js"
    "formatColors\formatColors.js"           = "formatColors.js"
    "featureshuffle\featureshuffle.js"       = "featureshuffle.js"
    "old-sidebar\oldSidebar.js"              = "oldSidebar.js"
}

# ---------------------------------------------------------------------------
# 0. Pre-flight: ensure pnpm is available (marketplace build requires it).
# ---------------------------------------------------------------------------
Write-Step "Checking toolchain"
if (-not (Get-Command go -ErrorAction SilentlyContinue)) { Write-Err "go not found on PATH" }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Err "node not found on PATH" }
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Host "    pnpm not found; installing via npm..." -ForegroundColor Yellow
    npm install -g pnpm@10 --no-audit --no-fund --loglevel=error
    if ($LASTEXITCODE -ne 0) { Write-Err "failed to install pnpm" }
}
Write-Ok "go=$(go version), node=$(node --version), pnpm=$(pnpm --version)"

# ---------------------------------------------------------------------------
# 1. Fetch / update source repositories.
# ---------------------------------------------------------------------------
$mpDir   = Join-Path $WorkDir "marketplace"
$extDir  = Join-Path $WorkDir "spicetify-extensions"

if (-not $SkipFetch) {
    Write-Step "Fetching source repositories"
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

    function Sync-Repo([string]$url, [string]$dest) {
        if (Test-Path (Join-Path $dest ".git")) {
            Write-Host "    updating $dest" -ForegroundColor DarkGray
            git -C $dest pull --ff-only --depth 1 2>$null
        } else {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            git clone --depth 1 $url $dest
            if ($LASTEXITCODE -ne 0) { Write-Err "failed to clone $url" }
        }
    }
    Sync-Repo $MarketplaceRepo $mpDir
    Sync-Repo $ExtensionsRepo  $extDir
    Write-Ok "repositories ready"
}

# ---------------------------------------------------------------------------
# 2. Build the Marketplace TypeScript frontend.
# ---------------------------------------------------------------------------
if (-not $SkipBuildAssets) {
    Write-Step "Building Marketplace frontend"
    Push-Location $mpDir
    try {
        pnpm install --config.strict-peer-dependencies=false 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Err "marketplace pnpm install failed" }
        pnpm run build:prod 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-Err "marketplace build failed" }
    } finally { Pop-Location }
    $mpDist = Join-Path $mpDir "dist"
    if (-not (Test-Path (Join-Path $mpDist "index.js"))) { Write-Err "marketplace dist/index.js missing" }
    Write-Ok "marketplace built"

    # 3a. Sync Marketplace dist -> CustomApps/marketplace
    Write-Step "Syncing Marketplace into CustomApps/marketplace"
    $mpDest = Join-Path $RepoRoot "CustomApps\marketplace"
    if ($Clean -and (Test-Path $mpDest)) { Remove-Item $mpDest -Recurse -Force }
    New-Item -ItemType Directory -Path $mpDest -Force | Out-Null
    Copy-Item (Join-Path $mpDist "*") -Destination $mpDest -Recurse -Force
    Write-Ok "CustomApps/marketplace updated ($((Get-ChildItem $mpDest -File).Count) files)"

    # 3b. Copy rxri extensions -> native Extensions/
    Write-Step "Syncing rxri extensions into Extensions/"
    foreach ($srcRel in $ExtensionMap.Keys) {
        $src = Join-Path $extDir $srcRel
        $dst = Join-Path $RepoRoot "Extensions\$($ExtensionMap[$srcRel])"
        if (-not (Test-Path $src)) { Write-Err "missing extension source: $src" }
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
    Write-Ok "Extensions/ updated with $($ExtensionMap.Count) rxri extensions"
}

# ---------------------------------------------------------------------------
# 4. Compile the customized Go CLI binary.
# ---------------------------------------------------------------------------
Write-Step "Compiling CLI binary"
$out = Join-Path $RepoRoot $OutputName
go build -ldflags "-X main.version=$Version" -o $out .
if ($LASTEXITCODE -ne 0) { Write-Err "go build failed" }
Write-Ok "binary: $out ($((Get-Item $out).Length) bytes)"

Write-Step "All-in-one build complete"
Write-Host "    Version: $Version" -ForegroundColor Green
Write-Host "    Binary:  $out" -ForegroundColor Green
Write-Host "    Assets:  CustomApps\marketplace, Extensions\*.js" -ForegroundColor Green
Write-Host "    Package these alongside Themes\ and jsHelper\ for distribution." -ForegroundColor DarkGray
