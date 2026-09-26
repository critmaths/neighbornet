#!/usr/bin/env bash
set -e

REPO_URL="${1:-https://github.com/critmaths/neighbornet.wiki.git}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$ROOT_DIR/docs"
TEMP_WIKI_DIR="$ROOT_DIR/.tmp_wiki_clone"

echo "Syncing NeighborNet docs to GitHub Wiki ($REPO_URL)..."

rm -rf "$TEMP_WIKI_DIR"

git clone "$REPO_URL" "$TEMP_WIKI_DIR"
cp "$DOCS_DIR"/*.md "$TEMP_WIKI_DIR/"

cd "$TEMP_WIKI_DIR"
git config user.name "NeighborNet Wiki Sync"
git config user.email "critmaths@gmail.com"
git add .

if [ -n "$(git status --porcelain)" ]; then
    git commit -m "docs: sync wiki documentation from master docs/ folder"
    git push origin master
    echo "GitHub Wiki successfully updated and pushed!"
else
    echo "GitHub Wiki is already up-to-date."
fi

cd "$ROOT_DIR"
rm -rf "$TEMP_WIKI_DIR"
