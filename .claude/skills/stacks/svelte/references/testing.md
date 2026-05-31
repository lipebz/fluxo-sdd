---
title: Svelte / SvelteKit — Testing
stack: svelte
---

# Svelte / SvelteKit Testing

## Stack

- **Vitest** as the runner. SvelteKit ships with Vitest config out of the box.
- **`@testing-library/svelte`** for component rendering and querying.
- **`@testing-library/user-event`** for interactions.
- **`@testing-library/jest-dom`** for DOM matchers (`toBeInTheDocument`, …).
- **MSW** for HTTP mocking when components fetch.
- **Playwright** for end-to-end and full-stack tests (SvelteKit's recommended E2E).

## Guiding principle

> Test what the user sees and does, not what the code does internally.

For Svelte specifically: don't test that `$state` mutated, test that the rendered output changed. Don't test that `$effect` ran, test the side effect's observable result.

## Component test structure

```ts
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { expect, it, vi } from 'vitest';
import UserCard from './UserCard.svelte';

it('emits edit when the button is clicked', async () => {
  // Arrange
  const onEdit = vi.fn();
  render(UserCard, { props: { user: { id: '1', name: 'Alice' }, onEdit } });

  // Act
  await userEvent.click(screen.getByRole('button', { name: /edit/i }));

  // Assert
  expect(onEdit).toHaveBeenCalledWith('1');
});
```

`render(Component, { props })` is the Svelte signature. Same RTL query priority as React (role > label > text > test-id).

## Query priority

1. `getByRole` (with `name`) — accessible queries.
2. `getByLabelText` — form fields with labels.
3. `getByText` — non-interactive content.
4. `getByDisplayValue` — form fields with values.
5. `getByTestId` — last resort.

Async variants:
- `findBy*` — waits for the element to appear.
- `queryBy*` — returns `null` for assertion-of-absence.

## Mocking SvelteKit modules

SvelteKit's `$app/*` modules need mocking when used in components:

```ts
// in your test setup or per-test
import { vi } from 'vitest';

vi.mock('$app/navigation', () => ({
  goto: vi.fn(),
  invalidate: vi.fn(),
  invalidateAll: vi.fn(),
}));

vi.mock('$app/state', () => ({
  page: { url: new URL('http://localhost/'), params: {}, data: {} },
}));
```

Mock per test file what that file uses — don't mock everything upfront.

## Mocking fetch with MSW

```ts
// src/test/server.ts
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

export const server = setupServer(
  http.get('/api/users/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, name: 'Alice' })
  )
);

// vitest setup file
import { server } from './src/test/server';
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Then in tests, override handlers per scenario:

```ts
it('shows error on 500', async () => {
  server.use(http.get('/api/users/:id', () => new HttpResponse(null, { status: 500 })));
  render(UserProfile, { props: { id: '1' } });
  expect(await screen.findByText(/error/i)).toBeInTheDocument();
});
```

## Testing load functions

Load functions are plain TypeScript — test them in isolation:

```ts
import { load } from './+page.server';

it('redirects when unauthenticated', async () => {
  const event = {
    locals: { user: null },
    params: { id: '1' },
  } as any;

  await expect(load(event)).rejects.toMatchObject({ status: 303, location: '/login' });
});
```

For form actions, same pattern — they're just functions that take an event.

## Testing form actions

```ts
import { actions } from './+page.server';

it('returns 400 when name is missing', async () => {
  const formData = new FormData();
  // no name set
  const event = {
    request: { formData: async () => formData },
    locals: { user: { id: '1' } },
  } as any;

  const result = await actions.default(event);
  expect(result).toMatchObject({ status: 400 });
});
```

For full integration, prefer Playwright — actions touch hooks, cookies, DB, and the rendered form.

## Runes testing

Runes work inside components and `.svelte.ts/js` modules. Test them through the component:

```ts
import Counter from './Counter.svelte';
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';

it('increments on click', async () => {
  render(Counter);
  expect(screen.getByText('count: 0')).toBeInTheDocument();
  await userEvent.click(screen.getByRole('button', { name: /\+/ }));
  expect(screen.getByText('count: 1')).toBeInTheDocument();
});
```

For runes in `.svelte.ts` modules, you can test directly — they work in plain TS:

```ts
// theme.svelte.ts
export const theme = $state({ value: 'light' as 'light' | 'dark' });

// theme.test.ts
import { theme } from './theme.svelte';
it('toggles', () => {
  theme.value = 'dark';
  expect(theme.value).toBe('dark');
});
```

Note: `.svelte.ts` files require Vitest config to handle them (SvelteKit's default does).

## E2E with Playwright

For anything that crosses the server/client boundary (form actions, full navigation, auth flows), use Playwright:

```ts
import { test, expect } from '@playwright/test';

test('user can log in and see profile', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('email').fill('alice@example.com');
  await page.getByLabel('password').fill('secret');
  await page.getByRole('button', { name: /sign in/i }).click();
  await expect(page).toHaveURL('/profile');
  await expect(page.getByRole('heading', { name: /alice/i })).toBeVisible();
});
```

SvelteKit's `npx sv create` scaffolds Playwright if you opt-in.

## Async patterns

Always `await` user-event:

```ts
await userEvent.click(button);
expect(...).toBe(...);
```

For things that appear after async work, use `findBy*`:

```ts
expect(await screen.findByText(/welcome/i)).toBeInTheDocument();
```

## Accessibility

Same as React — querying by role forces a11y; pair with `axe-playwright` (E2E) or `vitest-axe` for unit:

```ts
import { axe } from 'vitest-axe';

it('has no a11y violations', async () => {
  const { container } = render(UserCard, { props: { user: mockUser } });
  expect(await axe(container)).toHaveNoViolations();
});
```

## Anti-patterns

- **Testing the rune itself.** `expect(count).toBe(1)` — that's testing `=`, not behavior. Test the rendered output.
- **Mocking `$state`/`$effect`.** They're language features. If you need to mock them, you're testing the wrong layer.
- **Snapshot tests of whole components.** Class names change, tests fail, snapshots get re-recorded mindlessly.
- **Forgetting `await` on user-event.** Flaky tests.
- **`bind:` and asserting on the bound variable.** Test the rendered effect, not the JS variable.
- **Shared state across tests.** Stores leak between tests if not reset. Use `beforeEach` to reset stores, MSW handlers, mocks.
- **Skipping the load test, only testing the component.** Loads have logic — auth checks, redirects, data shaping. Test them as functions.
