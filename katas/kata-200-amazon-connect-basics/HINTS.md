# kata-200 Hints — Amazon Connect Basics: Instance, Hours of Operation & Queue

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

## Requirement 1 — Connect Instance

<details>
<summary>Hint 1 — What an instance is and where to start</summary>

An Amazon Connect instance is the top-level container for your contact center.
Everything else — queues, hours of operation, contact flows, agents — lives
inside an instance. Creating the instance is always the first step because no
dependent resource can exist without one.

Connect instances are created through the Amazon Connect console, the AWS CLI
(`aws connect`), or CloudFormation (`AWS::Connect::Instance`). The console
wizard asks several questions during setup; the key ones are the instance alias
and how users will be managed.

</details>

<details>
<summary>Hint 2 — Identity management and the instance alias</summary>

When creating an instance, AWS asks how you want to manage users. There are
three options: Connect's own built-in directory, an existing AWS Directory
Service directory, or a SAML 2.0 identity provider. For this kata there is no
external directory — use Connect's built-in option.

The instance alias becomes part of the URL used to access the Connect admin
interface and must be globally unique across all AWS accounts. It can contain
letters, numbers, and hyphens, and must not start with `d-`.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Instance alias:** `kata-200-instance`
- **Identity management type:** `CONNECT_MANAGED` (Connect's built-in user
  directory — select "Store users in Amazon Connect" in the console)

In the Amazon Connect console, choose **Add an instance**, select
**Store users in Amazon Connect**, enter `kata-200-instance` as the alias,
and step through the wizard accepting the defaults for the remaining pages
(telephony, data storage, and so on). The instance will show a status of
**Creating** for several minutes before becoming active.

In CloudFormation, use `AWS::Connect::Instance` with:
```yaml
IdentityManagementType: CONNECT_MANAGED
InstanceAlias: kata-200-instance
Attributes:
  InboundCalls: true
  OutboundCalls: true
```

`Attributes` with at least `InboundCalls` and `OutboundCalls` is required by
the CloudFormation schema even if you do not plan to use telephony.

</details>

---

## Requirement 2 — Hours of Operation

<details>
<summary>Hint 1 — What hours of operation do</summary>

An hours of operation resource defines when your contact center is open. It is
a named schedule attached to your instance. Queues reference it to determine
whether to accept or block incoming contacts. A queue cannot exist without an
hours of operation — it is a required dependency, not an optional setting.

Hours of operation live inside an instance, so you must have a working instance
before you can create them.

</details>

<details>
<summary>Hint 2 — Schedule structure and timezone</summary>

A schedule is made up of individual day entries, each specifying a start time
and end time. You need one entry per day you want the contact center to be open.
Five entries are needed to cover Monday through Friday. Times are expressed in
24-hour format using separate hours and minutes values.

You also need to choose a timezone for the schedule. Connect uses IANA timezone
names (for example, `America/New_York` or `Europe/London`). The timezone
determines how the times are interpreted — if you want 09:00 to mean 9 AM
Eastern, choose an Eastern timezone.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Name:** `kata-200-BasicHours`
- **Instance:** `kata-200-instance`
- **Timezone:** any valid IANA timezone (e.g. `America/New_York`)
- **Schedule:** five entries, one per weekday, each with start `09:00` and end
  `17:00` — expressed as `Hours: 9, Minutes: 0` and `Hours: 17, Minutes: 0`

In the Amazon Connect admin console, go to **Routing** → **Hours of operation**
→ **Add new set of hours**. Set the name, choose a timezone, then configure
five rows for Monday through Friday with 9:00 AM to 5:00 PM.

In CloudFormation, use `AWS::Connect::HoursOfOperation`:
```yaml
Name: kata-200-BasicHours
InstanceArn: !GetAtt ConnectInstance.Arn
TimeZone: America/New_York
Config:
  - Day: MONDAY
    StartTime: { Hours: 9, Minutes: 0 }
    EndTime:   { Hours: 17, Minutes: 0 }
  - Day: TUESDAY
    StartTime: { Hours: 9, Minutes: 0 }
    EndTime:   { Hours: 17, Minutes: 0 }
  - Day: WEDNESDAY
    StartTime: { Hours: 9, Minutes: 0 }
    EndTime:   { Hours: 17, Minutes: 0 }
  - Day: THURSDAY
    StartTime: { Hours: 9, Minutes: 0 }
    EndTime:   { Hours: 17, Minutes: 0 }
  - Day: FRIDAY
    StartTime: { Hours: 9, Minutes: 0 }
    EndTime:   { Hours: 17, Minutes: 0 }
Tags:
  - Key: Project
    Value: CloudKata
  - Key: Kata
    Value: kata-200
```

</details>

---

## Requirement 3 — Queue

<details>
<summary>Hint 1 — What a queue is and what it needs</summary>

A queue is where contacts wait until an agent is available to handle them.
Every queue in Connect must be associated with an hours of operation — Connect
uses this association to determine when the queue is open and eligible to
receive contacts. The hours of operation must already exist before you create
the queue.

</details>

<details>
<summary>Hint 2 — Creating the queue and linking it to hours of operation</summary>

In the Connect admin console, go to **Routing** → **Queues** → **Add new queue**.
Give it a name and then choose the hours of operation from a dropdown. The
dropdown lists all hours of operation in the current instance — you should see
`kata-200-BasicHours` there once it has been created.

