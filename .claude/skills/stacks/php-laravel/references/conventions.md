---
title: PHP / Laravel — Conventions
stack: php-laravel
---

# PHP / Laravel Conventions

## File and class naming

| Item | Convention | Example |
|---|---|---|
| Class file | PascalCase, matches class | `UserController.php` |
| Class | PascalCase | `UserController`, `CreateUserAction` |
| Method | camelCase | `getUserById`, `updateProfile` |
| Variable | camelCase | `$currentUser`, `$orderItems` |
| Property | camelCase | `public string $email` |
| Constant | UPPER_SNAKE_CASE | `const MAX_ATTEMPTS = 5` |
| DB table | snake_case plural | `users`, `order_items` |
| DB column | snake_case | `created_at`, `user_id` |
| Migration file | timestamped + descriptive | `2026_05_29_120000_create_users_table.php` |
| Route name | dot-separated, kebab inside | `users.show`, `orders.line-items.destroy` |
| Blade view | dot-separated lowercase | `users.show`, `partials.header` |
| Config key | snake_case | `config('app.timezone')` |

### Class naming conventions specific to Laravel

| Type | Suffix | Example |
|---|---|---|
| Controller | `Controller` | `UserController` |
| Resource | `Resource` | `UserResource`, `OrderCollection` |
| FormRequest | `Request` | `CreateUserRequest`, `UpdateOrderRequest` |
| Action | (no suffix or `Action`) | `CreateUser`, `CreateUserAction` |
| Service | `Service` | `BillingService` |
| Policy | `Policy` | `PostPolicy` |
| Job | (verb-based, no suffix) | `SendWelcomeEmail`, `ProcessPayment` |
| Event | (verb past or noun) | `UserRegistered`, `OrderPaid` |
| Listener | (verb-based) | `SendOrderConfirmation` |
| Exception | `Exception` | `OrderNotFoundException` |
| Mail | `Mail` or none | `OrderShippedMail` |
| Notification | `Notification` | `OrderShippedNotification` |
| Middleware | (PascalCase, descriptive) | `EnsureUserIsAdmin` |

Adopt one Action convention per project (`CreateUser` or `CreateUserAction`). Don't mix.

## Method shape — controller

```php
public function store(CreateUserRequest $request, CreateUser $action): JsonResponse
{
    $user = $action->handle($request->validated());

    return (new UserResource($user))
        ->response()
        ->setStatusCode(201);
}
```

Stick to this shape: type-hint request, type-hint action/service via DI, return a Resource. 1-3 lines.

## Type hints — everywhere

PHP 8+ has strong type system. Use it:

```php
public function handle(array $data): User { /* ... */ }
public function find(int $id): ?User { /* ... */ }
public function send(User $user, array $items): void { /* ... */ }
```

- **Return types are mandatory** — never omit. `void`, `?Type`, `iterable`, `static`, etc.
- **Parameter types** — always.
- **Property types** — `public string $email`, `protected ?int $age = null`.
- **`declare(strict_types=1);`** at top of every PHP file. Stops silent type coercion.

```php
<?php

declare(strict_types=1);

namespace App\Actions;
// ...
```

## Eloquent conventions

### Casts in `protected $casts`

```php
protected $casts = [
    'email_verified_at' => 'datetime',
    'is_admin' => 'boolean',
    'metadata' => 'array',
    'role' => UserRole::class,  // enum cast
];
```

Casts ensure types are correct on read. Without casts, dates are strings, booleans are 0/1.

### `$fillable` vs `$guarded`

Pick one per project. `$fillable` is safer (allow-list), `$guarded = []` is convenient but lets through anything.

```php
protected $fillable = ['email', 'name', 'password'];
```

### Don't define `$dates` (deprecated)

Use casts.

### Relationship methods return their type

```php
public function author(): BelongsTo
{
    return $this->belongsTo(User::class);
}
```

Type hint helps IDE and static analysis.

## Configuration — env vs config

Never use `env()` outside config files:

```php
// ❌ in app code
$timezone = env('APP_TIMEZONE');  // null in production after config:cache

// ✅
$timezone = config('app.timezone');
```

Add to a `config/` file:

```php
// config/services.php
'stripe' => [
    'key' => env('STRIPE_KEY'),
    'secret' => env('STRIPE_SECRET'),
],
```

Then:

```php
$key = config('services.stripe.key');
```

## Error handling

