---
id: kata-400
title: "Three-Tier Web App — CloudFront, ALB, EC2 & RDS in Multi-AZ"
level: 400
type: breadth
services:
  - cloudfront
  - elb
  - ec2
  - rds
  - vpc
tags:
  - cloudfront
  - alb
  - ec2
  - rds
  - vpc
  - auto-scaling
  - multi-az
  - breadth
  - advanced
estimated_time: 3 hours
estimated_cost: "$5.00 - $15.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-400 — Three-Tier Web App: CloudFront, ALB, EC2 & RDS in Multi-AZ

## Overview

In this kata you will build a production-pattern three-tier web application.
A custom VPC spans multiple Availability Zones with public and private
subnets. An Application Load Balancer in the public tier distributes traffic
to an Auto Scaling group of EC2 instances in the private tier. Those
instances connect to a Multi-AZ RDS database in an isolated data tier.
CloudFront sits in front of the ALB as the CDN and edge layer.

The validator checks that each tier is correctly provisioned, that
Multi-AZ requirements are met, and that the tiers are wired together with
least-privilege security group access — no tier reaches further than the
tier directly behind it.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage VPC, EC2, Auto Scaling, Elastic Load
  Balancing, RDS, and CloudFront resources
- Familiarity with the AWS Console and CLI at an intermediate-to-advanced
  level
- Comfort reading and reasoning about route tables, security groups, and
  subnet association — this kata assumes you already know VPC and EC2
  fundamentals (see kata-104 and kata-108 if you need a refresher first)

> ℹ️ **Recommended region:** any commercial region with at least 3
> Availability Zones. CloudFront is a global service and is not
> region-scoped.

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~3 hours |
| 💰 Estimated Cost | ~$5.00 – $15.00 |

> ⚠️ **Cost Warning:** This kata is one of the most expensive in the
> library. It provisions an Application Load Balancer (hourly + LCU
> charges), EC2 instances running continuously, a **Multi-AZ RDS instance**
> (which bills for two database instances, not one), and a CloudFront
> distribution. If you add NAT Gateways for private-subnet internet access,
> those bill hourly plus per-GB data processed and are often the single
> largest line item in a VPC of this shape. These are estimates only —
> actual costs depend on your region, account tier, traffic volume, and how
> quickly you complete and clean up the kata. Keep instance sizes minimal
> (`t3.micro` / `db.t3.micro`) and **never leave this stack running longer
> than your session.** All charges are your responsibility. Always run the
> cleanup instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-400-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — VPC & Subnetting

Create a VPC named `kata-400-VPC`. The VPC must contain:

- Public subnets in **at least 2 distinct Availability Zones**, each with a
  route to an Internet Gateway
- Private subnets in **at least 2 distinct Availability Zones**, with no
  direct route to the internet

Instances in the private subnets must still be able to reach the internet
to download software updates and patches, without being directly reachable
from it. Outbound-only internet access for the private tier is a hard
requirement — a private subnet with no outbound path at all does not satisfy
this kata.

The subnet layout must be sufficient to support an internet-facing load
balancer in the public tier and an Auto Scaling group and database in the
private tier, each spanning multiple AZs.

---

### Requirement 2 — Security Groups

Create security groups that enforce tier-to-tier access only — no tier may
be reachable by anything other than the tier directly in front of it:

- The ALB's security group must accept inbound web traffic from the public
  internet
- The EC2 tier's security group must accept inbound application traffic
  **only** from the ALB's security group — not from the internet directly
- The database's security group must accept inbound traffic **only** from
  the EC2 tier's security group — not from the internet, and not directly
  from the ALB

---

### Requirement 3 — Application Load Balancer

Create an internet-facing Application Load Balancer named `kata-400-ALB`.

- The load-balancing tier must survive the loss of a single Availability
  Zone without an outage — this means the ALB must be placed in public
  subnets spanning **at least 2 Availability Zones**, not one
- It must forward traffic to a target group associated with the EC2 Auto
  Scaling group (Requirement 4)
- The target group's health check must be passing for at least one
  registered target before this requirement is considered met

---

### Requirement 4 — EC2 Auto Scaling Group

Create an Auto Scaling group named `kata-400-ASG` that launches EC2
instances into the private subnets.

- The compute tier must survive the loss of a single Availability Zone —
  instances must be distributed across **at least 2 Availability Zones**
- The group must maintain a minimum of 2 running instances at all times
- Instances must be attached to the ALB's target group and reach a healthy
  state
