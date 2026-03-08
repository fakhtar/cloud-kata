---
id: kata-100
title: "Amazon Lex V2 Basics — Bots, Intents & Slots"
level: 100
type: depth
services:
  - lex-v2
tags:
  - lex-v2
  - conversational-ai
  - bots
  - intents
  - slots
  - depth
  - beginner
estimated_time: 1 hour
estimated_cost: "$0.00"
author: Faisal Akhtar
github: https://github.com/faisalakhtar
---

# kata-100 — Amazon Lex V2 Basics: Bots, Intents & Slots

## Overview

In this kata you will build a functional Amazon Lex V2 chatbot for a food
ordering scenario. You will create a bot with two intents, a custom slot type,
and verify that the bot reaches an Available state and responds correctly to
test utterances. This kata covers the foundational building blocks of every
Lex V2 implementation: bots, intents, utterances, slots, and slot types.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage Amazon Lex V2 resources
- Familiarity with the AWS Console or CLI

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~1 hour |
| 💰 Estimated Cost | $0.00 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your
> AWS region, account tier, and how quickly you complete the kata. Amazon Lex
> V2 charges per request when the bot is invoked. If you leave the bot running
> and invoke it beyond this kata session, costs will accumulate. All charges
> are your responsibility. Always run cleanup instructions when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-100-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Bot

Create an Amazon Lex V2 bot with the following configuration:

- **Name:** `kata-100-FoodOrderingBot`
- **Language:** English (US) — `en_US`
- **Session timeout:** 5 minutes (300 seconds)
- **IAM role:** A service role that allows Amazon Lex to call AWS services on
  your behalf
- **Bot status:** Must reach `Available` — a bot that exists but has not been
  built will not pass validation

---

### Requirement 2 — Intent: OrderFood

Create an intent within the `kata-100-FoodOrderingBot` bot with the following
configuration:

- **Intent name:** `OrderFood`
- **Sample utterances:** At least 5 distinct sample utterances that a user
  might say to order food. Utterances must be varied and natural.
- **Slot:** The intent must contain a slot named `FoodItem` of type
  `kata-100-FoodItemType` (see Requirement 4)
- **Closing response:** A confirmation message that the order has been placed

---

### Requirement 3 — Intent: CancelOrder

Create a second intent within the `kata-100-FoodOrderingBot` bot with the
following configuration:

- **Intent name:** `CancelOrder`
- **Sample utterances:** At least 5 distinct sample utterances that a user
  might say to cancel an order. Utterances must be varied and natural.
- **Closing response:** A confirmation message that the order has been cancelled

---

### Requirement 4 — Custom Slot Type

Create a custom slot type with the following configuration:

- **Slot type name:** `kata-100-FoodItemType`
- **Values:** At least 4 food item values. Suggested values: `Pizza`,
  `Burger`, `Salad`, `Tacos`
- **Resolution strategy:** The slot type must use top resolution

---

### Requirement 5 — Bot Locale Build

After creating the bot, intents, and slot types, build the bot locale so the
bot reaches `Available` status. A bot that has not been built will fail
validation regardless of whether the intents and slots are correctly configured.


---

### Requirement 6 — Bot Alias

Create a bot alias with the following configuration:

- **Alias name:** `kata-100-TestAlias`
- **Bot version:** `DRAFT`
- **Locale:** `en_US` must be explicitly enabled on the alias

This alias is required for the validator to run runtime utterance tests. A bot
alias that does not have the `en_US` locale enabled will fail Check 8.
---

### Requirement 7 — Test Utterances

Your bot must respond correctly to the following test utterances when invoked
via the Lex V2 test console or CLI:

| Utterance | Expected Intent |
|---|---|
| `I want to order a pizza` | `OrderFood` |
| `Can I get a burger` | `OrderFood` |
| `Cancel my order` | `CancelOrder` |
| `I want to cancel` | `CancelOrder` |

The bot does not need a Lambda fulfillment function for this kata. Closing
responses configured on each intent are sufficient.

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and
upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure and reports a score.
A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-100
 Amazon Lex V2 Basics: Bots, Intents & Slots
==================================================

✅ PASS — Bot 'kata-100-FoodOrderingBot' exists
✅ PASS — Bot language is configured for en_US
✅ PASS — Bot status is Available
✅ PASS — Intent 'OrderFood' exists with sufficient utterances
✅ PASS — Intent 'CancelOrder' exists with sufficient utterances
✅ PASS — Slot 'FoodItem' exists on intent 'OrderFood'
✅ PASS — Custom slot type 'kata-100-FoodItemType' exists with sufficient values
✅ PASS — Bot responds correctly to test utterances

==================================================
 Results: 8/8 checks passed (100%)
==================================================

 🎉 Perfect score! All requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. Follow these steps
in order.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.
Stack deletion will remove most resources automatically.

- Go to the AWS CloudFormation console
- Select the stack created for this kata
- Choose **Delete** and wait for deletion to complete before proceeding

Via CLI:
```bash
aws cloudformation delete-stack --stack-name kata-100-solution
aws cloudformation wait stack-delete-complete --stack-name kata-100-solution
```

### Step 2 — Run the cleanup script

Run the cleanup script to remove any resources not handled by CloudFormation,
or if you built the infrastructure manually:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

### Step 3 — Verify in the console

Go to the Amazon Lex V2 console and confirm that `kata-100-FoodOrderingBot`
no longer exists.

> ⚠️ If you leave infrastructure running, costs will continue to accumulate
> and are your responsibility.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Deploying `solution.yml` and re-running `validate.sh` should produce a
score of 100%.