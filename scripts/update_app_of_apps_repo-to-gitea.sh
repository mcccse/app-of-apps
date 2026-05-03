#!/usr/bin/env bash

GIT_APP="gitea"

GIT_PASS="$(kubectl -n ${GIT_APP} get secret ${GIT_APP}-admin -o jsonpath='{.data.password}' | base64 -d)"
GIT_USER="$(kubectl -n ${GIT_APP} get secret ${GIT_APP}-admin -o jsonpath='{.data.username}' | base64 -d)"
GIT_PASS_ENCODED=$(curl -Gso /dev/null -w "%{url_effective}" --data-urlencode "=${GIT_PASS}" "" | cut -c3-)
GIT_PASS_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe=''))" <<<"${GIT_PASS}")

# git remote set-url gitea http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/admin/app-of-apps.git
# git remote add gitea http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/${GIT_USER}/app-of-apps.git
# git remote set-url gitea "http://${GIT_USER}:${GIT_PASS}@localhost:3000/admin/app-of-apps.git"

git remote add gitappofapps http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/${GIT_USER}/app-of-apps.git
git remote set-url gitappofapps http://${GIT_USER}:${GIT_PASS_ENCODED}@localhost:3000/${GIT_USER}/app-of-apps.git
git push gitappofapps main:main
