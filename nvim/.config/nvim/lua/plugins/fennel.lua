--------------------------------------------------------------------------------
-- Fennel / Lisp structural editing + love2d eval loop
--------------------------------------------------------------------------------
--
-- An opinionated kit for editing Fennel (and other lisps) in Neovim. It keeps
-- the "indentation drives structure" comfort of parinfer AND layers discrete,
-- bindable paredit operations on top. All structural moves live on Alt chords,
-- are buffer-local to lisp filetypes, and -- where it makes sense mid-typing --
-- also work in INSERT mode.
--
-- ── The keyboard, at a glance ────────────────────────────────────────────────
--
-- GROW / SHRINK the current form (slurp / barf). Mnemonic from vim-sexp/parpar:
-- picture the parens sitting between the home-row keys, and move the one you
-- mean in the direction you press --
--
--        (            )
--      h   j        k   l
--      ←   →        ←   →
--
--   <A-h>  slurp backward   move "(" left   -> form grows on the LEFT
--   <A-j>  barf  backward   move "(" right  -> form shrinks on the LEFT
--   <A-k>  barf  forward    move ")" left   -> form shrinks on the RIGHT
--   <A-l>  slurp forward    move ")" right  -> form grows on the RIGHT
--
--        (foo) bar   --<A-l>-->   (foo bar)   --<A-k>-->   (foo) bar
--        foo (bar)   --<A-h>-->   (foo bar)   --<A-j>-->   foo (bar)
--
-- REORDER siblings (drag). The punctuation keys carry the direction (`,`=left,
-- `.`=right); Alt drags the ELEMENT under the cursor, Ctrl drags the whole FORM
-- (the Alt=element / Ctrl=form convention also used below):
--
--   <A-,>  drag element left    (+ a b) -> (+ b a)
--   <A-.>  drag element right   (paired forms like `let` bindings move as a pair)
--   <C-,>  drag form left       (x) (y) -> (y) (x)   (moves the enclosing form
--   <C-.>  drag form right       even when the cursor sits on an inner atom)
--
-- NAVIGATE by element (these are motions -- they also work after an operator,
-- e.g. `d<A-n>` deletes to the next element):
--
--   <A-n>  jump to next element head
--   <A-p>  jump to previous element head
--
-- WRAP / UNWRAP / RAISE -- add, remove, or promote a layer of parens:
--
--   <A-w>  wrap + head   wrap the element in () and drop into insert at its head
--                          x   --<A-w>--> (|x)   --type "inc "--> (inc x)
--   <A-u>  splice/unwrap strip one layer of parens, keep the contents
--                          (print (inc x))   ->   (print inc x)
--   <A-r>  raise form    replace the parent with THIS form, dropping the wrapper
--                          (when ok (go))   ->   (go)
--   <A-e>  raise element replace the parent with the single atom under the cursor
--                          (foo (bar baz)) ->  (foo bar)
--
-- INSERT a new argument / SELECT a form:
--
--   <A-a>  append arg    jump to the form's TAIL and insert a new last argument
--                          (print "hi")  --<A-a> 10 10-->  (print "hi" 10 10)
--   <A-i>  insert head   jump to the form's HEAD and insert a new first element
--                          (foo bar)     --<A-i> baz -->   (baz foo bar)
--   <A-g>  select form   visually select the whole form under the cursor
--
-- INSERT-MODE: <A-h/j/k/l> (slurp/barf), <A-,>/<A-.> and <C-,>/<C-.> (drag),
-- <A-w> (wrap), <A-a> (append) and <A-i> (insert head) all fire mid-typing too,
-- so you can restructure without first dropping back to normal mode.
--
-- TEXTOBJECTS (free, compose with d/y/c/v in normal mode):
--
--   af / if   AROUND / INNER nearest form          daf  yif  caf  vif
--   aF / iF   AROUND / INNER top-level form         daF  yiF
--   ae / ie   AROUND / INNER element                dae  cie
--
-- Wrapping in [] or {} (vectors / tables) is done with mini.surround over those
-- textobjects, e.g. `saie[` wraps the element under the cursor in brackets.
--
-- ── Eval / live-coding (Conjure, on <localleader> = ",") ─────────────────────
--
--   <ll>ee  eval current form        <ll>cs  start REPL  (launch game)
--   <ll>er  eval root (top) form      <ll>cS  stop REPL   (quit game)
--   <ll>eF  hot reload (eval_reload)   <ll>rg  restart     (custom, below)
--   <ll>lv  open the Conjure log (vertical split)
--
-- ── Prerequisites / gotchas ──────────────────────────────────────────────────
--
--   * Alt must reach Neovim. In iTerm2 set Left Option -> "Esc+" (Keys tab),
--     otherwise the <A-x> chords are dead. The chosen keys dodge Zellij's
--     default Alt binds, so no Zellij change is needed.
--   * The Ctrl form-drag chords (<C-,> / <C-.>) only reach Neovim if the
--     terminal reports modifiers via the CSI-u / kitty keyboard protocol --
--     plain terminals swallow Ctrl+punctuation. In iTerm2 enable "Report
--     modifiers using CSI u". Quick check: in insert mode press <C-v> then
--     Ctrl+comma; a code like `<44;5u` means it's transmitted. If it isn't,
--     rebind those two to letters (e.g. <A-[> / <A-]>) in the `keys` table.
--   * Eval/run only REACHES the running game if main.fnl exposes a Fennel REPL
--     over stdin (a love.thread reading stdin and pushing lines as events).
--     Without it, <ll>cs still launches `love .` but evaluated forms have
--     nowhere to land. Template: github.com/TheBlob42/love2d-fennel-neovim
--   * The game does NOT auto-launch when you open a .fnl file (see
--     conjure#client_on_load below). Start it explicitly with <ll>cs / <ll>rg.
--
-- ── Architecture (how the four plugins cooperate) ────────────────────────────
--
--   nvim-parinfer  Keeps parens balanced FROM your indentation -- the
--                  "autoformat" comfort layer. You mostly stop closing parens
--                  by hand.
--   nvim-paredit   The structural-editing engine: slurp / barf / wrap / splice /
--                  raise / drag, plus treesitter textobjects. Fennel is
--                  supported out of the box.
--   parpar.nvim    The glue. parinfer and paredit both want to own the parens,
--                  so they fight: paredit makes a structural edit, parinfer
--                  immediately re-infers from indentation and undoes it. parpar
--                  wraps each paredit op as: pause parinfer -> run op -> resume +
--                  rebalance once. So the op sticks AND indentation stays
--                  consistent. We use parpar's `keys` for normal mode and call
--                  `parpar.wrap` directly to build the insert-mode binds.
--   Conjure        Evaluation + the love2d live-reload loop (bottom of file).
--
--   (Autopairs is handled by mini.pairs, configured in init.lua.)
--------------------------------------------------------------------------------

local paredit = require("nvim-paredit")
local parpar = require("parpar")

--------------------------------------------------------------------------------
-- <A-w>: wrap + type head
--------------------------------------------------------------------------------
-- Turn `x` into `(f x)` in one keystroke + typing the head: wrap the element
-- under the cursor in (), then enter insert mode positioned right before it so
-- the next thing you type becomes the call head.
--
--   x   --<A-w>-->   (|x)   --type "inc "-->   (inc x)
--
-- WHY THIS ONE BYPASSES PARPAR (the subtle bit):
-- Every other structural move goes through parpar so parinfer cooperates. This
-- one can't, because of a timing collision with insert mode:
--   * parpar.wrap runs SYNCHRONOUSLY as: pause parinfer -> op -> resume(), where
--     resume() re-runs parinfer in "paren" mode to fix indentation.
--   * That synchronous resume() runs right after our op and momentarily drops us
--     back out of insert mode -- which eats the first character we type (the
--     leading "i" of "inc " disappears, leaving "(nc x)").
-- So instead we gate parinfer manually with full control over timing:
--   1. disable parinfer for the buffer,
--   2. wrap (parinfer can't strip the fresh parens now),
--   3. startinsert (no async resume to bounce us out),
--   4. re-enable + rebalance parinfer on InsertLeave -- once the head is typed
--      and the form is balanced again.
local function wrap_and_type_head()
  local was_enabled = vim.b.parinfer_enabled
  vim.b.parinfer_enabled = false

  -- Wrap the element. Returns the new range; the cursor is NOT moved.
  local wrapped = paredit.api.wrap_element_under_cursor("(", ")")

  if was_enabled then
    -- Re-enable parinfer once we leave insert. `once = true` so this fires for
    -- exactly this wrap, not every future InsertLeave in the buffer.
    vim.api.nvim_create_autocmd("InsertLeave", {
      buffer = 0,
      once = true,
      callback = function()
        vim.b.parinfer_enabled = true
        -- Nudge parinfer to rebalance/reindent the line we just edited.
        pcall(vim.cmd, "silent! ParinferOn")
      end,
    })
  end

  -- Place the cursor just after the inserted "(" so the head we type lands at
  -- the very start of the form, then enter insert before the element -> (|x).
  -- nvim_win_set_cursor is (1-indexed row, 0-indexed col).
  if wrapped then
    vim.api.nvim_win_set_cursor(0, { wrapped[1] + 1, wrapped[2] + 1 })
  end
  vim.cmd("startinsert")
end

--------------------------------------------------------------------------------
-- <A-a>: append a new trailing argument to the current form
--------------------------------------------------------------------------------
-- NOT a wrap -- it keeps the existing form and just drops you inside it at the
-- tail, ready to type a new last argument:
--
--   (love.graphics.print "hi")   --<A-a>-->   (love.graphics.print "hi" |)
--                                --type "10 10"-->  (love.graphics.print "hi" 10 10)
--
-- Implementation: jump to the closing delimiter of the nearest form
-- (move_to_parent_form_end leaves the cursor ON the ")"), enter insert before
-- it, and feed one leading space so the new arg is separated from the previous
-- one. No parens are created, so unlike wrap we don't need to gate parinfer;
-- fnlfmt tidies any stray spacing on save.
local function append_to_form()
  paredit.api.move_to_parent_form_end()
  vim.cmd("startinsert")
  vim.api.nvim_feedkeys(" ", "n", false)
end

--------------------------------------------------------------------------------
-- <A-i>: insert a new FIRST element at the head of the current form
--------------------------------------------------------------------------------
-- The mirror of <A-a>. move_to_parent_form_start lands the cursor ON the
-- opening "("; we nudge it one column right so it sits on the first inner char,
-- then startinsert opens just inside the paren. Type the new head element
-- followed by a space:
--
--   (foo bar)   --<A-i> "baz "-->   (baz foo bar)
--
-- No parens are created, so (like append) we don't gate parinfer; fnlfmt tidies
-- spacing on save.
local function insert_at_form_head()
  paredit.api.move_to_parent_form_start()
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] + 1 })
  vim.cmd("startinsert")
