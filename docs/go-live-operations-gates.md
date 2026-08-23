# Go-live operations gates

This is the executable production-release sequence. A checkbox or a green run
from another commit is not evidence for a release candidate.

## 1. Immutable source and exact-SHA CI

`deploy.yml` and `release-preflight.yml` resolve the requested ref once to its
full 40-character commit SHA. They refuse commits not reachable from
`origin/main` and query GitHub Actions by `head_sha`.

A full/web production deploy requires these successful workflows for that exact
SHA:

- `backend-ci.yml`;
- `admin-ci.yml`;
- `release-safeguards-ci.yml`.

The store preflight additionally requires `flutter-ci.yml`. Those workflows run
on every `main` commit without path filters so an unchanged component cannot
leave a release SHA with missing evidence.

Repository settings remain an external control: protect `main`, require pull
requests and the four checks above, prevent force pushes/deletion, and require a
reviewer on the GitHub `production` environment. The workflows cannot configure
those settings themselves.

## 2. Deployment evidence

The full deploy performs, in order:

1. resolve and authorize the immutable SHA;
2. mirror only the allowlisted deployment trees with scoped pruning, preserving
   runtime env files, uploads, dependencies/caches, root backups and unrelated
   VPS data;
3. build the API and admin images;
4. create a custom-format PostgreSQL dump and parse it with `pg_restore --list`;
5. run `prisma migrate deploy`, then require `prisma migrate status` to be clean;
6. optionally seed only when explicitly requested;
7. require `npm run verify:catalog` against the target database;
8. replace the containers and assert the running image tag equals the SHA;
9. require public liveness, readiness, and `/api/health/version` to report that
   exact SHA;
10. require the database-backed catalog, web redirect, and
   `scripts/delivery-gate.sh` to pass;
11. write the SHA, process start time, migration/catalog result, backup result,
    and public checks to the Actions job summary.

Migrations remain forward-only. A failed health gate rolls application images
back, not the database schema.

## 3. Backup heartbeat and safe restore evidence

The `db-backup` Compose service is unhealthy when it has no non-empty daily
archive newer than 30 hours. `.github/workflows/backup-readiness.yml` runs every
six hours from the protected default branch and proves:

- the `db-backup` container is running;
- the newest backup is no older than the selected threshold;
- the archive is non-trivial and its gzip stream/custom-dump header is readable.

No new credential value is required. The scheduled heartbeat uses the existing
`VPS_SSH_KEY`, `VPS_HOST`, `VPS_USER`, and `VPS_PATH` as repository Actions
secrets so it cannot be held waiting for a production-environment reviewer.
The manual restore workflow is still protected by that environment.

The restore tool is non-destructive by default:

```bash
BACKUP_DIR=./backups scripts/restore-drill.sh
```

That command only validates and prints a plan. A recorded manual
`backup-restore-drill.yml` run with `execute_restore_drill=true` passes
`--execute`; this creates a temporary
PostgreSQL 15 container and Docker volume on an isolated network, restores the
archive, verifies that public tables exist, and removes both resources. The
script never names, connects to, stops, or overwrites `kpb_db`.

Run an executed restore drill before launch and at least quarterly. The release
preflight rejects a drill older than 90 days. Retain its Actions URL in the
release ticket. This proves the local dump is restorable; an
off-site copy and a disaster-recovery drill from that copy remain separate human
operations.

## 4. Twenty-four-hour stability gate

`uptime.yml` still probes every 15 minutes. A manual run with `verify_24h=true`,
and the default store release preflight, query the preceding scheduled-run
history and require all of the following:

- no failed or cancelled completed scheduled probe in the last 24 hours;
- at least 80 successful scheduled runs;
- no uncovered interval longer than 30 minutes, including the edges of the
  24-hour window.

The window starts over after any outage or missing interval. The manual
preflight exposes an explicit override for emergencies, but records a warning
in its summary; it is not acceptable for normal go-live approval.

GitHub schedules are a backstop, not paging. Keep an independent external
monitor for API liveness/readiness, admin, legal pages, and the backup heartbeat.

## 5. Operator sequence

1. Merge the release candidate through protected `main`; record its full SHA.
2. Wait for Backend, Admin, Flutter, and Release safeguards CI on that SHA.
3. Confirm the latest scheduled **Backup readiness** heartbeat is green, then
   run **Backup restore drill** with execution enabled and retain its green URL.
4. Run **Deploy backend (VPS)** with the recorded SHA, `scope=full`, and seeding
   disabled unless this is an explicitly approved first install.
5. Retain the deploy summary and verify the reported `/health/version` SHA.
6. Let the uptime monitor accumulate a new uninterrupted 24-hour window.
7. Run **Uptime backstop** manually with the 24-hour gate enabled.
8. Run **Release preflight** on the same SHA with the correct backend-coupling
   direction and the stability gate enabled.
9. Only then promote signed artifacts to TestFlight/Play internal testing.

Steps requiring VPS access, GitHub production-environment approval, external
monitor configuration, store consoles, or real devices cannot be completed by
repository code alone.
