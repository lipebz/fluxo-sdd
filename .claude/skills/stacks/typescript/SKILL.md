---
name: typescript
version: 1.0.0
status: curated
description: Activate when implementing, fixing, refactoring, or reviewing TypeScript code — type definitions, generics, type guards, strict mode handling, module organization. Transversal skill — composes with stack-specific skills (react, svelte, node-typescript) for domain-specific patterns. Use this for TypeScript-the-language; use the stack skill for runtime/framework concerns.
---

# TypeScript Implementation

## When this is used

Use this skill any time the task touches TypeScript code on any stack: writing types, refining a type, debugging a type error, deciding between `any`/`unknown`/`never`, organizing module boundaries, configuring `tsconfig.json`, or reviewing type design.

This skill is **transversal**: it composes with the stack-specific skill. If the project has React + TypeScript, the agent loads both `typescript` (this skill) and `react`. They don't conflict — `typescript` handles the language, `react` handles the framework.

## References

Load only what the task needs.

- `references/architecture.md` — module boundaries, type design, generics, narrowing strategies, branded types.
- `references/conventions.md` — strict mode, naming, imports, `any`/`unknown` policy, null handling, type assertions.
- `references/testing.md` — typing tests, type-level testing with `expect-type`/`tsd`, mocking with type safety.

## Golden rules

- `strict: true` always. No exceptions, no `strictNullChecks: false`, no `noImplicitAny: false`.
- Prefer `unknown` over `any`. Narrow `unknown` with type guards or schema validation (zod/valibot) at boundaries.
- No type assertions to silence the compiler. `as Type` is a last resort, only when you have *proven* knowledge the compiler can't see, and you add a comment explaining why.
- Model errors, not just happy paths. Use `Result<T, E>` or discriminated unions for fallible operations when the domain calls for it; throw only for truly exceptional cases.
- Discriminated unions over boolean flags. `{ kind: 'loaded', data } | { kind: 'error', err } | { kind: 'loading' }` beats `{ isLoaded, isError, data?, err? }`.
- Make illegal states unrepresentable. If two fields are mutually exclusive, encode that in the type, not in runtime checks.
- Read `tsconfig.json` before assuming compiler behavior. `moduleResolution`, `target`, `paths`, and `lib` change a lot of what's possible.
- Module boundary = type boundary. Public exports of a module should expose minimal types; internal helpers stay internal. Use `export type` for type-only exports to keep the runtime graph clean.
- Don't fight inference. If TypeScript can infer it cleanly, let it. Explicit annotations are for public APIs and where inference would be wrong or confusing.
- Branded types for IDs and primitives that have semantic meaning. `type UserId = string & { __brand: 'UserId' }` prevents passing an order ID where a user ID is expected.

## When to break a rule

Each golden rule has a legitimate escape hatch. If you break one, document why in a code comment or ADR — never silently.
