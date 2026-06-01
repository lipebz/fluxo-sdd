---
title: TypeScript — Conventions
stack: typescript
---

# TypeScript Conventions

## tsconfig — non-negotiable

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  }
}
```

- `strict: true` enables `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes`, and friends. Never disable.
- `noUncheckedIndexedAccess: true` — `arr[i]` becomes `T | undefined`. Forces you to handle out-of-bounds.
- `exactOptionalPropertyTypes: true` — `{ x?: number }` no longer accepts `{ x: undefined }`. Tighter and more honest.

Other options are runtime-dependent (`target`, `module`, `moduleResolution`). Let the stack skill decide those.

## Naming

| Context | Convention | Example |
|---|---|---|
| Variables, functions | camelCase | `getUserById`, `userCount` |
| Types, interfaces, classes | PascalCase | `User`, `OrderRepository` |
| Type parameters (generics) | Single uppercase letter or PascalCase prefixed `T` | `T`, `TItem`, `TError` |
| Constants (module-level, frozen) | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT_MS` |
| Files (source) | match dominant export | `UserRepository.ts` or `user-repository.ts` — pick one per project |
| Files (tests) | `*.test.ts` or `*.spec.ts` | `UserRepository.test.ts` |

**Don't prefix interfaces with `I`** (`IUser`). It's a C# convention that doesn't translate. Same for `T` prefix on types — only use for generic parameters.

## Imports

### Order

1. External packages (`react`, `zod`, ...)
2. Internal absolute (`@/lib/...`, `~/services/...`)
3. Relative (`./foo`, `../bar`)
4. Type-only imports (when grouped separately, last)

Most linters (`eslint-plugin-import`, `simple-import-sort`) automate this. Configure once.

### Type-only

When importing only types, use `import type`:

```ts
import type { User } from './user';
import { fetchUser } from './user-api';
```

It signals intent and helps bundlers strip the import at build time. With `verbatimModuleSyntax: true` in `tsconfig`, this becomes mandatory.

### No default exports for libraries

For application code, default exports are fine when the file has one obvious thing. For shared libraries/utilities, prefer named exports — they refactor better and force consistent naming at call sites.

## Null and undefined

- Prefer `undefined` over `null` for "missing". TypeScript has special handling for `undefined` (optional properties, optional chaining).
- Use `null` only when interoperating with APIs that emit it (REST, GraphQL, some DBs).
- Convert at the boundary. Inside your domain, normalize to `undefined`.
- Optional chaining (`?.`) and nullish coalescing (`??`) over manual checks:

```ts
// ❌ verbose
const name = user && user.profile && user.profile.name ? user.profile.name : 'guest';

// ✅
const name = user?.profile?.name ?? 'guest';
```

## `any` and `unknown`

- **`any` is forbidden** except in two cases:
  1. Migration from JS, with a TODO to type properly.
  2. Interfacing with an untyped library where you genuinely can't model the type.
  
  In both cases, isolate `any` to a single thin adapter and type the boundary.

- **`unknown` is the right tool** for "I don't know yet, will narrow". Coming from `JSON.parse`, `fetch().json()`, external input — always `unknown`, then narrow with a schema validator or type guard.

```ts
const raw: unknown = await res.json();
const user = UserSchema.parse(raw); // typed as User from here on
```

## Type assertions

`as Foo` is a hammer. It silences the compiler without proving anything. Two legitimate uses:

1. **Adapter at I/O boundary** where you've validated separately (rare — prefer schema parse):
   ```ts
   const userId = req.params.id as UserId; // ok IF validated upstream
   ```
2. **Branded type construction** (the brand chokepoint):
   ```ts
   function asUserId(s: string): UserId { return s as UserId; }
   ```

Anywhere else, treat `as` as a code smell. Add a comment explaining why the compiler can't see what you see.

## Null operator (`!`) — almost never

`foo!` is `foo as NonNullable<typeof foo>`. Same rule as `as`: only when you've *proven* non-null in a way the compiler can't follow. Adding `!` to make red squigglies go away is a bug waiting to happen.

Better: refactor to a control flow the compiler understands.

```ts
// ❌
const value = map.get(key)!;

// ✅
const value = map.get(key);
if (value === undefined) throw new Error(`missing ${key}`);
// value is narrowed to V here
```

## Error handling

- Domain errors → discriminated union or `Result<T, E>` type.
- Programmer errors → throw (out-of-bounds, invariant violations).
- Async errors → never silently swallow. Either re-throw, map to domain error, or log + propagate.

For HTTP / external APIs at boundaries, structure errors as domain types:

```ts
type FetchError =
  | { kind: 'network'; cause: unknown }
  | { kind: 'http'; status: number; body: unknown }
  | { kind: 'parse'; cause: unknown };

type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: FetchError };
```

## Anti-patterns

- `// @ts-ignore` — almost never. `// @ts-expect-error` with a comment is slightly better (errors when the underlying issue is fixed).
- `Function` as a type — meaningless, accepts anything callable. Use `(...args: never[]) => unknown` or be specific.
- `object` as a type — almost as bad as `Function`. Use `Record<string, unknown>` or a proper interface.
- Empty interface (`interface Foo {}`) — `unknown` is what you want.
- Mutable default parameters with reference types — `function f(arr: string[] = [])` shares the array across calls. Use a factory or `undefined` default.
