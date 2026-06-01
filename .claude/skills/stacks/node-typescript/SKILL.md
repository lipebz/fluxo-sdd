---
name: node-typescript
version: 1.0.0
status: curated
description: Activate when implementing, fixing, refactoring, or reviewing backend code on a Node.js + TypeScript stack — HTTP APIs (Express, Fastify, NestJS), data access (Prisma, Drizzle, pg), validation (zod), tests (Vitest/Jest), logging, security, or project structure. Do not use for frontend-only or non-Node backends (Laravel, Django, Go).
---

# Node.js + TypeScript Backend

## When this is used

Use this skill any time the task touches a Node.js backend written in TypeScript: building an endpoint, wiring a repository, adding tests, hardening security, organizing the codebase, configuring auth/middleware.

Always load `typescript` alongside — `node-typescript` covers backend runtime concerns; `typescript` covers the language.

## References

Load only what the task needs.

- `references/architecture.md` — layering (domain/use-case/adapter), dependency injection, monorepo, framework choice (Express vs Fastify vs Nest), repository pattern.
- `references/conventions.md` — module structure, naming, error handling, async, environment variables, logging, lint config.
- `references/testing.md` — Vitest/Jest patterns, unit vs integration, test doubles, DB isolation, mocking external services with MSW or nock.

## Golden rules

- **Thin handlers, fat use cases.** Handler = parse input, call use case, format response. No business logic in transport.
- **Validate at the boundary.** Use zod/valibot at every external input — HTTP body, query, params, env vars, queue messages. Inside the domain, types are trusted.
- **Depend on interfaces at I/O.** Use cases take `UserRepository`, not `PrismaClient`. Inject the concrete adapter via constructors/factories. Makes testing and swapping painless.
- **Repositories return domain entities, not ORM rows.** Map at the repository boundary. Don't leak Prisma/Drizzle types into the domain.
- **Transactions belong to use cases, not repositories.** A use case can compose multiple repository calls inside a single transaction. A repository method that opens its own transaction can't be composed.
- **`strict: true` always.** No exceptions. (See `typescript` skill.)
- **Never log secrets or PII.** Strip them before logging. Use a structured logger (pino, winston) — never `console.log` in prod.
- **Never expose stack traces in responses.** Generic error message to the client; full detail to the log with correlation ID.
- **Parameterize every query.** No string-concat SQL, ever. Trust the ORM's parameter binding or use the driver's parameter API.
- **Read `package.json` first.** Engine, scripts, framework, ORM, test runner — assume nothing.

## Framework selection

- **Express** — minimal, ubiquitous. Use middleware chain. Fine for small services; lacks type safety out of the box.
- **Fastify** — faster, schema-based validation (JSON Schema or zod), better TS DX. Default choice for new services.
- **NestJS** — opinionated, DI container, decorators. Use when team wants Spring/Angular-style structure. Heavier conceptually.
- **Hono** — edge-first, runs everywhere (Node, Workers, Deno, Bun). Use for edge deployments or when targeting Cloudflare Workers/Vercel Edge.

If the project already has one, follow it. Don't introduce a second framework.

## When to break a rule

- A trivial CRUD endpoint with one query may not need a use case layer — direct handler-to-repository is fine if the codebase is consistent about it.
- A read-only repository method on a single table may not need a transaction.
- Logging request IDs (not PII) is fine and encouraged.

If you break a rule, explain why in an ADR or code comment.
