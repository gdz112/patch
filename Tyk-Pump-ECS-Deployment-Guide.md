# Tyk Pump on ECS

## Purpose

This document describes the ECS deployment strategy for `Tyk Pump` in the Barclays AWS Data Plane model, the code changes made in `ecs-app-deployer`, and the runtime inputs customers must provide when running the pipeline.

The goal is to provide a customer-facing guide for engineers and developers deploying `Tyk Pump` as a second ECS service alongside `Tyk Gateway`.

## Scope

- Control Plane remains unchanged
- Tyk Pump is deployed to Amazon ECS Fargate
- Pump is implemented as a second service in `ecs-app-deployer`
- Observe is supported through optional CloudWatch subscription filter creation
- ESaaS-specific runtime dependencies are not added to the new Pump service

## High-level strategy

### Service model

`Tyk Pump` is deployed as:

- a separate ECS service
- on the shared ECS cluster
- without an ALB
- with a container health check on `http://127.0.0.1:8083/health`
- using the same Redis instance as Gateway

### Image model

The runtime image model follows Barclays standards:

- the base image is a Barclays UBI8 Pump image
- that image is produced by `tyk-pump-docker-image`
- the ECS repo does not run the Tyk vendor image directly
- `ecs-app-deployer` builds a thin wrapper image on top of the internal Pump image so it can fetch runtime secrets from SSM

### Secret model

Pump only needs the Redis password at runtime for the current PoC path:

- `SSM parameter`: `/tyk/redis/password`
- fetched by `app/fetch_ssm.py`
- exported into `TYK_PMP_ANALYTICSSTORAGECONFIG_PASSWORD`

This matches the ECS secret-fetch pattern already used by Gateway.

### Observability model

Pump logs always go to CloudWatch.

Observe onboarding is treated as customer responsibility. The pipeline can optionally create CloudWatch subscription filters if the customer supplies the Observe onboarding output values at runtime.

## Files changed in `ecs-app-deployer`

### New files

| File | Purpose |
|------|---------|
| `pump/Dockerfile` | Builds Pump ECS wrapper image from Barclays UBI8 Pump base image |
| `pump/entrypoint.sh` | Fetches Redis password from SSM and starts Pump |
| `infra-pump/product.template.yaml` | Pump ECS CloudFormation template |
| `infra-pump/metadata.yaml` | Product metadata for Pump stack |
| `infra-pump/dev/deploy-stack.yaml` | Dev deployment parameters for Pump stack |
| `infra-pump/dev/provision-product.yaml` | Dev provisioning parameters for Pump stack |

### Updated file

| File | Purpose |
|------|---------|
| `gitlab-ci.yml` | Adds runtime inputs, optional Pump build/deploy, and optional Observe subscription filter job |

## Runtime parameters in the pipeline

The pipeline now supports manual runtime inputs through `spec.inputs`.

### Deployment flags

| Input | Default | Purpose |
|-------|---------|---------|
| `deploy_gateway` | `true` | Enable or disable Gateway build and deploy |
| `deploy_pump` | `false` | Enable or disable Pump build and deploy |

### Pump deployment inputs

| Input | Default | Purpose |
|-------|---------|---------|
| `pump_friendly_stack_name` | `tyk-pump-test` | Pump CloudFormation stack and ECS service prefix |
| `ecs_cluster_stack_name` | `tyk-cluster` | Shared ECS cluster stack name |
| `pump_base_image` | `.../tyk-pump/1.16.0:1.16.0.291` | Barclays UBI8 Pump base image |
| `pump_task_cpu` | `512` | Fargate CPU units |
| `pump_task_memory` | `1024` | Fargate memory in MiB |
| `pump_redis_endpoint` | `master.tykdevdpredis-elasticache-rg.pwgmjk.euw2.cache.amazonaws.com:6429` | Redis endpoint |
| `pump_redis_enable_cluster` | `false` | Redis cluster mode |
| `pump_redis_security_group_id` | `sg-0364d6d9228c04a57` | ElastiCache SG ID for egress |
| `pump_log_level` | `debug` | Pump log level |

### Observe inputs

| Input | Default | Purpose |
|-------|---------|---------|
| `enable_observe` | `false` | Enable or disable Observe subscription filter creation |
| `observe_kinesis_destination_arn` | empty | Kinesis destination ARN from Observe onboarding |
| `observe_filter_pattern` | empty | CloudWatch subscription filter pattern; empty forwards all log events |

## What the pipeline does

### 1. Versioning

Creates `RELEASE_VERSION` from pipeline time and branch type.

