#!/usr/bin/env bash

BRANCH="$(git rev-parse --abbrev-ref HEAD)" # get current branch

# Get secrets from cluster
GITEA_PASS="$(kubectl -n gitea get secret gitea-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
GITEA_USER="$(kubectl -n gitea get secret gitea-admin -o jsonpath='{.data.admin-username}' | base64 -d)"

# Make passwd http safe
GITEA_PASS_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" <<<"${GITEA_PASS}")

# Yes, here it is http with passwd in url, this example use localhost / port-forward.
git remote add gitappofapps http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/${GIT_USER}/app-of-apps.git
git remote set-url gitappofapps http://${GITEA_USER}:${GITEA_PASS_ENCODED}@localhost:3000/${GITEA_USER}/app-of-apps.git
git push gitappofapps ${BRANCH}:main --force
