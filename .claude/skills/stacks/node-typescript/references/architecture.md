---
title: Node.js + TypeScript — Architecture
stack: node-typescript
---

# Node.js + TypeScript Backend Architecture

## Layering

Four layers, with **strict dependency direction**: outer layers depend on inner, never the reverse.

```
┌──────────────────────────────────────────────────┐
│ Adapters / Infrastructure                         │
│  - HTTP handlers, controllers (Express/Fastify)   │
│  - DB clients (Prisma, Drizzle, pg)               │
│  - External APIs, queue clients, mailers          │
└──────────────────┬───────────────────────────────┘
                   ↓ depends on
┌──────────────────────────────────────────────────┐
│ Use Cases / Application                           │
│  - Orchestrate domain logic                       │
│  - Manage transactions                            │
│  - Use only interfaces declared in domain         │
└──────────────────┬───────────────────────────────┘
                   ↓ depends on
┌──────────────────────────────────────────────────┐
│ Domain                                            │
│  - Entities, value objects, domain rules          │
│  - Repository interfaces (no impl)                │
│  - Pure TS, no framework, no IO                   │
└──────────────────────────────────────────────────┘
```

Domain never imports from `infrastructure/` or `application/`. Application imports only from `domain/`. Infrastructure imports from both.

### Concrete folder layout

```
src/
├── domain/
│   ├── user.ts                   # entity
│   ├── user-repository.ts        # interface only
│   └── errors.ts
├── application/
│   ├── create-user.ts            # use case
│   ├── get-user-by-id.ts
│   └── transactions.ts           # tx orchestration helper
├── infrastructure/
│   ├── db/
│   │   ├── prisma.ts             # client
│   │   ├── prisma-user-repository.ts  # implements UserRepository
│   │   └── migrations/
│   ├── http/
│   │   ├── server.ts             # Fastify/Express bootstrap
│   │   ├── routes/
│   │   │   └── users.ts          # HTTP layer — thin
│   │   └── middlewares/
│   │       ├── auth.ts
│   │       └── error-handler.ts
│   └── logging.ts
├── shared/
│   ├── result.ts                 # Result<T, E> type
│   └── ids.ts                    # branded ID types
└── server.ts                     # entry point
```

For small projects, you can flatten into `src/users/` (feature folder) with `domain.ts`, `usecase.ts`, `repo.ts`, `http.ts` — same logic, less ceremony. For larger projects, the explicit layered split scales better.

## Handler shape (thin handler)

```ts
// infrastructure/http/routes/users.ts
import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { createUser } from '@/application/create-user';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

export function registerUserRoutes(app: FastifyInstance) {
  app.post('/users', async (request, reply) => {
    const input = createUserSchema.parse(request.body); // validate at boundary
    const user = await createUser(app.deps, input);     // call use case
    return reply.status(201).send({ id: user.id });    // format response
  });
}
```

No business logic in the handler. The use case has the brain.

## Use case shape

```ts
// application/create-user.ts
import type { UserRepository } from '@/domain/user-repository';
import type { Logger } from '@/infrastructure/logging';
import { User } from '@/domain/user';

type Deps = {
  userRepo: UserRepository;
  logger: Logger;
};

type Input = { email: string; name: string };

export async function createUser(deps: Deps, input: Input): Promise<User> {
  const existing = await deps.userRepo.findByEmail(input.email);
  if (existing) throw new EmailAlreadyUsedError(input.email);

  const user = User.create({ email: input.email, name: input.name });
  await deps.userRepo.save(user);

  deps.logger.info({ userId: user.id }, 'user created');
  return user;
}
```

