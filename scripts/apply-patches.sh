#!/bin/bash
set -e

UPSTREAM_REPO=$1
PATCHES_DIR="$(dirname "$0")/../galaxy-pullthrough-cache/patches"

if [ -z "$UPSTREAM_REPO" ]; then
    echo "Usage: $0 <path-to-upstream-repo>"
    exit 1
fi

cd "$UPSTREAM_REPO"
git am "$PATCHES_DIR"/*.patch
echo "Patches applied successfully"