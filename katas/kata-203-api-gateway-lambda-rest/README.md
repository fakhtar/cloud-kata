---
id: kata-203
title: "API Gateway + Lambda — REST API & Proxy Integration"
level: 200
type: breadth
services:
  - apigateway
  - lambda
tags:
  - apigateway
  - lambda
  - rest-api
  - proxy-integration
  - breadth
  - foundational
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-203 — API Gateway + Lambda: REST API & Proxy Integration

## Overview

In this kata you will build a REST API using API Gateway and wire it to a
Lambda function using proxy integration. You will define an API resource and
method, connect the integration, deploy the API to a stage, and verify that
the endpoint returns a valid HTTP response.

This kata covers foundational serverless API concepts: how API Gateway routes
HTTP requests to Lambda, what proxy integration means and how it differs from
custom integration, and how deployment stages control which version of an API
is live.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage API Gateway REST APIs, Lambda functions,
  and IAM roles

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. API Gateway and Lambda both
> have free tier allowances that comfortably cover this kata. All charges are
> your responsibility. Always run cleanup instructions when finished.

---

## Scenario

You are building the first endpoint of a new order management API. The backend
team has agreed on a contract: a `GET /orders` endpoint that returns a JSON
response. Your job is to provision the API infrastructure and wire it to a
Lambda function that handles the request. The function code is provided — this
is an infrastructure kata, not a coding kata.

---

## Lambda Function Code

Use the following code when creating `kata-203-HandlerFunction`. The runtime
must be **Python 3.12**.

```python
import json

def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": "orders ok"})
    }
```

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-203-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Lambda Function

Create a Lambda function named `kata-203-HandlerFunction` using the code
and runtime specified above. The function requires an execution role with
permission to write logs to CloudWatch Logs.

---

### Requirement 2 — REST API

Create a REST API named `kata-203-OrderAPI`.

---

### Requirement 3 — Resource and Method

Under the REST API, create a resource with the path `/orders`. On that
resource, create a `GET` method.

---

### Requirement 4 — Lambda Proxy Integration

Configure the `GET /orders` method to use Lambda proxy integration pointing
to `kata-203-HandlerFunction`. API Gateway must have permission to invoke
the function.

---

### Requirement 5 — Deployment and Stage

Deploy the API to a stage named `prod`. The validator will invoke the
deployed endpoint and expect a `200` HTTP response.

---

### Requirement 6 — Tags

Tag the Lambda function and the REST API with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-203`

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
 CloudKata Validator — kata-203
 API Gateway + Lambda: REST API & Proxy Integration
==================================================

✅ PASS — Lambda function 'kata-203-HandlerFunction' exists
✅ PASS — REST API 'kata-203-OrderAPI' exists
✅ PASS — Resource '/orders' exists
✅ PASS — GET method exists on '/orders'
✅ PASS — Lambda proxy integration is configured
✅ PASS — API is deployed to stage 'prod'
✅ PASS — Endpoint returns HTTP 200
✅ PASS — Required tags are present on Lambda function
✅ PASS — Required tags are present on REST API

==================================================
 Results: 9/9 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-203 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-203-solution
aws cloudformation wait stack-delete-complete --stack-name kata-203-solution
```

### Step 2 — Manual Cleanup

If you created resources manually:

```bash
# Get the REST API ID
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='kata-203-OrderAPI'].id" \
  --output text)

# Delete the REST API
aws apigateway delete-rest-api --rest-api-id "$API_ID"

# Delete the Lambda function
aws lambda delete-function --function-name kata-203-HandlerFunction
```

### Step 3 — Verify in the console

Confirm that `kata-203-OrderAPI` no longer appears in the API Gateway console
and that `kata-203-HandlerFunction` no longer appears in the Lambda console.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.