#!/usr/bin/env bash
set -euo pipefail

# This script mints a Gitea Personal Access Token (PAT) using admin credentials
# stored in a Kubernetes Secret, then stores it as the RENOVATE_TOKEN in the
# renovate-gitea-token Secret used by the Renovate Helm chart.

# Configurable settings (override via environment variables if needed)
GITEA_ENDPOINT="${GITEA_ENDPOINT:-http://localhost:3000}"
GITEA_NS="${GITEA_NS:-gitea}"
ADMIN_SECRET="${ADMIN_SECRET:-gitea-admin}"     # Secret containing admin creds
ADMIN_USER_KEY="${ADMIN_USER_KEY:-admin-username}"    # Key for admin username in secret
ADMIN_PASS_KEY="${ADMIN_PASS_KEY:-admin-password}"    # Key for admin password in secret
TARGET_USER="${TARGET_USER:-admin}"                   # User to create the PAT for
TOKEN_NAME="${TOKEN_NAME:-renovate}"            # Desired token name (will add suffix on conflict)
RENOVATE_NS="${RENOVATE_NS:-renovate}"
SECRET_NAME="${SECRET_NAME:-renovate-gitea-token}"
# Gitea token scopes (JSON array). Default to full access for Renovate.
SCOPES_JSON="${SCOPES_JSON:-[\"all\"]}"

# Requirements
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found in PATH" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl not found in PATH" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found in PATH" >&2; exit 1; }

# Fetch admin credentials from Kubernetes
ADMIN_USER="$(kubectl -n "$GITEA_NS" get secret "$ADMIN_SECRET" -o jsonpath="{.data.$ADMIN_USER_KEY}" | base64 -d 2>/dev/null || true)"
ADMIN_PASS="$(kubectl -n "$GITEA_NS" get secret "$ADMIN_SECRET" -o jsonpath="{.data.$ADMIN_PASS_KEY}" | base64 -d 2>/dev/null || true)"

if [[ -z "${ADMIN_USER}" || -z "${ADMIN_PASS}" ]]; then
  echo "Failed to read admin credentials from secret ${GITEA_NS}/${ADMIN_SECRET} (keys: ${ADMIN_USER_KEY}, ${ADMIN_PASS_KEY})" >&2
  exit 1
fi

# Function to request a token via Gitea admin API, returning "body\n<status>"
create_token() {
  local name="$1"
  curl -sS -u "${ADMIN_USER}:${ADMIN_PASS}" \
    -H 'Content-Type: application/json' \
    -X POST "${GITEA_ENDPOINT}/api/v1/users/${TARGET_USER}/tokens" \
    -d "{\"name\":\"${name}\",\"scopes\":${SCOPES_JSON}}" \
    -w '\n%{http_code}'
}

# Helper: attempt to create a token, print sha to stdout on success
attempt_create() {
  local name="$1"
  local resp http_code body sha
  resp="$(create_token "${name}")" || true
  http_code="$(printf '%s\n' "${resp}" | tail -n1)"
  body="$(printf '%s\n' "${resp}" | sed '$d')"

  if [[ "${http_code}" == "200" || "${http_code}" == "201" ]]; then
    sha="$(printf '%s' "${body}" | jq -r '.sha1 // empty' 2>/dev/null || true)"
    if [[ -n "${sha}" ]]; then
      echo "${sha}"
      return 0
    fi
    echo "Unexpected success response without sha1: ${body}" >&2
    return 1
  elif [[ "${http_code}" == "409" ]]; then
    # Name conflict: tell caller to retry with a unique name
    return 2
  else
    echo "Gitea API error creating token '${name}' (HTTP ${http_code}): ${body}" >&2
    return 1
  fi
}

SHA="$(attempt_create "${TOKEN_NAME}")" || rc=$?
rc="${rc:-0}"

if [[ "${rc}" == "2" || -z "${SHA}" ]]; then
  UNIQUE_NAME="${TOKEN_NAME}-$(date +%s)"
  SHA="$(attempt_create "${UNIQUE_NAME}")" || true
fi

if [[ -z "${SHA}" ]]; then
  echo "Failed to create PAT for user '${TARGET_USER}'. See errors above." >&2
  exit 1
fi

# Create/Update the Kubernetes secret used by the Renovate chart
kubectl create namespace "${RENOVATE_NS}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${RENOVATE_NS}" \
  --from-literal=RENOVATE_TOKEN="${SHA}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Created/updated secret ${RENOVATE_NS}/${SECRET_NAME} with RENOVATE_TOKEN for user '${TARGET_USER}'."
