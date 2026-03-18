---
description: Analyze prior OpenCode sessions for this repo
agent: general
subtask: true
---

Use the `opencode-introspect` skill.

Analyze OpenCode sessions for the current repository using the OpenCode CLI.

Do not stop after exploration. Synthesize the findings and return exactly one final message.

Required workflow:

1. Use `opencode session list --format json` to enumerate sessions.
2. Filter to sessions for the current repo by matching `directory` and/or `projectId`.
3. Export the relevant sessions with `opencode export <session-id>`.
4. Inspect those conversations for durable patterns.

Focus on:

- repeated user preferences
- recurring agent confusion or wheel-spinning
- missing repo guidance that should become a skill, command, or `AGENTS.md` rule
- concrete recommendations that would make future OpenCode sessions faster and more accurate

If arguments are provided, treat them as the analysis focus: `$ARGUMENTS`.

Return:

Use these exact headings:

- `User Preferences`
- `Failure Patterns`
- `Missing Guidance`
- `Recommended Skills Or Commands`
- `Top 3 Follow-Ups`

Requirements:

- complete the workflow before responding
- prefer durable patterns over one-off incidents
- include concrete repo-specific recommendations
- if no relevant sessions are found, say that explicitly instead of returning an empty result
- do not return tool logs or raw exports unless needed for a short quote

In the final message, provide:

- a concise behavioral/profile summary for this repo
- the strongest recurring failure patterns
- recommended new or updated skills/commands/instructions
- the top 3 highest-leverage follow-ups
