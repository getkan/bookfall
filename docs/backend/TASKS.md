# Backend tasks

## Current scope and session

- ID: **BACKEND**; [SPEC](SPEC.md), [ROADMAP](ROADMAP.md).
- Lifecycle: Stage 4 feature-wide review, **Completed**; approved by the user
  on 2026-10-24. Review remediation validated; awaiting commit/handoff.
- Stage 2: **Completed**, accepted by the user on 2026-10-24 after the
  reviewed architecture, skeleton and expected-red contract checkpoint.
- Stage 3 approval: granted on 2026-10-24. BE-BOOK and remaining model work
  were committed as `7b1b563`. BE-AUTH, GET /books and Books-only BE-SEEDS
  were committed as `ae58b2d`. User then selected finishing the book controller
  (remaining BE-CRUD), committed as `35a15f5`. User then selected event creation
  via book_events:sync and approved randomized ranks/overflow/preservation.
  Sync projection implemented below, uncommitted. User then selected the
  book-events controller with joined Book title/author/user_id/rating,
  explicitly excluding review; pagination/revision/refresh implemented below.
  Sync/ranks/timeline were committed as `ae169ef`. User now selected four
  sequential units: sync publication, CORS, PostgreSQL acceptance, then
  feature-wide review, reviewing each. Complete/review one unit and pause at
  its commit checkpoint; Stage 4 approval remains separate.
  Frontend implementation remains unselected. No commit implicitly authorized.
- `user_id` remains a nullable string placeholder, with no user association.
- FRONTEND remains Stage 1; DEPLOY remains blocked. No commit or publication
  is authorized by this stage transition.
- Earlier session records below are history, superseded by these decisions.

## Selected follow-up: public event detail

**Completed (2026-10-25), uncommitted** — BE-EVENT-DETAIL, BACKEND-4.

- User authorized `GET /book-event/:id`. Plan: public current-record lookup,
  `{ "book_event": {...} }` envelope, shared timeline field serialization and
  existing JSON not-found behavior. Keep revision-pinned list behavior intact.
- Reviewed controller/routes, BookEvent, Timeline::Refresh, event integration
  tests, application error/auth helpers and existing SPEC/TASKS before editing.
- Shared `BookEvent.with_book_details` query and `timeline_payload` serializer
  serve both detail and snapshot building. Single join, no User credentials;
  completed reviews only. Detail reads live data without cache mutation.
- Four integration tests cover START/FINISH payload parity, live values versus
  pinned snapshots, null fields/unfinished-review visibility, missing/deleted
  events and JSON 404 responses.
- Focused command: `bin/rails test test/integration/book_events_test.rb
  test/integration/timeline_contract_test.rb
  test/integration/book_event_sync_publication_test.rb`: **29 tests,
  595 assertions**, all passing. RuboCop on five touched Ruby files passed.
- Full `bin/rails test`: **129 tests, 1,656 assertions**, zero failures/errors/
  skips on SQLite and disposable PostgreSQL. `bin/rails db:prepare`,
  `bin/rails db:seed:replant` and `bin/rails book_events:sync` passed on both.
  SQLite `bin/rails zeitwerk:check`, `bin/rubocop` (61 files),
  `bin/bundler-audit` and
  `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` passed.
- Direct review verified single-query projection, public detail access,
  same event field whitelist, unchanged ordering/pinning and explicit missing
  event errors. `git diff --check` passed. Disposable PostgreSQL container,
  volume and network removed. No schema/dependency/frontend changes needed.
- Existing review-payload work and unrelated frontend document edits preserved.
  Stop at the commit checkpoint; no commits or publication authorized.

## Stage 4 review and provisioning remediation

**Completed (2026-10-24), uncommitted remediation** — BACKEND.

- User approved Stage 4 after Stage 3 acceptance, then authorized fixing the
  provisioning race and updating review status. Feature base `74fb80f` was
  verified as an ancestor of review HEAD `30b11d7`; read-only feature-wide
  review covered committed backend implementation, contracts, tests and
  operating procedures. No repository-defined automated review command or PR
  template was found.
- Finding resolved: concurrent `admin:provision` calls could both observe an
  empty admin set. AdminProvisioning now locks before either existence check:
  PostgreSQL `LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE`, SQLite a no-op
  UPDATE obtaining the transaction's write lock. Transaction-scoped locks
  release on commit/rollback; no session advisory locks, new schema or
  single-admin constraint restrict future account design. Unsupported adapters
  fail explicitly. Existing refusal/error/password semantics remain unchanged.
- Added `admin_provisioning_concurrency_test.rb`: nontransactional test with
  independent connections, synchronized starts and a delayed INSERT widens
  the race window. Exactly one success, one explicit existing-admin refusal
  and one persisted admin are required. Test cleans up its users and workers.
- Regression evidence: a session-only fault-injection shim suppressed only the
  PostgreSQL lock. The new test then failed with **two successful creations**.
  An initial shim failed adapter loading; after correcting that harness issue,
  the expected assertion failure reproduced. Repository code was not altered
  for injection. Three subsequent locked PostgreSQL repetitions passed.
- Validation (Ruby 3.4.11, disposable Docker databases):
  - `bin/rails db:prepare`: passed on SQLite/PostgreSQL.
  - `bin/rails test test/integration/admin_provisioning_test.rb test/integration/admin_provisioning_concurrency_test.rb`:
    **6 tests/33 assertions**, passed on both adapters (SQLite initially before
    adding the delayed-INSERT instrumentation; final full suite covers it).
  - `bin/rails test`: **124 tests/1,625 assertions**, zero failures/errors/skips
    on both SQLite and PostgreSQL.
  - `bin/rails zeitwerk:check`: passed.
  - `bin/rubocop`: **61 files**, no offenses.
  - `bin/bundler-audit`: no vulnerabilities.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    zero errors/warnings.
  - `bin/rails db:seed:replant`, `bin/rails book_events:sync`: passed on both.
  - `git diff --check`: passed for remediation.
- Direct remediation review confirmed lock-before-read ordering, shared
  transaction boundaries, exception propagation and connection-isolated tests.
  PostgreSQL container/volume/network removed. Prior production-configured
  migration/cache and HTTP acceptance remains applicable; no HTTP interface or
  schema changed. Evidence: session `admin-race-*.log` and Stage 4 gate logs.
- Historical hygiene exception: `git diff 74fb80f...HEAD --check` flags
  `backend/requests.http:8` trailing whitespace. This user-committed collection
  remains untouched per prior direction; do not claim a clean feature-base
  whitespace check. Lifecycle approval/status text is now reconciled.
