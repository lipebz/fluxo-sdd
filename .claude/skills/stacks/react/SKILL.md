---
name: react
version: 1.0.0
status: curated
description: Activate when implementing, fixing, refactoring, or reviewing React code — components, hooks, state management, data fetching, routing, performance, accessibility. Covers React 18/19 with TypeScript, Vite, and Next.js App Router patterns. Do not use for non-React frontends (Svelte, Vue, vanilla JS).
---

# React Implementation

## When this is used

Use this skill any time the task touches a React frontend: building a component, wiring a hook, fetching data, managing client/server state, handling routing, optimizing renders, fixing a11y issues, or organizing the component tree.

If the project is TypeScript-based, load `typescript` alongside this skill — they compose: `react` covers component patterns and runtime, `typescript` covers the language.

## References

Load only what the task needs.

- `references/architecture.md` — project layout, component hierarchy, server vs client components (Next), folder conventions, data flow.
- `references/conventions.md` — naming, file organization, prop design, hook rules, imports, lint config.
- `references/testing.md` — React Testing Library patterns, component tests, user-event, mocking fetch/router, accessibility queries.

## Golden rules

- Components are functions. No classes. Hooks for state and effects.
- Composition over configuration. A component with 12 boolean props is a sign you need multiple components or `children`.
- One source of truth for each piece of state. Don't sync local state with props — derive instead, or lift state up.
- Effects are for synchronizing with external systems. Don't use `useEffect` for things that happen *because of an event* — handle them in the event handler.
- Keys must be stable and unique among siblings. Never use the array index as key when items can reorder/insert.
- Server state ≠ client state. Use a server-state library (TanStack Query, SWR, RTK Query, Next.js server components) for data fetched from APIs. Don't roll your own with `useState + useEffect`.
- Lifting state up before reaching for context. Context is for *truly* global state (theme, auth, locale). Most "shared state" should live in a common parent.
- Memoization is a last-resort optimization. Don't preemptively wrap everything in `useMemo`/`useCallback`/`memo` — measure first.
- Accessibility is non-negotiable. Semantic HTML first, then ARIA only when semantic HTML can't express the intent. Keyboard navigation must work.
- Read `package.json` to know your React version, router (`react-router`/`next`/`@tanstack/router`), styling solution (CSS modules, Tailwind, styled-components), and state library before writing anything.

## When to break a rule

- Use a class component for an error boundary (no hook equivalent yet, though React 19 is changing this).
- Use `useEffect` for "do X when mounted" — that's a synchronization with the lifecycle, valid.
- Use index as key for static, never-reordered lists (rare; usually a smell).

If you break a rule, leave a comment explaining why.
