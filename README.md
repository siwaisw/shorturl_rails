# Technical Documentation
Build a URL shortener like https://bit.ly

This web application is built with **Ruby on Rails**.

## Specifications and Requirements
1. Web application
2. A Text box in the landing page to put the long URL in
3. Should only shorten valid URLs
4. A button that initiates the URL shortening when clicked
5. A feedback view to display the shortened URL
6. Unit tests
7. User-friendly and intuitive UI/UX
8. Mobile responsive

## Extended Specs
1. Links will expire after a default timespan with option for users to specify expiration time
2. Shortened links should not be deducible
3. Usage analytics and logging

# System Design Considerations
Assume more redirect requests as compared to creation of new short URLs, therefore system will be read heavy. Assume the system gets 1000 new shortened URL requests each month with each shortened URL redirecting 20 times.

## Traffic
- **New URL creation (writes):** 1,000 requests/month ÷ 2,592,000 seconds/month ≈ **0.0004 req/sec**
- **URL redirects (reads):** 1,000 URLs × 20 redirects = 20,000 requests/month ÷ 2,592,000 ≈ **0.008 req/sec**
- **Read-to-write ratio:** 20:1 — the system is read-heavy
- **Peak load estimate (10× average):** ~0.08 read req/sec, ~0.004 write req/sec

## Storage
Default storage for each shortened URL is 1 year.

Estimated size per URL record:

| Field        | Size       |
|--------------|------------|
| Short key    | 7 bytes    |
| Long URL     | ~100 bytes |
| User ID      | 4 bytes    |
| Created at   | 8 bytes    |
| Expires at   | 8 bytes    |
| Click count  | 4 bytes    |
| **Total**    | **~131 bytes** (≈ 500 bytes with indexes and row overhead) |

- **After 1 year:** 1,000 URLs/month × 12 months = 12,000 records × 500 bytes ≈ **6 MB**
- **After 5 years:** 60,000 records × 500 bytes ≈ **30 MB**

Storage requirements are minimal at this scale.

## Bandwidth
- **Incoming (writes):** 1,000 req/month × ~400 bytes (long URL + headers) ≈ **400 KB/month**
- **Outgoing (reads/redirects):** 20,000 req/month × ~500 bytes (redirect response + headers) ≈ **10 MB/month**
- **Total monthly bandwidth:** ~10.4 MB/month ≈ **~4 bytes/sec** average throughput — well within standard limits

## Memory
Applying the 80/20 rule: 20% of URLs will account for 80% of redirect traffic. Caching the most frequently accessed URLs avoids repeated database lookups.

- **Active URL pool (1-year retention):** ~12,000 records
- **Cache target (top 20%):** 12,000 × 20% = 2,400 records × 500 bytes ≈ **1.2 MB**

A small in-memory cache (e.g. Redis) of ~5 MB would comfortably serve the hot URL set with significant headroom.

## Database Design
A relational (SQL) database is used. The schema consists of two core tables:

**`users` table**

| Column       | Type         | Notes                        |
|--------------|--------------|------------------------------|
| id           | INTEGER (PK) | Auto-increment               |
| email        | VARCHAR(255) | Unique, for login/analytics  |
| created_at   | TIMESTAMP    |                              |

**`short_urls` table**

| Column       | Type         | Notes                              |
|--------------|--------------|------------------------------------|
| id           | INTEGER (PK) | Auto-increment                     |
| short_key    | VARCHAR(10)  | Unique encoded key, indexed        |
| original_url | TEXT         | The full original URL              |
| user_id      | INTEGER (FK) | References users(id), nullable     |
| click_count  | INTEGER      | Default 0                          |
| created_at   | TIMESTAMP    |                                    |
| expires_at   | TIMESTAMP    | Default: 1 year from created_at    |

A unique index on `short_key` ensures fast O(1) lookups on every redirect.

> **Scaling note:** At 1,000 new URLs/month a relational database (PostgreSQL or MySQL) is entirely sufficient. However, if request volume grows to **10 million or more new URL requests**, the write throughput and horizontal scaling limits of SQL become a bottleneck. At that point, migrating to a **NoSQL store** (such as DynamoDB, Cassandra, or Redis with persistence) is strongly recommended. NoSQL databases offer schema-free flexibility, built-in horizontal sharding, and sub-millisecond read performance at scale, which aligns well with the read-heavy nature of a URL shortener.

