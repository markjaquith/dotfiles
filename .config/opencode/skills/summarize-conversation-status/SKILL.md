---
name: summarize-conversation-status
description: Summarize the current conversation state in one sentence
---

## Goal

Provide a single-sentence status summary of the current conversation and work state.

## Instructions

When this skill is invoked:

1. Review the most recent user request, completed work, pending work, and any blockers.
2. Produce exactly one sentence.
3. Keep it concise and specific.
4. Mention what is done and what is next when applicable.
5. Do not ask follow-up questions unless the user explicitly asks for questions.

## Output Rules

- Output only the sentence.
- No bullets, headers, or extra commentary.
- If there is no active work, state that no active tasks are in progress.
