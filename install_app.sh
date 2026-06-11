#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./install_app.sh apps/gitea dev
#   ./install_app.sh apps/app-of-apps dev argocd

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 <chart_dir> [env] [namespace]"
  echo "Example: $0 apps/gitea dev"
  echo "Example: $0 apps/app-of-apps dev argocd"
  exit 1
fi

CHART_DIR="${1%/}"
ENV="${2:-dev}"

RELEASE="$(basename "$CHART_DIR")"
NAMESPACE="${3:-$RELEASE}"

BASE_VALUES="$CHART_DIR/values.yaml"
ENV_VALUES="$CHART_DIR/values-$ENV.yaml"

if [ ! -f "$BASE_VALUES" ]; then
  echo "Error: $BASE_VALUES not found" >&2
  exit 1
fi

CMD=(helm upgrade --install "$RELEASE" "$CHART_DIR"
  --namespace "$NAMESPACE" --create-namespace
  --dependency-update
  -f "$BASE_VALUES")

if [ -f "$ENV_VALUES" ]; then
  CMD+=(-f "$ENV_VALUES")
else
  echo "Note: $ENV_VALUES not found; proceeding without it." >&2
fi

exec "${CMD[@]}"