- Subsequent user request: include the Book review in public `/book-events`.
  The implementation returns a `review` key per event, exposes stored review
  only for completed Books and returns null for unfinished Books, preserving
  the approved unfinished-review visibility policy. Changed the snapshot cache
  namespace to v2 so previously published cached pages cannot hide the field;
  old pinned cursors may expire and must restart. Focused integration tests and
  validation:
  - `bin/rails test test/integration/book_events_test.rb
    test/integration/timeline_contract_test.rb
    test/integration/book_event_sync_publication_test.rb`: **25 tests,
    569 assertions**, passed; RuboCop on the three changed Ruby files passed.
  - Full SQLite `bin/rails test`: **125 tests, 1,630 assertions**, zero
    failures/errors/skips; `bin/rails zeitwerk:check`, `bin/rubocop`
    (61 files), `bin/bundler-audit`, Brakeman, `db:seed:replant`,
    `book_events:sync` and `git diff --check` passed.
  - Full disposable PostgreSQL `bin/rails test`: **125 tests, 1,630 assertions**,
    zero failures/errors/skips; `db:seed:replant` and `book_events:sync` passed.
  - New integration coverage verifies completed review values, null review for
    unfinished Books (even if a review is stored), exact event field shape,
    and ignoring cached pre-v2 payloads.
  - Database change uses ordinary joined columns; review visibility is applied
    during serialization, with no raw SQL interpolation. No schema or gem
    changes. Existing unrelated uncommitted `docs/frontend/*` edits were
    preserved. No frontend implementation or browser validation was needed.

### Handoff / PR summary (not published)

- Scope: model constraints; admin provisioning/login/token/rate limiting;
  protected book CRUD; randomized paired event ranks; incremental sync and
  atomic Solid Cache publication; immutable revision/date-span timeline;
  Books-only seeds; configured-origin CORS; complete cross-adapter acceptance.
- Review result: actionable provisioning finding resolved with demonstrated
  regression coverage; complete local gate passes. Remediation is uncommitted.
- Residual risks: advanced sync overlap/concurrent writes and scheduler
  infrastructure remain deferred. Nested backend CI workflow discoverability
  is inherited, not repaired here. Optional libvips warning is unrelated to
  implemented API behavior. Browser layout, Neon/Vercel/deployment were not
  tested or authorized; FRONTEND stays Stage 1 and DEPLOY remains blocked.
- Stop for commit/handoff. No commit, push, PR creation, frontend stage
  transition or deployment is authorized by this completion.

## Stage 3 selected unit: PostgreSQL acceptance

**Completed (2026-10-24), reviewed, uncommitted evidence** — BACKEND-1 through
BACKEND-6. CORS was committed as `aecc469`; user authorized continuing.

- Scoped plan: run the existing complete suite against disposable PostgreSQL;
  migrate a separate empty database with production configuration; verify
  constraints, pooler settings, Solid Cache and live cross-process HTTP behavior.
  No application changes or new dependencies/tests were necessary: existing
  adapter-independent tests passed without changes or weakened assertions.
- Reviewed inputs: database/production/cache configuration, three migrations,
  test helper, database constraint and cache-publication rollback tests,
  BookEventSync, Timeline::Refresh, User, book controller/routes, CI commands,
  SPEC acceptance and ROADMAP exit criteria. Existing work was preserved.
- Isolation: task-scoped Docker network and `postgres:17-alpine` container
  (PostgreSQL **17.11**), no host ports or external database URLs. Separate
  databases `bookfall_acceptance` (test) and `bookfall_production_acceptance`
  (production configuration); Ruby **3.4.11**, Rails **8.1.4**.
  Disposable credentials/signing key were not used outside this harness.
- Test database commands, inside the Ruby Docker container with
  `BUNDLE_PATH=/stage2-gems`, `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, and
  `DATABASE_URL=postgresql://postgres@postgres/bookfall_acceptance`:
  - `bin/rails db:prepare`: passed.
  - `bin/rails test`: **123 tests, 1,619 assertions**, zero failures/errors/skips;
    repeated with the full final gate and passed again. Includes SQL-enforced
    chronology/rating/rank/type/uniqueness and real-cache transaction rollback
    tests, auth/CRUD, ranks, cursor isolation/expiry and CORS.
  - `bin/rails zeitwerk:check`: passed.
  - `bin/rubocop`: **60 files**, no offenses.
  - `bin/bundler-audit`: no vulnerabilities.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    zero errors/warnings.
  - `bin/rails db:seed:replant` and `bin/rails book_events:sync`: passed.
- Empty production-configured database:
  - `RAILS_ENV=production bin/rails db:migrate`: all three migrations applied;
    verified their versions and all six domain/checkpoint checks plus event
    foreign key directly in PostgreSQL catalogs.
  - `bin/rails runner`: verified PostgreSQL adapter, `SELECT 1`, disabled prepared
    statements/advisory locks, Solid Cache write/read and shared primary pool.
  - `bin/rails db:seed` twice: exactly **17 Books**, zero events/users before
    disposable admin creation; `bin/rails book_events:sync` published **19 events**.
  - `bin/rails server -b 127.0.0.1 -p 3100 -P /tmp/bookfall-acceptance.pid`:
    `/up` returned **200** before the live walkthrough. Server accessible only
    inside its disposable container.
  - HTTP walkthrough: approved Authorization/JSON preflight, no cookie credentials,
    rejected unauthorized write, admin login/list/create/show/update/delete,
    finish-before-start **422**, complete **19-event** cursor traversal without
    duplicates, joined fields/rating, paired ranks, new revision
    after a separate sync process, old cursor retention and deletion publication.
    All assertions passed.
- Direct acceptance review: migrations and schema-loaded tests agree; primary
  pool/cache atomicity and production adapter flags verified, no adapter-specific
  regressions or actionable findings. Optional image processing emitted a
  missing-libvips warning; no image features are implemented/exercised. No
  dependency installed for that unrelated warning.
- Evidence retained in session artifacts: `postgres-acceptance.log`,
  `postgres-final-gate.log`, `postgres-production-acceptance.log`,
  `postgres-http-acceptance.log` and the HTTP walkthrough script.
  Disposable Rails/Postgres containers, Postgres volume and network removed.
- `git diff --check`: passed. No production/Neon, Vercel or browser rendering
  validation claimed. Advanced sync overlap/concurrent-write risk remains
  explicitly deferred. Full SQLite gate passed in the preceding CORS unit;
  application/test sources were unchanged by this acceptance unit.
- Stage 3 exit evidence now passes. Stop for the evidence commit checkpoint
  and request explicit Stage 4 approval before feature-wide review; that review
  is not performed or implied by this unit's acceptance review.

## Stage 3 selected unit: CORS

**Completed (2026-10-24), reviewed, uncommitted** — BE-CORS, BACKEND-5.

