#!/usr/bin/env bash
set -euo pipefail

# Self-contained test for Local Path Provisioner.
# 1) Create PVC and Pod, wait until Pod is Ready
# 2) Write a file on the mounted volume
# 3) Delete and recreate Pod, verify the file persists
# Resources are cleaned up on exit.

NAMESPACE="${NAMESPACE:-default}"
PVC_NAME="${PVC_NAME:-local-path-pvc}"
POD_NAME="${POD_NAME:-volume-test}"
STORAGE_CLASS_NAME="${STORAGE_CLASS_NAME:-local-path}"
TIMEOUT="${TIMEOUT:-180s}"

cleanup() {
  kubectl -n "${NAMESPACE}" delete pod "${POD_NAME}" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  kubectl -n "${NAMESPACE}" delete pvc "${PVC_NAME}" --ignore-not-found --wait=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ${STORAGE_CLASS_NAME}
  resources:
    requests:
      storage: 128Mi
EOF

kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
spec:
  containers:
  - name: ${POD_NAME}
    image: nginx:stable-alpine
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: volv
      mountPath: /data
    ports:
    - containerPort: 80
  volumes:
  - name: volv
    persistentVolumeClaim:
      claimName: ${PVC_NAME}
EOF

kubectl -n "${NAMESPACE}" wait --for=condition=Ready "pod/${POD_NAME}" --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}"
kubectl -n "${NAMESPACE}" get pod "${POD_NAME}"

# Write data
kubectl -n "${NAMESPACE}" exec "${POD_NAME}" -- sh -c "echo testing-write-local-path > /data/testfile"

# Recreate pod to ensure data persists
kubectl -n "${NAMESPACE}" delete pod "${POD_NAME}" --wait=true

kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
spec:
  containers:
  - name: ${POD_NAME}
    image: nginx:stable-alpine
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: volv
      mountPath: /data
    ports:
    - containerPort: 80
  volumes:
  - name: volv
    persistentVolumeClaim:
      claimName: ${PVC_NAME}
EOF

kubectl -n "${NAMESPACE}" wait --for=condition=Ready "pod/${POD_NAME}" --timeout="${TIMEOUT}"

kubectl -n "${NAMESPACE}" exec "${POD_NAME}" -- sh -c "cat /data/testfile"

# Success message
echo "PVC data persisted across pod recreation."
