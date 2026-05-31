---
title: PHP / Laravel — Testing
stack: php-laravel
---

# Laravel Testing

## Stack

- **Pest** — modern, readable DSL. Default for new Laravel projects.
- **PHPUnit** — classic, still widely used. Pest is built on top.
- **Laravel testing helpers** — `actingAs`, `assertDatabaseHas`, `mock`, `fake`, etc.
- **Factories** — for generating test data.
- **`RefreshDatabase`** trait — wraps each test in a transaction that rolls back.

## Test types

| Type | Folder | What |
|---|---|---|
| Unit | `tests/Unit/` | Isolated logic — no Laravel boot. Plain PHP. |
| Feature | `tests/Feature/` | Full Laravel stack — HTTP, DB, queue. Most tests live here. |

In Laravel, "Feature" is the default. Pure unit tests are rare because most code touches Eloquent/cache/queue and benefits from integration testing.

## Pest feature test

```php
// tests/Feature/CreateUserTest.php
use App\Models\User;

it('creates a user via POST /users', function () {
    $admin = User::factory()->admin()->create();

    $response = $this->actingAs($admin)
        ->postJson('/api/users', [
            'email' => 'alice@example.com',
            'name' => 'Alice',
            'password' => 'super-secret-password',
        ]);

    $response->assertCreated()
        ->assertJsonFragment(['email' => 'alice@example.com']);

    expect(User::where('email', 'alice@example.com')->exists())->toBeTrue();
});

it('rejects duplicate email', function () {
    $admin = User::factory()->admin()->create();
    User::factory()->create(['email' => 'alice@example.com']);

    $response = $this->actingAs($admin)
        ->postJson('/api/users', [
            'email' => 'alice@example.com',
            'name' => 'Alice',
            'password' => 'super-secret-password',
        ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['email']);
});
```

## PHPUnit feature test

```php
// tests/Feature/CreateUserTest.php
namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreateUserTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_a_user(): void
    {
        $admin = User::factory()->admin()->create();

        $response = $this->actingAs($admin)
            ->postJson('/api/users', [
                'email' => 'alice@example.com',
                'name' => 'Alice',
                'password' => 'super-secret-password',
            ]);

        $response->assertCreated();
        $this->assertDatabaseHas('users', ['email' => 'alice@example.com']);
    }
}
```

## Database isolation — RefreshDatabase

```php
// pest config (tests/Pest.php)
uses(Tests\TestCase::class, Illuminate\Foundation\Testing\RefreshDatabase::class)
    ->in('Feature');
```

`RefreshDatabase` wraps each test in a transaction, rolls back at the end. Fast. Clean state per test.

Alternative: `DatabaseMigrations` runs migrations per test (slow), `DatabaseTransactions` similar to RefreshDatabase.

Use SQLite in-memory for unit-ish speed when DB-specific features aren't needed:

```env
# .env.testing or phpunit.xml
DB_CONNECTION=sqlite
DB_DATABASE=:memory:
```

For tests that need PostgreSQL features (JSON columns, full-text search), use a real test DB.

## Factories

```php
// database/factories/UserFactory.php
namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'email' => $this->faker->unique()->safeEmail(),
            'name' => $this->faker->name(),
            'password' => Hash::make('password'),
            'email_verified_at' => now(),
        ];
    }

    public function admin(): static
    {
        return $this->state(fn () => ['is_admin' => true]);
    }

    public function unverified(): static
    {
        return $this->state(fn () => ['email_verified_at' => null]);
    }
}
```

Usage:

```php
User::factory()->create();                          // one user
User::factory()->count(5)->create();                // five users
User::factory()->admin()->create();                 // admin
User::factory()->admin()->unverified()->create();   // composed states
User::factory()->has(Post::factory()->count(3))->create();  // with posts
```

Factories are the canonical way to set up test data. Avoid hand-creating rows with `DB::insert`.

## HTTP assertions

```php
$response->assertOk();                 // 200
$response->assertCreated();            // 201
$response->assertNoContent();          // 204
$response->assertForbidden();          // 403
$response->assertNotFound();           // 404
$response->assertStatus(418);          // exact
$response->assertJson([...]);          // exact JSON match (subset OK)
$response->assertJsonFragment([...]);  // fragment
$response->assertJsonMissing([...]);
$response->assertJsonValidationErrors(['email']);
$response->assertJsonPath('data.0.id', 1);
$response->assertJsonCount(5, 'data');
$response->assertRedirect('/users');
$response->assertSee('Welcome');       // for HTML responses
```