- Prior publication unit is committed as `69d7dfe`; user authorized continuing.
- Scoped plan: enable rack-cors; configure one exact frontend origin before
  other middleware; allow the approved methods and any request headers,
  including Authorization/Content-Type, without cookie credentials. Preserve
  normal admin authentication and reject malformed configuration at boot.
- Reviewed inputs/changed surfaces: Gemfile/lockfile, cors initializer,
  application configuration, environment example, authentication integration
  tests, new cors integration tests, README and backend planning documents.
- Added five integration tests covering approved preflight methods/headers,
  actual authenticated and unauthorized responses, rejected origins (including
  prefix lookalikes and null), PUT rejection, no credentials, Vary: Origin,
  and requests without Origin.
- Validation in disposable Ruby 3.4 Docker/SQLite:
  - `bundle install --jobs 4`: added rack-cors 3.0.0; no unrelated upgrades.
  - `bin/rails db:prepare`: passed.
  - `bin/rails test test/integration/cors_test.rb test/integration/authentication_test.rb`:
    **15 tests, 292 assertions**, no failures/errors/skips.
  - `FRONTEND_ORIGIN=https://frontend.example.test bin/rails test test/integration/cors_test.rb`:
    **5 tests, 76 assertions**, all passing.
  - `bin/rails test`: **123 tests, 1,619 assertions**, no failures/errors/skips.
  - `bin/rails zeitwerk:check`, `bin/rubocop` (60 files),
    `bin/bundler-audit`, and
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed.
  - `bin/rails db:seed:replant` and `bin/rails book_events:sync`: passed.
  - Five separate `bin/rails runner` boot checks reject wildcard, path,
    trailing slash, null and empty origins with the explicit configuration error.
  - `git diff --check`: passed.
- Direct review: exact origin matching, middleware order, approved methods,
  no credential header, independent auth and scoped dependency lock changes
  verified; no actionable findings. Middleware tested through the real Rails
  integration stack; frontend browser rendering/live deployment not tested.
  PostgreSQL acceptance remains the next selected unit.
- Stop here for the CORS commit checkpoint. Stage 4 still requires Stage 3
  acceptance and separate approval; no frontend/deployment work authorized.

## Stage 3 selected unit: sync-to-cache publication

**Completed (2026-10-24), reviewed, uncommitted** — BE-SYNC, BACKEND-3/6.

- Plan/source review: BookEventSync, Timeline::Refresh, TaskCheckpoint,
  cache configuration/Solid Cache connection inheritance, sync contracts,
  backend SPEC/ROADMAP/TASKS and CI gates.
- Sync calls the existing refresh builder inside its event/checkpoint
  transaction, explicitly using Solid Cache. Guard shared primary connection
  pool before work; refuse separate-cache configurations rather than falsely
  claim atomicity. Refresh's default cache remains Rails.cache for other callers.
- Publish every successful run, including no-op runs to reflect hard deletions.
  Existing pinned revisions remain available. Cache build/write/pointer or
  final checkpoint failure rolls back snapshot, pointer, events and watermark;
  existing failed-attempt monitoring survives and the original exception raises.
- Four new integration tests use real Solid Cache, not MemoryStore:
  joined values published/pinned old cursor, no-op deletion publication,
  snapshot/pointer failure rollback and retry, final checkpoint SQL failure
  after pointer write proving all persisted state rolls back.
- Validation: Ruby 3.4 Docker, disposable SQLite, existing session gem cache,
  RAILS_ENV=test, PARALLEL_WORKERS=1:
  - `bin/rails db:prepare`: passed.
  - `bin/rails test test/integration/book_event_sync_publication_test.rb
    test/integration/book_event_sync_test.rb test/integration/book_event_sync_contract_test.rb
    test/integration/timeline_contract_test.rb`: **32 tests / 443 assertions,
    0 failures / 0 errors / 0 skips**.
  - Full `bin/rails test`: **118 tests / 1543 assertions, 0 failures /
    0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`: **59 files, no offenses**;
    `bin/bundler-audit`: no vulnerabilities;
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: no warnings.
  - `bin/rails db:seed:replant`, `bin/rails book_events:sync`, separate
    `bin/rails runner` process reading Solid Cache: published **19 events**.
- Post-implementation direct review: cache writes participate in the primary
  connection transaction, prior revisions are not overwritten, final-checkpoint
  rollback verified, default explicit refresh behavior unchanged. No actionable
  findings. Full gate commands run individually, avoiding setup's shared
  log/temp cleanup. PostgreSQL validation is the selected third unit, not yet
  performed; advanced sync overlap/concurrent-write risk remains deferred.
- Stop here for commit checkpoint. CORS and PostgreSQL are not started;
  feature-wide Stage 4 review waits for Stage 3 acceptance and approval.

## Stage 3 selected unit: book-events controller, joined fields and revisions

**Completed (2026-10-24)** — BE-EVENTS and BE-REVISION, uncommitted.

- User explicitly continued beyond the pending sync checkpoint, selecting the
  event controller and Book title/author/user/rating; follow-up excluded review.
  user_id remains the nullable opaque Book value, with no User association.
- Reviewed BookEventsController, Timeline::Page/Refresh, Book/BookEvent,
  timeline/skeleton contracts, development cache configuration, backend
  SPEC/ROADMAP/TASKS and frontend payload expectations before editing.
- Implement public before/after/cursor navigation in 30-day whole UTC spans,
  bounds/terminal/empty spans, stable FINISH-before-START ordering and signed
  versioned cursors pinning revision/direction/next boundary. Reject duplicate,
  conflicting, empty or nonscalar parameters, invalid timestamps/cursors;
  unavailable revisions return 410 with explicit restart instructions.
- Build immutable serialized revisions from one joined BookEvent/Book query:
  event identity/date/type/rank, title/author/user_id/rating, and review for
  completed Books only. Unfinished review content remains hidden. No credential
  fields. Continuations and cached initial requests do not
  reload Books. Retention is fixed at up to 24 hours from publication, not
  extended by reads. Write snapshot before current pointer, check both writes;
  failure raises and preserves prior current revision/checkpoint.
- Complete book_events:refresh_cache; initial timeline requests publish only
  when current revision is missing/expired. Development uses Solid Cache so
  separate rake/API processes see the same revisions. Sync projection remains
  separate; automatic publication integration is not claimed complete.
- Added six event integration tests: exact joined field shapes/no reviews,
  one SQL join/no cache-hit DB reads, pinned rating/deletion payloads, snapshot
  and pointer write failures, typed/signed malformed inputs and stable ties.
  Existing 14 timeline contracts pass unchanged; replace obsolete timeline
  501 skeleton expectation with the implemented public envelope.
- Validation: Ruby 3.4 Docker, disposable SQLite, session gem cache,
  RAILS_ENV=test, PARALLEL_WORKERS=1:
  - `bin/rails db:prepare`: passed.
  - `bin/rails test test/integration/timeline_contract_test.rb
    test/integration/book_events_test.rb test/integration/backend_skeleton_test.rb`:
    **21 tests / 529 assertions / 0 failures / 0 errors / 0 skips**.
  - Full `bin/rails test`: **114 tests / 1506 assertions / 0 failures /
    0 errors / 0 skips**. No expected-red exception needed.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`:
    **58 files, no offenses**; `bin/bundler-audit`: no vulnerabilities;
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    no warnings/errors.
  - `bin/rails db:seed:replant` and `bin/rails db:seed`: passed.
