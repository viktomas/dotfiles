-- Integration tests for the Fennel structural-editing layer
-- (lua/plugins/fennel.lua: parinfer + paredit + parpar).
--
-- Run with the user config loaded so the plugins and keymaps exist:
--
--   nvim --headless -c "luafile tests/structural_editing.lua"
--
-- or via the Makefile:
--
--   make test
--
-- Exits non-zero (cquit) if any assertion fails, so it's CI-friendly.

local paredit = require("nvim-paredit")
local parpar = require("parpar")

local passed, failed = 0, 0
local function ok(name)
  passed = passed + 1
  io.stderr:write(("  ok   %s\n"):format(name))
end
local function err(name, detail)
  failed = failed + 1
  io.stderr:write(("  FAIL %s\n       %s\n"):format(name, detail))
end

-- A scratch fennel buffer with treesitter parsing forced on, so paredit's
-- treesitter-based ops have an up-to-date tree to work against.
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "fennel" -- fires FileType -> paredit attach + our autocmd
pcall(vim.treesitter.start, buf, "fennel")
local parser = vim.treesitter.get_parser(buf, "fennel")

local function set(line, row, col)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
  parser:parse()
  vim.api.nvim_win_set_cursor(0, { row, col })
end
local function line()
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1]
end

--------------------------------------------------------------------------------
-- 1. Structural operations transform forms as documented
--------------------------------------------------------------------------------
-- Each case runs the raw paredit API through parpar.wrap (the same wrapper the
-- keymaps use), so this exercises the parinfer<->paredit integration too.
local ops = {
  { "slurp forward", "(foo) bar", 1, 1, paredit.api.slurp_forwards, "(foo bar)" },
  { "barf forward", "(foo bar)", 1, 1, paredit.api.barf_forwards, "(foo) bar" },
  { "slurp backward", "foo (bar)", 1, 6, paredit.api.slurp_backwards, "(foo bar)" },
  { "barf backward", "(foo bar)", 1, 1, paredit.api.barf_backwards, "foo (bar)" },
  { "drag element right", "(+ a b)", 1, 3, paredit.api.drag_element_forwards, "(+ b a)" },
  { "drag element left", "(+ a b)", 1, 5, paredit.api.drag_element_backwards, "(+ b a)" },
  { "drag form right", "(x) (y)", 1, 1, paredit.api.drag_form_forwards, "(y) (x)" },
  { "drag form left", "(x) (y)", 1, 5, paredit.api.drag_form_backwards, "(y) (x)" },
  { "raise form", "(when ok (go))", 1, 10, paredit.api.raise_form, "(go)" },
  { "raise element", "(foo (bar baz))", 1, 6, paredit.api.raise_element, "(foo bar)" },
  { "splice / unwrap", "(print (inc x))", 1, 8, paredit.api.unwrap_form_under_cursor, "(print inc x)" },
}

for _, c in ipairs(ops) do
  local name, input, row, col, fn, expected = unpack(c)
  set(input, row, col)
  local good = pcall(parpar.wrap(fn))
  local got = line()
  if good and got == expected then
    ok(name)
  else
    err(name, ("%q -> %q  (expected %q)"):format(input, got, expected))
  end
end

--------------------------------------------------------------------------------
-- 2. The expected keymaps are wired up on the lisp buffer
--------------------------------------------------------------------------------
-- Normalise a key spec to a canonical form so "<M-h>" (the readable lhs that
-- nvim_buf_get_keymap returns) compares equal regardless of internal encoding.
local function norm(s)
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(s, true, true, true))
end
local function has_map(mode, lhs)
  for _, k in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
    if norm(k.lhs) == norm(lhs) then
      return true
    end
  end
  return false
end

-- { mode, lhs } — every structural bind, including the insert-mode ones.
local maps = {
  { "n", "<M-h>" }, { "n", "<M-j>" }, { "n", "<M-k>" }, { "n", "<M-l>" },
  { "n", "<M-,>" }, { "n", "<M-.>" }, { "n", "<M-w>" }, { "n", "<M-u>" },
  { "n", "<M-r>" }, { "n", "<M-e>" }, { "n", "<M-a>" }, { "n", "<M-i>" }, { "n", "<M-g>" },
  { "n", "<M-n>" }, { "n", "<M-p>" }, { "n", "<C-,>" }, { "n", "<C-.>" },
  { "i", "<M-h>" }, { "i", "<M-j>" }, { "i", "<M-k>" }, { "i", "<M-l>" },
  { "i", "<M-,>" }, { "i", "<M-.>" }, { "i", "<M-w>" }, { "i", "<M-a>" }, { "i", "<M-i>" },
  { "i", "<C-,>" }, { "i", "<C-.>" },
  { "o", "af" }, { "o", "if" }, { "o", "aF" }, { "o", "iF" }, { "o", "ae" }, { "o", "ie" },
  { "o", "<M-n>" }, { "o", "<M-p>" },
}
for _, m in ipairs(maps) do
  local mode, lhs = m[1], m[2]
  if has_map(mode, lhs) then
    ok(("keymap %s %s"):format(mode, lhs))
  else
    err(("keymap %s %s"):format(mode, lhs), "not registered on lisp buffer")
  end
end

--------------------------------------------------------------------------------
-- Report + exit code
--------------------------------------------------------------------------------
io.stderr:write(("\n%d passed, %d failed\n"):format(passed, failed))
if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
