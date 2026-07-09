# AGENTS.md

llm-wiki is a pattern for building a personal knowledge base with an LLM agent. Instead of retrieving from raw documents at query time (RAG-style), the agent incrementally builds and maintains a persistent wiki — a structured, interlinked collection of markdown files in an Obsidian vault — that sits between you and your raw sources. When you add a source, the agent reads it, extracts the key information, and integrates it into the existing wiki: updating entity pages, revising summaries, flagging contradictions, strengthening the synthesis. The wiki is a persistent, compounding artifact that stays current because the agent does the maintenance no one wants to do by hand.

## Working in this repo

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## The five operations

- **wiki-capture** — file the current session's knowledge into the wiki (summary, enrichments, session log).
- **wiki-ingest** — process an external source (article, PDF, meeting notes) into the wiki, cross-referenced with existing knowledge.
- **wiki-query** — answer a natural-language question against the wiki with wikilink citations, optionally filing the answer back in.
- **wiki-lint** — health-check the wiki: orphans, broken wikilinks, stale TODOs, unprocessed inbox items, knowledge gaps.
- **wiki-configure** — set up or reconfigure the plugin for a vault: map folders to wiki roles, write the schema, wire the MCP server.

These are Agent Skills, auto-discovered from `.agents/skills/`. Any agent runtime that supports the Agent Skills convention picks them up automatically — no separate registration step.

## Per-agent notes

- **Claude Code** reads this file via `CLAUDE.md` (`@AGENTS.md` import).
- **Gemini CLI** reads this file via `GEMINI.md` (`@AGENTS.md` import).
- **Codex, OpenCode, Pi** read `AGENTS.md` natively — no shim needed.
- MCP server and hook wiring per agent live under `wiring/` — see that directory for setup instructions.
