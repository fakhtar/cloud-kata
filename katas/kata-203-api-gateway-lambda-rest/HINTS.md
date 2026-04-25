# kata-203 Hints — API Gateway + Lambda: REST API & Proxy Integration

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

## Requirement 1 — Lambda Function

<details>
<summary>Hint 1 — What the function needs</summary>

A Lambda function needs two things to exist: code and an execution role. The
role controls what the function is allowed to do inside AWS. Even a function
that only returns a static response needs permission to write its logs somewhere.
Think about what AWS service Lambda uses for logging and what permissions that
requires.

</details>

<details>
<summary>Hint 2 — The execution role</summary>

Lambda writes logs to Amazon CloudWatch Logs. The AWS managed policy
`AWSLambdaBasicExecutionRole` grants exactly the permissions needed for this —
no more. Attach it to an IAM role whose trust policy allows `lambda.amazonaws.com`
to assume it. That role is then passed to the function.

The function code is provided in the README. Use Python 3.12 as the runtime.

</details>

<details>
<summary>Hint 3 — Exact configuration</summary>

- **Function name:** `kata-203-HandlerFunction`
- **Runtime:** Python 3.12
- **Handler:** `index.handler` (if using CloudFormation inline code, the file
  is automatically named `index.py`, so the handler identifier must start
  with `index`)
- **Role:** an IAM role with `AWSLambdaBasicExecutionRole` attached and a trust
  relationship allowing `lambda.amazonaws.com` to assume it

In the Lambda console, choose **Author from scratch**, set the runtime to
Python 3.12, and paste the function code from the README into the inline
editor. You can create the execution role directly in the console during
function creation by choosing **Create a new role with basic Lambda permissions**.

</details>

---

## Requirement 2 — REST API

<details>
<summary>Hint 1 — REST API vs HTTP API</summary>

API Gateway offers two main API types: REST APIs (v1) and HTTP APIs (v2). They
look similar in the console but behave differently and use different CLI
namespaces. This kata uses a REST API. When creating via the console, choose
**REST API** — not HTTP API, not WebSocket.

</details>

<details>
<summary>Hint 2 — Creating the API</summary>

In the API Gateway console, choose **Create API** then select **REST API**
(the non-private variant). Choose **New API** and set the name to
`kata-203-OrderAPI`. The endpoint type can be left as Regional. No other
settings are required at creation time.

</details>

<details>
<summary>Hint 3 — Exact name</summary>

The API must be named exactly `kata-203-OrderAPI`. The validator finds the API
by name using `aws apigateway get-rest-apis`, so capitalisation and hyphens
must match exactly.

</details>

---

## Requirement 3 — Resource and Method

<details>
<summary>Hint 1 — Resources and methods in API Gateway</summary>

In a REST API, a resource represents a URL path segment. A method sits on a
resource and defines how HTTP verbs (GET, POST, etc.) are handled. To expose
`GET /orders`, you need a resource at the path `/orders` and a GET method on
that resource.

</details>

<details>
<summary>Hint 2 — Creating the resource and method</summary>

In the API Gateway console, select your API, go to **Resources**, and create
a new resource with the path segment `orders` under the root `/`. Then select
that resource and create a method by choosing **Create method** and selecting
`GET` as the method type.

</details>

<details>
<summary>Hint 3 — Exact path</summary>

The resource path must be `/orders` — a single segment directly under the root.
The validator checks for this exact path using `aws apigateway get-resources`.
The GET method must be on that resource specifically, not on the root or any
other path.

If you are using CloudFormation, the `PathPart` property takes just the segment
name without the leading slash: `orders`, not `/orders`.

</details>

---

## Requirement 4 — Lambda Proxy Integration

<details>
<summary>Hint 1 — What proxy integration means</summary>

API Gateway supports two modes for Lambda integration. In a custom (non-proxy)
integration, API Gateway transforms the request and response using mapping
templates. In a proxy integration, API Gateway passes the entire HTTP request
to Lambda as a structured event and returns Lambda's response object directly
to the client — no mapping templates needed. The function is responsible for
returning a well-formed response with `statusCode`, `headers`, and `body`.

</details>

<details>
<summary>Hint 2 — Wiring the integration</summary>

When configuring the GET method, choose **Lambda function** as the integration
type and enable the **Lambda proxy integration** toggle. Point it at
`kata-203-HandlerFunction`. API Gateway will prompt you to add a resource-based
permission so it can invoke the function — accept this prompt.

If you decline or skip the permission step, the integration will be wired but
invocations will fail with a permissions error. The validator checks that the
integration type is `AWS_PROXY` and that the URI references the correct function.

</details>

<details>
<summary>Hint 3 — CloudFormation integration properties</summary>

In CloudFormation, the `Integration` block on `AWS::ApiGateway::Method` needs:

```yaml
Integration:
  Type: AWS_PROXY
  IntegrationHttpMethod: POST
  Uri: !Sub
    - "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${FunctionArn}/invocations"
    - FunctionArn: !GetAtt HandlerFunction.Arn
```

