# Backend specification

## Scope and ownership

Subproject ID: **BACKEND**. Provide the Rails API for one shared bookclub
timeline and admin-authorized book management, with a Users table for admin accounts.
Non-admin user functionality is outside this project's current scope.
[Roadmap](ROADMAP.md) and [tasks](TASKS.md) track its independent lifecycle,
Stage 2 completed and Stage 3 authorized 2026-10-24; model work and BE-AUTH
and GET /books are implemented. Other implementation requires user-selected tasks.
[Deployment](../SPEC.md) follows completion of both apps.

The accepted [shared timeline layout](../BOOKEVENT_TIMELINE_LAYOUT_PLAN.md)
replaces event-count pagination and the proportional-gap/slider design.
This SPEC owns the API/data requirements used by the
[frontend](../frontend/SPEC.md); the shared layout owns cross-app layout rules.

## Requirements

### BACKEND-1: Books with embedded reviews

The user-selected logical tables replace the former separate Admin and Review
models and date-only Book fields. Approved SQL naming, defaults, indexes,
and Rails mapping are recorded in the structural schema below.

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
  or write workflows. Provision the initial admin through the approved one-time
  environment-driven rake task; usernames are unique. Future roles are not
  authorization to implement them now.
- Never store plaintext or reversibly encrypted passwords. Approved Rails
  mapping: virtual `password` input and bcrypt `password_digest` storage through
  `has_secure_password`, as established by the structural schema.
- `POST /login` returns `{ "token": "..." }` for valid credentials; invalid
  credentials and missing/invalid authentication return 401.
- Carry forward the planned Rails `generates_token_for :api_access` policy
  onto User: signed with `secret_key_base`, expiring after 12 hours and bound
  to `password_salt`. No refresh tokens or server-side denylist. Authorization
  must check the user's current `is_admin`; role-change behavior needs tests.
- `GET /books`, `GET /books/:id`, `POST /books`, `PATCH /books/:id`, and
  `DELETE /books/:id` require `Authorization: Bearer <token>`. Show includes
  the review only for a completed book. Response/error schemas are defined
  below; validation and missing-record failures must be explicit.
- Login rate limiting must be implemented and tested before production;
  the approved policy is 10 attempts per IP per 3 minutes with Retry-After.

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
  non-STI mapping established in Stage 2 rather than renaming it silently.
- Publish event data, ranks, and timeline bounds as one consistent revision.
  Changes affecting event payloads, dates, deletions, or ranks must never
  change the contents of an already pinned revision silently.
- Reconciliation is idempotent, including removal/correction of end dates.
  Use the approved immutable cache revisions and expiry/restart contract below.
  Never return mixed revisions or allocate columns server-side.

### BACKEND-4: Date-range timeline API

- Public `GET /book-events` is the approved timeline access policy.
- Paginate contiguous calendar-day spans, returning every event in a span.
  Never split a date; an empty span is valid and must still advance.
- Requests identify a revision and date span (or a cursor carrying them).
  Responses expose event identity, `book_id`, type/date, `start_rank`,
  opaque user_id/title/author, revision, earliest/latest event dates, and the next
  span cursor; terminal pagination is explicit.
- Use the stable order, field names, boundaries, 30-day spans, empty-timeline
  semantics, and explicit error statuses in the approved HTTP contract below.
- Invalid cursors and expired revisions produce explicit errors/restart
  instructions, not successful empty responses.
- Store timestamps in UTC and group events into UTC calendar days. Date-span
  boundaries use UTC, independent of browser or developer-machine timezone.
- Initial navigation accepts mutually exclusive `before` or `after` timestamp
  anchors; continuation accepts only `cursor`. These are date-span navigation
  anchors, not strict timestamp filters. See the HTTP contract for boundaries.

### BACKEND-5: Integration and deterministic data

- Idempotent staging seeds create Books only: completed/in-progress books,
  overlapping reading spans, same-day start/finish and dense same-day starts.
  Matching uses title/author/started_at, never fixture IDs; existing matches
  are left unchanged. Seeds create no users/admin and no BookEvents; events
  come from `book_events:sync` (supersedes the earlier seeded-events policy).
- Approved direct-browser `rack-cors` policy uses `FRONTEND_ORIGIN`, `headers: :any`,
  GET/POST/PATCH/DELETE/OPTIONS/HEAD, and no credentials; test allowed and
  disallowed origins and Authorization preflight. No Next.js proxy is required.

### BACKEND-6: Scheduled incremental BookEvents synchronization

