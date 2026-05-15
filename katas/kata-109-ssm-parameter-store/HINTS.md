# kata-109 Hints — SSM Parameter Store: Parameters, Types & Versioning

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

## Requirement 1 — String Parameter

<details>
<summary>Hint 1 — Where to start</summary>

Parameter Store lives inside AWS Systems Manager (SSM). In the console,
navigate to **Systems Manager** → **Parameter Store** → **Create parameter**.
Parameters are identified by their name, which can use a hierarchical path
format with forward slashes — for example `/myapp/config/setting`. This keeps
parameters organised and makes it easy to apply IAM policies to a whole path.

</details>

<details>
<summary>Hint 2 — Parameter types</summary>

Parameter Store supports three types: `String` (plain text), `StringList`
(comma-separated plain text), and `SecureString` (encrypted). A plaintext
environment label like `dev` or `staging` does not need encryption — use the
`String` type. The value is stored and returned exactly as you enter it.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Name:** `/kata-109/config/environment`
- **Type:** `String`
- **Value:** `dev`

Create the parameter with value `dev` first. You will update it to `staging`
in Requirement 3 — this is what drives the version counter. If you create it
with `staging` directly, you will need to make a second update to reach
version 2.

In the console: **Systems Manager** → **Parameter Store** → **Create parameter**.
Enter the name with the leading slash, select **String**, and enter `dev` as
the value.

Via CLI:
```bash
aws ssm put-parameter \
  --name /kata-109/config/environment \
  --type String \
  --value dev
```

In CloudFormation, use `AWS::SSM::Parameter` with `Type: String`.

</details>

---

## Requirement 2 — SecureString Parameter

<details>
<summary>Hint 1 — What SecureString means</summary>

A `SecureString` parameter is encrypted at rest using AWS KMS. When you
retrieve it, you get back the encrypted value unless you explicitly request
decryption. This type is appropriate for sensitive values like API keys,
passwords, and tokens that should not be stored in plain text. The encryption
and decryption are handled transparently by SSM — you do not need to call KMS
directly.

</details>

<details>
<summary>Hint 2 — KMS key selection</summary>

When creating a SecureString parameter, you must choose a KMS key for
encryption. You can use the AWS-managed key for SSM (`aws/ssm`) which exists
in every account and incurs no additional KMS charges for standard-tier
parameters. You do not need to create a customer-managed key for this kata.

</details>

<details>
<summary>Hint 3 — Exact configuration and CloudFormation limitation</summary>

- **Name:** `/kata-109/config/api-key`
- **Type:** `SecureString`
- **Value:** `supersecret`
- **KMS key:** use the default AWS-managed key (`aws/ssm`)

In the console: **Systems Manager** → **Parameter Store** → **Create parameter**.
Enter the name, select **SecureString**, leave the KMS key as the default
`aws/ssm` key, and enter `supersecret` as the value.

Via CLI:
```bash
aws ssm put-parameter \
  --name /kata-109/config/api-key \
  --type SecureString \
  --value supersecret
```

> ⚠️ **CloudFormation limitation:** `AWS::SSM::Parameter` does not support
> `Type: SecureString`. If you are using CloudFormation, you must create the
> SecureString parameter via a custom resource backed by a Lambda function
> that calls `ssm:PutParameter` with `Type=SecureString`. See `solution.yml`
> for the full pattern.

</details>

---

## Requirement 3 — Versioning

<details>
<summary>Hint 1 — How versioning works in Parameter Store</summary>

Every time you update a parameter's value, Parameter Store automatically
increments its version number. The first time you create a parameter it is
version 1. Each subsequent update creates a new version. You can retrieve a
specific historical version by appending `:version` to the parameter name —
for example `/kata-109/config/environment:1` — but the default always returns
the latest version. You cannot manually set the version number.

</details>

<details>
<summary>Hint 2 — What "update" means</summary>

Updating a parameter means calling `PutParameter` again with the same name
and a new value, with the overwrite flag set. In the console, open the
parameter and choose **Edit**, change the value, and save. Each save
increments the version by one. The validator checks both that the current
value is `staging` and that the version is 2 or higher — so the parameter
must have been updated at least once after its initial creation.

</details>

<details>
<summary>Hint 3 — Exact steps</summary>

If you created the parameter with value `dev` in Requirement 1, update it now:

In the console: open `/kata-109/config/environment`, choose **Edit**,
change the value to `staging`, and save. The version shown in the console
will increment to 2.

