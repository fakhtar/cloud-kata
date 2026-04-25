# kata-207 Hints -- CloudTrail Basics: Trails, Events & Audit Logging

> ⚠️ **Spoiler warning.** Each hint section reveals progressively more detail.
> Try to solve each requirement on your own before opening a hint. The learning
> is in the struggle.

---

## How to use these hints

Hints are organized by requirement number matching the README. Each requirement
has up to three levels:

- **Hint 1** -- a nudge in the right direction
- **Hint 2** -- more specific guidance
- **Hint 3** -- the exact approach (near-solution level)

---

## Requirement 1 -- S3 Bucket

<details>
<summary>Hint 1 -- Where to create the bucket</summary>

S3 buckets are managed in the Amazon S3 console. Search for "S3" in the AWS
console navigation bar and click **Create bucket**. The bucket must be created
in the same region where you will create the trail -- CloudTrail delivers logs
to buckets in the same region.

</details>

<details>
<summary>Hint 2 -- Bucket naming and settings</summary>

The bucket name must include your 12-digit AWS account ID as a suffix because
S3 bucket names are globally unique and this naming pattern prevents collisions.
You can find your account ID in the top-right corner of the AWS console under
your account name, or by running `aws sts get-caller-identity` in CloudShell.

Keep all other bucket settings at their defaults -- block public access should
remain enabled.

</details>

<details>
<summary>Hint 3 -- Exact configuration</summary>

- **Bucket name:** `kata-207-trail-logs-<your-account-id>` (replace
  `<your-account-id>` with your 12-digit account ID -- the validator detects
  this automatically)
- **Region:** same region as your CloudShell session
- **Block Public Access:** all four settings enabled (default)
- **Tags:** add `Project = CloudKata` and `Kata = kata-207`

The bucket needs a resource-based policy before CloudTrail can deliver logs to
it -- see Requirement 3, Hint 3 for the exact policy statements.

</details>

---

## Requirement 2 -- CloudTrail Trail

<details>
<summary>Hint 1 -- Where to create the trail</summary>

Trails are managed in the AWS CloudTrail console. Search for "CloudTrail" in
the AWS console navigation bar. From the CloudTrail dashboard, select **Trails**
in the left panel and click **Create trail**.

</details>

<details>
<summary>Hint 2 -- Trail scope and storage</summary>

When creating the trail, you will be asked whether to apply it to all regions
or to the current region only. For this kata, choose the current region only --
a single-region trail is sufficient. You will also need to point the trail at
the S3 bucket you created in Requirement 1. If you have not created the bucket
yet, do that first -- CloudTrail will validate that the bucket policy grants it
access before allowing you to save the trail.

</details>

<details>
<summary>Hint 3 -- Exact configuration</summary>

- **Trail name:** `kata-207-AuditTrail` (must be exact -- the validator checks
  this name)
- **Storage location:** use the existing bucket `kata-207-trail-logs-<account-id>`
- **Log file SSE-KMS encryption:** disabled (not required for this kata)
- **Log file validation:** optional
- **Multi-region trail:** no -- single region only
- **Tags:** add `Project = CloudKata` and `Kata = kata-207`

</details>

---

## Requirement 3 -- Management Event Logging

<details>
<summary>Hint 1 -- What management events are</summary>

Management events (also called control plane operations) capture API calls that
create, modify, or delete AWS resources -- for example, creating an EC2
instance, attaching an IAM policy, or deleting an S3 bucket. They are distinct
from data events, which track operations on the contents of resources (such as
reading or writing S3 objects). CloudTrail trails log management events by
default when you create a trail through the console.

</details>

<details>
<summary>Hint 2 -- Read vs Write events and logging state</summary>

Management events are categorised as either Read (describe, list, get) or Write
(create, update, delete). The validator requires both to be captured, which
corresponds to the "All" setting in the CloudTrail console under **Management
events - API activity**. Make sure the trail is also in an active logging state
-- a trail that exists but is stopped will fail Check 4. Logging state is
controlled by the **Start logging / Stop logging** toggle on the trail detail
page.

</details>

<details>
<summary>Hint 3 -- Exact configuration and bucket policy</summary>

**Event selector settings:**
- **Management events:** enabled
- **API activity:** Read and Write (select both)

**Trail state:** logging must be started (the toggle on the trail detail page
must show "Logging: On").

**S3 bucket policy** -- CloudTrail will not deliver logs without this. Go to
S3, select your `kata-207-trail-logs-<account-id>` bucket, open the
**Permissions** tab, and set the bucket policy to the following (replace
`<account-id>` and `<region>` with your values):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::kata-207-trail-logs-<account-id>",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "arn:aws:cloudtrail:<region>:<account-id>:trail/kata-207-AuditTrail"
        }
      }
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::kata-207-trail-logs-<account-id>/AWSLogs/<account-id>/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "aws:SourceArn": "arn:aws:cloudtrail:<region>:<account-id>:trail/kata-207-AuditTrail"
        }
      }
    }
  ]
}
```

</details>

---

## General Troubleshooting

<details>
<summary>Check 1 failing -- S3 bucket not found</summary>

The validator looks for a bucket named `kata-207-trail-logs-<account-id>` using
your current account ID. Two common causes: (1) the bucket was created in a
different region -- S3 bucket names are global but the validator uses
`head-bucket` which is region-aware; (2) the account ID suffix is wrong or
missing -- verify the exact bucket name in the S3 console.

</details>

<details>
<summary>Check 2 failing -- bucket policy missing CloudTrail permission</summary>

The bucket exists but its policy does not grant `cloudtrail.amazonaws.com`
permission to `s3:GetBucketAcl` or `s3:PutObject`. Go to S3, select the
bucket, open the **Permissions** tab, and add the policy from Requirement 3,
Hint 3. Make sure you replace all placeholder values with your actual account
ID and region.

</details>

<details>
<summary>Check 3 failing -- trail not found</summary>

The validator calls `describe-trails` by exact name. Verify the trail name is
exactly `kata-207-AuditTrail` (case-sensitive) and that it was created in the
same region as your CloudShell session. You can confirm the trail's home region
in the CloudTrail console under the trail's detail page.

</details>

<details>
<summary>Check 4 failing -- trail not logging</summary>

The trail exists but logging is stopped. Go to CloudTrail, select
`kata-207-AuditTrail`, and look for the logging toggle near the top of the
detail page. If it shows "Logging: Off", click **Start logging**.

</details>

<details>
<summary>Check 5 failing -- wrong S3 bucket</summary>

The trail is configured to deliver logs to a different bucket than
`kata-207-trail-logs-<account-id>`. Go to CloudTrail, select
`kata-207-AuditTrail`, click **Edit**, and update the storage location to the
correct bucket.

</details>

<details>
<summary>Check 6 failing -- management events not configured</summary>

The trail exists and is logging, but the event selector is not capturing
management events with ReadWriteType "All". Go to CloudTrail, select
`kata-207-AuditTrail`, open the **Event history** tab or the trail edit page,
and under **Management events** ensure both Read and Write are selected.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-207-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 6/6.
Study the solution to understand what you missed, then tear it down and try
again from scratch.