- Live HTTP on a disposable development database: db:prepare + book_events:sync,
  verified server health/readiness; public joined fields/rating and no review,
  all 19 events traversed with pinned revision, before/after and bad cursor
  400. Edited Book title/rating then ran a separate-process
  `bin/rails book_events:refresh_cache`; API saw new revision/values and prior
  cursor still used its original revision. Server stopped afterward.
- Gate commands run individually, not bin/setup clearing shared logs/tempfiles.
  PostgreSQL and frontend/browser/CORS checks not run: no schema/frontend/CORS
  implementation changed. Whole-backend readiness and Stage 4 remain unapproved;
  CORS, scheduled publication integration and cross-adapter acceptance remain.
- Preserve pending sync/rank implementation and documentation changes.
  Nothing staged or committed. Stop at this unit's commit checkpoint.

## Stage 3 selected unit: book_events:sync projection and ranks

**Projection unit completed (2026-10-24); BE-SYNC In progress** — BACKEND-3/6.

- User approved backend random ranks: pick an unused rank in 1..12 across
  STARTs on the UTC start day and FINISHes on the UTC finish day; if full,
  randomly choose among the least-used ranks by combined count. Unfinished
  books use START day only. Preserve existing START rank (otherwise FINISH)
  for both events, including added completion and date edits. Frontend handles
  remaining collisions; this supersedes the frontend-owned assignment deferral.
- Reviewed BookEventSync, TaskCheckpoint, Book/BookEvent models, rake entry
  point, sync/CRUD contracts, shared layout and backend/frontend project docs.
  Implemented only the selected projection unit, not revision publication,
  scheduler infrastructure, frontend rendering or advanced coordination.
- BookEventSync captures run-start time, processes first-run Books up to that
  bound, then uses inclusive prior-watermark through captured-bound selection
  ordered by updated_at/id. Creates START/optional FINISH, corrects dates,
  removes obsolete FINISH, preserves event identities/ranks and repairs pair
  rank mismatches using START's persisted rank.
- Projection event writes and successful watermark/count/status updates share
  one transaction. Failures roll back, retain prior successful state, record
  failed attempt timing and exception class (no SQL/book content), log and
  re-raise. No-op runs succeed; no success-shaped exception fallback.
- Added 9 focused sync tests for random nonsequential fill, all 12 ranks before
  reuse, least-used overflow, both day/type occupancy groups, opposite-type
  and adjacent-day exclusion, UTC offset/day boundaries, rank preservation on
  completion, partial-pair recovery, captured bounds/no-op monitoring and
  injected first-run rollback/sanitized failure/retry. Existing 5 sync contracts
  now pass without weakening assertions.
