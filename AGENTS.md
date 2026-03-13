# AGENTS.md

This repository is a live dotfiles repo rooted at `~/dotfiles`.
Treat it as environment configuration, not as an isolated app.

## Installing Things

A frequent user request you will get is to install a package. When the user says this they DO NOT mean that you should transiently install this package. They mean you should UPDATE THIS REPO to ensure that `dotfiles && dotfiles-install` installs that package. You MUST install the package in the appropriate `bin/dotfiles-install-*.zsh` file. e.g. if it's a Homebrew package, you must install it in `bin/dotfiles-install-brew.zsh`

## Repository Layout

- `bin/` contains executable install/sync scripts.
- `.zsh/` contains shell startup fragments and helper functions.
- `hk.pkl` defines the repo's hook-driven check/fix workflow.
- `.stowrc` controls what is and is not synced into `$HOME`.

## High-Signal Commands

### Setup / bootstrap

- `mise install` - install toolchain versions from `mise.toml`.
- `bun install` - install root dependencies from `package.json`.

### Lint / format / checks

- `hk run check` - best full-repo check command.
- `hk run fix` - best full-repo autofix command.
- `oxfmt --check <path>` - formatter check for one or more files.
- `oxfmt --write <path>` - formatter fix for one or more files.
- `bunx secretlint <path>` - secret scan specific files.
- `pkl eval hk.pkl >/dev/null` - validate the hook config.

### Type checking

- `bunx tsc --noEmit -p tsconfig.json` - root TS typecheck.
- `bunx tsc --noEmit -p .config/opencode/tsconfig.json` - typecheck the OpenCode TS subproject.

## Single-Test Equivalents

When asked to run a single test, use the narrowest relevant check for the file being changed:

- TypeScript file in `.config/opencode/`: `bunx tsc --noEmit -p .config/opencode/tsconfig.json`
- Specific TS file formatting: `oxfmt --check .config/opencode/plugin/block-git-push.ts`
- Specific TS file secret scan: `bunx secretlint .config/opencode/plugin/block-git-push.ts`
- zsh syntax check: `zsh -n bin/dotfiles-install-overlay.zsh`
- Pkl syntax check: `pkl eval hk.pkl >/dev/null`

If a change spans multiple file types, run the smallest set of relevant checks rather than pretending a unit test suite exists.

## Hook Workflow

- `hk.pkl` is the source of truth for check/fix behavior.
- `pre-commit` runs with `fix = true` and `stash = "patch-file"`.
- `pre-push` runs checks without autofixing.
- If a hook changes files, inspect the result and keep only intentional edits.

## Formatting Rules

- Follow `.editorconfig`: tabs, size 2.
- Follow `.oxfmtrc.json`: tabs, width 2, no semicolons, print width 80.
- `package.json` is the notable exception: spaces, not tabs.
- Preserve existing line endings and shebangs.

## TypeScript Conventions

- Use ESM `import` / `export` syntax.
- Prefer `import type` for type-only imports.
- Keep `const` as the default; use `let` only when reassignment is required.
- The repo uses strict TypeScript; do not weaken compiler settings.
- Avoid `any`; `.config/opencode/eslint.config.js` only permits it as a warning.
- Do not leave unused variables or imports in `.config/opencode/`.
- Prefer early returns over nested conditionals.
- Match neighboring files on whether import paths include extensions.

## Shell / zsh Conventions

- Use `#!/usr/bin/env zsh` for executable zsh scripts.
- Prefer `[[ ... ]]` for tests in zsh code.
- Quote paths and variable expansions unless globbing is intentional.
- Use uppercase names for exported environment variables.
- Prefer helper functions for non-trivial behavior.
- Use `emulate -L zsh` and `typeset` in scripts that need tighter scoping or options.
- Keep shell logic idempotent when possible.

## Naming Conventions

- TypeScript exported plugin names use `PascalCase`, e.g. `BlockGitPushPlugin`.
- TS locals and functions use `camelCase`.
- Shell env vars use `UPPER_SNAKE_CASE`.
- Shell helper/function names typically use lowercase with underscores.
- Numbered files in `.zsh/` reflect load order; preserve that ordering scheme.

## Error Handling

- Fail fast on invalid input.
- Prefer early returns in both TS and zsh.
- In zsh, return non-zero for real failures.
- Preserve existing safety behavior around destructive commands and Git operations.

## Safety-Sensitive Areas

- Overlay scripts in `bin/` can mutate symlinks, `.git/info/exclude`, and Git `skip-worktree` bits.
- Secret scanning is intentional and stricter than usual; do not bypass it.

## How To Verify Changes

- For formatting-only edits: `oxfmt --check <changed-files>`
- For shell edits: `zsh -n <changed-script>`
- For OpenCode TS edits: `bunx tsc --noEmit -p .config/opencode/tsconfig.json`
- For hook/config edits: `pkl eval hk.pkl >/dev/null`
- For anything broad or cross-cutting: `hk run check`

## Editing Guidance For Agents

- Read nearby files before changing conventions.
- Preserve tabs in files that already use tabs.
- Preserve Unicode only in files that already intentionally use it.
- Do not invent build/test scripts that do not exist.
- Do not "clean up" unrelated dotfiles while touching one file.
- Be conservative with install/bootstrap scripts; they affect the real machine.

## Good Defaults

- Prefer narrow verification over expensive machine-wide commands.
- Prefer direct tool commands when you only changed one file.
- Prefer `hk run check` before finishing larger changes.
- If no formal test exists, say so clearly and run the most relevant targeted checks.
