#!/usr/bin/env bash
set -Eeuo pipefail

# Apply DEP customizations from https://github.com/amrhym/dep onto a fresh chatwoot clone.
# By default, this will:
# - Ensure remotes 'origin' (chatwoot) and 'dep' (your fork) are present
# - Fetch both remotes
# - Create a new branch from BASE_REF (origin/develop by default)
# - Generate a binary-capable patch from BASE_REF..DEP_REF
# - Apply it with a 3-way merge (safer against upstream drift)
# - Commit the applied changes
#
# Usage:
#   ./scripts/apply_dep_customizations.sh
#
# Optional overrides (env or --flag=value):
#   --base-ref=REF           Base to apply onto (default: origin/develop)
#   --dep-remote-name=NAME   Name of dep remote (default: dep)
#   --dep-url=URL            URL of dep remote (default: https://github.com/amrhym/dep.git)
#   --dep-ref=REF            Source ref for customizations (default: dep/develop)
#   --target-branch=NAME     Branch to create/switch to (default: dep/customized-<timestamp>)
#   --dry-run=true|false     Only check if patch applies, do not modify the tree (default: false)
#   --keep-patch=true|false  Keep generated patch file under patches/ (default: false)
#
# Examples:
#   BASE_REF=origin/develop ./scripts/apply_dep_customizations.sh
#   ./scripts/apply_dep_customizations.sh --dry-run=true
#   ./scripts/apply_dep_customizations.sh --target-branch=dep/customized
#
# Requirements:
#   - git available
#   - run inside a git work tree of chatwoot

log()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; exit 1; }

# Defaults
BASE_REF="${BASE_REF:-origin/develop}"
DEP_REMOTE_NAME="${DEP_REMOTE_NAME:-dep}"
DEP_REMOTE_URL="${DEP_REMOTE_URL:-https://github.com/amrhym/dep.git}"
DEP_REF="${DEP_REF:-${DEP_REMOTE_NAME}/develop}"
TARGET_BRANCH="${TARGET_BRANCH:-dep/customized-$(date +%Y%m%d%H%M%S)}"
DRY_RUN_RAW="${DRY_RUN:-false}"
KEEP_PATCH_RAW="${KEEP_PATCH:-false}"

# Parse --flag=value args
for arg in "$@"; do
  case "$arg" in
    --base-ref=*)        BASE_REF="${arg#*=}" ;;
    --dep-remote-name=*) DEP_REMOTE_NAME="${arg#*=}" ;;
    --dep-url=*)         DEP_REMOTE_URL="${arg#*=}" ;;
    --dep-ref=*)         DEP_REF="${arg#*=}" ;;
    --target-branch=*)   TARGET_BRANCH="${arg#*=}" ;;
    --dry-run=*)         DRY_RUN_RAW="${arg#*=}" ;;
    --keep-patch=*)      KEEP_PATCH_RAW="${arg#*=}" ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

# Normalize booleans
shopt -s nocasematch || true
case "$DRY_RUN_RAW" in
  true|1|yes|on) DRY_RUN=true ;;
  false|0|no|off) DRY_RUN=false ;;
  *) die "Invalid value for --dry-run: $DRY_RUN_RAW" ;;
esac
case "$KEEP_PATCH_RAW" in
  true|1|yes|on) KEEP_PATCH=true ;;
  false|0|no|off) KEEP_PATCH=false ;;
  *) die "Invalid value for --keep-patch: $KEEP_PATCH_RAW" ;;
esac
shopt -u nocasematch || true

# Preconditions
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "Not inside a git work tree. Run this inside a chatwoot clone."
fi

# Basic sanity that this looks like chatwoot (best-effort, non-fatal)
if [ ! -f Gemfile ] || [ ! -d app ] || [ ! -d config ]; then
  warn "This directory doesn't resemble a chatwoot repo (missing Gemfile/app/config). Proceeding anyway."
fi

