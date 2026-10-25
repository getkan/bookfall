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

### FRONTEND-0: Application routes and API integration

- Use the existing Next.js/React application in `frontend/`, consuming the
  Rails API in `backend/`; do not create a second frontend project.
- Provide the following routes. Next.js dynamic route segments use `[id]`.
  In `/timeline/<id>`, `<id>` is a BookEvent ID. In admin book routes it is
  a Book ID.

| Route | Purpose |
| --- | --- |
| `/` | Landing page |
| `/timeline` | Book timeline displaying BookEvents |
| `/timeline/<id>` | Public details from a specific BookEvent |
| `/admin` | Select books to edit or delete, or navigate to add a book |
| `/admin/book/<id>` | Edit a book |
| `/admin/book/add` | Add a book |

- Keep the literal `add` route distinct from the dynamic book-ID route.
- The admin area is intentionally unlinked from public-page navigation and
  reached by direct URL. An unauthenticated admin visitor is prompted to log
  in at `/admin`; no additional login route is required.
- Landing-page content remains to be agreed. The route list does not authorize
  changing backend access policy.

### FRONTEND-1: Timeline content

- Render all club book records, with START and FINISHED labels paired by
  book identity. In-progress books render START only.
- Preserve the prior label content: `Reader - start_date` or
  `Reader - end_date`, followed by `Title by Author`. Dates inside labels
  versus the layout plan's "dates are not rendered" wording need explicit
  clarification; do not invent a date axis or day lines.
- `/timeline/<id>` identifies a BookEvent by its event ID and displays only
  information available from the public `GET /book-events` event payload.
  It must not use the event ID as a Book ID.
- The public event payload includes event identity, book identity, type, date,
  rank, reader placeholder, title, author and optional rating. Reviews are
  explicitly excluded from the public payload. Do not expose reviews or make
  `GET /books/:id` public; that endpoint remains admin-only.
- The current backend API only retrieves events through paginated date spans,
  not directly by event ID. Define a reliable direct-navigation lookup for
  `/timeline/<id>` during Stage 2 without changing public book access policy.

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
- Additional accounts/roles are not planned. Admin book management is now
  explicitly in scope under FRONTEND-6, including rating and review fields.
  The backend permits admin writes to both fields.

### FRONTEND-6: Admin book management

- Require admin authentication for book listing, creation, editing, and
  deletion. The backend remains the authorization authority; hiding controls
  alone is insufficient.
- `/admin` consumes `GET /books`, provides navigation to the add/edit routes,
  and allows deletion through `DELETE /books/:id`.
- `/admin/book/<id>` loads `GET /books/:id` and saves changes through
  `PATCH /books/:id`.
- `/admin/book/add` creates a book through `POST /books`.
- Authenticate through `POST /login` using the memory-only bearer-token
  lifecycle in FRONTEND-5. Keep admin entry unlinked from public navigation;
  offer login at `/admin` for unauthenticated direct visits.
- Edit title, author, reader placeholder (`user_id`), start and finish dates,
  rating and review. Rating and review are admin-only.
- Define delete confirmation, post-save navigation,
  validation feedback, and expired-session behavior before implementation.

### FRONTEND-7: Visual design direction

- Base the frontend's visual design on the user's reference project,
  `miss-micros-magick-wheel`, especially its `app/globals.css`,
  `app/layout.tsx`, and `app/page.tsx`. Adapt the design to Bookfall's
  reading timeline and admin tasks; do not reproduce wheel-specific branding
  or let decorative effects interfere with timeline readability.
- Use the reference's dark, near-black background (`#0b0e14`), darker panel
  surface (`#050a0f`), off-white primary text and borders (`#f5f5f5`), and
  muted slate accents (`#1f2937`, `#9ca3af`) as the design basis. The visual
  system may expand to include light and dark modes; alternate themes should
  retain the same recognizable palette relationships and panel treatment.
- Use a clean monospace-led typographic style with practical system fallbacks;
  do not assume the reference machine's `"SF Mono Regular"` font is installed.
