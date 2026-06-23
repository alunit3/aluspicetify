#!/usr/bin/env bash
# ============================================================
#  All-In-One Spicetify Installer (macOS / Linux)
#  Marketplace + rxri extensions pre-bundled
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/alunit3/aluspicetify/main/install-alus.sh | bash
# ============================================================
set -euo pipefail

REPO_API="https://api.github.com/repos/alunit3/aluspicetify/releases/latest"
INSTALL_DIR="${SPICETIFY_INSTALL:-$HOME/.spicetify}"

step() { printf "\n\033[36m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32mOK  %s\033[0m\n" "$1"; }
err()  { printf "    \033[31mERR %s\033[0m\n" "$1"; exit 1; }

printf "\n  \033[1mAll-In-One Spicetify Installer\033[0m\n"
printf "  \033[90mMarketplace + rxri extensions pre-bundled\033[0m\n\n"

# --- Root check -------------------------------------------------------------
if [ "$(id -u)" -eq 0 ] && [ -z "${1:-}" ]; then
    printf "    \033[33mWARN: Running as root is not recommended.\033[0m\n"
    printf "    Spicetify should run as a normal user.\033[0m\n"
    read -r -p "    Continue anyway? (y/N) " choice < /dev/tty
    case "$choice" in
        y|Y) ;;
        *) exit 0 ;;
    esac
fi

# --- Dependency check -------------------------------------------------------
step "Checking dependencies"
for cmd in curl tar; do
    command -v "$cmd" >/dev/null || err "$cmd is not installed"
done
ok "curl and tar available"

# --- Detect platform --------------------------------------------------------
case $(uname -sm) in
    "Darwin x86_64")  TARGET="darwin-amd64" ;;
    "Darwin arm64")   TARGET="darwin-arm64" ;;
    "Linux x86_64")   TARGET="linux-amd64" ;;
    "Linux aarch64")  TARGET="linux-arm64" ;;
    *) err "Unsupported platform: $(uname -sm)" ;;
esac
ok "platform: $TARGET"

# --- Fetch latest release ---------------------------------------------------
step "Fetching latest release"
tag=$(curl -fsSL "$REPO_API" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"//;s/"//')
[ -n "$tag" ] || err "could not determine latest release tag"
tag_num="${tag#v}"
ok "latest: $tag"

download_uri="https://github.com/alunit3/aluspicetify/releases/download/${tag}/spicetify-${tag_num}-${TARGET}.tar.gz"

# --- Download ---------------------------------------------------------------
step "Downloading"
tar_file="$INSTALL_DIR/spicetify.tar.gz"
mkdir -p "$INSTALL_DIR"
curl --fail --location --progress-bar --output "$tar_file" "$download_uri"
ok "downloaded"

# --- Extract ----------------------------------------------------------------
step "Extracting to $INSTALL_DIR"
tar xzf "$tar_file" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/spicetify"
rm -f "$tar_file"
ok "extracted"

# --- Verify bundled assets --------------------------------------------------
step "Verifying installation"
[ -f "$INSTALL_DIR/spicetify" ] || err "spicetify binary not found"
ver=$("$INSTALL_DIR/spicetify" --version 2>&1)
ok "installed: $ver"

if [ -f "$INSTALL_DIR/CustomApps/marketplace/index.js" ]; then
    ok "Marketplace bundled"
else
    printf "    \033[33mWARN: Marketplace not found\033[0m\n"
fi
if [ -f "$INSTALL_DIR/Extensions/adblock.js" ]; then
    ok "adblockify bundled"
else
    printf "    \033[33mWARN: adblock.js not found\033[0m\n"
fi

# --- Add to PATH ------------------------------------------------------------
step "Adding to PATH"
endswith_newline() {
    [ "$(od -An -c "$1" | tail -1 | grep -o '.$')" = "\n" ]
}

add_to_path() {
    local rc="$1" path_line="$2"
    if [ ! -f "$rc" ]; then touch "$rc"; fi
    if ! grep -q "$INSTALL_DIR" "$rc"; then
        if ! endswith_newline "$rc"; then echo >> "$rc"; fi
        echo "$path_line" >> "$rc"
        ok "added to $rc"
    else
        ok "already in $rc"
    fi
}

path_export="export PATH=\"\$PATH:$INSTALL_DIR\""
case "$SHELL" in
    *zsh)  add_to_path "${ZDOTDIR:-$HOME}/.zshrc" "$path_export" ;;
    *bash)
        [ -f "$HOME/.bashrc" ] && add_to_path "$HOME/.bashrc" "$path_export"
        [ -f "$HOME/.bash_profile" ] && add_to_path "$HOME/.bash_profile" "$path_export"
        ;;
    *fish) add_to_path "$HOME/.config/fish/config.fish" "fish_add_path $INSTALL_DIR" ;;
    *) printf "    \033[33mAdd to PATH manually: %s\033[0m\n" "$path_export" ;;
esac
export PATH="$PATH:$INSTALL_DIR"

# --- Apply ------------------------------------------------------------------
step "Applying to Spotify"
printf "    Running: spicetify backup apply\033[0m\n"
printf "    \033[90m(Make sure Spotify is installed and launched at least once)\033[0m\n\n"

if spicetify backup apply; then
    printf "\n  \033[32mInstallation complete!\033[0m\n"
    printf "  \033[32mRestart Spotify to see the Marketplace and extensions.\033[0m\n"
else
    printf "\n  \033[33mSpicetify installed, but apply failed.\033[0m\n"
    printf "  \033[33mMake sure Spotify is installed, then run:\033[0m\n"
    printf "    \033[37mspicetify backup apply\033[0m\n"
fi

printf "\n  \033[90mOpen a NEW terminal to use 'spicetify' command.\033[0m\n"
