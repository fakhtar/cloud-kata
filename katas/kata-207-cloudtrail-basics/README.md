---
id: kata-207
title: "CloudTrail Basics -- Trails, Events & Audit Logging"
level: 200
type: depth
services:
  - cloudtrail
  - s3
tags:
  - cloudtrail
  - s3
  - audit
  - logging
  - depth
  - intermediate
estimated_time: 45 minutes
estimated_cost: "$0.00 - $0.02"
author: Your Name
github: https://github.com/fakhtar
---

# kata-207 -- CloudTrail Basics: Trails, Events & Audit Logging

## Overview

In this kata you will build a foundational AWS CloudTrail setup covering the
three core components of audit logging: an S3 bucket configured to receive
CloudTrail log files, a trail that delivers management events to that bucket,
and the resource-based policy that permits CloudTrail to write to it. You will
end up with a working end-to-end audit logging pipeline that captures both read
and write management events across your AWS account.

This kata uses a single-region trail on the default CloudTrail configuration.
No organisation trail or CloudWatch Logs integration is required.

---

## Prerequisites

- An active AWS account
- Access to AWS CloudShell
- IAM permissions to create and manage CloudTrail trails and S3 buckets

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | ~$0.00 - $0.02 |

> ⚠️ **Cost Warning:** These are estimates only. Actual costs depend on your AWS
> region, account tier, and how quickly you complete the kata. If you leave
> infrastructure running beyond the kata session, costs will continue to
> accumulate. CloudTrail charges apply for management events beyond the free
> tier. All charges are your responsibility. Always run cleanup instructions
> when finished.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names must
follow the naming convention: `kata-207-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation, use
AI assistants, or search the web -- whatever you would use on the job.

---

### Requirement 1 -- S3 Bucket

Create an S3 bucket for CloudTrail log delivery with the following
configuration:

- **Bucket name:** `kata-207-trail-logs-<your-account-id>` (replace
  `<your-account-id>` with your 12-digit AWS account ID)
- **Tags:** `Project: CloudKata` and `Kata: kata-207`

The bucket must have a resource-based policy that grants CloudTrail permission
to deliver log files to it, scoped to your account and trail.

---

### Requirement 2 -- CloudTrail Trail

Create a CloudTrail trail with the following configuration:

- **Trail name:** `kata-207-AuditTrail`
- **S3 bucket:** the bucket created in Requirement 1
- **Multi-region trail:** no -- single region only
- **Tags:** `Project: CloudKata` and `Kata: kata-207`

---

### Requirement 3 -- Management Event Logging

Configure the trail to capture management events:

- **Management events:** enabled
- **Read/Write events:** All (both Read and Write)
- **Trail state:** actively logging (not stopped)

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and upload
or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure and reports a score. A fully
passing result looks like this:

```
==================================================
 CloudKata Validator -- kata-207
 CloudTrail Basics: Trails, Events & Audit Logging
==================================================

✅ PASS -- S3 bucket for log delivery exists
✅ PASS -- S3 bucket policy grants CloudTrail delivery permission
✅ PASS -- CloudTrail trail 'kata-207-AuditTrail' exists
✅ PASS -- Trail is actively logging
✅ PASS -- Trail delivers logs to the correct S3 bucket
✅ PASS -- Trail logs management events (Read and Write)

==================================================
 Results: 6/6 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-207 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished.

### Step 1 -- Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, you must **empty the S3 bucket before deleting
the stack**. CloudTrail will have delivered log files to the bucket during the
kata session, and CloudFormation cannot delete a non-empty bucket. Attempting
to delete the stack without emptying the bucket first will leave the bucket in
a `DELETE_FAILED` state.

Via CLI:
```bash
# Step 1a -- empty the bucket first (replace <account-id> with your account ID)
aws s3 rm s3://kata-207-trail-logs-<account-id> --recursive

# Step 1b -- then delete the stack
aws cloudformation delete-stack --stack-name kata-207-solution
aws cloudformation wait stack-delete-complete --stack-name kata-207-solution
```

Via console: go to S3, select the `kata-207-trail-logs-*` bucket, choose
**Empty**, confirm, then go to CloudFormation, select the stack, and choose
**Delete**.

### Step 2 -- Manual Cleanup

If you created resources manually, delete in this order:

1. **Stop and delete the CloudTrail trail** -- go to CloudTrail → Trails,
   select `kata-207-AuditTrail`, stop logging, then delete the trail.
2. **Empty the S3 bucket** -- go to S3, select the `kata-207-trail-logs-*`
   bucket, and delete all objects (including any log files CloudTrail
   delivered).
3. **Delete the S3 bucket** -- once empty, delete the bucket.

### Step 3 -- Verify in the console

Go to CloudTrail → Trails and confirm `kata-207-AuditTrail` no longer exists.
Go to S3 and confirm the `kata-207-trail-logs-*` bucket no longer exists.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml). Deploying
`solution.yml` and re-running `validate.sh` should produce a score of 100%.