## Encoding the Original URL
To generate a short, non-deducible key for each URL:

1. **Base62 encoding of a unique ID:** Take the auto-incremented database ID and encode it using Base62 (characters `a–z`, `A–Z`, `0–9`). A 7-character Base62 string yields 62⁷ ≈ 3.5 trillion unique combinations — sufficient for enormous scale.
2. **Hashing approach (alternative):** Compute an MD5 or SHA-256 hash of the long URL, then take the first 7 characters of the Base62-encoded digest. This is deterministic (same URL always produces the same key) but requires collision detection.
3. **Recommended approach for this project:** Use Base62 encoding of the auto-increment ID. It is simple, collision-free by design, and the sequential nature is not exposed because the encoded string appears random to end users.

Example: ID `12345` → Base62 → `"3d7"` (padded to 7 chars: `"0003d7X"`). The short URL becomes `https://shorturl.app/0003d7X`.

## REST API Design

The API is versioned and served under `/api/v1/`. The public redirect endpoint lives at the root level (`/:key`) since it is the primary read path and must remain as short as possible.

**Base URL:** `https://shorturl.app`

**Authentication:** All `/api/v1/` endpoints require a Bearer token in the `Authorization` header.
```
Authorization: Bearer <api_key>
```

The public `GET /:key` redirect endpoint requires no authentication.

---

### Endpoint Overview

| Method   | Endpoint              | Description                          | Auth |
|----------|-----------------------|--------------------------------------|------|
| `POST`   | `/api/v1/urls`        | Create a new short URL               | Yes  |
| `GET`    | `/api/v1/urls/:key`   | Retrieve URL details and analytics   | Yes  |
| `PATCH`  | `/api/v1/urls/:key`   | Update the expiry date               | Yes  |
| `DELETE` | `/api/v1/urls/:key`   | Delete a short URL                   | Yes  |
| `GET`    | `/:key`               | Redirect to the original URL         | No   |

---

### POST /api/v1/urls — Create a short URL

**Request body** (`application/json`)
```json
{
  "url": "https://example.com/very/long/path?utm_source=email",
  "expires_at": "2027-01-01T00:00:00Z"
}
```
> `expires_at` is optional. Defaults to 1 year from the time of creation.

**Response `201 Created`**
```json
{
  "short_key":    "00003d7",
  "short_url":    "https://shorturl.app/00003d7",
  "original_url": "https://example.com/very/long/path?utm_source=email",
  "click_count":  0,
  "created_at":   "2026-05-30T12:00:00Z",
  "expires_at":   "2027-05-30T12:00:00Z"
}
```

---

### GET /api/v1/urls/:key — Retrieve URL details

**Response `200 OK`**
```json
{
  "short_key":    "00003d7",
  "short_url":    "https://shorturl.app/00003d7",
  "original_url": "https://example.com/very/long/path",
  "click_count":  142,
  "created_at":   "2026-05-30T12:00:00Z",
  "expires_at":   "2027-05-30T12:00:00Z"
}
```

---

### PATCH /api/v1/urls/:key — Update expiry date

**Request body** (`application/json`)
```json
{
  "expires_at": "2028-06-01T00:00:00Z"
}
```

**Response `200 OK`** — returns the updated resource in the same shape as the `GET` response.

---

### DELETE /api/v1/urls/:key — Delete a short URL

**Response `204 No Content`** — empty body on success.

---

### GET /:key — Redirect (public)

**Response `301 Moved Permanently`**
```
Location: https://example.com/very/long/path
```

If the link has expired the server responds with `410 Gone` instead of redirecting.

---

### Error Response Format

All errors return a consistent JSON body:
```json
{
  "error": {
    "code":    "not_found",
    "message": "Short URL not found."
  }
}
```

| HTTP Status | Code                   | When it occurs                                      |
|-------------|------------------------|-----------------------------------------------------|
| `400`       | `invalid_url`          | `url` field is not a valid HTTP/HTTPS URL           |
| `401`       | `unauthorized`         | Missing or invalid Bearer token                     |
| `404`       | `not_found`            | `:key` does not match any record                    |
| `410`       | `link_expired`         | Link exists but `expires_at` is in the past         |
| `422`       | `validation_error`     | Request body is missing required fields             |
| `429`       | `rate_limit_exceeded`  | Too many requests (see rate limiting below)         |

