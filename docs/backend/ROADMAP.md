# Backend roadmap

## BACKEND lifecycle

Outcome: tested Rails book management and a consistent, revision-pinned,
date-range timeline API. Requirements: [SPEC](SPEC.md).
Evidence and checkpoints: [TASKS](TASKS.md).

| ID | Lifecycle stage | Status | Dependencies | Next approval |
| --- | --- | --- | --- | --- |
| BACKEND | Stage 2: architecture and skeleton | In progress | Frontend-owned rank assignment deferred | Stage 3 after design review and baseline acceptance |

Frontend integration depends on this API. Deployment depends on both completed
subprojects. Neither dependency grants permission to advance another lifecycle.

### Stage 1: Understanding the problem

- Outputs: BACKEND-1 through BACKEND-5, observed environment, accepted shared
  layout, testable acceptance, and explicit unresolved decisions in SPEC.
- Exit: public/detail access, validation bounds, calendar/revision constraints,
  integration approach, and material security/performance decisions agreed.
- Schema refinement: Books now embeds rating/review and uses timestamps;
  BookEvents is persisted; Users replaces Admin. Ownership via `Books.user_id`,
  nullable completion/reviews, rank 1..12 inclusive, UTC storage and admin-only
  writes/account scope are confirmed. Calendar-day grouping is UTC. Rank
  assignment is deferred to frontend implementation, not a Stage 1 blocker.
- Evidence: document split and new timeline direction approved 2026-10-24;
  remaining questions are recorded, not silently defaulted.
- Approval: user authorized Stage 2 on 2026-10-24. Ownership is now explicitly
  a nullable string placeholder with no user association. Existing API access
  restrictions remain unchanged; new operational policies are Stage 2 proposals.

### Stage 2: High-level design and implementation

- Define models/schema, auth boundaries, snapshot publication/storage,
  pagination/error schemas, and the frontend-facing API contract.
- Refine high-level tasks; add skeletons, deterministic seeds/fixtures, and
  executable end-to-end API tests before business logic.
- Exit: structural checks pass and exact expected-red integration baseline is
  recorded. Broken harness/discovery or unrelated regressions block exit.
- Evidence: structural models/schema, explicit failing endpoints, deterministic
  seed fixtures and executable integration tests exist. See TASKS for commands,
  passing structural gates, and the expected-red baseline.
- Approval: Stage 3 not granted. Review span/retention/rate-limit proposals
  and frontend-dependent rank contract before implementing affected behavior.

### Stage 3: Detailed design and implementation

- Implement only user-selected units with model/unit and integration tests:
  domain, auth, CRUD, ranks/revisions, pagination, seed data, and CORS.
- Reuse completed database configuration rather than reimplementing it.
- Exit: BACKEND acceptance passes on SQLite and disposable Postgres, manual
  API evidence recorded, no unimplemented integration cases hidden.
- Stop after each validated unit for the TASKS commit checkpoint; then request
  Stage 4 approval.

### Stage 4: Review and pull-request preparation

- Review the entire subproject against its verified base, including committed
  tasks and worktree changes; run the complete relevant local/integration gate.
- Exit: acceptance, auth/security, pagination consistency, and compatibility
  checks pass; findings resolved and PR evidence prepared.
- Stop for handoff. Commit/push/publication need explicit authorization.

## Risks and history

- Snapshot retention/storage, event-dense spans, and cross-app contract drift
  require design and tests; exact response schemas are not yet agreed.
- Rails scaffold and local production Postgres/cache configuration were
  completed previously; evidence remains in TASKS, not rerun here.
- 2026-10-24: Restart requirements in a separate BACKEND lifecycle. Replace
  event-count pagination with shared revision-pinned date spans.
- 2026-10-24: Record user-selected Books/BookEvents/Users schema. Separate
  Review/Admin models are superseded. Shared rank and reader-label impacts
  remain blockers; frontend/deployment stages and approvals do not advance.
- 2026-10-24: Confirm user ownership, nullable completion/rating/review, rank
  bounds inclusive, admin-only writes including reviews, no non-admin account
  implementation, and UTC storage. Rank assignment and club timezone stay open.
- 2026-10-24: Confirm UTC day grouping and defer rank assignment to frontend
  implementation. Preserve the backend 1..12 contract; do not invent an
  allocator/default. Remaining access, provisioning, and API policies stay open.
- 2026-10-24: Stage 2 authorized; `user_id` confirmed as a nullable string
  placeholder, superseding foreign-key ownership. Added structural skeleton
  and expected-red contract coverage without Stage 3 business logic.
- 2026-10-24: Add BACKEND-6: externally scheduled incremental event sync,
  Books timestamps, task checkpoint/monitoring table, rake/service skeleton,
  and executable expected-red contracts. Concurrent-write safety requires
  design; no Stage 3 or deployment authorization implied.
- 2026-10-24: Configure future scheduling through
  `BOOK_EVENTS_SYNC_INTERVAL_SECONDS`, default 600 seconds (10 minutes).
  Environment template added; runtime scheduling remains deferred.
- 2026-10-24: Accept before/after timestamp navigation anchors and cursor-only
  continuation for the timeline, retaining complete UTC-day spans and pinned
  revisions. API contract refinement only; Stage 3 remains unapproved.
- 2026-10-24: Approve 30-day pages, one-time environment-driven admin rake
  initialization, and 10 login attempts/IP/3 minutes with Retry-After.
  Expand executable timeline/sync contracts; revision storage, concurrent-sync
  strategy and browser/API access remain under explanation, not approved.
- 2026-10-24: Accept cache revisions with 24-hour maximum retention and early
  eviction/410 recovery, plus forced cache-refresh rake task. Accept direct
  browser-to-Rails access. Edit/delete associated events by book_id; advanced
  concurrency design deferred as low priority, not silently treated as solved.
