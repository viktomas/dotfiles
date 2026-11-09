# nvim-theme trigger evals

A case is a file: `should-<id>.md` (the skill must load) or
`shouldnot-<id>.md` (it must not). The file's content is the whole prompt —
terse and natural on purpose; eval files are readable by the agent under
test, so they must not announce themselves.

Run with `evals/run.sh` (isolated sessions; the runner reads which skills
loaded from the new session log). The write-y cases must go through
`evals/sandbox.sh` instead: it copies the repo to /tmp, rewrites the
skill's absolute `~/.dotfiles` references to the copy and shims nvim,
so the edits those cases instruct land in the throwaway copy, not the
live working tree.

Read failures by type: wrong-skill load → fix descriptions; nothing loaded
and answer wrong → real miss, fix description; nothing loaded and answer
correct → record, don't tune for it.