- An externally scheduled rake task selects Books changed by `updated_at`
  since its last successful processing checkpoint and reconciles BookEvents.
  Include newly created books and process all books on the first run.
- Add Books `created_at` and `updated_at`, maintained by Rails, and an index
  on `(updated_at, id)` for deterministic incremental selection.
- `task_checkpoints` stores one row per task name, with a nullable
  `processed_through` watermark separate from attempt start/finish times.
  Advance the watermark only after successful reconciliation/publication,
  not merely because a scheduled attempt began.
- Monitoring fields: last_started_at, last_finished_at, last_succeeded_at,
  status (idle/running/succeeded/failed), books_processed, last_error,
  extensible JSON metadata, and row created_at/updated_at.
- Rake entry point: `bin/rails book_events:sync`, delegating to
  `BookEventSync.call`. Stage 2 provides explicit failing stubs, not a scheduler
  or business logic. Deployment owns invocation infrastructure and must read
  `BOOK_EVENTS_SYNC_INTERVAL_SECONDS`, a positive integer in seconds with
  default `600` (10 minutes), documented in the backend environment template.
  Invalid values must fail explicitly when scheduling is configured, not
  silently revert to the default. The variable controls invocation frequency,
  not the changed-books query window. No background worker is added; the
  current skeleton does not consume the variable or start a scheduler.
  The freshness target beyond invocation frequency remains undecided.
- Stage 3 must handle retries idempotently, preserve existing event identities,
  reconcile changed/removed finish timestamps,
  and expose failures without advancing the successful watermark. Store
  sanitized operational error information, not credentials or book reviews.
- A naive `updated_at > last_finished_at` query can lose edits. Stage 3 must
  define a captured processing bound and inclusive boundary replay; advanced
  coordination of concurrent/uncommitted writes is deferred as low priority
  by the later user decision below. Advancing to wall-clock run completion
  is not a safe checkpoint. Event updates and watermark advancement
  must be atomic; failed-attempt monitoring must survive rollback.
- Hard-deleted books cannot be discovered through Books.updated_at. Retain
  dependent event removal on deletion; publish deletions in new revisions
  without modifying still-cached pinned revisions. Scheduled publication supersedes the earlier
  implication that all event synchronization runs inside each HTTP write.
- Rank assignment is still deferred. No sync allocator or arbitrary rank default
  is authorized; first-run generation remains dependent on the eventual rank
  contract. Fixtures have explicit test ranks, not an approved algorithm.

## Environment baseline

Foundation baseline: Rails 8.1.4 in [Gemfile](../../backend/Gemfile), Ruby 3.4.11
in [.ruby-version](../../backend/.ruby-version), API-only scaffold initially
containing only `/up`. Stage 2 now adds structural User/Book/BookEvent models
and explicit HTTP 501 product routes in [routes](../../backend/config/routes.rb).
bcrypt is installed for password structure; `rack-cors` remains commented out.
Local API port is 3001. BE-AUTH login, admin provisioning and book authorization
and book listing are implemented; authorized book detail/write actions and
public timeline remain 501 stubs.

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

The following is required final coverage, not a claim that all cases already
exist or pass. TASKS distinguishes the expected-red baseline from remaining
Stage 3 tests.

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

## Approved policies and remaining dependencies

- Existing access is retained: public timeline, admin-only book
  detail/list. Broader public detail remains an unapproved scope change.
- Unique usernames, one-time environment-driven admin provisioning, and the
  login rate-limit policy are approved; ordinary-user workflows remain out of scope.
- Thirty-day spans, immutable cache revisions retained up to 24 hours,
  early eviction with explicit 410 recovery, and direct-browser CORS access
  are approved. Detailed contracts below are canonical.
- No quantitative performance/freshness target beyond the configured sync
  interval is approved. Do not invent one during implementation.
- Advanced concurrent-write/overlap coordination is deferred; preserve the
  documented race risk rather than claim it solved.

Rank assignment/reuse is deferred to frontend implementation by user decision,
not an unresolved backend requirements question. Backend design must expose
the dependency without silently choosing cycling, random values, or defaults.

Stage 2 architecture, skeletons, deterministic fixtures and expected-red
integration baseline were accepted on 2026-10-24. Stage 3 is authorized.
The user selected BE-BOOK, the remaining model layer, and BE-AUTH; their model,
token, provisioning, login, authorization and rate-limit checks pass.
Other implementation tasks still require user selection from TASKS.

## Approved changes and resources

