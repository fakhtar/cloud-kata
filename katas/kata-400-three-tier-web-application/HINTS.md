# kata-400 Hints — Three-Tier Web App: CloudFront, ALB, EC2 & RDS in Multi-AZ

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

## Requirement 1 — VPC & Subnetting

<details>
<summary>Hint 1 — Public vs. private is about routing, not naming</summary>

A subnet is not "public" or "private" because you named it that way — it is
public if its route table sends `0.0.0.0/0` traffic to an Internet Gateway.
Naming a subnet `kata-400-PrivateSubnet1` does nothing on its own. Check
the route table, not the subnet name.

</details>

<details>
<summary>Hint 2 — The outbound-access requirement has exactly one answer</summary>

Requirement 1 says private-subnet instances must be able to download patches
and updates without being directly reachable from the internet. There is
only one AWS-native mechanism that satisfies both halves of that constraint
simultaneously: a **NAT Gateway**, placed in a public subnet, with the
private route table's `0.0.0.0/0` route pointed at it. A NAT instance is a
legacy alternative but is not the AWS-recommended pattern for new
architecture. If you skip the NAT Gateway, private instances can boot but
will fail to reach package repositories.

</details>

<details>
<summary>Hint 3 — Exact resource chain for the NAT path</summary>

The full chain, in order:

1. `AWS::EC2::EIP` with `Domain: vpc` — the NAT Gateway needs a static public
   IP
2. `AWS::EC2::NatGateway` — takes the EIP's `AllocationId` (via
   `Fn::GetAtt`, not `Ref` — `Ref` on an EIP returns the IP address itself,
   not the allocation ID) and a **public** subnet ID
3. A private route table with a `0.0.0.0/0` route whose target is
   `NatGatewayId`, not `GatewayId`
4. Both private subnets associated with that private route table

The EIP should depend on the VPC's Internet Gateway attachment
(`DependsOn`) — allocating an EIP before the IGW is attached can fail in
some accounts.

</details>

---

## Requirement 2 — Security Groups

<details>
<summary>Hint 1 — Three groups, one direction of trust each</summary>

Think of this as a strict pipeline: internet → ALB → EC2 → DB. Each
security group should only trust the group immediately before it in that
chain, never anything further back and never the raw internet (except the
ALB, which is the front door by design).

</details>

<details>
<summary>Hint 2 — Reference security groups by ID, not by CIDR</summary>

"Only from the ALB's security group" means the ingress rule's *source* is
another security group, not an IP range. In the console this is the
"Source" field on an inbound rule — search for the security group by name
instead of typing a CIDR. A rule with `0.0.0.0/0` anywhere on the EC2 or DB
tier fails the validator's isolation checks, even if a correct
security-group-sourced rule also exists alongside it.

</details>

<details>
<summary>Hint 3 — Avoid the circular-dependency trap in CloudFormation</summary>

