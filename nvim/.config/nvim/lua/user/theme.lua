-- Attention-based theme for Go and TypeScript.
--
-- Full documentation, rationale, measurements and the log: `nvim/THEME.md`.
-- Read it before changing the presets or the tier ramp.
--
-- Short version: colour *how much attention a token deserves*, not *what it
-- is*. The ramp is grayscale (plus bold and italic as separate channels); hue
-- belongs to diagnostics, diffs and search, which are left alone.
--
-- Mechanism: neovim resolves `@capture.<lang>` before falling back to
-- `@capture`, so defining `@capture.go = {}` blanks that capture for Go alone.
-- Everything starts BLANK; `M.rules` opts tokens back in. LSP semantic tokens
-- need all three of `@lsp.type.<t>.<ft>`, `@lsp.mod.<m>.<ft>` and
-- `@lsp.typemod.<t>.<m>.<ft>` blanked -- they are applied per token at
-- increasing priority, so missing one lets the colorscheme paint over us.

local M = {}

---------------------------------------------------------------------------
-- surfaces
---------------------------------------------------------------------------

--- Editor background. Ghostty's default (`ghostty +show-config --default`), so
--- nvim, fish and zellij share one background instead of nvim being a bluer
--- rectangle inside the terminal. `false` keeps the colorscheme's own.
--- Overwritten by `M.variants[<variant>].background`; see `M.set_variant`.
M.background = "#282c34"

--- Editor foreground: Tomorrow Night's fg, the neutral gray my fish theme is
--- built around. Neutral matters here -- the whole ramp is derived from it, and
--- a blue-tinted `Normal` makes a "grayscale" theme quietly not grayscale.
M.foreground = "#c5c8c6"

--- Which variant is live. Everything below (surfaces, ramp, hue palette) is
--- derived from `M.background` / `M.foreground`, so a variant is just a
--- different pair plus the ramp recalibration that pair needs.
---
--- Only a fallback: `setup()` derives the starting variant from
--- `vim.o.background`, which the TUI has already set from the terminal's own
--- background colour by the time user config runs.
M.variant = "dark"

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

