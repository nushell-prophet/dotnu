# Extract Session Context from Selected Pipelines

## Use Case

When using fzf to select commands from history:
1. User selects multiple commands in fzf
2. fzf combines them with `;\n` separator
3. User wants to see **full session context** for those commands

## Goal

Create a command that:
1. **Input**: String containing multiple pipelines (separated by `;` or newlines)
2. **Parse**: Extract individual complete pipelines using AST
3. **Query**: Search each pipeline in history database
4. **Expand**: Get session_ids of matching commands
5. **Output**: All commands from those sessions (full context)

## Example Flow

```nu
# Input from fzf (combined with ;\n)
"ls | where size > 1mb;\ncd ~/projects;\ngit status"

# Step 1: Parse into individual pipelines
# => ["ls | where size > 1mb", "cd ~/projects", "git status"]

# Step 2: Query history for each pipeline
# => Returns rows with session_ids: [abc123, def456, abc123]

# Step 3: Get unique session_ids
# => [abc123, def456]

# Step 4: Query all commands from those sessions
# => Full table of commands from sessions abc123 and def456
```

## AST Parsing Component

The key challenge: extract complete pipelines from input that may contain:
- Multiple pipelines separated by `;`
- Multiple pipelines separated by newlines
- Multi-line pipelines (blocks, closures)
- Comments between pipelines

### Approach: `ast --json`

`ast --json` is the right tool - it gives `pipelines` array directly:

```nu
ast --json 'ls | where size > 1mb;\ncd ~/projects;\ngit status'
| get block | from json | get pipelines | length
# => 3
```

No special handling needed:
- AST parser handles `;`, newlines, multi-line blocks correctly
- Each pipeline has spans for text extraction
- Just iterate over `pipelines` array

## Components to Build

1. **`extract-pipelines`** - Parse input string, return list of pipeline strings
   - Input: `"cmd1;\ncmd2;\ncmd3"`
   - Output: `["cmd1", "cmd2", "cmd3"]`

2. **`expand-to-sessions`** - Query history, return full session context
   - Input: list of command strings
   - Output: table of all commands from matching sessions

## Decisions

1. **Location**: `extract-pipelines` lives in dotnu (general AST utility)
2. **Missing commands**: Skip for now - no special handling needed
3. **Matching**: Start with exact match. Future: embeddings for semantic matching (easy to split commands into meaningful tokens)
4. **Performance**: Only need to parse single commandline on request - not a concern

## Related Work

- `split-statements` in dotnu - similar but returns spans, not strings
- `query-from-history` in nu-history-tools - querying component already exists
- `ast --json` test cases - document pipeline structure
