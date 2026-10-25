# Backend roadmap

## BACKEND lifecycle

Outcome: tested Rails book management and a consistent, revision-pinned,
date-range timeline API. Requirements: [SPEC](SPEC.md).
Evidence and checkpoints: [TASKS](TASKS.md).

| ID | Lifecycle stage | Status | Dependencies | Next approval |
| --- | --- | --- | --- | --- |
| BACKEND | Stage 1: requirements restart | In progress | Shared layout; cross-app API decisions | Stage 2 after open requirements are resolved |

Frontend integration depends on this API. Deployment depends on both completed
subprojects. Neither dependency grants permission to advance another lifecycle.

### Stage 1: Understanding the problem

- Outputs: BACKEND-1 through BACKEND-5, observed environment, accepted shared
  layout, testable acceptance, and explicit unresolved decisions in SPEC.
- Exit: public/detail access, validation bounds, calendar/revision constraints,
  integration approach, and material security/performance decisions agreed.
- Evidence: document split and new timeline direction approved 2026-10-24;
  remaining questions are recorded, not silently defaulted.
- Approval: Stage 2 not granted. Stop for approval after requirements settle.

### Stage 2: High-level design and implementation

- Define models/schema, auth boundaries, snapshot publication/storage,
  pagination/error schemas, and the frontend-facing API contract.
- Refine high-level tasks; add skeletons, deterministic seeds/fixtures, and
  executable end-to-end API tests before business logic.
- Exit: structural checks pass and exact expected-red integration baseline is
  recorded. Broken harness/discovery or unrelated regressions block exit.
- Approval: not granted. Stop for Stage 3 approval.

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
