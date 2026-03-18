---
id: kata-102
title: "Lambda Essentials — Functions, Triggers & Environment Variables"
level: 100
type: depth
services:
  - lambda
tags:
  - lambda
  - serverless
  - environment-variables
  - iam
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-102 — Lambda Essentials: Functions, Triggers & Environment Variables

## Overview

In this kata you will build a Lambda function that reads configuration from
an environment variable and returns a structured response. You will configure
the function's runtime, handler, memory, timeout, and execution role — the
foundational building blocks of every Lambda deployment.

This kata covers the core concepts every AWS engineer must understand before
working with serverless: how a function is configured, how it reads its
environment, and how it behaves at runtime.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Lambda functions and IAM roles
- Familiarity with the AWS Console or CLI

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. AWS Lambda
> charges per invocation and per GB-second of compute. At this scale, charges
> are negligible but not zero. All charges are your responsibility. Always
> run cleanup instructions when finished.

---

## Function Code

This is not a coding kata. Copy and paste the following function code exactly
as provided. The validator will invoke your function and check for a specific
response — modifying the code may cause validation to fail.

```python
import json
import os

def lambda_handler(event, context):
    environment = os.environ.get('APP_ENVIRONMENT', 'unknown')
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Function executed successfully',
            'environment': environment
        })
    }
```

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-102-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Lambda Function

Create a Lambda function with the following configuration:

- **Function name:** `kata-102-EnvironmentReader`
- **Runtime:** Python 3.12
- **Handler:** The handler must point to the `lambda_handler` function in
  the provided code
- **Function code:** Use the code provided in the Function Code section above

---

### Requirement 2 — Execution Role

Create an IAM role named `kata-102-LambdaExecutionRole` that allows the
Lambda service to assume it. Attach the AWS managed policy
`AWSLambdaBasicExecutionRole` to grant the function permission to write
logs to CloudWatch Logs.

> ⚠️ **Note:** Using `AWSLambdaBasicExecutionRole` is acceptable for this
> kata because the focus is Lambda configuration, not IAM least privilege.
> In production, you should always author a customer managed policy scoped
> to the minimum permissions required. See kata-101 for a deep dive on
> IAM least privilege.

---

### Requirement 3 — Environment Variable

Configure the function with the following environment variable:

- **Key:** `APP_ENVIRONMENT`
- **Value:** `production`

The validator will invoke your function and check that the response contains
this value. If the environment variable is missing or set to a different
value, the invocation check will fail.

---

### Requirement 4 — Timeout and Memory

Configure the function with non-default values for both timeout and memory:

- **Timeout:** Must be greater than the Lambda default of 3 seconds
- **Memory:** Must be greater than the Lambda default of 128 MB

The specific values are your choice — the validator checks that both are
set beyond their defaults, not that they match a specific value.

---

### Requirement 5 — Function State

The function must be in an active, deployable state. A function that exists
but cannot be invoked will fail the validator's runtime check.

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
 CloudKata Validator — kata-102
 Lambda Essentials: Functions, Triggers & Environment Variables
==================================================

✅ PASS — Function 'kata-102-EnvironmentReader' exists
✅ PASS — Runtime is python3.12
✅ PASS — Handler is correctly configured
✅ PASS — Execution role is attached
✅ PASS — Environment variable APP_ENVIRONMENT is set to 'production'
✅ PASS — Timeout is greater than default (3s)
✅ PASS — Memory is greater than default (128MB)
✅ PASS — Function invocation returns statusCode 200
✅ PASS — Invocation response contains correct environment value

==================================================
 Results: 9/9 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-102 requirements met.
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
aws cloudformation delete-stack --stack-name kata-102-solution
aws cloudformation wait stack-delete-complete --stack-name kata-102-solution
```

### Step 2 — Manual Cleanup

If you created resources manually, delete them in this order:

1. Delete the Lambda function `kata-102-EnvironmentReader`
2. Detach `AWSLambdaBasicExecutionRole` from `kata-102-LambdaExecutionRole`
3. Delete the role `kata-102-LambdaExecutionRole`

### Step 3 — Verify in the console

Go to the Lambda console and confirm that `kata-102-EnvironmentReader`
no longer exists.

> ⚠️ Lambda functions have no ongoing cost when not invoked, but cleaning
> up is good practice and keeps your account tidy.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.