#!/usr/bin/env bash

BROWSER="Brave Browser"

scripts/port-forward.sh &&
  open -a "${BROWSER}" http://localhost:8082 &&
  echo -n "grafana User: admin, passwd: " &&
  kubectl -n grafana get secret grafana-admin \
    -o jsonpath='{.data.admin-password}' | base64 -d
