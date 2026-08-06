---
description: Describe unpushed jj changes
model: openai/gpt-5.6-luna
subtask: true
---

Describe every unpushed, non-empty jj change that lacks a description. Follow
this procedure exactly.

1. Find the changes with this command. Do not run `jj status`, broad `jj log`
   queries, or `jj bookmark list` first.

   ```sh
   jj log \
     -r 'remote_bookmarks().. & mutable() & ~empty() & description(exact:"")' \
     --no-graph \
     -T 'change_id ++ "\n"'
   ```

   Treat each output line as a full, stable jj change ID. If there is no output,
   stop and report `Described 0 changes.`

2. Inspect every returned change in one command, passing each change ID as a
   separate argument:

   ```sh
   jj show CHANGE_ID_1 CHANGE_ID_2 \
     -T '"=== " ++ change_id.short() ++ " " ++ description.first_line() ++ " ===\n"'
   ```

   Add or remove `CHANGE_ID_N` arguments to match the discovery output. Do not
   use `jj diff -r` for multiple changes because it can combine a connected set
   into one aggregate diff. Determine one concise, accurate description for each
   individual change.

3. Apply distinct descriptions sequentially in one shell invocation, using the
   full change IDs from step 1:

   ```sh
   jj desc -r CHANGE_ID_1 -m 'Description one' &&
   jj desc -r CHANGE_ID_2 -m 'Description two'
   ```

   Generate one `jj desc` command per change. Do not run these commands in
   parallel. Do not use commit IDs: descriptions rewrite commits, while change
   IDs remain stable through descendant rebases.

4. Run the exact discovery command from step 1 again. It must produce no output.
   If any change IDs remain, inspect and describe them before reporting success.

Provide only this summary:

Described {n} changes:

- {jj-change-id} Description of change
- {jj-change-id} Description of another change
