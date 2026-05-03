#!/usr/bin/env bash

scripts/renovate_create_secret_token.sh

scripts/create_kubescape_job_from_cronjob.sh
scripts/create_renovate_job_from_cronjob.sh
