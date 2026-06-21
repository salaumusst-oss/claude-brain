#!/bin/bash
# Claude Brain Sync — run this to push/pull shared memory
BRAIN_DIR="$(cd "$(dirname "$0")" && pwd)"
MESSAGE="${1:-sync}"

cd "$BRAIN_DIR"

git pull --rebase origin main

if [[ -n $(git status --porcelain) ]]; then
    git add -A
    git commit -m "$MESSAGE $(date '+%Y-%m-%d %H:%M')"
    git push origin main
    echo "Brain synced."
else
    echo "Brain up to date."
fi