--- Tier -> attributes.
---
--- `blend` is a fraction of the way from `from` (default: `Normal`'s fg)
--- towards `toward` (default: the background for positive values, pure
--- white/black for negative ones). Computed at apply time and re-applied on
--- `ColorScheme`, so the ramp follows whatever `Normal` is.
---
--- The ramp is asymmetric on purpose. Downwards there is a lot of room
--- (`faint` is dE 37 from base); upwards there is almost none, because `Normal`
--- is already near-white -- pure white only buys dE 20. So *up* is paid for
--- with a second channel (bold), and anything that needs to be merely
--- *distinguishable* rather than louder uses italic, which costs no luminance
--- at all. See THEME.md ("Why the ramp is lopsided").
M.tiers = {
  faint  = { blend = 0.62 },                      -- #64676b  dE 37
  dim    = { blend = 0.42 },                      -- #838689  dE 25
  muted  = { blend = 0.20 },                      -- #a6a9a9  dE 11
  base   = {},                                    -- plain Normal, no attributes
  plain  = { plain = true },                      -- base, foreground written out
  strong = { blend = -0.55 },                     -- #e5e6e5  dE 11
  bold   = { blend = -1.0, bold = true },         -- #ffffff  dE 20 + weight
  -- italic is the "prose, not code" channel; it is spent only on comments
  note   = { blend = 0.20, italic = true },       -- in-body comments
  doc    = { blend = 0.42, italic = true },       -- declaration doc comments
}

--- Optional palette, only used by `presets.fish` (kept as an alternative, see
--- THEME.md). It is my fish theme -- Tomorrow Night -- copied from
--- `fish/.config/fish/conf.d/fish_frozen_theme.fish`. Swapped per variant.
M.palette = {
  gray   = "#969896", -- fish_color_autosuggestion
  red    = "#cc6666", -- fish_color_error  -- RESERVED: diagnostics only
  yellow = "#f0c674", -- fish_color_comment
  ochre  = "#b3a06d", -- fish_pager_color_description
  green  = "#b5bd68", -- fish_color_quote
  aqua   = "#8abeb7", -- fish_color_redirection
  cyan   = "#00a6b2", -- fish_color_escape
  blue   = "#81a2be", -- fish_color_param / _option
  purple = "#b294bb", -- fish_color_command / _keyword / _end
}

---------------------------------------------------------------------------
-- variants
---------------------------------------------------------------------------

--- A variant is a surface pair + the tier recalibration that pair needs.
---
--- The ramp is specified in *blend fractions*, but it is calibrated in *dE*:
--- the same fraction lands somewhere else when the distance from `Normal` to
--- the background changes. On white, `blend = 0.62` is dE 43 instead of 37, so
--- the light variant restates the recessive tiers at the fractions that
--- reproduce the dark dE ladder (37 / 25 / 11). `bold` is the one exception:
--- see THEME.md ("The light ramp is lopsided the other way").
---
--- Surfaces are NOT restated: the same `up()` fractions land within dE 1.5 of
--- their dark counterparts, measured, because both pairs have a similar
--- fg<->bg distance (63 vs 67).
M.variants = {
  dark = {
    -- ghostty's default background + Tomorrow Night's neutral fg
    background = "#282c34",
    foreground = "#c5c8c6",
  },
  light = {
    -- ghostty's `Tomorrow` theme, the light sibling of the fish palette:
    -- `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Tomorrow`
    background = "#ffffff",
    foreground = "#4d4d4c",
    tiers = {
      faint  = { blend = 0.53 },              -- #aaaaaa  dE 37
      dim    = { blend = 0.34 },              -- #898989  dE 24
      muted  = { blend = 0.15 },              -- #686868  dE 11
      strong = { blend = -0.32 },             -- #343434  dE 11
      bold   = { blend = -1.0, bold = true }, -- #000000  dE 33 + weight
      note   = { blend = 0.15, italic = true },
      doc    = { blend = 0.34, italic = true },
    },
    -- Tomorrow (light), same semantics as the Night palette above. The two
    -- yellows are darkened: #f0c674 / #eab700 are unreadable on white.
    palette = {
      gray   = "#8e908c",
      red    = "#c82829", -- RESERVED: diagnostics only
      yellow = "#8f6a00",
      ochre  = "#a08a5b",
      green  = "#718c00",
      aqua   = "#3e999f",
      cyan   = "#3e999f",
      blue   = "#4271ae",
      purple = "#8959a8",
    },
  },
}

--- capture (without the language suffix) -> tier name.
--- Lookup inherits up the capture hierarchy, like neovim's own `@`-group
--- fallback: `@keyword.conditional.ternary` uses the rule for
--- `@keyword.conditional`, else `@keyword`, else blank. So a broad rule covers
--- a whole family and a specific one overrides it.
M.rules = {}

---------------------------------------------------------------------------
-- implementation
---------------------------------------------------------------------------

-- The grayscale ramp as written above, before any variant or user override.
-- Variants are always merged onto *this*, never onto the merge result, so
-- switching back and forth is lossless.
local default_tiers = vim.deepcopy(M.tiers)
local default_palette = vim.deepcopy(M.palette)
local user_tiers = nil

-- Every standard capture (`:h treesitter-highlight-groups`). Special captures
-- (@spell, @nospell, @none, @conceal) are intentionally excluded.
-- `embedded.code` is ours; see `after/queries/ecma/highlights.scm`.
local captures = {
  "attribute", "attribute.builtin",
  "boolean", "character", "character.special",
  "comment", "comment.documentation", "comment.error", "comment.note",
  "comment.todo", "comment.warning",
  "constant", "constant.builtin", "constant.macro",
  "constructor",
  "embedded.code",
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

-- Standard LSP token modifiers, plus the two neovim adds for injections
-- (`injected`) and callable variables (`callable`).
local lsp_mods = {
  "declaration", "definition", "readonly", "static", "deprecated", "abstract",
  "async", "modification", "documentation", "defaultLibrary",
  "injected", "callable",
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

local function parse(color)
  if type(color) == "number" then return color end
  return tonumber((color:gsub("^#", "")), 16)
end

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
    vim.notify("user.theme: unknown tier " .. tostring(tier), vim.log.levels.WARN)
    return {}
  end
  local attrs = {}
  for _, k in ipairs({ "bold", "italic", "underline", "undercurl", "reverse" }) do
    if spec[k] then attrs[k] = true end
  end
  if spec.fg then
    attrs.fg = spec.fg
  elseif spec.plain then
    attrs.fg = hex(fg)
  elseif spec.blend and spec.blend ~= 0 then
    local amount = spec.blend
    local from = spec.from and parse(spec.from) or fg
    local toward = spec.toward == "fg" and fg
        or spec.toward == "bg" and bg
        or (amount > 0 and bg or extreme)
    attrs.fg = hex(blend(from, toward, math.abs(amount)))
  end
  return attrs
end

--- Neutral surfaces derived from the background, so nothing in the chrome
--- reintroduces the colorscheme's tint. Everything hue-bearing (diagnostics,
--- diff, search, git signs) is deliberately left to the colorscheme.
local function surfaces(fg, bg)
  local set = vim.api.nvim_set_hl
  local up = function(amount) return hex(blend(bg, fg, amount)) end
  local down = function(amount) return hex(blend(fg, bg, amount)) end
  local BG, FG = hex(bg), hex(fg)

  set(0, "Normal", { fg = FG, bg = BG })
  set(0, "NormalNC", { fg = FG, bg = BG })
  set(0, "SignColumn", { bg = BG })
  set(0, "EndOfBuffer", { fg = BG, bg = BG })

  set(0, "NormalFloat", { fg = FG, bg = up(0.05) })
  set(0, "FloatBorder", { fg = down(0.62), bg = up(0.05) })
  set(0, "FloatTitle", { fg = FG, bold = true, bg = up(0.05) })

  set(0, "CursorLine", { bg = up(0.07) })
  set(0, "CursorColumn", { bg = up(0.07) })
  set(0, "ColorColumn", { bg = up(0.07) })
  set(0, "Visual", { bg = up(0.18) })
  set(0, "Folded", { fg = down(0.42), bg = up(0.05) })

  set(0, "LineNr", { fg = down(0.68) })
  set(0, "LineNrAbove", { fg = down(0.68) })
  set(0, "LineNrBelow", { fg = down(0.68) })
  set(0, "CursorLineNr", { fg = FG, bold = true })
  set(0, "WinSeparator", { fg = up(0.20) })

  set(0, "StatusLine", { fg = down(0.20), bg = up(0.09) })
  set(0, "StatusLineNC", { fg = down(0.55), bg = up(0.05) })
  set(0, "TabLine", { fg = down(0.42), bg = up(0.05) })
  set(0, "TabLineFill", { bg = BG })
  set(0, "TabLineSel", { fg = FG, bold = true, bg = up(0.14) })

  set(0, "Pmenu", { fg = FG, bg = up(0.06) })
  set(0, "PmenuSel", { bg = up(0.18), bold = true })
  set(0, "PmenuSbar", { bg = up(0.10) })
  set(0, "PmenuThumb", { bg = up(0.28) })

  -- The dynamic layer (see M.dynamic): identity and matching are shown with
  -- background, not colour, and only where the cursor is.
  set(0, "MatchParen", { bg = up(0.26), bold = true })
  set(0, "LspReferenceText", { bg = up(0.13) })
  set(0, "LspReferenceRead", { bg = up(0.13) })
  set(0, "LspReferenceWrite", { bg = up(0.13), underline = true })
  set(0, "LspReferenceTarget", { bg = up(0.13) })

  -- Markdown inline code. tokyonight paints `@markup.raw.markdown_inline` as
  -- `bg = terminal_black, fg = blue` -- blue on blue-gray, the lowest-contrast
  -- pair on screen (measured #3f7fe5 on #a1a7c3 in the light variant). Keep
  -- the "this is code" box, drop the hue: plain fg on a neutral surface.
  -- render-markdown's `RenderMarkdownCodeInline` links to this group (via
  -- tokyonight), so the rendered spans follow.
  set(0, "@markup.raw.markdown_inline", { fg = FG, bg = up(0.10) })
  -- Fenced code blocks get the same surface, one step quieter than inline.
  set(0, "RenderMarkdownCode", { bg = up(0.06) })

  -- Unused code: the dimmest thing on screen. NOT italic -- italic is the
  -- prose channel now (comments), and diluting it costs more than it buys.
  set(0, "DiagnosticUnnecessary", { fg = down(0.62) })
  set(0, "DiagnosticUnderlineHint", { undercurl = false })
end

function M.apply()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local fg = M.foreground and parse(M.foreground) or normal.fg or 0xc0c0c0
  local bg = M.background and parse(M.background) or normal.bg or 0x000000
  -- "away from the background" direction: white on dark themes, black on light.
  local luminance = (math.floor(bg / 65536) % 256) * 0.299
      + (math.floor(bg / 256) % 256) * 0.587
      + (bg % 256) * 0.114
  local extreme = luminance < 128 and 0xffffff or 0x000000

  if M.background or M.foreground then surfaces(fg, bg) end

  local set = vim.api.nvim_set_hl
  local cache = {}
  local function hl(tier)
    if not tier then return {} end
    if cache[tier] == nil then cache[tier] = resolve(tier, fg, bg, extreme) end
    return cache[tier]
  end

  for _, lang in ipairs(M.langs) do
    for _, capture in ipairs(captures) do
      set(0, "@" .. capture .. "." .. lang, hl(rule_for("@" .. capture)))
    end
  end
  for _, ft in ipairs(M.filetypes) do
    for _, t in ipairs(lsp_types) do
      set(0, "@lsp.type." .. t .. "." .. ft, hl(rule_for("@lsp.type." .. t)))
      for _, mod in ipairs(lsp_mods) do
        set(0, "@lsp.typemod." .. t .. "." .. mod .. "." .. ft,
          hl(rule_for("@lsp.typemod." .. t .. "." .. mod)))
      end
    end
    for _, mod in ipairs(lsp_mods) do
      set(0, "@lsp.mod." .. mod .. "." .. ft, hl(rule_for("@lsp.mod." .. mod)))
    end
  end
end

---------------------------------------------------------------------------
-- the dynamic layer
---------------------------------------------------------------------------

--- Identity and nesting are not in the static theme; they are shown on demand,
--- where the cursor is. Hillel Wayne's point, made cheap: the static theme can
--- stay quiet because this layer answers "what else touches this symbol?" the
--- moment you stop moving.
---
--- `MatchParen` is built in and styled in `surfaces()`. This adds
--- `document_highlight` on CursorHold for any LSP that supports it, cleared as
--- soon as the cursor moves.
function M.dynamic(opts)
  opts = opts or {}
  vim.o.updatetime = opts.updatetime or 250

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or not client:supports_method("textDocument/documentHighlight") then
        return
      end
      local group = vim.api.nvim_create_augroup("user.theme.dynamic." .. ev.buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = group,
        buffer = ev.buf,
        callback = function() vim.lsp.buf.document_highlight() end,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
        group = group,
        buffer = ev.buf,
        callback = function() vim.lsp.buf.clear_references() end,
      })
      vim.api.nvim_create_autocmd("LspDetach", {
        group = group,
        buffer = ev.buf,
        callback = function() pcall(vim.api.nvim_del_augroup_by_id, group) end,
      })
    end,
  })
