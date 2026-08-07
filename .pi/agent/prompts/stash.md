---
description: Save the latest understanding of a topic to Obsidian Scratchpad
argument-hint: "<topic>"
---

# Stash Topic

Use `obsidian-stash` to preserve the latest understanding of this topic from the
current conversation:

<topic>
$ARGUMENTS
</topic>

Pi tokenizes the command tail with shell-like quote handling and then rejoins
the arguments for `$ARGUMENTS`. Treat this normalized text as a topic hint, not
as an exact filename.

Follow this procedure exactly:

1. If the topic is empty, infer it from the current conversation only when it is
   unambiguous. Otherwise, ask the user what should be stashed.
2. Run `obsidian-stash candidates "<search terms>"` exactly once, replacing the
   placeholder with the inferred topic text. Do not invoke `obsidian` directly
   or run additional searches. If the helper reports an error, report it clearly
   and stop.
3. Use the returned filenames and content matches as fuzzy evidence. Give exact
   identifiers such as ticket numbers extra weight.
4. If exactly one note is clearly about the same topic, use its path. If
   multiple notes are plausible and choosing the wrong one would overwrite
   information, use the available user-question tool to ask which note to use.
   If none match, choose a concise, human-readable `Scratchpad/...md` path that
   preserves recognizable identifiers.
5. Write a self-contained handoff artifact for another agent. Capture the latest
   understanding, important decisions and rationale, relevant facts and
   artifacts, current state, caveats, and useful next steps. Do not recreate a
   turn-by-turn transcript, retain superseded exploration, or invent missing
   details.
6. Pass the complete note on stdin to
   `obsidian-stash write "<Scratchpad/path.md>"` exactly once, replacing the
   placeholder with the chosen path. Use a quoted heredoc so shell expansion
   cannot alter the note:

   ```bash
   obsidian-stash write "<Scratchpad/path.md>" <<'OBSIDIAN_STASH_EOF'
   <complete note>
   OBSIDIAN_STASH_EOF
   ```

   Do not invoke `obsidian` directly.

7. Run `obsidian-stash read "<Scratchpad/path.md>"` exactly once, replacing the
   placeholder with the same path, and verify that the returned note contains
   the intended content.

Finish by reporting whether the note was created or updated and give its
`Scratchpad/...` path.
