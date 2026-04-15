# kata-108 Hints — EC2 Basics: Instances, Security Groups & Key Pairs

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

## Requirement 1 — Key Pair

<details>
<summary>Hint 1 — Where to find key pairs</summary>

Key pairs are managed in the EC2 console, not IAM. In the EC2 console,
look for **Key Pairs** under the **Network & Security** section in the
left navigation panel. From there you can create a new key pair.

</details>

<details>
<summary>Hint 2 — Download the private key immediately</summary>

When you create a key pair, AWS gives you exactly one opportunity to
download the private key file. Once you close or dismiss the download
prompt, the private key is gone — AWS does not store it. Save the `.pem`
file somewhere safe on your machine before continuing.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Key pair name:** `kata-108-KeyPair` (must be exact — the validator checks this name)
- **Key pair type:** RSA
- **Private key format:** `.pem`

The name is case-sensitive. A key pair named `kata-108-keypair` or
`Kata-108-KeyPair` will not pass validation.

</details>

---

## Requirement 2 — Security Group

<details>
<summary>Hint 1 — Where to find security groups</summary>

Security groups are also in the EC2 console under **Network & Security**
→ **Security Groups**. Click **Create security group**. You will need to
give it a name, a description, and associate it with a VPC — use the
default VPC for this kata.

</details>

<details>
<summary>Hint 2 — Inbound and outbound rules</summary>

A security group has two separate rule sets: inbound rules control what
traffic can reach your instance, and outbound rules control what traffic
your instance can send. You need to configure both. SSH uses TCP on
port 22. For outbound, you want to allow all traffic — this means all
protocols, all ports, to all destinations.

> 🔒 **Security note:** When setting the source for the SSH inbound rule,
> you should restrict it to your own IP address rather than `0.0.0.0/0`.
> Opening SSH to the entire internet exposes port 22 to constant automated
> scanning and brute-force attempts, even for short-lived lab resources.
> You can find your current public IP at
> [https://checkip.amazonaws.com](https://checkip.amazonaws.com) and enter
> it as `YOUR.IP.ADDRESS.HERE/32`. The `/32` means exactly that one address.
> The validator checks that an SSH rule exists on port 22 but does not
> require a specific source CIDR, so restricting to your IP will pass.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Security group name:** `kata-108-SecurityGroup` (must be exact)
- **Description:** Any text you choose
- **VPC:** Default VPC
- **Inbound rule:** Type = SSH, Protocol = TCP, Port = 22, Source = your IP (`x.x.x.x/32`) or `0.0.0.0/0`
- **Outbound rule:** Type = All traffic, Protocol = All, Port range = All, Destination = `0.0.0.0/0`

Note: AWS pre-populates a default outbound allow-all rule when you create
a new security group. Check that it is present before saving — do not
delete it.

</details>

---

## Requirement 3 — EC2 Instance

<details>
<summary>Hint 1 — Where to launch an instance</summary>

In the EC2 console, go to **Instances** → **Launch instances**. The
launch wizard will walk you through choosing an AMI, an instance type,
key pair, security group, and other settings. Work through each section
of the wizard carefully — several of the validator checks depend on
choices you make here.

</details>

<details>
<summary>Hint 2 — Connecting the pieces</summary>

Three of the nine checks depend on choices made at launch time that
cannot be changed afterward without terminating and re-launching the
instance: the instance type, the key pair, and the security group.
Make sure you select `t3.micro` as the instance type, `kata-108-KeyPair`
as the key pair, and `kata-108-SecurityGroup` as the security group
before confirming the launch. The Name tag can be added or corrected
after launch via the instance's Tags tab.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Name tag:** `kata-108-Instance` (can be set in the Name field at the
  top of the launch wizard, or added as a tag after launch)
- **AMI:** Any Amazon-provided AMI — Amazon Linux 2023 is recommended and
  has no additional cost
- **Instance type:** `t3.micro`
- **Key pair:** `kata-108-KeyPair`
- **Security group:** Select existing → `kata-108-SecurityGroup`
- **Subnet / VPC:** Default VPC and any default subnet (no change needed
  from the defaults)

Wait for the instance state to reach **running** before running the
validator. It typically takes 30–60 seconds after launch.

</details>

---

## General Troubleshooting

<details>
<summary>Check 1 failing — key pair not found</summary>

The validator looks up the key pair by its exact name `kata-108-KeyPair`
in the current region. Two common causes: (1) the key pair was created
in a different region — key pairs are regional, so check that your
CloudShell session and your key pair are in the same region; (2) the
name has a typo or different capitalisation — names are case-sensitive.

</details>

<details>
<summary>Check 3 failing — no SSH inbound rule</summary>

The security group exists but has no inbound rule for TCP port 22. Go
to EC2 → Security Groups → select `kata-108-SecurityGroup` → **Inbound
rules** tab → **Edit inbound rules** → **Add rule** → Type: SSH → save.

</details>

<details>
<summary>Check 4 failing — no unrestricted outbound rule</summary>

The default outbound allow-all rule may have been deleted. Go to EC2 →
Security Groups → select `kata-108-SecurityGroup` → **Outbound rules**
tab → **Edit outbound rules**. Add a rule with Type: All traffic,
Destination: `0.0.0.0/0`.

</details>

<details>
<summary>Check 7 failing — instance state is not running</summary>

The instance exists but is in a `stopped`, `pending`, or `stopping`
state. If it is stopped, select the instance → **Instance state** →
**Start instance** and wait for it to reach `running`. If it is
`pending`, wait a moment and re-run the validator.

</details>

<details>
<summary>Checks 8 or 9 failing — wrong key pair or security group</summary>

The key pair and security group associated with an instance cannot be
changed after launch. If either check is failing, you will need to
terminate the instance and launch a new one with the correct settings.
Before terminating, confirm the correct key pair and security group
names so you do not make the same mistake twice.

</details>

<details>
<summary>Instance is not appearing in the validator at all</summary>

Two common causes: (1) the Name tag is wrong — the validator filters by
the exact tag value `kata-108-Instance`, so check the instance's Tags
tab and correct it if needed; (2) the instance is in a `terminated`
state — terminated instances are excluded from the validator. Launch a
new instance if this is the case.

</details>

<details>
<summary>CloudFormation stack deletion does not remove the key pair</summary>

This is expected. CloudFormation creates the key pair as part of the
stack but does not delete it on stack deletion. After deleting the stack,
go to EC2 → Key Pairs → select `kata-108-KeyPair` → Actions → Delete.
Also delete the `.pem` file from your local machine.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

> ⚠️ `solution.yml` uses `0.0.0.0/0` as the SSH source CIDR so that it
> works out of the box for any user. This is intentional for a portable
> lab solution but is **not** recommended practice. Always restrict SSH
> source CIDRs to known IP ranges in real environments.

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-108-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 9/9.
Study the solution to understand what you missed, then tear it down and
try again from scratch.