- Validation: Ruby 3.4 Docker, session gem cache, disposable SQLite,
  RAILS_ENV=test, PARALLEL_WORKERS=1:
  - `bin/rails db:prepare`: passed.
  - `bin/rails test test/integration/book_event_sync_test.rb
    test/integration/book_event_sync_contract_test.rb test/integration/book_crud_test.rb
    test/integration/backend_contract_test.rb test/integration/book_listing_test.rb
    test/integration/authentication_test.rb test/integration/admin_provisioning_test.rb
    test/integration/staging_seeds_contract_test.rb test/integration/backend_skeleton_test.rb
    test/models test/integration/health_check_test.rb`:
    **94 tests / 980 assertions / 0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`:
    **56 files, no offenses**; `bin/bundler-audit`: no vulnerabilities;
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    no warnings/errors.
  - Full `bin/rails test`: **108 tests / 994 assertions / 14 failures /
    0 errors / 0 skips**. All 14 failures are timeline 501 contracts;
    the sync fault-injection failure and four sync errors are resolved.
  - `bin/rails db:seed:replant`, `bin/rails db:seed`, then
    `bin/rails book_events:sync` twice: passed. First sync produced 19 events
    from 17 Books, no users, and equal pair ranks; second retained identical
    event IDs/dates/ranks and a succeeded checkpoint.
- Updated README, shared layout and backend/frontend rank contract references;
  frontend remains Stage 1, no implementation approval or stage transition.
- Required final gates run individually to avoid bin/setup clearing shared
  logs/tempfiles. PostgreSQL and browser rendering were not revalidated;
  schema/frontend code unchanged. Run one sync at a time; concurrent syncs or
  uncommitted/backdated writes may still race as already approved/deferred.
- Projection success advances only the projection watermark. BE-SYNC overall
  stays In progress until BE-REVISION publication integration exists; no
  current timeline cache is published or invalidated by this task.
- Nothing committed. Stop at this implementation-unit commit checkpoint.

## Stage 3 selected unit: BE-CRUD (remaining book actions)

**Completed (2026-10-24)** — BACKEND-1/2, uncommitted.

- Plan/source review: BooksController, ApplicationController, Book/BookEvent
  models, routes/schema, backend CRUD/auth/listing/skeleton contracts and
  SPEC/ROADMAP/TASKS. Preserve local requests.http edits.
- Implement show/create/update/destroy with a shared serializer preserving
  existing listing output. Allow only book attributes, preserve omitted PATCH
  fields, return JSON error envelopes for invalid object/value shapes (400),
  missing records (404), and model validation failures (422).
- PATCH atomically updates dates on existing associated events, retaining IDs
  and ranks, and removes FINISH when completion is cleared. DELETE removes
  the Book and events atomically. No new events, rank assignment, synchronization,
  checkpoint changes or timeline cache publication.
- Added 10 CRUD integration tests including parameter shapes, attribute
  filtering, partial writes, invalid writes, conditional serialization,
  missing records, completion removal/addition, and injected update/deletion
  failures proving rollback. Reuse existing full CRUD and cascade contracts;
  update auth expectations and retain the timeline-only skeleton assertion.
- Validation: Ruby 3.4 Docker, disposable SQLite, RAILS_ENV=test,
  PARALLEL_WORKERS=1, existing session gem cache:
  - `bin/rails db:prepare`: passed.
  - `bin/rails test test/integration/book_crud_test.rb
    test/integration/backend_contract_test.rb test/integration/book_listing_test.rb
    test/integration/authentication_test.rb test/integration/admin_provisioning_test.rb
    test/integration/staging_seeds_contract_test.rb test/integration/backend_skeleton_test.rb
    test/models test/integration/health_check_test.rb`:
    **80 tests / 929 assertions / 0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`:
    **55 files, no offenses**; `bin/bundler-audit`: no vulnerabilities;
    `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    no warnings/errors.
  - Full `bin/rails test`: **99 tests / 944 assertions / 15 failures /
    4 errors / 0 skips**. Exactly 14 timeline HTTP 501 failures, one sync
    fault-injection expectation reaching its stub, and four sync stub errors.
    No remaining CRUD failures; full backend is not yet green.
  - `bin/rails db:seed:replant` and `bin/rails db:seed`: passed.
- Live HTTP: task-scoped Rails server on a disposable database, initialized
  via AdminProvisioning; health/readiness verified, anonymous books 401,
  login 200, create 201, detail/update 200, invalid rating 422, missing payload
  400, delete 204 and post-delete detail 404. Persisted event ID/rank/date
  update and cascade checked. Server stopped; no user database changed.
- Full gate commands run individually rather than bin/ci's setup wrapper,
  which clears shared logs/tempfiles. PostgreSQL and browser/CORS not run:
  no schema/frontend/CORS changes; cross-adapter and feature-wide acceptance
  remain required before BACKEND completion. Advanced write/sync race risk
  remains deferred as approved in SPEC.
- Stop at this unit's commit checkpoint; no next task selected or authorized.

## Stage 3 selected unit: BE-SEEDS (Books only)

**Completed (2026-10-24)** — BACKEND-5, uncommitted.

- User decision: seeds create Books only; BookEvents are created by
  `book_events:sync`. Supersedes the earlier seeded-events requirement.
- `StagingSeeds.load!` reads `db/seeds/books.yml`, validates every record,
  and creates missing Books by title/author/started_at in one transaction.
  Fixture IDs are ignored, avoiding PK collisions/sequence drift on Postgres;
  existing matches are not modified. No users, events, sync or cache work.
  Natural keys are not DB-unique; concurrent seed runs are not supported.
- Moved event data from `db/seeds/book_events.yml` into
  `test/fixtures/book_events.yml`; test fixtures are unchanged.
- Rewrote `staging_seeds_contract_test.rb` (4 tests): empty-database seed
  twice, existing books/events preserved, only missing books created without
  fixture IDs, invalid data raises and creates nothing.
- Evidence (Ruby 3.4 Docker, disposable SQLite, after `bin/rails db:migrate`):
  - `bin/rails test test/integration/staging_seeds_contract_test.rb`:
    **4 tests / 23 assertions / 0 failures**.
  - Fresh database `bin/rails db:seed` twice: **17 books, 0 events, 0 users**
    after each run.
  - `bin/rails zeitwerk:check` passed; `bin/rubocop` **54 files, no offenses**;
    Brakeman **no warnings**.
  - Full `bin/rails test`: **89 tests / 694 assertions / 20 failures /
    4 errors / 0 skips**. The seed-loader error is resolved; remaining are
    CRUD/timeline 501s and sync stubs. `db:prepare` no longer stops at seeds.

## Stage 3 selected unit: GET /books (partial BE-CRUD)

**Completed (2026-10-24)** — list action only, BACKEND-1/2.

- Reproduced local anonymous GET /books 401 and authenticated GET /books 501
  at the explicit listing stub. Authentication is required, not an error to
  remove. User requested resolving the endpoint failure, continuing beyond
  the prior commit checkpoint without committing.
- Implement index using all Books in ascending ID order, with explicit
  id/user_id/title/author/started_at/finished_at fields; completed books also
  expose nullable rating/review. Unfinished books omit both even if stored.
  Empty data returns `{ "books": [] }`. No records or credentials modified.
- Added three listing integration tests for full field/value shape, stable
  complete list, conditional reviews and empty state. Adjusted auth/skeleton
  tests only for the newly implemented list action; all other stubs remain.
- Documented Ruby 3.4 Docker prefix, disposable SQLite, RAILS_ENV=test,
  PARALLEL_WORKERS=1, after `bin/rails db:migrate`:
  - `bin/rails test test/integration/book_listing_test.rb
    test/integration/authentication_test.rb test/integration/admin_provisioning_test.rb
    test/integration/backend_skeleton_test.rb test/models
    test/integration/health_check_test.rb`:
    **58 tests / 634 assertions / 0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`: **54 files, no offenses**.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    **0 warnings/errors**; `bin/bundler-audit`: **no vulnerabilities**.
  - Full `bin/rails test`: **86 tests / 671 assertions / 20 failures /
    5 errors / 0 skips**. The existing combined list/show contract now proceeds
    past listing and fails at the show stub, rather than the list stub.
    Other CRUD, timeline, sync and seed contracts remain unimplemented.
- Verified actual local server after the change: authenticated GET /books 200,
  valid books envelope with zero books; anonymous GET /books remains 401.
  Token stayed in process memory; no credentials, tokens or book payloads
  printed, no sample data inserted. Docker host networking could not reach the
  host server, so generated the signed test token in the container and sent
  the request from the host without displaying it.
- PostgreSQL not rerun (no schema change); no browser changes. README,
  requests.http and SPEC distinguish implemented listing from remaining stubs.
  BE-CRUD overall remains In progress, not Completed.
- No commit created; stop at the implementation-unit commit checkpoint.

## Stage 3 selected unit: BE-AUTH

**Completed (2026-10-24)** — BACKEND-2.

- Plan: explicit `admin:provision` task/service from environment, refusing
  existing admins/usernames without overwriting or promoting accounts.
  Login validates admin credentials and returns the existing 12-hour
  password-bound token. Every book action requires a valid bearer and current
  admin role; anonymous/invalid requests get 401, non-admin tokens get 403.
- Add a database-backed Solid Cache login counter in every environment:
  10 attempts/IP/3 minutes, successful and failed attempts counted,
  429 rate_limited with conservative Retry-After 180 seconds. Missing cache
  counter results fail explicitly rather than bypassing the limiter.
- Configure explicit TRUSTED_PROXY_CIDRS (default no trusted proxy); ignore
  forwarding headers from untrusted peers. Verify real proxy ranges and ingress
  sanitation during deployment; do not invent trusted infrastructure.
- Tests: provisioning success/errors/refusal/rake behavior, login and all book
  authorization boundaries, token expiry/tamper/password revocation/deletion/
  current role, IP isolation/spoofing/proxy handling, reset timing, mixed
  successful/failed attempts, shared cache stores and explicit store failure.
- Replace temporary skeleton assertions only for implemented auth paths:
  authorized book actions and public timeline still explicitly return 501.
  No business contract assertion is weakened to accept a stub.
