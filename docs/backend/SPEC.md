# Backend specification

## Scope and ownership

Subproject ID: **BACKEND**. Provide the Rails API for one shared bookclub
timeline and single-admin book management.
[Roadmap](ROADMAP.md) and [tasks](TASKS.md) track its independent lifecycle,
restarted at Stage 1. [Deployment](../SPEC.md) follows completion of both apps.

The accepted [shared timeline layout](../BOOKEVENT_TIMELINE_LAYOUT_PLAN.md)
replaces event-count pagination and the proportional-gap/slider design.
This SPEC owns the API/data requirements used by the
[frontend](../frontend/SPEC.md); the shared layout owns cross-app layout rules.

## Requirements

### BACKEND-1: Books and reviews

- A book record represents one reader reading one book: `reader`, `title`,
  `author`, `start_date`, nullable `end_date`. Required fields are present;
  an end date cannot precede its start date. Null end date means in progress.
- A review has `book_id`, `rating`, and text `review`; at most one per book,
  enforced by model and database constraints. Rating bounds remain undecided.
- Serve a review only when the book has an end date. No review-write endpoint;
  staging reviews come from seeds. Production review creation and bulk import
  remain out of scope.

### BACKEND-2: Single-admin authentication and book API

- Exactly one admin has `username` and a bcrypt `password_digest` through
  `has_secure_password`. A one-time rake task reads `ADMIN_USERNAME` and
  `ADMIN_PASSWORD`; never persist plaintext credentials or log them.
- `POST /login` returns `{ "token": "..." }` for valid credentials; invalid
  credentials and missing/invalid authentication return 401.
- Use Rails `generates_token_for :api_access`, signed with `secret_key_base`,
  expiring after 12 hours and bound to `password_salt` so password changes
  revoke tokens. No refresh tokens or server-side denylist.
- `GET /books`, `GET /books/:id`, `POST /books`, `PATCH /books/:id`, and
  `DELETE /books/:id` require `Authorization: Bearer <token>`. Show includes
  the review only for a completed book. Define response/error schemas in
  Stage 2; validation and missing-record failures must be explicit.
- Login rate limiting must be implemented and tested before production;
  the policy remains a Stage 1 decision.

### BACKEND-3: Rank and revision consistency

- Events are derived from books, not an independently editable domain:
  one START and, only if completed, one FINISHED event per book, unique by
  `(book_id, type)`. Whether snapshots need storage is a Stage 2 decision.
- Assign dense `start_rank` ordered by `(start_date, book_id)`. Both events
  inherit the same rank, including when returned in different date spans.
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
  reader/title/author, revision, earliest/latest event dates, and the next
  span cursor; terminal pagination is explicit.
- Order by `(date, type, start_rank)` with exact type encoding/order,
  request/response field names, boundaries, span length, empty-timeline
  semantics, and error statuses to be agreed in Stage 2.
- Invalid cursors and expired revisions produce explicit errors/restart
  instructions, not successful empty responses.

### BACKEND-5: Integration and deterministic data

- Idempotent staging seeds include completed/in-progress books, overlapping
  reading spans, both event types on one day, empty date spans, cross-page
  event pairs, and dense same-day collisions. Seeds do not create the admin.
- Planned `rack-cors` policy uses `FRONTEND_ORIGIN`, `headers: :any`,
  GET/POST/PATCH/DELETE/OPTIONS/HEAD, and no credentials; test allowed and
  disallowed origins and Authorization preflight. Confirm direct-browser
  versus Next.js-proxy access jointly with FRONTEND.

## Environment baseline

Observed: Rails 8.1.4 in [Gemfile](../../backend/Gemfile), Ruby 3.4.11
in [.ruby-version](../../backend/.ruby-version), API-only scaffold with only
`/up` in [routes](../../backend/config/routes.rb), no book/admin/review models
or product endpoints yet. `bcrypt` and `rack-cors` remain commented out.
Local API port is 3001.

[Database configuration](../../backend/config/database.yml) uses SQLite for
development/test and a single production Postgres database from `DATABASE_URL`
with prepared statements/advisory locks disabled and `idle_timeout: 60`.
Solid Cache uses the primary database; Solid Queue/Cable have been removed.
These are completed foundation facts, not unfinished implementation tasks.
Neon and live deployment remain unverified.

Existing checks: from `backend/`, `bin/rails test`, `bin/rails zeitwerk:check`,
`bin/rubocop`, and `bin/brakeman`. Preserve historical container commands in
[TASKS](TASKS.md); no new checks were run for this documentation edit.

## Acceptance coverage

- BACKEND-1/2: model and request tests cover constraints, CRUD, conditional
  reviews, valid/invalid login, missing/malformed/tampered/expired tokens,
  password-change revocation, singleton behavior, and rate limiting.
- BACKEND-3/4: integration tests prove deterministic ranks, paired events
  across spans, complete dates, empty spans, no missing/duplicate events,
  valid bounds, mutation isolation, and explicit revision expiry/restart.
- BACKEND-5: seeds run twice without duplicates and CORS preflight is correct.
- Full Rails tests, autoloading, lint, and security checks pass; disposable
  Postgres checks prove migrations, `select 1`, and cache round-trip.
- Local manual API checks cover login, authorized CRUD, rejected unauthorized
  writes, and revision-pinned pagination. No expected-red final acceptance.

## Open Stage 1 decisions

- Public timeline versus restricted viewing; who can access book detail?
  Existing detail API is admin-only.
- Rating range; singleton admin task create-only versus explicit update mode.
- Date/calendar conventions, span size, revision retention/restart UX, and
  performance targets for large date ranges or event-dense dates.
- Login rate-limit policy; direct-browser versus proxied API access.

## Approved changes and resources

- 2026-10-24: Separate BACKEND lifecycle; preserve completed foundation.
- 2026-10-24: Adopt shared rank/revision and date-range layout requirements;
  no approval for Stage 2 or detailed implementation is implied.
- [Rails Guides](https://guides.rubyonrails.org/),
  [API-only guide](https://guides.rubyonrails.org/api_app.html),
  [Active Record](https://guides.rubyonrails.org/active_record_basics.html).