- Favor clear, rounded, outlined panels and restrained book-themed imagery.
  Keep timeline labels and reading information visually dominant, with
  decoration secondary.
- Honor `prefers-reduced-motion`; decorative motion must not be required to
  understand or use any page. Maintain readable contrast, responsive layout,
  and visible keyboard focus across the public and admin routes.

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

- FRONTEND-0: route checks verify all six pages, BookEvent-ID detail lookup,
  Book-ID admin navigation, unlinked admin entry, and literal `add` routing.
- FRONTEND-1: component/browser checks verify content, in-progress books,
  cross-span pairs, event-ID direct navigation, and that public views never
  expose reviews or call admin-only book routes.
- FRONTEND-2/3: geometry tests at all four column counts and immediately
  below thresholds; empty/single/both-type days; dense same-type collisions,
  occupied neighbors, edge spill, long labels, narrow screens, and resize.
  Measure rectangles for no overlap and no horizontal overflow.
- FRONTEND-4: executable integration tests prove complete date loading,
  empty-span advancement, terminal behavior, stable loaded-span heights,
  coherent revision switches, visible recovery errors, and scroll anchoring.
- FRONTEND-5: test agreed auth lifecycle, accessibility, and environment access.
- FRONTEND-6: integration/browser checks verify authorized listing, add,
  edit and delete, rejected unauthorized operations, visible API failures,
  all agreed editable fields including rating/review, and the agreed form and
  session behavior.
- FRONTEND-7: browser review checks the reference-based visual identity in
  supported light/dark modes, monospace-led type, panel treatment, book-themed
  restraint, responsive layouts, focus visibility, contrast, and reduced-motion
  behavior across representative public and admin pages.
- Lint/build and the future unit/integration gate pass. Verify seeded
  end-to-end behavior in a real browser, not HTTP response alone.

## Open Stage 1 decisions

- Concrete geometry, text overflow and minimum-viewport behavior.
- Date label wording, date formatting/calendar conventions and initial scroll
  direction/position; exact UX for empty/loading/error/restart states.
- UTC storage and UTC calendar-day grouping are confirmed backend constraints;
  display formatting must not silently move events to browser-local days.
- Direct lookup of a BookEvent ID through date-paginated timeline data.
- Landing-page content and navigation; admin delete confirmation,
  post-save navigation, validation feedback and expired-session behavior.
- Accessibility/browser support, performance budgets, unloaded-range sizing,
  and API access approach shared with BACKEND.

## Approved changes and resources

- 2026-10-24: Separate FRONTEND lifecycle; adopt shared calendar-row layout,
  base rank columns, spill/stack resolution, revision-pinned date ranges.
  No Stage 2 or implementation approval implied.
- 2026-10-24: Own the deferred 1..12 rank assignment/reuse decision during
  frontend implementation. UTC defines timeline days. No stage advance implied.
- 2026-10-25: User specified Next.js/React consuming the backend API and the
  six landing, timeline, book-detail, and admin routes above. Admin book CRUD
  UI is in scope. Detail access and remaining Stage 1 decisions are unresolved;
  no Stage 2 or implementation approval implied.
- 2026-10-25: User clarified that `/timeline/<id>` uses a BookEvent ID and
  public details come from the event payload; book/review endpoints remain
  private and review is not public. Admin entry is unlinked and reached by
  direct URL; rating/review are editable in admin forms. Direct event-ID
  lookup through paginated timeline data remains a Stage 2 design item.
- 2026-10-25: User selected `miss-micros-magick-wheel` as the frontend visual
  design reference. FRONTEND-7 records its dark palette, monospace-led type,
  rounded outlined panels, restrained book imagery, responsive/accessibility
  requirements, and adaptation rather than wheel-specific copying.
- 2026-10-25: User clarified that light and dark modes may be supported; the
  reference styling remains the visual basis rather than a dark-only mandate.
- [Next.js docs](https://nextjs.org/docs), [Next.js Learn](https://nextjs.org/learn),
  [React Learn](https://react.dev/learn).
