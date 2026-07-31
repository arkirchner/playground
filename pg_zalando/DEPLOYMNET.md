# Deploying the Zalando Postgres operator

Deploys `postgres-operator` + `postgres-operator-ui` into a dedicated
`zalando-postgres-operator` namespace, with WAL archiving and logical
backups going to an external S3 endpoint (e.g. Ceph OpenHPI Cloud).

## Prerequisites

- `kubectl` context pointing at the target cluster, Helm 3

## 1. Create the namespace

```bash
kubectl create namespace zalando-postgres-operator
```

## 2. Create the S3 credentials secret

The secret is needed in two kinds of namespaces:

- `zalando-postgres-operator`: the operator UI reads it via `secretKeyRef`.
- **Every** namespace where Postgres clusters are deployed: the operator reads
  `pod_environment_secret` and `logical_backup_cronjob_environment_secret`
  only from the cluster's own namespace (no cross-namespace support), and the
  Spilo pods reference it via `secretKeyRef` as well.

The name must match the references in both values files (`s3-access`). With
many cluster namespaces, replicate automatically instead of copying by hand
(e.g. with mittwald/kubernetes-replicator).

```bash
kubectl -n zalando-postgres-operator create secret generic s3-access \
  --from-literal=AWS_ACCESS_KEY_ID='U0PV847GLDETGJ7H5HOG' \
  --from-literal=AWS_SECRET_ACCESS_KEY='foobarbaz' \
  --from-literal=AWS_REGION='us-east-1' \
  --from-literal=AWS_DEFAULT_REGION='us-east-1' \
  --from-literal=AWS_ENDPOINT='https://s3.openhpicloud.de'

# repeat with the same literals for every namespace that hosts Postgres clusters:
# kubectl -n <cluster-namespace> create secret generic s3-access ...
```

If the S3 endpoint has no SSE/KMS support (plain Ceph RGW, MinIO), also add
`--from-literal=WALG_DISABLE_S3_SSE='true'` - Spilo otherwise defaults
`WALG_S3_SSE` to `AES256` and every WAL upload fails with
`NotImplemented: Server side encryption specified but KMS is not configured`.

## 3. Chart values for provider and UI

Create the two files for easy deployment.


```bash
# postgres-operator-values.yaml
configKubernetes:
  pod_environment_secret: s3-access

configAwsOrGcp:
  aws_region: us-east-1
  wal_s3_bucket: sci-test-kubernetes-postgres-backups

configLogicalBackup:
  logical_backup_s3_bucket: sci-test-kubernetes-postgres-backups
  logical_backup_s3_bucket_prefix: logical
  logical_backup_s3_retention_time: 7 days
  logical_backup_s3_sse: ""
  # non-sensitive: the backup script only honors LOGICAL_BACKUP_S3_ENDPOINT /
  # LOGICAL_BACKUP_S3_REGION, which the operator generates from this config
  logical_backup_s3_endpoint: https://s3.openhpicloud.de
  logical_backup_s3_region: us-east-1
  # credentials: read from the s3-access secret in each cluster's namespace
  logical_backup_cronjob_environment_secret: s3-access

```

```bash
# postgres-operator-ui-values.yaml

service:
  type: LoadBalancer

extraEnvs:
  - name: SPILO_S3_BACKUP_BUCKET
    value: sci-test-kubernetes-postgres-backups
  - name: SPILO_S3_BACKUP_PREFIX
    value: spilo/
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: s3-access
        key: AWS_ACCESS_KEY_ID
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: s3-access
        key: AWS_SECRET_ACCESS_KEY
  - name: AWS_DEFAULT_REGION
    valueFrom:
      secretKeyRef:
        name: s3-access
        key: AWS_DEFAULT_REGION
  - name: AWS_ENDPOINT
    valueFrom:
      secretKeyRef:
        name: s3-access
        key: AWS_ENDPOINT

```

## 4. Deploy the charts


Add the helm Repositories:

```bash

helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui

```

Install the provider with the UI.

```bash
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --version 2.0.0 \
  --namespace zalando-postgres-operator \
  -f postgres-operator-values.yaml

helm install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui \
  --version 2.0.1 \
  --namespace zalando-postgres-operator \
  -f postgres-operator-ui-values.yaml
```

## Verify

```bash
kubectl -n zalando-postgres-operator get pods
kubectl -n zalando-postgres-operator port-forward svc/postgres-operator-ui 8080:80
# UI at http://localhost:8080/
```
