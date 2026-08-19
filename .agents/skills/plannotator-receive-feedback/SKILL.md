---
name: plannotator-receive-feedback
description: Act on feedback returned from a Plannotator review only when the user's feedback clearly requests changes. Use when Plannotator returns review, annotation, or plan feedback to the agent.
---

# Receive Plannotator Feedback

Treat feedback returned by Plannotator as user feedback.

## When to make changes

Make the requested changes without waiting for another user message only when the
feedback clearly indicates that action should be taken. Clear signals include
direct requests such as "change," "fix," "remove," "add," "rename," "update,"
"replace," or an equally unambiguous instruction.

Apply only the clearly requested changes. If a review contains both clear and
ambiguous items, act on the clear items without guessing at the others.

## When not to make changes

Do not change code, plans, documents, or prior responses based only on:

- approval or LGTM-style feedback
- observations or informational notes
- questions that do not also request a change
- optional ideas or tentative suggestions
- ambiguous feedback whose desired action is unclear

Do not infer a change request merely because feedback exists. If action may be
wanted but is not clear, briefly acknowledge the feedback or ask a focused
clarifying question instead.

After making clearly requested changes, verify them using the narrowest relevant
checks and summarize what changed.
