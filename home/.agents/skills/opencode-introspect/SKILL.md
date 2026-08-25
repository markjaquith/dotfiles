---
name: opencode-introspect
description: Inspect OpenCode session history for the current repo, extract recurring user preferences and agent failure patterns, and recommend repo-specific skills or instructions to reduce repeated confusion.
---

# OpenCode Introspect

Use this skill when the user wants you to learn from prior OpenCode conversations in the current repository.

## Goal

Review the repository's OpenCode session history and produce actionable judgments such as:

- recurring user preferences
- common prompt patterns
- places where the agent repeatedly gets confused or wastes time
- candidate skills, commands, or AGENTS.md guidance that would prevent repeat mistakes

## Primary Workflow

1. Identify the current repository's OpenCode project ID.
2. List sessions in JSON.
3. Filter to sessions for the current repo.
4. Export the relevant sessions.
5. Read the conversations and synthesize patterns.
6. Recommend concrete follow-up guidance or skills.

## How To Find Sessions

Prefer the OpenCode CLI over filesystem spelunking.

Get the project sessions in JSON:

```bash
opencode session list --format json
```

This returns objects that include fields like:

- `id`
- `title`
- `projectId`
- `directory`
- `created`
- `updated`

When you only want a recent sample first:

```bash
opencode session list --max-count 20 --format json
```

## How To Scope To The Current Repo

Treat sessions as belonging to the current repo when either of these match:

- `directory` equals the current repo root
- `projectId` matches the repo's OpenCode project ID

If you need to verify the repo's project ID, you can often infer it from session list output for the current working directory. If needed, the git worktree may also contain a `.git/opencode` file with the project ID.

## How To Export Conversations

Export a full session as JSON:

```bash
opencode export <session-id>
```

The export includes:

- session metadata
- user messages
- assistant messages
- tool calls
- tool outputs
- model and agent metadata

Prefer reading exported sessions over trying to infer behavior from titles alone.

## What To Look For

Extract patterns that are durable and useful, not one-off trivia.

Pay special attention to:

- instructions the user repeats across sessions
- formatting preferences the user corrects repeatedly
- repo conventions the agent keeps rediscovering
- commands or checks the agent should have run sooner
- places the agent over-explores when a narrower path exists
- places the agent asks unnecessary permission questions
- repeated misunderstandings of project structure or naming
- recurring review/debugging tasks that deserve a reusable skill

## Recommended Analysis Structure

Return findings in sections like:

### User Preferences

- stable preferences about tone, brevity, output shape, or workflow

### Agent Failure Patterns

- where the agent tends to get confused, stall, over-search, or miss obvious repo cues

### Missing Reusable Guidance

- guidance that should probably live in `AGENTS.md`, a skill, or a custom command

### Candidate Skills Or Commands

- concrete proposals such as `rails-pr-review`, `narrow-rspec-debug`, or `github-pr-audit`

For each candidate, explain:

- what repeated problem it addresses
- what trigger phrases should invoke it
- what exact behavior it should standardize

## Heuristics

- Weight repeated patterns more heavily than isolated incidents.
- Prefer evidence from user prompts and final assistant answers over raw chain-of-thought-like reasoning artifacts.
- Use tool traces to understand process failures, not to overfit on incidental details.
- Distinguish repo-specific lessons from global user preferences.
- Quote short snippets when they sharpen the point.

## Output Expectations

Be concrete. Avoid vague statements like "the agent should do better research."

Prefer statements like:

- "Across 6 review sessions, the agent re-learned that PR review questions should start with `gh pr view` plus targeted file reads. A repo-specific PR review skill would likely reduce this churn."
- "The user repeatedly asks for concise judgment calls rather than exhaustive walkthroughs; default to short answers unless asked to expand."

When enough evidence exists, end with a short prioritized list of the top 3 improvements that would most reduce wasted tokens or repeated confusion.
