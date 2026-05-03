#!/usr/bin/env bash

kubectl -n renovate create job renovate-scan --from=cronjob/renovate