---

### Who Uses the API?

The web application itself does **not** consume the `/api/v1/` endpoints. It uses standard Rails server-rendered form submissions, when a user clicks "Shorten URL" the browser sends a `POST /short_urls` form request, the controller saves the record and redirects, and Rails renders the next page. That flow goes directly through the controller and model with no HTTP round-trip to the API layer.

The REST API is designed for **external consumers**:

| Consumer | Endpoint used |
|---|---|
| Web app (browser form submission) | `POST /short_urls` and `GET /:key` directly via Rails controllers |
| Mobile app | `POST /api/v1/urls`, `GET /api/v1/urls/:key` (JSON) |
| Third-party developer / integration | `POST /api/v1/urls` with a Bearer API key |
| Browser extension | `POST /api/v1/urls` (JSON) |

If the frontend were ever rebuilt as a React or Vue SPA, it would then consume the API but that would be a separate architectural decision from the current server-rendered implementation.

---

### Rate Limiting

To protect the service, API requests are limited per API key:

- **100 requests / minute** per key
- Every response includes the following headers:

| Header                  | Description                                   |
|-------------------------|-----------------------------------------------|
| `X-RateLimit-Limit`     | Maximum requests allowed per window           |
| `X-RateLimit-Remaining` | Requests remaining in the current window      |
| `X-RateLimit-Reset`     | Unix timestamp when the window resets         |

When the limit is exceeded the server responds with `429 Too Many Requests` and the `Retry-After` header indicating how many seconds to wait.

## DB Cleanup
Expired URLs should be removed periodically to reclaim storage and keep the database performant.

**Strategy:**
- Use a **soft delete** first: add a `deleted_at` timestamp column. Expired or user-deleted URLs are marked rather than immediately removed, preserving audit trails.
- A background job (e.g. a Rails `ActiveJob` with a Sidekiq worker, or a `cron`-scheduled Rake task) runs during **off-peak hours** (e.g. nightly at 2:00 AM) to hard-delete records where `expires_at < NOW()` and `deleted_at IS NOT NULL`.
- The cleanup query targets the indexed `expires_at` column to keep the operation efficient even as the table grows.
- Deletions are batched (e.g. 1,000 rows at a time) to avoid long-running transactions that lock the table and degrade redirect performance.

Example Rake task pseudocode:
```ruby
# lib/tasks/cleanup.rake
task cleanup_expired_urls: :environment do
  ShortUrl.where("expires_at < ?", Time.current).in_batches(of: 1000, &:delete_all)
end
```

---

## Ruby on Rails Setup

* **Ruby version:** 3.x (see `.ruby-version`)
* **Rails version:** 8.x

* **System dependencies:** PostgreSQL, Redis (for caching)

* **Configuration:** Copy `.env.example` to `.env` and fill in database credentials

* **Database creation:** `rails db:create`

* **Database initialization:** `rails db:migrate db:seed`

* **Services:** Redis for caching hot URLs; Sidekiq or AWS Eventbridge for background cleanup jobs

* **Deployment instructions:** Deploy via Heroku, Render, or Fly.io using the provided `Procfile`

---

## Unit Tests

The test suite is written with **RSpec** and uses the following supporting libraries:

| Library | Purpose |
|---|---|
| `rspec-rails` | Core test framework integrated with Rails |
| `factory_bot_rails` | Test data factories — creates model instances without fixture files |
| `shoulda-matchers` | One-line matchers for common Rails validations and associations |

### Running the suite

```bash
# Run all specs
bundle exec rspec

# Run a specific file
bundle exec rspec spec/models/short_url_spec.rb

# Run a single example by line number
bundle exec rspec spec/requests/sessions_spec.rb:42
```

### Test coverage

**Model specs** (`spec/models/`)

| Spec file | What is covered |
|---|---|
| `short_url_spec.rb` | `encode_base62` output for edge-case IDs, `before_create` expiry default, `after_create` key assignment, URL format validation, `belongs_to :user optional` |
| `user_spec.rb` | `has_secure_password`, password length, `#authenticate`, email presence / format / case-insensitive uniqueness, `before_save` email downcasing, `dependent: :nullify` on short_urls |