Via CLI:
```bash
aws ssm put-parameter \
  --name /kata-109/config/environment \
  --value staging \
  --overwrite
```

You can verify the version with:
```bash
aws ssm get-parameter \
  --name /kata-109/config/environment \
  --query 'Parameter.{Value:Value,Version:Version}'
```

</details>

---

## Requirement 4 — Tags

<details>
<summary>Hint 1 — Which parameter needs tags</summary>

Only the `/kata-109/config/environment` String parameter requires tags. The
SecureString parameter is excluded from tag validation in this kata due to API
constraints with SecureString tagging.

</details>

<details>
<summary>Hint 2 — How to tag SSM parameters</summary>

SSM parameters are tagged differently from most AWS resources. Rather than
using the standard `aws resourcegroupstaggingapi tag-resources` command, SSM
has its own tagging API: `ssm add-tags-to-resource`. You must specify the
resource type as `Parameter` and use the parameter name (not ARN) as the
resource ID.

In the console, open the parameter, choose the **Tags** tab, and add the
key-value pairs there.

</details>

<details>
<summary>Hint 3 — Exact tag values and CLI command</summary>

Tags are case-sensitive. The validator checks for these exact values on
`/kata-109/config/environment`:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-109`

Via CLI:
```bash
aws ssm add-tags-to-resource \
  --resource-type Parameter \
  --resource-id /kata-109/config/environment \
  --tags Key=Project,Value=CloudKata Key=Kata,Value=kata-109
```

In CloudFormation, `AWS::SSM::Parameter` supports tags as a flat map — not
a list of `{Key, Value}` objects:

```yaml
Tags:
  Project: CloudKata
  Kata: kata-109
```

</details>

---

## General Troubleshooting

<details>
<summary>Check 3 failing — value is not 'staging'</summary>

The validator reads the current value of `/kata-109/config/environment` and
compares it to `staging`. If the value is still `dev`, you have not yet
updated the parameter. If the value is something else, you may have edited
it incorrectly. Use the CLI to check the current state:

```bash
aws ssm get-parameter \
  --name /kata-109/config/environment \
  --query 'Parameter.{Value:Value,Version:Version}'
```

</details>

<details>
<summary>Check 4 failing — version is less than 2</summary>

If the version is 1, the parameter was created directly with `staging` and
has never been updated. Create a second update to push the version to 2:

```bash
aws ssm put-parameter \
  --name /kata-109/config/environment \
  --value staging \
  --overwrite
```

This writes the same value again — the version still increments even if the
value does not change.

</details>

<details>
<summary>Check 6 failing — parameter type is not SecureString</summary>

The validator checks `.Parameter.Type` from `get-parameter`. If type is
`String` instead of `SecureString`, the parameter was created with the wrong
type. Parameter types cannot be changed after creation — you must delete
the parameter and recreate it with `Type: SecureString`.

```bash
aws ssm delete-parameter --name /kata-109/config/api-key
aws ssm put-parameter \
  --name /kata-109/config/api-key \
  --type SecureString \
  --value supersecret
```

</details>

<details>
<summary>Check 7 failing — SecureString value is incorrect</summary>

The validator retrieves the SecureString value using `--with-decryption`. If
the value is returned as a ciphertext blob rather than `supersecret`, the
CloudShell IAM role may not have `kms:Decrypt` permission for the `aws/ssm`
key. Try retrieving the value manually to confirm:

```bash
aws ssm get-parameter \
  --name /kata-109/config/api-key \
  --with-decryption \
  --query 'Parameter.Value'
```

If decryption fails, check that your IAM permissions include `kms:Decrypt`
on the `aws/ssm` key, or recreate the parameter using a KMS key your role
can decrypt.

</details>

<details>
<summary>Check 8 failing — tags not found on environment parameter</summary>

The SSM tagging API uses `--resource-id` with the parameter name, not the
ARN. Verify the tags are set correctly:

```bash
aws ssm list-tags-for-resource \
  --resource-type Parameter \
  --resource-id /kata-109/config/environment
```

If the output shows no tags or wrong values, add or correct them:

```bash
aws ssm add-tags-to-resource \
  --resource-type Parameter \
  --resource-id /kata-109/config/environment \
  --tags Key=Project,Value=CloudKata Key=Kata,Value=kata-109
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-109-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

The `--capabilities CAPABILITY_NAMED_IAM` flag is required because the
template creates an IAM role with an explicit name.

Then re-run `validate.sh`. A correctly deployed solution should score 8/8.
Study the solution to understand what you missed, then tear it down and try
again from scratch.