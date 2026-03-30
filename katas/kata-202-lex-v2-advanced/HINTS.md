# kata-202 Hints — Amazon Lex V2 Advanced: Versioning, Aliases & Lambda Fulfillment

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

## Requirement 1 — Lambda Function

<details>
<summary>Hint 1 — Runtime and handler</summary>

The function code uses `lambda_handler` as the function name and reads from
`event['sessionState']` — this is the Lex V2 runtime event format. Use
Python 3.12 as the runtime. The handler must be set to `index.lambda_handler`
if you paste the code inline via CloudFormation, since CFN names the file
`index.py` when using the `ZipFile` property.

</details>

<details>
<summary>Hint 2 — Execution role</summary>

The function needs an execution role that allows it to write logs to
CloudWatch Logs. The AWS managed policy `AWSLambdaBasicExecutionRole`
(full ARN: `arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole`)
provides exactly this. See kata-102 for the full IAM execution role pattern.

</details>

<details>
<summary>Hint 3 — Deploy the function first</summary>

After creating the function via the console, make sure to click **Deploy**
to save the code. A function that exists but has not been deployed will
run the previous (default) code and may not return the expected Lex V2
response format, causing Check 9 to fail.

</details>

---

## Requirement 2 — Lex V2 Bot

<details>
<summary>Hint 1 — Same structure as kata-100</summary>

The bot, intents, slot type, and slot configuration are the same as kata-100.
If you completed kata-100, you already know how to build this. The key
difference is that the OrderFood intent needs fulfillment invocation enabled.

</details>

<details>
<summary>Hint 2 — Enabling fulfillment on the intent</summary>

In the Lex V2 console, navigate to your bot → **Languages** → English (US)
→ **Intents** → OrderFood → scroll down to **Fulfillment** → enable
**Use a Lambda function for fulfillment**. This tells Lex to invoke the
alias Lambda when the intent is ready to fulfill. The Lambda ARN is NOT
configured here — it is configured on the alias. See Requirement 4.

</details>

<details>
<summary>Hint 3 — Build the bot after enabling fulfillment</summary>

After enabling Lambda fulfillment on the intent, you must rebuild the bot
locale for the change to take effect. Go to Languages → English (US) →
click **Build**. Wait for the build to complete before creating a version
or testing.

</details>

---

## Requirement 3 — Bot Version

<details>
<summary>Hint 1 — What a bot version is</summary>

In Lex V2, DRAFT is the working copy of your bot. Every change you make
goes to DRAFT first. A published version is a snapshot of DRAFT at a point
in time — it is immutable. Versions are numbered sequentially starting from
1. Publishing a version is what enables safe production deployments where
DRAFT changes don't immediately affect live traffic.

</details>

<details>
<summary>Hint 2 — How to publish a version</summary>

In the Lex V2 console, navigate to your bot → **Bot versions** →
**Create version**. You will be asked which locale to include — select
English (US). Give the version a description. The version number is
assigned automatically by AWS starting from 1.

</details>

<details>
<summary>Hint 3 — Version must be numeric</summary>

The validator checks that a numeric version exists (not just DRAFT). If you
only see DRAFT in the bot versions list, you have not published a version
yet. Via CLI:

```bash
aws lexv2-models create-bot-version \
  --bot-id <BOT_ID> \
  --bot-version-locale-specification '{"en_US":{"sourceBotVersion":"DRAFT"}}'
```

</details>

---

## Requirement 4 — Production Alias

<details>
<summary>Hint 1 — Aliases in Lex V2</summary>

An alias is a named pointer to a specific bot version. Instead of callers
referencing a version number directly (which changes every time you publish),
they reference the alias. When you want to deploy a new version, you update
the alias to point to the new version — callers don't need to change
anything. Aliases also control which Lambda function is used at runtime.

</details>

<details>
<summary>Hint 2 — Lambda is configured on the alias, not the intent</summary>

