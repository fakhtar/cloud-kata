# kata-106 Hints — CloudWatch Basics: Billing Alarm & Alerting

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

## Before You Start — Prerequisite Checks

<details>
<summary>Billing alerts not showing in CloudWatch</summary>

If you cannot find billing metrics in CloudWatch, billing alerts have not
been enabled in your account. Navigate to **Billing and Cost Management** →
**Billing Preferences** → enable **Receive Billing Alerts** → save. Wait
approximately 15 minutes before billing metric data becomes available.

If you are using AWS Organizations, this must be enabled from the
Management/Payer account — not from a member account.

</details>

<details>
<summary>Resources must be in us-east-1</summary>

AWS billing metrics are only published to CloudWatch in us-east-1. If you
create the alarm in any other region, the metric will not be available and
the alarm will stay in INSUFFICIENT_DATA state. Make sure your CloudShell
session, console region, and CLI default region are all set to us-east-1
before building.

</details>

---

## Requirement 1 — SNS Topic

<details>
<summary>Hint 1 — What SNS topics are for</summary>

Amazon SNS (Simple Notification Service) is a pub/sub messaging service.
A CloudWatch alarm cannot send an email directly — it sends a message to
an SNS topic, and the topic delivers it to subscribers. For this kata you
need the topic to exist and be wired to the alarm. Adding an email
subscription is optional and not validated.

</details>

<details>
<summary>Hint 2 — Creating the topic</summary>

In the SNS console, choose **Topics** → **Create topic**. Select
**Standard** type (not FIFO). Name it exactly `kata-106-BillingAlertTopic`.
Make sure you are in us-east-1 before creating it.

</details>

<details>
<summary>Hint 3 — Adding tags</summary>

Tags can be added during topic creation or after. Navigate to the topic →
**Tags** tab → **Edit**. Add both required tags:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-106`

Tags are case-sensitive. The validator checks both keys and values exactly.

</details>

---

## Requirement 2 — CloudWatch Billing Alarm

<details>
<summary>Hint 1 — Finding the billing metric</summary>

In the CloudWatch console, navigate to **Alarms** → **Create alarm** →
**Select metric**. Look for the **Billing** section. If you do not see it,
billing alerts have not been enabled — see the prerequisite section above.
Make sure you are in us-east-1.

</details>

<details>
<summary>Hint 2 — Metric configuration</summary>

The metric you want is `EstimatedCharges` in the `AWS/Billing` namespace.
When selecting the metric, you will see options to filter by service.
For this kata select the account-level total — the option that shows
`Currency: USD` as the dimension without any service filter. A
service-specific alarm will fail Check 5.

</details>

<details>
<summary>Hint 3 — Alarm configuration details</summary>

Configure the alarm as follows:

- **Metric:** `EstimatedCharges`, namespace `AWS/Billing`
- **Dimension:** `Currency: USD` only — no service dimension
- **Statistic:** Maximum (billing charges only increase, Maximum gives
  you the running total)
- **Period:** 6 hours (21600 seconds) — billing metrics publish every
  6 hours
- **Threshold:** Any positive dollar amount of your choice
- **Comparison:** Greater than threshold
- **Evaluation periods:** 1
- **Alarm action:** Select or enter your SNS topic ARN for
  `kata-106-BillingAlertTopic`
- **Alarm name:** Must be exactly `kata-106-BillingAlarm`

</details>

---

## Requirement 3 — Tags

<details>
<summary>Hint 1 — Tag the SNS topic not the alarm</summary>

CloudWatch alarms have limited tagging support in some configurations.
For this kata, tag the SNS topic `kata-106-BillingAlertTopic` — not the
alarm. The validator checks tags on the SNS topic only.

</details>

<details>
<summary>Hint 2 — Exact tag values</summary>

Tags are case-sensitive. The validator checks for these exact values:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-106`

</details>

---

## General Troubleshooting

<details>
<summary>Check 2 failing — alarm not found</summary>

The validator looks for the alarm by name in us-east-1. Common causes:
(1) the alarm was created in a different region — switch to us-east-1 in
the console and check; (2) the alarm name has a typo — it must be exactly
`kata-106-BillingAlarm`. Confirm with:

```bash
aws cloudwatch describe-alarms \
  --alarm-names kata-106-BillingAlarm \
  --region us-east-1 \
  --query 'MetricAlarms[0].AlarmName'
```

</details>

<details>
<summary>Check 5 failing — wrong dimension</summary>

The alarm is scoped to a specific service instead of the account total.
When creating the alarm, make sure you select the `EstimatedCharges` metric
with only the `Currency: USD` dimension. If you selected a service-specific
metric (e.g. AmazonEC2), delete the alarm and recreate it selecting the
account-level total. The validator will tell you which service dimension
it found.

</details>

<details>
<summary>Alarm stuck in INSUFFICIENT_DATA</summary>

This is normal for a new billing alarm if billing data has not been
published yet. Billing metrics update approximately every 6 hours. The
alarm state does not affect the validator — the validator checks
configuration, not alarm state. An alarm in INSUFFICIENT_DATA will still
pass all 8 checks if configured correctly.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-106-solution \
  --region us-east-1
```

Then re-run `validate.sh`. A correctly deployed solution should score 8/8.
Study the solution to understand what you missed, then tear it down and
try again from scratch.