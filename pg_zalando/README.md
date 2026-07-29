# Cluster setup

## Create new cluster

```
kind create cluster --config kind-config.yaml --name salando

```
## Check if cluster is running

```
kubectl cluster-info --context kind-salando
```

## Destroy cluster after testing

```
kind delete cluster --name salando
```


# Setup Postgres provider

```
kubectl apply -f minio.yaml
kubectl wait --for=condition=available deployment/minio --timeout=180s
kubectl wait --for=condition=complete job/minio-create-bucket --timeout=180s

helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
helm install postgres-operator postgres-operator-charts/postgres-operator -f postgres-operator-values.yaml
helm install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui -f postgres-operator-ui-values.yaml
```

The Postgres operator UI is then available at `http://localhost:8080/`.

# Proxy for DB in openStack

## Create 

```
kubectl create secret generic openvpn-config \
  --from-file=client.ovpn \
  --from-file=ca.crt \
  --from-file=client.crt \
  --from-file=client.key

```

# Install a Postgres cluster

```
kubectl create -f postgres-manifest.yaml

```

# Connect to DB

## Setup connection information

```
kubectl port-forward svc/acid-minimal-cluster 5436:5432

export PGHOST=127.0.0.1
export PGPORT=5436
export PGPASSWORD=$(kubectl get secret postgres.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d)
export PGSSLMODE=require

```

## Connect to DB

```
psql -U postgres
```

# Backup storage

- MinIO runs inside the cluster as an S3-compatible endpoint at `http://minio.default.svc.cluster.local:9000`.
- From the host, the MinIO S3 API is reachable at `http://localhost:9000` (NodePort 30900 via a kind port mapping; credentials `minioadmin` / `minioadmin123`).
- The MinIO Console (web UI to manage buckets, objects and users) is available at `http://localhost:9001` (NodePort 30901).
- WAL archiving and physical base backups are configured through `postgres-operator-values.yaml`.
- Logical backups are enabled per cluster in `postgres-manifest.yaml` and stored in the same `postgres-backups` bucket.
- The installed operator chart version (`1.15.1`) does not accept `enableMasterNodePort` / `masterNodePort` in the `postgresql` manifest, so DB access stays on `kubectl port-forward` in this repo.

# Migrating the `web` DB from the external source

The source DB (PostgreSQL 16, OpenStack) is exposed inside the cluster as the
selector-less Service `external-db` (`db_service_pass_through.yml`). Physical
cloning (`pg_basebackup`, the operator's `clone:`/`standby:` features) is **not
possible**: the endpoint rejects replication-protocol connections and the only
available role (`web`) has no `REPLICATION` privilege. Migration is therefore
logical: parallel `pg_dump`/`pg_restore` inside a maintenance window.

## One-time setup

```bash
# target cluster: DB "web" owned by user "web"
kubectl apply -f postgres-manifest-web.yaml
kubectl wait --for=condition=ready pod -l cluster-name=acid-web --timeout=300s

# extensions must be created as superuser before the restore
kubectl exec acid-web-0 -- psql -U postgres -d web \
  -c 'CREATE EXTENSION IF NOT EXISTS dblink;' \
  -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;' \
  -c 'CREATE EXTENSION IF NOT EXISTS unaccent;' \
  -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp";' \
  -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;' \
  -c 'CREATE EXTENSION IF NOT EXISTS hstore;'

# credentials for the source DB (user "web")
kubectl create secret generic external-db-credentials \
  --from-literal=username=web \
  --from-literal=password='<source-password>'
```

## Run the migration

```bash
kubectl apply -f pg-migrate-web.yaml
kubectl wait --for=condition=complete job/pg-migrate-web --timeout=600s
kubectl logs job/pg-migrate-web
```

The Job dumps from `external-db` (`-Fd -j 4 -Z3 --no-owner --no-privileges`),
filters `EXTENSION` entries from the TOC (they are pre-created on the target),
and restores into `acid-web` with `-j 4 --clean --if-exists` (safe to re-run).
Validated on the test DB: all 121 table row counts and 265 indexes match.

## Adjustments for the ~400GB production DB

- `postgres-manifest-web.yaml`: `volume.size: 500Gi` (headroom; volumes can
  grow but not shrink), `numberOfInstances: 2`.
- `pg-migrate-web.yaml`: replace the `emptyDir` scratch volume with a PVC of
  ~200Gi (holds the compressed dump), raise `-j` to `8`.
- Cutover: stop application writes -> run the Job -> validate row counts ->
  repoint the application to the `acid-web` service.
- Duration is dominated by the single largest table (dump parallelism is
  per-table). If one table is a large fraction of the 400GB, split it with
  ranged `COPY ... WHERE` chunks as a fallback.

## Known caveats

- **Collation**: the source DB uses `C.UTF-8`; the operator-created `web` DB
  uses the Spilo default locale. Data is identical, but `ORDER BY` results can
  differ. If the application depends on `C.UTF-8` ordering, drop and recreate
  the database with `LC_COLLATE 'C.UTF-8'` (from `template0`) before the
  restore.
- **Large objects**: `web` cannot read `pg_largeobject`, so LO usage could not
  be verified and LOs would not be dumped. Confirm with the application team
  that no LOs are used (bytea is unaffected).
- Validation query used for the row-count diff: generate a
  `SELECT ... count(*) ... UNION ALL` statement from `pg_tables` on the source,
  run it against both databases, pipe both through `sort`, and `diff` (sorting
  first avoids false diffs from the collation difference above).