end

---------------------------------------------------------------------------
-- variant switching
---------------------------------------------------------------------------

--- Guard for the `OptionSet` handler installed by `setup()`: `set_variant`
--- writes `vim.o.background` itself, and that write fires `OptionSet` again.
local switching = false

--- The variant that matches whatever the terminal told neovim.
local function variant_for_background()
  return vim.o.background == "light" and "light" or "dark"
end

--- Rebuild the ramp and the palette for `name`, flip `background`, and repaint.
---
--- Order matters: `vim.o.background` is set *before* the colorscheme is
--- reloaded, because that is the only thing most colorschemes (tokyonight
--- included) look at to pick their light/dark side. The reload fires
--- `ColorScheme`, which calls `M.apply()` -- so everything the colorscheme just
--- painted is overwritten by our surfaces and tiers again.
function M.set_variant(name)
  local variant = M.variants[name]
  if not variant then
    vim.notify("user.theme: unknown variant " .. tostring(name), vim.log.levels.WARN)
    return
  end
  M.variant = name
  if variant.background ~= nil then M.background = variant.background end
  if variant.foreground ~= nil then M.foreground = variant.foreground end
  M.palette = vim.tbl_extend("force", default_palette, variant.palette or {})
  M.tiers = vim.tbl_deep_extend("force",
    default_tiers, M.hue_tiers(M.palette), variant.tiers or {}, user_tiers or {})

  local bg = M.background and parse(M.background) or 0
  local want = (bg % 256) * 0.114
      + (math.floor(bg / 256) % 256) * 0.587
      + (math.floor(bg / 65536) % 256) * 0.299 < 128 and "dark" or "light"

  -- Write only on a real mismatch. `background` is also neovim's own
  -- terminal-theme channel: its TUI keeps an autocommand that re-sets it from
  -- OSC 11 whenever the terminal sends a DEC 2031 notification, and that
  -- autocommand is deleted at `VimEnter` if `background` was set from a
  -- *sourced script* (sid ~= -8). Not writing it during startup is what keeps
  -- the terminal in charge; writes from `:ThemeVariant`'s callback are sid -8
  -- and harmless. See `runtime/lua/vim/_core/defaults.lua`.
  if vim.o.background ~= want then
    switching = true
    vim.o.background = want
    switching = false
  end

  local scheme = variant.colorscheme or vim.g.colors_name
  if scheme then pcall(vim.cmd.colorscheme, scheme) end
  M.apply()
