---
id: kata-108
title: "EC2 Basics — Instances, Security Groups & Key Pairs"
level: 100
type: depth
services:
  - ec2
tags:
  - ec2
  - security-groups
  - key-pairs
  - networking
  - depth
  - beginner
estimated_time: 45 minutes
estimated_cost: "$0.01 - $0.05"
author: Your Name
github: https://github.com/yourusername
---

# kata-108 — EC2 Basics: Instances, Security Groups & Key Pairs

## Overview

In this kata you will launch a foundational EC2 setup covering the three
core building blocks of a running instance: the instance itself, the security
group that controls its network access, and the key pair used for
authentication.

You will create a key pair, configure a security group with SSH inbound access
and unrestricted outbound access, and launch a `t3.micro` instance with both
attached. The goal is to understand how these three resources relate to each
other and how AWS uses them together to give you a running, reachable server.

This kata does not require a custom VPC. All resources are deployed into
your account's default VPC, which AWS provisions and manages automatically
in every region.

---

## Prerequisites

- An active AWS account with a default VPC present in your chosen region
- Access to AWS CloudShell
- IAM permissions to create and manage EC2 instances, security groups, and
  key pairs
- Familiarity with basic networking concepts (ports, inbound/outbound rules)

---

## Cost & Time

| | |
|---|---|
| ⏱ Estimated Time | ~45 minutes |
| 💰 Estimated Cost | ~$0.01 – $0.05 |

> ⚠️ **Cost Warning:** These are estimates only. EC2 instances accrue charges
> while running — a `t3.micro` costs approximately $0.01/hr in most regions.
> Actual costs depend on your AWS region, account tier, and how quickly you
> complete the kata. If you leave the instance running beyond the kata session,
> costs will continue to accumulate. All charges are your responsibility.
> Always run the cleanup instructions when finished.

---

## A Note on the Default VPC

Every AWS account includes a **default VPC** in each region. AWS creates and
manages this VPC automatically — it has a default subnet in each availability
zone, an internet gateway, and routing already configured. You do not need to
create any networking resources for this kata.

If you launch the EC2 instance without specifying a VPC or subnet, AWS will
place it in the default VPC automatically. The `solution.yml` CloudFormation
template does the same — it does not create a VPC, so CloudFormation will
also place the instance in the default VPC. If you manually built your
instance in a custom VPC, your infrastructure and the solution will differ
in where the instance lives — but the validator only checks instance
properties, security group rules, and key pair association, not which VPC
is in use.

---

## Requirements

Build the following infrastructure in your AWS account. All resource names
must follow the naming convention: `kata-108-ResourceName`

You are given a spec, not a tutorial. Use the AWS Console, CLI, IaC, or any
tools you choose to meet these requirements. Consult the AWS documentation,
use AI assistants, or search the web — whatever you would use on the job.

---

### Requirement 1 — Key Pair

Create an EC2 key pair with the following configuration:

- **Key pair name:** `kata-108-KeyPair`
- **Key pair type:** RSA
- **Private key format:** `.pem`

Download and store the private key file when prompted — AWS will only offer
it once. The key pair must exist in your account and region for the validator
to pass. The validator confirms the key pair is registered in EC2 and
associated with the instance; it cannot and does not verify your local
`.pem` file.

---

### Requirement 2 — Security Group

Create a security group with the following configuration:

- **Name:** `kata-108-SecurityGroup`
- **Description:** A description of your choice
- **VPC:** The default VPC in your region
- **Inbound access:** SSH must be permitted
- **Outbound access:** All outbound traffic must be permitted

---

### Requirement 3 — EC2 Instance

Launch an EC2 instance with the following configuration:

- **Name tag:** `kata-108-Instance`
- **Instance type:** `t3.micro`
- **Key pair:** `kata-108-KeyPair`
- **Security group:** `kata-108-SecurityGroup`
- **AMI:** Any Amazon-provided AMI (Amazon Linux 2023 is recommended)
- **Instance state:** `running`

