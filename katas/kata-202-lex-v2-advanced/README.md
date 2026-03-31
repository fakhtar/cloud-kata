---
id: kata-202
title: "Amazon Lex V2 Advanced — Versioning, Aliases & Lambda Fulfillment"
level: 200
type: depth
services:
  - lex-v2
  - lambda
tags:
  - lex-v2
  - lambda
  - conversational-ai
  - versioning
  - aliases
  - fulfillment
  - depth
  - foundational
estimated_time: 1.5 hours
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/fakhtar
---

# kata-202 — Amazon Lex V2 Advanced: Versioning, Aliases & Lambda Fulfillment

## Overview

In this kata you will build on the foundation of kata-100 by introducing
three advanced Lex V2 concepts: bot versioning, alias management, and Lambda
fulfillment. You will publish a named bot version from the DRAFT, create a
production alias that points to that version, and wire a Lambda function so
that the bot invokes it to fulfill the OrderFood intent.

This kata covers how Lex V2 separates bot development (DRAFT) from deployment
(published versions and aliases), and how Lambda fulfillment changes the
conversation flow from static closing responses to dynamic, code-driven
responses.

> ℹ️ This kata builds on the scenario from kata-100. Familiarity with Lex V2
> bots, intents, slots, and slot types is assumed. If you have not completed
> kata-100, consider doing so first.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Lex V2 bots, Lambda functions, and
  IAM roles
- Completion of kata-100 or equivalent Lex V2 experience

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~1.5 hours |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Amazon Lex V2 charges per
> request when the bot is invoked. Lambda charges per invocation and
> compute time. At this scale both are negligible. All charges are your
> responsibility. Always run cleanup instructions when finished.

---

## Function Code

This is not a coding kata. Copy and paste the following Lambda function
code exactly as provided. The validator will invoke your bot and check
that the Lambda fulfillment response is returned correctly — modifying
the code may cause validation to fail.

```python
import json

def lambda_handler(event, context):
    intent_name = event['sessionState']['intent']['name']
    slots = event['sessionState']['intent']['slots']

    if intent_name == 'OrderFood':
        food_item = None
        if slots.get('FoodItem') and slots['FoodItem'].get('value'):
            food_item = slots['FoodItem']['value']['interpretedValue']

        message = f"Got it! Your order for {food_item} has been placed." \
            if food_item else "Your food order has been placed."

        return {
            'sessionState': {
                'dialogAction': {'type': 'Close'},
                'intent': {
                    'name': intent_name,
                    'state': 'Fulfilled'
                }
            },
            'messages': [
                {
                    'contentType': 'PlainText',
                    'content': message
                }
            ]
        }

    return {
        'sessionState': {
            'dialogAction': {'type': 'Close'},
            'intent': {
                'name': intent_name,
                'state': 'Fulfilled'
            }
        },
        'messages': [
            {
                'contentType': 'PlainText',
                'content': 'Your request has been processed.'
            }
        ]
    }
```

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-202-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Lambda Function

Create a Lambda function using the code provided above:

- **Function name:** `kata-202-FulfillmentFunction`
- **Runtime:** Python 3.12
- **Execution role:** A role that allows Lambda to write logs to CloudWatch
  Logs

---

### Requirement 2 — Lex V2 Bot

Create an Amazon Lex V2 bot with the same structure as kata-100 but with
Lambda fulfillment enabled on the OrderFood intent:

- **Bot name:** `kata-202-FoodOrderingBot`
- **Language:** English (US)
- **Session timeout:** 5 minutes
- **Intent:** `OrderFood` with at least 5 sample utterances, a `FoodItem`
  slot, and fulfillment configured to invoke a Lambda function
- **Intent:** `CancelOrder` with at least 5 sample utterances
- **Slot type:** `kata-202-FoodItemType` with at least 4 values
- **Bot status:** Must reach `Available`


---

### Requirement 3 — Bot Version

Publish a numbered version of the bot from the DRAFT:

- The version must be a published numeric version — not DRAFT
- The version must be based on the DRAFT locale for `en_US`

---

### Requirement 4 — Production Alias

Create a bot alias that points to the published version:

- **Alias name:** `kata-202-ProductionAlias`
- **Bot version:** Must point to the published numeric version from
  Requirement 3 — not DRAFT
- **Locale:** `en_US` must be explicitly enabled on the alias
- **Lambda:** `kata-202-FulfillmentFunction` must be configured as the
  code hook for the `en_US` locale on this alias

---

### Requirement 5 — Lambda Permission

The Lex bot alias must have permission to invoke the Lambda function.
Without this permission, Lex cannot call your function at runtime even
if it is configured on the alias.

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
 CloudKata Validator — kata-202
 Amazon Lex V2 Advanced: Versioning, Aliases & Lambda Fulfillment
==================================================

✅ PASS — Lambda function 'kata-202-FulfillmentFunction' exists
✅ PASS — Bot 'kata-202-FoodOrderingBot' exists
✅ PASS — Bot status is Available
✅ PASS — OrderFood intent has fulfillment invocation enabled
✅ PASS — A published numeric bot version exists
✅ PASS — Alias 'kata-202-ProductionAlias' exists
✅ PASS — Alias points to a published numeric version
✅ PASS — Lambda is configured as code hook on the alias
✅ PASS — Bot responds correctly via production alias

==================================================
 Results: 9/9 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-202 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.

```bash
aws cloudformation delete-stack --stack-name kata-202-solution
aws cloudformation wait stack-delete-complete --stack-name kata-202-solution
```

### Step 2 — Manual Cleanup

If you created resources manually, delete them in this order:

1. Delete the bot alias `kata-202-ProductionAlias`
2. Delete the bot version
3. Delete the bot `kata-202-FoodOrderingBot`
4. Delete the Lambda function `kata-202-FulfillmentFunction`
5. Delete the Lambda execution role

### Step 3 — Verify in the console

Go to the Amazon Lex V2 console and confirm that `kata-202-FoodOrderingBot`
no longer exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.