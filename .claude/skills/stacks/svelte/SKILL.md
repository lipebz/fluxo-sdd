---
name: svelte
version: 1.0.0
status: curated
description: Activate when implementing, fixing, refactoring, or reviewing Svelte/SvelteKit code — components, runes (Svelte 5), stores, load functions, form actions, routing, transitions. Covers Svelte 5 (runes) and SvelteKit. Do not use for React/Vue/vanilla — use the matching skill.
---

# Svelte / SvelteKit Implementation

## When this is used

Use this skill any time the task touches a Svelte 5 component (`*.svelte`), a SvelteKit route (`+page`, `+layout`, `+server`), a load function, a form action, or a store/rune. If the project uses TypeScript (most do), load `typescript` alongside.

## References

Load only what the task needs.

- `references/architecture.md` — SvelteKit project layout, routes, load functions, server vs client, form actions, hooks.
- `references/conventions.md` — Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`), component shape, naming, imports, styling.
- `references/testing.md` — Vitest + `@testing-library/svelte`, Playwright for E2E, mocking SvelteKit modules.

## Golden rules

- **Svelte 5 = runes.** `$state`, `$derived`, `$effect`, `$props`, `$bindable` replace the magic of `let` reactivity. If the project is Svelte 5, use runes. If Svelte 4 (legacy), use the old reactivity (`$:`, plain `let`).
- **One source of truth per piece of state.** Don't sync rune state with props — derive with `$derived` or accept the prop directly via `$props`.
- **`$effect` synchronizes with external systems.** Not for derived values (use `$derived`). Not for "do X when Y changes" if Y change is from an event — handle in the event.
- **SvelteKit load functions run on server first, then client.** They run in both unless you opt out (`export const ssr = false`). Don't put browser APIs in `load` without guards.
- **Server vs client boundary is the `+server.ts` / `+page.server.ts` files.** Server code never ships to client. Don't import server-only code from a `+page.svelte`.
- **Use form actions for mutations** (clássico) **ou remote functions** (`$app/server`: `query`/`command`/`form`) se o projeto as adota. Remote functions são o padrão moderno de acesso a dados type-safe — quando presentes (`src/lib/remote/*.remote.ts`), são a camada primária, substituindo load+actions para dados. Em ambos: validação server-side, progressive enhancement. Não use fetch client-side quando action/remote resolve. Confira os patterns do projeto pra saber qual convenção ele segue.
- **Stores are global, runes are local.** Use `writable`/`readable` stores for app-wide state (auth, theme), runes for component/route state. Svelte 5 has `$state` outside `.svelte.ts/.svelte.js` files — that replaces simple stores in many cases.
- **Transitions and animations are first-class.** Use `transition:`, `in:`, `out:`, `animate:` directives. Don't reinvent with CSS classes + JS.
- **`{#each}` keys are mandatory** when items reorder/insert/delete. Use a stable id, never the index.
- **Read `package.json` and `svelte.config.js`** before writing — Svelte 4 vs 5 changes idioms, SvelteKit adapter affects what's possible (static? node? cloudflare? vercel?).

## When to break a rule

- `$effect` for derived state is acceptable when the derivation has side effects (logging, syncing to localStorage). Pure derivations → `$derived`.
- Svelte 4 codebases obviously use the old idioms — don't introduce runes piecemeal, migrate the whole component.
- `<script context="module">` (Svelte 4) → `*.svelte.ts` modules (Svelte 5) for shared module-level code.
