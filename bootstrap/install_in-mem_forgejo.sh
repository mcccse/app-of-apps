#!/usr/bin/env bash
set -euo pipefail

# Ephemeral Forgejo installation via the official Helm chart (no PVC).
# - Namespace: gitea
# - Admin credentials are managed in a Secret (created if missing)
# - Uses SQLite by default
# - persistence.enabled=false (uses emptyDir)
# - Creates 'app-of-apps' repository via a post-install Job

NS="forgejo"
RELEASE="forgejo"
SERVICE_NAME="forgejo"
HTTP_PORT=3000
SSH_PORT=2222

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl not found in PATH"
  exit 1
}
command -v helm >/dev/null 2>&1 || {
  echo "helm not found in PATH"
  exit 1
}

# 1) Namespace
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

# 2) Determine admin credentials and let Helm manage the Secret
if kubectl -n "${NS}" get secret forgejo-admin >/dev/null 2>&1; then
  OWNER_NS="$(kubectl -n "${NS}" get secret forgejo-admin -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-namespace}' 2>/dev/null || true)"
  OWNER_NAME="$(kubectl -n "${NS}" get secret forgejo-admin -o jsonpath='{.metadata.annotations.meta\.helm\.sh/release-name}' 2>/dev/null || true)"
  if [ "${OWNER_NS}" = "${NS}" ] && [ "${OWNER_NAME}" = "${RELEASE}" ]; then
    ADMIN_USER="$(kubectl -n "${NS}" get secret forgejo-admin -o jsonpath='{.data.username}' | base64 -d)"
    ADMIN_PASS="$(kubectl -n "${NS}" get secret forgejo-admin -o jsonpath='{.data.password}' | base64 -d)"
    echo "Reusing Helm-managed Secret ${NS}/forgejo-admin."
  else
    echo "Found pre-existing Secret ${NS}/forgejo-admin not managed by Helm; deleting to let Helm own it."
    kubectl -n "${NS}" delete secret forgejo-admin
    ADMIN_USER="admin"
    ADMIN_PASS="$(head -c 24 /dev/urandom | base64 -w 0)"
  fi
else
  ADMIN_USER="admin"
  ADMIN_PASS="$(head -c 24 /dev/urandom | base64 -w 0)"
fi

# Admin credentials prepared above; Helm will create/own Secret forgejo-admin

# 3) Install/upgrade via Helm (ephemeral)
# Using OCI chart; skipping 'helm repo add' and 'helm repo update'

helm upgrade --install "${RELEASE}" oci://code.forgejo.org/forgejo-helm/forgejo \
  --namespace "${NS}" \
  --create-namespace \
  -f - <<VALUES
gitea:
  admin:
    username: "${ADMIN_USER}"
    password: "${ADMIN_PASS}"
  config:
    server:
      ROOT_URL: "http://${SERVICE_NAME}.${NS}.svc.cluster.local:${HTTP_PORT}/"
      SSH_DOMAIN: "${SERVICE_NAME}.${NS}.svc.cluster.local"
      START_SSH_SERVER: true
      SSH_PORT: ${SSH_PORT}
    database:
      DB_TYPE: sqlite3
      PATH: /data/git/git.db
    cache:
      ADAPTER: memory
    session:
      PROVIDER: memory
    queue:
      TYPE: channel

service:
  http:
    type: ClusterIP
    port: ${HTTP_PORT}
  ssh:
    type: ClusterIP
    port: ${SSH_PORT}

persistence:
  enabled: false

postgresql-ha:
  enabled: false
# Also keep single-postgres disabled just in case
postgresql:
  enabled: false

# Disable Valkey/Redis subcharts
valkey:
  enabled: false
valkey-cluster:
  enabled: false
memcached:
  enabled: false
VALUES

# 4) Post-install Job to create 'app-of-apps' repository
kubectl -n "${NS}" delete job forgejo-create-app-of-apps --ignore-not-found
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: forgejo-create-app-of-apps
  namespace: ${NS}
spec:
  backoffLimit: 6
  activeDeadlineSeconds: 300
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: create-repo
          image: curlimages/curl:8.11.1
          imagePullPolicy: IfNotPresent
          env:
            - name: FORGEJO_BASE
              value: "http://${SERVICE_NAME}-http.${NS}.svc.cluster.local:${HTTP_PORT}"
            - name: FORGEJO_ADMIN_USER
              valueFrom:
                secretKeyRef:
                  name: forgejo-admin
                  key: username
            - name: FORGEJO_ADMIN_PASS
              valueFrom:
                secretKeyRef:
                  name: forgejo-admin
                  key: password
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -e
              i=1
              while [ "\$i" -le 60 ]; do
                if curl -fsS "\$FORGEJO_BASE/api/healthz" >/dev/null; then
                  break
                fi
                sleep 2
                i=\$((i + 1))
              done
              if curl -fsS -u "\$FORGEJO_ADMIN_USER:\$FORGEJO_ADMIN_PASS" \
                   "\$FORGEJO_BASE/api/v1/repos/\$FORGEJO_ADMIN_USER/app-of-apps" >/dev/null; then
                echo "Repository app-of-apps already exists."
                exit 0
              fi
              curl -fsS \
                -u "\$FORGEJO_ADMIN_USER:\$FORGEJO_ADMIN_PASS" \
                -H "Content-Type: application/json" \
                -d '{"name":"app-of-apps","private":false}' \
                -X POST \
                "\$FORGEJO_BASE/api/v1/user/repos"
              echo "Created repository app-of-apps."
EOF

# 5) Wait for Job completion (service readiness is polled within the Job)
kubectl -n "${NS}" wait --for=condition=complete job/forgejo-create-app-of-apps --timeout=300s

# 6) Create http service with suffix
kubectl get svc forgejo-http -n forgejo -o json | \
	jq 'del(.spec.clusterIP, .spec.clusterIPs) | .metadata.name="forgejo"' | \
	kubectl create -f -

# 7) Output connection info and credentials
echo
echo "Ephemeral Forgejo (Helm) is ready."
echo "HTTP URL:  http://${SERVICE_NAME}.${NS}.svc.cluster.local:${HTTP_PORT}"
echo "SSH URL:   ssh://git@${SERVICE_NAME}.${NS}.svc.cluster.local:${SSH_PORT}"
echo "Admin credentials: ${ADMIN_USER} / ${ADMIN_PASS}"
echo "Repo URLs:"
echo "  HTTP: http://${SERVICE_NAME}.${NS}.svc.cluster.local:${HTTP_PORT}/${ADMIN_USER}/app-of-apps.git"
echo "  SSH:   ssh://git@${SERVICE_NAME}.${NS}.svc.cluster.local:${SSH_PORT}/${ADMIN_USER}/app-of-apps.git"
echo "NOTE: Repositories are stored in memory and will be lost if the Pod restarts."
