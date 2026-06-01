---
title: TypeScript — Architecture
stack: typescript
---

# TypeScript Architecture

## Module boundaries

A TypeScript module exports two things: **values** (functions, classes, constants) and **types** (interfaces, type aliases, enums). Treat them as separate surfaces:

- `export type { Foo }` — type-only export. Erased at runtime. Use for DTOs, function signatures, contracts.
- `export { foo }` — value export. Present at runtime.
- `export { type Foo, bar }` — mixed. Acceptable but less explicit.

**Rule:** never re-export everything (`export *`). It hides what's public, makes refactoring dangerous, and breaks tree-shaking in bundlers. Always enumerate exports.

## Type design

### Prefer types over interfaces (for app code)

Interfaces and type aliases mostly overlap. Pick one and stick with it. Common convention:
- `type` for app code (composes better, supports unions, mapped types, conditional types).
- `interface` for declaration merging when integrating with libraries that expect it.

If your team already uses one consistently, follow that. Don't mix without reason.

### Discriminated unions

Model state machines and variants as discriminated unions:

```ts
type RequestState =
  | { kind: 'idle' }
  | { kind: 'loading' }
  | { kind: 'success'; data: User }
  | { kind: 'error'; error: ApiError };
```

Narrow with `switch (state.kind)` — exhaustiveness check via `never`:

```ts
function render(state: RequestState) {
  switch (state.kind) {
    case 'idle': return 'click to load';
    case 'loading': return 'loading…';
    case 'success': return state.data.name;
    case 'error': return state.error.message;
    default: {
      const _exhaustive: never = state;
      throw new Error(`unhandled: ${_exhaustive}`);
    }
  }
}
```

The `_exhaustive: never` line is critical — it makes the compiler complain when you add a new variant and forget to handle it.

### Branded types

Primitives like `string` and `number` carry no semantic meaning. Brand them when meaning matters:

```ts
type UserId = string & { readonly __brand: 'UserId' };
type OrderId = string & { readonly __brand: 'OrderId' };

function asUserId(s: string): UserId {
  return s as UserId; // single chokepoint where assertion lives
}

function getUser(id: UserId) { /* ... */ }

getUser('123'); // ❌ Type 'string' is not assignable to type 'UserId'
getUser(asUserId('123')); // ✅
```

Without brands, `getUser(orderId)` compiles. With brands, it doesn't. Cheap defense, huge payoff.

### Generics — keep them concrete

Generics are most useful at library/utility boundaries. In application code, prefer concrete types.

❌ Don't:
```ts
function fetchEntity<T>(url: string): Promise<T> { /* ... */ }
const user = await fetchEntity<User>('/users/1');
```
This lies — the function doesn't validate that the response actually matches `T`.

✅ Do:
```ts
async function fetchUser(id: UserId): Promise<User> {
  const res = await fetch(`/users/${id}`);
  return UserSchema.parse(await res.json()); // runtime validation
}
```

If you need a generic fetch helper, make the schema explicit:
```ts
async function fetchAndParse<T>(url: string, schema: ZodType<T>): Promise<T> {
  return schema.parse(await (await fetch(url)).json());
}
```

## Narrowing strategies

### `in` operator for shape checks

```ts
type Animal = { name: string; bark?: () => void } | { name: string; meow?: () => void };
if ('bark' in animal) animal.bark?.();
```

### Custom type guards for complex shapes

```ts
function isUser(x: unknown): x is User {
  return typeof x === 'object' && x !== null
    && 'id' in x && 'email' in x;
}
```

Better: use a schema validator (`zod`, `valibot`) and let it own the guard.

### Assertion functions for invariants

```ts
function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(msg);
}

assert(user.email, 'user must have an email at this point');
// from here on, user.email is narrowed to string (not string | undefined)
```

## Anti-patterns

- **`any` as documentation.** "I'll type this later." You won't. Use `unknown` instead — it forces you to narrow.
- **Type assertion as a fix.** `as Foo` should require an ADR or comment. If you reach for it, ask: why doesn't the compiler see what I see?
- **`as const` overuse.** Powerful for literal tuples and configs, but overusing leads to types that are too narrow to be useful.
- **Enum overuse.** Prefer string literal unions: `type Status = 'pending' | 'active' | 'closed'`. Enums add runtime overhead and surprise with reverse mappings.
- **Deep generic gymnastics.** If your type takes more than 2 generic parameters, ask whether a regular function with concrete types would do.

## Project structure

For TypeScript, the structure is owned by the runtime skill (`react`, `svelte`, `node-typescript`). This skill only enforces:

- `src/` contains source, never built artifacts.
- `dist/`, `build/`, `out/` are gitignored and never imported from `src/`.
- Path aliases (`@/`) are configured in `tsconfig.json` AND the bundler/runtime (vite, tsc, ts-node). One without the other breaks.
- One barrel (`index.ts`) per public module if barrels are used; never barrel everything (kills tree-shaking).