end

--- Flip between the two variants. Bound to nothing; `:ThemeVariant` calls it.
function M.toggle()
  M.set_variant(M.variant == "dark" and "light" or "dark")
end

function M.setup(opts)
  opts = opts or {}
  M.rules = opts.rules or M.rules
  user_tiers = opts.tiers or user_tiers
  if opts.langs then M.langs = opts.langs end
  if opts.filetypes then M.filetypes = opts.filetypes end
  vim.api.nvim_create_autocmd("ColorScheme", { callback = M.apply })
  M.set_variant(opts.variant or variant_for_background())
  -- Explicit surfaces still win over the variant, so a one-off pair (or
  -- `background = false`, keeping the colorscheme's own) stays possible.
  if opts.background ~= nil then M.background = opts.background end
  if opts.foreground ~= nil then M.foreground = opts.foreground end
  if opts.background ~= nil or opts.foreground ~= nil then M.apply() end

  vim.api.nvim_create_user_command("ThemeVariant", function(cmd)
    if cmd.args == "" then M.toggle() else M.set_variant(cmd.args) end
  end, {
    nargs = "?",
    complete = function() return vim.tbl_keys(M.variants) end,
    desc = "Switch the theme variant (dark/light); no argument toggles",
  })

  -- Follow the terminal. ghostty emits a DEC 2031 theme-change notification
  -- when it flips light/dark, zellij relays it into the pane, neovim re-queries
  -- OSC 11 and writes `background` -- so `background` is the single source of
  -- truth for which variant is live, and `:ThemeVariant` is just a manual write
  -- to it. See THEME.md ("Switching everything at once").
  vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = function()
      if switching then return end
      local want = variant_for_background()
      if want ~= M.variant then M.set_variant(want) end
    end,
  })

  if opts.dynamic ~= false then M.dynamic(opts.dynamic) end
