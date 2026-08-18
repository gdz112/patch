# Tyk Pump ECS — GitLab Pipeline Runbook

This runbook provides step-by-step instructions for deploying Tyk Pump on ECS using the `ecs-app-deployer` GitLab pipeline.

---

## Pipeline inputs summary

Use this section as the quick reference for the values a customer may need to supply when running the pipeline.

| Parameter | Default | When to change it |
|-----------|---------|-------------------|
| `deploy_gateway` | `true` | Set to `false` for Pump-only deployment |
| `deploy_pump` | `false` | Set to `true` when deploying Pump |
| `gateway_friendly_stack_name` | `tyk-gateway-test` | Change if the Gateway stack uses a different friendly name |
| `pump_friendly_stack_name` | `tyk-pump-test` | Change for environment-specific Pump stack naming |
| `ecs_cluster_stack_name` | `tyk-cluster` | Change if the target ECS cluster stack is named differently |
| `pump_base_image` | `container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291` | Change when using a newer approved Pump base image |
| `pump_task_cpu` | `512` | Change if Pump needs more CPU in higher environments |
| `pump_task_memory` | `1024` | Change if Pump needs more memory in higher environments |
| `pump_redis_endpoint` | `master.tykdevdpredis-elasticache-rg.pwgmjk.euw2.cache.amazonaws.com:6429` | Change for the target environment's Redis endpoint |
| `pump_redis_enable_cluster` | `false` | Set to `true` for prod-style cluster mode Redis |
| `pump_redis_security_group_id` | `sg-0364d6d9228c04a57` | Change for the target environment's Redis security group |
| `pump_log_level` | `debug` | Change to `info` or another level as required |
| `enable_observe` | `false` | Set to `true` only after Observe onboarding is complete |
| `observe_kinesis_destination_arn` | empty | Supply when `enable_observe=true` |
| `observe_filter_pattern` | empty | Supply only if logs should be filtered before forwarding |

---

## Prerequisites

Before running this pipeline, ensure:

1. **ECS cluster** is deployed (default stack name: `tyk-cluster`).
2. **Redis** (ElastiCache) is provisioned and reachable from the ECS subnets.
3. **SSM parameter** `/tyk/redis/password` exists in the target AWS account with the Redis password.
4. **Pump base image** exists in the internal container registry.
   - Default: `container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291`
   - To find the latest: check GitLab project `tyk-pump-docker-image` -> latest successful pipeline -> `IMAGE_NAME_NON_PROD` in the `initialize` job log.
5. **CSM onboarding** is complete (AD + KV safes configured).
6. **AWS account access** is available with `core-AccountAdmin` role.

### If using Observe

7. **Observe onboarding** is complete via `obsonboarding` portal.
8. **Kinesis destination ARN** has been received via onboarding confirmation email.
9. For non-IFE accounts: `esaas-subscription-filters-management` and `esaas-subscription-filters-consumer` Service Catalog products are deployed.
10. `ec2-spoke` SCP product is at least **v40**.

---

## How to run the pipeline

### Step 1: Navigate to the pipeline

1. Open GitLab project: `ecs-app-deployer`
2. Go to **CI/CD -> Pipelines**
3. Click **Run pipeline**
4. Select your branch (e.g. `main`, `develop`, or your feature branch)

### Step 2: Fill in the pipeline inputs

The pipeline will show input fields. Fill them in as follows.

---

## Scenario 1: Deploy Pump only (non-prod)

Use this when Gateway is already deployed and you only want to add Pump.

| Input | Value |
|-------|-------|
| `deploy_gateway` | `false` |
| `deploy_pump` | `true` |
| `pump_friendly_stack_name` | `tyk-pump-test` |
| `ecs_cluster_stack_name` | `tyk-cluster` |
| `pump_base_image` | `container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291` |
| `pump_task_cpu` | `512` |
| `pump_task_memory` | `1024` |
| `pump_redis_endpoint` | `master.tykdevdpredis-elasticache-rg.pwgmjk.euw2.cache.amazonaws.com:6429` |
| `pump_redis_enable_cluster` | `false` |
| `pump_redis_security_group_id` | `sg-0364d6d9228c04a57` |
| `pump_log_level` | `debug` |
| `enable_observe` | `false` |

Click **Run pipeline**.

---

## Scenario 2: Deploy both Gateway and Pump (non-prod)

| Input | Value |
|-------|-------|
| `deploy_gateway` | `true` |
| `deploy_pump` | `true` |
| `pump_friendly_stack_name` | `tyk-pump-test` |
| `gateway_friendly_stack_name` | `tyk-gateway-test` |
| `ecs_cluster_stack_name` | `tyk-cluster` |
| `pump_base_image` | `container-release.container-registry-non-prod.barcapint.com/barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0:1.16.0.291` |
| `pump_task_cpu` | `512` |
| `pump_task_memory` | `1024` |
| `pump_redis_endpoint` | `master.tykdevdpredis-elasticache-rg.pwgmjk.euw2.cache.amazonaws.com:6429` |
| `pump_redis_enable_cluster` | `false` |
| `pump_redis_security_group_id` | `sg-0364d6d9228c04a57` |
| `pump_log_level` | `debug` |
| `enable_observe` | `false` |

Click **Run pipeline**.

---

## Scenario 3: Deploy Pump with Observe subscription filters

Use this after Observe onboarding is complete and you have the Kinesis destination ARN.

