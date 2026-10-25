# Frontend specification

## Scope and ownership

Subproject ID: **FRONTEND**. Give bookclub members one shared timeline of
every reading record, conveying reading duration visually.
[Roadmap](ROADMAP.md) and [tasks](TASKS.md) track its independent Stage 1
restart. [Deployment](../SPEC.md) follows completion of both apps.

The accepted [shared timeline layout](../BOOKEVENT_TIMELINE_LAYOUT_PLAN.md)
is the canonical layout reference. It replaces the proportional bottom-to-top
gap formula, pixels-per-day slider, and event-count pagination; no slider is
planned. [Backend SPEC](../backend/SPEC.md) owns the shared API contract.

## Requirements

### FRONTEND-1: Timeline content

- Render all club book records, with START and FINISHED labels paired by
  book identity. In-progress books render START only.
- Preserve the prior label content: `Reader - start_date` or
  `Reader - end_date`, followed by `Title by Author`. Dates inside labels
  versus the layout plan's "dates are not rendered" wording need explicit
  clarification; do not invent a date axis or day lines.
- A detail view fetches a book and, if completed, its review. The current
  planned detail endpoint is admin-only; settle the intended viewer before
  designing navigation or adding admin-facing pages.

### FRONTEND-2: Calendar-row geometry

- Every calendar day occupies a row, including empty days. The base row is
  one label height for empty or single-type dates, two for both event types.
  FINISHED occupies the region above START; stacking grows the affected
  region by one label height per extra stacked label.
- Empty days have uniform height. This is not an exact proportional gap
  between label edges: event density and collisions can increase row height.
- Use fixed-size labels and column counts `{4, 6, 8, 12}`. Select the largest
  `N` satisfying `N * column_width + label_width <= viewport_width`.
  Half-label gutters permit edge spill; center remaining width in margins.
- Resolve label dimensions, gaps, padding, long-text handling, supported
  minimum viewport, and behavior when four columns do not fit before Stage 2.
  No horizontal overflow is an acceptance requirement, not a reason to
  silently add an unapproved column count.

### FRONTEND-3: Deterministic collision resolution

- Rank assignment/reuse for values 1..12 is owned by backend sync under the
  approved randomized UTC day/type occupancy policy in [Backend SPEC](../backend/SPEC.md).
  Both events retain their shared rank, including date edits and completion
  added later. Frontend handles overflow/collisions; refine equal-rank tie order
  during frontend design. This supersedes the earlier assignment deferral.
- Both events inherit `start_rank`; their base column is `start_rank % N`,
  even across date spans. Reserve label rectangles, not full reading spans.
- Resolve each date/type region as a pure function of its events and `N`,
  ordered by ascending `start_rank`. Resolve collisions for either type.
- A colliding pair may spill half a label width outward from its base column
  only if the overlapped neighbor halves are free; otherwise stack vertically
  without a fixed stack limit. Check padding and edge gutters too.
- Different types can share a column on one day. Different dates occupy
  different rows and cannot collide. Pair alignment refers to base columns;
  collision offsets may differ per event.
- Resizing recalculates placement deterministically for the same revision.
  Require nonintersecting rectangles and all label edges within the viewport.

### FRONTEND-4: Continuous loading and revision recovery

- Fetch contiguous date spans from `GET /book-events`, append near the loaded
  end, and continue through empty spans until terminal pagination.
- Use backend bounds to represent the timeline's date extent, including
  empty spans. Exact scroll sizing for not-yet-loaded dates must account
  for unknown collision-expanded heights; resolve estimation/anchoring design
  before implementing, rather than claiming bounds alone give exact height.
- A complete loaded date never receives later events within the same revision.
  Its height is independent of neighboring spans. If prepending spans is
  supported, compensate by their measured total height to preserve position.
- Never combine revisions. On expiry, perform an explicit, coherent restart;
  loading, errors, retry, empty timeline, and restart UX must be agreed.

### FRONTEND-5: Authentication and accessibility

- If consuming protected endpoints, send the backend bearer token, hold it
  only in memory, and discard it on logout; no localStorage/cookie storage.
- Keep API configuration environment-specific. Jointly decide direct-browser
  requests versus a Next.js proxy and consequent CORS behavior.
- Define keyboard/screen-reader access, reading order, focus preservation,
  responsive support, and measurable performance targets during Stage 1.
- Additional accounts/roles and production review entry are not planned.
  Admin login/CRUD UI scope is not established by the existence of API routes.

## Environment baseline

Observed [package manifest](../../frontend/package.json): Next.js 16.4.2,
React/React DOM 19.3.0, TypeScript 5, Tailwind 4, ESLint 9. Node.js 20.9+
is the documented runtime requirement. Local frontend port is 3000.
The current page is a generated placeholder; no product/API integration exists.

Available validation: `npm run lint`, `npm run build` from `frontend/`.
There is no test script or frontend test harness yet; choose/setup one in
approved Stage 2, not a fictitious existing `npm test` gate.
Follow [frontend agent instructions](../../frontend/AGENTS.md) and relevant
installed Next.js guides before future application-code work.

Historical foundation audit: zero production advisories; five high-severity
development lint dependency advisories. These are old results, not current
audit evidence; review compatible remediation before expanding dependencies.

## Acceptance coverage

- FRONTEND-1: component/browser checks verify content, in-progress books,
  cross-span pairs, and agreed detail/access behavior.
- FRONTEND-2/3: geometry tests at all four column counts and immediately
  below thresholds; empty/single/both-type days; dense same-type collisions,
  occupied neighbors, edge spill, long labels, narrow screens, and resize.
  Measure rectangles for no overlap and no horizontal overflow.
- FRONTEND-4: executable integration tests prove complete date loading,
  empty-span advancement, terminal behavior, stable loaded-span heights,
  coherent revision switches, visible recovery errors, and scroll anchoring.
- FRONTEND-5: test agreed auth lifecycle, accessibility, and environment access.
- Lint/build and the future unit/integration gate pass. Verify seeded
  end-to-end behavior in a real browser, not HTTP response alone.

## Open Stage 1 decisions

- Concrete geometry, text overflow and minimum-viewport behavior.
- Date label wording, date formatting/calendar conventions and initial scroll
  direction/position; exact UX for empty/loading/error/restart states.
- UTC storage and UTC calendar-day grouping are confirmed backend constraints;
  display formatting must not silently move events to browser-local days.
- Public timeline versus restricted viewing and detail access; admin UI scope.
- Accessibility/browser support, performance budgets, unloaded-range sizing,
  and API access approach shared with BACKEND.

## Approved changes and resources

- 2026-10-24: Separate FRONTEND lifecycle; adopt shared calendar-row layout,
  base rank columns, spill/stack resolution, revision-pinned date ranges.
  No Stage 2 or implementation approval implied.
- 2026-10-24: Own the deferred 1..12 rank assignment/reuse decision during
  frontend implementation. UTC defines timeline days. No stage advance implied.
- [Next.js docs](https://nextjs.org/docs), [Next.js Learn](https://nextjs.org/learn),
  [React Learn](https://react.dev/learn).
