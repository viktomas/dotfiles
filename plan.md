# Plan: GitLab MR Notes Skill

## Goal
Create a skill in `~/.pi/skills/` that reads notes (comments) from GitLab merge requests. The skill will retrieve both general notes and diff notes, with diff notes including their position information in the diff.

## Test MR
https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870

## Current State
Reading functionality is complete and tested. The skill successfully:
- Fetches all notes from GitLab MRs using GraphQL
- Distinguishes between general notes and diff notes
- Parses and displays position information for diff notes (file path, line number, type, commit SHA)
- Outputs in a clean format for AI assistant consumption
- Tested with MR 2870 (28 notes found and correctly formatted)

Skill location: `~/.pi/skills/gitlab-mr-notes/`

## Implementation Steps

No remaining implementation steps for reading functionality.

## Follow-Up: Creating Notes (Future Work)

After the reading functionality is complete, implement note creation:

### Creating General Notes
Add ability to create general MR comments (not attached to specific lines).

### Creating Diff Notes
Implement function to create comments on specific lines in diffs.

**Function Signature**:
```bash
create_mr_line_comment.sh <MR_URL> <FILE_PATH> <LINE_NUMBER> <COMMENT_BODY>
```

**Requirements**:
1. Fetch MR version data (get diffs and commit SHAs)
2. Find file in diffs
3. Parse diff to determine line type (added/unchanged/removed)
4. Build position object with appropriate oldLine/newLine
5. Call createDiffNote GraphQL mutation

**Key Constraints**:
- Line numbers are 1-indexed
- Unchanged lines require both oldLine and newLine (GitLab API issue #325161)
- Must use global MR ID format: `gid://gitlab/MergeRequest/{id}`
- File paths must match diff entry exactly

### Diff Parsing for Line Mapping

When creating comments, need to parse diffs to map line numbers:

**Hunk Format**:
```
@@ -38,9 +36,8 @@
 unchanged line
-removed line
+added line
 another unchanged line
```

**Algorithm**: Track old and new line counters, increment based on line prefix:
- `-` → increment oldIndex only
- `+` → increment newIndex only
- ` ` → increment both

### Test Cases for Creation
- Added line (only in new version)
- Unchanged line (both versions, needs oldLine and newLine)
- Multiple hunks in file
- Error cases: file not found, line out of bounds, diff too large

## Reference Material

### Understanding Comment/Discussion Structure

**GraphQL Query**: `getDiscussions(issuable)` returns discussions (comment threads), where each discussion contains:
- `replyId`: Discussion ID for replies
- `createdAt`: Timestamp
- `resolved`: Boolean indicating if discussion is resolved
- `resolvable`: Boolean indicating if discussion can be resolved
- `notes`: Array of notes (individual comments in the thread)

Each **note** contains:
- `id`: Unique note ID
- `author`: User info (name, username, avatarUrl)
- `body`: Comment text (markdown)
- `bodyHtml`: Rendered HTML
- `createdAt`: Timestamp
- `position`: Where the comment is located in the diff (null for general notes)

### Position Structure Details

The `position` field determines where a comment appears in the diff:

```javascript
position: {
  diffRefs: {
    baseSha: string,    // Target branch commit
    headSha: string,    // MR HEAD commit
    startSha: string    // Where MR branch diverged
  },
  filePath: string,
  newPath: string,      // Path in new version (HEAD)
  oldPath: string,      // Path in old version (base)
  positionType: 'text' | 'image',
  newLine: number | null,  // Line in new version (1-indexed)
  oldLine: number | null   // Line in old version (1-indexed)
}
```

### Three Types of Comment Positions

1. **Added Line**: `{ newLine: 42, oldLine: null }` - Comment on code added in the MR
2. **Removed Line**: `{ newLine: null, oldLine: 38 }` - Comment on code removed in the MR
3. **Unchanged Line**: `{ newLine: 42, oldLine: 38 }` - Comment on code existing in both versions

### Mapping Comments to Diff Lines

**Algorithm** (from `/Users/tomas/workspace/gl/gitlab-vscode-extension/main/src/desktop/review/gql_position_parser.ts`):

```javascript
// 1. Determine if comment is on old or new version
const isOld = position.oldLine !== null && position.newLine === null;

// 2. Get file path for the correct version
const path = isOld ? position.oldPath : position.newPath;

// 3. Get commit SHA for the correct version
const commit = isOld ? position.diffRefs.baseSha : position.diffRefs.headSha;

// 4. Get line number (whichever is not null)
const glLine = position.oldLine ?? position.newLine;

// 5. Convert from GitLab (1-indexed) to editor (0-indexed)
const editorLine = glLine - 1;
```

### Existing Codebase References
The GitLab LSP extension contains relevant code for:
- Fetching discussions: GraphQL queries
- Parsing positions: `/Users/tomas/workspace/gl/gitlab-vscode-extension/main/src/desktop/review/gql_position_parser.ts`
- Finding files in diffs: `/Users/tomas/workspace/gl/gitlab-vscode-extension/main/src/desktop/utils/find_file_in_diffs.ts`
- Diff line counting: `/Users/tomas/workspace/gl/gitlab-vscode-extension/main/src/desktop/git/diff_line_count.ts`
