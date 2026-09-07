; extends

; Doc comments on methods.
;
; nvim-treesitter's go queries promote `(comment)+` to
; `@comment.documentation` in front of a type, const, var or *function*
; declaration -- but not in front of a `method_declaration`. This theme paints
; doc comments (ochre) differently from the notes you leave inside a function
; body (yellow), so without this a method's doc comment is the loudest thing
; in the file while the identical comment on a plain function is not.
(source_file
  (comment)+ @comment.documentation
  .
  (method_declaration))
