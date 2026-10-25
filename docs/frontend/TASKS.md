# Frontend tasks

## Current scope and session

- ID: **FRONTEND**; [SPEC](SPEC.md), [ROADMAP](ROADMAP.md).
- Lifecycle: Stage 1 requirements restart, **In progress**.
- Authorized session: document split and adoption of the shared timeline
  layout, plus the 2026-10-25 route and admin-management requirements update.
  Clarified BookEvent ID/public event details and admin access/fields on
  2026-10-25. The user-selected visual reference was recorded the same day.
  No frontend implementation tasks selected; Stage 2 not approved.
- Dependency: agreed [backend API](../backend/SPEC.md) for integration.

## High-level scope for refinement

These outcomes are **Not started**, awaiting Stage 1 decisions, approved
Stage 2 contracts/test baseline, Stage 3 approval, and user task selection.

| Task ID | Outcome | Requirements | Dependencies | Acceptance/checks to establish |
| --- | --- | --- | --- | --- |
| FE-HARNESS | Structural components, deterministic fixtures, executable tests | All frontend requirements | Stage 2 approval; tooling choice | Test discovery and intended end-to-end baseline; lint/build |
| FE-PAGES | Landing page and six-route application structure | FRONTEND-0 | FE-HARNESS; landing content decisions | All six routes; BookEvent ID details and Book ID admin navigation; literal add route; no public admin link |
| FE-GEOMETRY | Calendar rows and fixed column geometry | FRONTEND-2 | Agreed dimensions/narrow-screen behavior; FE-HARNESS | All thresholds, row types, gutters, text limits |
| FE-RANK | Consume backend-assigned stable 1..12 ranks and refine equal-rank tie order | FRONTEND-3 | Approved backend random daily/type occupancy contract; frontend stage approvals | More than 12 books, equal ranks, event-pair consistency, deterministic rendering |
| FE-RESOLVE | Rank-based base columns and spill/stack resolver | FRONTEND-3 | FE-GEOMETRY, FE-RANK | Pure deterministic results, no rectangle overlap/overflow, dense dates and resize |
| FE-LOAD | API client, bounds, date spans, revision restart | FRONTEND-4 | Backend contract; FE-HARNESS | Empty/dense spans, cross-page pairs, no mixed revisions, explicit errors/retry |
| FE-TIMELINE | Label rendering and continuous scroll integration | FRONTEND-1/2/3/4 | FE-RESOLVE, FE-LOAD | Text/in-progress cases; stable loaded heights; measured anchoring and real-browser seeded checks |
| FE-ACCESS | Public BookEvent detail, authentication and accessible UX | FRONTEND-1/5 | Direct event-ID lookup design; FE-LOAD | Public event fields without review or admin-only book calls; memory-only token lifecycle; keyboard/screen-reader/focus checks |
| FE-ADMIN | Authenticated book listing, add, edit and delete pages | FRONTEND-0/5/6 | FE-PAGES; FE-ACCESS; agreed management flows | Direct-URL admin entry; API-backed CRUD including rating/review; unauthorized access; validation/API errors; session expiry; confirmed delete behavior |
| FE-VISUAL | Adapt reference visual design across public and admin pages | FRONTEND-7 | Stage 2 approval; FE-PAGES | Palette, typography, panel treatment, responsive behavior, contrast, keyboard focus and reduced motion |

The former slider task and exact proportional-gap tests are superseded,
not unfinished tasks. No unsupported `npm test` command is an existing gate.

## Stage 2 integration baseline

None exists yet. Select the repository-compatible test runner during approved
Stage 2, then record exact commands and expected failures for unimplemented
behavior. Include each `N` in `{4, 6, 8, 12}`, empty spans, both event types,
edge spill, occupied neighbors, dense collisions, and revision changes.
Harness/discovery failures and unrelated regressions block Stage 2 exit.

## Validation and commit checkpoint

- Existing commands from `frontend/`: `npm run lint`, `npm run build`.
- Future unit/component and real-browser integration commands must be recorded
  once the harness exists. Browser validation must measure actual layout, not
  substitute static inspection or an HTTP 200 response.
- Run focused checks per selected unit, record exact results, preserve other
  subprojects' behavior, and inspect the diff before marking tasks Completed.
- After a validated unit, remind the user to commit and stop. Continue only
  after commit confirmation or explicit instruction to continue without
  committing. No implicit staging/committing; no new checkpoint passed here.

## Completed foundation: Next.js scaffold

Preserved from the original combined scaffold record, not rerun this session.
[Backend TASKS](../backend/TASKS.md) preserves the Rails portion.

- Acceptance: apps in separate directories, root README setup/validation,
  original SPEC recording stack and unresolved product decisions.
- `cd frontend && npm run lint && npm run build`: passed.
- `cd frontend && npm audit --omit=dev`: passed; 0 production advisories.
- Full `npm audit`: 5 high-severity development-only lint advisories;
  compatible remediation remained unresolved.
- Manual: Next.js dev server returned HTTP 200 for `/`; generated page title
  present. Project structure/setup reviewed against generated apps.
- Initial checks from the repository root failed due to working directory;
  rerunning from `frontend/` passed.
- Residual risk: full real-browser visual inspection was unavailable.
  Foundation HTTP success is not timeline acceptance or a current audit.

## Documentation session evidence

2026-10-24: separated frontend planning and preserved scaffold evidence.
The shared layout replaces the proportional-gap/slider design.
No application code or dependencies changed; application/browser suites
skipped for this documentation-only edit. Inspect documentation links,
requirement ownership, diff scope, and whitespace; no feature task or stage
is newly Completed.

2026-10-25: recorded the six user-selected routes, existing Next.js/React
scaffold reuse, and backend API consumption. Added admin CRUD requirements
and future route/admin acceptance coverage. The public timeline versus
admin-only book-detail API mismatch remains an explicit decision, not an
implicit backend change. No application code or dependencies changed;
application/browser suites are not applicable to this requirements update.
The detail-access mismatch noted at that checkpoint is superseded by the
clarification below. No implementation task or lifecycle stage is newly
Completed.

2026-10-25: clarified that `/timeline/<id>` uses a BookEvent ID and public
details come from the event payload; book/review endpoints remain private.
The admin area has no public navigation link and prompts for login on direct
`/admin` access. Rating and review are included in admin book forms. Direct
event-ID lookup through paginated timeline data remains to be designed.
No application code or dependencies changed; no implementation task or
lifecycle stage is newly Completed.

2026-10-25: documented `miss-micros-magick-wheel` as the selected visual
reference and added FE-VISUAL with design and accessibility acceptance checks.
Clarified that light and dark modes may extend the reference styling while
preserving its visual identity. No application code or dependencies changed;
no implementation task or lifecycle stage is newly Completed.
