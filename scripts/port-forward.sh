#!/usr/bin/env bash


kubectl port-forward svc/headlamp 	-n headlamp 	8081:80 > /dev/null 2>&1 &
kubectl port-forward svc/forgejo-http 	-n forgejo 	3000:3000 > /dev/null 2>&1 &
kubectl port-forward svc/argocd-server 	-n argocd 	8080:80 > /dev/null 2>&1 &
