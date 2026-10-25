# Deployment roadmap

## Delivery order and independent lifecycles

Delivery order is BACKEND, FRONTEND, then DEPLOY. Each subproject has its own
four-stage lifecycle and approvals; a delivery position is not a lifecycle
stage. Frontend planning may use the backend contract before backend completion,
but this document authorizes no parallel implementation or stage transitions.

| ID | Outcome and owning roadmap | Current lifecycle stage | Status | Dependencies | Next approval |
| --- | --- | --- | --- | --- | --- |
| BACKEND | [Rails data and revision-pinned timeline API](backend/ROADMAP.md) | Stage 3: detailed design and implementation | In progress; sync publication and CORS implemented | PostgreSQL acceptance pending | Backend Stage 4 after implementation and acceptance |
| FRONTEND | [Calendar-row timeline and collision-safe rendering](frontend/ROADMAP.md) | Stage 1: requirements restart | In progress | Shared layout; backend API contract and implementation | Frontend Stage 2, after open decisions |
| DEPLOY | Staging and production deployment | Stage 1: deferred | Blocked | BACKEND and FRONTEND completed, including Stage 4 | Begin deployment planning after both complete |

Child roadmaps own their detailed scope, evidence, and approvals. The table is
an index, not an independent source of approval.

## DEPLOY lifecycle

Requirements and acceptance: [Deployment SPEC](SPEC.md).
Evidence and checkpoints: [Deployment TASKS](TASKS.md).

### Stage 1: Understanding the problem

- Begin only after BACKEND and FRONTEND complete.
- Confirm Vercel/Neon feasibility, environment isolation, staging branch and
  aliases, migration permissions, update and rollback requirements.
- Exit: deployment constraints, measurable acceptance, and platform decisions
  are explicit; blockers are resolved.
- Approval: not granted. Stop for DEPLOY Stage 2 approval.

### Stage 2: High-level design and implementation

- Design container/runtime configuration, environment mapping, migration
  workflow, and rollback; create structural files and disposable smoke tests.
- Exit: architecture, skeletons, deterministic test data, and executable
  deployment integration baseline exist. Record exact expected-red cases;
  harness failures and unrelated regressions block exit.
- Approval: not granted. Stop for DEPLOY Stage 3 approval.

### Stage 3: Detailed design and implementation

- Implement user-selected deployment configuration units and validate each.
- Provisioning and actual deployment require separate explicit authorization,
  even when configuration implementation is approved.
- Exit: selected scope passes image, migration, environment-isolation, and
  application smoke checks; update and rollback instructions are recorded.
- Stop at each commit checkpoint and then for DEPLOY Stage 4 approval.

### Stage 4: Review and pull-request preparation

- Review the entire deployment change against its verified base; run required
  backend, frontend, image, migration, and end-to-end gates.
- Exit: findings resolved; exact checks, manual environment evidence, skipped
  checks, residual risks, and PR summary recorded. No expected-red exception.
- Stop for handoff; publication and deployment need explicit authorization.

## Historical foundation

Rails and Next.js scaffolding and local production Postgres configuration
were completed before the planning restart. Preserve their existing evidence
in [Backend TASKS](backend/TASKS.md) and
[Frontend TASKS](frontend/TASKS.md); do not repeat scaffolding or infer
completed feature lifecycles from that foundation.

## Change record

- 2026-10-24: Restart requirements planning with separate BACKEND and FRONTEND
  lifecycles; defer DEPLOY until both are complete. Preserve foundation history.
- 2026-10-24: Replace the event-count/proportional-gap/slider plan with the
  accepted calendar-row, rank/revision, and date-range layout design.
- 2026-10-24: User authorized BACKEND Stage 2. FRONTEND remains Stage 1 and
  DEPLOY remains blocked. Backend skeleton evidence is in its own TASKS.
- 2026-10-24: User accepted BACKEND Stage 2 and authorized Stage 3; awaiting
  implementation task selection. FRONTEND and DEPLOY stages remain unchanged.
