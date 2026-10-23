# Project tasks

## Current phase

Phase 1: Backend implementation and testing. Not started; awaiting
authorization to implement. Phase 2 (frontend) and Phase 3 (Vercel
deployment) tasks will be defined when their phase begins; see
`docs/ROADMAP.md` for their scope.

- **Adding the Book model and migration — Not started**
  - Scope: `Book` model, migration, `db/schema.rb`: `reader`, `title`,
    `author`, `start_date`, nullable `end_date`; presence validations and
    `end_date >= start_date`.
  - Acceptance criteria: Model tests cover validations and in-progress state.
  - Automated validation: `bin/rails test test/models`.
  - Manual validation: None.
  - Dependencies or blockers: None.

- **Adding the Review model and migration — Not started**
  - Scope: `Review` model with `book_id`, `rating`, `review`; `belongs_to
    :book`, `has_one :review` on Book, uniqueness of `book_id`; rating range
    validation.
  - Acceptance criteria: Model tests cover one-review-per-book and rating
    bounds.
  - Automated validation: `bin/rails test test/models`.
  - Manual validation: None.
  - Dependencies or blockers: Depends on the Book model task.

- **Adding the Admin model, rake task, and login — Not started**
  - Scope: `bcrypt` gem; `Admin` model with `username`, `password_digest`
    via `has_secure_password`, and `generates_token_for :api_access`
    (12-hour expiry, bound to `password_salt`); `lib/tasks/admin.rake` with
    a one-time task that creates or updates the single admin from
    `ADMIN_USERNAME`/`ADMIN_PASSWORD`; `POST /login` returning
    `{ token }`; an `AdminAuthentication` concern using
    `authenticate_with_http_token` and `Admin.find_by_token_for`.
  - Acceptance criteria: Login returns a token with correct credentials and
    401 otherwise; token round-trips, expires after 12 hours, and is invalid
    after a password change; protected actions return 401 for missing,
    malformed, expired, or tampered tokens.
  - Automated validation: `bin/rails test test/models test/controllers`.
  - Manual validation: `bin/rails admin:create` with env vars, `curl` login,
    then an authenticated request.
  - Dependencies or blockers: None.

- **Adding book CRUD endpoints — Not started**
  - Scope: `config/routes.rb`, books controller with index, show, create,
    update, destroy; every action requires admin; strong parameters.
  - Acceptance criteria: Request tests cover each action, validation errors,
    and 401 on every action without a valid token.
  - Automated validation: `bin/rails test test/controllers`.
  - Manual validation: `curl` create, update, delete with a token.
  - Dependencies or blockers: Depends on Book model and Admin/login tasks.

- **Adding GET /books/:id with conditional review — Not started**
  - Scope: show action (admin) serializes the book and includes `review`
    only when `end_date` is present.
  - Acceptance criteria: Request tests assert review present for completed
    books, absent for in-progress books, and 401 without a token.
  - Automated validation: `bin/rails test test/controllers`.
  - Manual validation: None.
  - Dependencies or blockers: Depends on Book, Review, and Admin tasks.

- **Adding the cursor-paginated GET /book-events endpoint — Not started**
  - Scope: a query object deriving start/end events from books ordered by
    event date with a stable tiebreaker; public controller accepting
    `?cursor=` and returning events plus `next_cursor` (null on last page);
    fixed server-side page size.
  - Acceptance criteria: Request tests cover ordering, following
    `next_cursor` across pages without gaps or duplicates, null cursor on the
    last page, invalid cursor handling, in-progress books yielding one event,
    and event payload fields including `book_id` and type.
  - Automated validation: `bin/rails test test/controllers`.
  - Manual validation: `curl` first page, then follow `next_cursor` to the
    end.
  - Dependencies or blockers: Depends on Book model task. Page size value
    pending; use 50 unless decided.

- **Adding staging seed data — Not started**
  - Scope: `db/seeds.rb` with books and reviews including at least one
    in-progress book and one overlapping pair; idempotent. Seeds do not
    create the admin.
  - Acceptance criteria: `bin/rails db:seed` runs twice without duplicates;
    a test asserts seeded counts.
  - Automated validation: `bin/rails test` with a seeds test.
  - Manual validation: None.
  - Dependencies or blockers: Depends on Book and Review model tasks.