Chronological history follows; later decisions supersede earlier open questions.
The approved contracts above and below describe current requirements.

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
not advance. Stage 2 was subsequently accepted and Stage 3 authorized on
2026-10-24. Model validations, BE-AUTH and book listing are implemented;
Books-only staging seeds are implemented; book detail/writes, timeline and
sync business logic remains unimplemented.

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

- `User`: bcrypt password protection, required/unique username, boolean admin
  flag, and 12-hour password-salt-bound api_access tokens.
- `AdminProvisioning.call` and `admin:provision`: explicit initial creation from
  environment; reject missing settings, existing admin or occupied username.
  Reruns fail rather than overwrite a password or promote an existing account.
- `Book`, `BookEvent`: associations/database shape and model validations exist.
  BookEvent requires an existing book, START/FINISH type, unique book/type,
  valid date and integer rank 1..12. Mutation/event synchronization and
  serialization remain unimplemented; model callbacks do not allocate ranks
  or reconcile associated records.
- `SessionsController#create`: implemented admin credential validation and
  token response with Cache-Control no-store, no cookie session, shared
  Solid Cache attempt counter and explicit 429 response.
- `ApplicationController#require_admin`: verifies the bearer token and current
  persisted role for every book route. Invalid credentials return 401;
  authenticated non-admins return 403.
- `BooksController`: admin guard implemented for index/show/create/update/destroy;
  index returns all books in ascending ID order with the approved conditional
  review serialization. Other action bodies remain stubs.
  Intended writes include optional rating/review.
  No ownership lookup.
- `BookEventsController#index` currently delegates to `Timeline::Page.call(cursor:)`.
  Stage 3 must extend this boundary to carry the approved before/after anchors.
  The service owns cursor verification, UTC spans, pinned revision/bounds,
  event serialization and explicit errors. Stage 2 raises a specific
  unimplemented error; the controller logs and returns 501, never fake data.
- `StagingSeeds.load!`: implemented Books-only idempotent loader from
  `db/seeds/books.yml`, validated in one transaction. Deterministic BookEvents
  exist only as test fixtures. No admin secrets, users or events in seeds.
- `TaskCheckpoint` and `BookEventSync.call`: scheduled incremental projection
  boundary described in BACKEND-6. The new table is operational state, not a
  fourth user-facing resource; no management endpoint is added.
  TaskCheckpoint validates required/unique name, defined status, nonnegative
  integer books_processed and non-null metadata. No transition/watermark
  automation is added by those validations; the sync service remains a stub.
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
| `GET /book-events` with optional before, after, or cursor | 200, timeline envelope below |

Books serialize id, opaque user_id, title, author, started_at, finished_at.
Completed books additionally expose rating/review (possibly null); unfinished
books omit those two fields from reads. Writes permit them regardless of
completion. No credential data is ever included.

Errors use `{ "error": { "code": "...", "message": "..." } }`:
401 unauthorized, 403 forbidden for authenticated non-admin, 404 not_found,
422 validation_failed, 400 invalid_parameters/invalid_timestamp/invalid_cursor,
410 revision_expired, 429 rate_limited.
BE-AUTH implements 401/403 and login 429; unimplemented action bodies return
the skeleton-specific 501 not_implemented. Other errors remain intended contracts.

#### Timeline query parameters

Accepted 2026-10-24: use `before`, `after`, and opaque cursor pagination while
preserving complete UTC days per page.

| Parameter | Meaning |
| --- | --- |
| `after` | Initial ISO 8601 timestamp anchor; navigate toward newer UTC days |
| `before` | Initial ISO 8601 timestamp anchor; navigate toward older UTC days |
| `cursor` | Opaque server-issued continuation, preserving direction, span position, and revision |

- Supply at most one of these parameters. Reject before+after or cursor with
  either anchor using 400 `invalid_parameters`. Empty/duplicate parameter
  values are invalid, not an instruction to use defaults.
- Anchors require a full timestamp with explicit `Z` or timezone offset;
  normalize to UTC before identifying its calendar day. Invalid timestamps
  return 400 `invalid_timestamp`. Encode a positive offset's `+` as `%2B`.
- Both anchors include their entire UTC calendar day: `after` starts a span
  at that day and extends forward; `before` ends a span at that day and extends
  backward. Events earlier/later than the timestamp within the anchor day are
  included deliberately. No date is partially loaded.
- With no parameters, start at the earliest event date and navigate forward.
  Clip spans to the revision's timeline bounds. An after anchor beyond the
  latest date, or before anchor earlier than the earliest date, returns empty
  events, null span, and null next_cursor, retaining nonempty revision bounds.
  Anchors on the opposite outer side clip to the nearest timeline boundary.