end

---------------------------------------------------------------------------
-- Presets: pass one as `rules` to `setup()`. The staged plan lives in
-- THEME.md; live with each step for a day before adding the next.
---------------------------------------------------------------------------

M.presets = {}

-- 1. Nothing at all. Pure monochrome, Rob Pike mode.
M.presets.blank = {}

-- 2. Subtractive only. The single highest-leverage move every minimalist
--    converges on: dim the syntactic scaffolding so identifiers stand out
--    without spending anything.
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

-- 3. "Not code" tier. Comments and literals are foreign grammars embedded in
--    the host language; telling them apart from code is the one cost people
--    who go fully monochrome consistently report.
--
--    Comments are *recessive* here, and italic. The loud-comments idea
--    (tonsky) was measured and abandoned: upwards the ramp is only dE 11 wide,
--    so "loud" was never actually loud. Italic separates prose from code at no
--    luminance cost, and lets the two comment kinds differ from each other.
M.presets.foreign = vim.tbl_extend("force", M.presets.scaffolding, {
  ["@comment"]               = "note",  -- muted + italic: notes you wrote
  ["@comment.documentation"]  = "doc",  -- dim + italic: declaration boilerplate
  ["@string"]                = "muted",
  ["@string.escape"]         = "base",  -- pops out of a muted string by itself
  ["@string.regexp"]         = "base",
  ["@number"]                = "muted",
  ["@boolean"]               = "muted",
  ["@character"]             = "muted",
})

