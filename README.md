# AutoInfra

AutoInfra is a reference microservices + infrastructure project that demonstrates how to provision cloud infrastructure with Terraform and deploy multiple Spring Boot services onto a single EC2 host, backed by PostgreSQL (RDS).

This README is intentionally practical: it explains architecture, runtime request flow, how to change the project safely as a user, and how to propose future changes for collaborators.

---

## 1) What this project contains

- **Three Java microservices (Spring Boot 3.1.6, Java 17):**
  - `user-service` (port 8081, `/users`)
  - `product-service` (port 8082, `/products`)
  - `order-service` (port 8083, `/orders`)
- **Shared persistence pattern:** each service uses Spring Data JPA + PostgreSQL.
- **Terraform IaC:** provisions EC2, security group, key pair, and PostgreSQL RDS.
- **Operational scripts:** deployment and health-check shell scripts for EC2-based runtime.

Repository layout:

```text
.
├── config/
│   └── services.yaml
├── scripts/
│   ├── deploy_services.sh
│   ├── health_check.sh
│   └── systemd-unit-template.service
├── services/
│   ├── user-service/
│   ├── product-service/
│   └── order-service/
└── terraform/
    ├── main.tf
    ├── variables.tf
    └── terraform.tfvars.example
```

---

## 2) Architecture overview

### 2.1 Infra architecture (AWS)

Terraform provisions:

1. **AWS Key Pair** from local public key (`public_key_path`).
2. **Security Group** allowing:
   - SSH (`22/tcp`) from configurable CIDR (`ssh_cidr`)
   - App ports (`8081-8099/tcp`) from `0.0.0.0/0`
   - PostgreSQL (`5432/tcp`) within the same security group (`self = true`)
3. **One EC2 instance** for running all three service JARs as `systemd` services.
4. **One PostgreSQL RDS instance** used by all services.

### 2.2 Application architecture

Each service follows the same layer pattern:

- **Controller** (REST endpoints)
- **Service** (business logic / DTO mapping)
- **Repository** (JPA data access)
- **Entity + DTO** (persistence and API model)

All services are currently **independent CRUD-style services** and do **not call each other** directly.

### 2.3 Data model (current)

- `user-service`: `User(id, name, email)`
- `product-service`: `Product(id, name, price)`
- `order-service`: `Order(id, userId, productId, quantity)`

> Note: `order-service` stores foreign IDs (`userId`, `productId`) as plain fields and does not currently validate existence against user/product services.

---

## 3) Runtime flow

### 3.1 Provisioning flow

1. Fill `terraform/terraform.tfvars` from example.
2. Run Terraform (`init/plan/apply`).
3. Capture outputs:
   - `ec2_public_ip`
   - `db_endpoint`

### 3.2 Build + deploy flow

1. Build each service with Maven to produce JARs under `services/*/target`.
2. Run `scripts/deploy_services.sh <EC2_IP> <PEM_PATH> [DB_HOST]`.
3. Script copies JARs, creates per-service directories in `/opt/services/<service>`, writes systemd unit files, enables + restarts services.

### 3.3 Health verification flow

1. Run `scripts/health_check.sh <EC2_IP> <PEM_PATH> [DB_ENDPOINT]`.
2. Script checks:
   - SSH connectivity
   - Optional DB TCP reachability from EC2
   - systemd active status for each service
   - Port listening checks
   - HTTP 200 on `/users`, `/products`, `/orders`

---

## 4) Local development guide

## Prerequisites

- Java 17
- Maven 3.8+
- PostgreSQL (or reachable Postgres endpoint)
- Terraform 1.x
- AWS credentials configured for Terraform

### Build all services

```bash
cd services/user-service && mvn clean package
cd ../product-service && mvn clean package
cd ../order-service && mvn clean package
```

### Run services locally

In separate terminals:

```bash
cd services/user-service && mvn spring-boot:run
cd services/product-service && mvn spring-boot:run
cd services/order-service && mvn spring-boot:run
```

Each service supports env overrides:

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `SERVER_PORT`

### Quick API smoke test

```bash
# users
curl -X POST http://localhost:8081/users -H 'Content-Type: application/json' -d '{"name":"Alice","email":"alice@example.com"}'
curl http://localhost:8081/users

# products
curl -X POST http://localhost:8082/products -H 'Content-Type: application/json' -d '{"name":"Keyboard","price":59.99}'
curl http://localhost:8082/products

# orders
curl -X POST http://localhost:8083/orders -H 'Content-Type: application/json' -d '{"userId":1,"productId":1,"quantity":2}'
curl http://localhost:8083/orders
```

