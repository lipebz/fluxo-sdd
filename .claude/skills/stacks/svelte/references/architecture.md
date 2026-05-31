---
title: Svelte / SvelteKit — Architecture
stack: svelte
---

# Svelte / SvelteKit Architecture

## Project layout (SvelteKit)

```
src/
├── routes/                    # file-based routing
│   ├── +layout.svelte
│   ├── +page.svelte           # /
│   ├── login/
│   │   ├── +page.svelte
│   │   └── +page.server.ts    # form actions, load (server-only)
│   └── users/
│       └── [id]/
│           ├── +page.svelte
│           ├── +page.ts       # universal load (client + server)
│           └── +server.ts     # API endpoint (GET /users/[id])
├── lib/                       # imports as $lib (alias)
│   ├── components/            # shared UI
│   ├── stores/                # app-wide state
│   ├── server/                # server-only code (cannot be imported from client)
│   └── utils/
├── hooks.server.ts            # request hooks (auth, logging)
├── hooks.client.ts            # client hooks (error handling)
├── app.html                   # HTML template
└── app.d.ts                   # TS app types (Locals, PageData, etc.)
```

## Routing

SvelteKit uses file-system routing. Each folder under `routes/` is a URL segment. Files with the `+` prefix have special meaning:

| File | Role |
|---|---|
| `+page.svelte` | The page component |
| `+page.ts` | Universal load function (runs client + server) |
| `+page.server.ts` | Server-only load + form actions |
| `+layout.svelte` | Wraps child pages |
| `+layout.ts` / `+layout.server.ts` | Load for layout |
| `+server.ts` | API endpoint (HTTP verbs as named exports) |
| `+error.svelte` | Error UI for this route subtree |

Dynamic segments: `[id]` → `params.id`. Catch-all: `[...rest]`. Optional: `[[id]]`. Matchers: `[id=integer]` paired with `src/params/integer.ts`.

## Load functions

Load functions fetch data **before** the page renders.

### Universal (`+page.ts`)

Runs on the server during SSR, then on the client on navigation:

```ts
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, params }) => {
  const res = await fetch(`/api/users/${params.id}`);
  return { user: await res.json() };
};
```

Use `fetch` from the event — it's a tracked version that:
- Works on server (no full URLs needed).
- Inlines server-side requests during SSR (no double round trip).

### Server (`+page.server.ts`)

Runs only on the server. Can use server-only resources (DB, secrets, FS):

```ts
import type { PageServerLoad } from './$types';
import { db } from '$lib/server/db';

export const load: PageServerLoad = async ({ params, locals }) => {
  if (!locals.user) throw redirect(303, '/login');
  return { user: await db.user.findUnique({ where: { id: params.id } }) };
};
```

Choose **server load** when you need DB/secrets. Choose **universal load** when you want client-side navigation to skip the server round trip.

### Don't fetch in components when load can do it

```svelte
<!-- ❌ runs after the page renders, causes flash -->
<script>
  import { onMount } from 'svelte';
  let user = $state(null);
  onMount(async () => {
    user = await (await fetch(`/api/users/1`)).json();
  });
</script>

<!-- ✅ data is there on first render -->
<script>
  let { data } = $props();
</script>
<p>{data.user.name}</p>
```

## Form actions (`+page.server.ts`)

Mutations via progressive-enhanced forms:

```ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
  default: async ({ request, locals }) => {
    const data = await request.formData();
    const name = data.get('name');
    if (typeof name !== 'string' || !name) {
      return fail(400, { name, error: 'name required' });
    }
    await locals.db.user.update({ where: { id: locals.user.id }, data: { name } });
    throw redirect(303, '/profile');
  }
};
```

```svelte
<script>
  import { enhance } from '$app/forms';
  let { form } = $props(); // ActionData
</script>

<form method="POST" use:enhance>
  <input name="name" value={form?.name ?? ''} />
  {#if form?.error}<p class="error">{form.error}</p>{/if}
  <button>Save</button>
</form>
```

`use:enhance` progressively enhances the form — works without JS, but with JS gives the SPA experience. **Default for mutations** in SvelteKit.

Multiple named actions:

```ts
export const actions: Actions = {
  login: async (event) => { /* ... */ },
  signup: async (event) => { /* ... */ }
};
```

```svelte
<form method="POST" action="?/login">…</form>
<form method="POST" action="?/signup">…</form>
```

## Remote functions (`$app/server`) — SvelteKit moderno

Versões recentes do SvelteKit oferecem **remote functions**: funções server-side type-safe chamáveis direto do cliente, sem escrever um endpoint `+server.ts` à mão. São o padrão emergente para acesso a dados em apps SvelteKit modernos — quando o projeto as usa, elas substituem boa parte das load functions e form actions para dados.