# Ensure remotes
if ! git remote get-url origin >/dev/null 2>&1; then
  die "Missing 'origin' remote. Please add the chatwoot upstream as 'origin' and rerun."
fi
if ! git remote get-url "$DEP_REMOTE_NAME" >/dev/null 2>&1; then
  log "Adding remote '$DEP_REMOTE_NAME' -> $DEP_REMOTE_URL"
  git remote add "$DEP_REMOTE_NAME" "$DEP_REMOTE_URL"
else
  url_now=$(git remote get-url "$DEP_REMOTE_NAME")
  if [ "$url_now" != "$DEP_REMOTE_URL" ]; then
    warn "Remote '$DEP_REMOTE_NAME' points to $url_now (expected $DEP_REMOTE_URL). Using existing URL."
  fi
fi

log "Fetching latest from origin and $DEP_REMOTE_NAME ..."
git fetch --prune origin --tags
git fetch --prune "$DEP_REMOTE_NAME" --tags

# Verify refs exist
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  die "Base ref '$BASE_REF' not found."
fi
if ! git rev-parse --verify "$DEP_REF" >/dev/null 2>&1; then
  die "Dep ref '$DEP_REF' not found."
fi

# Create/switch to target branch
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  log "Switching to existing branch: $TARGET_BRANCH"
  git switch "$TARGET_BRANCH"
else
  log "Creating and switching to branch: $TARGET_BRANCH (base: $BASE_REF)"
  git switch -c "$TARGET_BRANCH" "$BASE_REF"
fi

# Generate patch (binary-capable)
patch_dir="patches"
mkdir -p "$patch_dir"
patch_file_tmp=$(mktemp "${patch_dir}/dep-customizations.XXXXXX.patch")
log "Generating patch: $BASE_REF..$DEP_REF -> $patch_file_tmp"
# Use --binary to include binary changes if any; --no-color for cleanliness
GIT_PAGER= git --no-pager diff --binary "$BASE_REF..$DEP_REF" >"$patch_file_tmp"

if [ ! -s "$patch_file_tmp" ]; then
  log "No differences found between $BASE_REF and $DEP_REF. Nothing to apply."
  if [ "$KEEP_PATCH" = false ]; then rm -f "$patch_file_tmp"; fi
  exit 0
fi

# Optionally keep a dated copy; else cleanup after success
if [ "$KEEP_PATCH" = true ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  kept_file="${patch_dir}/dep-customizations-${stamp}.patch"
  mv "$patch_file_tmp" "$kept_file"
  patch_file="$kept_file"
  log "Saved patch to: $patch_file"
else
  patch_file="$patch_file_tmp"
fi

# Check/apply patch
if [ "$DRY_RUN" = true ]; then
  log "Dry run: verifying patch applicability via 3-way check"
  if git apply -3 --check "$patch_file"; then
    log "Patch can be applied cleanly."
    log "Run again without --dry-run to apply."
    exit 0
  else
    die "Patch cannot be applied cleanly to current base ($BASE_REF). Rebase or update and retry."
  fi
else
  log "Applying patch (3-way merge, index update) ..."
  if git apply -3 --index "$patch_file"; then
    log "Patch applied successfully. Committing changes ..."
    git commit -m "Apply DEP customizations from $DEP_REF onto $BASE_REF"
    log "Summary of changes:"
    git --no-pager diff --stat HEAD~1..HEAD || true
    log "Done. Current branch: $TARGET_BRANCH"
  else
    warn "3-way apply failed. Attempting --reject mode to write .rej hunks ..."
    if git apply --reject "$patch_file"; then
      warn "Conflicts were produced (.rej files). Please resolve manually, then stage and commit."
      exit 2
    else
      die "Failed to apply patch."
    fi
  fi
fi

# Cleanup temp patch if not keeping
if [ "$KEEP_PATCH" = false ] && [ -f "$patch_file_tmp" ]; then
  rm -f "$patch_file_tmp"
fi
