#!/usr/bin/env bash
# One-command update for the all-in-one Spicetify fork.
#
# Re-syncs your fork with the latest upstream spicetify/cli, then
# regenerates all bundled assets (Marketplace + rxri extensions)
# and recompiles the binary.
#
#   1. Saves your Go/manifest source modifications as a patch.
#   2. Resets tracked files to upstream state (new files untouched).
#   3. Pulls the latest spicetify/cli.
#   4. Re-applies your source patch (3-way merge on conflict).
#   5. Rebuilds Marketplace + extensions via build-allinone.
#   6. Runs go vet + tests to verify.
#
# Usage:  ./update.sh
#         ./update.sh --skip-asset-build
#         ./update.sh --upstream origin --branch main
set -euo pipefail

UPSTREAM="origin"
BRANCH="main"
SKIP_ASSET_BUILD=0
NO_VERIFY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-asset-build) SKIP_ASSET_BUILD=1; shift ;;
        --no-verify)        NO_VERIFY=1; shift ;;
        --upstream)         UPSTREAM="$2"; shift 2 ;;
        --branch)           BRANCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$REPO_ROOT/alus-source.patch"

# Tracked upstream files we modify (new untracked files like bundle.go
# are NOT listed here — they survive git checkout/pull automatically).
SOURCE_FILES=(
    "src/utils/config.go"
    "src/cmd/apply.go"
    "src/cmd/watch.go"
    "manifest.json"
)

step() { printf "\n\033[36m==> %s\033[0m\n" "$1"; }
ok()   { printf "    \033[32mOK  %s\033[0m\n" "$1"; }
warn() { printf "    \033[33mWARN %s\033[0m\n" "$1"; }
err()  { printf "    \033[31mERR %s\033[0m\n" "$1"; exit 1; }

cd "$REPO_ROOT"

# --- 1. Save current source modifications -----------------------------------
step "Saving source modifications"
DIRTY=0
for f in "${SOURCE_FILES[@]}"; do
    if [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]; then
        DIRTY=1; break
    fi
done

if [ "$DIRTY" -eq 1 ]; then
    # Diff against HEAD so staged + unstaged changes are both captured.
    git diff HEAD -- "${SOURCE_FILES[@]}" > "$PATCH_FILE" 2>/dev/null
    SIZE=$(wc -c < "$PATCH_FILE" | tr -d ' ')
    if [ "$SIZE" -gt 0 ]; then
        ok "patch saved ($SIZE bytes): $PATCH_FILE"
    else
        warn "source files modified but patch is empty — check git status"
    fi
elif [ -f "$PATCH_FILE" ]; then
    SIZE=$(wc -c < "$PATCH_FILE" | tr -d ' ')
    ok "no uncommitted source changes; reusing existing patch ($SIZE bytes)"
else
    err "no source changes to save and no existing patch at $PATCH_FILE"
fi

# --- 2. Reset tracked files to upstream -------------------------------------
step "Resetting tracked files to upstream"
git reset HEAD -- . 2>/dev/null
git checkout -- . 2>/dev/null
ok "tracked files reset"

# --- 3. Pull latest upstream ------------------------------------------------
step "Fetching latest upstream ($UPSTREAM/$BRANCH)"
git fetch "$UPSTREAM" "$BRANCH" || err "git fetch failed"

step "Merging $UPSTREAM/$BRANCH"
if ! git merge "$UPSTREAM/$BRANCH" 2>&1; then
    warn "merge produced conflicts — resolve them, then re-run with --skip-asset-build"
    exit 1
fi
LATEST=$(git log --oneline -1 2>/dev/null)
ok "now at: $LATEST"

# --- 4. Re-apply source modifications ---------------------------------------
step "Re-applying source modifications"
if [ ! -f "$PATCH_FILE" ]; then
    warn "no patch file found — skipping (source mods not applied)"
else
    if git apply --3way "$PATCH_FILE" 2>/dev/null; then
        ok "source modifications re-applied"
    else
        warn "patch did not apply cleanly. Conflicts to resolve:"
        git status --short 2>/dev/null | while read -r line; do
            printf "      \033[33m%s\033[0m\n" "$line"
        done
        printf "\n    Resolve the conflicts in the files above, then:\n"
        printf "      \033[37m./update.sh --skip-asset-build\033[0m\n"
        exit 1
    fi
fi

# --- 5. Rebuild assets + binary ---------------------------------------------
if [ "$SKIP_ASSET_BUILD" -eq 0 ]; then
    BUILD_SCRIPT="$REPO_ROOT/build-allinone.sh"
    if [ -f "$BUILD_SCRIPT" ]; then
        step "Rebuilding assets and binary"
        bash "$BUILD_SCRIPT" || err "build-allinone failed"
    else
        warn "build-allinone.sh not found — skipping asset rebuild"
        warn "run it manually to regenerate Marketplace + extensions"
    fi
fi

# --- 6. Verify --------------------------------------------------------------
if [ "$NO_VERIFY" -eq 0 ]; then
    step "Verifying"
    go vet ./... || err "go vet failed"
    go test ./src/apply/ || err "tests failed"
    ok "verification passed"
fi

step "Update complete"
printf "    \033[32mRun: spicetify backup apply\033[0m\n"
