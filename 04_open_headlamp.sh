#!/usr/bin/env bash

BROWSER="Brave Browser"

scripts/port-forward.sh &&
  open -a "${BROWSER}" http://localhost:8081 &&
  scripts/headlamp_create_token.sh
