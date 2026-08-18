# Jira Update Comment

Copy the text below into the Jira ticket comment field.

---

**Tyk Pump ECS Implementation — Progress Update**

**Status:** Implementation complete; ready for pipeline validation and testing.

**Summary of work completed:**

Tyk Pump has been implemented as a second ECS Fargate service within the existing `ecs-app-deployer` repository, alongside the Tyk Gateway service. The implementation follows the same deployment patterns established by the Gateway ECS PoC (CloudFormation via Service Catalog, SSM secret fetch at container start, CloudWatch logging).

**Key design decisions:**

- Pump runs as a separate ECS service on the shared `tyk-cluster`, without an Application Load Balancer.
- The runtime image uses the Barclays UBI8 Pump base image (from `tyk-pump-docker-image`), not the Tyk vendor image directly.
- A thin wrapper Dockerfile adds SSM secret fetch capability (Redis password only).
- Container health check uses HTTP `:8083/health` (ECS container health check, not ALB).
- Redis endpoint, cluster mode, security group, CPU/memory, log level, and base image are all parameterised as pipeline runtime inputs.
- Gateway and Pump deployments are independently toggled via `deploy_gateway` and `deploy_pump` flags, matching the pattern used in the EKS Helm deployer.
- Observability uses CloudWatch (Observe-ready). An optional pipeline job creates CloudWatch subscription filters for Observe when the customer supplies their Kinesis destination ARN.
- ESaaS/Filebeat dependencies are not introduced for the new ECS Pump service.

**Files added to `ecs-app-deployer`:**

- `pump/Dockerfile` — Pump ECS wrapper image
- `pump/entrypoint.sh` — SSM secret fetch for Redis password
- `infra-pump/product.template.yaml` — Pump CloudFormation template
- `infra-pump/metadata.yaml` — Product metadata
- `infra-pump/dev/deploy-stack.yaml` — Dev deployment parameters
- `infra-pump/dev/provision-product.yaml` — Dev provisioning parameters

**File updated:**

- `gitlab-ci.yml` — Added `spec.inputs` for runtime parameters, optional Pump build/deploy jobs, and optional Observe subscription filter job.

**Pipeline parameters added:**

- `deploy_gateway` / `deploy_pump` — component toggle flags
- `pump_base_image` — Barclays UBI8 Pump image tag
- `pump_friendly_stack_name` — Pump stack name
- `pump_task_cpu` / `pump_task_memory` — Fargate sizing
- `pump_redis_endpoint` / `pump_redis_enable_cluster` / `pump_redis_security_group_id` — Redis configuration
- `pump_log_level` — runtime log level
- `enable_observe` / `observe_kinesis_destination_arn` / `observe_filter_pattern` — optional Observe integration

**Sizing:**

- PoC: 512 CPU / 1024 MiB (matches current Gateway ECS PoC)
- Helm EKS reference: 1000m request / 1024Mi request, 1500m limit / 2048Mi limit
- Pump and Gateway are sized identically in the Helm Data Plane config; ECS can be scaled up via pipeline parameters.

**Outstanding items:**

- SSM/Lambda population path remains a known issue (manual SSM entry for PoC; troubleshooting deferred).
- Pump base image tag (`1.16.0.291`) must be confirmed in Nexus before first pipeline run.
- Observe account onboarding (Kinesis ARN, IFE/non-IFE, SES roles, ITSI) is customer responsibility and is not automated by this pipeline.
- Prod Redis configuration uses `clustercfg.*` with `ENABLECLUSTER=true`; non-prod uses `master.*` with `ENABLECLUSTER=false`.

**Deliverables produced:**

- ECS Pump deployment code (in `ecs-app-deployer`)
- ECS Data Plane Readiness Assessment (in docs)
- Tyk Pump ECS Deployment Guide (in docs)
- Review and Testing Checklist (in docs)
- GitLab Runbook for customers (in docs)

**Next steps:**

1. Validate Pump base image exists in Nexus.
2. Run pipeline with `deploy_pump=true` in dev.
3. Verify ECS service health and CloudWatch logs.
4. Complete Observe onboarding for the target account (customer responsibility).
5. Optionally rerun pipeline with `enable_observe=true` and Kinesis ARN.
