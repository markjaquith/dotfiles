---
description: Merge the current pull request and clean up its Agency task
---

Merge the PR. If the PR is waiting on CI, wait for CI to pass, monitoring every
60 seconds for a maximum of 10 minutes. Once the PR merges, if this is an Agency
task, mark it as closed, attempt to archive it, and close this Herdr tab.
