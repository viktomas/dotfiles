#!/usr/bin/env bash
# Dump the live tier table (tier name -> resolved colour/attrs) as JSON, by
# asking the running config rather than by reading the source. Feed it to
# decode.py --tiers so the annotations always match what is actually loaded.
#
#   tiers.sh [variant] > /tmp/tiers.json
#
# `variant` (dark|light) switches the theme first, so the table matches a
# capture taken with the same variant. Defaults to whatever the config loads.
set -euo pipefail

VARIANT=${1:-}

nvim --headless -c "lua vim.g.user_theme_variant = '${VARIANT}'" -c 'lua
local ok, theme = pcall(require, "user.theme")
if not ok then io.stderr:write("cannot require user.theme\n") os.exit(1) end
if vim.g.user_theme_variant ~= "" then theme.set_variant(vim.g.user_theme_variant) end
local out = {}
for name, _ in pairs(theme.tiers) do
  -- resolve by round-tripping through a scratch highlight group
  vim.api.nvim_set_hl(0, "UserThemeProbe", {})
  local probe = "@comment"
  local saved = theme.rules[probe]
  theme.rules[probe] = name
  theme.apply()
  local hl = vim.api.nvim_get_hl(0, { name = "@comment." .. theme.langs[1], link = false })
  theme.rules[probe] = saved
  out[name] = {
    fg = hl.fg and string.format("#%06x", hl.fg) or vim.NIL,
    bold = hl.bold or false,
    italic = hl.italic or false,
  }
end
theme.apply()
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
out["base"] = {
  fg = normal.fg and string.format("#%06x", normal.fg) or vim.NIL,
  bold = false, italic = false,
}
out["__bg"] = {
  fg = normal.bg and string.format("#%06x", normal.bg) or vim.NIL,
  bold = false, italic = false,
}
io.stdout:write(vim.json.encode(out))
' -c q 2>/dev/null
echo
