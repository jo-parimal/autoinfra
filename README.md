# AutoInfra (Current State)

AutoInfra is a practical DevOps demo project that provisions AWS infrastructure and deploys 3 Spring Boot microservices using GitHub Actions.

This README is focused on the **current repository state**, what is already implemented, what still needs verification, and where contributors can improve the project.

---

## 1) What this project currently does

- Provisions infrastructure with Terraform:
  - EC2 app host
  - PostgreSQL RDS
  - Security group + key pair
- Builds and deploys microservices via GitHub Actions.
- Deploys services as `systemd` units on EC2.
- Runs post-deploy health checks (SSH, DB reachability, service/process checks, HTTP checks).

### Services

- `user-service` → `:8081` (`/users`)
- `product-service` → `:8082` (`/products`)
- `order-service` → `:8083` (`/orders`)

---

## 2) Repository structure

```text
.
├── .github/workflows/
│   ├── infra.yml            # manual infra provisioning + secret setup
│   └── build-deploy.yml     # build/deploy on push to main
├── services/
│   ├── user-service/
│   ├── product-service/
│   └── order-service/
├── scripts/
│   ├── deploy_services.sh   # copies jars + sets systemd + env
│   └── health_check.sh      # post-deploy validation
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
└── config/
    └── services.yaml
```

---

## 3) CI/CD workflow behavior

### A) Infra workflow (`infra.yml`)
- Trigger: **manual** (`workflow_dispatch`)
- Inputs:
  - `db_password` (required)
  - `db_user` (default: `infraadmin`)
  - `aws_region` (default: `ap-south-1`)
- Actions:
  1. Generates SSH keypair on runner
  2. Runs `terraform init` + `terraform apply`
  3. Captures outputs and writes repository secrets

### B) Build/deploy workflow (`build-deploy.yml`)
- Trigger: push to `main`
- Actions:
  1. Validates required secrets
  2. Builds all Java services
  3. Recreates private key from secret
  4. Runs deploy script
  5. Runs health-check script

---

## 4) Required repository secrets

### For infra workflow
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `GH_PAT`

### Produced/used for deploy workflow
- `EC2_IP`
- `EC2_SSH_KEY_BASE64`
- `DB_ENDPOINT`
- `DB_USER`
- `DB_PASSWORD`

---

## 5) What changed recently (current implementation)

- Added DB user/password propagation in workflow and deployment script.
- Added input-driven infra workflow (`db_password`, `db_user`, `aws_region`).
- Added deploy prechecks for missing secrets.
- Added deterministic service-to-port mapping in deploy script.
- Added `.env`-based runtime datasource config for systemd services.
- Added post-deploy health checks script.
- Added SG rule to allow Postgres traffic within app security group.

---

## 6) If you cannot test right now (recommended next steps)

If you are not able to run AWS/deployment tests immediately, do this in order:

1. **Static checks first**
   - Validate shell scripts syntax (`bash -n scripts/*.sh`)
   - Validate workflow YAML formatting/syntax in CI/linter
2. **Dry validation**
   - Run Terraform `fmt` and `validate` locally where Terraform is installed
3. **Small controlled deploy**
   - Run infra workflow in a sandbox AWS account
   - Run one push to `main` and inspect deployment logs
4. **Confirm runtime**
   - Verify `systemctl status` for all 3 services
   - Call `/users`, `/products`, `/orders`

---

## 7) Known limitations and improvement ideas

These are good next issues for contributors:

1. Split security groups (`app_sg` and `db_sg`) for least-privilege DB ingress.
2. Put services behind ALB + HTTPS.
3. Add DB migrations (Flyway/Liquibase).
4. Add rollback strategy on failed health checks.
5. Add integration tests and smoke tests in CI.
6. Replace PAT usage with tighter scoped auth where possible.
7. Add observability stack (structured logs, metrics, alerts).

---

## 8) Troubleshooting quick guide

- Deploy step fails quickly:
  - Check required secrets exist and are non-empty.
- SSH failures:
  - Verify `EC2_IP`, key secret value, and security group SSH CIDR.
- Service starts but DB errors:
  - Verify `DB_ENDPOINT`, `DB_USER`, `DB_PASSWORD` consistency with RDS.
- Health checks fail on HTTP:
  - Check service process status and open ports on EC2.

---

## 9) For LinkedIn / portfolio usage

You can describe this as:

> Built an AWS-based CI/CD deployment pipeline for Java microservices using Terraform and GitHub Actions, including infra provisioning, secrets wiring, automated EC2 deployment, and post-deploy health verification.

---

## 10) Contribution note

PRs/issues for improvements are welcome.

When proposing fixes, please include:
- What problem is being solved
- Why the current behavior is risky/suboptimal
- How you validated the change

