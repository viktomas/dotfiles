# cpi — "clean pi": a pi session deliberately detached from the current task.
#
# Blanking TASK_ID means the task extension injects nothing, no agent status
# is written back to the task file, and — most importantly — the session
# doesn't treat the task's state file as its own. Use it for throwaway
# questions inside a task's zellij session, where a second agent rewriting
# the state file would corrupt the task's memory.
function cpi
    TASK_ID="" pi $argv
end