Arquivos `*.remote.ts` exportam funções criadas com helpers de `$app/server`:

- **`query`** — leitura. Cacheável, revalidável (`.refresh()`), chamável de componentes.
- **`command`** — mutação imperativa (deletar, atualizar em massa).
- **`form`** — mutação ligada a um `<form>`, com progressive enhancement.

```ts
// src/lib/remote/todo.remote.ts
import { query, command, form } from '$app/server';
import * as v from 'valibot';
import { db } from '$lib/server/db';

const getTodosSchema = v.object({ organizationSlug: v.string() });

export const getTodos = query(getTodosSchema, async ({ organizationSlug }) => {
  // valida entrada (1º arg = schema), roda no servidor, retorna dados tipados
  return db.selectFrom('todo').selectAll()./* ...scope by org... */execute();
});

export const deleteTodo = command(deleteSchema, async ({ id }) => {
  await db.deleteFrom('todo').where('id', '=', id).execute();
  await getTodos({ organizationSlug }).refresh(); // revalida a query
});
```

No componente:

```svelte
<script>
  import { getTodos, deleteTodo } from '$lib/remote/todo.remote';
  const todos = await getTodos({ organizationSlug });
</script>
```

Convenções típicas (confirme nos patterns do projeto):
- 1º argumento sempre um schema de validação (zod/valibot) — validação no boundary.
- Resolva contexto/tenant/auth no início da função (server-side).
- `command`/`form` chamam `.refresh()` nas queries afetadas para revalidar o cache.

> **Quando o projeto usa remote functions**, elas — não load/form actions — são a camada de dados primária. Os patterns extraídos por `/sdd-analyze` em `docs/patterns/svelte/` são a autoridade sobre a convenção exata; este texto é o conceito geral. Como é um recurso que evolui rápido, **confirme a API no projeto e na doc oficial do SvelteKit** antes de assumir assinaturas.

## Server-only code isolation

`$lib/server/*` cannot be imported by client code — Vite throws at build. Use this convention to ensure secrets and DB don't leak.

```
src/lib/server/
  db.ts           # ✅ DB client, never reaches the browser
  auth.ts
```

Anything in `src/lib/` that isn't under `server/` is shipped to the client. Be careful.

## Hooks

`src/hooks.server.ts` runs for every request. Common uses:

```ts
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // attach user to locals
  event.locals.user = await getUserFromCookie(event.cookies);
  return resolve(event);
};
```

For multiple concerns, compose with `sequence`:

```ts
import { sequence } from '@sveltejs/kit/hooks';
export const handle = sequence(authHandle, logHandle, cspHandle);
```

`src/hooks.client.ts` for client error handling and similar.

## Stores vs runes (Svelte 5)

### Runes for component/route state

```svelte
<script>
  let count = $state(0);
  let doubled = $derived(count * 2);
  $effect(() => {
    document.title = `count: ${count}`;
  });
</script>
```

### Stores for app-wide state

Two options in Svelte 5:

#### Classic stores
```ts
// src/lib/stores/theme.ts
import { writable } from 'svelte/store';
export const theme = writable<'light' | 'dark'>('light');
```

```svelte
<script>
  import { theme } from '$lib/stores/theme';
</script>
<button onclick={() => $theme = $theme === 'light' ? 'dark' : 'light'}>
  Theme: {$theme}
</button>
```

#### Rune-based shared state (`.svelte.ts` module)
```ts
// src/lib/stores/theme.svelte.ts
export const theme = $state({ value: 'light' as 'light' | 'dark' });
```

```svelte
<script>
  import { theme } from '$lib/stores/theme.svelte';
</script>
<button onclick={() => theme.value = theme.value === 'light' ? 'dark' : 'light'}>
  Theme: {theme.value}
</button>
```

The `.svelte.ts` extension is required for runes outside components.

Pick one per project. Don't mix.

## Adapters

`svelte.config.js` declares the adapter — this determines runtime:

- `@sveltejs/adapter-node` — Node server.
- `@sveltejs/adapter-vercel` — Vercel.
- `@sveltejs/adapter-cloudflare` — Cloudflare Pages/Workers (limited Node APIs).
- `@sveltejs/adapter-static` — pre-rendered static files (no server).

The adapter affects what server-side code can do (e.g., no FS on Cloudflare Workers). Check before assuming.

## Error handling

`+error.svelte` files create error boundaries per route subtree:

```svelte
<script>
  import { page } from '$app/state';
</script>
<h1>{page.status}: {page.error?.message}</h1>
```

Use `error()` from `@sveltejs/kit` in load/actions:

```ts
import { error } from '@sveltejs/kit';
if (!user) throw error(404, 'user not found');
```

These render the nearest `+error.svelte`. For programmer errors, throw — they're caught and logged via `hooks.server.handleError`.