- Implementation: `AdminProvisioning.call`, `admin:provision`,
  SessionsController login/shared limiter, ApplicationController admin guard,
  BooksController filter, and explicit trusted-proxy initializer. User's
  existing password-bound token implementation is reused, not duplicated.
  Provisioning rejects any existing admin or occupied username; no implicit
  rotation, account promotion or startup task.
- Added 15 auth/provisioning integration tests. Existing backend contract
  tests isolate the login cache per test; the temporary skeleton test now
  exercises authorized unimplemented actions instead of expecting login 501.
- Exact validation uses the documented Ruby 3.4 Docker prefix with disposable
  SQLite, `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, after `bin/rails db:migrate`:
  - `bin/rails test test/integration/authentication_test.rb
    test/integration/admin_provisioning_test.rb test/integration/backend_skeleton_test.rb
    test/models test/integration/health_check_test.rb`:
    **55 tests / 524 assertions / 0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`: **53 files, no offenses**.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    **0 warnings/errors**; `bin/bundler-audit`: **no vulnerabilities**.
  - Full `bin/rails test`: **83 tests / 559 assertions / 20 failures /
    5 errors / 0 skips**. Exactly 19 CRUD/timeline HTTP 501 failures, one
    injected-SQL expectation hitting the sync stub, four sync and one seed
    stub errors. BE-AUTH tests pass; the full backend/CI is not green.
- Live HTTP smoke against a task-scoped Rails server/disposable database:
  run migrations and `bin/rails admin:provision`, then verify `/up` 200,
  login 200/token, anonymous `/books` 401, admin `/books` reaching its 501
  stub, ten successful login attempts and eleventh 429/Retry-After 180.
  Server stopped and container removed; no user database or account changed.
- Verified application boot fails with IPAddr::InvalidAddressError for
  `TRUSTED_PROXY_CIDRS=invalid-proxy`. Initial IP-spoof tests exposed Rails'
  forwarded-address precedence even for untrusted peers; implemented and
  tested an explicit direct-peer trust guard before using request.remote_ip.
- Shared limiter tested using two SolidCache::Store instances against the
  disposable SQLite database, including a blocked attempt near the end of the
  window and successful reset without sliding expiry, not only a memory-store
  substitute. Invalid
  counter results raise explicitly. PostgreSQL/live deployment proxy topology
  not tested in this unit; schema unchanged and deployment remains deferred.
  Browser/CORS checks skipped: no frontend or CORS implementation changed.
- `git diff --check` and relative documentation links passed. Updated README,
  environment example, request collection and SPEC with actual login status,
  provisioning command, proxy configuration and remaining stub behavior.
- Commit checkpoint: nothing committed; stop before another implementation unit.

## Stage 3 selected unit: remaining models

**Completed (2026-10-24)** — model-only portions of BACKEND-2/3/6.

- Plan: User validates required/unique username and boolean admin flag,
  retaining bcrypt protections; add 12-hour password-salt-bound api_access
  tokens with expiry, tamper, revocation and current-record lookup tests.
  BookEvent validates its existing book, START/FINISH type, unique book/type,
  valid date and integer rank 1..12. TaskCheckpoint validates required/unique
  task name, defined status, nonnegative integer count and non-null metadata.
- Add focused model tests; adapt database-constraint tests to bypass model
  validation deliberately, preserving their database exception assertions.
  No schema migration, HTTP authorization, admin provisioning, event
  reconciliation, rank allocator or checkpoint state machine is added.
- Model validation does not reconcile event dates/ranks against Books or other
  events. Those cross-record operations belong to the selected future sync/CRUD
  work; do not add callbacks that violate the scheduled-sync contract.
- Preserve all earlier pending changes. Stop at a commit checkpoint after
  validation; no commit or next implementation unit authorized.
- Added 18 model tests in `user_test.rb`, `book_event_test.rb`, and
  `task_checkpoint_test.rb`. User tests prove hashing/confirmation, username
  validation, boolean role, signed token resolution/tamper/12-hour expiry,
  password revocation, current-role lookup and deletion.
- Validation uses the documented Ruby 3.4 Docker prefix with disposable SQLite,
  `RAILS_ENV=test`, `PARALLEL_WORKERS=1`, after `bin/rails db:migrate`:
  - `bin/rails test test/models test/integration/backend_skeleton_test.rb
    test/integration/health_check_test.rb`: **40 tests / 280 assertions /
    0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed; `bin/rubocop`: **48 files, no offenses**.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    **0 warnings/errors**; `bin/bundler-audit`: **no vulnerabilities**.
  - Full `bin/rails test`: **68 tests / 304 assertions / 23 failures /
    5 errors / 0 skips**. Same existing boundaries: 22 HTTP 501 failures,
    one injected-SQL expectation encountering the sync stub, four sync and
    one seed-loader unimplemented errors. No new model/structural failures.
    Full backend acceptance/CI remains red, not waived by model completion.
- An initial run exposed a database uniqueness test intercepted by the newly
  added validation; corrected its database-write bypass and reran successfully.
- `git diff --check` passed. PostgreSQL not rerun: schema unchanged. Browser
  and manual API checks skipped because endpoints/frontend are unchanged.
- BE-AUTH, BE-REVISION and BE-SYNC are not complete: provisioning, HTTP auth,
  rate limiting, cache revisions and event/checkpoint workflows still need
  their own selected units and passing acceptance. Commit checkpoint reached;
  nothing committed and no further implementation started.

## Stage 3 selected unit: BE-BOOK

**Completed (2026-10-24)** — BACKEND-1 model validation unit only.

- Plan/scope: require nonblank title/author and a valid started_at; permit
  nullable finished_at/rating/review and opaque nullable string user_id.
  Validate integer ratings 1..5 and completion at/after start; reject supplied
  invalid completion timestamps rather than silently clearing them.
- Changed `backend/app/models/book.rb`; added
  `backend/test/models/book_test.rb` with 10 tests covering required/nullable
  values, all valid ratings, invalid/fractional ratings, chronology including
  equality, malformed timestamps, opaque user_id, clearing optional fields,
  and invalid updates preserving stored data.
- No migration, user association, controller/auth/serialization behavior,
  event synchronization, or rank allocator added. Existing database constraints
  and dependent event association remain unchanged.