end

--------------------------------------------------------------------------------
-- Normal-mode structural moves via parpar (slurp / barf / drag / unwrap / raise)
--------------------------------------------------------------------------------
-- parpar.setup forwards `paredit` options straight to nvim-paredit, but first
-- wraps every callback in `keys` so parinfer is paused for the op and rebalanced
-- afterwards (see the architecture note up top). These binds are applied by
-- paredit on buffer attach for its configured filetypes (clojure, fennel,
-- scheme, lisp, janet), so they are automatically buffer-local.
require("parpar").setup({
  paredit = {
    -- We bind everything explicitly on Alt chords; turn paredit's large default
    -- keymap off so it doesn't add noise. Textobjects are bound separately in
    -- the FileType autocmd below.
    use_default_keys = false,

    -- Fix indentation after slurp/barf so multi-line forms stay visually
    -- consistent (paredit's native, fast-but-not-100%-correct indentor).
    indent = { enabled = true },

    keys = {
      -- Slurp / barf, both directions. See the home-row mnemonic up top.
      ["<A-h>"] = { paredit.api.slurp_backwards, "Slurp backward (grow head)" },
      ["<A-l>"] = { paredit.api.slurp_forwards, "Slurp forward (grow tail)" },
      ["<A-j>"] = { paredit.api.barf_backwards, "Barf backward (shrink head)" },
      ["<A-k>"] = { paredit.api.barf_forwards, "Barf forward (shrink tail)" },

      -- Reorder siblings. ELEMENT drag (not form drag) because the common
      -- targets -- function arguments and `let` bindings -- are elements. With
      -- paredit's auto_drag_pairs (on by default) a `let` binding's key and
      -- value move together as a pair.
      ["<A-,>"] = { paredit.api.drag_element_backwards, "Drag element left" },
      ["<A-.>"] = { paredit.api.drag_element_forwards, "Drag element right" },

      -- FORM drag (Ctrl = the bigger unit). Moves the whole enclosing form among
      -- its siblings, even when the cursor is on an inner atom -- which element
      -- drag can't do. (Needs a CSI-u-capable terminal; see the gotcha up top.)
      ["<C-,>"] = { paredit.api.drag_form_backwards, "Drag form left" },
      ["<C-.>"] = { paredit.api.drag_form_forwards, "Drag form right" },

      -- Splice / unwrap one level -- the inverse of <A-w>. paredit calls this
      -- "unwrap"; other paredit implementations call it "splice".
      ["<A-u>"] = { paredit.api.unwrap_form_under_cursor, "Splice / unwrap" },

      -- Raise: replace the PARENT form with the thing under the cursor,
      -- discarding everything else around it (the emacs `M-r` move). <A-r>
      -- raises the whole FORM; <A-e> raises a single ELEMENT (atom). Both are
      -- plain (non-shifted) Alt chords so they work with chordless home-row mods.
      ["<A-r>"] = { paredit.api.raise_form, "Raise form" },
      ["<A-e>"] = { paredit.api.raise_element, "Raise element" },
    },
  },
})

--------------------------------------------------------------------------------
-- Insert-mode structural moves + custom moves + textobjects (FileType: lisp)
--------------------------------------------------------------------------------
-- Bound here rather than in parpar's `keys` because:
--   * the insert-mode slurp/barf/drag binds must NOT carry paredit's dot-repeat
--     machinery (which is normal-mode only), so we wrap the raw API with
--     parpar.wrap ourselves and bind it as plain `i` maps;
--   * textobjects are pure selections -- they must NOT be parpar-wrapped, or
--     parinfer's post-op rebalance could reflow the buffer on a mere selection;
--   * <A-w> gates parinfer itself (see wrap_and_type_head) and must not be
--     double-managed by parpar.
-- We scope everything to the same lisp filetypes paredit supports, buffer-local.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "fennel", "clojure", "scheme", "lisp", "janet" },
  callback = function(ev)
    local map = function(modes, lhs, rhs, desc)
      vim.keymap.set(modes, lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    -- Insert-mode slurp / barf / drag. parpar.wrap pauses parinfer around the
    -- op and rebalances after, exactly like the normal-mode binds, but we stay
    -- in insert mode the whole time so you can keep typing.
    map("i", "<A-h>", parpar.wrap(paredit.api.slurp_backwards), "Slurp backward")
    map("i", "<A-l>", parpar.wrap(paredit.api.slurp_forwards), "Slurp forward")
    map("i", "<A-j>", parpar.wrap(paredit.api.barf_backwards), "Barf backward")
    map("i", "<A-k>", parpar.wrap(paredit.api.barf_forwards), "Barf forward")
    map("i", "<A-,>", parpar.wrap(paredit.api.drag_element_backwards), "Drag element left")
    map("i", "<A-.>", parpar.wrap(paredit.api.drag_element_forwards), "Drag element right")
    map("i", "<C-,>", parpar.wrap(paredit.api.drag_form_backwards), "Drag form left")
    map("i", "<C-.>", parpar.wrap(paredit.api.drag_form_forwards), "Drag form right")

    -- Element motions. These are movements, NOT edits, so they must NOT be
    -- parpar-wrapped (a mere cursor move shouldn't trigger parinfer's reflow).
    -- Bound across n/x/o/v so they double as operator motions (e.g. d<A-n>).
    map({ "n", "x", "o", "v" }, "<A-n>", paredit.api.move_to_next_element_head, "Next element")
    map({ "n", "x", "o", "v" }, "<A-p>", paredit.api.move_to_prev_element_head, "Prev element")

    -- <A-w> wrap element + type head, <A-a> append a trailing arg, <A-i> insert
    -- a new head element. All three enter insert mode themselves, so they work
    -- identically from normal or insert mode -- bind them in both.
    map({ "n", "i" }, "<A-w>", wrap_and_type_head, "Wrap + head")
    map({ "n", "i" }, "<A-a>", append_to_form, "Append arg to form")
    map({ "n", "i" }, "<A-i>", insert_at_form_head, "Insert at form head")

    -- Textobjects. Bound in operator-pending (o) and visual (v) modes so they
    -- compose with d/y/c/v. af/if = (around/inner) nearest form; aF/iF = the
    -- top-level form; ae/ie = the element under the cursor.
    map({ "o", "v" }, "af", paredit.api.select_around_form, "Around form")
    map({ "o", "v" }, "if", paredit.api.select_in_form, "In form")
    map({ "o", "v" }, "aF", paredit.api.select_around_top_level_form, "Around top-level form")
    map({ "o", "v" }, "iF", paredit.api.select_in_top_level_form, "In top-level form")
    map({ "o", "v" }, "ae", paredit.api.select_element, "Around element")
    map({ "o", "v" }, "ie", paredit.api.select_element, "Inner element")

    -- <A-g> select the whole form under the cursor.
    -- We DON'T remap to the keys "vaf": that composition is unreliable because
    -- the textobject is implemented via operatorfunc and doesn't apply
    -- atomically inside a remap. Instead start visual mode and call the
    -- textobject function directly, which extends the selection reliably.
    map("n", "<A-g>", function()
      vim.cmd("normal! v")
      paredit.api.select_around_form()
    end, "Select form")
  end,
})