Via the CLI, `aws connect create-queue` takes `--hours-of-operation-id`, which
accepts either the ID or the ARN of the hours of operation.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Queue name:** `kata-200-BasicQueue`
- **Instance:** `kata-200-instance`
- **Hours of operation:** `kata-200-BasicHours`

In CloudFormation, use `AWS::Connect::Queue`. The `HoursOfOperationArn`
property requires the full ARN of the hours of operation — use `!GetAtt` to
reference it from the hours of operation resource:

```yaml
Name: kata-200-BasicQueue
InstanceArn: !GetAtt ConnectInstance.Arn
HoursOfOperationArn: !GetAtt BasicHours.HoursOfOperationArn
Tags:
  - Key: Project
    Value: CloudKata
  - Key: Kata
    Value: kata-200
```

Note that the property is called `HoursOfOperationArn` (requires the ARN),
not `HoursOfOperationId`.

</details>

---

## Requirement 4 — Tags

<details>
<summary>Hint 1 — Which resources need tags</summary>

Tags are required on the hours of operation and the queue. The Connect instance
itself does not need to be tagged for this kata — Connect instances have limited
tagging support through CloudFormation, and the validator does not check instance
tags.

</details>

<details>
<summary>Hint 2 — Where to add tags in the console</summary>

For **hours of operation**: open the hours of operation in the Connect admin
console, scroll to the **Tags** section at the bottom of the page, and add the
tags there.

For the **queue**: open the queue in the Connect admin console under
**Routing** → **Queues**, scroll to the **Tags** section, and add the tags.

Alternatively, both resources can be tagged via the CLI using
`aws connect tag-resource --resource-arn <arn> --tags Key=Project,Value=CloudKata Key=Kata,Value=kata-200`.

</details>

<details>
<summary>Hint 3 — Exact tag values</summary>

Tags are case-sensitive. The validator uses `aws connect list-tags-for-resource`
and checks for these exact values on both the hours of operation and the queue:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-200`

The Connect tagging API returns tags as a flat map `{"tags": {"Key": "Value"}}`.
If tags appear in the console but the validator still fails, confirm the exact
spelling and capitalisation match.

</details>

---

## General Troubleshooting

<details>
<summary>Check 2 failing — instance stuck in CREATION_IN_PROGRESS</summary>

Connect instances typically take 2–5 minutes to become ACTIVE after the API
call returns. The validator polls for up to 5 minutes before marking this check
as failed. If you are seeing this after waiting, check the Connect console for
a `CREATION_FAILED` status — this usually means the instance alias is already
in use by another account (aliases are globally unique). If creation failed,
delete the instance and choose a different alias, then re-create.

</details>

<details>
<summary>Check 4 failing — schedule does not match Monday-Friday 09:00-17:00</summary>

The validator calls `describe-hours-of-operation` and checks that all five
weekday entries (MONDAY through FRIDAY) have `StartTime.Hours == 9`,
`StartTime.Minutes == 0`, `EndTime.Hours == 17`, and `EndTime.Minutes == 0`.
Common causes of failure: configuring only some days (e.g. missing Friday),
using 12-hour time incorrectly (entering `9` for 9 PM instead of `21`), or
having non-zero minutes (e.g. `StartTime.Minutes: 1` instead of `0`). Check
the `Config` array in `describe-hours-of-operation` output directly to debug.

</details>

<details>
<summary>Check 6 failing — queue not associated with correct hours of operation</summary>

The validator calls `describe-queue` and compares `.Queue.HoursOfOperationId`
against the ID of `kata-200-BasicHours`. If you created the queue before the
hours of operation existed, the queue may have been linked to the default
hours of operation that Connect creates automatically. In the Connect admin
console, open the queue under **Routing** → **Queues** and verify that the
hours of operation field shows `kata-200-BasicHours`. If it shows something
else, update the queue to reference the correct hours of operation.

</details>

<details>
<summary>Check 7 or 8 failing — tags not found</summary>

Connect uses its own tagging API (`list-tags-for-resource`) which returns a
lowercase `tags` map. If you tagged the resources through CloudFormation or the
console and the check still fails, verify the resource ARNs are correct — the
ARN format for Connect resources is:
`arn:aws:connect:{region}:{account}:instance/{instance-id}/operating-hours/{hours-id}`
for hours of operation, and
`arn:aws:connect:{region}:{account}:instance/{instance-id}/queue/{queue-id}`
for queues. The validator pulls these ARNs from `list-hours-of-operations` and
`list-queues` output, so if those resources were found by name, the ARN used
for tag lookup should be correct.

</details>

<details>
<summary>CloudFormation stack stuck in CREATE_IN_PROGRESS for the instance</summary>

CloudFormation waits for the instance to reach ACTIVE before signalling success
on the `AWS::Connect::Instance` resource. This typically takes 3–5 minutes.
If the stack is still in `CREATE_IN_PROGRESS` after 10 minutes, check the
CloudFormation events tab for errors. A common cause is hitting the 30-day
instance creation limit — the event will show a service error message indicating
the limit has been reached.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-200-solution
```

No `--capabilities` flag is required because the template does not create any
IAM resources.

Then re-run `validate.sh`. A correctly deployed solution should score 8/8.
Study the solution to understand what you missed, then tear it down and try
again from scratch.