**Request specs** (`spec/requests/`)

| Spec file | What is covered |
|---|---|
| `short_urls_spec.rb` | `POST /short_urls` with valid, blank, non-HTTP, and plain-string URLs; `GET /:key` for active, expired, and unknown keys including click-count increment |
| `users_spec.rb` | `GET /signup` (guest and already-logged-in), `POST /signup` — valid creation, duplicate email, short password, mismatched confirmation, email case normalisation |
| `sessions_spec.rb` | `GET /login` (guest and already-logged-in), `POST /login` — correct credentials, wrong password, unknown email, case-insensitive matching, whitespace trimming; `DELETE /logout` session clearing and post-logout protection |

### Factories

Factories live in `spec/factories/`. The `short_url` factory includes an `:expired` trait that back-dates `expires_at` to yesterday — useful for testing redirect behaviour on stale links.

---

## Rails Logger

The application uses Rails' built-in `ActiveSupport::TaggedLogging` logger. Every log line is tagged with the **request UUID** so all messages belonging to one HTTP request can be correlated with a single grep.

### Log levels

Rails provides six levels. Use the right one so production operators can set a threshold without losing critical signal:

| Level | When to use |
|---|---|
| `debug` | Detailed internal state — fires only in development. Always use **block syntax** (`logger.debug { "..." }`) so the string is never built if the level is inactive. |
| `info` | Normal, expected business events: URL created, user registered, login, logout, redirect served. |
| `warn` | Recoverable problems: validation failure, expired link accessed, failed login attempt, unauthenticated access. |
| `error` | Something failed but the app kept running — unexpected exceptions, third-party service errors. |
| `fatal` | Causes a crash and requires immediate intervention. |
| `unknown` | Catch-all for messages that cannot be classified. |

### Environment configuration

| Environment | Log level | Extra behaviour |
|---|---|---|
| **development** | `debug` | Tagged with `request_id`; custom formatter adds a human-readable timestamp prefix: `[YYYY-MM-DD HH:MM:SS] LEVEL  message` |
| **test** | `warn` | Silences `debug` and `info` so `rspec` output stays readable |
| **production** | `info` (overridable via `RAILS_LOG_LEVEL` env var) | Tagged with `request_id`; writes to STDOUT via `ActiveSupport::TaggedLogging.logger` for capture by a log aggregator |

### What this application logs

All custom log messages use a `[Tag]` prefix and `key=value` pairs so they are machine-parseable:

```
[2026-05-30 12:00:01] INFO   [ShortUrl] Created short_key=0000007 expires_at=2027-05-30T12:00:01Z user_id=3
[2026-05-30 12:00:02] WARN   [ShortUrl] Expired link accessed short_key=0000002 expired_at=2025-01-01T00:00:00Z ip=203.0.113.5
[2026-05-30 12:00:03] INFO   [Session]  Login user_id=3 ip=203.0.113.5
[2026-05-30 12:00:04] WARN   [Session]  Failed login ip=203.0.113.5 user_found=false
[2026-05-30 12:00:05] INFO   [User]     Registered user_id=4 ip=203.0.113.5
[2026-05-30 12:00:06] WARN   [Auth]     Unauthenticated access attempt action=dashboard#index ip=203.0.113.5
[2026-05-30 12:00:07] DEBUG  [Dashboard] Loaded user_id=3 total_links=12 active=10 total_clicks=84
```

### What is never logged

- **Passwords** — never referenced in any log call.
- **Email addresses** — `user_id` is used for identity in all custom log messages. Rails' built-in `filter_parameters` already masks `:email` and `:passw` in the automatic request parameter lines.
- **Full original URLs in failure paths** — avoids leaking potentially sensitive query strings or tokens embedded in URLs.
- **Raw authentication tokens or session contents.**

### Block syntax — why it matters

```ruby
# Bad — the string is built even when the log level would discard it
logger.debug "Processing order #{expensive_method}"

# Good — the block is only evaluated if debug logging is active
logger.debug { "Processing order #{expensive_method}" }
```

In production at `INFO` level, every `debug` block is skipped entirely with zero string allocation cost. All `logger.debug` calls in this codebase use block syntax for this reason.
