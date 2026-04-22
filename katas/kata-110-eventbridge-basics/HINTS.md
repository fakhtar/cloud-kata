# kata-110 Hints -- EventBridge Basics: Rules, Targets & Scheduling

> ⚠️ **Spoiler warning.** Each hint section reveals progressively more detail.
> Try to solve each requirement on your own before opening a hint. The learning
> is in the struggle.

---

## How to use these hints

Hints are organized by requirement number matching the README. Each requirement
has up to three levels:

- **Hint 1** -- a nudge in the right direction
- **Hint 2** -- more specific guidance
- **Hint 3** -- the exact approach (near-solution level)

---

## Requirement 1 -- SNS Topic

<details>
<summary>Hint 1 -- Where to find SNS</summary>

SNS topics are managed in the Amazon SNS console. Search for "SNS" in the
AWS console navigation bar. From the SNS dashboard, select **Topics** in
the left panel and then click **Create topic**.

</details>

<details>
<summary>Hint 2 -- Topic type</summary>

When creating a topic you will be asked to choose between Standard and FIFO.
Standard topics support high throughput and at-least-once delivery. FIFO topics
guarantee ordering and exactly-once delivery but have throughput limits. For
this kata, choose **Standard**.

</details>

<details>
<summary>Hint 3 -- Exact configuration</summary>

- **Type:** Standard
- **Topic name:** `kata-110-AlertTopic` (must be exact -- the validator checks this name)
- **Tags:** Add `Project = CloudKata` and `Kata = kata-110`

Leave all other settings at their defaults. You do not need to add any
subscriptions for this kata -- the validator only checks that the topic
exists and has the correct resource policy.

</details>

---

## Requirement 2 -- EventBridge Rule

<details>
<summary>Hint 1 -- Where to find EventBridge rules</summary>

Rules are managed in the Amazon EventBridge console. Search for "EventBridge"
in the AWS console navigation bar. From the EventBridge dashboard, select
**Rules** under **Buses** in the left panel. Make sure the event bus selector
at the top shows **default** before creating your rule.

</details>

<details>
<summary>Hint 2 -- Schedule expression syntax</summary>

EventBridge supports two schedule expression formats: `rate` expressions and
`cron` expressions. A rate expression uses the format `rate(value unit)` where
unit is `minute`, `minutes`, `hour`, `hours`, `day`, or `days`. For example,
`rate(5 minutes)` fires every five minutes. Note that `minute` (singular) is
only valid for a value of 1 -- use `minutes` (plural) for values greater than 1.

</details>

<details>
<summary>Hint 3 -- Exact configuration</summary>

- **Event bus:** `default`
- **Rule name:** `kata-110-ScheduledRule` (must be exact)
- **Rule type:** Schedule
- **Schedule expression:** `rate(5 minutes)` (must be exact -- the validator checks this string)
- **State:** Enabled
- **Tags:** Add `Project = CloudKata` and `Kata = kata-110`

The validator checks the schedule expression as a literal string match, so
`rate(5 minutes)` and `rate(5 minute)` are not equivalent -- use the plural
form.

</details>

---

## Requirement 3 -- Rule Target

<details>
<summary>Hint 1 -- Adding a target to a rule</summary>

After creating the rule you can add targets from the rule detail page under
the **Targets** tab, or you can add the target during rule creation in the
wizard. The target is the resource EventBridge will invoke each time the rule
fires. For this kata the target is the SNS topic you created in Requirement 1.

</details>

<details>
<summary>Hint 2 -- SNS topic policy for EventBridge</summary>

EventBridge uses resource-based policies to publish to SNS topics -- it does
not use an IAM execution role for this. You need to add a policy statement
directly to the SNS topic that grants the `events.amazonaws.com` service
principal permission to call `sns:Publish` on your topic. Without this policy,
EventBridge will fail silently -- the rule fires but no message is delivered.

To add the policy, go to the SNS console, select `kata-110-AlertTopic`,
open the **Access policy** tab, and edit the policy document to add the
required statement alongside the existing default statement.

</details>

<details>
<summary>Hint 3 -- Exact configuration</summary>

**Target settings:**
- **Target ID:** `kata-110-AlertTopicTarget` (must be exact -- the validator checks this)
- **Target ARN:** the ARN of `kata-110-AlertTopic`
- **RoleArn:** do not set -- SNS targets use resource-based policies, not IAM roles

**SNS topic policy statement to add:**

```json
{
  "Sid": "AllowEventBridgePublish",
  "Effect": "Allow",
  "Principal": {
    "Service": "events.amazonaws.com"
  },
  "Action": "sns:Publish",
  "Resource": "<ARN of kata-110-AlertTopic>",
  "Condition": {
    "ArnLike": {
      "aws:SourceArn": "arn:aws:events:<region>:<account-id>:rule/kata-110-ScheduledRule"
    }
  }
}
```

Replace `<ARN of kata-110-AlertTopic>`, `<region>`, and `<account-id>` with
your actual values. Add this statement to the existing `Statement` array in
the topic's access policy -- do not replace the default statement.

</details>

---

## General Troubleshooting

<details>
<summary>Check 1 failing -- SNS topic not found</summary>

The validator looks up the topic by searching for an ARN ending in
`:kata-110-AlertTopic`. Two common causes: (1) the topic was created in a
different region -- SNS topics are regional, so verify your CloudShell session
and your topic are in the same region; (2) the name has a typo or different
capitalisation -- names are case-sensitive.

</details>

<details>
<summary>Check 2 failing -- EventBridge rule not found</summary>

The validator calls `describe-rule` by exact name on the default event bus.
Verify the rule name is exactly `kata-110-ScheduledRule` (case-sensitive) and
that it was created on the **default** event bus, not a custom bus.

</details>

<details>
<summary>Check 3 failing -- wrong schedule expression</summary>

The validator checks the schedule expression as a literal string. The expected
value is `rate(5 minutes)` -- including the space, the plural `minutes`, and
no extra characters. Open the rule in the EventBridge console and confirm or
correct the schedule expression.

</details>

<details>
<summary>Check 5 failing -- target not set</summary>

The rule exists but `kata-110-AlertTopic` is not listed as a target. Go to
EventBridge → Rules → select `kata-110-ScheduledRule` → **Targets** tab →
**Add target** → select SNS topic → select `kata-110-AlertTopic` → set the
target ID to `kata-110-AlertTopicTarget` → save.

</details>

<details>
<summary>Check 6 failing -- topic policy missing EventBridge permission</summary>

The SNS topic does not have a policy statement granting `events.amazonaws.com`
permission to `sns:Publish`. Go to SNS → Topics → select `kata-110-AlertTopic`
→ **Access policy** tab → **Edit** → add the statement shown in Requirement 3,
Hint 3. Make sure you are adding to the `Statement` array, not replacing the
entire policy.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-110-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 6/6.
Study the solution to understand what you missed, then tear it down and try
again from scratch.