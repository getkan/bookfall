# Backend tasks

## Current scope and session

- ID: **BACKEND**; [SPEC](SPEC.md), [ROADMAP](ROADMAP.md).
- Lifecycle: Stage 1 requirements restart, **In progress**.
- Authorized session: split documents and adopt the shared timeline design.
  No application implementation tasks selected.
- Stage 2 approval: not granted; resolve SPEC open decisions first.

## Carried-forward high-level work

These remain **Not started**, pending requirements resolution, Stage 2
contracts/test baseline, Stage 3 approval, and user task selection. They are
planning outcomes, not permission to implement the old task order.

| Task ID | Outcome | Requirements | Dependencies | Acceptance/checks to define or run |
| --- | --- | --- | --- | --- |
| BE-BOOK | Book model, migration, constraints | BACKEND-1 | Approved schema | Presence/date/in-progress model tests; `bin/rails test test/models` |
| BE-REVIEW | Review model and one-per-book constraint | BACKEND-1 | BE-BOOK; rating bounds | Model tests for uniqueness and agreed rating limits |
| BE-AUTH | Single admin, rake task, login, token validation and rate limit | BACKEND-2 | Singleton/update and rate-limit decisions | Model/request tests; expiry, revocation, invalid tokens; manual login |
| BE-CRUD | Protected book CRUD and conditional review | BACKEND-1/2 | BE-BOOK, BE-REVIEW, BE-AUTH | Request tests for every action, validation, missing records, 401; manual CRUD |
| BE-REVISION | Deterministic ranks and coherent revision publication | BACKEND-3 | BE-BOOK; snapshot contract | Backdated edits, deleted/removed dates, idempotence, immutable pinned responses |
| BE-EVENTS | Complete date-span API, bounds, next cursor and restart errors | BACKEND-4 | BE-REVISION; API contract | Empty/dense spans, cross-span pairs, no omissions/duplicates, expiry/error integration tests |
| BE-SEEDS | Idempotent staging books/reviews | BACKEND-5 | BE-BOOK, BE-REVIEW; agreed fixtures | Seeds test plus `bin/rails db:seed` twice without duplicates |
| BE-CORS | Frontend-origin integration | BACKEND-5 | Cross-app access decision | Authorization preflight and origin rejection integration tests |

Stage 2 must first add structural contracts, deterministic fixtures, and
executable integration tests covering intended behavior. No Stage 2 integration
baseline currently exists; record exact expected failures when it runs.

## Validation and commit checkpoint

- Planned full gate from `backend/`: `bin/rails test`,
  `bin/rails zeitwerk:check`, `bin/rubocop`, `bin/brakeman`.
- Also check production migrations/connection/cache against disposable Postgres
  and manually exercise API auth, CRUD, and date-span pagination.
- Write unit tests alongside implementation; run focused integration coverage
  after each selected unit. Record exact commands/results before marking it
  Completed. Existing historical passes do not validate new behavior.
- After each validated unit, remind the user to commit and stop. Resume only
  after commit confirmation or explicit continuation without committing.
  Never stage/commit implicitly. No new commit checkpoint has been passed.

## Completed foundation: production Postgres with SQLite locally

Historical result preserved from the original project TASKS; not rerun here.

- Scope: `backend/Gemfile`, `Gemfile.lock`, `config/database.yml`,
  `config/cable.yml`, `config/cache.yml`, `config/puma.rb`,
  `config/environments/production.rb`,
  `db/migrate/20261023040000_create_solid_cache_entries.rb`, `db/schema.rb`,
  root README stack note.
- Result: `sqlite3` limited to development/test; `pg ~> 1.5` in production.
  Single production database from `DATABASE_URL`; prepared statements and
  advisory locks disabled; `idle_timeout: 60`. Solid Queue/Cable removed.
  Solid Cache installed after the original `--skip-bundle` generation, its
  schema converted to a primary-database migration, `database: cache` removed,
  and `config.cache_store = :solid_cache_store` retained in production.
- Automated validation, all in `ruby:3.4-bookworm`:
  - `bin/rails db:prepare && bin/rails test`: passed; 1 test, 1 assertion.
  - `bin/rails zeitwerk:check`: "All is good!".
  - `bin/rubocop`: 23 files, no offenses.
  - `bin/brakeman -q`: 0 warnings.
  - `RAILS_ENV=production DATABASE_URL=postgres://...@bookfall-pg/...
    bin/rails db:migrate && bin/rails runner ...` against
    `postgres:17-alpine`: PostgreSQL adapter, `select 1` ok, prepared statements
    false, `SolidCache::Store` round-trip passed; migration status up.
- Manual: database configuration reviewed; no leftover multi-database entries;
  historical worktree inspection showed only scoped changes.
- Residual risk: not tested against Neon. Pre-existing image-processing
  libvips warning in the container remained out of scope.

## Completed foundation: Rails scaffold

The original combined Rails/Next.js foundation was completed; frontend
evidence now lives in [Frontend TASKS](../frontend/TASKS.md).

- Acceptance: separate apps exist; setup/validation documented in root README;
  requirements and unknowns recorded in the original SPEC.
- Exact historical Rails command:

  ```sh
  docker run --rm -v "$PWD/backend:/app" -w /app ruby:3.4-bookworm bash -c 'bundle install --quiet && bin/rails db:prepare && bin/rails test && bin/rails routes >/dev/null && bin/rails zeitwerk:check'
  ```

  Passed: 1 test, 1 assertion, including the `/up` smoke test.
- Rails was generated/validated in Ruby 3.4 because the host lacked Ruby
  development headers. Initial root-directory/separate-container attempts
  failed due to working-directory/dependency scope; installing gems and
  running checks in one container resolved those failures.
- Historical product work was blocked on unresolved SPEC decisions. Scaffold
  completion does not establish Stage 2 feature integration coverage.

## Documentation session evidence

2026-10-24: preserved completed records and carried-forward scope; replaced the
old fixed-event-count task with ranks/revisions and complete date spans.
No runtime files changed. Application checks skipped: documentation-only.
Inspect links, requirement ownership, diff scope, and whitespace for this edit;
no feature implementation task or lifecycle stage is newly Completed.
