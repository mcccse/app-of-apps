#!/usr/bin/env bash

NS=kubescape
kubectl -n "$NS" create job --from=cronjob/kubescape-scheduler manual-compliance-$(date +%s)
kubectl -n "$NS" create job --from=cronjob/kubevuln-scheduler manual-vuln-$(date +%s)
