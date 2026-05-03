#!/usr/bin/env bash

BROWSER="Brave Browser"

scripts/port-forward.sh &&
  open -a "${BROWSER}" http://localhost:3000/admin/app-of-apps &&
  open -a "${BROWSER}" http://localhost:8080 &&
  echo -n "argocd User: admin, passwd: " &&
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d &&
  echo "" &&
  echo -n "gitea User: admin, passwd: " &&
  kubectl -n gitea get secret gitea-admin \
    -o jsonpath="{.data.admin-password}" | base64 -d
