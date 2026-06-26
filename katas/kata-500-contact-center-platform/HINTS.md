# kata-500 Hints — Contact Center Platform

> ⚠️ **Spoiler warning.** Each hint section reveals progressively more detail.
> Try to solve each requirement on your own before opening a hint. The learning
> is in the struggle.

---

## How to use these hints

Hints are organised by requirement number matching the README. Each requirement
has up to three levels:

- **Hint 1** — a nudge in the right direction
- **Hint 2** — more specific guidance
- **Hint 3** — the exact approach (near-solution level)

---

## Requirement 1 — Amazon Connect Instance

<details>
<summary>Hint 1 — Where to start</summary>

Amazon Connect instance creation is available in the AWS Console under the
Amazon Connect service, or via the AWS CLI. Not all AWS regions support
Connect — `us-east-1` is the safest choice. If you have never created a
Connect instance in this account, you may need to request a service quota
increase before proceeding.

</details>

<details>
<summary>Hint 2 — Identity management and telephony</summary>

When creating the instance, you will be asked how users will be managed.
Choose the option that stores and manages users within Connect itself, rather
than federating to an external directory. Inbound and outbound calling are
configured in the telephony settings of the instance — both must be enabled.

</details>

<details>
<summary>Hint 3 — Contact flow logs and CloudFormation</summary>

Contact flow log emission is a per-instance attribute, not a contact flow
setting. In the console it appears under the instance settings in the Flows
section. In CloudFormation, the `AWS::Connect::Instance` resource takes an
`Attributes` block — the relevant property is `ContactflowLogs` (note the
lowercase 'f'). Set it to `true`.

One important caveat: **Amazon Connect instances cannot be deleted by
CloudFormation.** If you deploy via a stack, you must manually delete the
instance after the stack is torn down. The stack deletion will succeed, but
the instance will remain until you remove it explicitly.

</details>

---

## Requirement 2 — Lex V2 IVR Bot

<details>
<summary>Hint 1 — Bot structure</summary>

Amazon Lex V2 is structured differently from V1. The bot itself is a
container — intents, slots, and slot types all live inside a bot locale.
Create the bot first, then navigate into its English (US) locale to add
intents. The bot will not reach `Built` status until you explicitly trigger
a build of the locale after configuring your intents.

</details>

<details>
<summary>Hint 2 — The OrderId slot and the alias</summary>

The `OrderId` slot must be marked as required on the `CheckOrderStatus`
intent. This means configuring a prompt that the bot will use to elicit the
value from the caller if they did not provide it upfront. For the slot type,
use the built-in `AMAZON.AlphaNumeric` type — it handles mixed
letter-and-digit inputs without needing a custom slot type.

For the alias, creating it is not enough — you must also explicitly enable
the `en_US` locale on the alias itself. This is a separate step from
creating the alias and is easy to miss. Without it, the alias cannot be
invoked for English (US) calls.

</details>

<details>
<summary>Hint 3 — Lambda code hook on the alias</summary>

The Lambda code hook that connects Lex to your fulfilment function is
configured on the **alias**, not on the bot or the intent. In the console,
navigate to the alias settings and look for the language-specific settings
for English (US) — the Lambda function hook is configured there.

In CloudFormation, this is the `BotAliasLocaleSettings` property of
`AWS::Lex::BotAlias`. The structure is:

```
BotAliasLocaleSettings:
  - LocaleId: en_US
    BotAliasLocaleSetting:
      Enabled: true
      CodeHookSpecification:
        LambdaCodeHook:
          LambdaArn: <function ARN>
          CodeHookInterfaceVersion: "1.0"
```

Note that `CodeHookInterfaceVersion` must be the string `"1.0"` — other
values such as `"1"` will fail validation.

Also note: `AWS::Lex::BotAlias` cannot point directly to the `DRAFT`
version. You must first publish a `AWS::Lex::BotVersion` from `DRAFT`, then
point the alias at the published version number.

</details>

---

## Requirement 3 — Lambda Fulfilment Function

<details>
<summary>Hint 1 — Lex V2 invocation contract</summary>

When Lex V2 invokes a Lambda function, it sends a structured event containing
the session state, the recognised intent, and any slot values. The function
must return a response in the Lex V2 fulfilment format — it is not the same
format as Lex V1. The response must include a `sessionState` object with a
`dialogAction` of type `Close` and an `intent` with state `Fulfilled`.

</details>

<details>
<summary>Hint 2 — Extracting intent from the event and writing to DynamoDB</summary>

The intent name is nested inside the event at
`event['sessionState']['intent']['name']`. The caller session identifier is
at `event['sessionId']`. Use these as the values for the `intentName` and
`callerId` attributes respectively. For the timestamp, generate it inside the
function at invocation time rather than relying on an event field.

The function needs `dynamodb:PutItem` permission on
`kata-500-CallerDataTable` in its execution role. The table name should be
passed in via an environment variable rather than hardcoded.

