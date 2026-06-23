$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

<#
.SYNOPSIS
  One-click installer for the All-In-One Spicetify fork.

.DESCRIPTION
  Downloads the latest release, extracts spicetify + CustomApps +
  Extensions + Themes + jsHelper to the install directory, adds it
  to PATH, and runs "spicetify backup apply" so the Marketplace and
  rxri extensions go live immediately.

  Can be run directly from the web:
    iwr -useb https://raw.githubusercontent.com/<org>/aluspicetify/main/install-alus.ps1 | iex
#>

#region Variables
$InstallDir = "$env:LOCALAPPDATA\spicetify"
$OldDir     = "$HOME\spicetify-cli"
$RepoApi    = "https://api.github.com/repos/alunit3/aluspicetify/releases/latest"
#endregion Variables

#region Functions
function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "    ERR $msg" -ForegroundColor Red; exit 1 }

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    -not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-Architecture {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { 'x64' }
    elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' }
    else { 'x32' }
}

function Move-OldFolder {
    if (Test-Path $OldDir) {
        Write-Step "Moving old spicetify-cli folder"
        Copy-Item "$OldDir\*" $InstallDir -Recurse -Force
        Remove-Item $OldDir -Recurse -Force
        Write-Ok "moved"
    }
}

function Get-LatestRelease {
    Write-Host "    Fetching latest release..." -NoNewline
    $release = Invoke-RestMethod -Uri $RepoApi
    $tag = $release.tag_name -replace 'v', ''
    $assets = $release.assets
    $arch = Get-Architecture
    $pattern = "windows-$arch.zip"
    $asset = $assets | Where-Object { $_.name -like "*$pattern" } | Select-Object -First 1
    if (-not $asset) {
        # Fall back to x64 if specific arch not found
        $asset = $assets | Where-Object { $_.name -like "*windows-x64.zip" } | Select-Object -First 1
    }
    if (-not $asset) { Write-Err "No Windows release found (arch=$arch)" }
    Write-Ok "v$tag ($($asset.name))"
    return $asset.browser_download_url
}

function Add-ToPath {
    Write-Host "    Adding to PATH..." -NoNewline
    $user = [EnvironmentVariableTarget]::User
    $path = [Environment]::GetEnvironmentVariable('PATH', $user)
    $path = $path -replace "$([regex]::Escape($OldDir))\\*;*", ''
    if ($path -notlike "*$InstallDir*") {
        $path = "$path;$InstallDir"
    }
    [Environment]::SetEnvironmentVariable('PATH', $path, $user)
    $env:PATH = $path
    Write-Ok "$InstallDir"
}

function Install-Spicetify {
    Write-Step "Downloading All-In-One Spicetify"
    $url = Get-LatestRelease
    $zipPath = Join-Path $env:TEMP "alus-spicetify.zip"

    Write-Host "    Downloading $url..." -NoNewline
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    Write-Ok "downloaded"

    Write-Step "Extracting to $InstallDir"
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
    Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force
    Write-Ok "extracted"

    Add-ToPath

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}
#endregion Functions

#region Main
Write-Host ""
Write-Host "  All-In-One Spicetify Installer" -ForegroundColor White
Write-Host "  Marketplace + rxri extensions pre-bundled" -ForegroundColor DarkGray
Write-Host ""

# Admin check
if (-not (Test-Admin)) {
    Write-Host "    WARN: Running as administrator is not recommended." -ForegroundColor Yellow
    Write-Host "    Spicetify should run as a normal user." -ForegroundColor Yellow
    $choice = Read-Host "    Continue anyway? (y/N)"
    if ($choice -ne 'y' -and $choice -ne 'Y') { exit 0 }
}

Move-OldFolder
Install-Spicetify

Write-Step "Verifying installation"
$exe = Join-Path $InstallDir "spicetify.exe"
if (-not (Test-Path $exe)) { Write-Err "spicetify.exe not found in $InstallDir" }
$ver = & $exe --version 2>&1
Write-Ok "installed: $ver"

# Verify bundled assets
$mpPath = Join-Path $InstallDir "CustomApps\marketplace\index.js"
$adblockPath = Join-Path $InstallDir "Extensions\adblock.js"
if (Test-Path $mpPath) { Write-Ok "Marketplace bundled" } else { Write-Host "    WARN: Marketplace not found" -ForegroundColor Yellow }
if (Test-Path $adblockPath) { Write-Ok "adblockify bundled" } else { Write-Host "    WARN: adblock.js not found" -ForegroundColor Yellow }

Write-Step "Applying to Spotify"
Write-Host "    Running: spicetify backup apply" -ForegroundColor DarkGray
Write-Host "    (Make sure Spotify is installed and has been launched at least once)" -ForegroundColor DarkGray
Write-Host ""
& $exe backup apply 2>&1 | ForEach-Object { Write-Host "    $_" }
$applyExit = $LASTEXITCODE

Write-Host ""
if ($applyExit -eq 0) {
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "  Restart Spotify to see the Marketplace and extensions." -ForegroundColor Green
} else {
    Write-Host "  Spicetify installed, but apply failed (exit $applyExit)." -ForegroundColor Yellow
    Write-Host "  Make sure Spotify is installed, then run:" -ForegroundColor Yellow
    Write-Host "    spicetify backup apply" -ForegroundColor White
}
Write-Host ""
Write-Host "  Open a NEW terminal to use 'spicetify' command." -ForegroundColor DarkGray
#endregion Main
