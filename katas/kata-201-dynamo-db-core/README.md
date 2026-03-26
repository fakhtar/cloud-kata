---
id: kata-201
title: "DynamoDB Core — Tables, Keys, Indexes & Capacity Modes"
level: 200
type: depth
services:
  - dynamodb
tags:
  - dynamodb
  - nosql
  - indexes
  - gsi
  - capacity
  - depth
  - foundational
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-201 — DynamoDB Core: Tables, Keys, Indexes & Capacity Modes

## Overview

In this kata you will build a DynamoDB table for an order management system.
You will define a composite primary key, create a Global Secondary Index to
support an alternative access pattern, and configure the table's capacity mode.

This kata covers the foundational DynamoDB concepts that every AWS engineer
must understand: how primary keys determine data distribution and access,
why GSIs exist, what projection means, and how capacity modes affect cost
and throughput behaviour.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage DynamoDB tables
- Familiarity with NoSQL key concepts (partition key, sort key)

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. DynamoDB on-demand tables
> have no base cost — you pay only for reads and writes performed. An idle
> table with no traffic costs nothing. Provisioned tables charge for reserved
> capacity whether used or not. All charges are your responsibility. Always
> run cleanup instructions when finished.

---

## Scenario

You are building the data layer for an order management system. Orders need
to be retrieved by their unique order ID, but the system also needs to look
up all orders placed by a specific customer. Your table design must support
both access patterns efficiently.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-201-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — DynamoDB Table

Create a DynamoDB table named `kata-201-Orders` with the following
attributes defined exactly as specified:

| Attribute Name | Attribute Type |
|---|---|
| `OrderId` | String |
| `CreatedAt` | String |
| `CustomerEmail` | String |

The table's primary key must support the following access pattern:
retrieve all orders for a given order ID, filtered or sorted by the
date they were created. The table must be in an active state before
running the validator.

---

### Requirement 2 — Capacity Mode

The order management system experiences unpredictable traffic — quiet
periods followed by sudden spikes when promotions run. Configure the
table's capacity mode to match this traffic pattern without requiring
capacity planning in advance.

---

### Requirement 3 — Global Secondary Index

The system must support an additional access pattern: retrieving all
orders placed by a specific customer. Create a Global Secondary Index
named `kata-201-CustomerEmail-index` that enables this access pattern
using the `CustomerEmail` (String) attribute.

When querying via this index, all attributes stored in the primary table
must be available in the results.

---

### Requirement 4 — Tags

Tag the table with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-201`

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
 CloudKata Validator — kata-201
 DynamoDB Core: Tables, Keys, Indexes & Capacity Modes
==================================================

✅ PASS — Table 'kata-201-Orders' exists
✅ PASS — Table status is ACTIVE
✅ PASS — Partition key is correct
✅ PASS — Sort key is correct
✅ PASS — Capacity mode is configured correctly
✅ PASS — GSI 'kata-201-CustomerEmail-index' exists
✅ PASS — GSI partition key is correct
✅ PASS — GSI projection is correct
✅ PASS — Required tags are present

==================================================
 Results: 9/9 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-201 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-201-solution
aws cloudformation wait stack-delete-complete --stack-name kata-201-solution
```

### Step 2 — Manual Cleanup

If you created the table manually:

```bash
aws dynamodb delete-table --table-name kata-201-Orders
```

### Step 3 — Verify in the console

Go to the DynamoDB console and confirm that `kata-201-Orders` no longer
exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.