> 💡 **AMI note:** The validator does not check which AMI you use. You may
> select any AMI available in your region. Be aware that some third-party
> AMIs from AWS Marketplace carry additional software licensing costs on top
> of the EC2 instance cost. Amazon-provided AMIs (Amazon Linux, Ubuntu,
> Windows Server) do not carry additional AMI charges, though Windows
> instances do incur a licence cost. Amazon Linux 2023 is free and is
> the recommended choice for this kata.

---

## Running the Validator

Once you have built the required infrastructure, open AWS CloudShell and
upload or copy `validate.sh` to your CloudShell environment, then run:

```bash
sed -i 's/\r//' validate.sh
chmod +x validate.sh
./validate.sh
```

The validator checks your live AWS infrastructure and reports a score.
A fully passing result looks like this:

```
==================================================
 CloudKata Validator — kata-108
 EC2 Basics: Instances, Security Groups & Key Pairs
==================================================

✅ PASS — Key pair 'kata-108-KeyPair' exists
✅ PASS — Security group 'kata-108-SecurityGroup' exists
✅ PASS — Security group has SSH inbound rule on port 22
✅ PASS — Security group has unrestricted outbound rule
✅ PASS — Instance 'kata-108-Instance' exists
✅ PASS — Instance type is t3.micro
✅ PASS — Instance state is running
✅ PASS — Instance is using key pair 'kata-108-KeyPair'
✅ PASS — Instance is associated with security group 'kata-108-SecurityGroup'

==================================================
 Results: 9/9 checks passed (100%)
==================================================

 🎉 Perfect score! All kata-108 requirements met.
```

---

## Cleanup

Always clean up your resources when you are finished. EC2 instances accrue
charges while running — do not skip this step.

### Step 1 — Delete CloudFormation stacks (if applicable)

If you deployed `solution.yml`, delete that stack first via CloudFormation.
Stack deletion will terminate the instance and delete the security group
automatically.

- Go to the AWS CloudFormation console
- Select the stack created for this kata
- Choose **Delete** and wait for deletion to complete

Via CLI:
```bash
aws cloudformation delete-stack --stack-name kata-108-solution
aws cloudformation wait stack-delete-complete --stack-name kata-108-solution
```

> ⚠️ CloudFormation does **not** delete the key pair — key pairs are not
> managed by the stack. Delete `kata-108-KeyPair` manually after the stack
> is gone (see Step 2).

### Step 2 — Manual Cleanup

If you created resources manually, or to clean up the key pair after a
CloudFormation deployment, delete in this order:

1. **Terminate the EC2 instance** — go to EC2 → Instances, select
   `kata-108-Instance`, choose Instance State → Terminate. Wait for the
   instance state to reach `terminated`.
2. **Delete the security group** — go to EC2 → Security Groups, select
   `kata-108-SecurityGroup`, choose Actions → Delete. This will fail if
   the instance is not yet terminated.
3. **Delete the key pair** — go to EC2 → Key Pairs, select
   `kata-108-KeyPair`, choose Actions → Delete. Also delete the `.pem`
   file from your local machine.

### Step 3 — Verify in the console

Go to EC2 → Instances and confirm `kata-108-Instance` shows a state of
`terminated`. Go to EC2 → Security Groups and confirm `kata-108-SecurityGroup`
no longer exists. Go to EC2 → Key Pairs and confirm `kata-108-KeyPair` no
longer exists.

> ⚠️ A terminated instance remains visible in the console for a short period
> before AWS removes it from the list. A `terminated` state means billing
> has stopped — you do not need to wait for it to disappear from the console.

---

## Hints & Solution

Stuck? Refer to [HINTS.md](./HINTS.md) for progressive hints without full
spoilers.

The complete solution is available in [solution.yml](./solution.yml).
Note that `solution.yml` deploys into the default VPC. Deploying
`solution.yml` and re-running `validate.sh` should produce a score of 100%.