- Takes deps as first arg (functional DI) — easy to test, no DI container needed.
- Returns the domain entity (not a DTO — DTO formatting is the handler's job).
- Throws domain errors (caught by the error-handler middleware).

## Dependency injection — pick a style

Two viable approaches:

### Functional DI (preferred for most projects)

Bundle deps into an object, pass as the first argument:

```ts
// server.ts
const deps = {
  userRepo: new PrismaUserRepository(prisma),
  logger,
  emailer: new SendgridEmailer(env.SENDGRID_KEY),
};

app.decorate('deps', deps);
```

```ts
// in handlers
async (request, reply) => {
  await createUser(request.server.deps, input);
}
```

No framework, no decorators, easy testing (`createUser({ userRepo: fakeRepo, logger: silent, emailer: mock }, input)`).

### Container DI (Nest, tsyringe, awilix)

```ts
@Injectable()
class CreateUserUseCase {
  constructor(private userRepo: UserRepository, private logger: Logger) {}
  async execute(input: Input) { /* ... */ }
}
```

Use if the project is already on Nest or values the structure. Otherwise functional DI is lighter.

## Repository pattern

Interface in domain:

```ts
// domain/user-repository.ts
import type { User, UserId } from './user';

export interface UserRepository {
  findById(id: UserId): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  save(user: User): Promise<void>;
}
```

Implementation in infrastructure:

```ts
// infrastructure/db/prisma-user-repository.ts
import type { PrismaClient } from '@prisma/client';
import type { UserRepository } from '@/domain/user-repository';
import { User } from '@/domain/user';

export class PrismaUserRepository implements UserRepository {
  constructor(private prisma: PrismaClient) {}

  async findById(id: UserId): Promise<User | null> {
    const row = await this.prisma.user.findUnique({ where: { id } });
    return row ? this.toDomain(row) : null;
  }

  async save(user: User): Promise<void> {
    await this.prisma.user.upsert({
      where: { id: user.id },
      create: { ...user.toJSON() },
      update: { ...user.toJSON() },
    });
  }

  private toDomain(row: PrismaUser): User {
    return User.fromPersistence({
      id: row.id as UserId,
      email: row.email,
      name: row.name,
      createdAt: row.createdAt,
    });
  }
}
```

The `toDomain` mapper keeps Prisma types from leaking into the domain.

## Transactions

Owned by the use case, not the repository:

```ts
// application/transfer-funds.ts
export async function transferFunds(deps: Deps, input: Input) {
  await deps.db.$transaction(async (tx) => {
    const fromRepo = new PrismaAccountRepository(tx);
    const toRepo = new PrismaAccountRepository(tx);

    const from = await fromRepo.findById(input.fromId);
    const to = await toRepo.findById(input.toId);

    from.withdraw(input.amount);
    to.deposit(input.amount);

    await fromRepo.save(from);
    await toRepo.save(to);
  });
}
```

The use case opens the tx, creates repositories scoped to it. A single repository method opening its own tx can't be composed with others.

## Error handling — domain errors → HTTP

Throw domain errors in the use case; map to HTTP in middleware:

```ts
// domain/errors.ts
export class DomainError extends Error {
  constructor(message: string, public code: string) { super(message); }
}
export class EmailAlreadyUsedError extends DomainError {
  constructor(email: string) { super(`email already used: ${email}`, 'EMAIL_USED'); }
}
export class NotFoundError extends DomainError {
  constructor(entity: string, id: string) { super(`${entity} not found: ${id}`, 'NOT_FOUND'); }
}
```

```ts
// infrastructure/http/middlewares/error-handler.ts
app.setErrorHandler((err, request, reply) => {
  if (err instanceof NotFoundError) return reply.status(404).send({ code: err.code, message: err.message });
  if (err instanceof EmailAlreadyUsedError) return reply.status(409).send({ code: err.code, message: err.message });
  if (err instanceof z.ZodError) return reply.status(400).send({ code: 'VALIDATION', errors: err.errors });

  request.log.error({ err }, 'unexpected error');
  return reply.status(500).send({ code: 'INTERNAL', message: 'something went wrong' });
});
```

Client never sees a stack trace. Server log has everything.

## Environment configuration

Validate env at startup with zod — fail fast:

```ts
// infrastructure/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  PORT: z.coerce.number().int().positive().default(3000),
});

export const env = envSchema.parse(process.env);
```

The app refuses to start if env is wrong. Beats a runtime crash three hours after deploy.

## Monorepo

If using a monorepo (Turborepo, Nx, pnpm workspaces):

```
packages/
├── domain/                   # pure TS, no deps on infra
├── infrastructure/           # adapters
└── server/                   # composes domain + infra
apps/
└── api/                      # entry point
```

Domain has no runtime deps beyond TS. Infrastructure has Prisma/Express/etc. Server wires them together. Apps consume server.
