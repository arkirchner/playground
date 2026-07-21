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
