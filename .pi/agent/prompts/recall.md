---
description: Recall an Obsidian Scratchpad note into the conversation
argument-hint: "<topic>"
---

# Recall Topic

Use `obsidian-stash` to recall a note related to:

<topic>
$ARGUMENTS
</topic>

Pi tokenizes the command tail with shell-like quote handling and then rejoins
the arguments for `$ARGUMENTS`. Treat this normalized text as fuzzy search
guidance, not as an exact filename.

Follow this procedure exactly:

1. If the topic is empty, infer it from the current conversation only when it is
   unambiguous. Otherwise, ask the user what should be recalled.
2. Run `obsidian-stash candidates "<search terms>"` exactly once, replacing the
   placeholder with the inferred topic text. Do not invoke `obsidian` directly
   or run additional searches. If the helper reports an error, report it clearly
   and stop.
3. Use the returned filenames and content matches as fuzzy evidence. Give exact
   identifiers such as ticket numbers extra weight. The topic need not match a
   filename exactly.
4. If one note is clearly the intended match, run
   `obsidian-stash read "<Scratchpad/path.md>"` exactly once, replacing the
   placeholder with the chosen path, to load the complete note into context. If
   multiple notes remain plausible, use the available user-question tool to ask
   which one is intended before reading. Do not silently choose an uncertain
   match.
5. If no suitable note exists, say so clearly. Do not create one unless the user
   asks.

After loading a note, tell the user which `Scratchpad/...` path was recalled,
briefly confirm that it is now in context, and ask what they would like to do
next.
