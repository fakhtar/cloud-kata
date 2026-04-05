---
id: kata-107
title: "SQS Basics — Queues, Visibility & Dead-Letter Queues"
level: 100
type: depth
services:
  - sqs
tags:
  - sqs
  - messaging
  - dead-letter-queue
  - visibility-timeout
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-107 — SQS Basics: Queues, Visibility & Dead-Letter Queues

## Overview

In this kata you will build a two-queue Amazon SQS messaging setup. You will
configure message durability, failure handling, and queue behavior attributes.
This kata covers the foundational building blocks of every production SQS
implementation.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Amazon SQS resources

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. Amazon SQS
> charges per API request. All charges are your responsibility. Always run
> cleanup instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-107-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Primary Queue

Create a standard SQS queue named `kata-107-PrimaryQueue`.

The queue must be configured so that when a consumer receives a message, other
consumers are prevented from receiving that same message for a non-default
period of time.

---

### Requirement 2 — Secondary Queue

Create a standard SQS queue named `kata-107-SecondaryQueue`.

---

### Requirement 3 — Message Durability

Messages that cannot be successfully processed by the primary queue must not
be lost. They must be automatically routed to the secondary queue after a
defined number of receive attempts. The maximum number of attempts must be
explicitly configured.

---

### Requirement 4 — Tagging

Both queues must be tagged with:

- `Project`: `CloudKata`
- `Kata`: `kata-107`

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
 CloudKata Validator — kata-107
 SQS Basics: Queues, Visibility & Dead-Letter Queues
==================================================

✅ PASS — Queue 'kata-107-PrimaryQueue' exists
✅ PASS — Queue 'kata-107-SecondaryQueue' exists
✅ PASS — PrimaryQueue visibility timeout is set to a non-default value (60s)
✅ PASS — PrimaryQueue has a redrive policy configured
✅ PASS — PrimaryQueue redrive policy routes to 'kata-107-SecondaryQueue'
✅ PASS — PrimaryQueue maxReceiveCount is explicitly configured (value: 3)
✅ PASS — Both queues are tagged correctly (Project=CloudKata, Kata=kata-107)

==================================================
 Results: 7/7 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-107 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. Follow these steps
in order.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete the stack first:

```bash
aws cloudformation delete-stack --stack-name kata-107-solution
aws cloudformation wait stack-delete-complete --stack-name kata-107-solution
```

### Step 2 — Manual Cleanup

If you created resources manually, delete both queues. Work backwards through
the requirements — delete the primary queue before or at the same time as the
secondary queue.

### Step 3 — Verify in the console

Confirm that neither `kata-107-PrimaryQueue` nor `kata-107-SecondaryQueue`
appears in the SQS console.

> ⚠️ Amazon SQS enforces a 60-second cooldown before a deleted queue name can
> be reused.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints.

The complete solution is available in [solution.yml](./solution.yml).

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-107-solution
```