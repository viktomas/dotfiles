---
date:        2026-11-09
session/ref: task global-agent-sc-jakd6 (global scaffolding pass)
symptom:     pi fails to load a skill (and headless `pi -p` sessions die
             before creating a session log) with "Nested mappings are not
             allowed in compact mappings" pointing at the description line
evidence:    three SKILL.md rewrites in the global pass contained `: `
             (colon+space) inside unquoted YAML plain scalars
             ("Keywords: rodney", "an MR review: validate") — invalid YAML
             frontmatter; the whole harness reported the skills broken
             until fixed (commit-less working tree, fixed same session)
cause:       description rewrites used colons where the established style
             used " - "; plain scalars cannot contain ": "
fix type:    mechanism (validator) + skill (style rule)
fingerprint: skill-frontmatter-colon-space
count:       1
---

Fix applied: rewrote the three descriptions without `: `. Proposed
mechanism (in `.agents/proposals/global-hook-scope.md` rev 3): the extended
check.sh validator should parse frontmatter with a real YAML parser (or at
minimum fail on `: ` in an unquoted description) so this class of bug is
caught at commit time, not at session start.
