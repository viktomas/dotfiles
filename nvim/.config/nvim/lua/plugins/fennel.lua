--------------------------------------------------------------------------------
-- Fennel / Lisp structural editing + love2d eval loop
--------------------------------------------------------------------------------
--
-- A small, opinionated kit for editing Fennel (and other lisps) in Neovim. It
-- keeps the "indentation drives structure" comfort of an autoformatter AND adds
-- discrete, bindable structural-editing commands. Ten moves, no more.
--
-- ── How to drive it (cheat sheet) ────────────────────────────────────────────
--
-- The SIX structural moves are Alt chords. They are buffer-local to lisp files,
-- so they do nothing in other filetypes. Press them in NORMAL mode.
--
--   <A-s>   slurp forward     grow this form to swallow the next sibling
--                               (foo) bar   ->   (foo bar)
--   <A-b>   barf forward      shrink this form, expelling its last child
--                               (foo bar)   ->   (foo) bar
--   <A-w>   wrap + head       wrap the element under the cursor in () and drop
--                             into insert mode to type the call head
--                               x   ->   (|x)   --type "inc "-->   (inc x)
--   <A-u>   splice / unwrap   strip one layer of parens, keep the contents
--                               (print (inc x))   ->   (print inc x)
--   <A-e>   drag element fwd  move the element under the cursor right
--   <A-a>   drag element back move the element under the cursor left
--                               (+ a b)   <->   (+ b a)
--                             (used to reorder args, let bindings, branches)
--   <A-g>   select form       visually select the whole form under the cursor
--
-- Because the textobjects below are registered, you ALSO get the usual operator
-- compositions for free, just by typing them in normal mode:
--
--   daf / yaf / caf / vaf   delete / yank / change / select AROUND form
--   dif / yif / cif / vif   ... the INNER form (contents only)
--   daF / diF               ... the AROUND / INNER top-level form
--
-- The FOUR eval/run moves stay on <localleader> (set to "," in keymaps.lua).
-- These talk to a Conjure REPL whose subprocess is the running game:
--
--   <ll>ee  eval the current form (the expression under the cursor)
--   <ll>er  eval the root form    (the enclosing top-level form -- redefine a
--                                  whole `fn` live in the running game)
--   <ll>eF  hot reload            (re-run the current file in the game)
--   <ll>cs  start the REPL        (== launch the game)
--   <ll>cS  stop the REPL         (== quit the game)
--   <ll>rg  launch / restart      (custom: stop then start, e.g. after a crash)
--
-- ── Prerequisites / gotchas ──────────────────────────────────────────────────
--
--   * Alt must reach Neovim. In iTerm2 set Left Option -> "Esc+" (Keys tab),
--     otherwise <A-x> chords are dead. The chosen letters (s b w u e a g) dodge
--     Zellij's default Alt binds, so no Zellij change is needed.
--   * Eval/run (the <ll> moves) only REACHES the running game if main.fnl
--     exposes a Fennel REPL over stdin (a love.thread that reads stdin and
--     pushes lines as events). Without it, <ll>cs still launches `love .` but
--     evaluated forms have nowhere to land. Template:
--     github.com/TheBlob42/love2d-fennel-neovim
--   * The game does NOT auto-launch when you open a .fnl file (see
--     conjure#client_on_load below). Start it explicitly with <ll>cs / <ll>rg.
--
-- ── Architecture (how the four plugins cooperate) ────────────────────────────
--
--   nvim-parinfer  Keeps parens balanced FROM your indentation. This is the
--                  "autoformat" comfort layer -- you mostly stop closing parens
--                  by hand. Reacts to every buffer change.
--   nvim-paredit   The structural-editing engine: slurp / barf / wrap / splice
--                  / drag, plus treesitter textobjects (af/if). Fennel is
--                  supported out of the box -- no separate extension needed.
--   parpar.nvim    The glue. parinfer and paredit both want to own the parens,
--                  so they fight: paredit makes a structural edit, parinfer
--                  immediately "re-infers" from indentation and undoes it.
--                  parpar wraps each paredit op as: pause parinfer -> run the
--                  op -> re-enable parinfer and rebalance once. So the op sticks
--                  AND indentation stays consistent. It does this for every
--                  callback passed in `paredit.keys` below.
--   Conjure        Evaluation + the love2d live-reload loop (bottom of file).
--
--   (Autopairs is handled by mini.pairs, configured in init.lua -- nothing to
--    add here.)
--------------------------------------------------------------------------------

local paredit = require("nvim-paredit")

--------------------------------------------------------------------------------
-- Move 3: wrap + type head
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
--   * parpar.wrap runs SYNCHRONOUSLY as: pause parinfer -> op -> resume()
--     where resume() re-runs parinfer in "paren" mode to fix indentation.
--   * That synchronous resume() runs right after our op and momentarily drops
--     us back out of insert mode -- which eats the first character we type
--     (the leading "i" of "inc " disappears, leaving "(nc x)").
-- So instead we gate parinfer manually with full control over timing:
--   1. disable parinfer for the buffer,
--   2. wrap (parinfer can't strip the fresh parens now),
--   3. startinsert (no async resume to bounce us out),
--   4. re-enable + rebalance parinfer on InsertLeave -- i.e. once we're done
--      typing the head and the form is balanced again.
--
-- Notes on the implementation details that were easy to get wrong:
--   * wrap_element_under_cursor returns a LIST of nodes, not a single TSNode, so
--     don't call :start() on it. We don't need to: paredit leaves the cursor on
--     the (now wrapped) element, so a plain `startinsert` already lands us right
--     before it.
--   * We only register the InsertLeave re-enable if parinfer WAS enabled, so we
--     never silently turn it on in a buffer where the user had it off.
local function wrap_and_type_head()
  local was_enabled = vim.b.parinfer_enabled
  vim.b.parinfer_enabled = false

  -- Wrap the element; cursor ends up on the wrapped element, ready for insert.
  paredit.api.wrap_element_under_cursor("(", ")")

  if was_enabled then
    -- Re-enable parinfer once we leave insert. `once = true` so this fires for
    -- exactly this wrap, not every future InsertLeave in the buffer.
    vim.api.nvim_create_autocmd("InsertLeave", {
      buffer = 0,
      once = true,
      callback = function()
        vim.b.parinfer_enabled = true
        -- Nudge parinfer to rebalance/reindent the line we just edited, so the
        -- buffer matches what parinfer would have produced on its own.
        pcall(vim.cmd, "silent! ParinferOn")
      end,
    })
  end

  -- Enter insert mode before the wrapped element -> type the call head + space.
  vim.cmd("startinsert")
end

--------------------------------------------------------------------------------
-- Structural moves via parpar (1, 2, 4, 5)
--------------------------------------------------------------------------------
-- parpar.setup forwards `paredit` options straight to nvim-paredit, but first
-- wraps every callback in `keys` so parinfer is paused for the op and rebalanced
-- afterwards (see the architecture note up top). These binds are applied by
-- paredit on buffer attach for its configured filetypes (clojure, fennel,
-- scheme, lisp, janet), so they are automatically buffer-local -- they only
-- exist in lisp buffers and never shadow <A-x> elsewhere.
require("parpar").setup({
  paredit = {
    -- We bind the structural moves explicitly on Alt chords. Turn paredit's
    -- large default keymap off so it doesn't add noise; the textobjects we want
    -- are bound separately in the FileType autocmd below.
    use_default_keys = false,

    -- Fix indentation after slurp/barf so multi-line forms stay visually
    -- consistent (paredit's native, fast-but-not-100%-correct indentor).
    indent = { enabled = true },

    keys = {
      -- 1 + 2: grow / shrink the current form. Forward-only to start; add the
      --        backward variants (slurp_backwards / barf_backwards) later if
      --        you find you want them.
      ["<A-s>"] = { paredit.api.slurp_forwards, "Slurp forward" },
      ["<A-b>"] = { paredit.api.barf_forwards, "Barf forward" },

      -- 4: splice / unwrap one level -- the inverse of wrap (move 3). paredit
      --    calls this "unwrap"; other paredit implementations call it "splice".
      ["<A-u>"] = { paredit.unwrap.unwrap_form_under_cursor, "Splice / unwrap" },

      -- 5: reorder siblings. We use ELEMENT drag (not form drag) because the
      --    common targets -- function arguments and `let` bindings -- are
      --    elements. With paredit's auto_drag_pairs (on by default) a `let`
      --    binding's key and value move together as a pair.
      ["<A-e>"] = { paredit.api.drag_element_forwards, "Drag element fwd" },
      ["<A-a>"] = { paredit.api.drag_element_backwards, "Drag element back" },
    },
  },
})

--------------------------------------------------------------------------------
-- Move 6 + textobjects + move 3 binding (FileType: lisp buffers)
--------------------------------------------------------------------------------
-- These are bound here (rather than in parpar's `keys`) for two reasons:
--   * the textobjects are pure selections -- they must NOT be parpar-wrapped, or
--     parinfer's post-op rebalance could reflow the buffer on a mere selection;
--   * move 3 (<A-w>) gates parinfer itself (see wrap_and_type_head) and must not
--     be double-managed by parpar.
-- We scope them to the same lisp filetypes paredit supports, buffer-local, so
-- they mirror paredit's own attach behaviour.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "fennel", "clojure", "scheme", "lisp", "janet" },
  callback = function(ev)
    local map = function(modes, lhs, rhs, desc)
      vim.keymap.set(modes, lhs, rhs, { buffer = ev.buf, desc = desc })
    end

    -- 3: wrap element + type head (see wrap_and_type_head above).
    map("n", "<A-w>", wrap_and_type_head, "Wrap + head")

    -- Textobjects. Bound in operator-pending (o) and visual (v) modes so they
    -- compose with d/y/c/v: e.g. `daf` deletes the surrounding form, `cif`
    -- changes its contents. af/if = (around/inner) nearest form; aF/iF = the
    -- (around/inner) top-level form.
    map({ "o", "v" }, "af", paredit.api.select_around_form, "Around form")
    map({ "o", "v" }, "if", paredit.api.select_in_form, "In form")
    map({ "o", "v" }, "aF", paredit.api.select_around_top_level_form, "Around top-level form")
    map({ "o", "v" }, "iF", paredit.api.select_in_top_level_form, "In top-level form")

    -- 6: select the whole form under the cursor.
    -- We DON'T remap <A-g> to the keys "vaf": that composition is unreliable
    -- because the textobject is implemented via operatorfunc and doesn't apply
    -- atomically inside a remap. Instead we start visual mode and call the
    -- textobject function directly, which extends the selection reliably.
    map("n", "<A-g>", function()
      vim.cmd("normal! v")
      paredit.api.select_around_form()
    end, "Select form")
  end,
})

--------------------------------------------------------------------------------
-- Conjure: evaluation + the love2d live-reload loop (moves 7-10)
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
-- time we open a file -- and it's pointless until the stdin REPL thread exists.
-- So disable on-load auto-start; start the game explicitly with <ll>cs / <ll>rg.
vim.g["conjure#client_on_load"] = false

-- Don't hijack `K` for doc lookups in lisp buffers; keep the HUD quiet.
vim.g["conjure#mapping#doc_word"] = false

-- Move 10: launch / restart the game.
-- Restarting the game == restarting the Conjure stdio subprocess. We bind this
-- buffer-local on fennel files (so it doesn't exist where it makes no sense).
-- stop() is a no-op if nothing is running, so this doubles as a cold start.
-- The 200ms gap lets the old process fully exit before we spawn the new one.
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
