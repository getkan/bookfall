# Backend specification

## Scope and ownership

Subproject ID: **BACKEND**. Provide the Rails API for one shared bookclub
timeline and admin-authorized book management, with a Users table for ownership.
Non-admin user functionality is outside this project's current scope.
[Roadmap](ROADMAP.md) and [tasks](TASKS.md) track its independent lifecycle,
Stage 2 authorized 2026-10-24. [Deployment](../SPEC.md) follows completion of both apps.

The accepted [shared timeline layout](../BOOKEVENT_TIMELINE_LAYOUT_PLAN.md)
replaces event-count pagination and the proportional-gap/slider design.
This SPEC owns the API/data requirements used by the
[frontend](../frontend/SPEC.md); the shared layout owns cross-app layout rules.

## Requirements

### BACKEND-1: Books with embedded reviews

The user-selected logical tables replace the former separate Admin and Review
models and date-only Book fields. Remaining SQL naming, defaults,
indexes, and Rails mapping are Stage 2 design work after open requirements settle.

| Books field | Required type/constraint |
| --- | --- |
| `id` | Integer, unique identity |
| `user_id` | Nullable string placeholder; no foreign key or association for now |
| `title` | String |
| `author` | String |
| `started_at` | Timestamp |
| `finished_at` | Nullable timestamp |
| `rating` | Nullable integer, 1 through 5 when present |
| `review` | Nullable string |

- Rating and review belong directly to Books; there is no separate Review table.
- Null `finished_at` means in progress; completion cannot precede `started_at`.
  Rating and review may be absent, including for completed books.
- `user_id` is an opaque nullable string placeholder, not a Users foreign key.
  Do not resolve it to a username or implement ownership behavior. The reader
  label source is deferred to frontend integration; do not fabricate one.
- All book writes, including rating/review writes, are admin-only.
  This supersedes the prior seed-only review policy. An independent review
  endpoint is not required merely because the fields are now writable.

### BACKEND-2: Users, authentication and book API

| Users field | Required type/constraint |
| --- | --- |
| `id` | Integer, unique identity |
| `username` | String |
| `password` | Logical password input; salted, protected hash at rest |
| `is_admin` | Boolean |

- Users replaces the separate Admin model. Implement only the admin account
  functionality in current scope; no ordinary-user registration, management,
  or write workflows. Admin provisioning and username uniqueness still need
  design decisions. Future roles are not authorization to implement them now.
- Never store plaintext or reversibly encrypted passwords. Proposed Rails
  mapping: virtual `password` input and bcrypt `password_digest` storage through
  `has_secure_password`; confirm the physical column mapping in Stage 2.
- `POST /login` returns `{ "token": "..." }` for valid credentials; invalid
  credentials and missing/invalid authentication return 401.
- Carry forward the planned Rails `generates_token_for :api_access` policy
  onto User: signed with `secret_key_base`, expiring after 12 hours and bound
  to `password_salt`. No refresh tokens or server-side denylist. Authorization
  must check the user's current `is_admin`; role-change behavior needs tests.
- `GET /books`, `GET /books/:id`, `POST /books`, `PATCH /books/:id`, and
  `DELETE /books/:id` require `Authorization: Bearer <token>`. Show includes
  the review only for a completed book. Define response/error schemas in
  Stage 2; validation and missing-record failures must be explicit.
- Login rate limiting must be implemented and tested before production;
  the policy remains a Stage 2 design-review decision.

### BACKEND-3: Persisted book events, rank and revision consistency

| BookEvents field | Required type/constraint |
| --- | --- |
| `id` | Integer, unique identity |
| `book_id` | Foreign key to Books |
| `type` | `START` or `FINISH` |
| `date` | Timestamp |
| `start_rank` | Integer from 1 through 12, inclusive |

- BookEvents is now a SQL table. Preserve one START and, only if completed,
  one FINISH event per book, unique by `(book_id, type)`, synchronized with
  Books `started_at`/`finished_at`. Independent event editing is not assumed.
