---
title: Node.js + TypeScript — Conventions
stack: node-typescript
---

# Node.js + TypeScript Conventions

## File and folder naming

| Item | Convention | Example |
|---|---|---|
| Source files | kebab-case | `user-repository.ts`, `create-user.ts` |
| Test files | `*.test.ts` or `*.spec.ts` next to source | `user-repository.test.ts` |
| Classes | PascalCase | `UserRepository`, `EmailAlreadyUsedError` |
| Functions, variables | camelCase | `createUser`, `currentUser` |
| Constants (module-level) | UPPER_SNAKE_CASE | `DEFAULT_TIMEOUT_MS` |
| Types/interfaces | PascalCase | `User`, `CreateUserInput` |
| Domain folders | kebab-case singular | `user/`, `order/` |

If the project uses PascalCase for files (`UserRepository.ts`), match it. Don't mix.

## Module shape

```ts
// 1. imports — external, then absolute, then relative, then type-only
import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
import { createUser } from '@/application/create-user';
import { toUserResponse } from './mappers';
import type { Deps } from './deps';

// 2. schemas / constants
const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

const MAX_BODY_BYTES = 1024 * 1024;

// 3. types (local to module)
type Input = z.infer<typeof createUserSchema>;

// 4. exports — the actual behavior
export async function registerUserRoutes(app: FastifyInstance, deps: Deps) {
  app.post('/users', { config: { bodyLimit: MAX_BODY_BYTES } }, async (request, reply) => {
    const input = createUserSchema.parse(request.body);
    const user = await createUser(deps, input);
    return reply.status(201).send(toUserResponse(user));
  });
}
```

One concern per file. If you find yourself naming the file `helpers.ts` or `utils.ts`, the concern is unclear.

## Async patterns

### Always `async`/`await` — no `.then()` chains in app code

```ts
// ❌
fetch(url).then(r => r.json()).then(data => use(data));

// ✅
const data = await (await fetch(url)).json();
use(data);
```

`.then` is fine in tight one-off pipelines or library code. In application logic, `await` reads better.

### Never `async` without `await`

```ts
// ❌ async-without-await is a smell — usually a missed await
async function getUser(id: string): Promise<User> {
  return userRepo.findById(id);
}
// (would still work, but the async keyword wraps the already-Promise needlessly)

// ✅
function getUser(id: string): Promise<User> {
  return userRepo.findById(id);
}
```

### `Promise.all` for concurrent independent work

```ts
// ✅
const [user, orders] = await Promise.all([
  userRepo.findById(id),
  orderRepo.findByUserId(id),
]);

// ❌ sequential — slower for no reason
const user = await userRepo.findById(id);
const orders = await orderRepo.findByUserId(id);
```

For collection processing, `Promise.all(items.map(async ...))` works but watch for overload — large arrays can swamp the DB. Use `p-limit` or a batch helper for bounded concurrency.

### Never swallow errors

```ts
// ❌
try { await risky(); } catch { /* ignore */ }

// ✅
try {
  await risky();
} catch (err) {
  logger.warn({ err }, 'risky failed, continuing with default');
  // OR re-throw, OR return a Result
}
```

A bare `catch {}` is a bug factory.

## Imports

### Path aliases

Configure `tsconfig.json` `paths` for clean imports:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

Pair with the runtime — `tsx`/`tsc-alias`/`vite-node`/`tsconfig-paths` to resolve at runtime. Without runtime support, imports break.

### Import order (enforced by `eslint-plugin-import`)

1. Node built-ins (`node:fs`, `node:path`)
2. External packages
3. Internal absolute (`@/...`)
4. Relative (`./`, `../`)
5. Type-only imports (often last)

Use `node:` protocol for built-ins to be explicit:

```ts
import { readFile } from 'node:fs/promises';
import path from 'node:path';
```

## Environment variables