--------------------------------------------------------------------------------
-- Conjure: evaluation + the love2d live-reload loop
--------------------------------------------------------------------------------
-- Conjure evaluates Fennel by running a stdio subprocess and talking to it as a
-- REPL. We point that subprocess at `love .`, so the "REPL" IS the running game
-- -- evaluated forms execute inside it and can read/mutate live game state.
--
-- The eval/run moves use Conjure's default <localleader> binds plus one custom:
--   <ll>ee  eval current form          <ll>cs  start REPL  (launch game)
--   <ll>er  eval root (top-level) form  <ll>cS  stop REPL   (quit game)
--   <ll>eF  hot reload (eval_reload)    <ll>rg  restart     (custom, below)
--
-- IMPORTANT: for eval to actually reach the *running* game, the love2d process
-- must expose a Fennel REPL over stdin (a love.thread reading stdin and pushing
-- lines as events). Until main.fnl includes that, <ll>cs launches `love .` but
-- evaluated forms have nowhere to land. Template:
-- github.com/TheBlob42/love2d-fennel-neovim
vim.g["conjure#filetype#fennel"] = "conjure.client.fennel.stdio"
vim.g["conjure#client#fennel#stdio#command"] = "love ."

-- Conjure's stdio client otherwise runs M.start (== launches `love .`) the
-- moment you open ANY .fnl buffer. We don't want a game window popping up every
-- time we open a file. So disable on-load auto-start; start the game explicitly
-- with <ll>cs / <ll>rg.
vim.g["conjure#client_on_load"] = false

-- Don't hijack `K` for doc lookups in lisp buffers; keep the HUD quiet.
vim.g["conjure#mapping#doc_word"] = false

-- Launch / restart the game == restarting the Conjure stdio subprocess. Bound
-- buffer-local on fennel files. stop() is a no-op if nothing is running, so this
-- doubles as a cold start. The 200ms gap lets the old process fully exit before
-- we spawn the new one.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "fennel",
  callback = function(ev)
    vim.keymap.set("n", "<localleader>rg", function()
      local stdio = require("conjure.client.fennel.stdio")
      pcall(stdio.stop)
      vim.defer_fn(function()
        pcall(stdio.start)
      end, 200)
    end, { buffer = ev.buf, desc = "Launch / restart love2d game" })
  end,
})
