---
title: Stack Skills
---

# Stack Skills

Each subfolder here is a **knowledge base** for one technology stack. A stack skill is what stops the AI agent from hallucinating: before writing code, the implementation commands (`/sdd-spec`, `/sdd-tasks`, `/sdd-run-all`, `/sdd-direct`, `/sdd-direct-close`) load the skill that matches the project's stack (as recorded by `/sdd-analyze` in the constitution).

## Layout of a stack skill

```
<stack>/
├── SKILL.md                  # frontmatter (name, version, description) + "when used" + golden rules + references index
└── references/
    ├── architecture.md       # project layout, layering, dependency direction
    ├── conventions.md        # naming, file shape, error handling, lint, anti-patterns
    └── testing.md            # test stack, patterns, what to test, anti-patterns
```

This is a deliberate "lean" set — 1 SKILL + 3 references per skill. The previous SDD generation tried 7 references per skill and most projects only used 3-4 of them in practice. The lean set covers ~90% of decisions; for anything else, the agent reads code or asks.

Some skills add specific extras when warranted (e.g., a `runes.md` for Svelte 5, an `eloquent.md` for Laravel deep dives). When this happens, the SKILL.md indexes them.

## Available curated stacks

| Stack | Type | Notes |
|---|---|---|
| `typescript` | transversal | TypeScript-the-language. Composes with frontend/backend skills. |
| `react` | frontend | React 18/19 + TS. Vite/Next router-agnostic. |
| `svelte` | frontend | Svelte 5 (runes) + SvelteKit. |
| `node-typescript` | backend | Express/Fastify/Nest + Prisma/Drizzle. |
| `php-laravel` | backend | Laravel 11+ with Action classes. |

## Status field

Each `SKILL.md` declares `status:` in its frontmatter:

- `curated` — written and maintained by humans. High signal-to-noise.
- `auto-generated` — produced by `/sdd-analyze` from web sources (doc + 2-3 guides). Useful but should be reviewed before heavy use.

When `/sdd-analyze` finds a stack without a curated skill, it falls back to web search and writes an `auto-generated` skill. Same shape, just less reviewed.

## Composing skills

Skills compose. A Laravel + React project loads both `php-laravel` and `react` (and `typescript` if the frontend is TS). They don't conflict — each owns its domain.

Order of precedence when guidance overlaps:
1. `docs/constitution.md` — project-specific rules win.
2. `docs/patterns/<stack>/` — what the team actually does.
3. The stack's `SKILL.md` and `references/`.

If the team's pattern contradicts the skill, the team's pattern wins. The skill is the universal default; the project is the specific truth.

## Adding a new curated stack

1. Copy the layout of the closest existing stack (`react` for frontend, `node-typescript` for backend).
2. Keep the file names. The tooling expects `SKILL.md` + `references/architecture.md` + `conventions.md` + `testing.md`.
3. Write the SKILL.md first — frontmatter, "When this is used", golden rules. That's the single-page summary the agent loads first.
4. Fill the references with content drawn from real production code, not blog posts.
5. Status: `curated`.
6. Update this README's table.

## Adding extra references

If a skill needs more than the three default references (e.g., a complex stack with specific subsystems), add files to `references/` and index them in `SKILL.md`. Don't bloat the defaults — extras only when warranted.

## When the agent should load a skill

- **Always** before generating code (`/sdd-spec`, `/sdd-tasks`, `/sdd-run-all`, `/sdd-direct`, `/sdd-direct-close`).
- The SKILL.md is always loaded; references are loaded selectively based on what the task touches (a HTTP-only task doesn't need to read `testing.md`).
- The constitution's `## Active Stacks` section tells the agent which skills are active in the current project.