- Validation uses the documented Ruby 3.4 Docker prefix, disposable SQLite
  `sqlite3:/tmp/bookfall-be-book.sqlite3`, `RAILS_ENV=test`,
  `PARALLEL_WORKERS=1`, after `bin/rails db:migrate`:
  - `bin/rails test test/models/book_test.rb
    test/models/backend_structure_test.rb test/models/task_checkpoint_structure_test.rb
    test/integration/backend_skeleton_test.rb test/integration/health_check_test.rb`:
    **22 tests / 149 assertions / 0 failures / 0 errors / 0 skips**.
  - `bin/rails zeitwerk:check`: passed.
  - `bin/rubocop`: **45 files, no offenses**.
  - `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`:
    **0 warnings/errors**; `bin/bundler-audit`: **no vulnerabilities**.
  - Full `bin/rails test`: **50 tests / 173 assertions / 23 failures /
    5 errors / 0 skips**. Failures/errors remain the same unimplemented
    authentication/CRUD, timeline, sync and seed contracts as Stage 2.
    BE-BOOK checks pass; the backend/full CI gate is not green.
- Initial test run caught Rails' rejection of assert_equal with an expected nil;
  changed that assertion to assert_nil and reran the checks successfully.
- PostgreSQL not rerun: schema unchanged; new model behavior verified on SQLite.
  Browser/manual API checks skipped: no frontend or endpoint implementation.
  `git diff --check` passed. Prior pending documentation, request collection and
  mailer/layout removals preserved, not claimed as BE-BOOK work.
- Commit checkpoint: no commit authorized or created. Stop before another unit;
  resume after commit confirmation or explicit continuation without committing.

## Completed Stage 2 contract unit

2026-10-24 follow-up decisions supersede earlier open-policy notes:
24-hour non-sliding snapshot cache with early eviction/410 accepted; direct
browser API with CORS accepted. Add `book_events:refresh_cache` and
`Timeline::Refresh.call` explicit Stage 2 stub. Refresh publishes a new current
revision but preserves still-cached pinned revisions and the sync watermark.
PATCH updates existing book_id events; DELETE removes existing events.
Advanced concurrency coverage is explicitly deferred as low priority.

Expiry, early eviction, force-refresh/pinned-cursor, existing-event edit and
existing-event deletion contracts added. Cache tests use a private MemoryStore
per test and restore Rails.cache afterward; no application cache is cleared.
No Stage 3 runtime logic, live scheduler, or rank algorithm was implemented.
Reviewed and committed as `2f69e81`; the worktree was clean at that checkpoint.

Latest baseline for the complete expanded suite:

- Documented Ruby 3.4 Docker prefix with disposable SQLite:
  `bin/rails db:migrate && bin/rails test`:
  **40 tests / 86 assertions / 23 expected failures / 5 expected errors /
  0 skips**. Twenty-two failures are explicit HTTP 501 responses; the other
  failure expects injected SQL failure but encounters the sync stub first.
  Errors are four sync FeatureNotImplemented and one seed FeatureNotImplemented.
  No discovery/setup failures or unrelated structural regressions.
- Structural/route/health selection after db:migrate:
  **12 tests / 62 assertions passed**; `bin/rails zeitwerk:check` passed;
  `bin/rubocop`: **45 files, no offenses**. `git diff --check` passed.
- Cache expiry/eviction/
  refresh contracts now exist; advanced concurrency is intentionally deferred,
  not part of this Stage 2 test unit. Force-refresh and CRUD behaviors are
  assertions of intended future behavior; their later assertions remain blocked
  behind the present explicit HTTP/service stubs.
- No schema changes; Postgres and frontend/browser checks were not rerun.
  Review also passed Brakeman (0 warnings/errors) and dependency audit
  (no vulnerabilities). Stage 2 acceptance does not establish working business
  behavior or waive Stage 3/final validation.

2026-10-24 lifecycle transition: user requested documentation cleanup and
progression to Stage 3. Stage 2 is Completed; Stage 3 is approved but Not started
pending task selection. This documentation-only update reconciles decisions
and historical notes; runtime checks are not rerun. Validate whitespace and
links, preserve the exact historical baselines, and do not commit implicitly.

**BE-CONTRACT-EXPANSION — Completed (Stage 2 contracts only, 2026-10-24):**
user confirmed the
other endpoint contracts, 30-day spans, environment-driven one-time admin
initialization and the proposed login rate limit. Add executable tests for
anchor normalization/full days, backward traversal, boundary clipping,
same-timestamp events, invalid parameter combinations, pinned mutation
isolation, changed-book reconciliation, equal-watermark replay and failed-run
rollback/retry. Keep all Stage 3 stubs explicit.

Revision expiry and early eviction contracts were subsequently added under the
approved cache policy. Refresh failure/checkpoint invariance still need focused
tests with Stage 3 implementation. Advanced concurrent-run/write coverage is
explicitly deferred, not a remaining Stage 2 exit requirement.

Historical intermediate subset and validation (superseded by the 40-test baseline):

- Timeline tests now cover 30-day span bounds, offset/mid-day anchors, backward
  traversal and stable same-timestamp ordering, both outside-bound cases,
  conflicting/duplicate/empty parameters, invalid timestamps and payload
  consistency after source mutation.
- Sync tests now cover changed-book filtering, removed finish events, preserved
  IDs/unrelated events, exact-watermark replay, and write-failure rollback/retry.
  Failure injection subscribes to event-write SQL notifications without
  implementing or mocking a successful sync result.
- Using the documented Ruby 3.4 container prefix and disposable SQLite database:
  `bin/rails db:migrate && bin/rails test
  test/integration/timeline_contract_test.rb
  test/integration/book_event_sync_contract_test.rb`:
  **16 tests / 12 assertions / 12 expected failures / 4 expected errors /
  0 skips**. Eleven failures are HTTP 501, one expects an injected database
  failure but encounters the explicit sync stub first; all four errors are
  that same intentional FeatureNotImplemented sync exception.
- Structural regression selection (`backend_structure_test`,
  `task_checkpoint_structure_test`, `backend_skeleton_test`, `health_check_test`)
  after `db:migrate`: **12 tests / 62 assertions passed**.
  `bin/rubocop`: **44 files, no offenses**; `git diff --check` passed.
- Existing unrelated pending API documentation preserved. No application
  behavior, schemas, or Stage 3 implementation changed. Full suite/Postgres
  reruns skipped: only targeted integration tests and documents changed.
- This intermediate run predates the expiry/eviction/refresh and existing-event
  edit/delete contracts. The completed unit's full baseline is recorded above;
  true concurrent-run/write guarantees remain explicitly deferred.

API contract clarification, 2026-10-24: user accepted recommended before/after
timestamp navigation anchors with cursor-only continuation. SPEC defines full
UTC-day inclusion, chronological ordering within backward pages, boundary
clipping, terminal results, explicit errors, and revision pinning. No endpoint
behavior implemented or existing test baseline changed.

Subsequently added contract coverage: both anchor directions including timestamps
mid-day and with offsets, default earliest page, backward prepend traversal,
same-timestamp events, empty interior spans, outside-bounds anchors, conflicting/
duplicate/empty parameters, invalid timestamps/cursors and expired revisions.
These cases now exist as executable expected-red tests. The initial
documentation-only clarification used `git diff --check` and skipped runtime
checks; later test evidence and the authorized commit are recorded above.

