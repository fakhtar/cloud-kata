---
id: kata-109
title: "SSM Parameter Store — Parameters, Types & Versioning"
level: 100
type: depth
services:
  - ssm
tags:
  - ssm
  - parameter-store
  - secrets
  - depth
  - foundational
estimated_time: 30 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-109 — SSM Parameter Store: Parameters, Types & Versioning

## Overview

In this kata you will create two SSM Parameter Store parameters of different
types and explore how Parameter Store handles versioning. You will learn the
difference between plaintext and encrypted parameter types, how parameters are
named using path hierarchies, and how the version number changes each time a
parameter is updated.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage SSM Parameter Store parameters

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~30 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. SSM Parameter Store standard
> parameters are free. SecureString parameters use AWS KMS for encryption —
> using the AWS-managed key (`aws/ssm`) incurs no additional KMS charges for
> standard-tier parameters. All charges are your responsibility. Always run
> cleanup instructions when finished.

---

## Scenario

Your team is migrating application configuration into Parameter Store. Two
values need to be stored: a plaintext environment label that any service can
read, and a sensitive API key that must be encrypted at rest. Your job is to
provision both parameters in the correct format and verify that they are
accessible and correctly typed.

---

## Requirements

Build the following infrastructure in your AWS account. All parameter names
must use the path prefix `/kata-109/`.

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — String Parameter

Create a parameter at the path `/kata-109/config/environment` that stores a
plaintext string value. The value must be `dev`.

---

### Requirement 2 — SecureString Parameter

Create a parameter at the path `/kata-109/config/api-key` that stores a
sensitive value encrypted at rest. The value must be `supersecret`.

---

### Requirement 3 — Versioning

Update the `/kata-109/config/environment` parameter by changing its value to
`staging`. The parameter must be at version 2 or higher when the validator
runs.

---

### Requirement 4 — Tags

Tag the `/kata-109/config/environment` parameter with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-109`

> **Note:** SecureString parameters have tagging constraints that make them
> unsuitable for this kata. Only the String parameter is tagged.

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
 CloudKata Validator — kata-109
 SSM Parameter Store: Parameters, Types & Versioning
==================================================

✅ PASS — Parameter '/kata-109/config/environment' exists
✅ PASS — Parameter type is String
✅ PASS — Parameter value is 'staging'
✅ PASS — Parameter version is 2 or higher
✅ PASS — Parameter '/kata-109/config/api-key' exists
✅ PASS — Parameter type is SecureString
✅ PASS — Parameter value is 'supersecret'
✅ PASS — Required tags are present on '/kata-109/config/environment'

==================================================
 Results: 8/8 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-109 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-109-solution
aws cloudformation wait stack-delete-complete --stack-name kata-109-solution
```

### Step 2 — Manual Cleanup

If you created parameters manually:

```bash
aws ssm delete-parameter --name /kata-109/config/environment
aws ssm delete-parameter --name /kata-109/config/api-key
```

### Step 3 — Verify in the console

Confirm that neither parameter appears in the Systems Manager Parameter Store
console under the `/kata-109/` path.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.