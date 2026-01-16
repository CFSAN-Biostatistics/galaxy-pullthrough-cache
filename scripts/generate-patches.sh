#!/bin/bash
set -e

# Configuration
INSTALL_DIR="${1:-/path/to/your-install}"
UPSTREAM_REPO="https://github.com/org/project.git"
UPSTREAM_TAG="${2:-v1.2.3}"
PATCHES_OUTPUT="$(dirname "$0")/../galaxy-pullthrough-cache/patches"
TEMP_DIR=$(mktemp -d -t project-patches-XXXXXX)
PREVDIR=$(pwd)

# Files/dirs to exclude from comparison
EXCLUSIONS=(
    ':(exclude)*.log'
    ':(exclude)*.pyc'
    ':(exclude)*.pyo'
    ':(exclude)__pycache__/'
    ':(exclude).env*'
    ':(exclude)*.tmp'
    ':(exclude)local_config.py'
    ':(exclude)docs/*.local.*'
    ':(exclude)node_modules/'  # if present
    ':(exclude).DS_Store'
)

echo "=== Extracting patches from installation ==="
echo "Install dir: $INSTALL_DIR"
echo "Upstream: $UPSTREAM_REPO"
echo "Base tag: $UPSTREAM_TAG"
echo "Output: $PATCHES_OUTPUT"
echo ""

# Cleanup function
cleanup() {
    echo "Cleaning up temp directory..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Clone upstream
echo "Cloning upstream repository..."
git clone --quiet "$UPSTREAM_REPO" "$TEMP_DIR"
cd "$TEMP_DIR"

# Checkout base version
echo "Checking out $UPSTREAM_TAG..."
git checkout --quiet "$UPSTREAM_TAG"
git checkout -b our-changes

# Copy modified files
echo "Copying modified files..."
rsync -a --exclude='.git' "$INSTALL_DIR/" "$TEMP_DIR/"

# Show what changed
echo ""
echo "=== Changes detected ==="
git status --short

# Stage changes with exclusions
echo ""
echo "Staging changes (excluding patterns)..."
git add -A -- . "${EXCLUSIONS[@]}"

# Show what will be committed
echo ""
echo "=== Files to be included in patch ==="
git diff --cached --name-only

echo ""
read -p "Continue with patch generation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Commit
git commit -m "Production modifications from install

Extracted from: $INSTALL_DIR
Based on upstream: $UPSTREAM_TAG
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"

# Generate patches
echo ""
echo "Generating patches..."
mkdir -p "$PATCHES_OUTPUT"
rm -f "$PATCHES_OUTPUT"/*.patch
git format-patch "$UPSTREAM_TAG"..our-changes -o "$PATCHES_OUTPUT"
cd "$PATCHES_OUTPUT"/..
git tag -af "$UPSTREAM_TAG" -m "patches generated $(date -u +"%Y%m%d%H%M%S")"
cd "$PREVDIR"

# Summary
echo ""
echo "=== Patch generation complete ==="
echo "Patches created:"
ls -1 "$PATCHES_OUTPUT"/*.patch

echo ""
echo "To apply these patches:"
echo "  cd /path/to/fresh-install"
echo "  git am $PATCHES_OUTPUT/*.patch"