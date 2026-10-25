# Frontend roadmap

## FRONTEND lifecycle

Outcome: Next.js/React landing page, shared calendar-row timeline with
deterministic, collision-safe labels and continuous revision-consistent
loading, public BookEvent details, authenticated admin book management, and a
visual design adapted from the selected reference project.
[SPEC](SPEC.md) owns requirements; [TASKS](TASKS.md) owns evidence/checkpoints.

| ID | Lifecycle stage | Status | Dependencies | Next approval |
| --- | --- | --- | --- | --- |
| FRONTEND | Stage 1: requirements restart | In progress | Shared layout; backend contract and implementation | Stage 2 after open requirements are resolved |

BACKEND must provide the agreed API for final integrated acceptance.
Deployment cannot begin until both subprojects complete. Frontend planning
does not authorize backend work or parallel implementation.

### Stage 1: Understanding the problem

- Outputs: FRONTEND-0 through FRONTEND-7, six application routes, environment
  baseline, accepted layout and visual design directions, and explicit open
  decisions in SPEC.
- Exit: geometry/minimum viewport, date wording, user access, recovery UX,
  accessibility, and material performance/integration constraints agreed.
- Evidence: document split and replacement layout approved 2026-10-24.
- Approval: Stage 2 not granted. Stop for approval after requirements settle.

### Stage 2: High-level design and implementation

- Define API client, rank-based geometry/resolver, date-span state, revision
  recovery, scroll sizing/anchoring, component contracts, and auth boundaries.
- Select and establish executable unit/component/browser integration tooling;
  create skeletons and deterministic fixtures shared with backend scenarios.
- Exit: structural checks and discovery pass, intended end-to-end tests run,
  and exact expected-red baseline is recorded. Do not mask harness failures.
- Approval: not granted. Stop for Stage 3 approval.

### Stage 3: Detailed design and implementation

- Implement user-selected units with unit and integration tests; validate
  exact row heights, rectangle intersections, viewport bounds, pagination,
  revision recovery, and agreed UX in a real browser.
- Exit: SPEC acceptance passes against seeded backend data, including all
  four column counts, empty spans, dense dates, resizing, and supported
  narrow viewports. Lint/build and the future test gate pass.
- Stop after each unit for the commit checkpoint; request Stage 4 approval.

### Stage 4: Review and pull-request preparation

- Review the complete subproject/base including committed work and worktree
  changes; run the full relevant gate and real-browser end-to-end coverage.
- Exit: findings addressed, requirement coverage and manual measurements
  recorded, accessibility/compatibility/performance risks reviewed, PR evidence
  prepared. No expected-red final-readiness exception.
- Stop for handoff; publication and deployment need explicit authorization.

## Risks and history

- Four fixed column choices do not define below-minimum viewport behavior.
  Unknown geometry, text wrapping, collision-expanded unloaded heights, and
  revision expiry must be resolved rather than hidden behind defaults.
- Generated Next.js scaffold passed historical lint/build and HTTP smoke
  checks, not full browser acceptance; see TASKS.
- 2026-10-24: Restart requirements in a separate FRONTEND lifecycle; replace
  slider/gap and unresolved overlap planning with the accepted row model.
- 2026-10-25: Record the user-selected landing, timeline, book-detail and admin
  routes. Admin book CRUD, hidden direct-URL admin entry, BookEvent-ID public
  details, and admin-only rating/review editing are in scope. Direct lookup
  design and other Stage 1 decisions remain open. Stage 2 is not approved.
- 2026-10-25: User selected `miss-micros-magick-wheel` as the visual design
  reference. FRONTEND-7 records its adaptable dark palette, monospace-led type,
  outlined panels and restrained book imagery; no stage advance implied.
- 2026-10-25: User clarified that light and dark modes may extend the reference
  styling; its visual identity remains the basis, not a dark-only constraint.