-- 4. Attention tiers (hank.bond) -- the current theme. Two signals on top of
--    step 3, both grayscale:
--
--      "what does this file define?"  declarations -> white + bold
--      "where does control leave?"    return/throw/defer/await -> strong
--
--    `strong` is only dE 11 from base, which is why it is spent on *keywords*:
--    they sit in a field of `dim` siblings, so the local contrast is dE ~35.
--    Signals compete with their neighbours, not with the whole screen.
M.presets.attention = vim.tbl_extend("force", M.presets.foreign, {
  ["@function"]             = "bold",   -- declaration site (not @function.call)
  ["@function.builtin"]     = "dim",    -- ...but never `make` / `len` / `append`
  ["@function.call"]        = "base",   -- ...so undo the inherited bold
  ["@function.method"]      = "bold",
  ["@function.method.call"] = "base",
  ["@type.definition"]      = "bold",
  ["@constructor"]          = "bold",
  ["@keyword.return"]       = "strong", -- override the dim inherited from @keyword
  ["@keyword.exception"]    = "strong",
  ["@keyword.coroutine"]    = "strong", -- go / defer / async / await
  ["@keyword.debug"]        = "strong",
  -- SCREAMING_CASE matches both `@type` and `@constant` in the ecma queries;
  -- `@constant` lands on top, so leaving it blank lets whatever `@type` has
  -- bleed through. `plain` writes the foreground out. See THEME.md.
  ["@constant"]             = "plain",
  ["@constant.builtin"]     = "dim",
  -- `${...}` is code, not data: reset it so the enclosing string colour does
  -- not bleed through blank groups.
  ["@embedded.code"]        = "plain",
})

-- 5. Same tiers, hue instead of luminance, borrowed from my fish theme. Kept
--    because it looks good and because it is the honest alternative -- but it
--    fails the test the grayscale ramp passes: a purple-bold declaration is
--    *darker* than the plain identifier next to it, so the definition recedes
--    exactly where it should pop. See THEME.md ("Why not colour").
M.presets.fish = vim.tbl_extend("force", M.presets.attention, {
  ["@comment"]               = "note_hue",
  ["@comment.documentation"] = "doc_hue",
  ["@string"]                = "text",
  ["@character"]             = "text",
  ["@string.escape"]         = "escape",
  ["@string.regexp"]         = "escape",
  ["@string.special"]        = "escape",
  ["@function"]              = "def",
  ["@function.method"]       = "def",
  ["@type.definition"]       = "def",
  ["@constructor"]           = "def",
  ["@keyword.return"]        = "flow",
  ["@keyword.exception"]     = "flow",
  ["@keyword.coroutine"]     = "flow",
  ["@keyword.debug"]         = "flow",
  ["@type"]                  = "shape",
  ["@type.builtin"]          = "dim",
})

--- Tiers only `presets.fish` uses. A function of the palette, so the light
--- variant's palette produces a light hue ramp instead of Tomorrow Night's
--- (which is unreadable on white).
function M.hue_tiers(p)
  return {
    note_hue = { fg = p.yellow },
    doc_hue  = { fg = p.ochre },
    text     = { fg = p.green },
    escape   = { fg = p.cyan },
    def      = { fg = p.purple, bold = true },
    flow     = { fg = p.aqua },
    shape    = { fg = p.blue },
  }
end

M.tiers = vim.tbl_deep_extend("force", M.tiers, M.hue_tiers(M.palette))

return M
