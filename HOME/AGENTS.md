# Herdr guidelines

If the user says "in a new tab" or "in a new workspace" then unless there is clear evidence showing they mean something else, assume that they mean "in a new Herdr tab (same workspace)" and "in a new Herdr workspace". Use the `herdr` skill. NEVER auto-focus a newly created Herdr tab or Herdr workspace.

# Agency guidelines

If the user says to "open" or "view" or "materialize" an agency item (task, phase, epic), then by default that means to open it in a new Herdr tab, defaulting to the same workspace as the request was made in. Then, after naming the tab appropriately, you should `cd` to the item and run `agency work .` with no `--auto` flag. Then, in that same tab, open a new side-by-side split, and open the work item's plan document in neovim, i.e. `nvim TASK.md` or `nvim PHASE.md` or `nvim EPIC.md`.

If the user says to "create" an agency item, then by default you should create it in the @agency subagent, and then "open" the item in a new tab, as outlined above.

If, however, the user says to "work" or "launch" or "start" an agency item, then do all of the above, but pass the `--auto` flag so agency starts working on the item.

Be smart about composing these. i.e. do the right thing for "create and work" or "create and open"

## Examples

- Prompt: `make this task` Outcome: create, open and work without `--auto`
- Prompt: `launch this task` Outcome: open and work with `--auto`
- Prompt: `create and work this phase` Outcome: create, open, and work with `--auto`
