# kata-204 Hints — S3 + Lambda: Event Notifications & Triggers

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
<summary>Hint 1 — Where to start</summary>

S3 bucket names are global — unique across every AWS account on the
internet, not just your own. A bucket literally named `kata-204-bucket-`
will almost certainly already exist (or be rejected for other reasons), so
you need to append something to the prefix to make it unique.

</details>

<details>
<summary>Hint 2 — What to append</summary>

Your AWS account ID is a reliable, simple choice for the unique suffix —
it's already unique to you, it's stable, and it makes the bucket easy to
identify later. You can find it with:

```bash
aws sts get-caller-identity --query Account --output text
```

A bucket named `kata-204-bucket-<your-account-id>` satisfies the
requirement: it starts with the required prefix, and the suffix guarantees
no collision with anyone else's bucket.

</details>

<details>
<summary>Hint 3 — Exact creation command</summary>

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket \
  --bucket "kata-204-bucket-${ACCOUNT_ID}" \
  --region us-east-1
```

> If your region is not `us-east-1`, `create-bucket` requires an additional
> `--create-bucket-configuration LocationConstraint=<your-region>` argument
> — `us-east-1` is the one region that does not need this.

In CloudFormation, set `BucketName` to an explicit, predictable string
rather than omitting it (which would let CloudFormation auto-generate a
name). This matters more than it looks like it should — see Requirement 4,
Hint 3 for why.

</details>

---

## Requirement 2 — Lambda Function

<details>
<summary>Hint 1 — Where to start</summary>

You don't need to write any function logic — the README gives you the
exact code to use. Your job here is just getting that code deployed under
the right name, runtime, and role. If you're using the console, the
"Author from scratch" option with the Python 3.12 runtime gets you there
fastest.

</details>

<details>
<summary>Hint 2 — Execution role</summary>

Every Lambda function needs an execution role — an IAM role the Lambda
service assumes when running your code. For this kata, the function only
needs to write its own logs; it never calls any S3 API itself (it just
reads the event data S3 hands it). If you're creating the role via the
console, "Create a new role with basic Lambda permissions" gives you
exactly this. Via CLI or IaC, the standard
`AWSLambdaBasicExecutionRole` managed policy is exactly scoped for this —
nothing more is required.

</details>

<details>
<summary>Hint 3 — Exact configuration and gotcha</summary>

- **Function name:** `kata-204-ProcessorFunction` — exact match required
- **Runtime:** `python3.12`
- **Handler:** `index.handler` if your code file is named `index.py` and
  the function inside it is named `handler` (matching the README's
  provided code as-is)
- **Timeout:** the default of 3 seconds is technically enough for this
  function, but set it to 10+ seconds anyway — cold starts plus a slow
  CloudShell network round-trip have caused enough flaky timeouts in this
  kata that the small buffer is worth it

Via CLI:
```bash
aws iam create-role \
  --role-name kata-204-ProcessorFunctionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name kata-204-ProcessorFunctionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Wait a few seconds for IAM role propagation before creating the function,
# or you'll get an "InvalidParameterValueException: role cannot be assumed"
# error even though the role clearly exists.

zip function.zip index.py
aws lambda create-function \
  --function-name kata-204-ProcessorFunction \
  --runtime python3.12 \
  --handler index.handler \
  --role "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/kata-204-ProcessorFunctionRole" \
  --zip-file fileb://function.zip \
  --timeout 10
