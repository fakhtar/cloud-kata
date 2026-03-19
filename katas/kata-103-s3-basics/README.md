---
id: kata-103
title: "S3 Basics — Buckets, Versioning & Security"
level: 100
type: depth
services:
  - s3
tags:
  - s3
  - storage
  - versioning
  - encryption
  - security
  - public-access-block
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-103 — S3 Basics: Buckets, Versioning & Security

## Overview

In this kata you will create an S3 bucket and configure it with the
foundational security settings that every production bucket should have.
You will enable versioning to protect objects from accidental deletion,
block all public access, and enable server-side encryption at rest.

This kata covers the core S3 concepts every AWS engineer must understand
before using S3 in any real workload: how buckets are named and created,
how versioning works, and what it means to properly secure a bucket against
public exposure and unencrypted storage.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage S3 buckets
- Familiarity with the AWS Console or CLI

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. S3 charges
> for storage, requests, and data transfer. An empty bucket with no objects
> incurs no storage cost. All charges are your responsibility. Always run
> cleanup instructions when finished.

---

## A Note on Bucket Names

S3 bucket names must be **globally unique** across all AWS accounts and
regions. You cannot create a bucket with a name that already exists anywhere
in AWS. To guarantee uniqueness, include your AWS account ID in the bucket
name as shown in the requirements below.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-103-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — S3 Bucket

Create an S3 bucket with the following configuration:

- **Bucket name:** `kata-103-bucket-<your-account-id>` — replace
  `<your-account-id>` with your 12-digit AWS account ID
- **Region:** Any AWS region of your choice

---

### Requirement 2 — Versioning

Enable versioning on the bucket. A bucket with versioning suspended or
never enabled will fail validation.

---

### Requirement 3 — Public Access Block

All four public access block settings must be enabled on the bucket:

- Block public ACLs
- Block public policies
- Ignore public ACLs
- Restrict public buckets

A bucket with any of the four settings disabled will fail validation.

---

### Requirement 4 — Server-Side Encryption

Enable default server-side encryption on the bucket so that all objects
stored in the bucket are encrypted at rest. SSE-S3 (AES-256) is sufficient
for this kata.

---

### Requirement 5 — Tags

Tag the bucket with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-103`

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and
upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator will prompt you for your AWS account ID to locate the bucket.
A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-103
 S3 Basics: Buckets, Versioning & Security
==================================================

✅ PASS — Bucket 'kata-103-bucket-<account-id>' exists
✅ PASS — Versioning is enabled
✅ PASS — BlockPublicAcls is enabled
✅ PASS — BlockPublicPolicy is enabled
✅ PASS — IgnorePublicAcls is enabled
✅ PASS — RestrictPublicBuckets is enabled
✅ PASS — Default server-side encryption is enabled
✅ PASS — Required tags are present

==================================================
 Results: 8/8 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-103 requirements met.
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
aws cloudformation delete-stack --stack-name kata-103-solution
aws cloudformation wait stack-delete-complete --stack-name kata-103-solution
```

> ⚠️ CloudFormation cannot delete an S3 bucket that contains objects.
> Empty the bucket first before deleting the stack, or the stack deletion
> will fail.

### Step 2 — Manual Cleanup

If you created resources manually, empty and delete the bucket:

```bash
# Empty the bucket first
aws s3 rm s3://kata-103-bucket-<your-account-id> --recursive

# Then delete the bucket
aws s3api delete-bucket --bucket kata-103-bucket-<your-account-id>
```

### Step 3 — Verify in the console

Go to the S3 console and confirm that `kata-103-bucket-<your-account-id>`
no longer exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.