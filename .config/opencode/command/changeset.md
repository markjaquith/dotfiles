---
description: Create a changeset file for package versioning
agent: fast
subtask: true
---

# Create a changeset file

Create a changeset file in the style of the "changesets" package for tracking package version changes.

## Important

DO NOT use the `changeset` CLI tool because it is interactive-only and cannot be used in this context.

## Arguments

- If the first argument ($1) is a bump type ("major", "minor", or "patch"), use that bump type for the changeset.
- If no bump type is provided or the first argument is not a valid bump type, analyze the git changes and infer the appropriate bump type based on:
  - "major" for breaking changes
  - "minor" for new features or enhancements
  - "patch" for bug fixes or minor improvements

## Process

1. Check if a `.changeset` directory exists in the repository root
2. Determine the bump type (from argument or by analyzing changes)
3. Analyze the current changes to understand what has been modified
4. Generate a unique changeset filename (format: `[adjective]-[noun]-[number].md`)
5. Create the changeset file with:
   - YAML frontmatter listing affected packages and their bump types
   - A clear, descriptive summary of the changes
6. Follow the changesets format exactly:
   ```
   ---
   "package-name": [bump-type]
   ---

   Description of changes
   ```

## Rules

- The changeset must be manually created as a markdown file
- Use descriptive but concise language for the summary
- Ensure the bump type aligns with semantic versioning principles
- If there are multiple packages affected, list them all in the frontmatter
- Output the created changeset file path and its contents for user confirmation