## Database assertions

```php
$this->assertDatabaseHas('users', ['email' => 'a@b.com']);
$this->assertDatabaseMissing('users', ['email' => 'gone@b.com']);
$this->assertDatabaseCount('users', 5);
$this->assertSoftDeleted($user);
```

## Mocking — Mockery

```php
$mock = $this->mock(PaymentGateway::class);
$mock->shouldReceive('charge')
    ->once()
    ->with(100, 'USD')
    ->andReturn(['id' => 'ch_123', 'status' => 'succeeded']);
```

For services bound in the container, this swaps the resolved instance. Use sparingly — prefer real implementations for Eloquent/cache, mock for external APIs.

### Fake everything

Laravel has built-in fakes for many subsystems:

```php
Queue::fake();
Mail::fake();
Notification::fake();
Event::fake();
Storage::fake('local');
Http::fake();
Bus::fake();
```

After faking, assertions:

```php
Mail::assertSent(WelcomeEmail::class, fn ($m) => $m->hasTo('a@b.com'));
Notification::assertSentTo($user, OrderShipped::class);
Queue::assertPushed(SendWelcomeEmail::class);
Http::assertSent(fn ($req) => $req->url() === 'https://api.x.com/v1');
```

Fakes are the default for testing external interactions. Don't actually send mail in tests.

## Time control

```php
$this->travel(5)->minutes();
$this->travelTo(now()->addDay());
$this->freezeTime();

// ... do stuff ...

$this->travelBack();
```

For testing scheduled tasks, expirations, time-sensitive logic.

## Test naming

Pest is readable in plain English:

```php
it('creates a user with the given email and name', ...);
it('rejects when the email is already used', ...);
it('returns 404 for a missing order', ...);
```

PHPUnit method names should be snake_case and explicit:

```php
public function test_it_creates_a_user_with_the_given_email_and_name(): void { /* ... */ }
```

Both styles read the same. The point: the name describes the scenario, not the implementation.

## What to test

### Test
- HTTP endpoints (request → response, side effects).
- FormRequest validation rules.
- Policies (`->authorize()`).
- Actions and services (business logic).
- Eloquent scopes and complex queries.
- Jobs (via `Queue::fake()` and `Bus::dispatched()`).
- Mailables (via `Mail::fake()` and content assertions).

### Don't test
- Eloquent itself.
- Laravel framework code.
- Trivial accessors/casts.

## Queue tests

```php
it('queues a welcome email after user creation', function () {
    Queue::fake();
    User::factory()->create();  // triggers an observer that dispatches
    Queue::assertPushed(SendWelcomeEmail::class);
});
```

For testing the job itself:

```php
it('sends the email', function () {
    Mail::fake();
    $user = User::factory()->create();
    (new SendWelcomeEmail($user))->handle();
    Mail::assertSent(WelcomeMail::class, fn ($m) => $m->hasTo($user->email));
});
```

## Authentication helpers

```php
$this->actingAs($user);                   // logs in as $user for the next request
$this->actingAs($user, 'api');            // specific guard
$this->actingAs($user)->getJson('/me');   // chained
```

## Parallel testing

Pest and PHPUnit (with `paratest`) support parallel runs:

```bash
php artisan test --parallel
```

Each process gets its own DB (`tests_1`, `tests_2`, ...). Speeds up large suites significantly.

## Anti-patterns

- **Hitting the real network.** Use `Http::fake()` always.
- **`Mail::raw('...')->to(...)`** in tests without `Mail::fake()`. Sends real email if not faked.
- **Leaving uncleaned global state.** Cache, queue, storage. `RefreshDatabase` only handles the DB.
- **One test that does 10 things.** Split. The name should describe one scenario.
- **Tests that depend on each other.** Each test must be independent. `RefreshDatabase` enforces this for the DB; you enforce it for everything else.
- **`->dump()` or `->dd()` left in tests.** Catch in CI lint.
- **Skipping `assertDatabaseHas` after `->postJson`** that should persist data. Always assert the side effect, not just the response.
- **Faking what you should fake; not faking what you should.** Always fake external services. Don't fake Eloquent (use real DB with `RefreshDatabase`).
- **`actingAs($user)` without confirming the user can do the action.** Test both success and forbidden cases — policies matter.
