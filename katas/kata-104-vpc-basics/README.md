---
id: kata-104
title: "VPC Basics — Networking Constructs & Routing"
level: 100
type: depth
services:
  - vpc
tags:
  - vpc
  - networking
  - subnets
  - internet-gateway
  - route-table
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-104 — VPC Basics: Networking Constructs & Routing

## Overview

In this kata you will build the foundational networking constructs of an
AWS VPC. You will create a VPC, two public subnets in different availability
zones, an internet gateway, a route table with a default route to the
internet, and associate the subnets with the route table.

This kata focuses purely on networking constructs — no EC2 instances, no
NAT gateways, no security groups. The goal is to understand how the building
blocks of a VPC fit together and how traffic is routed.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage VPC resources
- Familiarity with basic networking concepts (CIDR, subnets, routing)

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. VPC resources themselves
> (VPC, subnets, internet gateway, route tables) have no ongoing cost.
> All charges are your responsibility. Always run cleanup instructions
> when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-104-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — VPC

Create a VPC with the following configuration:

- **Name tag:** `kata-104-VPC`
- **CIDR block:** `10.104.0.0/16`
- **DNS support:** Enabled
- **DNS hostnames:** Enabled

---

### Requirement 2 — Public Subnets

Create two public subnets inside the VPC, each in a different availability
zone:

- **Subnet 1 name tag:** `kata-104-PublicSubnet1`
- **Subnet 1 CIDR:** `10.104.1.0/24`
- **Subnet 2 name tag:** `kata-104-PublicSubnet2`
- **Subnet 2 CIDR:** `10.104.2.0/24`

Both subnets must be in the same VPC and in different availability zones.

---

### Requirement 3 — Internet Gateway

Create an internet gateway and attach it to the VPC:

- **Name tag:** `kata-104-IGW`
- The internet gateway must be attached to `kata-104-VPC` — an unattached
  internet gateway will fail validation

---

### Requirement 4 — Route Table

Create a route table associated with the VPC and add a default route to
the internet gateway:

- **Route table name tag:** `kata-104-PublicRouteTable`
- **Default route:** All traffic not destined for the VPC CIDR must be routed to the internet gateway

---

### Requirement 5 — Subnet Associations

Associate both public subnets with the route table. A subnet that is not
associated with the route table will not have internet routing and will
fail validation.

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
 CloudKata Validator — kata-104
 VPC Basics: Networking Constructs & Routing
==================================================

✅ PASS — VPC 'kata-104-VPC' exists with CIDR 10.104.0.0/16
✅ PASS — DNS support is enabled
✅ PASS — DNS hostnames are enabled
✅ PASS — Subnet 'kata-104-PublicSubnet1' exists with correct CIDR
✅ PASS — Subnet 'kata-104-PublicSubnet2' exists with correct CIDR
✅ PASS — Subnets are in different availability zones
✅ PASS — Internet gateway 'kata-104-IGW' exists and is attached to the VPC
✅ PASS — Route table 'kata-104-PublicRouteTable' exists
✅ PASS — Default route points to the internet gateway
✅ PASS — Both subnets are associated with the route table

==================================================
 Results: 10/10 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-104 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

- Go to the AWS CloudFormation console
- Select the stack created for this kata
- Choose **Delete** and wait for deletion to complete

Via CLI:
```bash
aws cloudformation delete-stack --stack-name kata-104-solution
aws cloudformation wait stack-delete-complete --stack-name kata-104-solution
```

### Step 2 — Manual Cleanup

If you created resources manually, delete them in this order:

1. Disassociate subnets from the route table
2. Delete the route table
3. Detach the internet gateway from the VPC
4. Delete the internet gateway
5. Delete the subnets
6. Delete the VPC

> ⚠️ VPC deletion will fail if any dependent resources (subnets, route
> tables, internet gateways) still exist. Always delete in order.

### Step 3 — Verify in the console

Go to the VPC console and confirm that `kata-104-VPC` no longer exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.