#!/usr/bin/env bash

bootstrap/install_in-mem_gitea.sh &&
  bootstrap/bootstrap_argocd-with-gitea.sh
