# Tmux CLI Testing - Reference

This file is for collecting additional insights, examples, and edge cases discovered while using the tmux-cli-testing skill.

## Notes

Add any useful findings here when testing interactive CLI applications:
- Non-obvious patterns or behaviors
- App-specific workarounds
- Timing quirks
- Useful debugging techniques
- Common pitfalls and solutions

## Testing Neovim: quick recipe (start here)

Learned the hard way while debugging a visual `>` indent in a parinfer Fennel
buffer. Most of the time was lost to *test harness confounds*, not the bug.
Follow these and it's fast:

1. **Always start nvim with `-n` (no swapfile).** A killed session leaves a
   swap file; the next run opens on the `"swap file already exists"` PROMPT and
   **silently eats every keystroke you send** — your test "does nothing" and
   you chase a ghost. `start_test "nvim" "-n" "-c" "..." "file"`. Also
   `rm -f ~/.local/share/nvim/swap/*<name>* ` between runs.
2. **Dump the buffer via a mapped key, not an ex-command.** Quoting
   `:call writefile(getline(1,'$'),'/tmp/b.txt')` through bash heredocs +
   `send_text`/`send-keys` is a quoting minefield (`$`, quotes, backslashes)
   and fails silently. Instead load a tiny helper and trigger it with one char:
   ```bash
   cat > /tmp/dump.lua <<'LUA'
   vim.keymap.set('n','Q',function() vim.fn.writefile(vim.fn.getline(1,'$'),'/tmp/dump.txt') end)
   LUA
   start_test "nvim" "-n" "-c" "luafile /tmp/dump.lua" "$file"
   # ...do actions, then:  send_key escape; send_text "Q"; sleep 0.4; cat /tmp/dump.txt
   ```
   (`send_key` only knows enter/escape/tab/arrows/ctrl-[acdz] + single printable
   chars — **no F-keys**. Map to a plain char like `Q`.)
3. **Navigate with `gg`+`j`, not `:N<CR>`.** `:2<CR>` via send-keys frequently
   did NOT move the cursor (stayed on line 1), so every selection was wrong.
   `send_text "gg"; send_key down; ...` is reliable. Verify the selection with
   an `x`-mode mapped probe writing `line('v')`/`line('.')`/`mode()` to a file.
4. **Measure the buffer, not the saved file.** `:w` can trigger format-on-save
   (conform/fnlfmt/stylua) that rewrites the file and masks what your edit did.
   Dump the live buffer (recipe above) instead of saving.
5. **Don't pass test flags via `VAR=val start_test`** — env doesn't reach the
   tmux nvim. Use `-c "let g:foo=1"` / `-c "lua FOO=true"` or a `luafile`.

### CRITICAL: how you inject keys changes the result for async plugins
For plugins that react on `TextChanged` via `vim.schedule` (parinfer,
treesitter, etc.) the input method is NOT interchangeable:
- **Real tmux `send-keys`** → goes through the real input loop → async
  reactions fire → **matches what the user actually experiences.** Use this to
  reproduce/verify the reported behavior.
- **`nvim_feedkeys(.., 'x', ..)`** runs synchronously and the scheduled
  reaction often *doesn't* fire — so a parinfer revert/flicker that happens for
  real will NOT reproduce. Gives false "it works" results.
- **`nvim_input` in `--headless` + `vim.wait`** frequently doesn't process the
  input at all (even `>>` no-ops). Don't rely on it headless.
Bottom line: to test a flicker/async-reaction bug, use real tmux with `-n`.
Use parinfer's own `vim.g.parinfer_logfile` to *count* reactions: 0 logged
`request:` lines during an operation = parinfer never reacted (no flicker).

## Testing Neovim (and editor) plugins/keymaps

Learned while building a Fennel structural-editing setup (parinfer/paredit/parpar).

### Prefer headless + Lua API over capture-pane for anything precise
Driving Neovim through `tmux send-keys` + `capture-pane` is fine for a final
smoke test, but **multi-key motions are flaky**, especially right after
startup. A single `send-keys "gg07l"` would silently not land the cursor
(stayed at col 1), which then made the action under test operate on the wrong
target and produced misleading "bugs". The config was correct; the *test
navigation* was wrong.

For deterministic results, run headless and place the cursor via the API, then
drive the *real* mapping and inspect state, writing results to a file:

```bash
cat > test.lua <<'LUA'
vim.defer_fn(function()
  vim.api.nvim_win_set_cursor(0, {1, 7})            -- 0-indexed col, exact
  local keys = vim.api.nvim_replace_termcodes("<M-w>", true, false, true)
  vim.api.nvim_feedkeys(keys, "m", false)           -- "m" = run real mappings
  vim.defer_fn(function()                           -- let plugins debounce
    local f = io.open("out.txt", "w")
    f:write("line=["..vim.api.nvim_get_current_line().."] "
         .. "mode=["..vim.api.nvim_get_mode().mode.."]\n")
    f:close(); vim.cmd("qa!")
  end, 400)
end, 500)
LUA
timeout 25 nvim --headless file.fnl -c "luafile test.lua" >/dev/null 2>&1
cat out.txt
```

### Specific gotchas
- **Alt/Meta keys**: send with `tmux send-keys -t S M-w` (or feedkeys
  `<M-w>`). Neovim stores them as `<M-w>`, NOT `<A-w>` — so checking
  `nvim_buf_get_keymap` by `lhs` must compare against `<M-...>` (or test
  `lhs:byte(1) > 127`). A naive `<A-w>` comparison reports "not mapped" when it
  is.
- **Verify the cursor before the action.** When using send-keys navigation,
  assert position first: `:echo col('.').':'.getline('.')[col('.')-1]` and read
  it back from `capture-pane`. Don't trust that `f x` / counts landed.
- **Assert the settled state of ONE action; don't simulate follow-up typing.**
  Chaining `feedkeys` to emulate "press wrap, then type the head" is
  unreliable for insert-mode transitions and produced false failures (lost
  first char). Instead assert mode/line right after the single action.
- **`startinsert` from a timer/scheduled callback silently no-ops** and the
  next typed char looks "lost". This is a real editor behavior to be aware of
  when a plugin defers insert — not a test artifact.
- **Give plugins time to debounce.** parinfer/treesitter react on
  `TextChanged*`; inspect 200–400ms after the action, and nest `vim.defer_fn`
  so the final `qa!` runs after the assertion.
- **capture-pane status line** shows `row,col` (e.g. `1,9`) — handy to read
  cursor position; `:echo` output appears on the line *above* the status line.
- **Orphan nvim + swapfiles**: headless runs that get killed leave swap files,
  causing `W325: Ignoring swapfile from Nvim process NNNN` and stale state on
  the next open. Clean between runs:
  `rm -f .<file>.sw* ~/.local/state/nvim/swap/*<name>*` and `kill <orphan pid>`.
- **Beware side effects on open**: opening the file under test launched an
  external process (Conjure auto-starting `love .`). Check with `pgrep -fl` and
  `pkill` between runs so leftover processes don't skew later tests.
