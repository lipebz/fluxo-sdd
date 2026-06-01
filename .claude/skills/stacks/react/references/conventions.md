---
title: React — Conventions
stack: react
---

# React Conventions

## File and folder naming

| Item | Convention | Example |
|---|---|---|
| Component file | PascalCase, matches export | `UserCard.tsx` |
| Hook file | camelCase, starts with `use` | `useDebounce.ts` |
| Utility file | kebab-case or camelCase, consistent per project | `format-date.ts` or `formatDate.ts` |
| Test file | `*.test.tsx` or `*.spec.tsx` next to source | `UserCard.test.tsx` |
| Index/barrel | `index.ts(x)` only when exporting a public feature | `features/auth/index.ts` |

Match the dominant convention in the project — never mix `UserCard.tsx` with `user-card.tsx` in the same folder.

## Component file shape

```tsx
// imports — externals first, then internal, then relative
import { useState } from 'react';
import { z } from 'zod';
import { Button } from '@/shared/ui/Button';
import type { User } from '@/features/users/types';
import { formatDate } from './format-date';

// types — public props first, then internal helpers
type UserCardProps = {
  user: User;
  onEdit?: (id: User['id']) => void;
};

// helper types/constants if any
const MAX_NAME_LENGTH = 40;

// component
export function UserCard({ user, onEdit }: UserCardProps) {
  const [expanded, setExpanded] = useState(false);

  return (
    <article aria-label={`profile of ${user.name}`}>
      {/* ... */}
    </article>
  );
}

// sub-components only if tightly coupled — otherwise move to separate file
```

## Prop design

### Boolean explosion is a smell

```tsx
// ❌ 12 booleans
<Button primary secondary danger small large disabled loading rounded outlined ghost />

// ✅ enums/variants
<Button variant="primary" size="md" />
<Button variant="danger" size="lg" disabled loading />
```

When variants combine in non-orthogonal ways, use a discriminated union:

```tsx
type ButtonProps =
  | { variant: 'icon'; icon: ReactNode; label: string } // a11y label required
  | { variant: 'text'; children: ReactNode };
```

### Avoid prop-drilling more than 2 levels

If a prop is being threaded through 3+ component layers untouched, lift the state up to where both consumers can reach it, or use context for that subtree.

### Children vs render props vs slots

- **`children: ReactNode`** — the default. Use whenever the consumer just needs to put something inside.
- **Named slots** (props that are `ReactNode`) — when you have multiple "holes":
  ```tsx
  <PageLayout header={<Header />} sidebar={<Nav />} footer={<Footer />}>
    {content}
  </PageLayout>
  ```
- **Render props** — only when the consumer needs runtime data from the parent. Hooks have replaced 90% of these cases.

### Discourage `style` and `className` as escape hatches

For UI components, expose semantic props (`variant`, `size`, `state`), not raw styling. The `className` escape hatch invites inconsistency. If your design system gives an out for one-off cases, document it.

## Hook rules — the immutable ones

1. **Hooks only at the top level** of components or other hooks. Not in loops, conditions, or nested functions.
2. **Hooks only from React functions** (components or custom hooks). Not from regular JS.
3. **Custom hooks start with `use`** — both for the lint rule and reader expectation.

The eslint plugin `eslint-plugin-react-hooks` enforces these. Don't disable it.

## State conventions

### `useState` initialization

For expensive initial state, use the function form:

```tsx
// ❌ runs computeInitialState() on every render (result is ignored after first)
const [state, setState] = useState(computeInitialState());

// ✅ runs only once
const [state, setState] = useState(() => computeInitialState());
```

### Multiple related states → reducer or single object

```tsx
// ❌ easy to forget one when transitioning
const [isLoading, setIsLoading] = useState(false);
const [data, setData] = useState<User | null>(null);
const [error, setError] = useState<Error | null>(null);

// ✅
const [state, setState] = useState<
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'success'; data: User }
  | { kind: 'error'; error: Error }
>({ kind: 'idle' });
```

Or `useReducer` for state with non-trivial transitions.

### Derived state

If a value can be computed from existing state/props, compute it — don't store it.

```tsx
// ❌
const [items, setItems] = useState(initialItems);
const [count, setCount] = useState(initialItems.length);
// setItems + setCount must stay in sync — easy to forget

// ✅
const [items, setItems] = useState(initialItems);
const count = items.length;
```

For expensive derivations, `useMemo`. Cheap ones, compute inline every render.

## Effect conventions

### Cleanup is mandatory for subscriptions

```tsx
useEffect(() => {
  const id = setInterval(tick, 1000);
  return () => clearInterval(id); // ✅ cleanup
}, []);
```

Without cleanup, you leak.

### Dependency array tells the truth

Every value from component scope read in the effect must be in the deps. Linter (`react-hooks/exhaustive-deps`) enforces this. Don't disable it. If you're tempted, the effect probably shouldn't be an effect.

### Single concern per effect

```tsx
// ❌ two unrelated things
useEffect(() => {
  document.title = user.name;
  fetchPosts(user.id).then(setPosts);
}, [user]);

// ✅
useEffect(() => {
  document.title = user.name;
}, [user.name]);

useEffect(() => {
  fetchPosts(user.id).then(setPosts);
}, [user.id]);
```

Easier to reason about, narrower deps.

## Performance — memoization

Don't preemptively memoize. The cost (memory + comparison) often exceeds the benefit. Memoize when:

1. The expensive computation is **measured** to be slow.
2. The component renders **often** with the same inputs.
3. You're passing a prop to a `memo`'d child that re-renders on identity change.

```tsx
// ✅ legit — child is React.memo and we don't want to break referential equality
const handleClick = useCallback((id: string) => onSelect(id), [onSelect]);
```

React Compiler (RC) automates much of this — when available, lean on it instead of manual memoization.

## Imports — order

```tsx
// 1. React + framework
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';

// 2. External
import { z } from 'zod';
import { format } from 'date-fns';

// 3. Internal absolute
import { Button } from '@/shared/ui/Button';
import { useAuth } from '@/features/auth';

// 4. Relative
import { UserCardSkeleton } from './UserCardSkeleton';

// 5. Types (when separated)
import type { User } from '@/features/users/types';

// 6. Styles last
import styles from './UserCard.module.css';
```

`eslint-plugin-import` / `simple-import-sort` automate this. Configure once.

## Anti-patterns

- **Forwarding `...rest`** without typing. Either type it precisely or don't spread.
- **Inline styles for theming.** Use CSS variables, design tokens, or the styling solution. Inline style for truly dynamic values is fine (`style={{ left: x }}`).
- **`dangerouslySetInnerHTML`** — XSS magnet. If you absolutely must use it: sanitize the HTML with **DOMPurify** (`DOMPurify.sanitize(html)`) at the boundary, document the source of the HTML, and add a comment explaining why structured content (JSX, escaped markdown) wasn't enough. Prefer markdown libraries that escape by default (`react-markdown`, `marked` with sanitization on). Never pass user-provided HTML through `dangerouslySetInnerHTML` unsanitized.
- **Synchronizing state with props via effect.** `setState` in response to a prop change is almost always a sign of derived state. Compute it instead, or use `key` to reset.
- **Refs for state.** `useRef` is for things React doesn't need to re-render on. Reading a ref's `.current` in render is suspect.
- **`useEffect` for fetching.** Use a server state library. The "fetch in useEffect" pattern leaks races, breaks on Strict Mode double-render, has no caching, no retry, no SWR.
- **Mutating state directly.** `state.push(x); setState(state)` doesn't trigger a re-render. `setState([...state, x])`.
- **Returning `false` to skip render.** Return `null`.
