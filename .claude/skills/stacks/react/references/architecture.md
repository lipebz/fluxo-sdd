---
title: React — Architecture
stack: react
---

# React Architecture

## Folder layout

Two common shapes work — pick one per project and stick with it.

### Layout A — feature-first (preferred for medium+ apps)

```
src/
├── features/
│   ├── auth/
│   │   ├── components/        # AuthForm, LoginButton
│   │   ├── hooks/             # useAuth, useSession
│   │   ├── api/               # auth-api.ts
│   │   ├── types.ts
│   │   └── index.ts           # public exports
│   └── orders/
│       ├── components/
│       ├── hooks/
│       └── ...
├── shared/
│   ├── ui/                    # Button, Input, Modal — generic UI primitives
│   ├── lib/                   # helpers, formatters
│   └── hooks/                 # cross-feature hooks
├── routes/ or pages/          # routing layer
└── app.tsx
```

A feature owns its components, hooks, API calls, and types. Cross-feature reuse goes through `shared/`. Other features import only from `features/<name>/index.ts` (the barrel) — never from internals.

### Layout B — type-first (works for small apps)

```
src/
├── components/
├── hooks/
├── api/
├── pages/
└── app.tsx
```

Fine until you hit ~30 components. After that, finding things becomes painful and feature-first scales better.

## Routing layer

- **React Router** — declarative or data routers (v6.4+). Data routers + loaders give SSR-like data fetching client-side.
- **TanStack Router** — file-based or programmatic, type-safe routes, strong loader story.
- **Next.js App Router** — file-system routing, server components by default.

For a new SPA, TanStack Router is the most type-safe choice. For SSR/SSG, Next App Router. For "I just need a router", React Router.

## Next.js — server vs client components

If on Next.js App Router, the most important architectural decision is **server vs client**:

- **Server Components (default)** — render on server. Can `async`/`await`. Can read DB/files directly. **Cannot** use `useState`, `useEffect`, browser APIs, event handlers.
- **Client Components** (`'use client'` directive at top of file) — hydrate on client. Can use hooks and event handlers. **Cannot** be `async` (use hooks for data).

Rules of thumb:
- Default to server. Add `'use client'` only at the leaf that needs interactivity.
- Pass data from server to client via props. Don't fetch in client when server can.
- The `'use client'` boundary cascades — once you cross it, everything imported transitively becomes client.

## Component hierarchy

### Component sizes

A component should fit on one screen (~100 lines tops, often much less). If it grows beyond that:
- Extract sub-components for distinct visual sections.
- Extract custom hooks for reusable behavior.
- Extract pure helpers to `lib/`.

### Container vs presentation (modern take)

The old "container/presentational" split is mostly dead — components do both fine now. What survives is:

- **Data-aware components** at the top of a tree (page-level, route-level): fetch data, manage URL state, orchestrate.
- **Reusable UI primitives** at the bottom: no data fetching, props-only, pure rendering.

The middle is fuzzy — let it be.

### Composition patterns

#### Slot pattern (children)

```tsx
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Body>Content</Card.Body>
</Card>
```

vs:

```tsx
<Card title="Title" body="Content" /> // ❌ rigid
```

Use composition when consumers need flexibility about what goes inside.

#### Render props (rare, mostly replaced by hooks)

Still useful when you need to share *imperative* behavior with rendering. Most cases now use hooks.

#### Compound components

Components that work together via context:

```tsx
<Tabs defaultValue="one">
  <Tabs.List>
    <Tabs.Trigger value="one">One</Tabs.Trigger>
    <Tabs.Trigger value="two">Two</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Content value="one">…</Tabs.Content>
  <Tabs.Content value="two">…</Tabs.Content>
</Tabs>
```

Pattern of choice for design systems (Radix, Headless UI).

## Data flow

### Client state

- **Local UI state** (input value, modal open/closed) → `useState`.
- **Cross-component within a feature** → lift to common parent or feature-level context.
- **Cross-feature / app-wide** → context, or a state library (Zustand for simple, Redux Toolkit for complex with devtools, Jotai/Recoil for atom-based).

### Server state

**Use a library.** Don't build your own with `useEffect`. Libraries solve:
- Caching
- Background revalidation
- Stale-while-revalidate
- Deduplication
- Optimistic updates
- Pagination

Choose:
- **TanStack Query** — works everywhere, framework-agnostic. Default choice.
- **SWR** — simpler, Vercel's. Great for Next.
- **RTK Query** — if you're already on Redux Toolkit.
- **Next.js Server Components + fetch** — simplest if you can use the server.

### URL state

URL is shared state. Use it for:
- Filters, sorts, pagination on list views.
- Selected item in a master-detail.
- Modal open/closed (so refreshes preserve, deep-links work).

Tools: `useSearchParams` (React Router / Next), `nuqs`, TanStack Router's typed search params.

### Form state

- **Simple form** (login, settings) — `useState` + uncontrolled inputs is fine.
- **Complex form** (multi-step, validation, dynamic fields) — React Hook Form or TanStack Form.
- **Schema-first validation** — Zod/Valibot integrated with the form library.

## Effects — what they're for and what they're not

`useEffect` synchronizes with **external systems**:
- Subscribe/unsubscribe (event listener, WebSocket).
- Sync data to/from non-React state (localStorage, URL, third-party widget).

`useEffect` is **NOT** for:
- Reacting to props/state changes that should compute a derived value → compute in render.
- Fetching data → use a server state library or server component.
- "Running this when X happens" where X is an event → handle in the event handler.

The "you might not need an effect" article from React docs is required reading.

## Error boundaries

Error boundaries catch render-phase errors. They're the only React feature that still requires a class component (until React 19's `react-error-boundary` lib or built-in).

Place them:
- At the route level (so a page error doesn't break the whole app).
- Around third-party widgets that can crash.
- Around isolated features (a broken comments widget shouldn't break the article).

Don't wrap everything — too many boundaries swallow errors that would help in dev.

## Suspense

React 18+ Suspense boundaries declaratively handle loading states:

```tsx
<Suspense fallback={<Spinner />}>
  <UserProfile id="123" />
</Suspense>
```

Works with:
- React.lazy() for code-splitting.
- Server state libraries that support it (TanStack Query with `suspense: true`).
- Next.js server components with async data.

Pair with error boundaries — Suspense handles loading, boundaries handle errors.
