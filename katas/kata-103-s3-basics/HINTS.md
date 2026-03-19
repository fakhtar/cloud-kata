# kata-103 Hints — S3 Basics: Buckets, Versioning & Security

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

## Requirement 1 — S3 Bucket

<details>
<summary>Hint 1 — Bucket naming rules</summary>

S3 bucket names must be globally unique across all AWS accounts and all
regions. If you try to create a bucket with a name that is already taken —
anywhere in AWS — the creation will fail. Including your account ID in the
bucket name is the standard way to guarantee uniqueness without guessing.

</details>

<details>
<summary>Hint 2 — Finding your account ID</summary>

You can find your 12-digit AWS account ID in the top-right corner of the
AWS console (click your username). Via CLI:

```bash
aws sts get-caller-identity --query Account --output text
```

</details>

<details>
<summary>Hint 3 — Exact bucket name format</summary>

The bucket name must be exactly:
```
kata-103-bucket-<your-12-digit-account-id>
```

For example, if your account ID is `123456789012`, the bucket name is
`kata-103-bucket-123456789012`. The validator automatically constructs
this name from your account ID — any deviation will cause Check 1 to fail.

</details>

---

## Requirement 2 — Versioning

<details>
<summary>Hint 1 — What versioning does</summary>

When versioning is enabled, S3 keeps every version of every object stored
in the bucket. If you overwrite or delete an object, the previous version
is retained. This protects against accidental deletion and allows you to
restore previous versions of objects.

</details>

<details>
<summary>Hint 2 — Where to enable it in the console</summary>

In the S3 console, navigate to your bucket → **Properties** tab → scroll
down to **Bucket Versioning** → click **Edit** → select **Enable** →
click **Save changes**.

</details>

<details>
<summary>Hint 3 — Versioning states</summary>

A bucket can be in one of three versioning states: unversioned (never
enabled), enabled, or suspended. Only `Enabled` will pass the validator.
`Suspended` means versioning was previously enabled but has been paused —
new objects will not be versioned but old versions are retained. The
validator checks for the string `Enabled` exactly.

</details>

---

## Requirement 3 — Public Access Block

<details>
<summary>Hint 1 — Why all four settings matter</summary>

S3 has two separate mechanisms that can make a bucket public: ACLs (Access
Control Lists) and bucket policies. The public access block has four settings
because you need to block both mechanisms in two ways each — blocking new
ones from being created and ignoring existing ones that may already be in
place. All four must be enabled for the bucket to be fully protected.

</details>

<details>
<summary>Hint 2 — Where to find it in the console</summary>

In the S3 console, navigate to your bucket → **Permissions** tab →
**Block public access (bucket settings)** → click **Edit** → check all
four checkboxes → click **Save changes**. You will be asked to confirm
by typing "confirm".

</details>

<details>
<summary>Hint 3 — The four settings explained</summary>

- **BlockPublicAcls** — prevents new public ACLs from being set on the
  bucket or its objects
- **IgnorePublicAcls** — ignores any existing public ACLs already on the
  bucket or objects
- **BlockPublicPolicy** — prevents new bucket policies that grant public
  access from being set
- **RestrictPublicBuckets** — restricts access to buckets with public
  policies to only AWS services and authorized users

All four must be `true`. The validator checks each one individually.

</details>

---

## Requirement 4 — Server-Side Encryption

<details>
<summary>Hint 1 — What default encryption means</summary>

Default encryption means that any object uploaded to the bucket is
automatically encrypted at rest, even if the uploader does not specify
an encryption method. Without default encryption, objects may be stored
unencrypted unless the uploader explicitly requests encryption.

</details>

<details>
<summary>Hint 2 — Where to enable it in the console</summary>

In the S3 console, navigate to your bucket → **Properties** tab → scroll
down to **Default encryption** → click **Edit** → select
**Server-side encryption with Amazon S3 managed keys (SSE-S3)** →
click **Save changes**.

</details>

<details>
<summary>Hint 3 — SSE-S3 vs SSE-KMS</summary>

There are two main encryption options for this kata. SSE-S3 (AES-256)
uses keys managed entirely by AWS — simpler to configure and no additional
cost. SSE-KMS uses a KMS key and provides more control over key management
and access — covered in kata-105. Either option will pass the validator.
SSE-S3 is the recommended choice for this kata.

</details>

---

## Requirement 5 — Tags

<details>
<summary>Hint 1 — Where to add tags in the console</summary>

In the S3 console, navigate to your bucket → **Properties** tab → scroll
down to **Tags** → click **Edit** → add the required key-value pairs →
click **Save changes**.

</details>

<details>
<summary>Hint 2 — Exact tag values</summary>

Tags are case-sensitive. The validator checks for these exact values:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-103`

A value of `cloudkata` or `Kata-103` will fail the check.

</details>

---

## General Troubleshooting

<details>
<summary>Check 1 failing — bucket not found</summary>

The validator constructs the bucket name as `kata-103-bucket-<account-id>`
using your current AWS credentials. Common causes: the bucket was created
in a different account, the bucket name has a typo (extra dash, wrong
account ID), or the bucket was created in a region the validator cannot
reach. Confirm the exact bucket name with:

```bash
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `kata-103`)]'
```

</details>

<details>
<summary>Stack deletion failing — bucket not empty</summary>

CloudFormation cannot delete an S3 bucket that contains objects or
previous versions. If your stack deletion is failing, empty the bucket
first including all versions:

```bash
# Delete all current objects and versions
aws s3api delete-objects \
  --bucket kata-103-bucket-<account-id> \
  --delete "$(aws s3api list-object-versions \
    --bucket kata-103-bucket-<account-id> \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)"

# Then retry stack deletion
aws cloudformation delete-stack --stack-name kata-103-solution
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-103-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 8/8.
Study the solution to understand what you missed, then tear it down and
try again from scratch.