**BE-SKELETON — Completed (Stage 2 structural unit only):** schema/models and bcrypt,
controller/service stubs with explicit logged failures, deterministic shared
seed/test data, and intended API integration tests.

- Requirements: BACKEND-1 through BACKEND-5; detailed contract in SPEC.
- Schema: Users, Books with opaque nullable string user_id, BookEvents; checks
  for rating, date ordering, event type, rank bounds and unique book/type.
- No ownership lookup, rank allocator/default, login/CRUD implementation,
  revision query, seed loader logic, or CORS behavior is implemented.
- Snapshot/retention, span/rate-limit/provisioning and direct-access decisions
  are approved in SPEC. Rank assignment stays deferred to frontend implementation.
- Tests cover structural constraints, fixture geometry cases, route discovery,
  intended login/admin CRUD, serialization, UTC span completeness, empty spans,
  cross-span pairs, invalid cursor and idempotent seed loading.
- Remaining Stage 3 tests: token expiry/tamper/password revocation/current-role,
  rate limits, missing records, refresh failure/checkpoint invariance, CORS,
  and full seeded end-to-end acceptance. Snapshot mutation/expiry tests already
  exist but remain blocked by stubs. Existing expected failures cannot waive
  passing validation of new Stage 3 behavior.
- Replace temporary `BackendSkeletonTest` 501 expectations as each endpoint
  is implemented in Stage 3; never weaken intended-behavior contract tests
  to expect unimplemented stubs.

## Carried-forward high-level work

**BE-SYNC-SKELETON — Completed (Stage 2 structural unit only):** BACKEND-6.
Add Books timestamps/index, task checkpoint monitoring table/model,
`book_events:sync` rake/service stub, and structural/intended-behavior tests.
No scheduling infrastructure or reconciliation logic is implemented.
Stage 3 BE-SYNC depends on the rank contract, bounded/inclusive watermark policy,
retry/failure handling and snapshot publication. Required cases include first
run, changed/unchanged books, finish correction/removal, inclusive time-boundary
replay, failed runs and hard deletion. Advanced concurrent writes/runs are
deferred; document the residual race risk.

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

This historical checkpoint preceded the approved concurrency deferral and
Stage 3 transition. Rank-dependent generation remains a cross-project dependency.

2026-10-24 interval decision: `BOOK_EVENTS_SYNC_INTERVAL_SECONDS=600` added to
`backend/.env.example`. Future scheduling must use a positive integer in seconds,
defaulting to 600 (10 minutes); reject invalid configuration explicitly.
No scheduler is running or consuming the setting yet. Scheduler wiring and
configuration validation tests belong to the authorized scheduling work.
Validation: `git diff --check` and exact environment-template value check passed.
Runtime tests skipped: environment-template and documentation changes only.

All selected Stage 3 implementation units and cross-adapter acceptance are
complete. Stage 4 was explicitly approved, reviewed and remediated; evidence
and the uncommitted handoff checkpoint are above.

| Task ID | Outcome | Requirements | Dependencies | Acceptance/checks to define or run |
| --- | --- | --- | --- | --- |
| BE-BOOK (Completed) | Books with opaque user_id, timestamps, nullable rating/review and model validations | BACKEND-1 | Structural schema | 10 new model tests pass; validation evidence and commit checkpoint above |
| BE-AUTH (Completed) | Admin-only account functionality on Users, one-time env provisioning, protected passwords, login and rate limit | BACKEND-2 | Existing User schema; approved auth/provisioning policy | Passing auth/provisioning integration tests and live HTTP smoke; evidence and commit checkpoint above |
| BE-CRUD (Completed; 35a15f5) | Admin-only book writes including rating/review; conditional review reads | BACKEND-1/2 | BE-BOOK, BE-AUTH | CRUD/auth/error/rollback tests and live HTTP CRUD pass; evidence above |
| BE-REVISION (Completed; ae169ef) | Immutable cached timeline revisions and force refresh from persisted events | BACKEND-3 | Existing BookEvents; approved snapshot and randomized rank contracts | Pinned payloads, 24-hour expiry, eviction/410 recovery and refresh failure tests pass; cross-process live refresh passes |
| BE-SYNC (Completed; publication committed as `69d7dfe`) | Incremental event reconciliation, atomic revision publication and durable checkpoint monitoring | BACKEND-3/6 | BE-BOOK; randomized rank contract; BE-REVISION | Projection/rank/checkpoint and real-cache atomic publication/rollback tests pass; advanced concurrency risk deferred |
| BE-EVENTS (Completed; ae169ef; review payload follow-up uncommitted) | Complete date-span API, bounds, next cursor and restart errors; joined Book fields/rating/review | BACKEND-4 | BE-REVISION; API contract | Timeline joined-field/review visibility tests and full 125-test SQLite/PostgreSQL suites pass |
| BE-SEEDS (Completed; ae58b2d) | Idempotent staging Books with embedded reviews; no events/users | BACKEND-5 | BE-BOOK; agreed fixtures | Seeds test plus `bin/rails db:seed` twice without duplicates |
| BE-CORS (Completed; aecc469) | Direct-browser frontend-origin integration | BACKEND-5 | Approved FRONTEND_ORIGIN allowlist; no proxy/cookie credentials | Authorization preflight, origin rejection, unchanged auth and full SQLite/PostgreSQL gates pass |
| BE-ACCEPTANCE (Completed; 30b11d7) | Disposable PostgreSQL acceptance | BACKEND-1/2/3/4/5/6 | Completed implementation units | Full suite, fresh production-configured migrations, Solid Cache and live cross-process HTTP walkthrough pass |
| BE-FINAL-REVIEW (Completed; remediation uncommitted) | Feature-wide review and provisioning race fix | BACKEND-1/2/3/4/5/6 | Stage 4 approval, complete Stage 3 acceptance | Base review, reproduced/fixed race and full 124-test SQLite/PostgreSQL gate; handoff evidence above |

Structural contracts, deterministic fixtures and executable intended-behavior
tests now exist; see Stage 2 baseline below. All implementation units and
PostgreSQL acceptance and approved Stage 4 review are complete; commit/handoff
remains separate from publication authorization.

BE-REVIEW is superseded by embedded Books fields, not completed. Separate Admin
model and date-only schema tasks are superseded too. Rank assignment is
now implemented by backend sync under the approved randomized policy; UTC day grouping, nullable fields,
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
Business feature completion is not claimed. The above historical run preceded
the policy approvals and expanded contracts recorded at the top of this file.
Stage 2 is now accepted and Stage 3 approved; task selection remains required.

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
