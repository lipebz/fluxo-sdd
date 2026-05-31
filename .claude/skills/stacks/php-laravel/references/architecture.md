---
title: PHP / Laravel — Architecture
stack: php-laravel
---

# Laravel Architecture

## Project layout (Laravel 11+)

```
app/
├── Console/
│   └── Commands/                # artisan commands
├── Http/
│   ├── Controllers/             # thin: validate → call action → respond
│   ├── Middleware/
│   ├── Requests/                # FormRequest classes (validation + authorization)
│   └── Resources/               # JsonResource (API output shaping)
├── Models/                      # Eloquent
├── Policies/                    # authorization logic per model
├── Providers/                   # service providers (bootstrapping)
├── Services/                    # business logic (when groups of methods cluster)
├── Actions/                     # single-action classes (modern convention)
├── Jobs/                        # queueable
├── Mail/                        # mailable classes
├── Events/                      # event objects
├── Listeners/                   # event listeners
├── Notifications/
├── Exceptions/                  # custom exception classes
└── Rules/                       # custom validation rules

bootstrap/
config/                          # config files (database, mail, queue, etc.)
database/
├── factories/
├── migrations/
└── seeders/
routes/
├── web.php                      # session-based (CSRF)
├── api.php                      # token-based (Sanctum/Passport)
├── console.php                  # closure-based artisan commands
└── channels.php                 # broadcasting channels
resources/
├── views/                       # Blade templates
├── js/                          # frontend assets if used
└── css/
tests/
├── Feature/                     # HTTP-level tests
└── Unit/                        # isolated tests
```

Laravel 11 removed `app/Http/Kernel.php`, `app/Exceptions/Handler.php`, and `app/Console/Kernel.php` — their config moved to `bootstrap/app.php`. Middleware, exception handling, and command scheduling are now configured there.

## Layers — Controller → Action/Service → Eloquent

### Modern convention: Action classes (single responsibility)

One class per business operation. Single public method (`handle`, `execute`, or `__invoke`).

```php
// app/Actions/CreateUser.php
namespace App\Actions;

use App\Models\User;
use App\Notifications\WelcomeEmail;
use Illuminate\Support\Facades\Hash;

class CreateUser
{
    public function handle(array $data): User
    {
        $user = User::create([
            'email' => $data['email'],
            'name' => $data['name'],
            'password' => Hash::make($data['password']),
        ]);

        $user->notify(new WelcomeEmail());

        return $user;
    }
}
```

Use from a controller:

```php
// app/Http/Controllers/UserController.php
namespace App\Http\Controllers;

use App\Actions\CreateUser;
use App\Http\Requests\CreateUserRequest;
use App\Http\Resources\UserResource;

class UserController extends Controller
{
    public function store(CreateUserRequest $request, CreateUser $action)
    {
        $user = $action->handle($request->validated());
        return (new UserResource($user))->response()->setStatusCode(201);
    }
}
```

Notes:
- FormRequest auto-validates and authorizes before the controller method runs.
- Action is auto-injected by the container.
- Resource shapes the response.
- Controller is 1-2 lines. As it should be.

### Service classes — when methods cluster

For features with multiple related operations (e.g., `BillingService::charge`, `refund`, `applyCredit`), a service class is fine. The line between Service and Action is fuzzy — pick a convention per project.

### Don't use repositories blindly

Eloquent is already a repository abstraction. Adding a `UserRepository` layer over `User::find()` adds ceremony without value in most cases. Repository pattern earns its place when:
- You'd swap the data source (DB → external API).
- You have complex queries that don't fit on the model.
- You're aggressively testing with fakes.

In a typical Laravel app, Action + Eloquent is enough.

## Routing

```php
// routes/api.php
use App\Http\Controllers\UserController;

Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('users', UserController::class);
    Route::post('users/{user}/promote', [UserController::class, 'promote']);
});
```

- `apiResource` generates the 5 standard REST routes (index, store, show, update, destroy).
- Group middleware to avoid repetition.
- Route model binding (`{user}` resolves to `User`) — use type-hinted parameters.

### Implicit binding with custom resolution

```php
Route::get('users/{user:uuid}', ...);
```

Or override on the model:

```php
class User extends Model
{
    public function getRouteKeyName(): string { return 'uuid'; }
}
```

## Eloquent — relationships and N+1

### Define relationships explicitly

```php
class Post extends Model
{
    public function author(): BelongsTo { return $this->belongsTo(User::class); }
    public function comments(): HasMany { return $this->hasMany(Comment::class); }
}
```

