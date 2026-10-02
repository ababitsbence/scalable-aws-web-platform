# Scalable AWS Web Platform

[![Terraform CI](https://github.com/ababitsbence/scalable-aws-web-platform/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/ababitsbence/scalable-aws-web-platform/actions/workflows/terraform-ci.yml)

A production-style AWS infrastructure project built entirely in Terraform: a VPC with public and private tiers, a load-balanced and auto-scaled application layer, a bastion host for controlled SSH access, and a container registry, all wired together with least-privilege security groups and IAM roles.

## About The Project

This project provisions a small but realistic web platform on AWS, the kind of network and compute layout a real production service would sit behind. A minimal Express app is included as the sample workload, but the actual subject of this project is the infrastructure around it: network segmentation, controlled ingress, autoscaling, and IAM-based access to a container registry, rather than the application itself.

### Core Features

- VPC with distinct public and app subnet tiers, spread across multiple availability zones
- Application servers behind a Network Load Balancer, running as an Auto Scaling Group
- Bastion host as the only SSH entry point, reachable exclusively from a configured admin IP
- Least-privilege security groups: the app tier is only reachable from the NLB and the bastion, never directly from the internet
- Application and bastion AMIs are resolved dynamically to the latest Amazon Linux 2023 image at apply time, rather than pinned to a fixed, aging AMI ID
- IAM role granting app servers pull-only access to a private ECR repository, no long-lived credentials on the instances
- Fully defined as code with Terraform, modularized by concern (`vpc`, `security`, `iam`, `ecr`, `compute`, `nlb`, `bastion`)

### Architecture

![Architecture diagram](./docs/architecture/architecture.png)

The editable diagram source is at `docs/architecture/architecture.drawio` ([draw.io](https://app.diagrams.net)).

**Traffic flow:** the internet reaches the app tier only through the Network Load Balancer; the only path to SSH into anything is through the bastion host, and only from the configured admin IP; app servers pull their container image from ECR at boot, authorized by an attached IAM role rather than stored credentials.

## Built With

- **Infrastructure:** Terraform, AWS (VPC, EC2, Auto Scaling, Network Load Balancer, ECR, IAM)
- **Sample application:** Node.js, Express, Docker
- **Diagramming:** draw.io

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) (CLI)
- An AWS account with credentials configured locally (`aws configure`)
- [Docker](https://www.docker.com/), for building and pushing the app image
- An SSH key pair for bastion access (see step 2 below)

> **Cost warning:** running `terraform apply` creates real, billable AWS resources (EC2 instances, a Network Load Balancer, a NAT Gateway, and others). Run `terraform destroy` when you're done to avoid ongoing charges.

## How to Run

### 1. Configure your variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Fill in your own values:

| Variable | Description |
|---|---|
| `project_name` | Prefix used for naming every resource this creates |
| `ecr_repo_name` | Name for the ECR repository that will be created |
| `admin_ip` | Your own public IP, in CIDR form (e.g. `["203.0.113.10/32"]`), the only address allowed to SSH into the bastion |
| `aws_region` | Defaults to `eu-west-3`, override if you want a different region |
| `instance_type` | Defaults to `t3.micro` |

### 2. SSH key pair

Terraform generates a dedicated ED25519 key pair for bastion access automatically as part of `terraform apply`, the private key is written to `terraform/bastion-key` (gitignored, never committed). No manual key generation is needed.

### 3. Create the ECR repository first

The application servers pull their image from ECR at boot, so the repository has to exist, and the image has to be pushed, before the rest of the infrastructure comes up:

```bash
terraform init
terraform apply -target=module.ecr
```

### 4. Build and push the app image

```bash
cd ../app
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com

docker build -t <your-ecr-repo-name> .
docker tag <your-ecr-repo-name>:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/<your-ecr-repo-name>:latest
docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/<your-ecr-repo-name>:latest
```

### 5. Provision the rest of the infrastructure

```bash
cd ../terraform
terraform apply
```

Review the plan output before confirming, since this stage creates the VPC, load balancer, autoscaled app servers, and bastion host.

### 6. Connect to the bastion (optional)

```bash
ssh -i bastion-key ec2-user@<bastion-public-ip>
```

The bastion's public IP is available in the `terraform apply` output.

### 7. Tear it down

```bash
terraform destroy
```

## Validating the Infrastructure

Before applying changes, check formatting and validity:

```bash
cd terraform
terraform fmt -check
terraform validate
```

These same checks, plus TFLint and a Checkov security scan, run automatically on every push via [GitHub Actions](.github/workflows/terraform-ci.yml).

## Security Scan Findings

Checkov runs on every push (see CI badge above), scoped against `terraform.tfvars.example` so variable-dependent checks resolve correctly. 22 findings remain, all reviewed:

**Intentional design decisions:**
- **Bastion has a public IP** (`CKV_AWS_88`): required for its role as the sole SSH entry point, access is restricted to a single admin IP via security groups.
- **Bastion has no IAM role** (`CKV2_AWS_41`): it needs no AWS API access; attaching one would violate least-privilege rather than improve it.
- **NLB is reachable on plain HTTP** (`CKV_AWS_260`): the intended entry point for this project's sample workload; HTTPS requires a domain and ACM certificate, see roadmap.
- **Public subnets auto-assign public IPs** (`CKV_AWS_130`): required for the bastion and NAT gateway to function.
- **ECR tags are mutable** (`CKV_AWS_51`): the current deploy model pulls `:latest` at boot. Switching to immutable, versioned tags with an ASG instance refresh for rollout is on the roadmap.
- **Detailed EC2 monitoring is disabled** (`CKV_AWS_126`): a cost tradeoff appropriate for a project torn down between uses via `terraform destroy`.
- **Load balancer deletion protection is disabled** (`CKV_AWS_150`): intentionally, so `terraform destroy` works without a manual unlock step.
- **Security group egress is unrestricted** (`CKV_AWS_382`): a common simplification; a stricter, explicit egress allowlist is on the roadmap.
- **ECR uses AWS-managed encryption, not a customer-managed KMS key** (`CKV_AWS_136`): default encryption at rest already applies; a CMK is an optional hardening step with added operational overhead.
- **The `db` security group has no attached resource** (`CKV2_AWS_5`, explicitly skipped inline): reserved for a future RDS instance, not yet provisioned.

**Scanner limitations, not real issues:**
- **`CKV2_AWS_5` on `bastion`, `app`, and `nlb`**: each is genuinely attached via a module-passed security group ID, Checkov's static analysis doesn't trace attachment across module boundaries in this version.

## Project Structure

```
scalable-aws-web-platform/
├── app/                Sample Express workload, containerized
├── terraform/
│   ├── main.tf         Wires all modules together
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/        Network: subnets, route tables, NAT
│       ├── security/   Security groups, least-privilege rules
│       ├── iam/        EC2 role with ECR pull access
│       ├── ecr/        Container registry
│       ├── compute/    Auto Scaling Group, launch template
│       ├── nlb/        Network Load Balancer
│       └── bastion/    Bastion host
├── docs/
│   └── architecture/   Architecture diagram (source + exported image)
└── README.md
```

## Roadmap / Future Improvements

- [ ] HTTPS via ACM certificate and HTTP→HTTPS redirect (`CKV2_AWS_20`)
- [ ] VPC flow logging to CloudWatch (`CKV2_AWS_11`)
- [ ] NLB access logging to S3 (`CKV_AWS_91`)
- [ ] Explicit, restrictive egress rules instead of allow-all (`CKV_AWS_382`)
- [ ] Automated image build-and-push step, rather than the manual Docker steps above
- [ ] NAT Gateway per availability zone, instead of a single shared one, for higher availability
- [ ] Automated tests for the sample application

## License

This project was built as a personal portfolio piece and is not licensed for production use.