# kata-102 Hints — Lambda Essentials: Functions, Triggers & Environment Variables

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
<summary>Hint 1 — Where to start</summary>

Navigate to the Lambda console and choose **Create function**. Select
**Author from scratch** — you are providing the code directly, not using
a blueprint or container image.

</details>

<details>
<summary>Hint 2 — Runtime and handler</summary>

Select **Python 3.12** as the runtime. The handler tells Lambda which file
and function to call when the function is invoked. It follows the format
`filename.function_name`. The file created by Lambda when you paste inline
code is named `lambda_function` by default in the console — but the validator
checks for `lambda_handler` as the function name. Make sure your handler
setting matches where your code actually lives.

</details>

<details>
<summary>Hint 3 — Pasting the code</summary>

In the Lambda console, after creating the function, go to the **Code** tab
and replace the default code with the code provided in the README. After
pasting, click **Deploy** to save the changes. A function that has not been
deployed will run the old code and may fail the invocation check.

If you are using CloudFormation with the `ZipFile` inline property, CFN
automatically creates a file named `index.py`. Your handler must be set to
`index.lambda_handler` to match.

</details>

---

## Requirement 2 — Execution Role

<details>
<summary>Hint 1 — What the execution role does</summary>

Every Lambda function needs an IAM role that it assumes at runtime. This
role controls what AWS services the function can call. At minimum, the role
needs permission to write logs to CloudWatch Logs — without this, Lambda
cannot record any output and the function may behave unexpectedly.

</details>

<details>
<summary>Hint 2 — Creating the role</summary>

When creating a Lambda function via the console, you can let AWS create a
basic execution role automatically. This role will be named something generic
by default. For this kata the role must be named `kata-102-LambdaExecutionRole`
exactly — the validator checks for this name. If you let the console create
a role automatically, rename it or create a separate role with the correct name.

</details>

<details>
<summary>Hint 3 — Attaching the right policy</summary>

The AWS managed policy `AWSLambdaBasicExecutionRole` grants the minimum
permissions needed for a Lambda function to write logs to CloudWatch Logs.
Attach this policy to `kata-102-LambdaExecutionRole`. The full ARN is:

```
arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Note the `/service-role/` path — this is different from policies stored
at the root path and is a common source of confusion.

> ⚠️ Using an AWS managed policy is acceptable for this kata because the
> focus is Lambda configuration, not IAM least privilege. In production,
> always author a scoped customer managed policy. See kata-101 for a deep
> dive on IAM least privilege.

</details>

---

## Requirement 3 — Environment Variable

<details>
<summary>Hint 1 — What environment variables are for</summary>

Environment variables let you change a function's behavior without modifying
its code. They are set at the function configuration level and are available
to the function at runtime via `os.environ`. This is how real-world Lambda
functions receive configuration like database connection strings, feature
flags, and environment names.

</details>

<details>
<summary>Hint 2 — Where to set them in the console</summary>

In the Lambda console, navigate to your function → **Configuration** tab →
**Environment variables** → **Edit**. Add a new key-value pair. The key
and value are both case-sensitive.

</details>

<details>
<summary>Hint 3 — Exact key and value</summary>

The validator invokes your function and checks the response body for a
specific value. The environment variable must be set exactly as follows:

- **Key:** `APP_ENVIRONMENT`
- **Value:** `production`

If the key is missing or the value is anything other than `production`
(including `Production` or `PRODUCTION`), Check 5 and Check 9 will both
fail.

</details>

---

## Requirement 4 — Timeout and Memory

<details>
<summary>Hint 1 — Why these settings matter</summary>

Lambda's default timeout is 3 seconds and default memory is 128 MB. These
defaults are intentionally conservative. In real workloads you size these
based on your function's actual execution profile. This requirement tests
that you know where these settings live and how to change them — not that
you picked the optimal values.

</details>

<details>
<summary>Hint 2 — Where to find them in the console</summary>

In the Lambda console, navigate to your function → **Configuration** tab →
**General configuration** → **Edit**. Timeout and memory are both configured
here. Memory is set in MB increments. Timeout is set in minutes and seconds.

</details>

<details>
<summary>Hint 3 — Valid values that will pass</summary>

Any value above the defaults will pass:

- **Timeout:** Any value greater than 3 seconds (e.g. 30 seconds)
- **Memory:** Any value greater than 128 MB (e.g. 256 MB)

The validator checks thresholds, not specific values. Choose whatever
makes sense to you — the point is demonstrating that you know these
settings exist and how to configure them.

</details>

---

## Requirement 5 — Function State

<details>
<summary>Hint 1 — What function state means</summary>

A Lambda function can exist in several states. A newly created function
goes through an `Pending` state before becoming `Active`. An `Active`
function can be invoked immediately. A function in a failed or inactive
state cannot be invoked and will fail the validator's runtime check.

</details>

<details>
<summary>Hint 2 — How to check the state</summary>

In the Lambda console the function state is shown on the function overview
page. Via CLI:

```bash
aws lambda get-function-configuration \
  --function-name kata-102-EnvironmentReader \
  --query 'State'
```

Wait until the state returns `Active` before running the validator.

</details>

<details>
<summary>Hint 3 — If the function is not Active</summary>

If you deployed via CloudFormation and the stack completed successfully,
the function should be `Active` immediately. If you created the function
manually and it is stuck in `Pending`, wait 30-60 seconds and check again.
If the function is in a `Failed` state, check the function configuration
for errors — a missing execution role or invalid handler are the most
common causes.

</details>

---

## General Troubleshooting

<details>
<summary>Check 3 failing — handler not found</summary>

The validator checks that your handler references `lambda_handler`. The
most common mistake is leaving the handler as the console default
(`lambda_function.lambda_handler`) while naming the function differently
in the code, or setting the handler to `index.handler` instead of
`index.lambda_handler`. Check your function's **Configuration** →
**General configuration** → **Handler** field.

</details>

<details>
<summary>Check 8 or 9 failing — invocation errors</summary>

If the invocation check fails, test the function manually first. In the
Lambda console, go to the **Test** tab, create a test event with an empty
JSON payload `{}`, and invoke it. Check the response and logs. Common
causes: the code was never deployed after pasting (click **Deploy**),
the handler is pointing to the wrong function name, or the environment
variable is missing.

</details>

<details>
<summary>Check 9 failing but Check 8 passes</summary>

If the function returns statusCode 200 but the environment value check
fails, the `APP_ENVIRONMENT` environment variable is either missing or
set to the wrong value. The function falls back to `'unknown'` if the
variable is not set — check the **Configuration** → **Environment
variables** section and confirm the key is `APP_ENVIRONMENT` and the
value is `production` exactly.

</details>

---

## Still stuck?

The complete working solution is in [solution.yml](./solution.yml).

Deploy it with:

```bash
aws cloudformation deploy \
  --template-file solution.yml \
  --stack-name kata-102-solution \
  --capabilities CAPABILITY_NAMED_IAM
```

Then re-run `validate.sh`. A correctly deployed solution should score 9/9.
Study the solution to understand what you missed, then tear it down and
try again from scratch.