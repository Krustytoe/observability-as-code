# Contributing

Thanks for taking a look. Issues and PRs are welcome. For anything bigger than a small fix, open an issue first so we can agree on the approach before you write code.

## Workflow

1. Branch from `main` (fork first if you don't have write access).
2. Make the change and run the local checks below. They're the same ones CI runs.
3. Open a PR using the template. **The PR title must be a [Conventional Commit](https://www.conventionalcommits.org/)** (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `feat!:` for breaking changes). PRs are squash-merged, so the title becomes the commit, and [release-please](https://github.com/googleapis/release-please) uses it to pick the next version and write the changelog.
4. CI must be green and the PR reviewed before merge.

## Local checks

Requires `promtool`, go-jsonnet (`jsonnet`, `jsonnetfmt`), `jb`, and Python 3. CI installs pinned versions; see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

```bash
make vendor   # first time only: jb install (pinned in grafana/jsonnetfile.lock.json)
make ci       # fmt-check → promtool check rules → promtool test rules → build dashboards → policy checks
make fmt      # auto-format Jsonnet
```

If you touched `deploy/terraform`:

```bash
cd deploy/terraform
terraform fmt -check
terraform init -backend=false -input=false
terraform validate
```

## Content conventions

- **Every alert has a test with both a firing and a non-firing case** in `prometheus/tests/`. A rule PR without a test won't be merged.
- **Severity follows the repo convention:** `warning` is informational/awareness, `critical` means service interruption or needs immediate attention. Every alert carries a `summary` and a `runbook_url` pointing at its anchor in [`runbooks/README.md`](runbooks/README.md).
- **Dashboards are Jsonnet only.** Don't commit hand-edited JSON. Everything in `build/` is generated. Dashboards must use the `$datasource` variable, a stable `uid` of 40 characters or fewer, and `editable: false`. `scripts/check_dashboards.py` enforces all of this.

## Ground rules

- **No secrets in the repo, ever.** That includes tokens, keys, account/subscription/tenant IDs, and internal hostnames in examples or test fixtures. Use obvious placeholders.
- **Pin third-party GitHub Actions to a full commit SHA** with the version as a trailing comment (`uses: org/action@<sha> # v1.2.3`) so Dependabot can bump them.
- Keep changes focused: one concern per PR makes review and rollback easy.

## Security issues

Don't open a public issue. See [SECURITY.md](SECURITY.md).
