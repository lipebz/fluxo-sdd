---
title: Node.js + TypeScript — Testing
stack: node-typescript
---

# Node.js + TypeScript Testing

## Stack

- **Vitest** — default. Fast, ESM-native, great TS DX, watch mode out of box.
- **Jest** — legacy or when ecosystem tooling demands it. Use `ts-jest` or SWC transform.
- **Node test runner** (`node:test`) — zero deps, fine for tiny services.
- **Supertest** or **Fastify's `app.inject()`** for HTTP-level tests.
- **MSW** for outbound HTTP mocking (your service calling external APIs).
- **Testcontainers** for real DB/Redis/etc in integration tests.

## Pyramid: unit > integration > E2E

| Layer | What | Where |
|---|---|---|
| Unit | Use cases with fake repositories, pure domain logic, mappers | `*.test.ts` next to source |
| Integration | Repository against real DB (Testcontainers or test schema), HTTP route via `app.inject()` | `tests/integration/` |
| E2E | Whole service deployed locally, real HTTP, real DB | `tests/e2e/` |

Most tests should be unit. Integration tests cover the edges. E2E catches wiring bugs — keep them few.

## Unit test — use case with fake repo

```ts
// application/create-user.test.ts
import { describe, it, expect, vi } from 'vitest';
import { createUser, EmailAlreadyUsedError } from './create-user';
import type { UserRepository } from '@/domain/user-repository';

function fakeRepo(initial: User[] = []): UserRepository {
  const users = new Map(initial.map(u => [u.id, u]));
  return {
    findById: async (id) => users.get(id) ?? null,
    findByEmail: async (email) => [...users.values()].find(u => u.email === email) ?? null,
    save: async (u) => { users.set(u.id, u); },
  };
}

const silentLogger = { info: vi.fn(), warn: vi.fn(), error: vi.fn() };

describe('createUser', () => {
  it('creates a user', async () => {
    const userRepo = fakeRepo();
    const user = await createUser({ userRepo, logger: silentLogger }, {
      email: 'alice@example.com',
      name: 'Alice',
    });
    expect(user.email).toBe('alice@example.com');
    expect(await userRepo.findById(user.id)).not.toBeNull();
  });

  it('rejects duplicate email', async () => {
    const existing = User.create({ email: 'alice@example.com', name: 'Alice' });
    const userRepo = fakeRepo([existing]);

    await expect(
      createUser({ userRepo, logger: silentLogger }, { email: 'alice@example.com', name: 'Bob' })
    ).rejects.toBeInstanceOf(EmailAlreadyUsedError);
  });
});
```

The fake repo is a real implementation against an in-memory map. Much better than `vi.mock()` — tests the actual interface contract, not the call pattern.

## Integration test — HTTP via app.inject

Fastify's `app.inject()` is the canonical integration approach — no port, no network, full middleware chain:

```ts
import { describe, it, expect, beforeAll } from 'vitest';
import { buildApp } from '@/server';

describe('POST /users', () => {
  let app: ReturnType<typeof buildApp>;
  beforeAll(async () => {
    app = await buildApp({ /* test deps with test DB */ });
  });

  it('creates a user', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/users',
      payload: { email: 'alice@example.com', name: 'Alice' },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ id: expect.any(String) });
  });

  it('rejects invalid email', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/users',
      payload: { email: 'not-an-email', name: 'Alice' },
    });
    expect(res.statusCode).toBe(400);
  });
});
```

For Express, use `supertest(app)`. Same pattern.

## Integration test — repository with real DB

Use Testcontainers to spin up Postgres per test run:

