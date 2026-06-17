---
id: kata-204
title: "S3 + Lambda — Event Notifications & Triggers"
level: 200
type: breadth
services:
  - s3
  - lambda
tags:
  - s3
  - lambda
  - event-driven
  - notifications
  - triggers
  - breadth
  - intermediate
estimated_time: 45 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-204 — S3 + Lambda: Event Notifications & Triggers

## Overview

In this kata you will build an event-driven architecture where uploading an
object to an S3 bucket automatically triggers a Lambda function. You will
configure an S3 event notification and grant S3 permission to invoke your
function via a resource-based policy — the exact wiring behind nearly every
S3-triggered serverless workflow: image processing pipelines, file
ingestion, log shipping, and more.

This is not a coding kata. The Lambda function code is provided for you
below — your job is the infrastructure and the event wiring around it.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage S3 buckets, Lambda functions, IAM
  roles, and CloudWatch Logs

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. S3 storage and requests,
> Lambda invocations, and CloudWatch Logs all have a perpetual free tier
> that easily covers this kata. Actual costs depend on your AWS region,
> account tier, and how quickly you complete the kata. All charges are
> your responsibility. Always run cleanup instructions when finished.

---

## Scenario

Your team needs a lightweight ingestion pipeline: whenever a file is
uploaded to a specific S3 bucket, a Lambda function should run automatically
to process it. For this kata, "processing" simply means logging details
about the uploaded object — but the wiring you build here is the same
wiring used in production ingestion pipelines that resize images, parse
CSVs, or kick off downstream workflows.

---

## Provided Lambda Function Code

You do not need to write any function logic for this kata. Use the
following Python 3.12 code as the Lambda function's source. It logs the
bucket name, object key, and event name for every record in the S3 event.

```python
import json

def handler(event, context):
    print("kata-204 ProcessorFunction invoked")
    print(json.dumps(event))

    for record in event.get("Records", []):
        bucket = record.get("s3", {}).get("bucket", {}).get("name", "unknown-bucket")
        key = record.get("s3", {}).get("object", {}).get("key", "unknown-key")
        event_name = record.get("eventName", "unknown-event")
        print(f"PROCESSED bucket={bucket} key={key} event={event_name}")

    return {"statusCode": 200}
```

Use this exact code (or behaviorally identical code) as the function's
handler. The validator does not inspect log content, but the optional
self-check described later in this README does — if you write your own
function logic instead of using this code, make sure it still prints a
recognizable line so you can confirm invocation manually.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must use the prefix `kata-204-`.

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — S3 Bucket

Create an S3 bucket with a name that **starts with** the prefix
`kata-204-bucket-`.

> S3 bucket names must be globally unique across all AWS accounts. You
> cannot use the prefix alone as the full bucket name — append something
> unique to it, such as your AWS account ID or a random suffix, e.g.
> `kata-204-bucket-123456789012`.

- **Name:** must start with `kata-204-bucket-`
- The validator discovers your bucket by searching for this prefix, so any
  suffix you choose is fine as long as the prefix matches exactly.

---

### Requirement 2 — Lambda Function

Create a Lambda function with the following configuration:

- **Name:** `kata-204-ProcessorFunction` (exact name required)
- **Runtime:** Python 3.12
- **Handler code:** the code provided above in
  [Provided Lambda Function Code](#provided-lambda-function-code)
- **Permission** the function must be able to write its own
  invocation logs to CloudWatch Logs
- **Timeout:** at least 10 seconds

---

### Requirement 3 — S3 Event Notification

Configure an S3 event notification on your bucket so that **all object
creation events** (`s3:ObjectCreated:*`) invoke `kata-204-ProcessorFunction`.

- No prefix or suffix filter is required — the notification should apply to
  the whole bucket.

---

### Requirement 4 — Permission to Invoke

`kata-204-ProcessorFunction` must be invocable by your S3 bucket
specifically — not by S3 buckets in general, and not by any other AWS
service or account.

- Your bucket must be able to invoke the function
- Other buckets, services, or accounts must not gain this ability as a
  side effect of however you grant it

---

### Optional — Verify It Yourself

The validator confirms your trigger is wired correctly, but it does not
upload a test object or check for an actual invocation. If you want to see
the whole thing work end to end before moving on, you can check it
yourself:

```bash
echo "hello kata-204" > /tmp/test-object.txt
aws s3 cp /tmp/test-object.txt s3://<your-bucket-name>/manual-test.txt
```

Then check the function's log group (`/aws/lambda/kata-204-ProcessorFunction`)
for a line containing `PROCESSED bucket=` and `key=manual-test.txt`. This
step is optional and not scored.

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
 CloudKata Validator — kata-204
 S3 + Lambda: Event Notifications & Triggers
==================================================

✅ PASS — Bucket with prefix 'kata-204-bucket-' exists
✅ PASS — Lambda function 'kata-204-ProcessorFunction' exists
✅ PASS — Lambda runtime is python3.12
✅ PASS — S3 event notification configured for s3:ObjectCreated:*
✅ PASS — Notification targets 'kata-204-ProcessorFunction'
✅ PASS — Lambda resource policy allows s3.amazonaws.com to invoke the function
✅ PASS — Resource policy is scoped to this bucket

==================================================
 Results: 7/7 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-204 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. Follow these steps
in order.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-204-solution
aws cloudformation wait stack-delete-complete --stack-name kata-204-solution
```

> ⚠️ **S3 buckets must be empty before they can be deleted.** If the stack
> deletion fails with a `DELETE_FAILED` status on the bucket resource,
> empty the bucket manually and re-run the delete:
>
> ```bash
> aws s3 rm s3://<your-bucket-name> --recursive
> aws cloudformation delete-stack --stack-name kata-204-solution
> ```

### Step 2 — Manual Cleanup

If you created any resources manually via the console or via the CLI, it is
your responsibility to delete them to avoid incurring ongoing costs.

- Empty and delete the S3 bucket
- Delete the Lambda function `kata-204-ProcessorFunction`
- Delete the IAM role created for the function's execution role
- Delete the CloudWatch Logs log group
  `/aws/lambda/kata-204-ProcessorFunction`

Read the instructions again and work backwards to ensure you have deleted
all created resources.

### Step 3 — Verify in the console

Go to the S3 console and confirm the `kata-204-bucket-*` bucket no longer
exists. Go to the Lambda console and confirm `kata-204-ProcessorFunction`
no longer exists.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.