This is the most important Lex V2 concept in this kata. Unlike what you
might expect from tutorials, the Lambda ARN is NOT set on the intent.
In Lex V2, Lambda is configured per alias per locale. Navigate to your bot
→ **Aliases** → create or select your alias → **Languages** → English (US)
→ set the Lambda function here.

</details>

<details>
<summary>Hint 3 — Exact alias configuration</summary>

Create an alias with:

- **Alias name:** `kata-202-ProductionAlias`
- **Bot version:** Select the published numeric version from Requirement 3
  — do NOT select DRAFT
- **Language:** English (US) must be enabled
- **Lambda function:** Select `kata-202-FulfillmentFunction`
- **Lambda version or alias:** $LATEST is sufficient

The validator checks that the alias points to a numeric version and that
the Lambda ARN on the alias contains `kata-202-FulfillmentFunction`.

</details>

---

## Requirement 5 — Lambda Permission

<details>
<summary>Hint 1 — Why this permission is needed</summary>

AWS Lambda uses resource-based policies to control which services can invoke
a function. Even though you have configured the Lambda ARN on the Lex alias,
Lex cannot actually call the function unless the function's resource policy
explicitly allows `lexv2.amazonaws.com` to invoke it. Without this, Lex
silently fails to invoke Lambda with no error message in the bot response.

</details>

<details>
<summary>Hint 2 — How to add the permission</summary>

Via the AWS console: go to your Lambda function → **Configuration** tab →
**Permissions** → **Resource-based policy statements** → **Add permissions**
→ choose **AWS service** → select **Lex** → provide your alias ARN as the
source. Via CLI:

```bash
aws lambda add-permission \
  --function-name kata-202-FulfillmentFunction \
  --statement-id LexInvokePermission \
  --action lambda:InvokeFunction \
  --principal lexv2.amazonaws.com \
  --source-arn <YOUR_ALIAS_ARN>
```

</details>

<details>
<summary>Hint 3 — Getting the alias ARN</summary>

The alias ARN follows this format:
```
arn:aws:lex:<region>:<account-id>:bot-alias/<bot-id>/<alias-id>
```

You can find it in the Lex console under your alias details, or via CLI:

```bash
aws lexv2-models describe-bot-alias \
  --bot-id <BOT_ID> \
  --bot-alias-id <ALIAS_ID> \
  --query 'botAliasArn'
```

</details>

---

## General Troubleshooting

<details>
<summary>Check 4 failing — fulfillment not enabled on OrderFood</summary>

The validator checks `fulfillmentCodeHook.enabled` on the OrderFood intent
in DRAFT. Go to your bot → Languages → English (US) → Intents → OrderFood
→ Fulfillment section → confirm "Use a Lambda function for fulfillment" is
checked. After enabling it, rebuild the bot locale.

</details>

<details>
<summary>Check 9 failing — intent recognized but state is not Fulfilled</summary>

If the bot recognizes OrderFood but the state is not `Fulfilled`, Lambda
is not being invoked. Most common causes:

1. **Lambda permission missing** — Requirement 5 not completed. Add the
   resource-based policy (see Requirement 5 Hint 2).
2. **Lambda ARN not on alias** — check the alias locale settings confirm
   `kata-202-FulfillmentFunction` is configured.
3. **Fulfillment not enabled on intent** — even if Lambda is on the alias,
   the intent must have fulfillment invocation enabled (Check 4).
4. **Lambda returning wrong format** — the function code must return the
   exact Lex V2 response format with `sessionState.dialogAction.type: Close`
   and `sessionState.intent.state: Fulfilled`.

</details>

<details>
<summary>Check 7 failing — alias points to DRAFT</summary>

The alias must point to a published numeric version, not DRAFT. Edit the
alias and change the bot version to the numeric version you published in
Requirement 3. In the console: Aliases → select your alias → Edit →
change Bot version to the numeric version → Save.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-202-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score 9/9.
Study the solution to understand what you missed, then tear it down and
try again from scratch.