If you're using CloudFormation: do **not** embed cross-referencing ingress
rules directly inside two `AWS::EC2::SecurityGroup` resources that
reference each other. AWS's own documentation warns this creates a
circular dependency that CloudFormation cannot resolve. Instead, declare
the three security groups with no embedded ingress (or only CIDR-based
ingress, like the ALB's), then add the cross-referencing rules as separate
`AWS::EC2::SecurityGroupIngress` resources:

```yaml
EC2SecurityGroupIngressFromALB:
  Type: AWS::EC2::SecurityGroupIngress
  Properties:
    GroupId: !GetAtt EC2SecurityGroup.GroupId
    IpProtocol: tcp
    FromPort: 8080
    ToPort: 8080
    SourceSecurityGroupId: !GetAtt ALBSecurityGroup.GroupId
```

This isn't strictly circular in a three-tier linear chain (ALB → EC2 → DB),
but following the documented pattern avoids any ordering ambiguity.

</details>

---

## Requirement 3 — Application Load Balancer

<details>
<summary>Hint 1 — Scheme and subnet placement are separate settings</summary>

An ALB's `Scheme` (internet-facing vs. internal) and which subnets it's
placed in are independent choices that must agree with each other. An
internet-facing ALB placed in private subnets will fail to provision
correctly. Double-check both.

</details>

<details>
<summary>Hint 2 — The target group needs a registered target before it can be healthy</summary>

An empty target group with zero registered targets isn't "unhealthy" — it
has no health state to report at all. If Check 9 in the validator fails
with zero healthy targets, first confirm the Auto Scaling group
(Requirement 4) actually has running instances and that they're attached
to this target group, before troubleshooting the health check itself.

</details>

<details>
<summary>Hint 3 — Health check path and target port must match what's actually running</summary>

The target group's health check path and port need to match the
application listening on the instance. If your instances run a simple HTTP
server on port 8080 with content at `/`, the target group's `Port` should
be `8080` and `HealthCheckPath` should be `/` — a mismatch here (e.g.
checking port 80 while the app listens on 8080) produces `unhealthy`
targets that look identical to a broken security group rule from the
outside. Check both possibilities: the EC2 security group's ingress port
and the target group's configured port must be the same number.

</details>

---

## Requirement 4 — EC2 Auto Scaling Group

<details>
<summary>Hint 1 — Launch templates, not launch configurations</summary>

Launch configurations are the older, deprecated mechanism. Use
`AWS::EC2::LaunchTemplate` (or the equivalent console flow) — it's required
for newer instance features and is what current AWS guidance recommends.

</details>

<details>
<summary>Hint 2 — HealthCheckType matters</summary>

By default, an Auto Scaling group only checks EC2 status (is the instance
running?), not application health. Set `HealthCheckType: ELB` so the ASG
also considers the ALB target group's health check result — otherwise a
broken application on port 8080 can still show as `InService` in the ASG
even though the ALB is correctly refusing to route traffic to it.

</details>

<details>
<summary>Hint 3 — UserData needs to actually produce a health-check-passable response</summary>

Something needs to be listening on the target group's configured port
before the health check will ever pass. A minimal approach that needs no
package installation:

```bash
#!/bin/bash
mkdir -p /opt/app
echo "OK" > /opt/app/index.html
cd /opt/app
nohup python3 -m http.server 8080 &
```

Base64-encode this into the launch template's `UserData` field. Don't
forget: changes to `UserData` require a new launch template *version*, and
the Auto Scaling group must reference that new version (or `$Latest`) for
existing or newly-launched instances to pick it up.

</details>

---

## Requirement 5 — RDS Database (Multi-AZ)

<details>
<summary>Hint 1 — Multi-AZ takes longer than you expect</summary>

A Multi-AZ `db.t3.micro` instance typically takes 10–20 minutes to reach
`available`, sometimes longer. During that window you'll see status values
like `creating`, `backing-up`, and `modifying` — all of these are normal
provisioning states, not signs of a stuck deployment. Don't assume
something is broken just because Check 12 in the validator is failing five
minutes after you kicked off the deploy.

</details>

<details>
<summary>Hint 2 — Diagnosing a slow RDS deployment</summary>

If you want to confirm progress rather than guess, the event timeline is
more informative than the status field alone:

```bash
aws rds describe-events \
  --source-identifier kata-400-DB \
  --source-type db-instance \
  --duration 60 \
  --query 'Events[*].{Time:Date,Message:Message}' \
  --output table
```

Healthy progress looks like a chronological sequence — "DB instance
created" → "Applying modification to convert to a Multi-AZ DB Instance" →
"Finished applying..." → "Backing up DB instance" — with new events
continuing to appear over time. A stuck deployment looks like the same
status persisting with no new events at all.

</details>

<details>
<summary>Hint 3 — DB subnet group and password management</summary>

The DB subnet group must contain **only** private subnets — if you
accidentally include a public subnet, the instance will still deploy, but
it fails the validator's network-isolation check. Confirm with:

```bash
aws rds describe-db-subnet-groups --db-subnet-group-name <your-group-name>
```

For credentials, avoid embedding a plaintext `MasterUserPassword` in your
template. Set `ManageMasterUserPassword: true` instead — RDS generates and
stores the password in Secrets Manager automatically, and you can retrieve
it via `Database.MasterUserSecret.SecretArn` if you ever need to connect
manually.

</details>

---

## Requirement 6 — CloudFront Distribution

<details>
<summary>Hint 1 — ALB origins use a different config block than S3 origins</summary>

Most CloudFront tutorials online use an S3 bucket as the origin, which uses
`S3OriginConfig`. An ALB is a **custom origin** and needs
`CustomOriginConfig` instead, with `OriginProtocolPolicy` set to how the
ALB actually serves traffic (`http-only` if the ALB only has an HTTP
listener, `https-only` if it terminates TLS).

</details>

<details>
<summary>Hint 2 — Cache policy is required, not optional, on modern CloudFront</summary>

`DefaultCacheBehavior` needs either a `CachePolicyId` (current, recommended
approach) or the older `ForwardedValues` block (deprecated). Since this
kata's ALB serves dynamic content from an Auto Scaling group rather than
static assets, use AWS's managed **CachingDisabled** policy so CloudFront
doesn't cache stale responses across instances:

```
CachePolicyId: 4135ea2d-6df8-44a3-9df3-4b5a84be39ad
```

</details>

<details>
<summary>Hint 3 — Deployment time and the disable-before-delete rule</summary>

CloudFront distributions take roughly 15–25 minutes to reach `Deployed`
status after creation *or* any modification — every fix you make costs
another wait. Verify your `Origins` and `DefaultCacheBehavior` configuration
carefully before deploying rather than iterating blindly.

Separately: a distribution must be **disabled** before it can be deleted.
If you're tearing down manually (not via CloudFormation), set
`Enabled: false`, wait for that change to propagate, then delete. Trying to
delete an enabled distribution will fail with an error regardless of how
you're managing it.

</details>

---

## Requirement 7 — End-to-End Integration

<details>
<summary>Hint 1 — Integration failures are usually one layer removed from where they appear</summary>

If the CloudFront check fails, the actual problem is often in the ALB or
target group, not CloudFront itself — CloudFront is just forwarding
whatever the ALB gives it. Work backward from the symptom: can you reach
the ALB's DNS name directly first? If not, fix that before touching
CloudFront.

</details>

<details>
<summary>Hint 2 — Cross-referencing checks depend on exact resource identity</summary>

Two checks in this requirement compare identifiers across services:
CloudFront's origin domain against the ALB's actual DNS name, and the
ASG's registered targets against the target group's healthy target list.
Both are exact-match comparisons. If you manually recreate the ALB after
initially setting up CloudFront, the ALB's DNS name changes and the
CloudFront origin becomes stale — you'd need to update the distribution
(and wait through another 15–25 minute deploy).

</details>

<details>
<summary>Hint 3 — Verifying the full chain via CLI before running the validator</summary>

```bash
# Confirm ALB DNS name
aws elbv2 describe-load-balancers --names kata-400-ALB \
  --query 'LoadBalancers[0].DNSName' --output text

# Confirm CloudFront's origin matches it
aws cloudfront list-distributions \
  --query "DistributionList.Items[*].Origins.Items[0].DomainName" --output text

# Confirm every ASG instance is a healthy target
TG_ARN=$(aws elbv2 describe-target-groups --names kata-400-TG \
  --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[*].{Id:Target.Id,State:TargetHealth.State}' \
  --output table

# Confirm no security group in the stack allows 0.0.0.0/0 to a non-ALB group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=kata-400-EC2-SG,kata-400-DB-SG" \
  --query 'SecurityGroups[*].IpPermissions[*].IpRanges[*].CidrIp' --output text
```

The last command should return nothing — any output means an open ingress
rule exists where it shouldn't.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-400-solution \
  --capabilities CAPABILITY_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score
14/14. Study the solution to understand what you missed, then tear it down
and try again from scratch.

> ⚠️ Remember: CloudFront distributions must be disabled before they can be
> deleted, and a Multi-AZ RDS instance bills for two instances the entire
> time it exists. Don't leave this stack running longer than your session.