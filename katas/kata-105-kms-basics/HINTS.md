# kata-105 Hints — KMS Basics: Keys, Aliases & Rotation

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

## Requirement 1 — Customer Managed Key

<details>
<summary>Hint 1 — AWS managed vs customer managed</summary>

AWS creates and manages its own KMS keys for services like S3 and Lambda
(e.g. `alias/aws/s3`). These are AWS managed keys — you cannot configure,
rotate, or delete them directly. For this kata you need a **customer managed
key** — one that you create and control. The validator checks the
`KeyManager` field and will fail if it finds an AWS managed key.

</details>

<details>
<summary>Hint 2 — Key type selection</summary>

When creating a KMS key you will be asked to choose a key type and key
usage. There are several combinations available — asymmetric keys for
signing or encryption, HMAC keys, and symmetric keys. Only one combination
supports automatic key rotation. Think about which type fits the
requirements before selecting.

</details>

<details>
<summary>Hint 3 — Exact key configuration</summary>

Create a key with the following settings:

- **Key type:** Symmetric
- **Key usage:** Encrypt and decrypt
- **Key spec:** SYMMETRIC_DEFAULT (this is the only option for symmetric
  encrypt/decrypt keys)
- **Origin:** KMS (AWS-generated key material)

In CloudFormation: `KeySpec: SYMMETRIC_DEFAULT` and
`KeyUsage: ENCRYPT_DECRYPT`. The key must be in `Enabled` state — newly
created keys are enabled by default.

</details>

---

## Requirement 2 — Key Alias

<details>
<summary>Hint 1 — What aliases are for</summary>

A KMS key ID looks like `1234abcd-12ab-34cd-56ef-1234567890ab` — not
human-readable. An alias gives the key a friendly name you can reference
in your code and policies. Aliases can be updated to point to different
keys without changing the references in your application.

</details>

<details>
<summary>Hint 2 — Alias naming rules</summary>

KMS alias names must start with `alias/`. They cannot start with
`alias/aws/` — that prefix is reserved for AWS managed keys. The rest
of the name can contain alphanumeric characters, hyphens, underscores,
and forward slashes.

</details>

<details>
<summary>Hint 3 — Creating the alias</summary>

The alias must be named exactly `alias/kata-105-key`. Create it in the
KMS console under **Customer managed keys** → select your key → **Aliases**
tab → **Add alias**. Or via CLI:

```bash
aws kms create-alias \
  --alias-name alias/kata-105-key \
  --target-key-id <YOUR_KEY_ID>
```

The validator looks up the key by this alias name — if the alias is missing
or named differently, Check 1 will fail and the validator will exit.

</details>

---

## Requirement 3 — Key Rotation

<details>
<summary>Hint 1 — What automatic rotation does</summary>

When automatic key rotation is enabled, KMS generates new key material
for the key once per year. The old key material is retained so that data
encrypted with it can still be decrypted. From the application's perspective
nothing changes — the same key ID and alias continue to work. Rotation
only applies to the key material, not the key itself.

</details>

<details>
<summary>Hint 2 — Which key types support rotation</summary>

Automatic key rotation is only supported on symmetric encryption keys
with AWS-generated key material (KeySpec = SYMMETRIC_DEFAULT, Origin = AWS_KMS).
Asymmetric keys, HMAC keys, and keys with imported key material do not
support automatic rotation. This is why Requirement 1 specifies a symmetric
key — rotation is only possible with that configuration.

</details>

<details>
<summary>Hint 3 — Enabling rotation in the console</summary>

Navigate to KMS → Customer managed keys → select your key →
**Key rotation** tab → check **Automatically rotate this KMS key every year**
→ **Save**. Via CLI:

```bash
aws kms enable-key-rotation --key-id <YOUR_KEY_ID>
```

The validator calls `get-key-rotation-status` and checks that
`KeyRotationEnabled` is `true`. If rotation was never enabled or was
disabled, Check 6 will fail.

</details>

---

## Requirement 4 — Tags

<details>
<summary>Hint 1 — KMS tag format</summary>

KMS tags follow the same key-value format as other AWS services but are
managed through a separate API (`kms:TagResource`). In the console, tags
are found under the key's **Tags** tab. Note that KMS requires the
`kms:TagResource` permission — make sure your IAM role has this permission
before attempting to add tags.

</details>

<details>
<summary>Hint 2 — Adding tags in the console</summary>

Navigate to KMS → Customer managed keys → select your key → **Tags** tab
→ **Edit** → **Add tag**. Add both required tags and save.

</details>

<details>
<summary>Hint 3 — Exact tag values</summary>

Tags are case-sensitive. The validator checks for these exact values:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-105`

A value of `cloudkata` or `Kata-105` will fail the check.

</details>

---

## General Troubleshooting

<details>
<summary>Check 1 failing — alias not found</summary>

The validator searches for `alias/kata-105-key` exactly. Common causes:
the alias was created with a different name, the `alias/` prefix is missing,
or the alias was created in a different region than your CloudShell session.
Confirm with:

```bash
aws kms list-aliases --query "Aliases[?contains(AliasName, 'kata-105')]"
```

</details>

<details>
<summary>Check 2 failing — not a customer managed key</summary>

If the alias points to an AWS managed key, Check 2 will fail. AWS managed
keys have `KeyManager: AWS` rather than `KeyManager: CUSTOMER`. Delete the
alias and create a new one pointing to a customer managed key you created.

</details>

<details>
<summary>Cost warning — key deletion waiting period</summary>

KMS keys cannot be deleted immediately. When you schedule a key for
deletion, you must specify a waiting period of 7 to 30 days. During this
period the key is disabled but you are still billed $1.00/month. To
minimize cost, use the minimum waiting period of 7 days. You can cancel
a scheduled deletion before the waiting period expires if needed.

```bash
# Cancel a scheduled deletion
aws kms cancel-key-deletion --key-id <YOUR_KEY_ID>
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-105-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 7/7.
Study the solution to understand what you missed, then tear it down and
try again from scratch.