</details>

<details>
<summary>Hint 3 — Lex invocation permission</summary>

Granting Lex permission to invoke the function requires a Lambda
resource-based policy — an IAM execution role alone is not sufficient. In
CloudFormation, use `AWS::Lambda::Permission` with `Principal:
lexv2.amazonaws.com`. Scope it to your account with `SourceAccount` and to
the specific bot alias ARN with `SourceArn`. Without this permission, Lex
will receive an access denied error when attempting to invoke the function,
even if everything else is correctly configured.

</details>

---

## Requirement 4 — DynamoDB Table

<details>
<summary>Hint 1 — Key design</summary>

The table stores one record per fulfilment invocation. Each record has a
caller session identifier and a timestamp. Think about how you would query
records — all invocations for a given caller, ordered by time. That access
pattern should guide your choice of partition key and sort key.

</details>

<details>
<summary>Hint 2 — Key schema</summary>

Use `callerId` as the partition key (String) and `timestamp` as the sort key
(String). This matches the record structure written by the Lambda function
and allows efficient retrieval of all invocations for a given caller session.

</details>

<details>
<summary>Hint 3 — Capacity and CloudFormation</summary>

Use on-demand capacity (`PAY_PER_REQUEST` billing mode in CloudFormation) —
there is no need to provision throughput for a kata workload. In
`AWS::DynamoDB::Table`, set `BillingMode: PAY_PER_REQUEST` and define both
keys in `AttributeDefinitions` and `KeySchema`. Only attributes used as keys
need to appear in `AttributeDefinitions` — do not list `intentName`, `status`,
or `timestamp` there unless they are index keys.

</details>

---

## Requirement 5 — Contact Flow

<details>
<summary>Hint 1 — Association before flow creation</summary>

Before you can reference a Lex V2 bot inside a contact flow, the bot must be
associated with the Connect instance. This is a separate step from creating
the bot. In the console it is done under the Connect instance settings →
Amazon Lex. Via CloudFormation, use `AWS::Connect::IntegrationAssociation`
with `IntegrationType: LEX_BOT` and `IntegrationArn` set to the bot alias
ARN — not the bot ARN.

</details>

<details>
<summary>Hint 2 — Contact flow content</summary>

A contact flow is defined as a JSON document in the Connect flow language.
The minimal structure for this kata is: play a greeting prompt, invoke the
Lex bot to collect caller intent, then disconnect. The action type for
invoking a Lex V2 bot is `ConnectParticipantWithLexBot`. It requires the
alias ARN under `Parameters.LexV2Bot.AliasArn` and also requires at least
one of `Text`, `SSML`, `PromptId`, or `Media` to be set — Connect will
reject the flow at creation time if no prompt is provided on the bot
invocation action.

</details>

<details>
<summary>Hint 3 — Flow language structure and CloudFormation</summary>

The Connect flow language JSON must follow this structure:

```json
{
  "Version": "2019-10-30",
  "StartAction": "<identifier of first action>",
  "Actions": [
    {
      "Identifier": "<uuid-format string>",
      "Type": "MessageParticipant",
      "Parameters": { "Text": "Welcome message here." },
      "Transitions": {
        "NextAction": "<next identifier>",
        "Errors": [{ "NextAction": "<fallback>", "ErrorType": "NoMatchingError" }],
        "Conditions": []
      }
    },
    {
      "Identifier": "<uuid-format string>",
      "Type": "ConnectParticipantWithLexBot",
      "Parameters": {
        "Text": "How can I help you today?",
        "LexV2Bot": { "AliasArn": "<alias ARN>" }
      },
      "Transitions": {
        "NextAction": "<disconnect identifier>",
        "Errors": [
          { "NextAction": "<disconnect>", "ErrorType": "NoMatchingError" },
          { "NextAction": "<disconnect>", "ErrorType": "NoMatchingCondition" },
          { "NextAction": "<disconnect>", "ErrorType": "InputTimeLimitExceeded" }
        ],
        "Conditions": []
      }
    },
    {
      "Identifier": "<uuid-format string>",
      "Type": "DisconnectParticipant",
      "Parameters": {},
      "Transitions": {}
    }
  ]
}
```

In CloudFormation, pass this as the `Content` property of
`AWS::Connect::ContactFlow` using `Fn::Sub` to inject the bot alias ARN
dynamically.

</details>

---

## Requirement 6 — CloudWatch Log Group

<details>
<summary>Hint 1 — Log group naming</summary>

Amazon Connect automatically emits contact flow logs to a log group named
`/aws/connect/<instance-alias>` when flow logging is enabled on the instance.
However, the validator checks for a log group named exactly
`kata-500-ContactFlowLogs` — this is the canonical observability resource for
this kata. Create it explicitly with the correct name and retention period.

</details>

