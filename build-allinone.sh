#!/usr/bin/env bash
# Unified all-in-one build pipeline for the Spicetify CLI fork.
#
# 1. Fetches/updates the Marketplace and rxri/spicetify-extensions
#    source repositories into a temporary working directory.
# 2. Builds the Marketplace TypeScript/SCSS frontend (pnpm).
# 3. Syncs the compiled Marketplace CustomApp into CustomApps/marketplace
#    and copies the rxri extensions into the native Extensions/ directory.
# 4. Compiles the customized Go CLI binary with bundled assets resolved
#    natively at runtime.
#
# Usage: ./build-allinone.sh [version] [output-name]
set -euo pipefail

VERSION="${1:-v2.39.9-allinone}"
OUTPUT_NAME="${2:-spicetify-allinone}"
MARKETPLACE_REPO="https://github.com/spicetify/marketplace.git"
EXTENSIONS_REPO="https://github.com/rxri/spicetify-extensions.git"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-${TMPDIR:-/tmp}/alus-build}"
MP_DIR="$WORK_DIR/marketplace"
EXT_DIR="$WORK_DIR/spicetify-extensions"

step() { printf "\n\033[36m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32mOK  %s\033[0m\n" "$1"; }
err()  { printf "    \033[31mERR %s\033[0m\n" "$1"; exit 1; }

# rxri extension source files -> native Extensions/ destination filenames.
declare -A EXTENSION_MAP=(
    ["adblock/adblock.js"]="adblock.js"
    ["phraseToPlaylist/phraseToPlaylist.js"]="phraseToPlaylist.js"
    ["songstats/songstats.js"]="songstats.js"
    ["wikify/wikify.js"]="wikify.js"
    ["writeify/writeify.js"]="writeify.js"
    ["formatColors/formatColors.js"]="formatColors.js"
    ["featureshuffle/featureshuffle.js"]="featureshuffle.js"
    ["old-sidebar/oldSidebar.js"]="oldSidebar.js"
)

SKIP_FETCH="${SKIP_FETCH:-0}"
SKIP_ASSETS="${SKIP_BUILD_ASSETS:-0}"

# --- 0. Pre-flight -----------------------------------------------------------
step "Checking toolchain"
command -v go   >/dev/null || err "go not found on PATH"
command -v node >/dev/null || err "node not found on PATH"
if ! command -v pnpm >/dev/null; then
    printf "    \033[33mpnpm not found; installing via npm...\033[0m\n"
    npm install -g pnpm@10 --no-audit --no-fund --loglevel=error
fi
ok "go=$(go version | awk '{print $3}'), node=$(node --version), pnpm=$(pnpm --version)"

# --- 1. Fetch / update source repositories -----------------------------------
if [ "$SKIP_FETCH" != "1" ]; then
    step "Fetching source repositories"
    mkdir -p "$WORK_DIR"
    sync_repo() {
        local url="$1" dest="$2"
        if [ -d "$dest/.git" ]; then
            printf "    updating %s\n" "$dest"
            git -C "$dest" pull --ff-only --depth 1 >/dev/null 2>&1 || true
        else
            rm -rf "$dest"
            git clone --depth 1 "$url" "$dest" || err "failed to clone $url"
        fi
    }
    sync_repo "$MARKETPLACE_REPO" "$MP_DIR"
    sync_repo "$EXTENSIONS_REPO"  "$EXT_DIR"
    ok "repositories ready"
fi

# --- 2 + 3. Build marketplace and sync assets --------------------------------
if [ "$SKIP_ASSETS" != "1" ]; then
    step "Building Marketplace frontend"
    ( cd "$MP_DIR" && pnpm install --config.strict-peer-dependencies=false && pnpm run build:prod ) || err "marketplace build failed"
    [ -f "$MP_DIR/dist/index.js" ] || err "marketplace dist/index.js missing"
    ok "marketplace built"

    step "Syncing Marketplace into CustomApps/marketplace"
    MP_DEST="$REPO_ROOT/CustomApps/marketplace"
    rm -rf "$MP_DEST"; mkdir -p "$MP_DEST"
    cp -R "$MP_DIR/dist/." "$MP_DEST/"
    ok "CustomApps/marketplace updated ($(ls -1 "$MP_DEST" | wc -l | tr -d ' ') files)"

    step "Syncing rxri extensions into Extensions/"
    mkdir -p "$REPO_ROOT/Extensions"
    for src_rel in "${!EXTENSION_MAP[@]}"; do
        src="$EXT_DIR/$src_rel"
        dst="$REPO_ROOT/Extensions/${EXTENSION_MAP[$src_rel]}"
        [ -f "$src" ] || err "missing extension source: $src"
        cp -f "$src" "$dst"
    done
    ok "Extensions/ updated with ${#EXTENSION_MAP[@]} rxri extensions"
fi

# --- 4. Compile the customized Go CLI binary ---------------------------------
step "Compiling CLI binary"
OUT="$REPO_ROOT/$OUTPUT_NAME"
go build -ldflags "-X main.version=$VERSION" -o "$OUT" . || err "go build failed"
ok "binary: $OUT ($(wc -c < "$OUT" | tr -d ' ') bytes)"

step "All-in-one build complete"
printf "    \033[32mVersion: %s\033[0m\n" "$VERSION"
printf "    \033[32mBinary:  %s\033[0m\n" "$OUT"
printf "    \033[32mAssets:  CustomApps/marketplace, Extensions/*.js\033[0m\n"
printf "    \033[90mPackage these alongside Themes/ and jsHelper/ for distribution.\033[0m\n"
