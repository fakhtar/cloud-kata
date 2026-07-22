# kata-205 Hints — Lambda + SQS: Event Source Mapping & Error Handling

> ⚠️ **Spoiler warning.** Each hint section reveals progressively more detail.
> Try to solve each requirement on your own before opening a hint. The learning
> is in the struggle.

---

## How to use these hints

Hints are organized by requirement number matching the README. Each requirement
has up to three levels:

- **Hint 1** — a nudge in the right direction
- **Hint 2** — more specific guidance
- **Hint 3** — the exact approach (near-solution level)

---

## Requirement 1 — Processing queue

<details>
<summary>Hint 1 — What kind of queue</summary>

This is an ordinary **standard** SQS queue — nothing special about it on its
own. What makes it the "processing queue" is that the function will consume
from it and that it will carry a redrive policy (Requirement 3). Naming a queue
without a `.fifo` suffix makes it a standard queue, which is what you want here.

</details>

<details>
<summary>Hint 2 — Naming and the ARN you'll need later</summary>

The queue must be named exactly `kata-205-ProcessingQueue`. Once it exists,
note its **ARN** — you will need it when you wire up the event source mapping
in Requirement 6. The ARN looks like
`arn:aws:sqs:<region>:<account-id>:kata-205-ProcessingQueue`.

</details>

<details>
<summary>Hint 3 — CLI</summary>

```bash
aws sqs create-queue --queue-name kata-205-ProcessingQueue

# Fetch its ARN for later
aws sqs get-queue-attributes \
  --queue-url <processing-queue-url> \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text
```

Hold off on the visibility timeout for a moment — it interacts with the
function timeout, which is covered in Requirement 6, Hint 3.

</details>

---

## Requirement 2 — Dead-letter queue

<details>
<summary>Hint 1 — There is nothing structurally special about a DLQ</summary>

A dead-letter queue is just another standard queue. A queue only *becomes* a
dead-letter queue because a **source** queue names it as its redrive target
(Requirement 3). So create this one exactly like the processing queue, then
wire the relationship separately.

</details>

<details>
<summary>Hint 2 — Create it first</summary>

Create the DLQ **before** the processing queue, or at least before you set the
redrive policy — the redrive policy on the processing queue needs the DLQ's
ARN. A longer message retention on the DLQ is good practice, since the whole
point is to keep failed messages around long enough to inspect them.

</details>

<details>
<summary>Hint 3 — CLI</summary>

```bash
aws sqs create-queue \
  --queue-name kata-205-DeadLetterQueue \
  --attributes MessageRetentionPeriod=1209600   # 14 days, the maximum

# Fetch its ARN — you'll reference it in the redrive policy
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text
```

</details>

---

## Requirement 3 — Failed-message routing

<details>
<summary>Hint 1 — This lives on the source queue</summary>

The routing is configured on the **processing queue**, not on the dead-letter
queue. Look for the "dead-letter queue" / "redrive policy" settings on
`kata-205-ProcessingQueue`. The DLQ itself needs no configuration for this.

</details>

<details>
<summary>Hint 2 — Two pieces of information</summary>

A redrive policy has two parts: **which** queue failed messages go to (the DLQ
ARN) and **after how many attempts** they are moved there. That second number
is the maximum receive count — how many times a message can be received and
returned to the queue before SQS gives up and moves it to the DLQ.

</details>

<details>
<summary>Hint 3 — Exact shape</summary>

The `RedrivePolicy` queue attribute is a JSON object with exactly these keys:

```json
{"deadLetterTargetArn":"<dlq-arn>","maxReceiveCount":3}
```

Via CLI:

```bash
aws sqs set-queue-attributes \
  --queue-url <processing-queue-url> \
  --attributes '{"RedrivePolicy":"{\"deadLetterTargetArn\":\"<dlq-arn>\",\"maxReceiveCount\":\"3\"}"}'
```

The validator confirms the target ARN resolves to `kata-205-DeadLetterQueue`
and that `maxReceiveCount` is at least 1. A value of `3` is a sensible default.

</details>