- Both events must share the book's rank across date spans. The requested
  bounded rank conflicts with the shared layout's dense chronological rank
  ordered by start time and book identity. The 1..12 bound is approved;
  assignment/reuse and deterministic tie order are explicitly deferred to
  frontend implementation. Cycling after 12 is not approved. This is not a
  backend Stage 1 decision blocker; keep the 1..12 storage/API constraint and
  pair consistency, without inventing an allocator or placeholder default.
  Record any later backend contract changes as a cross-subproject dependency.
- The shared layout uses the display term FINISHED; the selected stored event
  type is FINISH. Define API/display mapping explicitly. Rails reserves `type`
  for single-table inheritance; retain the requested name with an explicit
  non-STI mapping in Stage 2 rather than renaming it silently.
- Publish event data, ranks, and timeline bounds as one consistent revision.
  Changes affecting event payloads, dates, deletions, or ranks must never
  change the contents of an already pinned revision silently.
- Reconciliation is idempotent, including removal/correction of end dates.
  Define snapshot retention, publication, and expiry/restart behavior before
  implementation. Never return mixed revisions or allocate columns server-side.

### BACKEND-4: Date-range timeline API

- Retain public `GET /book-events` as the existing planned access policy;
  confirm public visibility during Stage 1 before finalizing it.
- Paginate contiguous calendar-day spans, returning every event in a span.
  Never split a date; an empty span is valid and must still advance.
- Requests identify a revision and date span (or a cursor carrying them).
  Responses expose event identity, `book_id`, type/date, `start_rank`,
  opaque user_id/title/author, revision, earliest/latest event dates, and the next
  span cursor; terminal pagination is explicit.
- Order by `(date, type, start_rank)` with exact type encoding/order,
  request/response field names, boundaries, span length, empty-timeline
  semantics, and error statuses to be agreed in Stage 2.
- Invalid cursors and expired revisions produce explicit errors/restart
  instructions, not successful empty responses.
- Store timestamps in UTC and group events into UTC calendar days. Date-span
  boundaries use UTC, independent of browser or developer-machine timezone.

### BACKEND-5: Integration and deterministic data

- Idempotent staging seeds include completed/in-progress books, overlapping
  reading spans, both event types on one day, empty date spans, cross-page
  event pairs, and dense same-day collisions. Seeds do not create the admin.
- Planned `rack-cors` policy uses `FRONTEND_ORIGIN`, `headers: :any`,
  GET/POST/PATCH/DELETE/OPTIONS/HEAD, and no credentials; test allowed and
  disallowed origins and Authorization preflight. Confirm direct-browser
  versus Next.js-proxy access jointly with FRONTEND.

## Environment baseline

Foundation baseline: Rails 8.1.4 in [Gemfile](../../backend/Gemfile), Ruby 3.4.11
in [.ruby-version](../../backend/.ruby-version), API-only scaffold initially
containing only `/up`. Stage 2 now adds structural User/Book/BookEvent models
and explicit HTTP 501 product routes in [routes](../../backend/config/routes.rb).
bcrypt is installed for password structure; `rack-cors` remains commented out.
Local API port is 3001. Detailed behavior is not implemented.

[Database configuration](../../backend/config/database.yml) uses SQLite for
development/test and a single production Postgres database from `DATABASE_URL`
with prepared statements/advisory locks disabled and `idle_timeout: 60`.
Solid Cache uses the primary database; Solid Queue/Cable have been removed.
These are completed foundation facts, not unfinished implementation tasks.
Neon and live deployment remain unverified.

Existing checks: from `backend/`, `bin/rails test`, `bin/rails zeitwerk:check`,
`bin/rubocop`, and `bin/brakeman`. Preserve historical container commands in
[TASKS](TASKS.md); Stage 2 checks and exact expected failures are recorded there.

## Acceptance coverage

- BACKEND-1/2: model and request tests cover the opaque ownership placeholder, nullable
  completion/rating/review fields, rating bounds, admin-only book/review writes,
  valid/invalid login, missing/malformed/tampered/expired tokens,
  password-change revocation, current-role authorization, and rate limiting.
- BACKEND-3/4: integration tests prove deterministic ranks, paired events
  across spans, complete dates, empty spans, no missing/duplicate events,
  valid bounds, mutation isolation, and explicit revision expiry/restart.
