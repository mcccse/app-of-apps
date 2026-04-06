#!/usr/bin/env bash

kubectl -n renovate create job --from=cronjob/renovate renovate-once
