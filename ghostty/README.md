# Ghostty

Config is stow-managed at `ghostty/.config/ghostty/config.ghostty`. Ghostty
auto-loads it from the XDG path (`~/.config/ghostty/config.ghostty`) — no manual
setup needed after `stow ghostty`.

## Tab switching (Space+j / Space+k)

`Space+j` / `Space+k` switch tabs across apps. Ghostty is the bridge between the
keyboard layer and zellij:

- **Kanata** (`defchordsv2`): `Space+j` → `Cmd+Shift+[`, `Space+k` → `Cmd+Shift+]`.
  See `../kanata/README.md`.
- **Browsers / other apps**: `Cmd+Shift+[`/`]` is the native macOS tab-switching
  shortcut — works out of the box.
- **Ghostty → zellij**: Ghostty intercepts `Cmd+Shift+[`/`]` and forwards it as
  `Ctrl+Shift+j`/`k` (kitty keyboard protocol), which zellij binds to
  `GoToPreviousTab` / `GoToNextTab` in normal mode.
