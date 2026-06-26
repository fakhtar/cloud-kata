---
id: kata-500
title: "Contact Center Platform — Connect, Lex V2, Lambda, DynamoDB & CloudWatch"
level: 500
type: breadth
services:
  - connect
  - lex-v2
  - lambda
  - dynamodb
  - cloudwatch
tags:
  - connect
  - lex-v2
  - lambda
  - dynamodb
  - cloudwatch
  - conversational-ai
  - serverless
  - contact-center
  - breadth
  - expert
estimated_time: 4 hours
estimated_cost: "$1.00 - $5.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-500 — Contact Center Platform: Connect, Lex V2, Lambda, DynamoDB & CloudWatch

## Overview

In this kata you will build a production-grade contact center platform by
integrating five AWS services end-to-end. Amazon Connect handles telephony
and contact routing. A Lex V2 bot serves as the conversational IVR, parsing
caller intent. A Lambda function fulfils those intents, reading from and
writing to a DynamoDB table that persists caller interaction records. CloudWatch
provides the operational layer: an alarm monitors Lambda error rate and a
dedicated log group receives contact flow logs from Connect.

The validator checks every layer of the stack — that each service is correctly
configured in isolation, that the integration wiring is in place, and that the
observability layer is active. A score of 100% means the platform is fully
operational.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Amazon Connect, Lex V2, Lambda,
  DynamoDB, CloudWatch, and IAM resources
- Familiarity with the AWS Console and CLI at an intermediate-to-advanced level
- Amazon Connect is available in select regions — confirm your target region
  supports all five services in this kata before starting. If you have never
  used Connect in this account, verify your service quota for Connect instances.

> ℹ️ **Recommended region:** `us-east-1` supports all five services and has
> the broadest Connect feature availability.

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~4 hours |
| 💰 Estimated Cost | ~$1.00 – $5.00 |

> ⚠️ **Cost Warning:** This kata involves **five billable services running
> concurrently.** These are estimates only. Actual costs depend on your AWS
> region, account tier, usage volume, and how quickly you complete and clean
> up the kata. Amazon Connect charges per minute of active contact flow
> execution. Lambda charges per invocation and duration. DynamoDB charges for
> reads, writes, and storage. Lex V2 charges per request. CloudWatch charges
> for log ingestion and alarm evaluations. If you leave infrastructure running
> beyond the kata session, costs will continue to accumulate. **All charges
> are your responsibility.** Always run the cleanup instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-500-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Amazon Connect Instance

Create an Amazon Connect instance named `kata-500-instance`. Users must be
managed directly by Amazon Connect. The instance must be able to receive and
place calls. Contact flow log emission must be enabled. The instance must
reach `ACTIVE` status.

---

### Requirement 2 — Lex V2 IVR Bot

Create an Amazon Lex V2 bot named `kata-500-IVRBot`. The bot must support
English (US), have a service role that permits Lex to call AWS services on
its behalf, and time out idle sessions after a reasonable period. The bot
locale must be built and reach `Built` status.

The bot must contain the following intents in its English (US) locale:

**Intent: `CheckOrderStatus`**
- At least 5 distinct sample utterances expressing a desire to check an order
  status
- A slot named `OrderId` that captures an alphanumeric order identifier. The
  slot must be required — the bot must elicit it from the caller if not
  provided
- A closing response confirming the intent was recognised

**Intent: `CancelOrder`**
- At least 5 distinct sample utterances expressing a desire to cancel an order
- A closing response confirming the intent was recognised

**Bot alias:** Create a bot alias named `kata-500-ProdAlias`. The alias must
support English (US) and be configured with a Lambda code hook pointing to
`kata-500-FulfillmentFunction` (see Requirement 3).

---

### Requirement 3 — Lambda Fulfilment Function

Create a Lambda function named `kata-500-FulfillmentFunction`. The function
must be configured with a timeout sufficient to complete a DynamoDB write and
return a valid response to Lex. The function's execution role must grant it
the permissions necessary to write records to `kata-500-CallerDataTable` and
emit logs. Amazon Lex must be permitted to invoke the function.

When invoked by Lex V2, the function must write a record to
`kata-500-CallerDataTable`. Each record must identify the caller session, the
recognised intent, the time of invocation, and carry a fulfilment status. At
minimum the record must contain:

