-- Attention-based highlighting for Go and TypeScript.
--
-- Rationale, the staged rollout plan and the findings log live in
-- `nvim/docs/highlighting.md`. Read it before changing the presets.
--
-- Short version: colour *how much attention a token deserves*, not *what it
-- is*; reserve hue for diagnostics/diff/search. Mechanism: neovim resolves
-- `@capture.<lang>` before falling back to `@capture`, so defining
-- `@capture.go = {}` blanks that capture for Go alone. LSP semantic tokens use
-- `@lsp.type.<type>.<filetype>` and are blanked the same way.
--
-- Everything starts BLANK. Add entries to `M.rules` to opt tokens back in.

local M = {}

-- Treesitter language names to blank (`:Inspect` tells you which lang applied).
M.langs = {
  "go", "gomod", "gowork", "gosum", "gotmpl",
  "typescript", "tsx", "javascript", "jsdoc",
}

-- Filetypes to blank LSP semantic tokens for.
M.filetypes = {
  "go", "gomod",
  "typescript", "typescriptreact", "javascript", "javascriptreact",
}

--- Tier -> attributes. `base` is the plain foreground (no attributes at all,
--- so Visual/CursorLine/Search compose cleanly underneath).
--- Colours are derived from `Normal` at apply time, so this survives a
--- colorscheme switch. `contrast` values are 0..1 fractions of the way from
--- the normal foreground towards the background (dim) or away from it (strong).
M.tiers = {
  faint  = { blend = 0.62 },              -- barely there
  dim    = { blend = 0.42 },              -- clearly recessive
  muted  = { blend = 0.20 },              -- a nudge quieter
  base   = {},                            -- plain text
  strong = { blend = -0.45 },             -- brighter than plain text
  bold   = { blend = -0.45, bold = true },
}

--- capture (without the language suffix) -> tier name.
--- Lookup inherits up the capture hierarchy, like neovim's own `@`-group
--- fallback: `@keyword.conditional.ternary` uses the rule for
--- `@keyword.conditional`, else `@keyword`, else blank. So a broad rule covers
--- a whole family and a specific one overrides it.
--- Empty = completely blank theme. See the presets at the bottom of this file.
M.rules = {}

---------------------------------------------------------------------------
-- implementation
---------------------------------------------------------------------------

-- Every standard capture (`:h treesitter-highlight-groups`). Special captures
-- (@spell, @nospell, @none, @conceal) are intentionally excluded.
local captures = {
  "attribute", "attribute.builtin",
  "boolean", "character", "character.special",
  "comment", "comment.documentation", "comment.error", "comment.note",
  "comment.todo", "comment.warning",
  "constant", "constant.builtin", "constant.macro",
  "constructor",
  "function", "function.builtin", "function.call", "function.macro",
  "function.method", "function.method.call",
  "keyword", "keyword.conditional", "keyword.conditional.ternary",
  "keyword.coroutine", "keyword.debug", "keyword.directive",
  "keyword.directive.define", "keyword.exception", "keyword.function",
  "keyword.import", "keyword.modifier", "keyword.operator", "keyword.repeat",
  "keyword.return", "keyword.type",
  "label",
  "markup.heading", "markup.italic", "markup.link", "markup.link.label",
  "markup.link.url", "markup.list", "markup.math", "markup.quote",
  "markup.raw", "markup.raw.block", "markup.strikethrough", "markup.strong",
  "markup.underline",
  "module", "module.builtin",
  "number", "number.float",
  "operator", "property",
  "punctuation.bracket", "punctuation.delimiter", "punctuation.special",
  "string", "string.documentation", "string.escape", "string.regexp",
  "string.special", "string.special.path", "string.special.symbol",
  "string.special.url",
  "tag", "tag.attribute", "tag.builtin", "tag.delimiter",
  "type", "type.builtin", "type.definition",
  "variable", "variable.builtin", "variable.member", "variable.parameter",
  "variable.parameter.builtin",
}

local lsp_types = {
  "class", "comment", "decorator", "enum", "enumMember", "event", "function",
  "interface", "keyword", "macro", "method", "modifier", "namespace", "number",
  "operator", "parameter", "property", "regexp", "string", "struct", "type",
  "typeParameter", "variable",
}

--- Find the most specific rule for a capture, walking up the dotted hierarchy.
local function rule_for(capture)
  while capture ~= "" do
    local tier = M.rules[capture]
    if tier then return tier end
    capture = capture:match("^(.*)%.[^.]+$") or ""
  end
end

local function hex(n) return string.format("#%06x", n) end