<details>
<summary>Hint 2 — Retention</summary>

CloudWatch log groups have no retention set by default — logs are kept
indefinitely. Set the retention period to 30 days. In the console this is
under the log group settings → Edit retention. Via CLI:

```bash
aws logs put-retention-policy \
  --log-group-name kata-500-ContactFlowLogs \
  --retention-in-days 30
```

</details>

<details>
<summary>Hint 3 — CloudFormation</summary>

Use `AWS::Logs::LogGroup` with `LogGroupName: kata-500-ContactFlowLogs` and
`RetentionInDays: 30`. Create it explicitly — do not rely on auto-creation
from Connect or Lambda, which would produce a log group with a different name
and no retention policy set.

</details>

---

## Requirement 7 — CloudWatch Alarm

<details>
<summary>Hint 1 — What to monitor</summary>

Lambda publishes an `Errors` metric to the `AWS/Lambda` namespace
automatically — no custom instrumentation is needed. The metric counts the
number of invocations that resulted in an error (exceptions, timeouts, or
out-of-memory failures). Filter the metric to your specific function using
the `FunctionName` dimension.

</details>

<details>
<summary>Hint 2 — Threshold and missing data</summary>

The alarm must activate on the first error — set the threshold to 1 with a
`GreaterThanOrEqualToThreshold` comparison. A function that has never been
invoked will have no data points for the `Errors` metric. If missing data
is treated as breaching, the alarm will immediately enter `ALARM` state on
a freshly deployed function with no invocations. Set missing data treatment
to `notBreaching` so the alarm stays in `OK` state when the function is idle.

</details>

<details>
<summary>Hint 3 — CloudFormation</summary>

In `AWS::CloudWatch::Alarm`, the key properties are:

- `Namespace: AWS/Lambda`
- `MetricName: Errors`
- `Dimensions` — one dimension with `Name: FunctionName` and `Value:
  kata-500-FulfillmentFunction`
- `Statistic: Sum`
- `Period: 60`
- `EvaluationPeriods: 1`
- `Threshold: 1`
- `ComparisonOperator: GreaterThanOrEqualToThreshold`
- `TreatMissingData: notBreaching`

</details>

---

## Requirement 8 — End-to-End Integration

<details>
<summary>Hint 1 — The dependency order matters</summary>

The five services have strict dependency ordering. You cannot create a
contact flow that references a Lex bot until the bot is associated with the
Connect instance. You cannot associate the bot until both the instance and
the bot alias exist. Build in this order: IAM roles → DynamoDB → Lambda →
Lex bot → Lex alias → Connect instance → bot association → contact flow →
CloudWatch resources.

</details>

<details>
<summary>Hint 2 — The two most commonly missed wiring steps</summary>

Two integration steps are easy to overlook:

1. **Lex bot association** — The bot must be associated with the Connect
   instance via the Connect console (Instance settings → Amazon Lex → Add
   bot) or via `AWS::Connect::IntegrationAssociation`. Simply creating the
   bot is not enough — Connect has no awareness of it until it is explicitly
   associated.

2. **Lambda code hook on the alias** — The Lambda function must be
   registered as the code hook on the `kata-500-ProdAlias` alias, not on the
   bot itself. If you configure it on the bot's locale settings instead of
   the alias, the validator will not find it.

</details>

<details>
<summary>Hint 3 — Verifying the wiring via CLI</summary>

Use these commands to verify each integration point independently before
running the validator:

```bash
# Confirm the Lex bot is associated with the Connect instance
INSTANCE_ID=$(aws connect list-instances \
  --query "InstanceSummaryList[?InstanceAlias=='kata-500-instance'].Id | [0]" \
  --output text)
aws connect list-bots \
  --instance-id "$INSTANCE_ID" \
  --lex-version V2 \
  --query "LexBots[].LexV2Bot.AliasArn" \
  --output json

# Confirm the Lambda hook is on the alias
BOT_ID=$(aws lexv2-models list-bots \
  --filters name=BotName,values=kata-500-IVRBot,operator=EQ \
  --query 'botSummaries[0].botId' --output text)
ALIAS_ID=$(aws lexv2-models list-bot-aliases \
  --bot-id "$BOT_ID" \
  --query "botAliasSummaries[?botAliasName=='kata-500-ProdAlias'].botAliasId | [0]" \
  --output text)
aws lexv2-models describe-bot-alias \
  --bot-id "$BOT_ID" \
  --bot-alias-id "$ALIAS_ID" \
  --query "botAliasLocaleSettings.en_US.codeHookSpecification.lambdaCodeHook.lambdaArn" \
  --output text
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-500-solution \
  --capabilities CAPABILITY_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score 13/13.
Study the solution to understand what you missed, then tear it down and try
again from scratch.

> ⚠️ Remember: the Connect instance must be deleted manually after the stack
> is removed. CloudFormation cannot delete Connect instances.