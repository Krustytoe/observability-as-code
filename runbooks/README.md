# Runbooks

Each alert's `runbook_url` points to an anchor on this page. Keep entries short: what it means, how to confirm, what to do.

## NodeExporterDown

**Severity:** critical. Prometheus can't scrape `node_exporter`, so the host is down, unreachable, or the exporter has stopped.

1. Is the host up? Check the cloud console instance status checks.
2. If it is up: `systemctl status node_exporter`, and check the SG / NACL / host firewall allows `:9100` from Prometheus.
3. If many hosts drop at once, suspect Prometheus, service discovery, or the network path, not the hosts.

## NodeHighCPU

**Severity:** warning. CPU has been above 90% for 15 minutes.

1. Identify the process: `top -o %CPU` / `pidstat 5`.
2. Compare with the **Load average per core** panel. Load > 1 per core means work is queueing, so latency is likely affected.
3. Decide: expected batch job (tune the threshold or schedule), runaway process (restart / fix), or real demand (scale out or up).

## NodeMemoryPressure

**Severity:** warning above 90%, critical (`NodeMemoryExhausted`) above 97%.

1. `ps aux --sort=-rss | head`. Look for a leak (RSS growing over days on the dashboard).
2. Check `dmesg -T | grep -i oom` for kills that already happened.
3. Short term: restart the leaking service. Long term: fix the leak or right-size the instance.

## NodeFilesystemFillingUp

**Severity:** warning when predicted full within 24h; critical (`NodeFilesystemAlmostFull`) below 5% free.

1. `du -xh --max-depth=2 <mountpoint> | sort -h | tail`. Usual suspects: logs, core dumps, container images, temp files.
2. Find files that are deleted but still held open: `lsof +L1`.
3. Free space safely (rotate/compress logs, prune images). If the growth is legitimate, expand the volume (EBS online resize + `growpart` / `xfs_growfs`).

## SLOErrorBudgetBurn

**Severity:** critical (fast burn, someone gets paged) or warning (slow burn, file a ticket).

1. Open **SLO / HTTP Availability** and filter to the job. Which window is hot?
2. Line the start of the burn up against deploys, config changes, and dependency incidents.
3. Fast burn: roll back or fail over first, investigate after. Slow burn: find the failing endpoint/code path (`sum by (handler, code)`) and prioritize the fix against the remaining budget.

## KubePodCrashLooping

**Severity:** warning.

1. `kubectl -n <ns> describe pod <pod>`: check exit code, last state, and events.
2. `kubectl -n <ns> logs <pod> -c <container> --previous`.
3. Common causes: bad config or secret, a failing dependency at startup, OOMKilled (exit 137, so raise limits or fix the leak), a failing liveness probe.

## KubeDeploymentReplicasMismatch

**Severity:** warning when degraded, critical (`KubeDeploymentUnavailable`) at zero available.

1. `kubectl -n <ns> rollout status deploy/<name>` and `kubectl -n <ns> get rs`.
2. Pending pods mean capacity or scheduling (taints, affinity, quota, PVC binding). Running but not ready means failing readiness probes.
3. If a rollout caused it: `kubectl -n <ns> rollout undo deploy/<name>`.

## KubePersistentVolumeAlmostFull

**Severity:** critical.

1. Check what's consuming the space inside the pod (`kubectl exec ... -- du -sh /data/*`).
2. If the StorageClass has `allowVolumeExpansion: true`, raise `spec.resources.requests.storage` on the PVC.
3. Databases: check WAL / binlog retention and replication slots before deleting anything.