- Read from `process.env` only in **one** module (`src/env.ts` or `src/config.ts`).
- Validate at startup with zod (see architecture.md).
- Export the typed `env` object. Everything else imports from there.
- Never log `env`. Never inline-template secrets.

```ts
// ❌ scattered process.env reads
const dbUrl = process.env.DATABASE_URL!;  // (somewhere deep in code)

// ✅ centralized + typed
import { env } from '@/env';
const dbUrl = env.DATABASE_URL;
```

## Logging

Use a structured logger (pino, winston). Never raw `console.log` in production paths.

```ts
import pino from 'pino';

export const logger = pino({
  level: env.LOG_LEVEL,
  redact: ['req.headers.authorization', 'password', 'token', '*.password'],
});
```

### Log shape

- One JSON object per log line.
- Include `requestId`/`correlationId` to trace across services (via middleware).
- Levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal`.
- Use `info` for normal events, `warn` for recoverable issues, `error` for unhandled.

```ts
logger.info({ userId, action: 'login' }, 'user logged in');
logger.warn({ err, userId }, 'rate-limited login attempt');
logger.error({ err }, 'payment failed');
```

### Never log

- Passwords, tokens, JWTs, API keys
- PII unless required and approved (emails, names — varies by jurisdiction)
- Full request body for sensitive endpoints
- Stack traces sent to clients

Pino's `redact` config catches most slips automatically.

## Error handling

### Throw domain errors

```ts
throw new NotFoundError('User', id);
```

### Catch in one place (error-handler middleware)

```ts
app.setErrorHandler((err, request, reply) => {
  if (err instanceof DomainError) {
    return reply.status(domainErrorStatus(err)).send({ code: err.code, message: err.message });
  }
  request.log.error({ err }, 'unhandled');
  return reply.status(500).send({ code: 'INTERNAL', message: 'something went wrong' });
});
```

Don't try/catch in every handler. Let the centralized handler do its job.

### Don't return errors from functions you can throw

A use case throws. A handler catches via the middleware. Returning `{ ok, error }` everywhere is fine but adds verbosity — pick a pattern per project.

## TypeScript settings

See the `typescript` skill — same rules apply: `strict: true`, `noUncheckedIndexedAccess: true`, no `any`, prefer `unknown` at boundaries.

Node-specific:
- `"module": "NodeNext"` and `"moduleResolution": "NodeNext"` for ESM-first projects, or `"module": "CommonJS"` for CJS.
- `"target"` ≥ `ES2022` for Node 18+.
- Set `"types": ["node"]` and install `@types/node`.

## Lint

`eslint` + `@typescript-eslint` with the recommended config. Add:
- `eslint-plugin-import` for import order.
- `eslint-plugin-promise` for Promise pitfalls.
- `eslint-plugin-n` for Node-specific rules.

Format with Prettier. Don't fight Prettier defaults.

## Anti-patterns

- **`console.log` in production code.** Replace with the logger. If you need ad-hoc debugging, use `logger.debug` and gate via log level.
- **Global mutable state.** Singletons for caches and clients are fine — but no `let counter = 0` at module top level that gets mutated.
- **`require()` in TS code.** Use `import`. If you absolutely need `require` for a CJS-only lib in an ESM project, use `createRequire(import.meta.url)`.
- **`any` casts at boundaries.** Validate with zod, get a typed value, work from there.
- **Stack traces in HTTP responses.** Even in dev. Use `NODE_ENV === 'development'` if you want stack in logs, never in the response body.
- **Missing `await`.** A handler that returns a non-awaited promise will respond before the work finishes. Use the `no-floating-promises` lint rule.
- **Synchronous I/O in handlers.** No `readFileSync`, no `execSync`. Block the event loop = block all concurrent requests.
- **String-concat SQL.** Always parameterize. ORMs do this; raw queries need `$1`/`?`/`:name` syntax.
- **Returning `null` vs throwing — inconsistently.** Pick one per layer. "Repository returns null for missing, use case throws NotFoundError" is a common, clean split.
