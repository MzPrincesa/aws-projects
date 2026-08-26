# 6.15 Security Validation — inner-circle Project

**Project:** inner-circle
**AWS Account:** 343218184480
**Region:** us-east-1
**Document date:** 2026-08-26
**Owner:** MzPrincesa

---

## 1. Purpose

This document is the final security review of the `inner-circle` project, consolidating findings, remediations, and accepted risks from steps 6.1 through 6.14. It is intended to give an accurate, honest picture of the project's security posture — what was hardened, what was explicitly deferred, and why — rather than claiming a perfect state that doesn't exist.

---

## 2. Architecture summary

`inner-circle` is a containerized Node.js/Express REST API backed by DynamoDB, running on ECS Fargate inside a private VPC subnet, fronted by an internet-facing Application Load Balancer. All AWS service communication from the private subnets happens via VPC endpoints rather than a NAT gateway, minimizing internet egress paths. Infrastructure is fully defined in Terraform and deployed via a GitHub Actions CI/CD pipeline using OIDC federation (no long-lived AWS credentials in CI).

---

## 3. Security controls implemented, by category

### Network isolation (6.1–6.6)
- Custom VPC (10.0.0.0/16) with public and private subnets across two AZs
- ECS Fargate tasks run exclusively in private subnets with no public IP assignment
- Security groups scoped to minimum required paths: ALB (0.0.0.0/0:80) → Fargate task (3000, ALB-SG-only) → VPC endpoints (443, Fargate-SG-only)
- Six VPC endpoints (S3, DynamoDB, ECR API, ECR DKR, CloudWatch Logs, Secrets Manager) eliminate the need for a NAT gateway for AWS service traffic

### Container image hardening (6.7)
- Migrated from a full `node:24.14.0` Debian image to a multi-stage build on `node:24.19.0-slim`, eliminating an entire class of unrelated OS packages (image processing libraries, build toolchain, database clients) that had no relationship to the application
- Reduced CRITICAL Inspector findings from 200+ to 3
- Container runs as non-root user (`node`) with explicit file ownership (`--chown`)
- Registry-wide enhanced scanning enabled with continuous scan frequency

**Remaining accepted risk:** 3 unpatched Perl CVEs (CVE-2026-13221, CVE-2026-57433, CVE-2026-12087) with no upstream fix available at time of writing. Full rationale documented in the 6.7 security documentation — low EPSS scores (<0.5%), no known exploits, not reachable through the application's attack surface (app never invokes Perl), and mitigated by non-root execution and no exposed shell access.

### IAM least privilege (6.8)
- Task role and execution role kept strictly separate: execution role handles only ECR pull, CloudWatch Logs, and Secrets Manager read; task role handles only application-level DynamoDB access
- DynamoDB policy trimmed to the three actions the application code actually uses (`GetItem`, `PutItem`, `Scan`) rather than the original six-action policy that included unused `UpdateItem`, `DeleteItem`, and `Query` permissions

### Secrets management (6.9)
- Application secrets stored in AWS Secrets Manager, injected into the container via the ECS `secrets` block rather than plaintext environment variables
- Execution role scoped to read exactly one secret ARN, not a broader namespace
- **Lesson learned:** the private-subnet architecture from 6.4 initially lacked a VPC endpoint for Secrets Manager, causing task launch failures (`ResourceInitializationError`, connection timeout) until the endpoint was added. This is now corrected and documented as a reminder that new AWS service dependencies require corresponding endpoint coverage.

### HTTPS / TLS (6.10) — **Deferred**
- Not implemented. ACM cannot issue certificates for AWS's auto-generated ALB DNS names, and no custom domain was registered for this project (a deliberate cost decision for a learning project).
- **Accepted risk:** traffic to the ALB currently travels over plain HTTP. This is acceptable for a demo/learning project with no real user data; it would be a hard blocker before any production use.

### ALB hardening (6.11)
- Deletion protection enabled
- Invalid HTTP header fields dropped at the load balancer
- Access logging enabled to a dedicated, least-privilege-scoped S3 bucket, verified receiving real log data

### Autoscaling (6.12)
- Target tracking scaling on both CPU (60%) and memory (70%), min 1 / max 3 tasks, asymmetric cooldowns (fast scale-out, slow scale-in) to avoid flapping under bursty load

### Infrastructure as Code (6.13)
- Entire infrastructure (networking, IAM, ECS, ALB, Secrets Manager, autoscaling, ECR) imported into Terraform with verified zero configuration drift
- Remote state stored in a versioned, encrypted, public-access-blocked S3 bucket with native S3 state locking

### CI/CD pipeline (6.14)
- GitHub Actions authenticates to AWS via OIDC federation — no static AWS access keys stored in GitHub
- Trust policy scoped to this specific repository using GitHub's immutable subject claim format (owner ID + repo ID), which is resistant to repository name recycling/hijacking attacks
- Pipeline separates `plan` (runs on every PR, read-only preview) from `apply` (runs only on merge to `main`), giving a review checkpoint before any real infrastructure change

**Accepted risk:** the CI role's permissions policy (`InnerCircleGithubActionsDeploy`) is broader than the application-level IAM policies from 6.8 — it needs read/write access across ECS, ALB, IAM (scoped to the two specific roles/policy this project uses), Secrets Manager (scoped to the one secret), S3 (scoped to the two specific buckets), and ECR. This is a known, common tradeoff: a deployment role that manages infrastructure inherently needs broader permissions than an application role that only serves requests. It is not scoped to `*` on every service — resource-level scoping is used everywhere AWS's API supports it (IAM roles/policy, Secrets Manager, S3 buckets). Full least-privilege scoping of a Terraform CI role (down to individual actions per resource type) is a larger, ongoing exercise noted here as a future improvement rather than a gap introduced carelessly.

---

## 4. Summary table — accepted risks

| Item | Risk | Mitigation | Status |
|---|---|---|---|
| 3 Perl CVEs in container base image | CRITICAL CVSS, but <0.5% EPSS, no known exploits, not reachable via app | Non-root execution, no exposed shell, documented and monitored | Accepted |
| No HTTPS/TLS on ALB | Traffic unencrypted in transit | No real user data in this project; would block production use | Deferred, documented |
| CI role has broad (but resource-scoped) permissions | Larger blast radius than app-level roles if CI credentials were ever compromised | OIDC federation (no static keys), resource-level ARN scoping where AWS supports it | Accepted, known tradeoff |

---

## 5. Verification evidence

- ECR Inspector scan history: 200+ → 8 → 3 CRITICAL findings across image tags 2.0 → 3.0 → 4.0
- `terraform plan` returns `No changes` across all resource layers as of the final CI run on 2026-08-26
- ALB access logs confirmed writing real request data to S3
- ECS service health checks passing (`HEALTHY` status) on current task definition revision
- End-to-end CI/CD pipeline verified: OIDC auth → Docker build/push → `terraform plan` on PR → `terraform apply` on merge, all completed successfully

---

## 6. Sign-off

This project demonstrates a defense-in-depth approach across network isolation, container hardening, least-privilege IAM, secrets management, and infrastructure-as-code — with honest documentation of the items that were deferred or accepted rather than silently omitted. All deferred/accepted items are re-evaluable: HTTPS can be added once a domain is acquired; the Perl CVEs are being tracked against upstream fix availability; the CI role's permissions can be progressively tightened as a follow-up exercise.

**Reviewed by:** MzPrincesa
**Date:** 2026-08-26