local function blend(from, to, amount)
  local out = 0
  for shift = 0, 16, 8 do
    local a = math.floor(from / 2 ^ shift) % 256
    local b = math.floor(to / 2 ^ shift) % 256
    local c = math.floor(a + (b - a) * amount + 0.5)
    out = out + math.min(255, math.max(0, c)) * 2 ^ shift
  end
  return math.floor(out)
end

--- Resolve a tier to concrete `nvim_set_hl` opts.
local function resolve(tier, fg, bg, extreme)
  local spec = M.tiers[tier]
  if not spec then
    vim.notify("user.highlight: unknown tier " .. tostring(tier), vim.log.levels.WARN)
    return {}
  end
  local attrs = {}
  for _, k in ipairs({ "bold", "italic", "underline", "undercurl", "reverse" }) do
    if spec[k] then attrs[k] = true end
  end
  if spec.fg then
    attrs.fg = spec.fg
  elseif spec.blend and spec.blend ~= 0 then
    local amount = spec.blend
    attrs.fg = hex(blend(fg, amount > 0 and bg or extreme, math.abs(amount)))
  end
  return attrs
end

function M.apply()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local fg = normal.fg or 0xc0c0c0
  local bg = normal.bg or 0x000000
  -- "away from the background" direction: white on dark themes, black on light.
  local luminance = (math.floor(bg / 65536) % 256) * 0.299
      + (math.floor(bg / 256) % 256) * 0.587
      + (bg % 256) * 0.114
  local extreme = luminance < 128 and 0xffffff or 0x000000

  local set = vim.api.nvim_set_hl
  for _, lang in ipairs(M.langs) do
    for _, capture in ipairs(captures) do
      local tier = rule_for("@" .. capture)
      set(0, "@" .. capture .. "." .. lang, tier and resolve(tier, fg, bg, extreme) or {})
    end
  end
  for _, ft in ipairs(M.filetypes) do
    for _, t in ipairs(lsp_types) do
      local tier = rule_for("@lsp.type." .. t)
      set(0, "@lsp.type." .. t .. "." .. ft, tier and resolve(tier, fg, bg, extreme) or {})
    end
  end
end

function M.setup(opts)
  opts = opts or {}
  M.rules = opts.rules or M.rules
  if opts.tiers then M.tiers = vim.tbl_deep_extend("force", M.tiers, opts.tiers) end
  if opts.langs then M.langs = opts.langs end
  if opts.filetypes then M.filetypes = opts.filetypes end
  vim.api.nvim_create_autocmd("ColorScheme", { callback = M.apply })
  M.apply()
end

---------------------------------------------------------------------------
-- Presets: pass one as `rules` to `setup()`. Steps 1-4 of the plan in
-- `nvim/docs/highlighting.md`. Live with each for a day before the next.
---------------------------------------------------------------------------

M.presets = {}

-- 0. Nothing at all. Pure monochrome, Rob Pike mode.
M.presets.blank = {}

-- 1. Subtractive only. The single highest-leverage move every minimalist
--    converges on: dim the syntactic scaffolding so identifiers stand out
--    without spending a colour.
M.presets.scaffolding = {
  ["@punctuation"]      = "faint", -- covers bracket / delimiter / special
  ["@tag.delimiter"]    = "faint",
  ["@operator"]         = "dim",
  ["@keyword"]          = "dim",   -- covers every @keyword.* subcapture
  ["@type.builtin"]     = "dim",
  ["@variable.builtin"] = "dim",
  ["@constant.builtin"] = "dim",
  ["@module"]           = "dim",
}

-- 2. "Not code" tier. Comments and literals are foreign grammars embedded in
--    the host language; telling them apart from code is the one cost people
--    who go fully monochrome consistently report.
M.presets.foreign = vim.tbl_extend("force", M.presets.scaffolding, {
  ["@comment"]       = "strong", -- loud, not dimmed -- see docs/highlighting.md
  ["@string"]        = "muted",
  ["@string.escape"] = "strong", -- the one part of a string that is code
  ["@number"]        = "muted",
  ["@boolean"]       = "muted",
  ["@character"]     = "muted",
})

-- 3. Attention tiers (hank.bond). Definitions and control-flow exits get the
--    strongest weight; references stay at base.
M.presets.attention = vim.tbl_extend("force", M.presets.foreign, {
  ["@function"]          = "bold",   -- declaration site (not @function.call)
  ["@function.call"]     = "base",   -- ...so undo the inherited bold
  ["@function.method"]      = "bold",
  ["@function.method.call"] = "base",
  ["@type.definition"]   = "bold",
  ["@constructor"]       = "bold",
  ["@keyword.return"]    = "strong", -- override the dim inherited from @keyword
  ["@keyword.exception"] = "strong",
  ["@keyword.coroutine"] = "strong", -- go / defer / async / await
  ["@keyword.debug"]     = "strong",
})

return M