---

## 5) Infra setup and deployment

### Step A: Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

Collect outputs:

```bash
terraform output ec2_public_ip
terraform output db_endpoint
```

### Step B: Deploy services to EC2

From repository root:

```bash
./scripts/deploy_services.sh <EC2_PUBLIC_IP> <PATH_TO_PEM> <DB_ENDPOINT>
```

### Step C: Validate deployment

```bash
./scripts/health_check.sh <EC2_PUBLIC_IP> <PATH_TO_PEM> <DB_ENDPOINT>
```

---

## 6) How users should make changes safely

Use this checklist whenever modifying this project.

### 6.1 Change APIs or models

When you add or change fields in `Entity`/`Dto`:

1. Update `entity`, `dto`, `service`, and `controller` consistently.
2. Add request/response validation (recommended next step: Bean Validation annotations).
3. Add tests before deployment.
4. Run local smoke tests for affected endpoints.

### 6.2 Change infrastructure

When changing Terraform:

1. Always run `terraform fmt` and `terraform validate`.
2. Review `terraform plan` output carefully for destructive operations.
3. Restrict `ssh_cidr` and app ingress for non-demo environments.
4. Prefer remote state + state locking for team usage.

### 6.3 Change deployment behavior

If updating deployment scripts:

1. Keep script idempotency (safe to rerun).
2. Ensure systemd units still restart and persist on reboot.
3. Keep secrets out of shell history and source control.
4. Validate with `health_check.sh` after every deploy.

---

## 7) Future improvements roadmap

High-impact next changes:

1. **Service-to-service validation for orders**
   - verify `userId` and `productId` before storing orders.
2. **API gateway + load balancer**
   - expose one public entry point (ALB + path routing).
3. **Containerization**
   - Dockerfiles + ECS/EKS or at least Docker Compose for local parity.
4. **Observability**
   - structured logging, central log aggregation, metrics, tracing.
5. **CI/CD pipeline**
   - build/test/deploy automation with staged environments.
6. **Security hardening**
   - private subnets, least privilege IAM, Secrets Manager/SSM.
7. **Database migration tooling**
   - Flyway/Liquibase instead of relying on `ddl-auto=update`.
8. **Contract and integration testing**
   - protect service interfaces and cross-service assumptions.

---

## 8) Collaboration and change request process

When asking someone else to implement a change, give enough context that they can start without guessing.

### Why this matters

A clear request helps reviewers and implementers quickly understand:

- what problem is being solved
- what is in/out of scope
- how to know when the work is done

This reduces back-and-forth, avoids missed requirements, and makes PR reviews much faster.

### Use this request format

Copy this block and fill it in before assigning work:

```text
Change Request:
- Goal:
- Scope (files/services):
- API or schema impact:
- Infra impact:
- Backward compatibility requirement:
- Test cases expected:
- Definition of done:
```

### What each field should contain

- **Goal:** One short sentence describing the business or technical outcome.
- **Scope (files/services):** Exactly which service(s), folder(s), or files can be changed.
- **API or schema impact:** Any endpoint/contract/database changes and whether clients are affected.
- **Infra impact:** Terraform, networking, IAM, secrets, or deployment changes required.
- **Backward compatibility requirement:** Explicitly state if old clients/workflows must continue working.
- **Test cases expected:** Minimum tests or checks required before merge (unit, integration, smoke tests).
- **Definition of done:** Clear acceptance criteria in plain language.

### Example (good request)

```text
Change Request:
- Goal: Ensure orders cannot be created with non-existent userId/productId.
- Scope (files/services): services/order-service only (controller/service layer + tests).
- API or schema impact: Keep request/response shape unchanged; return 400 for invalid IDs.
- Infra impact: None.
- Backward compatibility requirement: Existing valid order creation flow must remain unchanged.
- Test cases expected: Unit tests for validation logic + API test for 400/201 behavior.
- Definition of done: Invalid user/product IDs are rejected, tests pass, README updated if behavior changes.
```

### PR expectations for contributors

- Keep PRs focused and small where possible.
- Include:
  - summary of behavior change
  - migration/deployment notes (if any)
  - test evidence
  - rollback notes for infra or runtime changes
- Update README when architecture or operational flow changes.

---

## 9) Current limitations (important)

- No authentication/authorization.
- No rate limiting or gateway.
- No centralized config/secrets manager.
- Limited test coverage in repository.
- Open app ports in SG are demo-friendly, not production-safe by default.

---

## 10) License / usage

No explicit license file is currently present in this repository. Add a `LICENSE` file before distributing for external/public reuse.
