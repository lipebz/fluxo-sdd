---
title: TypeScript — Testing
stack: typescript
---

# TypeScript Testing

This skill covers **TypeScript-specific** testing concerns: how types interact with tests, type-level testing, and mocking with type safety. For runtime testing strategy (unit vs integration, AAA pattern, fixtures), see the stack-specific skill (`react`, `node-typescript`, etc.).

## Test framework choice

TypeScript works with any JS test framework. Common choices:

- **Vitest** — fast, ESM-native, great TS DX, Vite-native. Default for new projects.
- **Jest** — mature, large ecosystem, requires `ts-jest` or babel preset.
- **Node test runner** (`node:test`) — built-in, zero deps, no watch mode out of the box.
- **Bun test** — built-in if you're on Bun.

Pick one per project. Don't mix.

## Strict types in tests

Tests use the same `tsconfig.json` strictness as source. No relaxation. The most common temptation:

❌ Don't:
```ts
it('returns the user', async () => {
  const result = await getUser('123') as any;
  expect(result.name).toBe('Alice');
});
```

✅ Do:
```ts
it('returns the user', async () => {
  const result = await getUser('123');
  expect(result).toMatchObject({ name: 'Alice' });
});
```

If `getUser` returns `User | null`, narrow explicitly:
```ts
const result = await getUser('123');
assert(result !== null, 'expected user');
expect(result.name).toBe('Alice');
```

Tests are also documentation. `as any` in tests teaches the wrong lesson.

## Mocking with type safety

When mocking a function, preserve its signature:

### Manual mocks

```ts
import type { UserRepository } from './user-repository';

const mockUserRepo: UserRepository = {
  findById: async (id) => ({ id, name: 'Test' }),
  save: async (_user) => undefined,
};
```

Typing `mockUserRepo: UserRepository` forces you to implement the full interface. If the interface grows, the mock fails to compile — you remember to update tests.

### Partial mocks

When you don't need the whole interface:

```ts
const mockUserRepo = {
  findById: async (id: string) => ({ id, name: 'Test' }),
} as Partial<UserRepository> as UserRepository;
```

Two assertions on purpose — it forces a pause. If you do this often, your dependencies are too wide; consider narrower interfaces (interface segregation).

### vi.fn / jest.fn

Use the framework's mock helpers with explicit typing:

```ts
import { vi } from 'vitest';
import type { UserRepository } from './user-repository';

const findById = vi.fn<UserRepository['findById']>().mockResolvedValue({ id: '1', name: 'Test' });
```

This makes the mock return type-checked against the real signature.

## Type-level testing

When you write generic utilities, types ARE the contract. Test them like code.

### Inline assertions with `expect-type`

```ts
import { expectTypeOf } from 'expect-type';

expectTypeOf<MyHelper<string>>().toEqualTypeOf<{ value: string; length: number }>();
expectTypeOf<MyHelper<number>>().not.toEqualTypeOf<{ value: string }>();
```

Runs at compile time. No runtime cost. Available in Vitest natively and as a standalone package.

### Compile-time assertions with conditional types

```ts
type Assert<T, U extends T> = U;

type _t1 = Assert<true, IsString<string>>;       // ok
type _t2 = Assert<true, IsString<number>>;       // ❌ compile error
```

Use when `expect-type` isn't available. Less ergonomic but zero dependency.

## What to test, what not to test

### Test
- Behavior at module boundaries (public API of a unit).
- Type-level invariants of generic utilities.
- Edge cases (empty input, null, max values).
- Error paths.

### Don't test
- Compiler behavior. `expect(typeof x).toBe('string')` when the type already says `string` is noise.
- Implementation details. Tests should survive a refactor that doesn't change behavior.
- Third-party libraries. Trust them or vendor them.

## Test doubles — terminology

Use the right name:
- **Stub** — returns a canned value. No verification of how it's called.
- **Mock** — verifies how it's called (was `save` invoked with this user?).
- **Spy** — wraps real impl, observes calls.
- **Fake** — alternative implementation (in-memory DB, fake clock).

When in doubt, prefer fakes over mocks for non-trivial dependencies. They test the contract, not the call pattern.

## Async patterns

Always `await` async assertions:

```ts
// ❌ silently passes if rejected
expect(fetchUser('bad')).rejects.toThrow();

// ✅
await expect(fetchUser('bad')).rejects.toThrow();
```

For multiple awaits, prefer sequential reads:

```ts
const user = await getUser('1');
expect(user.email).toBe('a@b.com');
const orders = await getOrders(user.id);
expect(orders).toHaveLength(2);
```

Not Promise.all in tests unless you're specifically testing concurrency.

## Snapshot tests — sparingly

Snapshots have a place (large stable outputs), but they rot:
- Don't snapshot objects that change every run (timestamps, IDs).
- Don't snapshot large React trees — they break on every CSS class change.
- Inline snapshots (`toMatchInlineSnapshot`) are better than file snapshots when the value is small.

If a snapshot is 200 lines, you don't have a test, you have a re-recording.

## Anti-patterns

- **`describe.skip` / `it.skip` left in code.** Either fix the test or delete it.
- **Tests that test the mock.** If you're asserting that `mockFn.calls[0]` matches `mockFn.calls[0]`, you've lost the plot.
- **One test, many assertions, vague name.** Split into focused tests with names that describe the scenario.
- **Global state between tests.** Use `beforeEach` to reset, or scope state to the test.
- **Type errors silenced in tests.** `@ts-ignore` in a test means the test is lying about what it tests.
