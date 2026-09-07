; extends

; `${ ... }` inside a template literal is code, not data.
;
; nvim-treesitter captures the whole literal as `(template_string) @string` and
; then marks the interpolation `(template_substitution) @none` -- but `@none`
; is *ignored* by the highlighter, it does not reset anything. Captures inside
; the interpolation that resolve to an attribute-less highlight group (our
; `base` tier is deliberately `{}` so backgrounds compose) therefore inherit
; the foreground of the string extmark underneath them, and every identifier
; in `${...}` reads as a string.
;
; This adds a capture on the substitution node that our theme maps to the
; `plain` tier -- `Normal`'s foreground, written out. Because the node is
; deeper than the enclosing template_string, its extmark lands on top at equal
; priority, so blank captures fall back to it instead of to `@string`.
; Priority is intentionally NOT raised: captures nested deeper still win, so
; `@operator` / `@punctuation` keep their own tiers inside `${}`.
((template_substitution) @embedded.code)
