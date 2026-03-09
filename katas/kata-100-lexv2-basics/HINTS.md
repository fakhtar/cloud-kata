# kata-100 Hints — Amazon Lex V2 Basics: Bots, Intents & Slots

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

## Requirement 1 — Bot

<details>
<summary>Hint 1 — Where to start</summary>

Amazon Lex V2 is a separate service from Lex V1. Make sure you are in the
**Amazon Lex** console and that you are creating a **V2** bot, not a V1 bot.
The V2 console is the default as of 2023.

</details>

<details>
<summary>Hint 2 — IAM role</summary>

When creating the bot via the console, you can let AWS create a service role
for you automatically. If creating via CLI or IaC, the role needs a trust
policy allowing `lexv2.amazonaws.com` to assume it, and a policy granting
`AmazonLexFullAccess` or a scoped equivalent.

</details>

<details>
<summary>Hint 3 — Session timeout and naming</summary>

The session timeout is set at the bot level, not the intent level. It is
specified in seconds — 5 minutes equals 300 seconds. The bot name must be
exactly `kata-100-FoodOrderingBot` — the validator checks for this exact
string.

</details>

---

## Requirement 2 — Intent: OrderFood

<details>
<summary>Hint 1 — Where intents live</summary>

Intents are created inside a bot locale. You must first create the bot,
then navigate into the `en_US` locale to create intents. In the console,
this is under the bot → Languages → English (US).

</details>

<details>
<summary>Hint 2 — Sample utterances</summary>

Sample utterances are the phrases a user might say to trigger this intent.
You need at least 5. They should be natural and varied — avoid slight
rewording of the same phrase. Good examples: "I'd like to order food",
"Place an order for me", "I want to get some food". The validator counts
utterances so make sure all 5 are saved.

</details>

<details>
<summary>Hint 3 — Slot on the intent</summary>

The `FoodItem` slot must be added to the `OrderFood` intent specifically.
You cannot add it at the bot level. When adding the slot, you will be asked
to choose a slot type — select `kata-100-FoodItemType`. If you have not
created that slot type yet, create it first (see Requirement 4), then come
back and add the slot to this intent.

</details>

---

## Requirement 3 — Intent: CancelOrder

<details>
<summary>Hint 1 — Same locale</summary>

`CancelOrder` lives in the same `en_US` locale as `OrderFood`. Add it as
a second intent — do not create a second bot.

</details>

<details>
<summary>Hint 2 — Sample utterances</summary>

Sample utterances for `CancelOrder` should clearly express cancellation
intent. Good examples: "Cancel my order", "I want to cancel", "Stop my
order", "Forget my order", "I changed my mind". Avoid utterances that
overlap with `OrderFood` — ambiguous utterances confuse the NLU model.

</details>

<details>
<summary>Hint 3 — Closing response</summary>

Both `OrderFood` and `CancelOrder` need a closing response configured.
In the console this is under the intent → Closing response → Add a
response. A simple message like "Your order has been cancelled." is
sufficient. Without a closing response, the bot may behave unexpectedly
at runtime even if it passes structural validation.

</details>

---

## Requirement 4 — Custom Slot Type

<details>
<summary>Hint 1 — Where slot types live</summary>

Custom slot types are created at the bot locale level, not at the intent
level. In the console, navigate to the `en_US` locale and look for
**Slot types** in the left navigation. Create `kata-100-FoodItemType`
there before adding it to an intent.

</details>

<details>
<summary>Hint 2 — Values</summary>

Add at least 4 values: `Pizza`, `Burger`, `Salad`, `Tacos`. You can add
synonyms for each value (e.g., "Cheeseburger" as a synonym for "Burger")
but the base values are what the validator checks — you need at least 4
distinct values.

</details>

<details>
<summary>Hint 3 — Resolution strategy</summary>

The resolution strategy controls what value Lex returns when a user says
a synonym. **Top resolution** means Lex returns the canonical value
(e.g., "Burger") even if the user said "Cheeseburger". In the console,
this is the **Slot type resolution** dropdown — set it to
**Top resolution**. In CFN this is `ResolutionStrategy: TOP_RESOLUTION`.

</details>

---

## Requirement 5 — Bot Locale Build

<details>
<summary>Hint 1 — The build step is mandatory</summary>

Creating a bot, intents, and slot types does not automatically make the
bot `Available`. You must explicitly build the bot locale after configuring
everything. A bot that has not been built will show a status of `Not built`
and will fail Check 3 of the validator.

</details>

<details>
<summary>Hint 2 — How to build via console</summary>

In the console, navigate to the bot → Languages → English (US) and click
the **Build** button. Wait for the build to complete before running the
validator. The build status changes to `Built` when done.

</details>

<details>
<summary>Hint 3 — How to build via CLI</summary>

```bash
aws lexv2-models build-bot-locale \
  --bot-id <YOUR_BOT_ID> \
  --bot-version DRAFT \
  --locale-id en_US
```

Poll the status with:

```bash
aws lexv2-models describe-bot-locale \
  --bot-id <YOUR_BOT_ID> \
  --bot-version DRAFT \
  --locale-id en_US \
  --query 'botLocaleStatus'
```

Wait until the status returns `Built`.

</details>

---

## Requirement 6 — Bot Alias

<details>
<summary>Hint 1 — Why a bot alias is needed</summary>

The Lex V2 runtime API requires a bot alias to invoke a bot. The validator
uses the runtime API to test utterances in Check 8. Without a published
alias with `en_US` enabled, the runtime tests will fail even if the bot
is structurally correct.

</details>

<details>
<summary>Hint 2 — Creating the alias</summary>

In the console, navigate to the bot → Aliases → Create alias. Name it
`kata-100-TestAlias`. You will be asked to associate it with a bot version
— select **Draft version** for this kata. Make sure English (US) is enabled
under the alias locale settings.

</details>

<details>
<summary>Hint 3 — en_US must be explicitly enabled on the alias</summary>

This is the most commonly missed step. Even after creating the alias, you
must go into the alias settings and explicitly enable the `en_US` locale.
In the console: Alias → Languages → Add language → English (US) → Save.
Without this step, the validator's runtime utterance test (Check 8) will
return a `ValidationException` and fail.

</details>

---

## Requirement 7 — Test Utterances

<details>
<summary>Hint 1 — Test in the console first</summary>

Before running the validator, test your bot in the Lex V2 console using
the built-in test window. Enter each of the four test utterances and
confirm the correct intent is shown in the response. If the console test
fails, the validator will also fail.

</details>

<details>
<summary>Hint 2 — Wrong intent being returned</summary>

If an utterance is routing to the wrong intent or to `FallbackIntent`,
check two things: (1) your sample utterances — the test utterance or
something close to it should appear in the intent's sample utterances;
(2) rebuild the bot locale after making any changes. Changes to utterances
do not take effect until the bot is rebuilt.

</details>

<details>
<summary>Hint 3 — Check 8 failing in the validator</summary>

The validator runs runtime tests via the CLI using `kata-100-TestAlias`.
If Check 8 fails after the console test passes, verify that:

1. The alias name is exactly `kata-100-TestAlias`
2. The `en_US` locale is enabled on the alias (see Requirement 6, Hint 3)
3. The alias is pointing to the **Draft** version
4. The bot status is `Available` (Check 3 must pass first)

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-100-solution \
  --capabilities CAPABILITY_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score 8/8.
Study the solution to understand what you missed, then tear it down and
try again from scratch.