- `callerId` — a non-empty string identifying the caller session
- `intentName` — the name of the recognised intent from the Lex event
- `timestamp` — the time of invocation
- `status` — indicating the invocation was fulfilled

---

### Requirement 4 — DynamoDB Table

Create a DynamoDB table named `kata-500-CallerDataTable` to store caller
interaction records. The table must reach `ACTIVE` status.

---

### Requirement 5 — Contact Flow

Create a contact flow named `kata-500-ContactFlow` inside `kata-500-instance`.
The flow must invoke `kata-500-IVRBot` to handle caller input.

---

### Requirement 6 — CloudWatch Log Group

Create a CloudWatch log group named `kata-500-ContactFlowLogs` with a
retention period of 30 days.

---

### Requirement 7 — CloudWatch Alarm

Create a CloudWatch alarm named `kata-500-LambdaErrorAlarm` that monitors
`kata-500-FulfillmentFunction` for invocation errors. The alarm must activate
on the first error detected. It must not enter an alarm state when the
function has not been invoked. The alarm must be evaluable.

---

### Requirement 8 — End-to-End Integration

All five services must be wired together as a cohesive platform:

- `kata-500-IVRBot` must be associated with `kata-500-instance`
- `kata-500-FulfillmentFunction` must be the Lambda code hook on
  `kata-500-ProdAlias`
- The execution role of `kata-500-FulfillmentFunction` must grant it access
  to `kata-500-CallerDataTable`
- `kata-500-ContactFlow` must exist within `kata-500-instance`

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
 CloudKata Validator — kata-500
 Contact Center Platform
==================================================

✅ PASS — Connect instance 'kata-500-instance' is ACTIVE
✅ PASS — Lex V2 bot 'kata-500-IVRBot' exists and locale is Built
✅ PASS — Bot alias 'kata-500-ProdAlias' exists with en_US enabled
✅ PASS — Lambda function 'kata-500-FulfillmentFunction' exists and is configured correctly
✅ PASS — DynamoDB table 'kata-500-CallerDataTable' is ACTIVE
✅ PASS — Contact flow 'kata-500-ContactFlow' exists in the Connect instance
✅ PASS — CloudWatch log group 'kata-500-ContactFlowLogs' exists with 30-day retention
✅ PASS — CloudWatch alarm 'kata-500-LambdaErrorAlarm' is correctly configured
✅ PASS — Integration: Lex bot is associated with Connect instance
✅ PASS — Integration: Lambda hook is configured on 'kata-500-ProdAlias'
✅ PASS — Integration: Lambda execution role has DynamoDB access

==================================================
 Results: 11/11 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-500 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. This kata spans five
services — follow the steps in order to avoid orphaned dependencies that
block deletion.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first.

```bash
aws cloudformation delete-stack --stack-name kata-500-solution
aws cloudformation wait stack-delete-complete --stack-name kata-500-solution
```

> ⚠️ Amazon Connect instances cannot be deleted by CloudFormation. You must
> delete the Connect instance manually after the stack is removed.

### Step 2 — Delete the Amazon Connect instance manually

Amazon Connect instances must be deleted via the console or CLI regardless of
how they were created.

Via CLI:

```bash
INSTANCE_ID=$(aws connect list-instances \
  --query "InstanceSummaryList[?InstanceAlias=='kata-500-instance'].Id | [0]" \
  --output text)
aws connect delete-instance --instance-id "$INSTANCE_ID"
```

Via console: **Amazon Connect → Instances → kata-500-instance → Delete**

### Step 3 — Manual cleanup of any remaining resources

If you created resources manually outside of CloudFormation, delete them in
reverse dependency order:

1. Delete the CloudWatch alarm `kata-500-LambdaErrorAlarm`
2. Delete the CloudWatch log group `kata-500-ContactFlowLogs`
3. Delete the DynamoDB table `kata-500-CallerDataTable`
4. Delete the Lambda function `kata-500-FulfillmentFunction` and its
   execution role
5. Delete the Lex V2 bot alias `kata-500-ProdAlias`, then the bot
   `kata-500-IVRBot`
6. Delete the Connect instance `kata-500-instance` (if not already done)

### Step 4 — Verify in the console

Confirm in each service console that no `kata-500-` resources remain.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility. Amazon Connect in particular continues to
> accrue charges for an active instance even when no calls are in progress.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.