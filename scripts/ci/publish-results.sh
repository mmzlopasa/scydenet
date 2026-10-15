#!/usr/bin/env bash
# Force-push the contents of ci-out/ to an orphan branch so results can be fetched with plain git.
set -euo pipefail
cd ci-out
rm -rf .git
git init -q
git checkout -q -b ci-results
git add -A
git -c user.name=ci -c user.email=ci@users.noreply.github.com commit -qm "CI results for ${GITHUB_SHA}" || true
git push -f -q "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}" ci-results
