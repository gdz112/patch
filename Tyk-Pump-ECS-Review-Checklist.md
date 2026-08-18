# Tyk Pump ECS — Review and Testing Checklist

Use this checklist before and after deploying Tyk Pump on ECS Fargate.

---

## Pre-deployment checks

### Image

- [ ] Confirm `pump_base_image` tag exists in Nexus / internal container registry
  - Path: `barclays/barclays-api-gateway/tyk/tyk-pump/1.16.0`
  - Tag: `1.16.0.291` (or latest from `tyk-pump-docker-image` pipeline)
- [ ] Confirm ECR sync product (`infra-ecr-infra`) is deployed in the target account
- [ ] Confirm the Pump Dockerfile builds successfully locally (optional but recommended)

### Redis

- [ ] Confirm Redis endpoint is reachable from ECS subnets
  - Non-prod: `master.*:6429` with `ENABLECLUSTER=false`
  - Prod: `clustercfg.*:6429` with `ENABLECLUSTER=true`
- [ ] Confirm ElastiCache security group ID is correct (`sg-0364d6d9228c04a57` for dev)
- [ ] Confirm Redis password exists in SSM at `/tyk/redis/password`

### ECS cluster

- [ ] Confirm shared ECS cluster stack exists (default: `tyk-cluster`)
- [ ] Confirm VPC subnets are populated in SSM (`/app/network/Sub1Id`, `Sub2Id`, `Sub3Id`)
- [ ] Confirm VPC ID is populated in SSM (`/app/network/VPCId`)

### IAM

- [ ] Confirm `core-ServiceRolePermissionsBoundary` policy exists in account
- [ ] Confirm `svc-ECSFargateExecutionRole-{region}` exists in account
- [ ] Confirm task role can read `ssm:GetParameter` on `arn:aws:ssm:*:*:parameter/tyk/*`

### Pipeline

- [ ] Confirm GitLab runner tag `aws-eu-west-2/linux/micro` is available
- [ ] Confirm CSM secrets for Nexus and AWS are accessible
- [ ] Confirm BLZ login with `core-AccountAdmin` role succeeds
- [ ] Confirm `yq` is available on the builder image

---

## Pipeline execution checks

### Pump-only deploy (`deploy_pump=true`, `deploy_gateway=false`)

- [ ] `version` job completes and produces `RELEASE_VERSION`
- [ ] `set-image-url` job updates `infra-pump/dev/deploy-stack.yaml` with correct image URL
- [ ] `set-image-url` job injects correct values for:
  - `FriendlyStackName`
  - `ECSClusterStack`
  - `TaskCPU` / `TaskMemory`
  - `RedisEndpoint`
  - `RedisEnableCluster`
  - `RedisSecurityGroupId`
  - `PumpLogLevel`
- [ ] `docker-build-pump` job builds and pushes wrapper image
- [ ] `docker-build` job is **skipped** (Gateway disabled)
- [ ] `ecs-pump-deploy-dev-deploy` job creates or updates CloudFormation stack
- [ ] `ecs-deploy-dev-deploy` job is **skipped** (Gateway disabled)
- [ ] CloudFormation stack reaches `CREATE_COMPLETE` or `UPDATE_COMPLETE`

### Both Gateway and Pump deploy

- [ ] Both `docker-build` and `docker-build-pump` jobs run
- [ ] Both `ecs-deploy-dev-deploy` and `ecs-pump-deploy-dev-deploy` jobs run
- [ ] Both stacks reach `CREATE_COMPLETE` or `UPDATE_COMPLETE`

---

## Post-deployment checks

### ECS service

- [ ] ECS service `tyk-pump-test-service` is running with desired count = 1
- [ ] Task status is `RUNNING`
- [ ] No task failures or restarts in the last 5 minutes

### Container health

- [ ] Container health check passes (`http://127.0.0.1:8083/health`)
- [ ] Health status shows `HEALTHY` in ECS console

### Logs

- [ ] CloudWatch log group exists: `/ecs/app/ecscontainer/tyk-pump-test`
- [ ] Log stream contains `[INIT] Redis password loaded from SSM`
- [ ] No `[FATAL]` messages in log stream
- [ ] Pump analytics records appear as JSON with field `tyk-analytics-record` (requires Gateway to be sending analytics to Redis)

### Redis connectivity

- [ ] Pump connects to Redis without errors in logs
- [ ] No `connection refused` or `timeout` errors
- [ ] Pump purges analytics from Redis (check Redis key count if accessible)

### Security group

- [ ] Pump SG allows egress to Redis on port 6429
- [ ] Pump SG allows egress on 443 (SSM, proxy)
- [ ] No unexpected ingress rules (Pump should have none — no ALB)

---

## Observe checks (only if `enable_observe=true`)

- [ ] `observe-subscription-filters-dev-deploy` job completes
- [ ] Subscription filter exists on `/ecs/app/ecscontainer/tyk-pump-test`
- [ ] Filter destination ARN matches the supplied Kinesis ARN
- [ ] Logs appear in Observe within expected timeframe

---

## Rollback

If the deployment fails:

1. Check CloudFormation events for the failing resource
2. If stack is in `ROLLBACK_COMPLETE`, delete and redeploy
3. If task fails to start, check:
   - image pull errors (ECR sync / image tag)
   - SSM fetch errors (missing parameter or IAM)
   - Redis connectivity (SG / endpoint / SSL)
4. Gateway is unaffected by Pump deployment failures (separate stack)

---

## Sign-off

| Check | Owner | Date | Status |
|-------|-------|------|--------|
| Pre-deployment | | | |
| Pipeline execution | | | |
| Post-deployment | | | |
| Observe (if applicable) | | | |
