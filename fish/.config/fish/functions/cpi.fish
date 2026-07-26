# cpi — "clean pi": a pi session deliberately detached from the current task.
#
# Blanking TASK_ID means the tm and task extensions inject nothing, no agent
# status is written back to the task file, and — most importantly — nothing in
# the session can append to the task's tm memory. Use it for throwaway
# questions inside a task's zellij session, where a second agent recording
# findings would corrupt the task's memory.
function cpi
    TASK_ID="" pi $argv
end
