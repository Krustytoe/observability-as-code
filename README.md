# observability-as-code

Prometheus alerting rules, Grafana dashboards, and the deploy pipeline for both, all version-controlled, unit-tested, and generated from code instead of being clicked together in a UI.

```
prometheus/
  rules/        node, kubernetes, and SLO burn-rate rules
  tests/        promtool unit tests: every alert has a firing AND a non-firing case
grafana/
  lib/          shared Grafonnet helpers: datasource variable, panel defaults, thresholds
  dashboards/   *.jsonnet → build/dashboards/*.json
deploy/
  terraform/    publishes rendered dashboards to Grafana / Grafana Cloud
runbooks/       one anchor per alert, linked from each rule's runbook_url
scripts/        policy checks on rendered dashboards
```

## What's in it

| Area | Highlights |
|---|---|
| **Host alerts** | Predictive disk-fill (`predict_linear` + a "<25% free" guard to cut noise), separate warning/critical memory tiers, tmpfs/overlay and read-only mounts excluded |
| **Kubernetes alerts** | CrashLoopBackOff, degraded vs. fully unavailable deployments (scale-to-zero won't page), PVC exhaustion |
| **SLO alerts** | 99.9% HTTP availability with **multi-window, multi-burn-rate** alerts (Google SRE Workbook): 14.4x/6x pages, 3x/1x tickets |
| **Dashboards** | Fleet overview and SLO/error-budget views, built with Grafonnet and templated on `$datasource` so they import into any stack |
| **Guardrails** | CI blocks hard-coded datasource UIDs, duplicate or overlong UIDs, and `editable: true` dashboards |

## Alerting convention

| Severity | Meaning | Route |
|---|---|---|
| `warning` | Awareness; act within business hours | Ticket / chat |
| `critical` | Service interruption or imminent impact; act now | Page on-call |

Every alert carries a `runbook_url`, and its thresholds match the dashboard panel colors so the alert and the graph agree.

## Usage

```bash
make vendor          # jb install grafonnet (pinned in jsonnetfile.lock.json)
make ci              # fmt-check, promtool check + test, build dashboards, policy checks
make fmt             # jsonnetfmt -i
```

Deploying the dashboards:

```bash
make dashboards
cd deploy/terraform
export TF_VAR_grafana_url=https://<stack>.grafana.net
export TF_VAR_grafana_auth=<service-account-token>   # never commit
terraform init && terraform plan && terraform apply
```

Rules load straight into Prometheus (`rule_files:`). For Grafana Cloud / Mimir, run `mimirtool rules sync --rule-dirs=prometheus/rules`.

## Testing philosophy

An alert without a test is a guess. Each rule file has a promtool test that proves it:

- **fires** on the condition it's meant to catch, with the exact labels and annotations,
- **stays quiet** on the look-alike cases: healthy neighbours, tmpfs, read-only mounts, scaled-to-zero deployments, error spikes that have already recovered.

## Dashboard policy checks

`scripts/check_dashboards.py` runs after the build and fails CI when a rendered dashboard:

- is missing a `uid`, or the uid exceeds Grafana's 40-char limit, or two dashboards share the same uid
- references a datasource by a hard-coded uid instead of the `$datasource` variable
- has `editable: true` (the repo is the source of truth; UI edits get overwritten on the next deploy)

Run it locally: `python3 scripts/check_dashboards.py build/dashboards`

## Requirements

`promtool` ≥ 2.x, `jsonnet` / `jsonnetfmt` (go-jsonnet), `jb`, Python 3, Terraform ≥ 1.7 for deploys. CI installs pinned versions; see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## License

MIT
