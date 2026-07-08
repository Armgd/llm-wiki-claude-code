---
type: system
tags: [wiki, schema, system]
---

<!-- llm-wiki-template:v1 -->

# Wiki Schema

> System-agnostic contract for LLM wiki operations. Any LLM that can read markdown can follow this schema. Adapter skills (Claude Code, Codex, Gemini) implement the operations using their own tool layer.

## Vault Configuration

- vault_path: test-fixtures/vault
- wiki_source: claude-code
- inbox_threshold: 5
- io:
  - preference: auto
  - cli_path: ""
  - headless: false
  - qmd: false
- folders:
  - inbox: "00 - Inbox"              # required
  - projects: "01 - Projects"        # required
  - resources: "03 - Resources"      # required
  - system: "_System"            # required
  - areas: "02 - Areas"              # optional (empty string if unused)
  - notes: ""              # optional (empty string if unused)
- paths:
  - wiki_log: "_System/wiki-log.md"
  - templates: "_System/Templates"
  - archive_sources: "_System/Archive/Sources"

## Project Mapping

Session logs go under `{folders.projects}`. Sub-structure is free-form.
The following convention applies in this vault:

Flat: projects directly under 01 - Projects/.

Fuzzy matching rules the skill applies:
- CWD basename matches a folder name (case-insensitive)
- Git remote URL hints at client/org when present
- If no match → ask user, or file under `{folders.notes}` if configured, otherwise under `{folders.projects}/misc/`

## Page Types

### session-log

Captures decisions, findings, state, and next steps from an LLM session.

**Location**: `{folders.projects}/<sub-structure>/session-log-YYYY-MM-DD.md`

**Frontmatter**:

    ---
    type: session-log
    date: YYYY-MM-DD
    project: <project-name>
    tags: [<relevant-tags>]
    wiki-source: <wiki_source>
    ---

**Required sections**:
- `## Decisions` — architectural choices, library picks, trade-offs made
- `## Findings` — bugs found, patterns discovered, gotchas hit
- `## State` — current progress, what's done, what's blocked
- `## Next Steps` — actionable items for the next session, use `- [ ]` task syntax

**Guidance**: Write decisions and findings as if explaining to someone resuming the work tomorrow with no context. Link to knowledge pages with `[[wikilinks]]` for any pattern or concept worth remembering beyond this session.

### knowledge

Standalone reference for a pattern, technique, or concept that transcends a single session.

**Location**: `{folders.resources}/<domain>/<topic>.md`

**Frontmatter**:

    ---
    type: knowledge
    domain: <domain>
    tags: [<relevant-tags>]
    wiki-source: <wiki_source>
    wiki-confidence: high | medium | low
    sources: <count>
    ---

**Required sections**:
- Introductory paragraph — what this is and why it matters, in 2-3 sentences
- `## Key Patterns` — the core techniques or approaches
- `## Gotchas` — common mistakes, surprises, edge cases
- `## Related` — `[[wikilinks]]` to related knowledge pages, session logs, source summaries

**Guidance**: Knowledge pages should be self-contained. A reader should understand the topic without following links. Keep them focused — one concept per page. If a page grows beyond ~300 lines, split it.

### source-summary

Generated when ingesting an external source (article, PDF, meeting notes).

**Location**: `{folders.resources}/<domain>/<source-title> — Summary.md`

**Frontmatter**:

    ---
    type: source-summary
    source: <original-title>
    source-type: article | paper | video | podcast | meeting | book
    ingested: YYYY-MM-DD
    tags: [<relevant-tags>]
    wiki-source: <wiki_source>
    ---

**Required sections**:
- `## Key Claims` — the main arguments or findings, as bullet points
- `## Relevance` — how this connects to existing wiki knowledge, with `[[wikilinks]]`
- `## Contradictions` — if this source contradicts existing wiki content, note it explicitly
- `## Original` — link to the archived source: `[[{paths.archive_sources}/<filename>|Original]]`

**Guidance**: Summaries should be opinionated — highlight what matters for the vault owner's context, not just neutral bullet points. Flag contradictions with existing content explicitly.

