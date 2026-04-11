#!/usr/bin/env bash

GITEA_PASS="$(kubectl -n gitea get secret gitea-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
GITEA_USER="$(kubectl -n gitea get secret gitea-admin -o jsonpath='{.data.admin-username}' | base64 -d)"
# GITEA_PASS_ENCODED=$(curl -Gso /dev/null -w "%{url_effective}" --data-urlencode "=${GITEA_PASS}" "" | cut -c3-)
# git remote set-url gitea http://${GITEA_USER}:${GITEA_PASS_ENCODED}@localhost:3000/admin/app-of-apps.git
# git remote add gitea http://${GITEA_USER}:${GITEA_PASS_ENCODED}@localhost:3000/${GITEA_USER}/app-of-apps.git
# git remote set-url gitea "http://${GITEA_USER}:${GITEA_PASS}@localhost:3000/admin/app-of-apps.git"
GITEA_PASS_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" <<<"${GITEA_PASS}")
git remote add gitappofapps http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/${GIT_USER}/app-of-apps.git
git remote set-url gitappofapps http://${GITEA_USER}:${GITEA_PASS_ENCODED}@localhost:3000/${GITEA_USER}/app-of-apps.git
git push gitappofapps main:main --force
