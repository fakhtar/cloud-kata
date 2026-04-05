# kata-107 Hints — SQS Basics: Queues, Visibility & Dead-Letter Queues

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

## Requirement 1 — Primary Queue

<details>
<summary>Hint 1 — Queue type</summary>

Amazon SQS offers two queue types: Standard and FIFO. This kata requires a
Standard queue. If you accidentally create a FIFO queue, you cannot convert
it — you must delete it and recreate it. Note that SQS enforces a 60-second
cooldown before a deleted queue name can be reused.

</details>

<details>
<summary>Hint 2 — The attribute you need to configure</summary>

The requirement describes a window of time during which a received message is
hidden from other consumers. Look up the SQS attribute that controls this
behavior and how its default value is defined.

</details>

<details>
<summary>Hint 3 — CLI approach</summary>

The attribute is `VisibilityTimeout`. The default is 30 seconds. Set it to
any value other than 30 to satisfy the validator.

```bash
aws sqs create-queue \
  --queue-name kata-107-PrimaryQueue \
  --attributes VisibilityTimeout=60 \
  --tags Project=CloudKata,Kata=kata-107
```

If you already created the queue without it, you can update in place:

```bash
PRIMARY_URL=$(aws sqs get-queue-url --queue-name kata-107-PrimaryQueue --query QueueUrl --output text)
aws sqs set-queue-attributes \
  --queue-url "$PRIMARY_URL" \
  --attributes VisibilityTimeout=60
```

</details>

---

## Requirement 2 — Secondary Queue

<details>
<summary>Hint 1 — Nothing special here</summary>

The secondary queue is a plain standard SQS queue. What makes it serve a
specific purpose is how the primary queue is configured to use it — not
anything you set on the secondary queue itself.

</details>

<details>
<summary>Hint 2 — Order of creation matters</summary>

Create the secondary queue before the primary queue. You will need its ARN
when configuring the primary queue, and the ARN is only available after the
queue exists.

</details>

<details>
<summary>Hint 3 — CLI approach</summary>

```bash
aws sqs create-queue \
  --queue-name kata-107-SecondaryQueue \
  --tags Project=CloudKata,Kata=kata-107
```

Retrieve its ARN for use in Requirement 3:

```bash
SECONDARY_URL=$(aws sqs get-queue-url --queue-name kata-107-SecondaryQueue --query QueueUrl --output text)
SECONDARY_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$SECONDARY_URL" \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)
echo "$SECONDARY_ARN"
```

</details>

---

## Requirement 3 — Message Durability

<details>
<summary>Hint 1 — What mechanism handles this</summary>

SQS has a built-in mechanism for routing messages that have been received too
many times without being deleted. Research how SQS handles messages that a
consumer repeatedly fails to process. The answer is a queue configuration
attribute, not application code.

</details>

<details>
<summary>Hint 2 — What you need to configure</summary>

The mechanism is called a redrive policy. It is set as an attribute on the
primary queue — not on the secondary queue. It requires two pieces of
information: the ARN of the queue where failed messages should be sent, and
the maximum number of times a message can be received before it is routed
there.

</details>

<details>
<summary>Hint 3 — CLI approach</summary>

Retrieve the secondary queue ARN first (see Requirement 2, Hint 3), then
apply the redrive policy to the primary queue:

```bash
PRIMARY_URL=$(aws sqs get-queue-url --queue-name kata-107-PrimaryQueue --query QueueUrl --output text)

aws sqs set-queue-attributes \
  --queue-url "$PRIMARY_URL" \
  --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${SECONDARY_ARN}\\\",\\\"maxReceiveCount\\\":3}\"}"
```

Note the double JSON encoding — `RedrivePolicy` is a string attribute that
itself contains a JSON string. The console handles this automatically.

Verify it was applied:

```bash
aws sqs get-queue-attributes \
  --queue-url "$PRIMARY_URL" \
  --attribute-names RedrivePolicy
```

</details>

---

## Requirement 4 — Tagging

<details>
<summary>Hint 1 — Tag keys are case-sensitive</summary>

The validator checks for `Project` (capital P) and `Kata` (capital K).
Casing must match exactly.

</details>

