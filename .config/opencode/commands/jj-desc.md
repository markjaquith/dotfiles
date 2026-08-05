---
description: Describe unpushed jj changes
model: openai/gpt-5.6-luna
---

Look at all unpushed jj changes that lack descriptions. For each, examine the
change, and use `jj desc -r {revision_id} -m "{description}"` to describe it.

Provide a summary like follows:

Described {n} changes:

- {jj-change-id} Description of change
- {jj-change-id} Description of another change
