# Backend tasks

## Current scope and session

- ID: **BACKEND**; [SPEC](SPEC.md), [ROADMAP](ROADMAP.md).
- Lifecycle: Stage 2 architecture/skeleton, **In progress**.
- Authorized session: user approved Stage 2 on 2026-10-24 and then confirmed
  `user_id` as a nullable string placeholder, with no user association.
- Stage 3 approval: not granted. No detailed business-logic tasks selected.
- Earlier session records below are history, superseded by these decisions.

## Stage 2 session unit

**BE-SKELETON — Completed (Stage 2 structural unit only):** schema/models and bcrypt,
controller/service stubs with explicit logged failures, deterministic shared
seed/test data, and intended API integration tests.

- Requirements: BACKEND-1 through BACKEND-5; detailed contract in SPEC.
- Schema: Users, Books with opaque nullable string user_id, BookEvents; checks
  for rating, date ordering, event type, rank bounds and unique book/type.
- No ownership lookup, rank allocator/default, login/CRUD implementation,
  revision query, seed loader logic, or CORS behavior is implemented.
- Stage 3 review must resolve snapshot/retention, span/rate-limit/provisioning
  proposals. Rank assignment stays deferred to frontend implementation.
- Tests cover structural constraints, fixture geometry cases, route discovery,
  intended login/admin CRUD, serialization, UTC span completeness, empty spans,
  cross-span pairs, invalid cursor and idempotent seed loading.
- Remaining Stage 3 tests: token expiry/tamper/password revocation/current-role,
  rate limits, missing records, snapshot mutation/expiry, CORS, and full seeded
  end-to-end acceptance. Existing expected failures cannot waive these.
- Replace temporary `BackendSkeletonTest` 501 expectations as each endpoint
  is implemented in Stage 3; never weaken intended-behavior contract tests
  to expect unimplemented stubs.

## Carried-forward high-level work

**BE-SYNC-SKELETON — Completed (Stage 2 structural unit only):** BACKEND-6.
Add Books timestamps/index, task checkpoint monitoring table/model,
`book_events:sync` rake/service stub, and structural/intended-behavior tests.
No scheduling infrastructure or reconciliation logic is implemented.
Stage 3 BE-SYNC depends on rank contract, concurrent-write/watermark policy,
retry/failure handling and snapshot publication. Required cases include first
run, changed/unchanged books, finish correction/removal, inclusive time-boundary
replay, failed runs, concurrent writes/runs and hard deletion.

Validation (Ruby 3.4 Docker command prefix in the baseline section, disposable
SQLite DATABASE_URL `sqlite3:/tmp/bookfall-sync.sqlite3`):

- `bin/rails db:migrate && bin/rails test
  test/models/backend_structure_test.rb test/models/task_checkpoint_structure_test.rb
  test/integration/backend_skeleton_test.rb test/integration/health_check_test.rb
  && bin/rails zeitwerk:check && bin/rubocop`: passed, **12 tests / 62 assertions**,
  autoload good, **44 files / no offenses**.
- Same migrations/structural tests on disposable `postgres:17-alpine`:
  **12 tests / 62 assertions passed**. Task-specific container
  `bookfall-sync-pg-7d66451e` stopped/removed automatically; no published ports.
  Postgres schema dump directed to container `/tmp`, preserving SQLite schema.
- `bin/rails db:migrate && bin/rails test`: **24 tests / 71 assertions**,
  **9 expected failures / 3 expected errors / 0 skips**. The prior baseline's
  nine HTTP 501 failures and seed stub error are unchanged. Two additional
  errors are exactly BookEventSync's explicit unimplemented exception, one
  through the service and one through the real rake entry point.
- Database tests cover independent watermark/monitoring timestamps, task-name
  uniqueness, status/count constraints and automatic Book updated_at behavior.
- `git diff --check`: passed. No Stage 3 implementation or live scheduler added;
  no unrelated in-progress skeleton changes reverted.

Stop at this Stage 2 checkpoint. Watermark concurrency policy and
rank-dependent generation remain review items; no Stage 3 approval or commit.

2026-10-24 interval decision: `BOOK_EVENTS_SYNC_INTERVAL_SECONDS=600` added to
`backend/.env.example`. Future scheduling must use a positive integer in seconds,
defaulting to 600 (10 minutes); reject invalid configuration explicitly.
No scheduler is running or consuming the setting yet. Scheduler wiring and
configuration validation tests belong to the authorized scheduling work.
Validation: `git diff --check` and exact environment-template value check passed.
Runtime tests skipped: environment-template and documentation changes only.

