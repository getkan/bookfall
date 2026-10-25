# Book event timeline layout plan

## Authority and ownership

Accepted 2026-10-24 as the replacement for the proportional-gap/slider design.
This is the shared layout reference, not a competing project specification.
[Backend SPEC](backend/SPEC.md) owns data/API requirements;
[Frontend SPEC](frontend/SPEC.md) owns rendering requirements. Their ROADMAP
and TASKS documents track separate lifecycles. [Deployment](SPEC.md) follows
completion of both subprojects.

Schema refinement, 2026-10-24: the user selected persisted BookEvents with
timestamp `date`, stored type `FINISH`, and `start_rank` 1 through 12 inclusive,
plus Books timestamps and Users. The later Stage 2 clarification makes
`user_id` a nullable string placeholder without a user association or ownership
behavior. Non-admin account functionality is out of scope; the reader-label
source remains deferred. See [Backend SPEC](backend/SPEC.md).
The bounded rank supersedes the earlier unbounded dense rank.
Approved 2026-10-24: backend sync randomly selects an unused rank in 1..12
across STARTs on the UTC start day and FINISHes on the UTC finish day.
If none is unused across both groups, randomly choose among ranks with the
lowest combined event count. For unfinished books, consider only STARTs.
Reuse the existing START rank (otherwise FINISH rank) for both events, even
after date edits or adding completion. No cycling or automatic reshuffle.
Frontend spill/stack handles overflow; equal-rank tie order remains to refine.
Timestamps are stored in UTC and calendar-day grouping also uses UTC.
Earlier rank assumptions do not override this approved allocation policy.

## Problem and approach

Design a technology-independent, paginated timeline with fixed-size labels,
proportional date spacing, and no horizontal overflow. Each book's START and
FINISHED events must share a column, even across page boundaries. Other books
may reuse that column wherever their labels do not overlap; the intervening
reading span is not reserved. A book without an end date has only a START
event. Layout revisions may move books, but must move both events together.

Publish shared, versioned event data and book ranks before pagination.
The frontend computes base columns and resolves actual event-label rectangles,
not the full reading span. Return the book's rank and revision with each event.
Pagination must refer to one consistent data and rank version; there is no
server-side column allocator.

## Evaluated alternatives

### Modulo-based frontend column assignment (evaluated)

Proposal: server stores a dense `start_rank` per book (ordered by
`start_date`); frontend computes `column = start_rank % N` for its current
column count `N`.

Holds: alignment is automatic because both events use the same book rank.
START labels are collision-free up to capacity, since ranks `i` and `i+N`
have `N-1` starts between them. Rank is independent of `N`, so resizing needs
no server call.

Fails: FINISHED labels. Finish order is independent of start order, so two
books with ranks congruent mod `N` can finish on the same or adjacent dates and
overlap. A FINISHED label can also overlap a START label in the same column.
No single per-book key can satisfy two independent label intervals for every
`N`. Backdated inserts shift all ranks, so revision pinning is still required.

Selected direction (user decision): hybrid. Server assigns `start_rank` and
a revision; frontend computes `start_rank % N` and resolves same-date/type
collisions locally. Rejected alternative: server-side allocation for a
fixed breakpoint set of column counts, which guarantees non-overlap but
requires an allocator over both label intervals.

## Decisions made

- Vertical scale is a per-date row model, not a fixed pixels-per-day.
  Each calendar day is one row. Row height: one label height if the date
  has no events or only events of one type; two label heights if it has
  both FINISHED and START events (one region above the line, one below).
  Stacking adds one label height per extra stacked label to the affected
  region. Spacing between dates stays proportional to elapsed days because
  empty days are uniform; a date with both types adds one extra unit.
- Consequence: labels on different dates occupy different rows and cannot
  overlap. The only collision is same date, same type, same
  `start_rank % N`. The cross-date FINISHED-on-START case does not exist.
- Horizontal resolution spills into the neighbor column. Interpretation:
  a colliding pair is centered on its column, each label offset half a
  label width outward, so each overlaps half of one neighbor. Display
  gutters are half a label width on each side so edge columns can spill.
  Horizontal spill is used only when the overlapped neighbor halves are
  free in that row region; otherwise stack vertically.
- Vertical stacking is unbounded; the row region grows to hold the stack.
  Collisions are expected to be rare.
- A FINISHED label (above the line) and a START label (below) from
  different books may share a column on the same date.
- Resolution is a pure function of (events on the date, N) with tie order
  `start_rank` ascending, so identical input renders identically.
- Fetch margin: pagination is by date range, not by event count. A page
  covers a contiguous span of days and returns every event in that span,
  so a date is never split and events do not appear later inside an
  already loaded date. A page may hold zero events; it still occupies one
  label height per day.
- Dates and day lines are not rendered. Dates are used only to compute
  row heights and ordering. Within a row, the FINISHED region sits above
  the START region; no visible line placement convention is needed.