<details>
<summary>Hint 2 — Tagging after creation</summary>

If you forgot to tag at creation time, you can add tags to an existing queue
without recreating it using `aws sqs tag-queue`.

</details>

<details>
<summary>Hint 3 — CLI approach</summary>

```bash
PRIMARY_URL=$(aws sqs get-queue-url --queue-name kata-107-PrimaryQueue --query QueueUrl --output text)
SECONDARY_URL=$(aws sqs get-queue-url --queue-name kata-107-SecondaryQueue --query QueueUrl --output text)

aws sqs tag-queue --queue-url "$PRIMARY_URL" --tags Project=CloudKata,Kata=kata-107
aws sqs tag-queue --queue-url "$SECONDARY_URL" --tags Project=CloudKata,Kata=kata-107
```

Verify:

```bash
aws sqs list-queue-tags --queue-url "$PRIMARY_URL"
aws sqs list-queue-tags --queue-url "$SECONDARY_URL"
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-107-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 7/7.
Study the solution to understand what you missed, then tear it down and
try again from scratch.

# kata-107 Hints — SQS Basics: Queues, Visibility & Dead-Letter Queues

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

## Requirement 1 — Primary Queue

<details>
<summary>Hint 1 — Queue type</summary>

Amazon SQS offers two queue types. This kata requires the simpler of the two.
If you create the wrong type, you cannot convert it — you must delete and
recreate it.

</details>

<details>
<summary>Hint 2 — The attribute you need</summary>

There is a specific SQS queue attribute that controls how long a received
message is hidden from other consumers. Look it up. Pay attention to what
its default value is — the validator checks that you have set it to something
other than that default.

</details>

<details>
<summary>Hint 3 — Narrowing it down</summary>

The attribute is called `VisibilityTimeout`. The default is 30 seconds. Set
it to any value other than 30. You can set it at creation time or update it
on an existing queue without recreating it.

</details>

---

## Requirement 2 — Secondary Queue

<details>
<summary>Hint 1 — Nothing special here</summary>

The secondary queue is a plain standard SQS queue with no special
configuration. What makes it useful is entirely determined by how the primary
queue is configured to interact with it.

</details>

<details>
<summary>Hint 2 — Order matters</summary>

Create the secondary queue before the primary queue. You will need something
from the secondary queue when configuring the primary queue, and that
something is only available after the secondary queue exists.

</details>

<details>
<summary>Hint 3 — What you need from it</summary>

You will need the secondary queue's ARN — not its URL — when configuring
Requirement 3. The ARN is available in the console under queue details, or
via the CLI using `get-queue-attributes`.

</details>

---

## Requirement 3 — Message Durability

<details>
<summary>Hint 1 — This is a queue configuration, not application code</summary>

SQS has a native built-in mechanism for handling messages that a consumer
repeatedly fails to process. You do not need a Lambda function or any
application logic. Research how SQS routes messages that have been received
too many times without being deleted.

</details>

<details>
<summary>Hint 2 — Where the configuration lives</summary>

The configuration goes on the primary queue, not the secondary queue. It is
a single attribute that references the secondary queue by ARN and specifies
a threshold. When a message exceeds that threshold, SQS moves it
automatically.

</details>

<details>
<summary>Hint 3 — What it's called</summary>

The attribute is called a redrive policy. It takes two values: the ARN of
the destination queue, and the maximum number of times a message can be
received before it is redirected. Both must be explicitly set. Note that
in the CLI and CloudFormation, the redrive policy is expressed as a
JSON string, not a native JSON object — this is a common source of errors.

</details>

---

## Requirement 4 — Tagging

<details>
<summary>Hint 1 — Tags are case-sensitive</summary>

The validator checks for exact key and value casing. `project` and `Project`
are different tags. Make sure your keys and values match the requirement
exactly.

</details>

<details>
<summary>Hint 2 — You can tag after creation</summary>

If you forgot to tag at creation time, you do not need to recreate the queues.
SQS supports adding and updating tags on existing queues independently of
other attributes.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-107-solution
```

Run `validate.sh`, and confirm a score of 7/7. Then tear it down
and try again from scratch. Study the solution to understand what you missed.