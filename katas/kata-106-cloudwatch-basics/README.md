---
id: kata-106
title: "CloudWatch Basics — Billing Alarm & Alerting"
level: 100
type: depth
services:
  - cloudwatch
  - sns
tags:
  - cloudwatch
  - sns
  - billing
  - alarms
  - alerting
  - cost-management
  - depth
  - beginner
estimated_time: 30 minutes
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-106 — CloudWatch Basics: Billing Alarm & Alerting

## Overview

In this kata you will create a CloudWatch billing alarm that monitors your
estimated AWS charges and sends a notification when spending exceeds a
threshold. You will create an SNS topic as the alarm's notification target
and wire the two together.

This kata covers two foundational AWS concepts: CloudWatch metric alarms
and SNS topics. Setting up a billing alarm is one of the first things a
responsible AWS engineer does in a new account — this kata makes sure
you know how.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create CloudWatch alarms and SNS topics
- **Billing alerts must be enabled** in your AWS Billing console — see
  the note below before starting

---

## ⚠️ Important: Enable Billing Alerts First

AWS billing metrics are not available in CloudWatch by default. You must
enable billing alerts in the Billing and Cost Management console before
the `EstimatedCharges` metric becomes available.

**To enable billing alerts:**
1. Sign in to the AWS console
2. Navigate to **Billing and Cost Management** → **Billing Preferences**
3. Enable **Receive Billing Alerts**
4. Save preferences

After enabling, wait approximately 15 minutes before billing metric data
becomes available in CloudWatch.

> ℹ️ If you are using AWS Organizations or Consolidated Billing, billing
> alerts must be enabled from the Management/Payer account.

---

## ⚠️ Important: This Kata Must Be Built in us-east-1

AWS billing metrics are only published to CloudWatch in the **us-east-1**
region, regardless of where your workloads run. The alarm, the SNS topic,
and the CloudFormation stack must all be created in **us-east-1**.

The validator explicitly targets us-east-1 when checking your resources.
Resources created in any other region will not be found.

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~30 minutes |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** CloudWatch alarms and SNS topics themselves are
> either free or negligible in cost at this scale. The alarm monitors
> your billing — it does not incur the charges it monitors. All charges
> are your responsibility.

---

## Requirements

Build the following infrastructure in your AWS account in **us-east-1**.
All resource names must follow the naming convention: `kata-106-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — SNS Topic

Create an SNS topic that will receive notifications when the billing alarm
triggers:

- **Topic name:** `kata-106-BillingAlertTopic`
- **Region:** us-east-1

---

### Requirement 2 — CloudWatch Billing Alarm

Create a CloudWatch alarm with the following configuration:

- **Alarm name:** `kata-106-BillingAlarm`
- **Metric:** The AWS billing estimated charges metric
- **Namespace:** The alarm must monitor the AWS Billing namespace
- **Dimension:** The alarm must be scoped to the account-level total
  charges in USD — not filtered to a specific service
- **Threshold:** A threshold of your choice — any positive dollar amount
  will pass validation
- **Alarm action:** The alarm must notify `kata-106-BillingAlertTopic`
  when in ALARM state
- **Region:** us-east-1

---

### Requirement 3 — Tags

Tag the SNS topic with the standard CloudKata tags:

- `Project: CloudKata`
- `Kata: kata-106`

> ℹ️ CloudWatch alarms do not support tags via the standard AWS tagging
> API in all configurations. Tagging the SNS topic is sufficient for
> this requirement.

---

## Running the Validator

The validator must be run from AWS CloudShell in **us-east-1**. If your
default CloudShell region is different, switch regions before running.

Upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-106
 CloudWatch Basics: Billing Alarm & Alerting
==================================================

✅ PASS — SNS topic 'kata-106-BillingAlertTopic' exists in us-east-1
✅ PASS — Alarm 'kata-106-BillingAlarm' exists in us-east-1
✅ PASS — Alarm monitors the AWS/Billing namespace
✅ PASS — Alarm monitors the EstimatedCharges metric
✅ PASS — Alarm dimension is scoped to Currency: USD
✅ PASS — Alarm threshold is a positive value
✅ PASS — Alarm action points to kata-106-BillingAlertTopic
✅ PASS — Required tags are present on SNS topic

==================================================
 Results: 8/8 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-106 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack in **us-east-1**:

```bash
aws cloudformation delete-stack \
  --stack-name kata-106-solution \
  --region us-east-1

aws cloudformation wait stack-delete-complete \
  --stack-name kata-106-solution \
  --region us-east-1
```

### Step 2 — Manual Cleanup

If you created resources manually, delete them in us-east-1:

```bash
# Delete the alarm
aws cloudwatch delete-alarms \
  --alarm-names kata-106-BillingAlarm \
  --region us-east-1

# Delete the SNS topic (replace with your topic ARN)
aws sns delete-topic \
  --topic-arn <TOPIC_ARN> \
  --region us-east-1
```

### Step 3 — Verify in the console

Switch to us-east-1 in the console and confirm the alarm and topic no
longer exist.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.