- Column count is restricted to the fixed set {4, 6, 8, 12}. The frontend
  selects the largest `N` in the set such that
  `N * column_width + label_width <= viewport_width`, and centers the grid
  so leftover width goes to the outer margins. Resolver behavior is then
  testable at exactly four values of `N`. Since 4 and 6 divide 12 and 4
  divides 8, books sharing a column at a larger `N` also share it at the
  smaller `N` that divides it, so resizing merges columns predictably.

## Phases and todos

1. Define geometry.
   - Goal: establish the visual contract.
   - Ownership: [Frontend SPEC](frontend/SPEC.md), FRONTEND-2.
   - Approach: define label width/height, horizontal gap, and usable
     viewport width. Column count `N` is the largest of
     {4, 6, 8, 12} with `N * column_width + label_width <= viewport_width`;
     half-label gutters on each side, remaining width split into outer
     margins. Define the row model: height per date as a function of its
     event types and stack depth, with the FINISHED region above the
     START region. Include padding in collision checks.
   - Validation: arithmetic examples at each of the four column counts,
     including the viewport width just below each threshold; row heights
     for empty, FINISHED-only, START-only, both-type, and stacked dates;
     edge-column spill into a gutter.

2. Specify book-level rank assignment.
   - Goal: give every book one stable key that both events inherit.
   - Ownership: [Backend SPEC](backend/SPEC.md), BACKEND-3.
   - Approach: randomly choose a rank using the daily/type occupancy policy
     above. Both events carry the same stable rank. Existing assignments
     survive reruns, backdated inserts, date edits and added completion.
     No server-side column allocation; persisted revisions pin assignments.
   - Validation: pairs share a rank, twelve available ranks fill randomly
     without reuse, overflow minimizes combined usage, relevant UTC day/type
     groups alone affect selection, and reruns preserve existing ranks.

3. Specify synchronization and paginated API semantics.
   - Goal: keep events and assignments consistent across requests and updates.
   - Ownership: [Backend SPEC](backend/SPEC.md), BACKEND-3/4.
   - Approach: enforce uniqueness of (book_id, type); reconcile current book
     dates idempotently, including removed dates. Build and publish event data
     and `start_rank` assignments as a consistent revision. Paginate by
     date range: the request names a revision and a span of days; the
     response returns every event in that span ordered by
     (date, type, start_rank), plus the next span cursor. Expose the
     timeline bounds (earliest and latest event dates) so the frontend can
     size the full scroll range and render empty spans without events.
     Return event identity, book identity, event type/date, `start_rank`,
     and revision. Define explicit restart behavior if a revision expires;
     never mix revisions silently.
   - Validation: a span with zero events, a span with a date holding more
     events than a typical page, a book whose two events fall in different
     spans, date corrections between requests, removed end dates, and a
     rank shift forcing a revision change.

4. Specify rendering and acceptance tests.
   - Goal: demonstrate the exact guarantees, not just plausible placement.
   - Ownership: [Frontend SPEC](frontend/SPEC.md), FRONTEND-1 through FRONTEND-5.
   - Approach: group events by date; for each date and each type, place
     labels at `start_rank % N` with `N` from {4, 6, 8, 12}. Run the
     collision resolver per (date, type) region as a pure function with
     tie order `start_rank` ascending: spill horizontally if the overlapped
     neighbor halves are free in that region, otherwise stack vertically
     and grow the region by one label height per extra label. Compute row
     heights from the row model and y cumulatively across the loaded
     spans, rendering every day in a span as a row whether or not it has
     events. Because spans are contiguous and row heights depend only on
     a date's own events, a loaded span's height never changes when
     neighboring spans load. When prepending spans, offset by the new
     span's total height so visible content does not move. Switch
     revisions coherently rather than moving one event of a pair
     independently.
   - Validation: assert equal columns for each pair fetched in different
     spans before resolution, nonintersecting label rectangles after
     resolution, all label edges within viewport width including gutter
     spill, row heights matching the row model, span height independent
     of neighboring spans, and no missing/duplicate events within a
     revision. Include each of the four column counts, a date with many
     same-type collisions, an edge-column spill, a both-type date, and a
     span with no events.

## Scope and status

The layout direction is accepted; application implementation is not authorized.
Backend and frontend requirements planning has restarted at Stage 1 against
the existing Rails and Next.js scaffold. Geometry values, below-minimum viewport
behavior, label-date wording, API schemas, revision retention/restart behavior,
and unloaded scroll-height handling remain explicit decisions in the child
specifications. Timeline bounds establish date extent, not exact heights of
unloaded collision-expanded rows.

The numbered design work above is scoped into the child ROADMAP/TASKS documents;
it is not approval to cross their stage or commit checkpoints. No executable
feature integration baseline exists yet. Historical foundation validation is
preserved separately from future feature acceptance.