### 2. Image URL generation

If `deploy_gateway=true`, updates Gateway `deploy-stack.yaml`.

If `deploy_pump=true`, updates Pump `deploy-stack.yaml` with:

- Pump stack name
- ECS cluster stack name
- CPU
- memory
- image URL
- Redis endpoint
- Redis cluster mode
- Redis SG ID
- Pump log level

### 3. Build jobs

#### Gateway

Runs only when `deploy_gateway=true`.

#### Pump

Runs only when `deploy_pump=true`.

It builds:

- wrapper image from `pump/Dockerfile`
- `FROM` the supplied `pump_base_image`
- pushes to:
  `container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump:<RELEASE_VERSION>`

### 4. CloudFormation deploy jobs

#### Gateway deploy job

Runs only when `deploy_gateway=true`.

Deploys `infra/`.

#### Pump deploy job

Runs only when `deploy_pump=true`.

Deploys `infra-pump/`.

### 5. Optional Observe job

Runs only when:

- `enable_observe=true`

It creates CloudWatch subscription filters for the deployed log groups using:

- log group name derived from stack name
- filter name derived from stack name
- filter pattern from `observe_filter_pattern`
- destination ARN from `observe_kinesis_destination_arn`

## Pump runtime behaviour

### Health

- endpoint: `:8083/health`
- ECS uses a container health check, not an ALB health check

### Redis

- analytics store type: `redis`
- SSL: enabled
- cluster mode: runtime parameter
- password source: SSM

### Logging

Pump writes JSON analytics records to stdout:

- `TYK_PMP_PUMPS_STDOUT_TYPE=stdout`
- `TYK_PMP_PUMPS_STDOUT_META_LOGFIELDNAME=tyk-analytics-record`
- `TYK_PMP_PUMPS_STDOUT_META_FORMAT=json`

Those logs go to CloudWatch and can then be shipped to Observe.

## Customer responsibilities

### Required for Pump deployment

Customers must provide or confirm:

- AWS account access
- ECS cluster stack name if different from default
- correct Redis endpoint
- correct Redis cluster mode
- correct ElastiCache security group ID
- correct Pump base image if newer than the default

### Required for Observe integration

Customers are responsible for onboarding to Observe and obtaining all required dependencies, including:

- Kinesis destination ARN
- account registration in `obsonboarding`
- IFE vs non-IFE determination
- SES role owner approvals
- ITSI confirmation
- Observe token configuration
- any required Service Catalog products for subscription filter management and consumption

This pipeline does not perform onboarding to Observe. It only consumes the onboarding outputs if supplied.

## Known constraints

1. The SSM/Lambda population path is outside Pump scope and may still need troubleshooting.
2. Pump currently assumes Redis password exists in `/tyk/redis/password`.
3. Observe application log onboarding readiness is external to this repo.
4. Pump uses the same proxy model as Gateway.

## Recommended deployment order

1. Confirm Redis exists and is reachable.
2. Confirm `/tyk/redis/password` exists in SSM.
3. Confirm `pump_base_image` exists in Nexus / internal registry.
4. Run pipeline with:
   - `deploy_pump=true`
   - `deploy_gateway=false` if only Pump is being deployed
5. Verify ECS service health.
6. If Observe is ready, rerun or run with:
   - `enable_observe=true`
   - `observe_kinesis_destination_arn=<customer ARN>`

## Example runtime values

### Non-prod Pump-only deploy

```text
deploy_gateway=false
deploy_pump=true
pump_friendly_stack_name=tyk-pump-test
ecs_cluster_stack_name=tyk-cluster
pump_base_image=container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291
pump_task_cpu=512
pump_task_memory=1024
pump_redis_endpoint=master.tykdevdpredis-elasticache-rg.pwgmjk.euw2.cache.amazonaws.com:6429
pump_redis_enable_cluster=false
pump_redis_security_group_id=sg-0364d6d9228c04a57
pump_log_level=debug
enable_observe=false
```

### Pump deploy with Observe subscription filters

```text
deploy_gateway=false
deploy_pump=true
enable_observe=true
observe_kinesis_destination_arn=<customer supplied ARN>
observe_filter_pattern=
```

## Summary

The implementation now supports:

- optional Pump deployment with a flag
- customer-supplied Pump runtime parameters
- optional Observe CloudWatch subscription filter creation
- reuse of the existing `ecs-app-deployer` structure and shared secret-fetch pattern

This gives customers a practical Pump ECS deployment path while keeping account onboarding and observability registration responsibilities outside the application deployment code.