```

In CloudFormation, `AWS::Lambda::Function` with an inline `ZipFile` under
`Code` avoids needing to upload a zip to S3 first — fine for a function
this small.

</details>

---

## Requirement 3 — S3 Event Notification

<details>
<summary>Hint 1 — Where this configuration lives</summary>

S3 event notifications are a property of the bucket itself, not of the
Lambda function. In the console, this is under your bucket → **Properties**
tab → **Event notifications** → **Create event notification**. There's no
separate "trigger" resource to create — you're configuring the bucket to
call out to Lambda.

</details>

<details>
<summary>Hint 2 — Event type selection</summary>

S3 offers many granular event types (`s3:ObjectCreated:Put`,
`s3:ObjectCreated:Post`, `s3:ObjectCreated:Copy`, etc.) as well as the
wildcard `s3:ObjectCreated:*`, which covers all of them. Use the wildcard
— it's what the README and validator both expect, and it means your
trigger fires regardless of how an object gets created (regular upload,
multipart upload completion, copy from another bucket, and so on).

</details>

<details>
<summary>Hint 3 — Exact CLI command and CFN property name</summary>

Via CLI (this replaces the *entire* notification configuration, so if you
already have other notifications configured, fetch and merge them first
rather than overwriting):

```bash
aws s3api put-bucket-notification-configuration \
  --bucket "kata-204-bucket-${ACCOUNT_ID}" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [
      {
        "LambdaFunctionArn": "arn:aws:lambda:'"${REGION}"':'"${ACCOUNT_ID}"':function:kata-204-ProcessorFunction",
        "Events": ["s3:ObjectCreated:*"]
      }
    ]
  }'
```

> **This will fail with `InvalidArgument: Unable to validate the following
> destination configurations`** if Requirement 4 (the Lambda permission)
> isn't already in place. S3 checks, at the moment you submit this
> configuration, that the target function's resource policy already
> grants S3 permission to invoke it — it will not let you configure the
> notification first and grant permission second. Do Requirement 4 before
> this step, or your `put-bucket-notification-configuration` call will be
> rejected outright with a clear error (this one is loud, not silent).

In CloudFormation, the property is `NotificationConfiguration` on
`AWS::S3::Bucket`, with a `LambdaConfigurations` list. Each entry uses the
singular key `Event` (not `Events`) and a `Function` key for the ARN:

```yaml
NotificationConfiguration:
  LambdaConfigurations:
    - Event: "s3:ObjectCreated:*"
      Function: !GetAtt YourFunction.Arn
```

</details>

---

## Requirement 4 — Permission to Invoke

<details>
<summary>Hint 1 — Why this is a separate step at all</summary>

Configuring the event notification on the bucket (Requirement 3) only
tells S3 *what* to call. It does not, by itself, give S3 permission to
call it — Lambda functions are private by default and only respond to
invocations from principals explicitly authorized via the function's own
resource-based policy (separate from the function's execution role, which
controls what the function can do, not who can invoke it). This is the
single most commonly missed step in S3-to-Lambda wiring, precisely because
nothing about Requirement 3 visibly fails if you skip it — well, almost
nothing; see Hint 3 below.

</details>

<details>
<summary>Hint 2 — What "scoped to your bucket" means</summary>

It's not enough to allow the S3 service in general — that would let *any*
S3 bucket in *any* AWS account invoke your function, since `s3.amazonaws.com`
on its own is just "the S3 service," not "my bucket." You need to add a
condition that restricts the grant to your specific bucket's ARN. In the
Lambda console, when you add a trigger from the function's **Configuration
→ Triggers** tab and select S3, this scoping is handled for you
automatically — but if you're doing this manually via the CLI or IaC, you
have to specify it yourself.

</details>

<details>
<summary>Hint 3 — Exact CLI command and the CloudFormation circular dependency</summary>

Via CLI:
```bash
aws lambda add-permission \
  --function-name kata-204-ProcessorFunction \
  --statement-id AllowS3Invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::kata-204-bucket-${ACCOUNT_ID}" \
  --source-account "${ACCOUNT_ID}"