These remain **Not started** as detailed business-logic units, pending design
review, Stage 3 approval, and user task selection. They are
planning outcomes, not permission to implement the old task order.

| Task ID | Outcome | Requirements | Dependencies | Acceptance/checks to define or run |
| --- | --- | --- | --- | --- |
| BE-BOOK | Books with opaque user_id, timestamps, nullable rating/review and model validations | BACKEND-1 | Structural schema | No user association, rating 1..5, nullable fields, timestamp ordering and in-progress tests |
| BE-AUTH | Admin-only account functionality on Users, protected passwords, login and rate limit | BACKEND-2 | Provisioning and rate-limit decisions | Model/request tests; expiry, revocation, current-role checks; manual login |
| BE-CRUD | Admin-only book writes including rating/review; conditional review reads | BACKEND-1/2 | BE-BOOK, BE-AUTH | Request tests for every action, validation, missing records, 401/role rejection; manual CRUD |
| BE-REVISION | Persisted BookEvents, synchronized timestamps/ranks and coherent revisions | BACKEND-3 | BE-BOOK; rank and snapshot contracts | Event FK/type/uniqueness, rank bounds/ties, backdated edits, idempotence, pinned responses |
| BE-EVENTS | Complete date-span API, bounds, next cursor and restart errors | BACKEND-4 | BE-REVISION; API contract | Empty/dense spans, cross-span pairs, no omissions/duplicates, expiry/error integration tests |
| BE-SEEDS | Idempotent staging books, embedded reviews and events | BACKEND-5 | BE-BOOK, BE-REVISION; agreed fixtures | Seeds test plus `bin/rails db:seed` twice without duplicates |
| BE-CORS | Frontend-origin integration | BACKEND-5 | Cross-app access decision | Authorization preflight and origin rejection integration tests |

Structural contracts, deterministic fixtures and executable intended-behavior
tests now exist; see Stage 2 baseline below. Detailed implementation tasks
remain Not started and are not selected by Stage 2 approval.

BE-REVIEW is superseded by embedded Books fields, not completed. Separate Admin
model and date-only schema tasks are superseded too. Rank assignment is
deferred to frontend implementation; UTC day grouping, nullable fields,
inclusive rank bounds and admin-only write/account scope are confirmed.
The later nullable-string user_id decision supersedes the earlier user FK.

## Stage 2 validation baseline

Validation uses the existing `ruby:3.4-bookworm` Docker image, with gems cached
outside the repository at the current session's `files/backend-gems`. The host
has Ruby 4.0.7 and lacks the required bundle (`bundle check` failed); no host
runtime or global gems were changed. First user-mapped container installation
failed on native prism file permissions; root inside the isolated container
completed `bundle install --jobs 4`. Only bcrypt changed the dependency lock.

Reusable command prefix, from the repository root:

```sh
docker run --rm \
  -e BUNDLE_PATH=/stage2-gems \
  -e RAILS_ENV=test \
  -e DATABASE_URL=sqlite3:/tmp/bookfall-stage2.sqlite3 \
  -e PARALLEL_WORKERS=1 \
  -v /home/getkan/.copilot/session-state/7d66451e-8824-4765-aa1e-b2e991eae2f7/files/backend-gems:/stage2-gems \
  -v "$PWD/backend:/app" -w /app ruby:3.4-bookworm \
  bash -c '<commands below>'
```

- `bin/rails db:migrate && bin/rails test test/models/backend_structure_test.rb
  test/integration/health_check_test.rb && bin/rails zeitwerk:check &&
  bin/rubocop`: passed; 8 tests, 24 assertions; autoload good; 37 files,
  no offenses (before the separate skeleton-route test was added).
- `bin/rails db:migrate && bin/rails test`: baseline before the route test:
  18 tests, 33 assertions, 9 expected assertion failures, 1 expected
  FeatureNotImplemented error, 0 skips. Six admin API contract cases fail on
  login/books HTTP 501; three timeline contract cases fail on HTTP 501;
  seed idempotence errors explicitly at the Stage 3 loader stub. No discovery,
  routing, fixture, or unrelated health-check failures.
- `bin/brakeman -q` in the same Ruby/gem container: passed, 0 warnings/errors.
- Initial fresh `db:prepare` also invokes seeds and therefore stopped at the
  deliberate seed stub. Use `db:migrate` for Stage 2 disposable setup, not
  a catch/skip or fake successful seed loader. `db:seed` remains expected red.
- A structural test initially reused an in-memory attribute changed inside a
  rolled-back transaction; reloading the fixture before the uniqueness check
  fixed this test-harness bug. The passing baseline above is after that fix.
