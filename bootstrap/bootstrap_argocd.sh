#!/usr/bin/env bash
set -euo pipefail

# ── Konfiguration ────────────────────────────────────────────
ARGOCD_VERSION="${ARGOCD_VERSION:-7.7.0}"          # Helm chart-version
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
GITEA_NAMESPACE="${GITEA_NAMESPACE:-gitea}"
GITEA_SECRET="${GITEA_SECRET:-gitea-admin}"
GITEA_SVC="${GITEA_SVC:-gitea-http.gitea.svc.cluster.local:3000}"
APPS_REPO_NAME="${APPS_REPO_NAME:-app-of-apps}"
APPS_PATH="${APPS_PATH:-clusters/dev-nbg}"
# ─────────────────────────────────────────────────────────────

# 1. Hämta Gitea-credentials från klustret
ADMIN_USER="$(kubectl -n "${GITEA_NAMESPACE}" get secret "${GITEA_SECRET}" \
  -o jsonpath='{.data.admin-username}' | base64 -d)"
ADMIN_PASS="$(kubectl -n "${GITEA_NAMESPACE}" get secret "${GITEA_SECRET}" \
  -o jsonpath='{.data.admin-password}' | base64 -d)"

REPO_URL="http://${GITEA_SVC}/${ADMIN_USER}/${APPS_REPO_NAME}.git"

# 2. Installera Argo CD via Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --create-namespace \
  --version "${ARGOCD_VERSION}" \
  --set "configs.params.server\.insecure=true" \
  --wait

# 3. Skapa repo-secret för Gitea
kubectl -n "${ARGOCD_NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea-app-of-apps-repo
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: ${REPO_URL}
  username: ${ADMIN_USER}
  password: ${ADMIN_PASS}
EOF

# 4. Applicera root App of Apps
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: ${APPS_PATH}
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "✅ Klar. Admin-lösenord:"
echo "   kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret \\"
echo "     -o jsonpath='{.data.password}' | base64 -d"