```

The `--source-arn` is what scopes the grant to this one bucket. Without
it, the statement would allow `s3.amazonaws.com` unconditionally — which
satisfies "S3 can invoke the function" but fails "scoped to your bucket
specifically," since it would technically permit any bucket, in any
account, to invoke your function. `--source-account` is good practice
alongside it: it guards against the edge case where a bucket with the same
name is deleted and later recreated by a different AWS account.

**If you're using CloudFormation**, this requirement runs straight into a
well-known circular dependency. The natural way to write this is to give
`AWS::Lambda::Permission`'s `SourceArn` a `!GetAtt YourBucket.Arn`
reference — but your bucket's `NotificationConfiguration` (Requirement 3)
needs `!GetAtt YourFunction.Arn`, and now the permission depends on the
bucket while the bucket depends on the function depends on... nothing
depends on the permission, except that S3 won't accept the notification
config without it. CloudFormation can't find a valid creation order and
will reject the template outright with a dependency error before it even
attempts to deploy.

The way out: don't let CloudFormation auto-generate your bucket's name.
Give the bucket an explicit `BucketName` (see Requirement 1, Hint 3), and
build the bucket's ARN as a plain string with `!Sub` in your
`AWS::Lambda::Permission`'s `SourceArn` — for example
`!Sub "arn:aws:s3:::kata-204-bucket-${AWS::AccountId}"` — instead of
referencing the bucket resource directly. Since the permission no longer
references the bucket resource at all, there's no cycle: the permission
can be created right after the function, and the bucket (which still
needs both the permission and the function) goes last. Add an explicit
`DependsOn` from the bucket to the permission resource to guarantee
CloudFormation enforces that order, since the bucket's only *reference* to
the permission is implicit otherwise.

</details>

---

## General Troubleshooting

<details>
<summary>S3 rejects my notification configuration before I even finish Requirement 3</summary>

This means you're hitting Requirement 3 before Requirement 4 — S3
validates, at the moment you submit a Lambda notification configuration,
that the target function already has a resource policy granting S3
invoke permission. Go set up the permission first (Requirement 4), then
come back and configure the notification.

</details>

<details>
<summary>Everything looks correctly configured but nothing happens when I upload a file</summary>

Work through these in order — they're the only four things that can break
this wiring, and they fail silently in this order of likelihood:

1. Check the resource policy actually exists and is scoped to the right
   bucket:
   ```bash
   aws lambda get-policy --function-name kata-204-ProcessorFunction --query Policy --output text | jq .
   ```
   Look for a statement with `"Service": "s3.amazonaws.com"` and a
   `Condition.ArnLike."AWS:SourceArn"` matching your bucket's ARN exactly.
   A missing `SourceArn` condition (the function is invocable, just not
   scoped) won't cause a missed invocation — but a *wrong* bucket ARN in
   that condition will.

2. Check the notification configuration is still attached to the function
   you think it is:
   ```bash
   aws s3api get-bucket-notification-configuration --bucket kata-204-bucket-<your-account-id>
   ```
   Confirm `LambdaFunctionArn` points at `kata-204-ProcessorFunction` and
   `Events` includes an `s3:ObjectCreated` entry. If you edited the bucket
   or redeployed a stack since you last tested, double check this wasn't
   silently dropped or overwritten — `put-bucket-notification-configuration`
   replaces the *entire* configuration, so a second call without merging
   the first can wipe out what you set up earlier.

3. Check you're uploading to the bucket the notification is actually
   configured on — easy to mix up if you created more than one bucket
   while experimenting.

4. If you're doing the optional manual check from the README, check
   CloudWatch Logs directly for the invocation rather than trusting that
   "no errors visible" means "nothing happened" (the validator itself
   does not check this — only the optional self-check does):
   ```bash
   aws logs tail /aws/lambda/kata-204-ProcessorFunction --since 5m
   ```
   S3 event delivery is asynchronous and occasionally takes longer than
   you'd expect even when everything is wired correctly — if you see your
   upload's invocation in the logs a little later than you expected, the
   wiring was fine all along and this was just a timing illusion, not a
   bug.

</details>

<details>
<summary>I get an "AccessDenied" or similar error when uploading to my own bucket</summary>

This is unrelated to the Lambda wiring — it means your own IAM identity
(the one running `aws s3 cp`) doesn't have `s3:PutObject` permission on
the bucket, which is a separate concern from the bucket's notification
configuration or the Lambda's resource policy. Check the permissions
attached to the IAM user or role you're using in CloudShell.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-204-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

The `--capabilities CAPABILITY_NAMED_IAM` flag is required because the
template creates an IAM role with an explicit name.

Then re-run `validate.sh`. A correctly deployed solution should score 7/7.
Study the solution to understand what you missed, then tear it down and
try again from scratch.