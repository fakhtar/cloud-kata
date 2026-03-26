# kata-201 Hints — DynamoDB Core: Tables, Keys, Indexes & Capacity Modes

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

## Requirement 1 — DynamoDB Table

<details>
<summary>Hint 1 — Thinking about the primary key</summary>

In DynamoDB, the primary key determines how data is distributed and how
it can be retrieved without a scan. Read the access pattern carefully:
"retrieve all orders for a given order ID, filtered or sorted by the date
they were created." This describes two dimensions — one for identifying a
specific order, one for ordering results within that group. DynamoDB
supports a composite primary key for exactly this pattern.

</details>

<details>
<summary>Hint 2 — Composite primary key</summary>

A composite primary key consists of a partition key and a sort key. The
partition key determines which partition the data lives in. The sort key
allows items with the same partition key to be stored in sorted order and
queried by range. Think about which attribute uniquely identifies an order
and which attribute represents when it was created.

</details>

<details>
<summary>Hint 3 — Exact key configuration</summary>

- **Partition key (HASH):** `OrderId` — String
- **Sort key (RANGE):** `CreatedAt` — String

In the DynamoDB console, when creating the table, set the partition key
to `OrderId` and enable the sort key, setting it to `CreatedAt`. Both
are of type String. The table will not be ACTIVE until creation completes —
wait for the status to show Active before running the validator.

</details>

---

## Requirement 2 — Capacity Mode

<details>
<summary>Hint 1 — Two capacity modes</summary>

DynamoDB offers two capacity modes. One requires you to estimate and
reserve read and write capacity in advance — you pay for what you reserve
whether you use it or not. The other charges only for the reads and writes
you actually perform, scaling automatically to any level of traffic. Think
about which model fits a workload described as unpredictable.

</details>

<details>
<summary>Hint 2 — When to use each mode</summary>

Provisioned capacity works well when traffic is predictable and consistent.
On-demand capacity works well when traffic is unpredictable, spiky, or
when you simply don't want to manage capacity units. The trade-off is cost:
provisioned is cheaper at sustained high throughput, on-demand is cheaper
at variable or low throughput.

</details>

<details>
<summary>Hint 3 — Exact setting</summary>

Set the capacity mode to **On-demand** (also called `PAY_PER_REQUEST` in
the API and CloudFormation). In the DynamoDB console when creating the
table, under **Table settings** → **Capacity mode** → select **On-demand**.
The validator will fail if the table is configured with Provisioned capacity.

</details>

---

## Requirement 3 — Global Secondary Index

<details>
<summary>Hint 1 — Why a GSI is needed</summary>

DynamoDB tables can only be queried efficiently by their primary key. The
table's primary key is `OrderId` + `CreatedAt`, which supports retrieving
orders by order ID. To also support retrieving orders by customer email,
you need a separate index with `CustomerEmail` as its partition key. This
is what a Global Secondary Index provides — an alternative access pattern
on a different key.

</details>

<details>
<summary>Hint 2 — GSI structure</summary>

A GSI has its own partition key (and optionally a sort key). It also has
a projection — a definition of which attributes from the base table are
copied into the index. There are three projection types: `KEYS_ONLY`
(only key attributes), `INCLUDE` (keys plus specific attributes you name),
and `ALL` (every attribute from the base table). The requirement states
that all attributes must be available when querying via the index.

</details>

<details>
<summary>Hint 3 — Exact GSI configuration</summary>

Create a GSI with:

- **Index name:** `kata-201-CustomerEmail-index`
- **Partition key:** `CustomerEmail` (String) — this becomes the HASH key
  of the index, enabling queries by customer email
- **Sort key:** none required
- **Projection:** `ALL` — projects all table attributes into the index

In the DynamoDB console, go to your table → **Indexes** tab →
**Create index**. Set the partition key to `CustomerEmail`, select
projection type **All**, and name the index `kata-201-CustomerEmail-index`.

> ℹ️ If you are using CloudFormation, `CustomerEmail` must also be declared
> in `AttributeDefinitions` even though it is not part of the table's
> primary key — any attribute used in any key schema must be declared there.

</details>

---

## Requirement 4 — Tags

<details>
<summary>Hint 1 — Where to add tags</summary>

In the DynamoDB console, navigate to your table → **Additional settings**
tab → **Tags** section → **Manage tags**. Add both required tags and save.

</details>

<details>
<summary>Hint 2 — Exact tag values</summary>

Tags are case-sensitive. The validator checks for these exact values:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-201`

</details>

---

## General Troubleshooting

<details>
<summary>Check 3 or 4 failing — key configuration</summary>

The validator checks both the attribute name and the key role (HASH or
RANGE). Common mistakes: setting `OrderId` as the sort key instead of the
partition key, or choosing Number type instead of String. Both `OrderId`
and `CreatedAt` must be String type. Check your table's key schema in
the DynamoDB console under the table's **Overview** tab.

</details>

<details>
<summary>Check 5 failing — capacity mode</summary>

The validator requires on-demand capacity (`PAY_PER_REQUEST`). If your
table was created with provisioned capacity, you can switch modes. In the
DynamoDB console go to your table → **Additional settings** tab →
**Read/write capacity** → **Edit** → change to **On-demand** → **Save**.

</details>

<details>
<summary>Check 7 failing — GSI partition key</summary>

The GSI's partition key must be `CustomerEmail`. If the validator reports
the GSI partition key is incorrect, check two things: (1) the attribute
name is spelled exactly `CustomerEmail` with that capitalization, and
(2) the attribute type is String. If you are using CloudFormation, confirm
`CustomerEmail` is declared in `AttributeDefinitions`.

</details>

<details>
<summary>AttributeDefinitions error in CloudFormation</summary>

A common CFN error when creating DynamoDB tables with GSIs is:
`Property AttributeDefinitions is inconsistent with the KeySchema`.
This means an attribute used in a key schema (table or GSI) is missing
from `AttributeDefinitions`. Every attribute used as a HASH or RANGE key
anywhere in the template must be declared in `AttributeDefinitions`.
Attributes that are not keys should NOT be declared there.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-201-solution
```

Then re-run `validate.sh`. A correctly deployed solution should score 9/9.
Study the solution to understand what you missed, then tear it down and
try again from scratch.