---

## Requirement 4 — Processing function

<details>
<summary>Hint 1 — Use the code you were given</summary>

This is not a coding kata. Create a Python Lambda function named
`kata-205-ProcessorFunction` and paste in the handler from the README. It just
logs each message so the invocation is observable.

</details>

<details>
<summary>Hint 2 — The handler string must match how you deploy</summary>

The handler identifier is `<file>.<function>`. If you author in the console,
the default file is `lambda_function.py`, so the handler is
`lambda_function.lambda_handler`. If you deploy inline via CloudFormation, the
file is named `index`, so the handler is `index.lambda_handler`. Mismatching
these is the most common reason a function "exists but never runs."

</details>

<details>
<summary>Hint 3 — Runtime and the timeout that matters</summary>

Use a current Python runtime such as `python3.12`. The function's **timeout**
is worth setting deliberately — not because the validator checks it, but
because it constrains the queue's visibility timeout (Requirement 6, Hint 3).
A 30-second function timeout is comfortable for this workload.

</details>

---

## Requirement 5 — Function consume permissions

<details>
<summary>Hint 1 — Logging permission is not enough</summary>

A brand-new Lambda execution role can usually write logs but cannot touch SQS.
To drain a queue, the role needs permission to **receive**, **delete**, and
**read the attributes of** that queue. Without these, the event source mapping
cannot poll and the function never runs.

</details>

<details>
<summary>Hint 2 — There is a purpose-built managed policy</summary>

You don't have to hand-write these permissions. AWS provides a managed policy
specifically for Lambda functions that consume from SQS. It bundles the three
SQS actions above together with CloudWatch Logs write access, so it can replace
the basic execution policy entirely.

</details>

<details>
<summary>Hint 3 — Exact policy</summary>

Attach this managed policy to the function's execution role:

```
arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole
```

It grants `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`,
plus `logs:CreateLogGroup`, `logs:CreateLogStream`, and `logs:PutLogEvents`.

If you prefer a scoped custom policy instead, grant those three `sqs:` actions
on the `kata-205-ProcessingQueue` ARN. The validator accepts either the managed
policy or a custom policy that grants the receive action.

</details>

---

## Requirement 6 — Event source mapping

<details>
<summary>Hint 1 — What connects the queue to the function</summary>

The link between SQS and Lambda is an **event source mapping** (in the console
it appears as an SQS **trigger** on the function). You create it from the Lambda
side: add an SQS trigger and point it at `kata-205-ProcessingQueue`. Lambda then
polls the queue for you — there is no schedule or manual step to configure.

</details>

<details>
<summary>Hint 2 — It must be enabled, and it reads in batches</summary>

The mapping must be **enabled** to poll. It delivers messages to the function
in batches; the batch size sets how many messages arrive per invocation. The
validator checks that a mapping links the queue to the function and that its
state is `Enabled`.

</details>

<details>
<summary>Hint 3 — CLI, and the timeout gotcha that trips everyone</summary>

```bash
aws lambda create-event-source-mapping \
  --function-name kata-205-ProcessorFunction \
  --event-source-arn <processing-queue-arn> \
  --batch-size 10 \
  --enabled
```

For a standard SQS source the maximum batch size is **10** (going higher
requires a batching window).

**The gotcha:** the processing queue's **visibility timeout must be at least
the function timeout — AWS recommends at least 6x it.** With a 30-second
function timeout, set the queue visibility timeout to around 180 seconds. If it
is too low, a message becomes visible again while the function is still
processing it, so it gets picked up a second time and eventually lands in the
DLQ even though nothing actually failed.

If mapping creation fails with a message about the role not being allowed to
call `ReceiveMessage`, finish Requirement 5 first, then create the mapping —
the permission must exist before the mapping can be established.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-205-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

`CAPABILITY_NAMED_IAM` is required because the template creates an execution
role with an explicit name.

Then re-run `validate.sh`. A correctly deployed solution should score 6/6.
Study the solution to understand what you missed, then tear it down (delete the
CloudFormation stack) and try again from scratch.