- BACKEND-5: seeds run twice without duplicates and CORS preflight is correct.
- Full Rails tests, autoloading, lint, and security checks pass; disposable
  Postgres checks prove migrations, `select 1`, and cache round-trip.
- Local manual API checks cover login, authorized CRUD, rejected unauthorized
  writes, and revision-pinned pagination. No expected-red final acceptance.

## Policies carried into Stage 2 review

- Existing access is retained for Stage 2: public timeline, admin-only book
  detail/list. Broader public detail remains an unapproved scope change.
- Admin provisioning and username uniqueness; ordinary-user workflows are
  explicitly out of scope, not open implementation work.
- Span size, revision retention/restart UX, and performance targets for large
  or event-dense ranges.
- Login rate-limit policy; direct-browser versus proxied API access.

Rank assignment/reuse is deferred to frontend implementation by user decision,
not an unresolved backend requirements question. Backend design must expose
the dependency without silently choosing cycling, random values, or defaults.

## Approved changes and resources

- 2026-10-24: Separate BACKEND lifecycle; preserve completed foundation.
- 2026-10-24: Adopt shared rank/revision and date-range layout requirements;
  no approval for Stage 2 or detailed implementation is implied.
- 2026-10-24: User selected Books (embedded rating/review, timestamps),
  persisted BookEvents (`START`/`FINISH`), and Users (`is_admin`, protected
  passwords). These replace the former separate Admin/Review model plan.
  Rank and ownership conflicts are explicit blockers, not resolved defaults.
- 2026-10-24: Add Books `user_id`; limit account functionality to admin.
  Confirm rank 1..12 inclusive, nullable completion/rating/review, all writes
  (including rating/review) admin-only, and UTC storage with club-timezone
  grouping. Rank assignment and the timezone identifier are not yet agreed.
- 2026-10-24: UTC is also the calendar-day grouping timezone. Defer rank
  assignment/reuse to frontend implementation; retain inclusive 1..12 bounds
  and remove algorithm selection from backend Stage 1 blockers.
- 2026-10-24: User approved BACKEND Stage 2 and confirmed nullable string
  `user_id` with no association/ownership implementation. This supersedes
  the previously approved user foreign key.
