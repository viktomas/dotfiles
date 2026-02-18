# GitLab MR Notes - Implementation Reference

## API Structure

### GraphQL Query: getDiscussions

Returns discussions (comment threads) from a merge request. Each discussion contains multiple notes.

**Query Structure**:
```graphql
query getMrDiscussions($projectPath: ID!, $iid: String!) {
  project(fullPath: $projectPath) {
    mergeRequest(iid: $iid) {
      discussions {
        nodes {
          id
          replyId          # Discussion ID for creating replies
          createdAt
          resolved         # Is the discussion resolved?
          resolvable       # Can the discussion be resolved?
          notes {
            nodes {
              id
              author { name, username, avatarUrl }
              body           # Markdown text
              bodyHtml       # Rendered HTML
              createdAt
              position       # null for general notes, object for diff notes
            }
          }
        }
      }
    }
  }
}
```

## Position Object Structure

The `position` field in a note determines where it appears in the diff. It's `null` for general MR comments.

### Structure
```json
{
  "diffRefs": {
    "baseSha": "abc123...",    // Target branch commit
    "headSha": "def456...",    // MR HEAD commit
    "startSha": "ghi789..."    // Where MR branch diverged
  },
  "filePath": "src/file.ts",
  "newPath": "src/file.ts",    // Path in new version (HEAD)
  "oldPath": "src/file.ts",    // Path in old version (base)
  "positionType": "text",      // or "image"
  "newLine": 42,               // Line in new version (1-indexed), or null
  "oldLine": 38                // Line in old version (1-indexed), or null
}
```

### Position Types

#### 1. Added Line
```json
{
  "newLine": 42,
  "oldLine": null
}
```
- Comment on code that was **added** in the MR
- Only exists in new version
- Use `newPath` and `headSha`

#### 2. Removed Line
```json
{
  "newLine": null,
  "oldLine": 38
}
```
- Comment on code that was **removed** in the MR
- Only exists in old version
- Use `oldPath` and `baseSha`

#### 3. Unchanged Line
```json
{
  "newLine": 42,
  "oldLine": 38
}
```
- Comment on code that exists in **both versions**
- Line numbers may differ if lines were added/removed before this line
- Use `newPath` and `headSha` (convention)

## Line Number Indexing

**Important**: GitLab API uses **1-indexed** line numbers, while most editors use **0-indexed** line numbers.

**Conversion**:
```javascript
// GitLab API → Editor
editorLine = glLine - 1

// Editor → GitLab API
glLine = editorLine + 1
```

## Authentication

The script uses `glab` CLI which handles authentication:
- Uses stored credentials from `glab auth login`
- Respects `GITLAB_TOKEN` environment variable
- Supports multiple GitLab instances

## Error Handling

Common errors:
- **Invalid URL**: Regex doesn't match expected format
- **Authentication failed**: Run `glab auth login`
- **MR not found**: Check project path and MR IID
- **Insufficient permissions**: Need at least Reporter role

## Related Files in GitLab VSCode Extension

Reference implementation from `/Users/tomas/workspace/gl/gitlab-vscode-extension`:

1. **gql_position_parser.ts** (`main/src/desktop/review/`)
   - Parses position objects
   - Determines if comment is on old or new version
   - Maps to file paths and commits

2. **find_file_in_diffs.ts** (`main/src/desktop/utils/`)
   - Finds files in diff data
   - Handles renamed files

3. **diff_line_count.ts** (`main/src/desktop/git/`)
   - Parses diff hunks
   - Maps between file line numbers and diff positions

## Future Enhancements

### Creating Notes

To create notes, we'll need:

1. **General Note Creation**:
   - Use `createNote` GraphQL mutation
   - Only requires MR ID and body

2. **Diff Note Creation**:
   - Use `createDiffNote` GraphQL mutation
   - Requires building complete position object
   - Must parse diffs to determine line type (added/removed/unchanged)
   - Known issue: Unchanged lines require both `oldLine` and `newLine` (GitLab #325161)

**Position Building Algorithm**:
```bash
# 1. Fetch MR diffs (get diffRefs)
# 2. Find target file in diffs
# 3. Parse diff hunks to map line numbers
# 4. Determine position type:
#    - Added: newLine set, oldLine null
#    - Removed: oldLine set, newLine null  
#    - Unchanged: both set (requires parsing diff)
# 5. Build position object
# 6. Call createDiffNote mutation
```

## Testing

Test with MR: https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/merge_requests/2870

Expected output:
- Multiple discussions with notes
- Mix of general and diff notes
- Various position types (added/removed/unchanged lines)
