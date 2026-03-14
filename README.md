# CloudKata ☁️🥋

> **Prove you know it by building it.**

CloudKata is an open source, self-graded AWS lab framework. You are given a set of infrastructure requirements, you build them in your own AWS account, and you run a single validation script that tells you exactly how you did.

No multiple choice. No honor system. Just real infrastructure, real AWS, and a score that reflects what you can actually build.

---

## How It Works

1. **Pick a kata** from the library based on your skill level
2. **Read the requirements** in `README.md` — you are given a spec, not a tutorial
3. **Build the infrastructure** in your own AWS account using any tools you choose
4. **Run the validator** in AWS CloudShell to get your score
5. **Clean up** your resources using the provided cleanup instructions

That's it. The validator checks your live AWS infrastructure against the kata requirements and reports a detailed pass/fail score for every check.

---

## Open Book by Design

CloudKata is intentionally open book. In the real world, engineers consult documentation, use AI assistants, and collaborate with colleagues. CloudKata evaluates whether you can *build*, not whether you can memorize.

You are encouraged to:
- Consult the AWS documentation
- Use AI assistants like Claude or ChatGPT
- Reference previous projects or notes
- Search the web
- Call a friend

How you get there is your business. The validator only cares about what you built.

---

## Using CloudKata in an Interview

CloudKata was partly born from the frustration of technical interviews that rely entirely on verbal questioning. Asking a candidate *about* Amazon Connect tells you very little about whether they can *use* Amazon Connect.

CloudKata gives interviewers a better option. Select one or more katas appropriate for the role, ask the candidate to demonstrate, and observe — not just what they build, but how they build it. Watch how they navigate unfamiliar territory, recover from mistakes, and structure their work under light pressure.

**As an interviewer, you will learn more from watching someone work than from asking them about their work.**

CloudKata is open book by default and by philosophy. Whether to restrict documentation or AI tools during an interview is the interviewer's prerogative, but the framework is designed with open book in mind.

### What to observe beyond the score
- Do they go straight to the console or do they reach for IaC?
- Do they read the docs or do they already know the service?
- How do they recover when something does not work?
- How do they structure and sequence their work?
- How do they communicate what they are doing?

---

## Kata Levels

CloudKata uses a college course numbering system to indicate difficulty:

| Level | Description |
|---|---|
| **100** | Introductory — single service, core concepts, minimal configuration |
| **200** | Foundational — moderate depth, some service interaction |
| **300** | Intermediate — multi-service, real-world patterns |
| **400** | Advanced — complex architecture, edge cases, production considerations |
| **500** | Expert — sophisticated multi-service solutions, deep configuration mastery |

---

## Kata Types

| Type | Description |
|---|---|
| **Depth** | Master a single AWS service — its hierarchy, configuration, and nuances |
| **Breadth** | Wire multiple AWS services together into a complete solution architecture |

---

## Kata Library

### 100 — Introductory

| ID | Title | Level | Type | Services | Status |
|---|---|---|---|---|---|
| [kata-100](./katas/kata-100-lexv2-basics/) | Amazon Lex V2 Basics — Bots, Intents & Slots | 100 | Depth | Lex V2 | Published |
| [kata-101](./katas/kata-101-iam-fundamentals/) | IAM Fundamentals — Roles, Policies & Trust Relationships | 100 | Depth | IAM | Published |


> Want to contribute a kata? Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for a roadmap.
Browse the [open issues](../../issues) to claim one, or propose a new one.

---

## Prerequisites

To run any CloudKata kata you will need:

- An active AWS account
- Access to [AWS CloudShell](https://aws.amazon.com/cloudshell/) — no local setup required
- Sufficient IAM permissions to create and describe the services covered in the kata
- Basic familiarity with the AWS Management Console or CLI

---

## Cost & Safety Warning

> ⚠️ **You are building infrastructure in your own AWS account. All costs incurred are your responsibility.**

Each kata includes an estimated cost and time to complete. Cost estimates assume you complete the kata in the allotted time and follow the cleanup instructions promptly. If you leave infrastructure running beyond the kata session, costs will continue to accumulate.

Every kata includes cleanup instructions. Always run them when you are done.

---

## Why I Built This

I have conducted a lot of technical interviews over the years. Like most interviewers, I relied on verbal questioning — asking candidates about AWS services, architecture decisions, and troubleshooting scenarios. I even used AI to generate better questions.

But I kept running into the same problem: **knowing how to answer a question about a service and knowing how to use that service are two very different things.**

A candidate can describe the difference between a Lex V2 intent and a slot type in perfect detail and still struggle to build a working bot from scratch. Verbal interviews don't surface that gap. CloudKata does.

I built the tool I wish I had — one that lets you watch someone work, not just talk. One that gives a fair, objective, reproducible score based on real infrastructure. One that respects how engineers actually work: with documentation, with AI, with the full toolkit available to them on the job.

CloudKata is open source because this problem is not unique to me. If you have ever sat across from a candidate and wished you could just say *show me*, this framework is for you too.

---

## Contributing

CloudKata grows through community contributions. If you want to contribute a kata, please read [CONTRIBUTING.md](./CONTRIBUTING.md) for the full kata specification, quality standards, and submission process.

Browse the [open issues](../../issues) to find a kata to claim. All open katas in the library table above have a corresponding GitHub issue. Comment on the issue to claim it before you start building.

---

## Created By

**Faisal Akhtar**
[LinkedIn](https://www.linkedin.com/in/faisalakhtar/) · [GitHub](https://github.com/fakhtar)

---

## License

This project is licensed under the [MIT License](./LICENSE).