- **Configuring CORS for the frontend origin — Not started**
  - Scope: `Gemfile` (`rack-cors`), `config/initializers/cors.rb` with
    `origins ENV["FRONTEND_ORIGIN"]`, `headers: :any`, methods GET, POST,
    PATCH, DELETE, OPTIONS, HEAD; no credentials.
  - Acceptance criteria: Integration test asserts CORS headers on an
    `OPTIONS /books` preflight with `Access-Control-Request-Headers:
    Authorization`.
  - Automated validation: `bin/rails test`.
  - Manual validation: None.
  - Dependencies or blockers: None.

## Completed

- **Configuring Postgres for production with SQLite locally — Completed**
  - Scope: `backend/Gemfile`, `Gemfile.lock`, `config/database.yml`,
    `config/cable.yml`, `config/cache.yml`, `config/puma.rb`,
    `config/environments/production.rb`,
    `db/migrate/20261023040000_create_solid_cache_entries.rb`,
    `db/schema.rb`, root `README.md` stack note.
  - Result: `sqlite3` limited to development/test; `pg ~> 1.5` in
    production. Production `database.yml` is a single `postgresql` entry
    from `DATABASE_URL` with `prepared_statements: false`,
    `advisory_locks: false`, `idle_timeout: 60`. Solid Queue and Solid Cable
    removed (gems, puma plugin, Redis cable entry). Solid Cache installed
    (it had never been installed because the generator ran with
    `--skip-bundle`), with its schema converted to a primary-database
    migration and `database: cache` removed from `cache.yml`;
    `config.cache_store = :solid_cache_store` in production.
  - Automated validation (all in `ruby:3.4-bookworm` container):
    - `bin/rails db:prepare && bin/rails test` — passed; 1 test, 1 assertion.
    - `bin/rails zeitwerk:check` — "All is good!".
    - `bin/rubocop` — 23 files, no offenses.
    - `bin/brakeman -q` — 0 warnings.
    - `RAILS_ENV=production DATABASE_URL=postgres://...@bookfall-pg/...
      bin/rails db:migrate && bin/rails runner ...` against
      `postgres:17-alpine` — adapter `PostgreSQL`, `select 1` ok,
      `prepared_statements` false, `Rails.cache` is `SolidCache::Store` and
      round-trips a value; `db:migrate:status` shows the migration up.
  - Manual validation: Reviewed `database.yml` for leftover multi-DB
    entries; none remain. `git status` shows only the scoped files changed.
  - Residual risk: Not yet tested against Neon itself (Phase 3). Active
    Storage's `image_processing` gem logs a libvips warning in the container;
    pre-existing and out of scope.

- **Scaffolding the Rails and Next.js foundation — Completed**
  - Scope: Generate the Rails API and Next.js frontend, document setup and
    validation, and record product questions without inventing requirements.
  - Acceptance criteria: Both apps exist in separate directories, the root
    README documents local setup, and `docs/SPEC.md` records the agreed stack
    and unresolved product decisions.
  - Automated validation:
    - `docker run --rm -v "$PWD/backend:/app" -w /app ruby:3.4-bookworm bash -c 'bundle install --quiet && bin/rails db:prepare && bin/rails test && bin/rails routes >/dev/null && bin/rails zeitwerk:check'` — passed; 1 test, 1 assertion.
    - `cd frontend && npm run lint && npm run build` — passed.
    - `cd frontend && npm audit --omit=dev` — passed; 0 production advisories.
    - Full `npm audit` — reports 5 high-severity advisories in development-only lint dependencies; compatible remediation requires review.
  - Manual validation: Next.js dev server returned HTTP 200 for `/` and the
    generated page title was present. Project structure and setup commands
    were checked against the generated apps.
  - Dependencies or blockers: None for the foundation. Product-specific work
    is blocked on answers to `docs/SPEC.md`.
  - Validation record: Rails was generated and validated in Ruby 3.4 because
    the host lacks Ruby development headers. Initial checks from the repository
    root / separate ephemeral container runs failed due to working-directory /
    dependency scope; rerunning from `frontend/` and installing Rails gems in
    the same container as the Rails checks passed. The generated Rails test
    suite now includes a `/up` health-check smoke test.
  - Residual risk: Full browser-based visual inspection was not available;
    the generated frontend was checked by HTTP response only. Development-only
    npm audit findings remain unresolved.