`IntegrationHttpMethod` must be `POST` for Lambda integrations — this is the
method API Gateway uses internally to call Lambda, regardless of the
client-facing HTTP method.

You also need a `AWS::Lambda::Permission` resource to allow API Gateway to
invoke the function:

```yaml
LambdaInvokePermission:
  Type: AWS::Lambda::Permission
  Properties:
    FunctionName: !GetAtt HandlerFunction.Arn
    Action: lambda:InvokeFunction
    Principal: apigateway.amazonaws.com
    SourceArn: !Sub "arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${OrderApi}/*/*/*"
```

</details>

---

## Requirement 5 — Deployment and Stage

<details>
<summary>Hint 1 — Why deployment is a separate step</summary>

In API Gateway REST APIs, changes to resources and methods are not live until
you deploy them. A deployment is a snapshot of your API configuration. A stage
is a named reference to a deployment — it is the URL prefix that callers use.
Until you deploy, the endpoint does not exist and cannot be invoked.

</details>

<details>
<summary>Hint 2 — Deploying in the console</summary>

In the API Gateway console, go to your API and choose **Deploy API** from the
**Actions** menu (or the **Deploy** button in the Resources view). When prompted,
create a new stage named `prod`. After deployment, the console will show the
invoke URL — it will look like
`https://{api-id}.execute-api.{region}.amazonaws.com/prod`.

Append `/orders` to that URL and verify that a GET request returns HTTP 200.

</details>

<details>
<summary>Hint 3 — CloudFormation deployment</summary>

Use `AWS::ApiGateway::Deployment` with `StageName: prod`. This resource must
have a `DependsOn` pointing to your method resource — without it, CloudFormation
may create the deployment before the method exists and fail with:
`The REST API doesn't contain any methods`.

```yaml
ApiDeployment:
  Type: AWS::ApiGateway::Deployment
  DependsOn: OrdersGetMethod
  Properties:
    RestApiId: !Ref OrderApi
    StageName: prod
```

</details>

---

## Requirement 6 — Tags

<details>
<summary>Hint 1 — Tagging both resources</summary>

This kata requires tags on two separate resources: the Lambda function and the
REST API. Tagging one without the other will cause checks 8 or 9 to fail. Both
resources must carry the same two tags.

</details>

<details>
<summary>Hint 2 — Where to add tags in the console</summary>

For the Lambda function: go to the function page, choose **Configuration** →
**Tags** → **Manage tags**.

For the REST API: go to the API in the API Gateway console, choose
**Settings** (at the API level, not the stage level) → **Tags** → **Add tag**.
Alternatively, navigate to the API's stage and add tags there — but note that
the validator checks tags on the REST API resource itself, not on the stage.

</details>

<details>
<summary>Hint 3 — Exact tag values</summary>

Tags are case-sensitive. The validator checks for these exact values on both
the Lambda function and the REST API:

- Key: `Project` — Value: `CloudKata`
- Key: `Kata` — Value: `kata-203`

</details>

---

## General Troubleshooting

<details>
<summary>Check 5 failing — integration type is not AWS_PROXY</summary>

The validator reads `.methodIntegration.type` from `get-method` and checks for
`AWS_PROXY`. If you chose **Lambda function** in the console without enabling
the **Use Lambda Proxy integration** checkbox, the type will be `AWS` instead.
Delete the method and recreate it with proxy integration enabled, or update the
integration type via the console under **Method Execution** → **Integration
Request** → **Integration type**.

</details>

<details>
<summary>Check 7 failing — endpoint returns non-200</summary>

A non-200 response from the endpoint usually means one of three things. First,
the Lambda permission is missing — API Gateway cannot invoke the function and
returns 500. In the console, go to the method's **Integration Request** and
check that a resource-based policy exists on the function. Second, the function
code is returning an unexpected status code — verify the code matches what is
in the README exactly. Third, the API has not been redeployed after a change —
any change to a method requires a new deployment before it takes effect.

</details>

<details>
<summary>Check 8 or 9 failing — tags not found</summary>

The validator uses two different APIs for tags. Lambda tags are retrieved with
`aws lambda list-tags` using the function ARN. API Gateway tags are retrieved
with `aws apigateway get-tags` using the REST API ARN, which has the format
`arn:aws:apigateway:{region}::/restapis/{api-id}` — note there is no account ID
in this ARN. If tags appear in the console but the validator still fails, verify
that tags are on the correct resource type (the REST API itself, not a stage
or deployment).

</details>

<details>
<summary>CloudFormation DependsOn error — REST API has no methods</summary>

If your stack fails with `The REST API doesn't contain any methods`, the
`AWS::ApiGateway::Deployment` resource was created before the method was ready.
Add `DependsOn: OrdersGetMethod` (or whatever your method's logical ID is) to
the deployment resource. CloudFormation does not automatically infer this
dependency because the deployment references only the RestApi ID, not the method.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-203-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

Note the `--capabilities CAPABILITY_NAMED_IAM` flag — it is required because
the template creates an IAM role with an explicit name.

Then re-run `validate.sh`. A correctly deployed solution should score 9/9.
Study the solution to understand what you missed, then tear it down and
try again from scratch.