### Always eager-load when iterating

```php
// ❌ N+1
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name;  // separate query per post
}

// ✅
$posts = Post::with('author')->get();
foreach ($posts as $post) {
    echo $post->author->name;  // single join (or 2 queries via with)
}
```

Enable `Model::preventLazyLoading()` in dev/test to catch N+1 at runtime:

```php
// app/Providers/AppServiceProvider.php
public function boot(): void
{
    Model::preventLazyLoading(! $this->app->isProduction());
}
```

This makes lazy loading throw an exception in non-prod, forcing eager loading.

### Use scopes for reusable queries

```php
class Post extends Model
{
    public function scopePublished(Builder $q): void
    {
        $q->whereNotNull('published_at')->where('published_at', '<=', now());
    }
}

Post::published()->latest()->paginate(20);
```

## Validation — FormRequest

```php
// app/Http/Requests/CreateUserRequest.php
namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', User::class);
    }

    public function rules(): array
    {
        return [
            'email' => ['required', 'email', 'unique:users,email'],
            'name' => ['required', 'string', 'min:1', 'max:100'],
            'password' => ['required', 'string', 'min:8'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.unique' => 'This email is already in use.',
        ];
    }
}
```

When type-hinted in a controller method (`store(CreateUserRequest $request)`), Laravel automatically:
1. Resolves the request.
2. Authorizes (returns 403 if `authorize` is false).
3. Validates (returns 422 with errors if rules fail).
4. Hands the validated payload to the controller (`$request->validated()`).

## Authorization — Policy

```php
// app/Policies/PostPolicy.php
namespace App\Policies;

use App\Models\User;
use App\Models\Post;

class PostPolicy
{
    public function update(User $user, Post $post): bool
    {
        return $user->id === $post->author_id || $user->isAdmin();
    }
}
```

Use in controllers:

```php
public function update(UpdatePostRequest $request, Post $post)
{
    $this->authorize('update', $post);  // 403 if false
    // ...
}
```

Auto-discovered in Laravel 11 (no need to register in `AuthServiceProvider` if naming matches).

## Queues and Jobs

For anything async:

```php
// app/Jobs/SendWelcomeEmail.php
namespace App\Jobs;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable as QueueableTrait;

class SendWelcomeEmail implements ShouldQueue
{
    use Queueable, QueueableTrait;

    public function __construct(public User $user) {}

    public function handle(): void
    {
        $this->user->notify(new WelcomeEmail());
    }
}
```

Dispatch:

```php
SendWelcomeEmail::dispatch($user);
SendWelcomeEmail::dispatch($user)->onQueue('emails')->delay(now()->addMinutes(5));
```

Configure retries:

```php
class SendWelcomeEmail implements ShouldQueue
{
    public int $tries = 3;
    public int $backoff = 60; // seconds, or array [10, 30, 60]
}
```

## Configuration

- Never call `env()` outside config files. Config is cached in prod (`php artisan config:cache`); `env()` reads return null after cache.
- Read via `config('app.timezone')` not `env('APP_TIMEZONE')` in app code.
- Validate critical env values via a custom command at deploy time, or via `php artisan about`.

## Service Providers

Use a provider for:
- Binding interfaces to implementations (`$this->app->bind(Notifier::class, MailNotifier::class)`).
- Registering macros, event listeners, view composers.
- Configuring global behavior at boot.

Don't put business logic in providers — they're for wiring.

## Broadcasting and Real-time

For real-time, use Laravel Reverb (Laravel's own WS server in 11+), Pusher, or Soketi. Define channels in `routes/channels.php`:

```php
Broadcast::channel('orders.{orderId}', function (User $user, int $orderId) {
    return $user->orders()->where('id', $orderId)->exists();
});
```

Use `ShouldBroadcast` on events to push to clients.

## Anti-patterns

- **Business logic in models.** Models hold relationships and scopes. Methods like `User::createWithBilling()` should be a `CreateUserWithBilling` action.
- **Business logic in controllers.** Controller orchestrates HTTP, doesn't decide what to do.
- **Direct DB queries in views/blade.** All data passed from controller/view composer.
- **Returning Eloquent models from API endpoints.** Use Resources.
- **Edit a migration after merge.** Add a new one.
- **`->get()` inside a loop.** Eager load or restructure.
- **Validation inline in controller.** FormRequest scales.
- **Storing secrets in `.env.example`.** `.env.example` is committed; secrets aren't. Use placeholders.
