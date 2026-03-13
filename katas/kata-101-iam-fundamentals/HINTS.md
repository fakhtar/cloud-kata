# kata-101 Hints — IAM Fundamentals: Roles, Policies & Trust Relationships

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

## Requirement 1 — IAM Role

<details>
<summary>Hint 1 — Where to start</summary>

Navigate to the IAM console and look for the **Roles** section. You are
creating a new role — not a user, not a group. Roles are assumed by services
and people temporarily, not permanently attached to an identity.

</details>

<details>
<summary>Hint 2 — Role creation flow</summary>

When creating a role via the console, you will be asked to select a trusted
entity type. You are building a role for an AWS service. Select the service
that will assume this role — think about what service this role is designed
for.

</details>

<details>
<summary>Hint 3 — Naming and description</summary>

The role name must be exactly `kata-101-LambdaExecutionRole` — the validator
checks for this exact string. Add a short description so the role's purpose
is clear to anyone who reviews it in the future. Descriptions are good
practice and cost nothing.

</details>

---

## Requirement 2 — Trust Policy

<details>
<summary>Hint 1 — What a trust policy controls</summary>

A trust policy is not the same as a permission policy. Permission policies
control what the role can do. The trust policy controls who can assume the
role. These are two separate concepts in IAM — make sure you are editing
the right one.

</details>

<details>
<summary>Hint 2 — Service principals</summary>

AWS services that need to assume a role identify themselves using a service
principal — a string in the format `service-name.amazonaws.com`. When you
select a trusted entity type in the console, AWS builds this principal for
you. If you are writing the trust policy manually, you need to know the
correct principal for the service this role is designed for.

</details>

<details>
<summary>Hint 3 — Trust policy structure</summary>

A trust policy is a JSON document with a `Statement` containing an `Effect`,
a `Principal`, and an `Action`. The action in a trust policy is always
`sts:AssumeRole`. The principal should contain only one service. If you
see multiple services or a wildcard principal (`"*"`), the validator will
fail Check 3.

</details>

---

## Requirement 3 — Customer Managed Policy

<details>
<summary>Hint 1 — Customer managed vs AWS managed</summary>

AWS provides pre-built managed policies like `AmazonDynamoDBFullAccess` that
grant broad permissions. These are convenient but they are not least privilege.
For this kata you must author the policy document yourself — a customer managed
policy. This is what the kata is testing: whether you know which specific
actions are needed, not whether you can find a pre-built policy that works.

</details>

<details>
<summary>Hint 2 — Finding the right actions</summary>

To find the exact API actions needed for a given operation, consult the
[AWS IAM Actions Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html).
Look up the DynamoDB and CloudWatch Logs sections. For DynamoDB, you need
basic item-level read and write operations — not table management, not
streams, not batch operations. For CloudWatch Logs, you need only what a
Lambda function uses to write its output.

</details>

<details>
<summary>Hint 3 — Exact actions and policy name</summary>

The policy name must be exactly `kata-101-LambdaExecutionPolicy`.

The validator checks for these exact DynamoDB actions — no more, no less:
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:DeleteItem`

And these exact CloudWatch Logs actions — no more, no less:
- `logs:CreateLogGroup`
- `logs:CreateLogStream`
- `logs:PutLogEvents`

Any additional actions in the policy — including `dynamodb:Query`,
`dynamodb:Scan`, or `dynamodb:BatchWriteItem` — will cause the validator
to fail. The requirement is strict.

</details>

---

## Requirement 4 — Resource Scoping (Least Privilege)

<details>
<summary>Hint 1 — Why resource scoping matters</summary>

Granting `dynamodb:GetItem` is a good start, but granting it on `*` (all
DynamoDB tables) is still a least privilege violation. A compromised Lambda
function with that policy could read data from any table in your account.
The permission should only work against the specific table this function
is designed to use.

</details>

<details>
<summary>Hint 2 — How to construct an ARN</summary>

AWS resource ARNs follow a predictable format:
`arn:aws:<service>:<region>:<account-id>:<resource-type>/<resource-name>`

For DynamoDB tables, the ARN looks like:
`arn:aws:dynamodb:us-east-1:123456789012:table/MyTableName`

You need to substitute your own region and account ID. You can find your
account ID in the top-right corner of the AWS console or by running
`aws sts get-caller-identity` in CloudShell.

</details>

<details>
<summary>Hint 3 — DynamoDB and CloudWatch Logs resource ARNs</summary>

For DynamoDB, scope the resource to the specific table:
```
arn:aws:dynamodb:<your-region>:<your-account-id>:table/kata-101-OrdersTable
```

For CloudWatch Logs, a scoped wildcard on the log group name is acceptable
since the Lambda function name is not known at policy creation time. Scope
to the kata-101 log group prefix:
```
arn:aws:logs:<your-region>:<your-account-id>:log-group:/aws/lambda/kata-101-*
```

Using `*` as the resource for either service will fail validation.

</details>

---

## Requirement 5 — Policy Attachment

<details>
<summary>Hint 1 — Managed policy vs inline policy</summary>

There are two ways to attach a policy to a role: as a managed policy
(standalone, reusable, visible in the IAM Policies list) or as an inline
policy (embedded directly in the role, not reusable). The validator looks
for `kata-101-LambdaExecutionPolicy` as an attached customer managed policy
specifically. An inline policy with the same permissions will not pass
Check 11.

</details>

<details>
<summary>Hint 2 — Attaching via console</summary>

In the IAM console, navigate to the role → **Permissions** tab →
**Add permissions** → **Attach policies**. Search for
`kata-101-LambdaExecutionPolicy` in the search box. If you do not see it,
confirm you created it as a customer managed policy (not an inline policy
on another role).

</details>

<details>
<summary>Hint 3 — What the validator checks</summary>

The validator calls `aws iam list-attached-role-policies` on the role and
looks for `kata-101-LambdaExecutionPolicy` in the results. It also scans
all attached policies for known overly broad AWS managed policies. If you
attached any AWS managed policy — even a seemingly harmless one like
`AWSLambdaBasicExecutionRole` — the validator will flag it as a least
privilege violation. Your customer managed policy must cover everything
the role needs.

</details>

---

## General Troubleshooting

<details>
<summary>Check 5 or 6 failing — action mismatch</summary>

The validator checks for an exact set of actions — not a subset. If Check 5
or 6 is failing, two things could be wrong: (1) a required action is missing,
or (2) an extra action is present beyond what is required. Review your policy
document carefully. Common mistakes include adding `dynamodb:Query` or
`dynamodb:Scan` thinking they are needed for reads, or adding
`logs:DescribeLogGroups` for CloudWatch.

</details>

<details>
<summary>Check 8 failing — DynamoDB resource scoping</summary>

The validator confirms that the DynamoDB resource ARN contains the table
name `kata-101-OrdersTable` and is not set to `*`. Double-check your ARN
for typos in the table name, region, or account ID. A single character
difference will cause this check to fail.

</details>

<details>
<summary>jq not available in CloudShell</summary>

The validator requires `jq` to parse IAM policy documents. `jq` is installed
by default in AWS CloudShell. If you see a `jq: command not found` error,
you may be running the script outside of CloudShell. Install it with:

```bash
sudo yum install -y jq   # Amazon Linux
sudo apt-get install -y jq  # Ubuntu/Debian
```

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-101-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score 11/11.
Study the solution to understand what you missed, then tear it down and
try again from scratch.