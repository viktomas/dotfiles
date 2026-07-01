---
name: mr-issue-standards
description: Content standards for writing GitLab merge request and issue titles, descriptions, and comments — formatting, structure, and conventions. Use whenever you create or update an MR/issue description or body, or write any comment. This is about WHAT to write, not how to call the API (see gitlab-api / gitlab-mr-comments for the commands). Keywords - MR description, issue description, MR title, issue title, conventional commit, Problem Solution, AI-generated.
---

# MR & Issue Content Standards

This skill is the single source of truth for **how MR/issue content should read** —
titles, description structure, and formatting. It does **not** cover API calls:

- Making the call (create/update MR, issue) → **gitlab-api** skill
- Reading/writing MR discussion comments → **gitlab-mr-comments** skill

## The `:robot: AI-generated` Prefix (canonical rule)

**MANDATORY**: Every piece of content an agent writes to GitLab — MR descriptions,
issue descriptions, and all comments/notes — MUST start with:

```
:robot: AI-generated

```

…followed by the actual content. No exceptions. This is the canonical definition of
the rule; other skills reference it from here.

## Referring to MRs and Issues

**Never use the `#123` (issue) or `!345` (MR) shortcuts.** Tomas does not keep integer
IDs in his head and they are useless to him. Always use the `[title](full URL)` markdown
format when mentioning an MR or issue in chat, descriptions, or comments.

## Titles

Use Conventional Commits style: `type(scope): summary`.

- Common types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`.
- Keep the summary short, imperative, lowercase: `feat(cli): add --json flag`.
- Drafts use the `Draft:` prefix: `Draft: feat(cli): add --json flag`.

## Issue Descriptions

Keep them **brief**. Use these two headers:

```markdown
:robot: AI-generated

## Problem

What's wrong / what's missing, in a sentence or two.

## Solution

The proposed change, in a sentence or two.
```

## MR Descriptions

Keep them brief and reviewer-focused. Lead with *what changed and why*, not a
play-by-play of the work.

```markdown
:robot: AI-generated

## What

One or two sentences on what this MR changes.

## Why

The motivation / the problem it solves. Link the related issue as [title](URL).

## Notes for the reviewer

Anything non-obvious: trade-offs, follow-ups, things to look at closely. Omit if empty.
```

Link related issues with the `[title](URL)` format. Don't paste raw `#`/`!` references.
