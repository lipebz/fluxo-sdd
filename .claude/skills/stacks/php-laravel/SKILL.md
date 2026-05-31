---
name: php-laravel
version: 1.0.0
status: curated
description: Activate when implementing, fixing, refactoring, or reviewing PHP code on a Laravel 11+ stack — controllers, services, models, Eloquent, FormRequests, policies, Artisan commands, jobs/queues, tests (Pest/PHPUnit), migrations, broadcasting. Do not use for non-Laravel PHP (Symfony, raw PHP) — use the matching skill.
---

# PHP / Laravel Implementation

## When this is used

Use this skill any time the task touches a Laravel application: building an endpoint, writing a service, creating a model/migration, adding validation/authorization, queueing a job, writing tests, configuring middleware, or organizing the project.

Targets **Laravel 11+** (the streamlined skeleton without `app/Http/Kernel.php`, etc.). Patterns work in Laravel 10 as well, but file locations may differ — read `composer.json` first.

## References

Load only what the task needs.

- `references/architecture.md` — project layout, MVC + Service layer, Action classes, Eloquent vs Repository, queues, broadcasting, routing.
- `references/conventions.md` — naming, FormRequests, Policies, Resources, dependency injection, error handling, configuration, Artisan.
- `references/testing.md` — Pest/PHPUnit, feature tests, factories, database transactions, HTTP testing, mocking with Mockery, Laravel testing helpers.

## Golden rules

- **Thin controllers.** Controller = receive validated request, call a service/action, return response. No business logic, no Eloquent queries beyond `findOrFail`-level.
- **Validation via FormRequest** at the boundary. Never validate inline in controllers (except trivial cases). FormRequest also handles authorization in many cases.
- **Authorization via Policy or Gate.** Never check permissions inline in controllers. `$this->authorize('update', $post)` or `Gate::authorize(...)`.
- **Eloquent is fine — until it isn't.** For typical CRUD, Eloquent everywhere. When a query touches multiple aggregates or has gnarly performance constraints, extract to a dedicated query class or use raw SQL via the query builder.
- **Service layer or Action classes** for business logic. Per-feature single-method Action classes are the modern Laravel convention (`CreateUser`, `UpdateInvoice`); Service classes work when state/methods cluster naturally.
- **Migrations are append-only in main.** Once merged, never edit a migration. Create a new one to alter.
- **Resources for API responses.** Use `JsonResource` to shape API output. Never return raw models from API endpoints — leaks columns, breaks on rename.
- **Queue the slow stuff.** Anything > 200ms that doesn't need to block the request — send email, post to external API, generate PDF — goes to a queued job.
- **Never log sensitive data.** Laravel logs request data by default in some contexts; review `LogManager` config and use `LOG_LEVEL` and redaction.
- **Read `composer.json` and `config/app.php`** first. Confirm Laravel version, key packages (Sanctum, Passport, Spatie Permission, Telescope), and timezone before writing code.

## When to break a rule

- A "skinny" controller with one query is fine for read endpoints with no logic.
- Inline `$request->validate([...])` is acceptable in single-use, internal admin endpoints — but FormRequest scales better.
- For internal admin tools, returning a model with `->toArray()` is acceptable; the Resource ceremony isn't worth it.

When you break a rule, prefer to leave a comment with reasoning rather than an ADR — Laravel projects tend to be opinionated already.
