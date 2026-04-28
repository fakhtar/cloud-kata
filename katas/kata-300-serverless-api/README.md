---
id: kata-300
title: "Serverless API — Lambda, API Gateway & DynamoDB"
level: 300
type: breadth
services:
  - lambda
  - apigateway
  - dynamodb
tags:
  - lambda
  - apigateway
  - dynamodb
  - rest-api
  - proxy-integration
  - breadth
  - serverless
estimated_time: 60 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-300 — Serverless API: Lambda, API Gateway & DynamoDB

## Overview

In this kata you will build a fully serverless API backed by a persistent NoSQL
table. You will provision a DynamoDB table, wire a Lambda function to read from
and write to it, expose two HTTP endpoints via API Gateway, and deploy the API
to a stage.

This kata brings together three core serverless building blocks: an HTTP
frontend (API Gateway), a compute layer (Lambda), and a persistence layer
(DynamoDB). You will configure the IAM permissions that allow Lambda to interact
with the table, implement two operations — creating an item and listing all
items — and verify the full stack end to end.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Lambda functions, API Gateway REST APIs,
  DynamoDB tables, and IAM roles and policies

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~60 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Lambda, API Gateway, and
> DynamoDB all have free tier allowances that comfortably cover this kata.
> All charges are your responsibility. Always run cleanup instructions when
> finished.

---

## Scenario

You are building a lightweight item registry service. The backend team needs
two endpoints: one to create a new item with a generated ID and a name, and
one to list all existing items. Your job is to provision the full infrastructure
stack. The function code is provided — this is an infrastructure kata, not a
coding kata.

---

## Lambda Function Code

Use the following code when creating `kata-300-HandlerFunction`. The runtime
must be **Python 3.12**.

```python
import json
import os
import uuid
import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    method = event.get("httpMethod", "")
    path = event.get("path", "")

    if method == "POST" and path == "/items":
        body = json.loads(event.get("body") or "{}")
        name = body.get("name", "unnamed")
        item_id = str(uuid.uuid4())
        table.put_item(Item={"id": item_id, "name": name})
        return {
            "statusCode": 201,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"id": item_id, "name": name})
        }

    if method == "GET" and path == "/items":
        result = table.scan()
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"items": result.get("Items", [])})
        }

    return {
        "statusCode": 404,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": "not found"})
    }
```

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-300-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — DynamoDB Table

Create a DynamoDB table named `kata-300-ItemsTable`. Individual items must be
uniquely identifiable and retrievable by an `id` field.

---

### Requirement 2 — Lambda Function

Create a Lambda function named `kata-300-HandlerFunction` using the code and
runtime specified above. The function requires an execution role with appropriate
permissions. The function must be able to reach `kata-300-ItemsTable` at
runtime, and the table name must be available to the function as configuration. The function must also be able to write logs.

---

### Requirement 3 — REST API

Create a REST API named `kata-300-ItemsAPI`.

---

### Requirement 4 — Resources and Methods

The API must support creating a new item and listing all existing items. Both
operations should be accessible under the same path /items.

---

### Requirement 5 — Lambda Integration

Both methods must invoke `kata-300-HandlerFunction` and pass the full HTTP
request context to the function. The function must be reachable by API Gateway.

---

### Requirement 6 — Deployment and Stage

Deploy the API to a stage named `prod`.

---

### Requirement 7 — Tags

Tag the Lambda function, the REST API, and the DynamoDB table with the standard
CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-300`

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
 CloudKata Validator — kata-300
 Serverless API: Lambda, API Gateway & DynamoDB
==================================================

✅ PASS — DynamoDB table 'kata-300-ItemsTable' exists
✅ PASS — Lambda function 'kata-300-HandlerFunction' exists
✅ PASS — TABLE_NAME environment variable is set correctly
✅ PASS — REST API 'kata-300-ItemsAPI' exists
✅ PASS — Resource '/items' exists
✅ PASS — POST method exists on '/items'
✅ PASS — GET method exists on '/items'
✅ PASS — Lambda proxy integration is configured on POST /items
✅ PASS — Lambda proxy integration is configured on GET /items
✅ PASS — API is deployed to stage 'prod'
✅ PASS — POST /items returns HTTP 201
✅ PASS — GET /items returns HTTP 200
✅ PASS — Required tags are present on DynamoDB table
✅ PASS — Required tags are present on Lambda function
✅ PASS — Required tags are present on REST API

==================================================
 Results: 15/15 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-300 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-300-solution
aws cloudformation wait stack-delete-complete --stack-name kata-300-solution
```

### Step 2 — Manual Cleanup

If you created resources manually:

```bash
# Get the REST API ID
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='kata-300-ItemsAPI'].id" \
  --output text)

# Delete the REST API
aws apigateway delete-rest-api --rest-api-id "$API_ID"

# Delete the Lambda function
aws lambda delete-function --function-name kata-300-HandlerFunction

# Delete the DynamoDB table
aws dynamodb delete-table --table-name kata-300-ItemsTable
```

### Step 3 — Verify in the console

Confirm that `kata-300-ItemsAPI` no longer appears in the API Gateway console,
`kata-300-HandlerFunction` no longer appears in the Lambda console, and
`kata-300-ItemsTable` no longer appears in the DynamoDB console.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.