- Use `t3.micro` — this kata does not require compute capacity, only correct
  wiring

---

### Requirement 5 — RDS Database (Multi-AZ)

Create an RDS database instance named `kata-400-DB`.

- The data tier must survive the loss of a single Availability Zone without
  data loss or manual failover — Multi-AZ deployment must be enabled, giving
  the database a synchronously replicated standby in a second Availability
  Zone
- The instance must use a DB subnet group containing only private subnets,
  spanning at least 2 Availability Zones
- The instance must **not** be publicly accessible
- Use `db.t3.micro` — this kata does not require database capacity, only
  correct Multi-AZ and network configuration
- The instance must reach `available` status

---

### Requirement 6 — CloudFront Distribution

The platform needs an edge caching and delivery layer in front of the
load-balancing tier, rather than serving every request straight from the
ALB. Create a CloudFront distribution with `kata-400-ALB` configured as its
origin.

- The distribution must reach `Deployed` status
- Viewer traffic must be redirected to HTTPS (`redirect-to-https` viewer
  protocol policy)
- The origin protocol policy must match how the ALB serves traffic

---

### Requirement 7 — End-to-End Integration

All three tiers must be wired together as a cohesive, correctly isolated
architecture:

- Every instance in `kata-400-ASG` must be a healthy, registered target
  behind `kata-400-ALB`
- The CloudFront distribution's origin domain must match the DNS name of
  `kata-400-ALB`
- `kata-400-DB` must be reachable only from resources using the EC2 tier's
  security group — no broader ingress path may exist
- No security group in the stack may permit unrestricted inbound access to
  the EC2 or database tiers from `0.0.0.0/0`

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and
upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure and reports a score.
A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-400
 Three-Tier Web App: CloudFront, ALB, EC2 & RDS in Multi-AZ
==================================================

✅ PASS — VPC 'kata-400-VPC' exists with public/private subnets across 2+ AZs
✅ PASS — Public subnets route to an Internet Gateway
✅ PASS — Private subnets have no direct internet route
✅ PASS — Security groups enforce tier-to-tier access only
✅ PASS — ALB 'kata-400-ALB' is internet-facing and spans 2+ public AZs
✅ PASS — Target group has at least one healthy target
✅ PASS — Auto Scaling group 'kata-400-ASG' spans 2+ private AZs with 2+ instances
✅ PASS — ASG instances are healthy targets behind the ALB
✅ PASS — RDS instance 'kata-400-DB' is Multi-AZ and available
✅ PASS — RDS subnet group is private and spans 2+ AZs
✅ PASS — RDS instance is not publicly accessible
✅ PASS — CloudFront distribution is Deployed with 'kata-400-ALB' as origin
✅ PASS — CloudFront enforces HTTPS on viewer traffic

==================================================
 Results: 13/13 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-400 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. This kata spans four
services with real hourly and per-GB charges — follow the steps in order to
avoid orphaned dependencies that block deletion or leave you paying for
idle infrastructure.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-400-solution
aws cloudformation wait stack-delete-complete --stack-name kata-400-solution
```

> ⚠️ CloudFront distributions must be **disabled before they can be
> deleted**, and disabling can take several minutes to propagate. If your
> stack deletion stalls on the CloudFront resource, this is expected —
> CloudFormation will wait for the distribution to finish disabling before
> it can be removed.

### Step 2 — Manual cleanup

If you created any resources manually via the console or CLI, it is your
responsibility to delete them to avoid incurring ongoing costs. Work in
reverse dependency order:

1. Disable, then delete the CloudFront distribution (disabling must
   complete before deletion is possible)
2. Delete the Application Load Balancer `kata-400-ALB` and its target group
3. Delete the Auto Scaling group `kata-400-ASG` (this terminates its
   instances)
4. Delete the RDS instance `kata-400-DB` — skip the final snapshot unless
   you specifically want to keep one, as snapshots incur their own storage
   cost
5. Delete the DB subnet group
6. Delete any NAT Gateways and release their associated Elastic IPs — these
   are easy to forget and continue billing hourly if missed
7. Delete the security groups, subnets, route tables, and the VPC
   `kata-400-VPC` itself

### Step 3 — Verify in the console

Check the VPC, EC2, RDS, and CloudFront consoles to confirm no `kata-400-`
resources remain, and confirm no unattached Elastic IPs or NAT Gateways are
still accruing charges.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility. A Multi-AZ RDS instance and an idle ALB are
> both easy to forget and both bill continuously while they exist.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.