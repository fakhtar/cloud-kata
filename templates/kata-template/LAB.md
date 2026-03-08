---
id: kata-XXX
title: "Your Kata Title Here"
level: 100
type: depth
services:
  - service-name
tags:
  - tag-one
  - tag-two
estimated_time: 1 hour
estimated_cost: "$0.00 - $1.00"
author: Your Name
github: https://github.com/yourusername
---

# kata-XXX — Your Kata Title

## Overview

A 2-3 sentence description of what this kata covers and what the user will
build. Be specific about the AWS services involved and the end state the user
is working toward.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage: [list services here]
- [Add any other prerequisites here]
- [If prereqs.yml is required, state that clearly here]

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~1 hour |
| 💰 Estimated Cost | ~$0.00 - $1.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. If you
> leave infrastructure running beyond the kata session, costs will continue
> to accumulate. All charges are your responsibility. Always run cleanup
> instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-XXX-ResourceName`

You are given a spec, not a tutorial. Use the AWS console, CLI, IaC, or any
tools you choose to meet these requirements.

---

### Requirement 1 — [Requirement Name]

[Describe what must exist and how it must be configured. Be specific about
names, settings, and values the validator will check.]

Resource name: `kata-XXX-ResourceName`

---

### Requirement 2 — [Requirement Name]

[Describe what must exist and how it must be configured.]

Resource name: `kata-XXX-ResourceName`

---

### Requirement 3 — [Requirement Name]

[Describe what must exist and how it must be configured.]

Resource name: `kata-XXX-ResourceName`

---

[Add additional requirements as needed. Each requirement should map to one
or more checks in validate.sh]

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and run
the validator:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure against the kata requirements
and reports a score. A passing result looks like this:

```
==================================================
 CloudKata Validator — kata-XXX
 Your Kata Title
==================================================

✅ PASS — [Check description]
✅ PASS — [Check description]
❌ FAIL — [Check description]: [Reason]

==================================================
 Results: 7/8 checks passed (87%)
==================================================
```

A score of 100% means all requirements are met. Use the failure messages to
diagnose and fix any gaps, then re-run the validator.

---

## Cleanup

Always clean up your resources when you are finished. Follow these steps
in order.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml` or `prereqs.yml`, delete those stacks first
via CloudFormation. Stack deletion will remove most resources automatically.

- Go to the AWS CloudFormation console
- Select the stack(s) created for this kata
- Choose **Delete** and wait for deletion to complete before proceeding

### Step 2 — Run the cleanup script

Run the cleanup script to remove any resources not handled by CloudFormation,
or if you built the infrastructure manually without using the solution template:

```bash
sed -i 's/\r//' cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
```

### Step 3 — Verify in the console

Check the AWS console to confirm all resources prefixed with `kata-XXX-` have
been removed.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available as a CloudFormation template in
[solution.yml](./solution.yml). Deploying `solution.yml` and re-running
`validate.sh` should produce a score of 100%.