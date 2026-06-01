---
title: React — Testing
stack: react
---

# React Testing

## Stack

The canonical React test stack:

- **Vitest** or **Jest** as the runner.
- **React Testing Library** (RTL) for rendering and querying.
- **`@testing-library/user-event`** for interactions (preferred over `fireEvent`).
- **`@testing-library/jest-dom`** for DOM matchers (`toBeInTheDocument`, `toHaveValue`, …).
- **MSW** (Mock Service Worker) for HTTP mocks at the network layer.

Use Playwright or Cypress for end-to-end. RTL is not for E2E.

## Guiding principle

> Test the component the way a user uses it. Not the way the code is written.

Query by role and accessible name first. If a test depends on `getByTestId` because nothing else works, that's a hint the component lacks semantic markup or labels.

## Query priority (RTL)

1. `getByRole` (with `name` for disambiguation) — closest to how screen readers find things.
2. `getByLabelText` — for form fields.
3. `getByPlaceholderText` — fallback for labelless inputs.
4. `getByText` — for non-interactive content.
5. `getByDisplayValue` — for filled form fields.
6. `getByAltText` / `getByTitle` — niche.
7. `getByTestId` — last resort.

```tsx
// ❌ fragile
const submit = screen.getByTestId('submit-button');

// ✅ what the user sees
const submit = screen.getByRole('button', { name: /save changes/i });
```

If you can't query by role, the component is probably failing a11y too — fix both at once.

## `find` vs `get` vs `query`

- `getBy*` — must exist now. Throws if not.
- `queryBy*` — returns `null` if not. Use for asserting absence.
- `findBy*` — async, waits up to the timeout. Use for things that appear after a render/effect.

```tsx
// ✅ asserting absence
expect(screen.queryByText(/error/i)).not.toBeInTheDocument();

// ✅ waiting for async
expect(await screen.findByText(/welcome/i)).toBeInTheDocument();
```

## Component test structure (AAA)

```tsx
it('marks the order as paid when the user clicks Pay', async () => {
  // Arrange
  const onPay = vi.fn();
  render(<OrderCard order={mockOrder} onPay={onPay} />);

  // Act
  await userEvent.click(screen.getByRole('button', { name: /pay/i }));

  // Assert
  expect(onPay).toHaveBeenCalledWith(mockOrder.id);
});
```

One scenario per test. The test name describes the behavior, not the implementation.

## User-event over fireEvent

```tsx
// ❌ fireEvent — synthetic, skips real browser behavior
fireEvent.click(button);
fireEvent.change(input, { target: { value: 'hello' } });

// ✅ user-event — simulates a real user (focus, keydown, keyup, etc.)
await userEvent.click(button);
await userEvent.type(input, 'hello');
```

`fireEvent` only when `user-event` lacks the specific interaction (rare).

## Mocking fetch / API

### MSW — preferred

```tsx
// setup in a single file
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

export const server = setupServer(
  http.get('/api/users/:id', ({ params }) =>
    HttpResponse.json({ id: params.id, name: 'Alice' })
  )
);

// in test setup
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Why MSW: tests use the real fetch path. No `vi.mock('axios')`. The same handlers work for Storybook, dev, and E2E if you want.

### Inline handler override per test

```tsx
it('shows error on 500', async () => {
  server.use(
    http.get('/api/users/:id', () => new HttpResponse(null, { status: 500 }))
  );

  render(<UserProfile id="1" />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

## Mocking router

For React Router:

```tsx
import { MemoryRouter } from 'react-router-dom';

render(
  <MemoryRouter initialEntries={['/users/1']}>
    <UserProfile />
  </MemoryRouter>
);
```

For Next.js, use `next-router-mock` or test the page through `next-test-api-route-handler` for API routes.

## Mocking context / providers

Wrap renders in providers — write a custom `render` once:

```tsx
function renderWithProviders(ui: ReactElement, options?: { route?: string }) {
  return render(
    <QueryClientProvider client={testQueryClient()}>
      <MemoryRouter initialEntries={[options?.route ?? '/']}>
        <ThemeProvider>{ui}</ThemeProvider>
      </MemoryRouter>
    </QueryClientProvider>
  );
}
```

Use everywhere. Avoids 5 levels of nesting in every test.

## Async patterns

### Always await `userEvent` calls

```tsx
await userEvent.click(submit); // ← await
expect(...).toBe(...);
```

Forgetting `await` causes flaky tests that pass locally and fail in CI.

### `waitFor` for things RTL can't queue itself

```tsx
await waitFor(() => {
  expect(spy).toHaveBeenCalledTimes(2);
});
```

Don't `waitFor` an assertion against a DOM node — use `findBy*` (semantically clearer).

### Don't use `act()` manually unless React tells you to

RTL wraps `act` internally. Manual `act()` calls are a smell — usually means you're testing implementation, not behavior.

## Hooks — testing isolated hooks

```tsx
import { renderHook, act } from '@testing-library/react';

it('increments the counter', () => {
  const { result } = renderHook(() => useCounter());

  act(() => {
    result.current.increment();
  });

  expect(result.current.count).toBe(1);
});
```

Use only for non-trivial hooks. Simple hooks are better tested through a component that uses them.

## Accessibility in tests

Two free a11y checks per test:

1. **Querying by role with name** — you can't write the test if the component isn't accessible.
2. **`expect.toHaveNoViolations()`** with `jest-axe` — catches contrast, missing labels, ARIA misuse:

```tsx
import { axe } from 'jest-axe';

it('has no a11y violations', async () => {
  const { container } = render(<UserCard user={mockUser} />);
  expect(await axe(container)).toHaveNoViolations();
});
```

Run jest-axe at least once per component. It's slow — don't run on every test.

## Snapshot tests — sparingly

- Inline snapshots (`toMatchInlineSnapshot`) over file snapshots when possible.
- Snapshot small, stable outputs (error message text, computed values).
- **Never** snapshot a whole component tree. They break on every CSS class change and teach the team to "press u" without thinking.

## Anti-patterns

- **Testing implementation details.** "Does this `useState` get called?" The user doesn't care. Test the rendered output and behavior.
- **`container.querySelector('.foo')`.** Bypasses RTL queries, ties test to CSS class name. Use `getByRole`/`getByText`.
- **`it.only` / `describe.only` committed.** Either remove or document why a suite is isolated.
- **Mocking React itself** (`vi.mock('react')`). Almost always wrong.
- **Shared state between tests.** Reset MSW handlers, reset QueryClient, reset zustand stores in `beforeEach`/`afterEach`.
- **Test the mock.** `expect(mockFn).toHaveBeenCalled()` without asserting the consequence in the UI tests the mock, not the component.
- **Snapshot the universe.** A 500-line snapshot is not a test.
