---
description: Deep MR review - validate the business need and challenge the solution with alternative designs
argument-hint: "[mr-url] [extra context]"
---
Load the `problem-validation` and `solution-validation` skills and run both on ${1:-the MR from this session's review file, or ask me which MR}. Follow each skill's own instructions and output rules — their sections are never posted as MR comments.

End with a single `GATE: reply - <problem verdict>; <solution verdict>` (mid-review, keep the session's existing gate). ${@:2}
