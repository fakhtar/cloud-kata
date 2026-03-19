# kata-104 Hints — VPC Basics: Networking Constructs & Routing

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

## Requirement 1 — VPC

<details>
<summary>Hint 1 — Where to start</summary>

Navigate to the VPC console and choose **Create VPC**. You want to create
a VPC only — not the VPC and more wizard option which creates subnets and
other resources automatically. Creating each component individually is
the right approach for this kata and will teach you how the pieces fit
together.

</details>

<details>
<summary>Hint 2 — DNS settings</summary>

Two DNS-related settings must be enabled on the VPC. These are separate
settings — enabling one does not automatically enable the other. Both are
required for the validator to pass Checks 2 and 3. They can be configured
during VPC creation or edited afterward via the VPC settings.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Name tag:** `kata-104-VPC`
- **IPv4 CIDR:** `10.104.0.0/16`
- **DNS resolution (EnableDnsSupport):** Enabled
- **DNS hostnames (EnableDnsHostnames):** Enabled

The CIDR must be exactly `10.104.0.0/16` — the validator checks this value.

</details>

---

## Requirement 2 — Public Subnets

<details>
<summary>Hint 1 — Subnets and availability zones</summary>

A subnet exists within a single availability zone. When you create a subnet
you must choose which AZ it lives in. For resilience, the two subnets in
this kata must be in different AZs. Any two different AZs in your region
will pass validation.

</details>

<details>
<summary>Hint 2 — CIDR blocks must not overlap</summary>

Each subnet's CIDR block must be a subset of the VPC CIDR (`10.104.0.0/16`)
and must not overlap with any other subnet in the VPC. The two CIDRs
specified in the requirements are already non-overlapping — use them exactly.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

Create two subnets inside `kata-104-VPC`:

- **Subnet 1:** Name `kata-104-PublicSubnet1`, CIDR `10.104.1.0/24`,
  any AZ in your region
- **Subnet 2:** Name `kata-104-PublicSubnet2`, CIDR `10.104.2.0/24`,
  any different AZ in your region

The name tags and CIDRs must be exact. The AZs can be any two different
AZs available in your region.

</details>

---

## Requirement 3 — Internet Gateway

<details>
<summary>Hint 1 — Two steps: create and attach</summary>

An internet gateway is a separate resource from the VPC. Creating it is
only the first step — it must also be explicitly attached to a VPC before
it can route traffic. A created-but-unattached IGW will fail the validator.

</details>

<details>
<summary>Hint 2 — Where to attach in the console</summary>

After creating the internet gateway in the VPC console, select it from
the list, then choose **Actions** → **Attach to VPC**. Select `kata-104-VPC`
and confirm. The state will change from `detached` to `available` once
attached.

</details>

<details>
<summary>Hint 3 — Name tag matters</summary>

The validator looks up the internet gateway by its Name tag. The name
must be exactly `kata-104-IGW`. If you created the IGW without a name
or with a different name, edit the tags to add or correct it.

</details>

---

## Requirement 4 — Route Table

<details>
<summary>Hint 1 — Every VPC has a default route table</summary>

When you create a VPC, AWS automatically creates a default route table
with a local route for the VPC CIDR. You should NOT use this default route
table for this kata. Create a new route table named `kata-104-PublicRouteTable`
and add the internet gateway route to it.

</details>

<details>
<summary>Hint 2 — Adding a route</summary>

After creating the route table, select it and go to the **Routes** tab →
**Edit routes** → **Add route**. Set the destination to `0.0.0.0/0` and
the target to your internet gateway. This tells AWS to send all traffic
not destined for the VPC CIDR out to the internet.

</details>

<details>
<summary>Hint 3 — The route must point to your IGW specifically</summary>

The validator confirms the default route (`0.0.0.0/0`) target is the
internet gateway ID. If the route points to a different target (such as
a NAT gateway or local), Check 9 will fail. The route table must be
associated with the VPC and named `kata-104-PublicRouteTable` exactly.

</details>

---

## Requirement 5 — Subnet Associations

<details>
<summary>Hint 1 — Explicit association required</summary>

Creating a route table does not automatically associate it with any subnet.
Each subnet must be explicitly associated with the route table. Until a
subnet is associated with a custom route table, it uses the VPC's default
route table.

</details>

<details>
<summary>Hint 2 — Where to associate in the console</summary>

Select the route table → **Subnet associations** tab → **Edit subnet
associations** → check both `kata-104-PublicSubnet1` and
`kata-104-PublicSubnet2` → **Save associations**.

</details>

<details>
<summary>Hint 3 — Both subnets must be associated</summary>

The validator checks both subnets individually. If only one subnet is
associated, the validator will tell you exactly which one is missing.
Check 10 produces a specific fail message for each subnet independently.

</details>

---

## General Troubleshooting

<details>
<summary>Check 7 failing — IGW not found or not attached</summary>

Two common causes: (1) the IGW was created but not attached to the VPC —
go to VPC console → Internet Gateways → select the IGW → Actions →
Attach to VPC; (2) the Name tag is wrong — the validator searches by
the exact tag value `kata-104-IGW`. Check the tags on your IGW and
correct if needed.

</details>

<details>
<summary>Check 9 failing — no default route</summary>

The route table exists but the `0.0.0.0/0` route is missing or pointing
to the wrong target. Go to VPC console → Route Tables → select
`kata-104-PublicRouteTable` → Routes tab → confirm a route exists with
destination `0.0.0.0/0` and target set to your internet gateway ID
(starts with `igw-`).

</details>

<details>
<summary>Stack deletion order for manual cleanup</summary>

VPC deletion will fail if dependent resources still exist. Delete in this
order: route table associations → routes → route table → detach IGW →
delete IGW → delete subnets → delete VPC. The VPC console will show
dependency errors if you attempt deletion out of order.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-104-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 10/10.
Study the solution to understand what you missed, then tear it down and
try again from scratch.