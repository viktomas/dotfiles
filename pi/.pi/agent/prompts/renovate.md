---
description: Merge all my renovate MRs
---

## Check which renovate MRs are assigned to me

## Categorise:

1. green pipeline -> approve and start merge trains
2. red pipeline -> start subagent to investigate

## Red pipeline subagent

### Transitory failure
If the pipeline failure looks like a transitory failure

1. re-run the failed job
2. wait for it to succed
3. if successful return to the parent agent saying it was a transitory failure

### Failure caused by the dependency upgrade
If the piepline failure looks genuine

1. start a new worktree
2. cherry-pick the dependency update
3. work on top of it to resolve the issue
4. create a new MR
5. wait for the MR pipeline to be green
6. respond to the parent agent with info about the fix and the link to the MR