| Input | Value |
|-------|-------|
| `deploy_gateway` | `false` |
| `deploy_pump` | `true` |
| `pump_friendly_stack_name` | `tyk-pump-test` |
| `ecs_cluster_stack_name` | `tyk-cluster` |
| `pump_base_image` | *(use default or latest from Nexus)* |
| `pump_task_cpu` | `512` |
| `pump_task_memory` | `1024` |
| `pump_redis_endpoint` | *(your Redis endpoint)* |
| `pump_redis_enable_cluster` | `false` |
| `pump_redis_security_group_id` | *(your Redis SG)* |
| `pump_log_level` | `debug` |
| `enable_observe` | `true` |
| `observe_kinesis_destination_arn` | `arn:aws:kinesis:eu-west-2:XXXXXXXXXXXX:stream/observe-XXXXXXXX` |
| `observe_filter_pattern` | *(leave empty to forward all logs, or specify a filter)* |

Click **Run pipeline**.

---

## Scenario 4: Production Pump deployment

| Input | Value |
|-------|-------|
| `deploy_gateway` | `false` |
| `deploy_pump` | `true` |
| `pump_friendly_stack_name` | `tyk-pump-prod` |
| `ecs_cluster_stack_name` | `tyk-cluster-prod` |
| `pump_base_image` | *(prod-promoted image from `container-registry-prod`)* |
| `pump_task_cpu` | `1024` |
| `pump_task_memory` | `2048` |
| `pump_redis_endpoint` | `clustercfg.tykproddpredis-elasticache-rg.XXXXXX.euw2.cache.amazonaws.com:6429` |
| `pump_redis_enable_cluster` | `true` |
| `pump_redis_security_group_id` | *(prod Redis SG)* |
| `pump_log_level` | `info` |
| `enable_observe` | `true` |
| `observe_kinesis_destination_arn` | *(prod Kinesis ARN)* |
| `observe_filter_pattern` | *(as required)* |

Click **Run pipeline**.

---

## Step 3: Monitor the pipeline

Watch these jobs in order:

1. **version** -> creates release version
2. **set-image-url** -> stamps image URLs and parameters into deploy-stack files
3. **docker-build-pump** -> builds and pushes Pump wrapper image
4. **ecs-pump-deploy-dev-deploy** -> deploys Pump CloudFormation stack
5. **observe-subscription-filters-dev-deploy** -> creates subscription filters (only if `enable_observe=true`)

If any job fails, check the job log for the error. Common issues:

| Error | Likely cause | Fix |
|-------|-------------|-----|
| Image pull failed | Base image tag does not exist in Nexus | Confirm tag in `tyk-pump-docker-image` pipeline or Nexus |
| SSM parameter not found | `/tyk/redis/password` missing | Create the SSM parameter manually or fix Lambda population |
| Connection refused on 6429 | Redis SG does not allow Pump SG | Check `pump_redis_security_group_id` and SG rules |
| Stack creation failed | IAM boundary or execution role missing | Check account has required Fargate IAM roles |
| Subscription filter failed | Kinesis ARN invalid or log group missing | Confirm Observe onboarding and that ECS service created the log group |

---

## Step 4: Verify deployment

After the pipeline succeeds:

1. Open **AWS Console -> ECS -> Clusters -> tyk-cluster -> Services**
2. Find `tyk-pump-test-service`
3. Check:
   - Desired count: 1
   - Running count: 1
   - Task health: HEALTHY
4. Open **CloudWatch -> Log groups -> /ecs/app/ecscontainer/tyk-pump-test**
5. Check for:
   - `[INIT] Redis password loaded from SSM`
   - No `[FATAL]` messages
   - JSON analytics records with field `tyk-analytics-record` (once Gateway is sending analytics)

---

## How to update Pump

To update Pump (e.g. new image version, different Redis, changed log level):

1. Run the pipeline again with `deploy_pump=true`
2. Change the relevant input(s)
3. The pipeline will update the existing CloudFormation stack

---

## How to remove Pump

To remove the Pump ECS service:

1. Delete the CloudFormation stack `tyk-pump-test` from AWS Console or CLI:

```bash
aws cloudformation delete-stack --stack-name tyk-pump-test --region eu-west-2
```

2. Optionally remove the CloudWatch log group:

```bash
aws logs delete-log-group --log-group-name /ecs/app/ecscontainer/tyk-pump-test --region eu-west-2
```

3. Optionally remove subscription filters if Observe was enabled.

---

## Parameter reference

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `deploy_gateway` | Yes | `true` | Toggle Gateway build/deploy |
| `deploy_pump` | Yes | `false` | Toggle Pump build/deploy |
| `gateway_friendly_stack_name` | No | `tyk-gateway-test` | Gateway stack name |
| `pump_friendly_stack_name` | No | `tyk-pump-test` | Pump stack name |
| `ecs_cluster_stack_name` | No | `tyk-cluster` | Shared ECS cluster |
| `pump_base_image` | No | `...tyk-pump/1.16.0:1.16.0.291` | UBI8 Pump base image |
| `pump_task_cpu` | No | `512` | Fargate CPU |
| `pump_task_memory` | No | `1024` | Fargate memory |
| `pump_redis_endpoint` | No | `master...euw2...com:6429` | Redis address |
| `pump_redis_enable_cluster` | No | `false` | Redis cluster mode |
| `pump_redis_security_group_id` | No | `sg-0364d6d9228c04a57` | Redis SG for egress |
| `pump_log_level` | No | `debug` | Pump log level |
| `enable_observe` | No | `false` | Create subscription filters |
| `observe_kinesis_destination_arn` | If Observe | empty | Observe Kinesis ARN |
| `observe_filter_pattern` | No | empty | Filter pattern (empty = all logs) |
