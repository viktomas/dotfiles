---
description: Ensure successful pipeline
---

Use gitlab-api and wait-for skills. Detect last pipeline for current branch and make sure it's successful. If it's failinng, implement a fix, conv commit and push. Repeat until the pipeline is successful.

- NEVER force push, ALWAYS add new commits
- If the pipeline still fails after two fixes, update the .gitlab-ci.yml to only keep the failing jobs and remove any `retry` config. Do this change as a separate commit that you'll revert once the fix is implemented

