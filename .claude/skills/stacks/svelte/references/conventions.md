---
title: Svelte / SvelteKit — Conventions
stack: svelte
---

# Svelte / SvelteKit Conventions

## File naming

| Item | Convention | Example |
|---|---|---|
| Component | PascalCase | `UserCard.svelte` |
| Shared store/module | kebab-case | `auth-store.ts`, `theme.svelte.ts` |
| Route files | `+page.svelte`, `+layout.svelte`, `+page.server.ts`, `+server.ts` | (literal, set by SvelteKit) |
| Test file | `*.test.ts` next to source | `UserCard.test.ts` |

## Component file shape (Svelte 5)

```svelte
<script lang="ts">
  // 1. external imports
  import { onMount } from 'svelte';
  import { z } from 'zod';

  // 2. internal imports
  import Button from '$lib/components/Button.svelte';
  import type { User } from '$lib/types';

  // 3. props (Svelte 5 rune)
  let { user, onEdit }: { user: User; onEdit?: (id: string) => void } = $props();

  // 4. local state
  let expanded = $state(false);

  // 5. derived
  let displayName = $derived(user.name.length > 40 ? user.name.slice(0, 40) + '…' : user.name);

  // 6. effects (only for syncing with external systems)
  $effect(() => {
    document.title = displayName;
  });

  // 7. handlers
  function handleEdit() {
    onEdit?.(user.id);
  }
</script>

<article aria-label="profile of {user.name}">
  <h2>{displayName}</h2>
  <button onclick={handleEdit}>Edit</button>
</article>

<style>
  article {
    /* scoped by default */
  }
</style>
```

The `<style>` block is component-scoped by default — class names are mangled. Use `:global(.foo)` only when integrating with third-party CSS.

## Runes (Svelte 5) — the four you'll use most

### `$state` — reactive variable

```svelte
let count = $state(0);
let items = $state<string[]>([]);
items.push('hello'); // ✅ deep reactivity for arrays/objects (in deep mode)
```

`$state` makes deep reactivity work for objects and arrays — mutations are tracked. For primitives, it's similar to `let` in Svelte 4.

For raw, non-reactive state (refs, dom nodes), use plain `let`.

### `$derived` — pure computation from other state

```svelte
let count = $state(0);
let doubled = $derived(count * 2);
let summary = $derived.by(() => {
  // for multi-statement derivations
  const lower = items.filter(i => i < 0);
  const upper = items.filter(i => i > 0);
  return { lower: lower.length, upper: upper.length };
});
```

Pure. No side effects. If you need side effects on change, use `$effect`.

### `$effect` — sync with external system

```svelte
$effect(() => {
  document.title = `count: ${count}`;  // side effect
  return () => { /* cleanup on re-run / destroy */ };
});
```

Runs after render, re-runs when accessed reactive values change.

**Not** for derived state. **Not** for "on every click" (that's an event handler).

### `$props` — component inputs

```svelte
let { user, onEdit, class: className = '' }: Props = $props();
```

Destructure with defaults. Forward bindable props with `$bindable`:

```svelte
let { value = $bindable() }: { value: string } = $props();
```

Now the parent can `bind:value={...}` and child updates propagate up.

## Imports

### `$lib` alias

`$lib` resolves to `src/lib/`. Use it for everything in `src/lib/`:

```ts
import Button from '$lib/components/Button.svelte';
import { auth } from '$lib/stores/auth';
```

### `$app/*` for framework

```ts
import { page } from '$app/state';        // current page info (Svelte 5)
import { goto } from '$app/navigation';   // programmatic navigation
import { browser } from '$app/environment'; // SSR vs CSR check
import { enhance } from '$app/forms';     // form progressive enhancement
```

### Server-only imports

```ts
import { db } from '$lib/server/db'; // ✅ only allowed in +page.server.ts, +server.ts, hooks.server.ts
```

If you try to import `$lib/server/*` from a `.svelte` file or `+page.ts`, Vite throws. That's by design.

## Naming conventions

| Context | Convention | Example |
|---|---|---|
| Variables, functions | camelCase | `currentUser`, `formatDate` |
| Component | PascalCase | `UserCard.svelte` |
| Store | camelCase, often `*Store` suffix or just the noun | `theme`, `authStore` |
| Types/interfaces | PascalCase | `User`, `ApiError` |
| Constants (module-level) | UPPER_SNAKE_CASE | `MAX_RETRIES` |
| Event handler props | `on<Event>` | `onClick`, `onSubmit`, `onUserChange` |

In Svelte 5, prefer `onclick` (lowercase, DOM-native) over `on:click` (Svelte 4 syntax) in templates. The custom event handler convention (`onUserChange`) for component props is camelCase with `on` prefix.

## Conditional and list rendering

```svelte
{#if user}
  <p>hello {user.name}</p>
{:else if loading}
  <p>loading…</p>
{:else}
  <p>not logged in</p>
{/if}

{#each items as item (item.id)}     <!-- key is required for reordering -->
  <li>{item.name}</li>
{:else}
  <li>no items</li>
{/each}

{#await promise}
  <p>loading…</p>
{:then value}
  <p>{value}</p>
{:catch error}
  <p>error: {error.message}</p>
{/await}
```

The `(item.id)` key in `{#each}` is mandatory for any list that can mutate. Without it, Svelte falls back to index-based reconciliation and breaks.

## Bindings

```svelte
<input bind:value={name} />               <!-- two-way -->
<input type="checkbox" bind:checked={agreed} />
<select bind:value={selected}>...</select>
<div bind:this={el} />                    <!-- ref to DOM node -->
<Child bind:value />                      <!-- two-way to child prop (child must use $bindable) -->
```

Two-way binding is fine in Svelte (unlike React's one-way preference). Use it where it makes the code clearer; avoid when the parent needs to react to changes with logic (use `oninput` instead).

## Transitions and animations

Built-in directives:

```svelte
<script>
  import { fade, slide, fly } from 'svelte/transition';
</script>

{#if visible}
  <div transition:fade>fades in and out</div>
  <div in:slide out:fly={{ y: 200 }}>different in/out</div>
{/if}
```

For lists, `animate:flip` from `svelte/animate` handles reordering smoothly:

```svelte
{#each items as item (item.id)}
  <li animate:flip>{item.name}</li>
{/each}
```

Prefer these over CSS classes + JS for simple cases. They handle "during transition" interruptions correctly.

## CSS

- Scoped by default — `<style>` in a component scopes its selectors.
- `:global(.foo)` to escape scoping (use rarely, for resets and third-party).
- CSS variables for theming — defined at `:root` or component level.
- Tailwind works fine if you want — it composes with scoped styles.

## Anti-patterns

- **Mixing Svelte 4 reactivity (`$:`, plain `let`) with runes in a Svelte 5 project.** Pick one. Migrate the file fully when you touch it.
- **`$effect` for derived values.** Use `$derived`. Effects run after the DOM updates and add a reactivity cycle.
- **Mutating `$props()` values inside the child.** Props are read-only unless declared `$bindable`. Mutate a child copy or use `$bindable`.
- **Browser APIs in `+page.ts` load** without `if (browser)` guard. The load runs server-side too — `window`/`document`/`localStorage` will crash.
- **Skipping `(item.id)` in `{#each}`** for lists that change. Causes visual glitches and key reuse bugs.
- **Server-only imports from `.svelte` files.** Vite blocks them, but the error is sometimes confusing — keep server code in `+*.server.ts` or `$lib/server/`.
- **`use:enhance` without a fallback action.** The form should work without JS — that's the whole point of progressive enhancement.