- Within every response, events remain in ascending stable order, even when
  browsing backward. A backward continuation selects the immediately preceding
  date span, so the frontend prepends it. Forward continuation appends.
- `next_cursor` continues in the original direction; null means exhausted.
  Do not add a redundant `has_more`. Empty nonterminal spans still advance.
- Cursor contents are private and signed: version, pinned revision, direction
  and next UTC date-span boundary. Timestamp alone is never an event cursor.
  Complete-day boundaries plus deterministic `(timestamp, type priority,
  start_rank, book_id, id)` ordering preserve all same-timestamp events.
- A malformed/tampered cursor returns 400 `invalid_cursor`; an unavailable
  pinned revision returns 410 `revision_expired`. Restart explicitly from an
  initial anchor or default request; never silently mix revisions.

```http
GET /book-events?after=2026-01-01T12:00:00Z
GET /book-events?before=2026-04-01T12:00:00Z
GET /book-events?cursor=<opaque-token>
```

The examples anchor on January 1 or April 1 respectively and include that
entire UTC day, not just events strictly after/before noon. Each page covers
30 consecutive UTC dates, clipped at timeline bounds; there is no event-count
limit that could split a day. Approved 2026-10-24.

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

Approved 2026-10-24: initial admin provisioning is a one-time initialization
rake task reading `ADMIN_USERNAME` and `ADMIN_PASSWORD` from the environment.
It hashes the password and grants the admin role; missing settings fail
explicitly. This is an explicit task invocation, not a per-request operation
or automatic password overwrite on every app start. Password rotation is a
separate, not-yet-defined administrative operation.
Implemented command: `bin/rails admin:provision` after migrations. If any admin
already exists or the configured username is occupied, fail without changing
accounts. No silent idempotent success or automatic role promotion.

Approved login rate limit: 10 attempts per IP per 3 minutes, responding with
429 `rate_limited` and Retry-After seconds. Count attempts regardless of
credential success; use a shared store and trusted proxy/IP configuration.
No user-management endpoints are added.

Implemented using SolidCache::Store directly in every environment, independent
of the general Rails.cache setting. Counters expire three minutes after the
first attempt; later increments do not extend that window. Return conservative
Retry-After 180 seconds on rejection. Cache errors or invalid counter results
raise rather than disable the limit. TRUSTED_PROXY_CIDRS is an explicit
comma-separated IP/CIDR list, empty by default; invalid entries fail boot.
Use forwarded client IPs only when the direct peer is trusted, otherwise use
the direct peer IP. Deployment must verify actual proxy ranges and ingress
header sanitation; no platform range is assumed.

Approved 2026-10-24: immutable serialized revisions in Rails.cache, with
24-hour maximum retention from publication (not sliding on reads). Eviction
may end availability earlier. Unavailable revisions return 410 revision_expired
and require an explicit initial request; do not silently switch to live data.
Old cursors retain their original payloads after new revisions are published.
No additional SQL snapshot table is required.

Add `bin/rails book_events:refresh_cache`, delegating to `Timeline::Refresh.call`.
It builds and publishes a new revision from committed Books/BookEvents even
when the normal current revision has not expired. It does not globally clear
Rails.cache, invalidate still-available pinned revisions, or advance the
incremental sync checkpoint. It refreshes the cached projection, not a substitute
for synchronizing missing events. Failure must surface and leave the prior
current revision usable. Stage 2 contains only the explicit failing boundary.

Book edits are rare: PATCH updates existing associated events by book_id,
preserving identities for types that remain. DELETE removes the Book and its
existing BookEvents atomically. Removing finished_at removes the FINISH event;
adding a finish still requires the shared deferred rank contract.
Scheduled sync remains responsible for incremental creation/reconciliation.
Existing cached revisions remain immutable; a scheduled publication or explicit
refresh exposes edits/deletions to new timeline requests.

Advanced concurrent-write/overlap design is deferred as low priority by user
decision, not claimed solved or tested. Keep idempotent boundary replay, failure
rollback and successful-checkpoint semantics; Stage 3 must document remaining
race risk and avoid claiming timestamp selection alone guarantees no lost
updates. Do not add a writer/reader coordination subsystem in this stage.

Approved API access: browser calls Rails directly. Allow only configured
FRONTEND_ORIGIN via CORS, allow the Authorization header, and do not enable
credentialed cookie requests. Rails still enforces admin permissions independently
of CORS. No Next.js forwarding proxy is needed.

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