### Throw exceptions, catch globally

```php
// app/Exceptions/OrderNotFoundException.php
namespace App\Exceptions;

use RuntimeException;

class OrderNotFoundException extends RuntimeException
{
    public function __construct(public string $orderId)
    {
        parent::__construct("Order not found: {$orderId}");
    }
}
```

Render with `bootstrap/app.php` exception config (Laravel 11):

```php
->withExceptions(function (Exceptions $exceptions) {
    $exceptions->render(function (OrderNotFoundException $e) {
        return response()->json(['error' => 'not_found', 'message' => $e->getMessage()], 404);
    });
})
```

### `abort()` for HTTP-shaped errors

```php
abort(404, 'Order not found');
abort_unless($user->canEdit($order), 403);
```

### Validation errors are auto-handled

FormRequest failures return 422 with errors in `errors` key. No try/catch needed.

## Resources — shaping API output

```php
// app/Http/Resources/UserResource.php
namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id,
            'email' => $this->email,
            'name' => $this->name,
            'created_at' => $this->created_at?->toIso8601String(),
            // never expose password, internal flags, etc.
        ];
    }
}
```

For collections, use `UserResource::collection($users)` or a custom `UserCollection`.

### Conditional fields

```php
'admin_flag' => $this->when($request->user()->isAdmin(), $this->is_admin),
```

## Database conventions

### Migrations

```php
public function up(): void
{
    Schema::create('users', function (Blueprint $table) {
        $table->id();
        $table->string('email')->unique();
        $table->string('name');
        $table->string('password');
        $table->timestamp('email_verified_at')->nullable();
        $table->timestamps();
        $table->softDeletes();  // if soft-deleting
    });
}

public function down(): void
{
    Schema::dropIfExists('users');
}
```

- Always implement `down()` — even if you never expect to rollback. Documents the change.
- `$table->id()` for autoincrement BIGINT. `$table->uuid('id')->primary()` for UUID.
- Foreign keys: `$table->foreignId('user_id')->constrained()->cascadeOnDelete()`.
- Indexes on frequently-queried columns: `$table->index('email')`.

### Avoid `down()` that drops user data unnecessarily

If a migration adds a column, `down()` removes the column. Fine. If a migration restructures data, `down()` should restore — but in practice, rollbacks past production are rare. Documenting the data path is enough.

### Index ID + timestamp combos

For `where('user_id', X)->orderBy('created_at')` patterns, compound index helps:

```php
$table->index(['user_id', 'created_at']);
```

## Dependency injection

Always inject via constructor (for classes) or method (for controllers):

```php
class BillingService
{
    public function __construct(
        private readonly PaymentGateway $gateway,
        private readonly LoggerInterface $logger,
    ) {}
}
```

- `readonly` (PHP 8.1+) for properties that don't change after construction.
- Don't `app()->make(BillingService::class)` inside methods — that's service location, not injection.

## Pest vs PHPUnit

Pest is built on PHPUnit, adds a more readable DSL. Both work; pick one per project.

```php
// Pest
it('creates a user', function () {
    $user = User::factory()->create(['email' => 'a@b.com']);
    expect($user->email)->toBe('a@b.com');
});

// PHPUnit
public function test_it_creates_a_user(): void
{
    $user = User::factory()->create(['email' => 'a@b.com']);
    $this->assertSame('a@b.com', $user->email);
}
```

See `testing.md` for the full pattern.

## Anti-patterns

- **`Model::find($id)->something()`** without null check. Use `findOrFail()` or check.
- **`Auth::user()->something()`** in middleware/route closures without guarantee user exists. Use the typed `$request->user()` or check.
- **`DB::raw()` with user input.** Always parameterize. `DB::raw("WHERE name = '{$input}'")` is SQL injection.
- **`env()` in app code.** Use `config()`. Config is cached; env reads return null after.
- **Suppressing exceptions with `@`.** Never. Catch, log, decide.
- **Massive controllers.** If a controller has more than ~7 methods or any method is more than ~15 lines, extract to actions/services.
- **`$request->all()`** into `User::create($request->all())`. Mass-assignment bug magnet. Use `validated()` from FormRequest.
- **Business logic in service providers.** Providers wire; they don't run logic.
- **Forgetting `$fillable` or `$guarded`** on a model with `create()`/`update()`. Mass assignment vulnerability.
- **Loops with queries.** N+1 strikes. Eager load.
