# apps-repo

Centralt GitOps-repo för App of Apps med Argo CD.

## Struktur

```
apps-repo/
  clusters/               # Ett katalog per kluster — här styr du vilka appar klustret har
    prod-ams/
      apps.yaml
    staging-fsn/
      apps.yaml
    dev-nbg/
      apps.yaml

  apps/                   # En katalog per applikation — Helm chart wrapper + values per miljö
    kubescape/
      Chart.yaml
      values.yaml
      values-dev.yaml
      values-staging.yaml
      values-prod.yaml
    argocd/
      Chart.yaml
      values.yaml
      values-dev.yaml
      values-staging.yaml
      values-prod.yaml

  renovate.json           # Renovate håller Helm chart-versioner uppdaterade automatiskt
```

## Lägga till en ny app på ett kluster

Redigera `clusters/<kluster>/apps.yaml` och lägg till ett element i listan:

```yaml
- app: min-nya-app
  env: prod
```

Committa och pusha — Argo CD synkar automatiskt.

## Lägga till en ny applikation

1. Skapa en ny katalog under `apps/<app-namn>/`
2. Lägg till `Chart.yaml` med dependency mot applikationens Helm chart
3. Lägg till `values.yaml` och `values-<env>.yaml` för varje miljö
4. Lägg till appen i önskade kluster under `clusters/`

## Miljöer

| Miljö     | Kluster       | Syfte                          |
|-----------|---------------|--------------------------------|
| dev       | dev-nbg       | Utveckling, testar nya versioner |
| staging   | staging-fsn   | UAT, verifiering innan prod    |
| prod      | prod-ams      | Produktion                     |

## Versionshantering med Renovate

Renovate skannar `Chart.yaml`-filer och öppnar automatiskt PRs när nya
Helm chart-versioner finns tillgängliga. Se `renovate.json` för konfiguration.

Kontrollera alltid att en ny version fungerar i dev/staging innan du mergar till prod.
