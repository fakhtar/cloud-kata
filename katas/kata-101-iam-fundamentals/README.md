---
id: kata-101
title: "IAM Fundamentals — Roles, Policies & Trust Relationships"
level: 100
type: depth
services:
  - iam
tags:
  - iam
  - security
  - roles
  - policies
  - trust
  - least-privilege
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-101 — IAM Fundamentals: Roles, Policies & Trust Relationships

## Overview

In this kata you will build an IAM execution role scoped for a Lambda function
that reads from and writes to a specific DynamoDB table. You will create a
customer managed policy with least privilege permissions, attach it to a role
with a correctly configured trust relationship, and verify that the role cannot
be used to access anything beyond what is strictly required.

This kata covers the three foundational IAM concepts every AWS engineer must
understand: the **role** (who you are), the **trust policy** (who can assume
you), and the **permission policy** (what you can do — and nothing more).

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage IAM roles and policies
- Familiarity with the AWS Console or CLI

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. IAM
> resources themselves have no cost. All charges are your responsibility.
> Always run cleanup instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-101-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — IAM Role

Create an IAM role named `kata-101-LambdaExecutionRole` intended for use
by a Lambda function. The role should clearly indicate its purpose.

---

### Requirement 2 — Trust Policy

The role must be configured so that only the AWS Lambda service can assume
it. No other service, user, or account should be able to assume this role.

---

### Requirement 3 — Customer Managed Policy

Create a customer managed policy named `kata-101-LambdaExecutionPolicy`
that grants a Lambda function the minimum permissions needed to:

- Read from and write to a DynamoDB table
- Write logs to CloudWatch Logs

The policy must contain only the actions required for those two purposes.
No additional actions are permitted. AWS managed policies are not acceptable
— you must author the policy document yourself.

---

### Requirement 4 — Resource Scoping (Least Privilege)

Granting the right actions is only half of least privilege. The policy must
also restrict *where* those actions can be performed:

- **DynamoDB:** Permissions must be scoped to a single specific table named
  `kata-101-OrdersTable`. Granting access to all DynamoDB tables will fail
  validation.

  > ℹ️ **You do not need to create the DynamoDB table.** This kata tests
  > IAM only. The validator checks that the policy references a specific
  > table ARN — not that the table exists.

- **CloudWatch Logs:** Permissions must be scoped to log groups associated
  with this kata's Lambda functions. A scoped wildcard on the log group name
  is acceptable. Granting access to all log groups will fail validation.

  > ℹ️ **You do not need to create the Lambda function.** This kata tests
  > IAM only. The validator checks that the policy is correctly scoped —
  > not that the Lambda function exists.

---

### Requirement 5 — Policy Attachment

Attach `kata-101-LambdaExecutionPolicy` to `kata-101-LambdaExecutionRole`.

The policy must be attached as a customer managed policy and least privilege must be maintained.
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
 CloudKata Validator — kata-101
 IAM Fundamentals: Roles, Policies & Trust Relationships
==================================================

✅ PASS — Role 'kata-101-LambdaExecutionRole' exists
✅ PASS — Trust policy allows lambda.amazonaws.com only
✅ PASS — No overly broad principals in trust policy
✅ PASS — Policy 'kata-101-LambdaExecutionPolicy' exists
✅ PASS — All required DynamoDB actions are present
✅ PASS — All required CloudWatch Logs actions are present
✅ PASS — No wildcard actions found in policy
✅ PASS — DynamoDB actions are scoped to a specific table ARN
✅ PASS — CloudWatch Logs actions are scoped (not wildcard resource)
✅ PASS — No overly broad managed policies attached
✅ PASS — Policy is attached to the role

==================================================
 Results: 11/11 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-101 requirements met.
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
aws cloudformation delete-stack --stack-name kata-101-solution
aws cloudformation wait stack-delete-complete --stack-name kata-101-solution
```

### Step 2 — Manual Cleanup

If you created resources manually, delete them in this order:

1. Detach `kata-101-LambdaExecutionPolicy` from `kata-101-LambdaExecutionRole`
2. Delete the policy `kata-101-LambdaExecutionPolicy`
3. Delete the role `kata-101-LambdaExecutionRole`

### Step 3 — Verify in the console

Go to the IAM console and confirm that neither the role nor the policy
exists.

> ⚠️ IAM resources have no ongoing cost but leaving them in your account
> represents an unnecessary security surface. Clean up when finished.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.