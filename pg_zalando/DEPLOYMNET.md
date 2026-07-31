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

The operator mounts this secret into Postgres pods (`pod_environment_secret`)
and into the logical-backup CronJobs; the operator UI also reads it for its S3
snapshot view. The name must stay `local-s3-credentials` (referenced by both
values files).

```bash
kubectl -n zalando-postgres-operator create secret generic s3-access \
  --from-literal=AWS_ACCESS_KEY_ID='U0PV847GLDETGJ7H5HOG' \
  --from-literal=AWS_SECRET_ACCESS_KEY='foobarbaz' \
  --from-literal=AWS_DEFAULT_REGION='us-east-1' \
  --from-literal=AWS_ENDPOINT='https://s3.openhpicloud.de' \

```

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
  logical_backup_cronjob_environment_secret: s3-secret

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

## 3. Deploy the charts


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