```ts
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import { PrismaClient } from '@prisma/client';
import { execSync } from 'node:child_process';

let container: StartedPostgreSqlContainer;
let prisma: PrismaClient;

beforeAll(async () => {
  container = await new PostgreSqlContainer().start();
  process.env.DATABASE_URL = container.getConnectionUri();
  execSync('npx prisma migrate deploy', { env: process.env });
  prisma = new PrismaClient();
});

afterAll(async () => {
  await prisma.$disconnect();
  await container.stop();
});

beforeEach(async () => {
  await prisma.user.deleteMany(); // clean state per test
});

it('saves and retrieves a user', async () => {
  const repo = new PrismaUserRepository(prisma);
  const user = User.create({ email: 'a@b.com', name: 'Alice' });
  await repo.save(user);
  const fetched = await repo.findById(user.id);
  expect(fetched?.email).toBe('a@b.com');
});
```

Alternative: a single shared test DB with a transaction per test that rolls back. Faster, more setup.

## Mocking outbound HTTP — MSW

```ts
// test/server.ts
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

export const mockServer = setupServer(
  http.get('https://api.payments.com/v1/charges/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, status: 'paid' })
  )
);
```

```ts
beforeAll(() => mockServer.listen({ onUnhandledRequest: 'error' }));
afterEach(() => mockServer.resetHandlers());
afterAll(() => mockServer.close());
```

`onUnhandledRequest: 'error'` catches unintended outbound calls — if your code suddenly hits a new external URL, the test fails loudly.

## Test doubles — pick the right name

- **Stub** — canned return. `findById: async () => fakeUser`.
- **Mock** — verify interaction. `expect(saveSpy).toHaveBeenCalledWith(...)`.
- **Fake** — real impl, different backing. In-memory repo, fake clock.
- **Spy** — wrap real, observe calls.

Prefer fakes for non-trivial collaborators. They test the contract; mocks test the call pattern (brittle).

## Time and randomness

Inject. Don't `Date.now()` or `Math.random()` in domain code.

```ts
type Deps = { now: () => Date; randomId: () => string; };

// production
const deps = { now: () => new Date(), randomId: () => crypto.randomUUID() };

// test
const deps = { now: () => new Date('2026-01-01'), randomId: () => 'fixed-id' };
```

Or use Vitest's `vi.useFakeTimers()` for clock control inside a test.

## Coverage — useful, not a goal

- Branches and statements > 70% on use cases and domain.
- Don't chase 100%. Adapters (Prisma repo, HTTP routes) get integration-level coverage, not unit.
- Use coverage to find untested files, not to satisfy a number.

## Test naming

```ts
// ❌
it('test1', ...);
it('works', ...);

// ✅
it('creates a user with the given email and name', ...);
it('rejects when the email is already used', ...);
it('rolls back when the second repository call fails', ...);
```

Test name = the scenario. Reads like documentation.

## What to test, what not to test

### Test
- Public behavior of use cases.
- Domain invariants (`User.create` rejects bad input).
- Adapter contracts (repository against real DB).
- HTTP error mapping (middleware translates `NotFoundError` to 404).
- Edge cases: empty, null, max values, concurrent.

### Don't test
- Prisma/Drizzle itself. Trust the lib.
- `console.log`s.
- Trivial getters.
- The fake/mock you created.

## Async test patterns

Always `await`:

```ts
// ❌ silently passes
expect(createUser(deps, badInput)).rejects.toThrow();

// ✅
await expect(createUser(deps, badInput)).rejects.toThrow();
```

For rejection assertions on instances:

```ts
await expect(createUser(deps, bad)).rejects.toBeInstanceOf(ValidationError);
```

## Anti-patterns

- **`vi.mock('@/...')` everywhere.** Auto-mocking modules makes tests brittle and hides what's being tested. Use DI + fakes instead.
- **Tests that depend on test order.** Each test must work in isolation. Reset state in `beforeEach`.
- **One huge test that does 12 things.** Split it. The test name should describe one scenario.
- **Mocking what you should fake.** Mocking a database client method-by-method = pain. Use a fake repo.
- **Hitting the real network in unit tests.** MSW or fake. Real network = flaky CI.
- **No cleanup.** Open DB connections, timers, listeners leak between tests. `afterAll`/`afterEach` matter.
- **Snapshot serialization of full objects.** Snapshot small, stable strings. Object diffs hide what changed.
- **`it.only` committed.** CI gate this or pre-commit lint it.
