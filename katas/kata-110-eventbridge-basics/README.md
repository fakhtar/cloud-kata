---
id: kata-110
title: "EventBridge Basics -- Rules, Targets & Scheduling"
level: 100
type: depth
services:
  - eventbridge
  - sns
tags:
  - eventbridge
  - sns
  - scheduling
  - depth
  - beginner
estimated_time: 30 minutes
estimated_cost: "$0.00 - $0.01"
author: Your Name
github: https://github.com/fakhtar
---

# kata-110 -- EventBridge Basics: Rules, Targets & Scheduling

## Overview

In this kata you will build a foundational Amazon EventBridge setup covering the
three core concepts of event-driven scheduling: a scheduled rule, an SNS topic
as the target, and the resource-based policy that permits EventBridge to publish
to it. You will configure a rule on the default event bus that fires on a fixed
rate and routes invocations to an SNS topic, giving you a working end-to-end
scheduled notification pipeline.

This kata uses only the default EventBridge event bus. No custom event bus is
required.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage EventBridge rules and SNS topics

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~30 minutes |
| 💰 Estimated Cost | ~$0.00 - $0.01 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your AWS
> region, account tier, and how quickly you complete the kata. If you leave
> infrastructure running beyond the kata session, costs will continue to
> accumulate. All charges are your responsibility. Always run cleanup
> instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names must
follow the naming convention: `kata-110-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation, use
AI assistants, or search the web -- whatever you would use on the job.

---

### Requirement 1 -- SNS Topic

Create an SNS standard topic with the following configuration:

- **Topic name:** `kata-110-AlertTopic`
- **Tags:** `Project: CloudKata` and `Kata: kata-110`

---

### Requirement 2 -- EventBridge Rule

Create a scheduled EventBridge rule with the following configuration:

- **Rule name:** `kata-110-ScheduledRule`
- **Schedule:** Fires every 5 minutes
- **State:** Enabled
- **Tags:** `Project: CloudKata` and `Kata: kata-110`

---

### Requirement 3 -- Rule Target

Configure the EventBridge rule to deliver to the SNS topic:

- **Target:** `kata-110-AlertTopic`
- **Target ID:** `kata-110-AlertTopicTarget`

EventBridge requires permission to publish to the SNS topic. The SNS topic must
have a resource-based policy that grants EventBridge publish access, scoped to
this rule.

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and upload
or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure and reports a score. A fully
passing result looks like this:

```
==================================================
 CloudKata Validator -- kata-110
 EventBridge Basics: Rules, Targets & Scheduling
==================================================

✅ PASS -- SNS topic 'kata-110-AlertTopic' exists
✅ PASS -- EventBridge rule 'kata-110-ScheduledRule' exists
✅ PASS -- Rule schedule expression is 'rate(5 minutes)'
✅ PASS -- Rule state is ENABLED
✅ PASS -- Rule target is set to 'kata-110-AlertTopic'
✅ PASS -- SNS topic policy grants EventBridge publish permission

==================================================
 Results: 6/6 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-110 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 -- Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.
Stack deletion will remove the EventBridge rule and SNS topic automatically.

- Go to the AWS CloudFormation console
- Select the stack created for this kata
- Choose **Delete** and wait for deletion to complete

Via CLI:
```bash
aws cloudformation delete-stack --stack-name kata-110-solution
aws cloudformation wait stack-delete-complete --stack-name kata-110-solution
```

### Step 2 -- Manual Cleanup

If you created resources manually, delete in this order:

1. **Remove the EventBridge rule target** -- a rule with targets cannot be
   deleted until all targets are removed first. Go to EventBridge → Rules,
   select `kata-110-ScheduledRule`, open the **Targets** tab, select the
   target, and choose **Remove**.
2. **Delete the EventBridge rule** -- once all targets are removed, select
   `kata-110-ScheduledRule` and choose **Delete**.
3. **Delete the SNS topic** -- go to SNS → Topics, select
   `kata-110-AlertTopic`, and choose **Delete**.

### Step 3 -- Verify in the console

Go to EventBridge → Rules and confirm `kata-110-ScheduledRule` no longer
exists. Go to SNS → Topics and confirm `kata-110-AlertTopic` no longer exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml). Deploying
`solution.yml` and re-running `validate.sh` should produce a score of 100%.