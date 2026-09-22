#import "lib.typ": *

// Mirrors zellij/.config/zellij/config.kdl. When a keybind changes there,
// change it here too.

#show: body => sheet(
  "Zellij",
  subtitle: [everything starts with #key("ctrl y") → *pane mode*; #key("esc") gets back out],
  body,
)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 7pt,

  // ── Column 1 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "Normal mode",
      rows(
        ("ctrl y", "→ pane mode (turns pane frames on)"),
        ("ctrl J", "previous tab"),
        ("ctrl K", "next tab"),
      ),
    ),

    panel(
      "Pane mode — panes",
      rows(
        ("h j k l", "move focus"),
        ("H J K L", "new pane left / down / up / right"),
        ("ctrl d", "close focused pane"),
        ("f", "fullscreen toggle"),
        ("w", "toggle floating panes"),
        ("e", "embed ↔ float the focused pane"),
        ("c", "rename pane"),
        ("z", "toggle pane frames"),
        ("/", "open scrollback in nvim"),
        ("m", "→ move mode (swap panes around)"),
        ("r", "→ resize mode"),
        ("s", "→ scroll / search mode"),
      ),
      color: accent2,
    ),
  ),

  // ── Column 2 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "Pane mode — tabs & session",
      rows(
        ("t", "→ tab mode"),
        ("ctrl t", "rename tab"),
        ("n", "new tab"),
        ("ctrl h", "previous tab"),
        ("ctrl l", "next tab"),
        ("ctrl 1 … 9", "go to tab n"),
        ("ctrl D", "close tab"),
        ("ctrl s", "toggle sync for this tab"),
        ("o", "→ session mode"),
        ("d", "detach"),
        ("ctrl q", "quit zellij"),
      ),
    ),

    panel(
      "Tab mode",
      rows(
        ("h l", "previous / next tab"),
        ("H L", [*move the current tab* left / right]),
        ("1 … 9", "go to tab n"),
        ("tab", "toggle — jump back to the tab you came from"),
        ("n", "new tab"),
        ("x", "close tab"),
        ("r", "rename tab"),
        ("s", "toggle sync: type once, every pane in the tab gets it"),
        ("esc", "back to normal"),
      ),
      color: accent2,
    ),
  ),

  // ── Column 3 ─────────────────────────────────────────────────
  stack(
    spacing: 6pt,

    panel(
      "My popups (pane mode)",
      rows(
        ("ctrl y", [#key("ctrl y") twice: floating `task switch` picker]),
        ("a", "floating prompt: new task"),
        ("g", "show the kanata symbol layer"),
      ),
    ),

    panel(
      "Resize / move / scroll",
      rows(
        ("r h j k l", "grow the pane in that direction"),
        ("r + -", "grow / shrink all round"),
        ("m h j k l", "move the pane in that direction"),
        ("m tab", "swap with the next pane"),
        ("s j k", "scroll line, " + [#key("d") #key("u") half page]),
        ("s /", "search; " + [#key("n") #key("N") next / previous match]),
        ("s e", "edit scrollback in nvim"),
        ("esc", "every sub-mode returns to pane mode"),
      ),
      color: accent2,
    ),

    panel(
      "Two tab tricks worth remembering",
      [
        *Sync* (#key("s") in tab mode, #key("ctrl s") in pane mode) broadcasts
        your keystrokes to *every pane in the tab* — one `git pull`, four
        repos. The tab bar shows `<SYNC>`; press again to stop.

        *Toggle* (#key("tab") in tab mode) is "previous tab" in the alt-tab
        sense: it flips between the last two tabs you used, not between
        neighbours. Ideal for bouncing editor ↔ logs.
      ],
    ),
  ),
)
