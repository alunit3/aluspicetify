<h3 align="center"><a href="https://spicetify.app/"><img src="https://i.imgur.com/iwcLITQ.png" width="600px"></a></h3>

<p align="center">
  <strong>All-In-One Spicetify Fork — Marketplace &amp; rxri Extensions Pre-Bundled</strong>
</p>

<p align="center">
  <a href="https://github.com/spicetify/cli/releases/latest"><img src="https://img.shields.io/github/release/spicetify/cli/all.svg?colorB=97CA00&label=upstream%20version"></a>
  <a href="https://discord.gg/VnevqPp2Rr"><img src="https://img.shields.io/discord/842219447716151306?label=chat&logo=discord&logoColor=discord"></a>
</p>

---

Command-line tool to customize the official Spotify client.
Supports **Windows**, **macOS** and **Linux**.

This is a self-contained fork of [spicetify/cli](https://github.com/spicetify/cli) that bundles the
[Spicetify Marketplace](https://github.com/spicetify/marketplace) and all extensions from
[rxri/spicetify-extensions](https://github.com/rxri/spicetify-extensions) **natively**. When you
install this version and run `spicetify apply`, you get a fully customized Spotify client with the
Marketplace and ad-blocking extensions active out-of-the-box — no manual secondary downloads, git
clones, or configuration appending required.

<img src=".github/assets/logo.png" alt="img" align="right" width="560px" height="400px">

### What's Pre-Bundled

**Custom App:**
- **Marketplace** — in-client storefront to browse and install themes &amp; extensions

**Extensions (active by default):**
- **adblockify** (`adblock.js`) — block audio/stream ads
- **Phrase to Playlist** (`phraseToPlaylist.js`) — turn a phrase into a playlist
- **Song Stats** (`songstats.js`) — display a song's audio features
- **WikiFy** (`wikify.js`) — view an artist's Wikipedia page
- **Writeify** (`writeify.js`) — take notes on songs, albums, artists
- **Format colors** (`formatColors.js`) — convert colors to `color.ini` format
- **Feature Shuffle** (`featureshuffle.js`) — playlist based on audio features

All original Spicetify built-in extensions (`fullAppDisplay.js`, `keyboardShortcut.js`, etc.) and
Custom Apps (`lyrics-plus`, `new-releases`, `reddit`) are also included.

### Features

- Change colors across the User Interface
- Inject CSS for advanced customization
- Inject Extensions to extend functionalities, manipulate UI and control player
- Inject Custom Apps
- **Marketplace &amp; rxri extensions load automatically — no extra setup**

---

## Installation

### One-Click Install (recommended)

#### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/alunit3/aluspicetify/main/install-alus.ps1 | iex
```

Or download [`install-alus.bat`](./install-alus.bat) and double-click it.

#### macOS / Linux (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/alunit3/aluspicetify/main/install-alus.sh | bash
```

The one-click scripts will:

1. Download the latest release archive for your platform
2. Extract `spicetify` + `CustomApps/` + `Extensions/` + `Themes/` + `jsHelper/` to your install directory
3. Add spicetify to your `PATH`
4. Run `spicetify backup apply` so the Marketplace and extensions go live immediately

> **Note:** Spotify must be installed and launched at least once before running the installer.

### Manual Install

#### Windows

1. Download `spicetify-<version>-windows-x64.zip` from the [Releases page](../../releases/latest)
2. Extract the zip to `%LOCALAPPDATA%\spicetify\`
3. Add `%LOCALAPPDATA%\spicetify` to your `PATH` environment variable
4. Open a new terminal and run:
   ```powershell
   spicetify backup apply
   ```

#### macOS / Linux

1. Download `spicetify-<version>-darwin-arm64.tar.gz` (or your platform's archive) from [Releases](../../releases/latest)
2. Extract:
   ```bash
   mkdir -p ~/.spicetify
   tar xzf spicetify-*.tar.gz -C ~/.spicetify
   chmod +x ~/.spicetify/spicetify
   ```
3. Add to `PATH` (add to your shell profile):
   ```bash
   export PATH="$PATH:$HOME/.spicetify"
   ```
4. Apply:
   ```bash
   spicetify backup apply
   ```

---

## Basic Usage

After installation, the Marketplace and all bundled extensions are active immediately. To
customize further:

```bash
# Browse all config values
spicetify config

# Enable an additional extension
spicetify config extensions fullAppDisplay.js

# Set a theme
spicetify config current_theme SpicetifyDefault

# Apply changes
spicetify apply

# Restore Spotify to stock
spicetify restore
```

### Disabling the Bundled Extensions

The bundled Marketplace and rxri extensions are force-injected at runtime. To opt out entirely
(for example, to use a minimal setup):

```bash
# Set this environment variable before running spicetify apply
# Windows (PowerShell):
$env:SPICETIFY_DISABLE_BUNDLE = "1"
spicetify apply

# macOS / Linux:
SPICETIFY_DISABLE_BUNDLE=1 spicetify apply
```

Individual extensions can be removed from your config normally:

```bash
spicetify config extensions adblock.js-
```

---

## Updating

### Update the All-In-One Fork

When a new version of this fork is released:

```powershell
# Windows
.\update.ps1

# macOS / Linux
./update.sh
```

The update script will pull the latest upstream `spicetify/cli`, re-apply the all-in-one
modifications, rebuild the Marketplace and extensions, and recompile the binary.

### Re-apply After a Spotify Update

Spotify updates overwrite the customization. Just re-run:

```bash
spicetify backup apply
```

---

## Building From Source

See [`build-allinone.ps1`](./build-allinone.ps1) (Windows) or [`build-allinone.sh`](./build-allinone.sh)
for the unified build pipeline. Requirements: Go 1.24+, Node.js 20+, and pnpm 10+.

```powershell
# Windows
.\build-allinone.ps1

# macOS / Linux
./build-allinone.sh
```

---

### Links

- [Upstream Spicetify CLI](https://github.com/spicetify/cli)
- [Marketplace Repository](https://github.com/spicetify/marketplace)
- [rxri Extensions Repository](https://github.com/rxri/spicetify-extensions)
- [Basic Usage](https://spicetify.app/docs/getting-started#basic-usage)

### Code Signing Policy

Free code signing provided by [SignPath.io](https://signpath.io), certificate by [SignPath Foundation](https://signpath.org).
