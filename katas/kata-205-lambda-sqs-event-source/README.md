---
id: kata-205
title: "Lambda + SQS — Event Source Mapping & Error Handling"
level: 200
type: breadth
services:
  - lambda
  - sqs
tags:
  - lambda
  - sqs
  - event-driven
  - event-source-mapping
  - dead-letter-queue
  - error-handling
  - breadth
  - intermediate
estimated_time: 1 hour
estimated_cost: "$0.00 - $1.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-205 — Lambda + SQS: Event Source Mapping & Error Handling

## Overview

In this kata you will build an event-driven message-processing pipeline in
which an AWS Lambda function automatically consumes messages from an Amazon SQS
queue. You will connect the queue to the function with an event source mapping,
grant the function the permissions it needs to consume from the queue, and add
a dead-letter queue so that messages which repeatedly fail processing are
captured instead of lost. This kata covers the core asynchronous worker
pattern behind most decoupled, resilient serverless systems: a queue absorbing
work, a function draining it in batches, and a safety net for failures.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage SQS queues, Lambda functions, IAM
  roles, event source mappings, and CloudWatch Logs
- Familiarity with the AWS Console or CLI

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~1 hour |
| 💰 Estimated Cost | ~$0.00 - $1.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. A modest
> number of messages and function invocations fall well within the AWS Free
> Tier; CloudWatch Logs storage may incur a negligible charge. If you leave
> infrastructure running beyond this kata session, costs will continue to
> accumulate. All charges are your responsibility. Always run cleanup
> instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-205-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Processing queue

Work items enter the system through a dedicated SQS queue.

- **Queue name:** `kata-205-ProcessingQueue`
- This queue is the source that the function drains.

---

### Requirement 2 — Dead-letter queue

Messages that cannot be processed must have somewhere to go instead of being
lost or retried forever.

- **Queue name:** `kata-205-DeadLetterQueue`
- This is a separate queue whose only job is to hold messages that failed
  processing so they can be inspected later.

---

### Requirement 3 — Failed-message routing

The processing queue must protect itself from poison messages.

- After a message has been received and returned to the processing queue a
  **bounded number of times without being successfully processed**, it must be
  moved automatically to `kata-205-DeadLetterQueue`.
- The routing must be a property of the processing queue itself — no custom
  code should be responsible for shuffling failed messages.

---

### Requirement 4 — Processing function

Messages must be consumed and handled by a Lambda function.

- **Function name:** `kata-205-ProcessorFunction`
- The function receives batches of messages and processes each one. For this
  kata it only needs to record that it handled each message, so its work is
  observable in logs — the function code is provided below (this is **not** a
  coding kata).

---

### Requirement 5 — Function consume permissions

The function must be allowed to drain the queue.

- The function's execution role must **permit it to receive messages from,
  delete messages from, and read the attributes of `kata-205-ProcessingQueue`.**
- Without these permissions the connection between the queue and the function
  cannot function, even when everything else is wired correctly.

---

### Requirement 6 — Event source mapping

The function must consume from the queue on its own, continuously.

- The function must be connected to `kata-205-ProcessingQueue` by an **active
  event source mapping** that delivers messages to the function in **batches**.
- Consumption must be automatic and ongoing: there must be no manual polling,
  schedule, or trigger step between a message arriving and the function
  receiving it.

---

## Function Code

This is not a coding kata. Deploy the following handler as the code for
`kata-205-ProcessorFunction`. It iterates the batch of SQS records and prints a
distinctive line per message so that processing is easy to observe in
CloudWatch Logs.

```python
def lambda_handler(event, context):
    records = event.get("Records", [])
    for record in records:
        message_id = record.get("messageId")
        body = record.get("body")
        print(f"kata-205 processed message {message_id}: {body}")
    return {"processed": len(records)}
```

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
 CloudKata Validator — kata-205
 Lambda + SQS: Event Source Mapping & Error Handling
==================================================

✅ PASS — SQS queue 'kata-205-ProcessingQueue' exists
✅ PASS — Dead-letter queue 'kata-205-DeadLetterQueue' exists
✅ PASS — Processing queue routes failed messages to the dead-letter queue
✅ PASS — Lambda function 'kata-205-ProcessorFunction' exists
✅ PASS — Function's execution role permits consuming from the queue
✅ PASS — Event source mapping connects the queue to the function and is enabled

==================================================
 Results: 6/6 checks passed (100%)
==================================================

 🎉 Perfect score! All requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. Follow these steps
in order.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.
Stack deletion removes the queues, the function, the event source mapping, and
the execution role automatically.

- Go to the AWS CloudFormation console
- Select the stack created for this kata
- Choose **Delete** and wait for deletion to complete before proceeding

Via CLI:
```bash
aws cloudformation delete-stack --stack-name kata-205-solution
aws cloudformation wait stack-delete-complete --stack-name kata-205-solution
```

### Step 2 — Manual Cleanup

If you created any resources manually via the console or the CLI, it is your
responsibility to delete them to avoid incurring ongoing costs. Work backwards
and remove: the event source mapping, `kata-205-ProcessorFunction`, its
execution role, both SQS queues, and the CloudWatch log group
`/aws/lambda/kata-205-ProcessorFunction`.

Read the instructions again and work backwards to ensure you have deleted all
created resources.

### Step 3 — Verify in the console

Confirm in the SQS and Lambda consoles that `kata-205-ProcessingQueue`,
`kata-205-DeadLetterQueue`, and `kata-205-ProcessorFunction` no longer exist.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.