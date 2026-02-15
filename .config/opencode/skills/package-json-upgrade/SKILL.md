---
name: package-json-upgrade
description: Systematically upgrade package.json dependencies by analyzing coupling, upgrading in safe order, testing after each change, and committing incrementally
---

## Overview

Upgrade all dependencies in a project's package.json systematically and safely. The goal is to reach the latest versions of all packages while maintaining a working codebase with passing tests at every step.

## Step 1: Detect Package Manager

Determine which package manager the project uses by checking for lock files:

- `bun.lock` or `bun.lockb` → use `bun`
- `pnpm-lock.yaml` → use `pnpm`
- `yarn.lock` → use `yarn`
- `package-lock.json` → use `npm`

Use the detected package manager for ALL subsequent commands.

## Step 2: Discover Available Scripts

Read `package.json` and identify available scripts for:

- **Testing**: Look for `test`, `test:unit`, `test:integration`, `test:e2e`, or similar
- **Linting**: Look for `lint`, `eslint`, `check`, or similar
- **Formatting**: Look for `format`, `prettier`, `fmt`, or similar
- **Type checking**: Look for `typecheck`, `tsc`, `types`, or similar
- **Building**: Look for `build`, `compile`, or similar

Note which scripts exist. You will run the relevant ones after each upgrade.

## Step 3: Get Current Dependency State

Run the appropriate outdated command:

- `npm outdated` (npm)
- `yarn outdated` (yarn)
- `pnpm outdated` (pnpm)
- `bun outdated` (bun)

Collect all outdated packages from:

- `dependencies`
- `devDependencies`
- `peerDependencies`
- `optionalDependencies`

Note the current version, wanted version, and latest version for each package.

## Step 4: Analyze Package Coupling

Categorize packages into groups:

### Standalone Packages (upgrade first)

Packages that are independent utilities with no tight coupling to other packages:

- Utility libraries (lodash, date-fns, uuid, etc.)
- Standalone tools (prettier, eslint plugins, etc.)
- Type definitions (@types/\*)

### Coupled Package Groups (upgrade together)

Packages that must be upgraded in tandem:

- Framework ecosystems (react + react-dom + @types/react)
- Testing frameworks (jest + @jest/\* + ts-jest)
- Build toolchains (webpack + webpack-cli + loaders)
- Linting ecosystems (eslint + @typescript-eslint/\* + eslint plugins)
- Related scoped packages (@scope/\*)

### Major Version Upgrades of Critical Packages (upgrade last)

Hold these for the end as they often have breaking changes:

- Core frameworks (react, vue, angular, svelte)
- Build tools (vite, webpack, esbuild)
- Language tooling (typescript)
- Test frameworks (jest, vitest, mocha)
- Runtime dependencies that are deeply integrated

## Step 5: Upgrade Process

For each package or package group, in order of risk (safest first):

### 5a. Upgrade the package(s)

Use the appropriate command:

- `npm install <package>@latest` (npm)
- `yarn add <package>@latest` (yarn)
- `pnpm add <package>@latest` (pnpm)
- `bun add <package>@latest` (bun)

For devDependencies, add the appropriate flag (`-D`, `--save-dev`, etc.).

### 5b. Run validation checks

Run all available validation scripts discovered in Step 2:

1. Type checking (if available)
2. Linting (if available)
3. Formatting check (if available)
4. Tests (if available)
5. Build (if available)

### 5c. Handle failures

If any check fails:

- For minor issues (lint/format): attempt to auto-fix with `--fix` or equivalent
- For type errors: assess if they're trivial to fix or indicate deeper issues
- For test failures: determine if they're related to the upgrade

If fixes are straightforward, apply them. If not, **revert the upgrade** and note the package for the final report.

### 5d. Commit the upgrade

If all checks pass, commit with a descriptive message:

```
chore(deps): upgrade <package-name> to <version>
```

For grouped packages:

```
chore(deps): upgrade <group-description>

- package-a: x.x.x → y.y.y
- package-b: x.x.x → y.y.y
```

## Step 6: Generate Report

After processing all packages, provide a comprehensive report:

### Successfully Upgraded

List all packages that were upgraded, organized by grouping:

- Package name
- Previous version → new version
- Commit hash (if available)

### Skipped/Held Back

List packages that were NOT upgraded:

- Package name
- Current version → attempted version
- Reason for skipping (test failures, type errors, breaking changes, etc.)
- Brief description of what went wrong

### Summary

- Total packages upgraded
- Total packages skipped
- Overall health assessment

## Step 7: Offer to Tackle Difficult Upgrades

For any packages that were skipped, offer to attempt them if the user wants:

"The following packages were held back due to issues. Would you like me to attempt upgrading any of these? This may require more extensive changes to your codebase:

- [package-name]: [brief issue description]"

If the user accepts, work through those upgrades with more careful attention to breaking changes, consulting changelogs and migration guides as needed.

## Important Notes

- **Never skip the test step** - Every upgrade must be validated
- **Commit frequently** - Each successful upgrade (or small group) gets its own commit
- **Preserve working state** - If an upgrade breaks things and can't be easily fixed, revert it
- **Be conservative with majors** - Major version bumps of core dependencies are high-risk
- **Check for migration guides** - For major version upgrades, look for official migration documentation