- [Rails Guides](https://guides.rubyonrails.org/),
  [API-only guide](https://guides.rubyonrails.org/api_app.html),
  [Active Record](https://guides.rubyonrails.org/active_record_basics.html).

## Stage 2 architecture and contracts

Authorization: user approved BACKEND Stage 2 on 2026-10-24 and confirmed
`user_id` as a nullable string placeholder with no association. This supersedes
the earlier foreign-key/username-label requirement. FRONTEND and DEPLOY do
not advance. Stage 3 business logic is not authorized.

### Structural schema

- Rails conventional `users`, `books`, `book_events` tables, integer primary
  keys (Rails bigint identities on Postgres), no separate Review/Admin table.
- Users: non-null username/password_digest/is_admin, unique username index,
  `is_admin` default false. bcrypt through `has_secure_password`; password is
  virtual and never serialized. Only admin provisioning is in scope.
- Books: nullable string `user_id`; non-null string title/author and datetime
  started_at; nullable datetime finished_at, integer rating, string review.
  Database checks: finished_at >= started_at when present; rating 1..5 when
  present. Index started_at. No user association, automatic reader, or owner
  authorization.
- BookEvents: non-null book foreign key, string type, datetime date and integer
  start_rank. Unique `(book_id, type)`; indexes for chronological queries.
  Checks: type START/FINISH, rank 1..12 inclusive. Disable Rails STI for type.
  Book has_many events, deleted transactionally with the book.
- UTC timestamps/day boundaries. No rank default, generation, cycling, or
  ordinary-user management is introduced by the skeleton.

### Components and data flow

- `User`: password hashing structure. Stage 3 adds admin provisioning and the
  12-hour password-bound token contract; current admin role checked per request.
- `Book`, `BookEvent`: associations and database shape in Stage 2; model
  validations, mutation/event synchronization and serialization in Stage 3.
- `SessionsController#create`: planned credential validation and token response.
- `BooksController`: authenticated/admin index/show/create/update/destroy;
  all writes include optional rating/review. No ownership lookup.
- `BookEventsController#index` delegates to `Timeline::Page.call(cursor:)`.
  The service owns cursor verification, UTC spans, pinned revision/bounds,
  event serialization and explicit errors. Stage 2 raises a specific
  unimplemented error; the controller logs and returns 501, never fake data.
- `StagingSeeds.load!`: idempotent staged-data loader contract with explicit
  stub failure. Deterministic YAML books/events are executable test fixtures
  now; Stage 3 implements loading/synchronization. No admin secrets in seeds.
- Rank assignment stays owned by frontend implementation. Fixtures contain
  explicit ranks to test the accepted storage/pair contract, not an algorithm.
  Rank-dependent live mutation/publication remains a named cross-project
  dependency; no implementation can silently substitute a default.

### HTTP contract

Existing access policies are preserved, not broadened: timeline public,
all `/books` routes admin-authenticated. Revisit public detail only by explicit
approval. Browser/proxy choice does not change these API permissions.

| Request | Intended successful response |
| --- | --- |
| `POST /login` with username/password | 200, `{ "token": "..." }` |
| `GET /books` | 200, `{ "books": [...] }` |
| `GET /books/:id` | 200, `{ "book": {...} }` |
| `POST /books` with `{ "book": {...} }` | 201, `{ "book": {...} }` |
| `PATCH /books/:id` with `{ "book": {...} }` | 200, `{ "book": {...} }` |
| `DELETE /books/:id` | 204, empty body |
| `GET /book-events` with optional cursor | 200, timeline envelope below |

Books serialize id, opaque user_id, title, author, started_at, finished_at.
Completed books additionally expose rating/review (possibly null); unfinished
books omit those two fields from reads. Writes permit them regardless of
completion. No credential data is ever included.

Errors use `{ "error": { "code": "...", "message": "..." } }`:
401 unauthorized, 403 forbidden for authenticated non-admin, 404 not_found,
422 validation_failed, 400 invalid_cursor, 410 revision_expired, 429 rate_limited.
Only the skeleton-specific 501 not_implemented exists at this stage.

Timeline response shape:

```json
{
  "revision": "opaque-revision",
  "bounds": { "first_date": "2026-01-01", "last_date": "2026-04-01" },
  "span": { "from": "2026-01-01", "through": "2026-01-30" },
  "events": [
    {
      "id": 1, "book_id": 1, "type": "START",
      "date": "2026-01-01T12:00:00Z", "start_rank": 1,
      "user_id": null, "title": "Example", "author": "Example author"
    }
  ],
  "next_cursor": "opaque-signed-cursor"
}
```

No `reader` field is promised while its source is unresolved. FINISH is the API
type; FINISHED remains a display term. Stable event order is timestamp, explicit
type priority FINISH before START, rank, then book_id/id to resolve reused ranks.
Each span includes all timestamps on its UTC dates, never splitting a day.
Empty timeline: null bounds values, null span, empty events, null next_cursor.
Nonterminal empty spans retain a cursor.

Design proposals for Stage 3 review, not approved product commitments:
30-day spans, signed cursors carrying revision and next UTC day, immutable
serialized revisions retained 24 hours in Rails.cache, 410 forcing a fresh
first-page request. Snapshot publication must be coherent with mutations;
the three requested domain tables do not alone provide historical revisions.
Resolve retention/cache guarantees before implementing publication. Proposed
login policy: 10 attempts per IP per 3 minutes, with Retry-After and tests;
provisioning via explicit environment-driven rake task and explicit rotation.
These policies and the frontend-dependent rank assignment remain visible work.

### Stage 2 acceptance and expected-red coverage

Migrations/fixtures must load on a disposable test DB; password digests are
hashed, table checks/associations/STI mapping pass structural tests, `/up`
continues to pass, autoload/lint/security gates work.
Executable API tests assert intended authentication/CRUD/serialization and
complete-date pagination, including cross-span pairs, dense dates, empty
spans, terminal response, invalid cursor, and explicit seed-loader behavior.
They fail against 501/unimplemented stubs, not broken routing or discovery.
Exact counts and commands belong in TASKS. Uncovered Stage 3 auth/revision/CORS
cases remain listed; no expected-red exception applies to final completion.