### enrichment (inline, not a new page)

Appended to an existing note to add new information discovered during a session or ingestion.

**Format**: Obsidian callout block appended to the note:

    > [!claude] Added YYYY-MM-DD
    > Session: <context description>
    >
    > <content with [[wikilinks]]>

**Frontmatter update** on the enriched note:

    wiki-updated: YYYY-MM-DD
    wiki-updated-by: <wiki_source>

**Guidance**: Never modify the original author's content. Always append after a `---` horizontal rule. The callout makes enrichments visually distinct in Obsidian reading view.

## Wiki Log Format

`{paths.wiki_log}` is an append-only chronological record. Each entry uses a consistent heading format for parseability:

    ## [YYYY-MM-DD] <operation> | <subject>
    - <action>: [[link-to-affected-page]] (description)

Operations: `capture`, `ingest`, `query`, `lint`, `configure`.

## Operations

### capture

**When**: end of session (prompted by stop hook) or manual invocation.

**Confidence threshold**:
- **Auto-capture** (write directly): technical decisions, bug root causes + fix patterns, new patterns/techniques, session state summary
- **Prompt first** (ask before filing): enriching an existing user-authored note, creating knowledge in an ambiguous domain, cross-referencing across unrelated areas

**Flow**:
1. Read the session change manifest (if available from notification hook)
2. Review session context — identify decisions, findings, patterns, state
3. Search existing wiki for related pages (to cross-reference and avoid duplicates)
4. Write session log to `{folders.projects}/<sub-structure>/`
5. For each finding worth persisting: create or update a knowledge page in `{folders.resources}/`
6. For relevant existing notes: append enrichment with attribution callout
7. Update relevant MOCs under `{folders.areas}` (skip if areas is unset)
8. Append entry to wiki log

### ingest

**When**: explicit invocation with a source path.

**Flow**:
1. Read the source document
2. Identify key claims, arguments, and takeaways
3. Discuss findings with the user — get their take on what matters
4. Determine the domain and relevant existing pages
5. Write source summary page in `{folders.resources}/<domain>/`
6. Create or update knowledge pages for new concepts
7. Update relevant MOCs under `{folders.areas}` (skip if areas is unset)
8. Cross-reference with existing wiki content
9. Flag contradictions explicitly
10. Move original source to `{paths.archive_sources}/`
11. Append entry to wiki log

### query

**When**: explicit invocation with a natural language question.

**Flow**:
1. Search wiki: prefer qmd semantic search if available (io.qmd is true), fall back to Obsidian search or Grep for keyword/metadata queries
2. Read relevant pages (follow links for deeper context)
3. Synthesize answer with `[[wikilinks]]` as citations
4. Present answer to user
5. If the answer is substantial, offer to file it as a new knowledge page

### lint

**When**: explicit invocation (recommend weekly).

**Checks**:
- Contradictions between pages
- Stale claims superseded by newer sources
- Orphan pages (no inbound `[[wikilinks]]`)
- Concepts mentioned frequently (>3 pages) but lacking own page
- Missing cross-references between related pages
- Unprocessed items in `{folders.inbox}`
- Knowledge gaps worth investigating

**Output**: health report with counts and actionable suggestions.
With `--fix` flag: apply safe repairs (add cross-references, link orphans to MOCs).

## Frontmatter Fields Reference

Wiki-specific fields (added alongside existing vault conventions):

| Field | Type | On | Purpose |
|---|---|---|---|
| `wiki-source` | string | new pages | Which system created this page |
| `wiki-confidence` | `high\|medium\|low` | knowledge pages | How confident the LLM is in the content |
| `wiki-updated` | date | enriched pages | When the page was last enriched by an LLM |
| `wiki-updated-by` | string | enriched pages | Which system enriched the page |
| `domain` | string | knowledge, source-summary | Knowledge domain for PARA filing |
| `sources` | number | knowledge pages | How many sources inform this page |
| `source` | string | source-summary | Original source title |
| `source-type` | string | source-summary | Type of source material |
| `ingested` | date | source-summary | When the source was processed |
