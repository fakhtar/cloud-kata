# Contributing to CloudKata

Thank you for your interest in contributing to CloudKata. This guide covers everything you need to know to contribute a kata — from claiming an idea to submitting a pull request.

Read this guide fully before you start building. The first kata in the library was built by following this exact guide. If something is unclear or missing, open an issue.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [The Golden Rule](#the-golden-rule)
- [Resource Naming Convention](#resource-naming-convention)
- [Contribution Workflow](#contribution-workflow)
- [Kata Specification](#kata-specification)
  - [Folder Structure](#folder-structure)
  - [Metadata & Frontmatter](#metadata--frontmatter)
  - [LAB.md](#labmd)
  - [validate.sh](#validatesh)
  - [solution.yml](#solutionyml)
  - [prereqs.yml](#prereqsyml)
  - [cleanup.sh](#cleanupsh)
  - [HINTS.md](#hintsmd)
- [Quality Standards](#quality-standards)
- [Pull Request Checklist](#pull-request-checklist)
- [Kata Roadmap](#kata-roadmap)

---

## Code of Conduct

CloudKata is an open, welcoming project. Contributors are expected to be respectful and constructive in all interactions. Issues and pull requests that are disrespectful, hostile, or off-topic will be closed without discussion.

---

## The Golden Rule

> **A kata must be verifiable by running `solution.yml` and then `validate.sh`.**

Every kata ships with a CloudFormation solution template. When a user deploys `solution.yml` and runs `validate.sh`, the validator must pass 100%. If it does not, the kata is not ready to publish. This is non-negotiable — the solution template is the acceptance test for the kata itself.

---

## Resource Naming Convention

All AWS resources created as part of a kata must be prefixed with the kata ID.

**Format:** `kata-XXX-ResourceName`

**Examples for kata-100:**
- Lex bot: `kata-100-FoodOrderingBot`
- IAM role: `kata-100-LexRole`
- Lambda function: `kata-100-FulfillmentFunction`
- DynamoDB table: `kata-100-OrdersTable`

**Why this matters:**

- **Safe cleanup** — the cleanup script can target resources by prefix without risk of accidentally deleting unrelated resources in the user's AWS account
- **Reliable validation** — the validator can find resources by exact name without ambiguity
- **Account hygiene** — users may run multiple katas in the same account; prefixed names prevent collisions

This convention is mandatory and applies to:
- All resource names specified in `LAB.md` requirements
- All resource names in `validate.sh` checks
- All resource names in `solution.yml`
- All resource names targeted by `cleanup.sh`

---

## Contribution Workflow

### Step 1 — Claim the kata

Before you start building, open a GitHub issue to claim the kata you want to contribute.

- Check the [Kata Roadmap](#kata-roadmap) for planned katas
- Check open issues to make sure nobody has already claimed it
- Open a new issue with the title: `[Kata Claim] kata-XXX — Title`
- Wait for a maintainer to assign the issue to you before you start building

This prevents duplicated effort and ensures the kata fits the roadmap.

### Step 2 — Fork the repository

Fork `cloud-kata` to your own GitHub account and clone it locally.

```bash
git clone https://github.com/YOUR_USERNAME/cloud-kata.git
cd cloud-kata
```

### Step 3 — Copy the template

Copy the kata template folder and rename it to your kata ID.

```bash
cp -r templates/kata-template katas/kata-XXX
```

### Step 4 — Build the kata

Follow the [Kata Specification](#kata-specification) to build out all required files. Use the template files as your starting point.

As you build, test your validator against infrastructure you manually create, then test it again against your `solution.yml` deployment to confirm it passes 100%.

### Step 5 — Validate your own kata

Before submitting, you must:

1. Manually build the required infrastructure in your own AWS account
2. Run `validate.sh` and confirm it produces the expected results
3. Tear down the manual infrastructure
4. Deploy `solution.yml` via CloudFormation
5. Run `validate.sh` again and confirm it passes 100%
6. Run `cleanup.sh` and confirm all resources are removed cleanly

### Step 6 — Open a pull request

Push your branch and open a pull request against the `main` branch. Use the [Pull Request Checklist](#pull-request-checklist) to self-review before submitting.

Reference the issue you claimed in the PR description: `Closes #XX`

---

## Kata Specification

Every kata lives in its own folder under `katas/` and follows this exact structure.

### Folder Structure

```
katas/
└── kata-XXX/
    ├── LAB.md           # Required — kata instructions
    ├── validate.sh      # Required — CloudShell validator script
    ├── solution.yml     # Required — CloudFormation solution template
    ├── cleanup.sh       # Required — cleanup script
    ├── prereqs.yml      # Optional — prerequisite infrastructure template
    └── HINTS.md         # Optional — spoiler-gated hints
```

---

### Metadata & Frontmatter

Every `LAB.md` must begin with a metadata block. This is the single source of truth for kata metadata including tags.

```
---
id: kata-XXX
title: "Your Kata Title Here"
level: 100
type: depth
services:
  - lex-v2
tags:
  - conversational-ai
  - beginner
  - depth
estimated_time: 1 hour
estimated_cost: "$0.00 - $1.00"
author: Your Name
github: https://github.com/yourusername
---
```

**Field definitions:**

| Field | Required | Description |
|---|---|---|
| `id` | Yes | Kata ID matching the folder name e.g. `kata-100` |
| `title` | Yes | Full descriptive title |
| `level` | Yes | 100, 200, 300, 400, or 500 |
| `type` | Yes | `depth` or `breadth` |
| `services` | Yes | List of AWS services involved, lowercase hyphenated |
| `tags` | Yes | Descriptive tags for discoverability |
| `estimated_time` | Yes | Human time to complete e.g. `30 minutes`, `1 hour`, `2 hours` |
| `estimated_cost` | Yes | Cost range e.g. `"$0.00 - $1.00"` |
| `author` | Yes | Your name |
| `github` | Yes | Link to your GitHub profile |

---

### LAB.md

The lab instructions file. This is what the user reads and works from.

**Structure:**

```markdown
---
[frontmatter block]
---

# kata-XXX — Your Kata Title

## Overview
A 2-3 sentence description of what this kata covers and what the user will build.

## Prerequisites
- What the user needs before starting
- Any required IAM permissions
- Whether prereqs.yml must be deployed first

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~1 hour |
| 💰 Estimated Cost | ~$0.00 - $1.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your AWS
> region, account tier, and how quickly you complete the kata. If you leave
> infrastructure running beyond the kata session, costs will continue to
> accumulate. All charges are your responsibility. Always run cleanup
> instructions when finished.

## Requirements

This section is the heart of the kata. List every infrastructure requirement
the user must build. Write these as requirements, not steps. Do not tell the
user how to build — tell them what to build.

All resource names must follow the kata naming convention: `kata-XXX-ResourceName`

### Requirement 1 — [Name]
Description of what must exist and how it must be configured.
Resource name: `kata-XXX-ResourceName`

### Requirement 2 — [Name]
Description of what must exist and how it must be configured.
Resource name: `kata-XXX-ResourceName`

[Continue for all requirements]

## Running the Validator

Once you have built the required infrastructure, run the validator in AWS CloudShell:

\`\`\`bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
\`\`\`

The validator will check each requirement and report a score. A passing result
looks like this:

\`\`\`
✅ PASS — [Check description]
✅ PASS — [Check description]
❌ FAIL — [Check description]: [Reason]

Results: 7/8 checks passed (87%)
\`\`\`

## Cleanup

Always clean up your resources when you are finished. Follow these steps in order:

### Step 1 — Delete CloudFormation stacks (if applicable)
If you deployed `solution.yml` or `prereqs.yml`, delete those stacks first via
CloudFormation. Stack deletion will remove most resources automatically.

- Go to the AWS CloudFormation console
- Select the stack(s) created for this kata
- Choose Delete and wait for deletion to complete

### Step 2 — Run the cleanup script
Run the cleanup script to remove any resources not handled by CloudFormation,
or if you built the infrastructure manually without using the solution template:

\`\`\`bash
sed -i 's/\r//' cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
\`\`\`

### Step 3 — Verify in the console
Check the AWS console to confirm all resources have been removed.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility.

Refer to [HINTS.md](./HINTS.md) if you are stuck. The solution is available
in [solution.yml](./solution.yml).
```

**Writing good requirements:**

- Be specific about names, configurations, and values the validator will check
- All resource names must follow the `kata-XXX-ResourceName` naming convention
- Use exact resource names — the validator depends on them
- Do not provide step-by-step console instructions — give a spec, not a tutorial
- Each requirement should map to one or more validator checks

---

### validate.sh

The validator script runs in AWS CloudShell and checks the user's live infrastructure against the kata requirements.

**Standards:**

- Must run in AWS CloudShell with no additional dependencies beyond the AWS CLI
- Must use the AWS CLI — no Python, no external libraries
- Each check must be independent — a failure in one check must not block others
- Each check must print a clear `✅ PASS` or `❌ FAIL` message with a description
- On failure, print a specific reason that helps the user understand what is wrong
- Must print a final summary: `Results: X/Y checks passed (XX%)`
- Must handle AWS CLI errors gracefully — do not let a missing resource crash the script
- All resource name lookups must use the `kata-XXX-` prefix convention

**Template structure:**

```bash
#!/bin/bash
# =============================================================================
# CloudKata — kata-XXX Validator
# kata: kata-XXX
# title: Your Kata Title
# =============================================================================

set -euo pipefail

PASS=0
FAIL=0
TOTAL=0

pass() {
  echo "✅ PASS — $1"
  ((PASS++))
  ((TOTAL++))
}

fail() {
  echo "❌ FAIL — $1: $2"
  ((FAIL++))
  ((TOTAL++))
}

echo ""
echo "=================================================="
echo " CloudKata Validator — kata-XXX"
echo " Your Kata Title"
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# Check 1 — Description of what you are checking
# ------------------------------------------------------------------------------
RESULT=$(aws some-service describe-something --name "kata-XXX-ResourceName" --query 'Something' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$RESULT" != "NOT_FOUND" ]; then
  pass "Check description"
else
  fail "Check description" "Resource 'kata-XXX-ResourceName' not found or misconfigured"
fi

# Add additional checks following the same pattern

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "=================================================="
PERCENTAGE=$(( PASS * 100 / TOTAL ))
echo " Results: $PASS/$TOTAL checks passed ($PERCENTAGE%)"
echo "=================================================="
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
```

---

### solution.yml

A CloudFormation template that, when deployed, creates all infrastructure required to pass the validator at 100%.

**Standards:**

- Must be a valid CloudFormation template
- Must deploy successfully in a clean AWS account with standard permissions
- Must include a stack `Description` that references the kata ID and title
- Must include an `Outputs` section with key resource identifiers
- Must include resource tags: `Project: CloudKata` and `Kata: kata-XXX`
- All resource names must follow the `kata-XXX-ResourceName` naming convention and exactly match what the validator checks for
- Must be deployable via the AWS Console or CLI without modification

**Tagging standard:**

Every resource in `solution.yml` must include at minimum:

```yaml
Tags:
  - Key: Project
    Value: CloudKata
  - Key: Kata
    Value: kata-XXX
```

---

### prereqs.yml

Optional. Only include this file if the kata requires infrastructure that must exist before the user starts — for example, an existing Amazon Connect instance.

If included, `LAB.md` must clearly instruct the user to deploy `prereqs.yml` before starting the kata requirements.

**Standards:**

- Same tagging standard as `solution.yml`
- Same resource naming convention as all other kata files
- Must include clear `Outputs` for any resources the user will reference during the kata
- Must be deployable independently of `solution.yml`

---

### cleanup.sh

A script that removes any resources not automatically handled by CloudFormation stack deletion.

**Standards:**

- Must run in AWS CloudShell
- Must target resources using the `kata-XXX-` prefix to avoid deleting unrelated resources
- Must handle the case where resources do not exist — do not error on missing resources
- Must print a confirmation message for each deleted resource
- Must include a final message confirming cleanup is complete
- Must include a note reminding the user to verify in the AWS Console
- Must include a reminder at the top to delete CloudFormation stacks first if applicable

**Template structure:**

```bash
#!/bin/bash
# =============================================================================
# CloudKata — kata-XXX Cleanup
# =============================================================================
#
# IMPORTANT: If you deployed solution.yml or prereqs.yml, delete those
# CloudFormation stacks first before running this script.
# This script removes any resources not handled by CloudFormation stack
# deletion, or resources created manually without the solution template.
# =============================================================================

echo ""
echo "=================================================="
echo " CloudKata Cleanup — kata-XXX"
echo " Your Kata Title"
echo "=================================================="
echo ""
echo "NOTE: If you deployed solution.yml or prereqs.yml, please delete"
echo "those CloudFormation stacks first via the AWS Console or CLI."
echo ""

# Delete resources in reverse dependency order
# All resource names must use the kata-XXX- prefix
# Example:
echo "Deleting kata-XXX-ResourceName..."
aws some-service delete-something --name "kata-XXX-ResourceName" 2>/dev/null && \
  echo "✅ Deleted kata-XXX-ResourceName" || \
  echo "⚠️  kata-XXX-ResourceName not found or already deleted"

echo ""
echo "=================================================="
echo " Cleanup complete."
echo " Please verify in the AWS Console that all"
echo " resources have been removed."
echo "=================================================="
echo ""
```

---

### HINTS.md

Optional. A spoiler-gated hints file for users who are stuck.

Structure hints progressively — a small nudge first, more detail further down. Gate each hint so the user has to scroll deliberately to reveal it.

```markdown
# Hints — kata-XXX

> ⚠️ Spoilers below. Try to work through the requirements independently first.

---

## Hint 1 — [Topic]

<details>
<summary>Click to reveal hint</summary>

Your hint text here. Keep it directional, not prescriptive.

</details>

## Hint 2 — [Topic]

<details>
<summary>Click to reveal hint</summary>

Your hint text here.

</details>
```

---

## Quality Standards

Before submitting a pull request, your kata must meet all of the following standards:

- The kata has a clear, specific title that accurately describes what is being built
- `LAB.md` gives requirements, not step-by-step instructions
- All resource names in requirements follow the `kata-XXX-ResourceName` convention
- Every requirement in `LAB.md` maps to at least one check in `validate.sh`
- `validate.sh` passes 100% when `solution.yml` is deployed
- `validate.sh` produces meaningful failure messages that help the user self-diagnose
- `validate.sh` checks resources by their prefixed names only
- `solution.yml` deploys cleanly in a standard AWS account without modification
- All resources in `solution.yml` follow the naming convention and are tagged with `Project: CloudKata` and `Kata: kata-XXX`
- `cleanup.sh` targets resources by `kata-XXX-` prefix only
- `cleanup.sh` includes the CloudFormation stack deletion reminder
- `cleanup.sh` removes all resources without errors
- Cost and time estimates are realistic and documented in `LAB.md` frontmatter
- The cost warning is present and unmodified in `LAB.md`
- All files use consistent naming and follow the folder structure exactly

---

## Pull Request Checklist

Copy this checklist into your pull request description and check every item before submitting.

```
## Kata Submission Checklist

### Structure
- [ ] Kata folder is named correctly: `katas/kata-XXX/`
- [ ] All required files are present: LAB.md, validate.sh, solution.yml, cleanup.sh
- [ ] Optional files (prereqs.yml, HINTS.md) are included only if needed

### Resource Naming
- [ ] All resource names in LAB.md follow the kata-XXX-ResourceName convention
- [ ] All resource names in validate.sh match the naming convention exactly
- [ ] All resource names in solution.yml match the naming convention exactly
- [ ] cleanup.sh targets resources by kata-XXX- prefix only

### LAB.md
- [ ] Frontmatter is complete and all fields are populated
- [ ] Overview clearly describes what the user will build
- [ ] Requirements are written as a spec, not step-by-step instructions
- [ ] Cost and time estimates are included
- [ ] Cost warning is present and unmodified
- [ ] Validator usage instructions are included
- [ ] Cleanup instructions include CloudFormation stack deletion as Step 1
- [ ] Cleanup instructions include running cleanup.sh as Step 2
- [ ] Cleanup instructions include console verification as Step 3

### validate.sh
- [ ] Runs successfully in AWS CloudShell
- [ ] Each check prints a clear PASS or FAIL message
- [ ] Failure messages are specific and helpful
- [ ] Final summary line is present
- [ ] Script does not crash on missing resources

### solution.yml
- [ ] Deploys successfully in a clean AWS account
- [ ] All resource names follow the kata-XXX-ResourceName convention
- [ ] All resources are tagged with Project: CloudKata and Kata: kata-XXX
- [ ] Outputs section is present
- [ ] Running validate.sh after deploying solution.yml passes 100%

### cleanup.sh
- [ ] Includes CloudFormation stack deletion reminder at the top
- [ ] Targets resources by kata-XXX- prefix only
- [ ] Runs successfully in AWS CloudShell
- [ ] All resources are removed cleanly
- [ ] Script handles missing resources gracefully
- [ ] Completion message is present

### Self-Testing
- [ ] I manually built the infrastructure and ran validate.sh
- [ ] I deployed solution.yml and confirmed validate.sh passes 100%
- [ ] I ran cleanup.sh and confirmed all resources were removed
```

---

## Kata Roadmap

The following katas are planned for the CloudKata library. All are open for community contribution. Open an issue to claim one before you start building.

### 100 Level Kata

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| kata-100 | Amazon Lex V2 Basics — Bots, Intents & Slots | 100 | Depth | Lex V2 | Open |
| kata-101 | IAM Fundamentals — Roles, Policies & Trust Relationships | 100 | Depth | IAM | Open |
| kata-102 | Lambda Essentials — Functions, Triggers & Environment Variables | 100 | Depth | Lambda | Open |

### 200 Level Kata

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| kata-200 | Amazon Connect Basics — Instance, Hours of Operation & Queues | 200 | Depth | Connect | Open |
| kata-201 | DynamoDB Core — Tables, Keys, Indexes & Capacity Modes | 200 | Depth | DynamoDB | Open |
| kata-202 | Amazon Lex V2 Advanced — Versioning, Aliases & Lambda Fulfillment | 200 | Depth | Lex V2, Lambda | Open |

### 300 Level Kata

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| kata-300 | Serverless API — Lambda, API Gateway & DynamoDB | 300 | Breadth | Lambda, API Gateway, DynamoDB | Open |
| kata-301 | Amazon Connect Contact Flows — IVR Design & Lex Integration | 300 | Depth | Connect, Lex V2 | Open |
| kata-302 | AI-Powered IVR — Connect, Lex V2 & Lambda Fulfillment | 300 | Breadth | Connect, Lex V2, Lambda | Open |

### 400 Level Kata

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| kata-400 | Three-Tier Web App — CloudFront, ALB, EC2 & RDS in Multi-AZ | 400 | Breadth | CloudFront, ALB, EC2, RDS | Open |
| kata-401 | Amazon Connect Global Resiliency | 400 | Depth | Connect | Open |

### 500 Level Kata

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| kata-500 | Contact Center Platform — Connect, Lex V2, Lambda, DynamoDB & CloudWatch | 500 | Breadth | Connect, Lex V2, Lambda, DynamoDB, CloudWatch | Open |

**Status key:**
- **Open** — available for community contribution, open an issue to claim
- **In Progress** — claimed and actively being built
- **Published** — live in the library