- SQLite databases live only at `/tmp` inside removed containers; no developer
  database or production data is migrated. Final evidence supplements below.

Final validation, after adding the temporary route-skeleton test:

- Same prefix, `bin/rails db:migrate && bin/rails test
  test/models/backend_structure_test.rb test/integration/backend_skeleton_test.rb
  test/integration/health_check_test.rb && bin/rails zeitwerk:check &&
  bin/rubocop`: passed, **9 tests / 45 assertions**, autoload good,
  **38 Ruby files / no offenses**.
- Same prefix, `bin/rails db:migrate && bin/rails test`: intentionally red,
  **19 tests / 54 assertions / 9 failures / 1 error / 0 skips**.
  Failures are exactly the six admin API and three timeline contract tests;
  the error is exactly the seed-loader FeatureNotImplemented. No other failures.
- Postgres compatibility: created task-scoped `postgres:17-alpine` container
  `bookfall-stage2-pg-7d66451e`, waited for `pg_isready`, then ran the same Ruby
  container with `--network container:bookfall-stage2-pg-7d66451e`,
  `RAILS_ENV=test`, disposable Postgres DATABASE_URL, and
  `SCHEMA=/tmp/bookfall-stage2-pg-schema.rb`. Exact Rails commands:
  `bin/rails db:migrate && bin/rails test test/models/backend_structure_test.rb
  test/integration/backend_skeleton_test.rb test/integration/health_check_test.rb`.
  Passed both migrations and **9 tests / 45 assertions**. The container/database
  was stopped and automatically removed; verified no matching container remains.
  No ports were published, and SQLite's committed schema was preserved.
- `git diff --check`: passed. Existing requirements edits preserved; only
  backend skeleton/tests/dependency, shared status/docs, and README added.
- Frontend/browser checks skipped: no frontend runtime changes. Live Neon,
  deployment and production cache smoke checks skipped: outside this Stage 2
  unit; Postgres test compatibility is not deployed-environment evidence.

Stage 2 skeleton acceptance passed under the documented expected-red exception.
Business feature completion is not claimed. Stage 2 remains in design review:
span length, retention/cache guarantees, provisioning/rate-limit proposals
need confirmation before affected Stage 3 logic. No Stage 3 task or commit
authorized. Stop for review, Stage 3 approval and user task selection.

## Validation and commit checkpoint

- 2026-10-24: User explicitly requested review and commit of the pending
  Stage 2 changes. Review found no blocking skeleton defect. The generated
  workflow under `backend/.github/workflows/` is not discoverable by GitHub;
  this is pre-existing and unchanged, reserved for deployment/CI work.
- Review validation rerun in the documented Ruby container:
  `bin/rails db:migrate` followed by the structural/route/health selection:
  **12 tests / 62 assertions passed**; `bin/rails zeitwerk:check` passed;
  `bin/rubocop`: **44 files, no offenses**;
  `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
  **0 warnings/errors**; `bin/bundler-audit`: **no vulnerabilities found**.
- Full `bin/rails test` rerun: **24 tests / 71 assertions / 9 failures /
  3 errors / 0 skips**, matching the documented expected-red baseline exactly.
  This commit is a Stage 2 checkpoint, not a green full-suite, merge, release,
  or Stage 3 readiness claim. `bin/ci` setup/seed/full-test steps cannot pass
  while the documented stubs remain; assertions/gates were not weakened.
- Postgres structural validation remains the recorded 12-test/62-assertion
  pass from the same unchanged schema; not rerun during this review.
  Frontend/browser/live deployment checks skipped: no relevant runtime changes
  or deployment authorization. `git diff --check` passed.
- Commit authorization does not authorize Stage 3 work or publication.

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

2026-10-24 schema revision: recorded the user-selected three tables and replaced
affected pending work. Requirements remain unresolved; no migrations or source
changes made. Documentation whitespace checked with `git diff --check`;
application tests skipped because this change only records requirements.

2026-10-24 clarification: add `Books.user_id`; no non-admin account
implementation. Confirm rank 1..12 inclusive, nullable finished timestamp and
review fields, admin-only writes including ratings/reviews, and UTC storage
with club-timezone grouping. Rank cycling and the exact timezone remain open.
Documentation-only; application checks skipped. No task or stage completed.

2026-10-24 follow-up: UTC day grouping confirmed. Rank assignment/reuse and
tie policy belong to future frontend implementation, not backend Stage 1.
BE-REVISION retains the bounded storage/API and pair-consistency requirements;
algorithm-dependent implementation must await that contract rather than use
a silent placeholder. No task or lifecycle approval is implied.
