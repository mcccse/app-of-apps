#!/usr/bin/env bash

kubectl -n kubescape create job vuln-scan --from=cronjob/kubevuln-scheduler

kubectl -n kubescape create job compliance-scan --from=cronjob/kubescape-scheduler
