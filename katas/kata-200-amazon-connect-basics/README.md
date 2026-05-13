---
id: kata-200
title: "Amazon Connect Basics — Instance, Hours of Operation & Queue"
level: 200
type: depth
services:
  - connect
tags:
  - connect
  - contact-center
  - depth
  - foundational
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-200 — Amazon Connect Basics: Instance, Hours of Operation & Queue

## Overview

In this kata you will provision the foundational building blocks of an Amazon
Connect contact center. You will create a Connect instance, configure when the
contact center is open, and set up a queue that uses those hours. These three
resources form the prerequisite layer that every contact flow, routing profile,
and agent configuration depends on.

This kata introduces Connect-specific concepts: how instances are identified
and scoped, why hours of operation must exist before a queue can be created,
and how the two resources are linked.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Amazon Connect instances, hours of
  operation, and queues

> ⚠️ **Instance limit:** AWS enforces a limit on how many Connect instances
> you can create and delete within a 30-day period. If you hit this limit, you
> will need to wait before creating new instances. Plan your cleanup accordingly.

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Amazon Connect charges are
> based on usage (calls, tasks, and so on). The resources created in this kata
> do not generate usage charges on their own. All charges are your
> responsibility. Always run cleanup instructions when finished.

---

## Scenario

You are provisioning the AWS infrastructure for a new contact center team.
Before any agent can take a call or any contact flow can route traffic, the
core scaffolding must exist: an instance to host everything, a schedule that
defines when the center is open, and a queue where contacts will wait. Your
job is to provision this foundation.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-200-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Connect Instance

Create an Amazon Connect instance with the instance alias `kata-200-instance`.
The instance must be active before any dependent resources can be created.
Use CONNECT_MANAGED identity management.

---

### Requirement 2 — Hours of Operation

Create a hours of operation named `kata-200-BasicHours` within the instance.
The schedule should represent standard business hours: Monday through Friday,
09:00 to 17:00. Choose an appropriate timezone.

---

### Requirement 3 — Queue

Create a queue named `kata-200-BasicQueue` within the instance. The queue
must be associated with `kata-200-BasicHours`.

---

### Requirement 4 — Tags

Tag the hours of operation and the queue with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-200`

> **Note:** Amazon Connect instances do not support tagging via the standard
> CloudFormation `Tags` property. Instance tags are managed separately and
> are not validated by this kata.

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and
upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

> ⏳ **Allow time for the instance to become active.** A newly created Connect
> instance can take several minutes to reach `ACTIVE` status. The validator
> will wait and retry if the instance is still initialising.

The validator checks your live AWS infrastructure and reports a score.
A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-200
 Amazon Connect Basics: Instance, Hours of Operation & Queue
==================================================

✅ PASS — Connect instance 'kata-200-instance' exists
✅ PASS — Instance status is ACTIVE
✅ PASS — Hours of operation 'kata-200-BasicHours' exists
✅ PASS — Hours of operation covers Monday to Friday, 09:00-17:00
✅ PASS — Queue 'kata-200-BasicQueue' exists
✅ PASS — Queue is associated with 'kata-200-BasicHours'
✅ PASS — Required tags are present on hours of operation
✅ PASS — Required tags are present on queue

==================================================
 Results: 8/8 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-200 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

> ⚠️ **Instance deletion counts against your 30-day limit.** AWS tracks
> instance creations and deletions together. Deleting this instance will
> count toward the limit just as creating it did.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-200-solution
aws cloudformation wait stack-delete-complete --stack-name kata-200-solution
```

### Step 2 — Manual Cleanup

If you created resources manually:

```bash
# Get the instance ID
INSTANCE_ID=$(aws connect list-instances \
  --query "InstanceSummaryList[?InstanceAlias=='kata-200-instance'].Id" \
  --output text)

# Delete the instance (queues and hours of operation are deleted automatically)
aws connect delete-instance --instance-id "$INSTANCE_ID"
```

> Queues and hours of operation cannot be deleted independently — they are
> removed when the instance is deleted.

### Step 3 — Verify in the console

Confirm that `kata-200-instance` no longer appears in the Amazon Connect
console under **Instances**.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.