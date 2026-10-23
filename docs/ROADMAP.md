# Project roadmap

## Completed: Foundation

Generated `backend/` (Rails 8.1.4 API-only) and `frontend/` (Next.js 16.4.2),
added the root README and planning documents. Validated with `bin/rails test`
(1 test), `npm run lint && npm run build`, and an HTTP 200 smoke check of the
frontend. See `docs/TASKS.md` for the full validation record.

## Phase 1: Backend implementation and testing

### Outcome

The Rails API stores admins, books, and reviews; serves paginated book events,
book detail with review, and admin-authenticated book CRUD; seeds staging
data; and is configured for SQLite locally and Neon Postgres in production.

### Included work

- Models and migrations:
  - `Admin` with `username` and `password_digest` (`has_secure_password`,
    bcrypt) and `generates_token_for :api_access` (12-hour expiry, bound to
    `password_salt`). A one-time rake task creates the single admin from
    `ADMIN_USERNAME`/`ADMIN_PASSWORD` environment variables.
  - `Book` with `reader`, `title`, `author`, `start_date`, nullable
    `end_date`; validation that `end_date` is not before `start_date`.
  - `Review` with `book_id`, `rating`, `review`; one review per book; no
    write endpoint.
- API endpoints:
  - `GET /book-events` (public): cursor-paginated start/end events derived
    from books, ordered by event date, each with `book_id`, type, date,
    reader, title, author, plus `next_cursor`.
  - `GET /books/:id` (admin): book with its review included only when
    `end_date` is present.
  - `POST /login`: admin authentication returning a bearer token.
  - `GET/POST/PATCH/DELETE /books` (admin): CRUD. All `/books` routes require
    `Authorization: Bearer <token>`.
- `db/seeds.rb` with staging books and reviews, including in-progress and
  overlapping books.
- CORS configuration (`rack-cors`) allowing `FRONTEND_ORIGIN` with
  `headers: :any` and no credentials.
- Database configuration: add the `pg` gem for production; keep `sqlite3` for
  development and test. Collapse production `database.yml` to a single
  primary database read from `DATABASE_URL` with `prepared_statements: false`
  and `advisory_locks: false`. Point Solid Cache at it; remove Solid Queue,
  Solid Cable, and the Redis `cable.yml` entry.
- Testing: model tests (validations, review-per-book, admin password, token
  round-trip, expiry, revocation on password change), request tests for every
  endpoint including cursor boundaries and last page, 401 on missing, invalid,
  expired, and tampered tokens, review omitted for in-progress books, CORS
  preflight headers, and a seeds test.

### Dependencies and risks

- Production config can only be smoke-tested locally against a Postgres
  container, not against Neon, until Phase 3.
- `FRONTEND_ORIGIN` for staging depends on a stable Vercel preview alias
  (Phase 3 open item).
- Rate limiting on `/login` is deferred to Phase 3 readiness.

### Exit criteria

- `bin/rails test` passes on SQLite with coverage for all models, all
  endpoints, authentication, and seeds.
- `RAILS_ENV=production DATABASE_URL=<local postgres> bin/rails runner
  'ActiveRecord::Base.connection.execute("select 1")'` succeeds.
- `bin/rails db:seed` loads the staging data without error and is idempotent.

### Validation

- Automated: `bin/rails test`; `bin/rubocop`; `bin/brakeman`.
- Manual: `curl` each endpoint locally, including a login followed by an
  authenticated create and an unauthenticated create that is rejected.

## Phase 2: Frontend implementation and testing

### Outcome

The Next.js page renders the shared club timeline from the API with start and
end labels separated by a height proportional to elapsed days, adjustable by a
slider.

### Included work

- Fetch book events from `GET /book-events` using a configurable base URL,
  with continuous scrolling: load the next page as the user nears the end of
  loaded content and append it; pair start and end events by `book_id`.
- Render each book's start label (`Reader - start_date` /
  `Title by Author`) and end label (`Reader - end_date` / `Title by Author`),
  with the gap from the bottom of the start label to the top of the end label
  equal to `elapsed_days * pixels_per_day`.
- In-progress books (no end date) render only the start label.
- Slider controlling `pixels_per_day`, defaulting to
  `(viewport_height / 2) / 14` on load.
- Component tests for label text, gap computation, in-progress handling,
  event pairing across page boundaries, continuous-scroll loading, and the
  slider default.

### Dependencies and risks

- Depends on the Phase 1 `/book-events` contract and pagination style.
- An end event may arrive in a later page than its start event; the layout
  must handle a start without a yet-loaded end.
- Overlapping books have no agreed visual treatment; the layout must
  degrade without breaking.
- Slider range and persistence are undecided; use a sensible range and no
  persistence until decided.

### Exit criteria

- Page renders seeded books with labels in the agreed format and measured
  gaps matching the formula.
- Scrolling to the end of loaded content loads the next page until the API
  reports no more pages.
- Moving the slider rescales gaps; in-progress books show one label.
- `npm run lint`, `npm run build`, and the component tests pass.

### Validation

- Automated: `npm run lint && npm run build && npm test`.
- Manual: browser check that scrolling reveals end labels and loads further
  pages, gap heights scale with elapsed days, and the slider changes the
  scale.

## Phase 3: Vercel deployment

### Outcome

Both apps deploy to Vercel with a Production environment from `main` and a
staging environment on Vercel Preview, backed by Neon Postgres with a branch
per environment, and migrations run from GitHub Actions.

### Included work

- `backend/Dockerfile.vercel` running Puma on `$PORT` with `libpq5`, no
  Thruster, and no migration on boot (`bin/docker-entrypoint` adjusted).
- `backend/vercel.json` for container-image functions; Rails Vercel project
  with root directory `backend/`; Next.js Vercel project with root directory
  `frontend/`.
- Neon store connected to the Rails project; env vars (`DATABASE_URL`,
  `DATABASE_URL_UNPOOLED`, `RAILS_MASTER_KEY`, `RAILS_MAX_THREADS`,
  `FRONTEND_ORIGIN`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`) scoped
  separately to Preview and Production. Frontend API base URL scoped per
  environment.
- GitHub Actions workflow running `bin/rails db:migrate` against the unpooled
  URL for the matching environment on pushes to `main` and the staging
  branch, plus `db:seed` for staging.
- README deployment section.

### Dependencies and risks

- Requires a Neon store and both Vercel projects created in the dashboard,
  and repository secrets for the workflow.
- Deploy and migrate are not atomic; schema changes must be backward
  compatible with the previously deployed code.
- Vercel container docs must be confirmed for the `vercel.json` schema and
  the Neon integration's env var names.
- Staging branch name and stable domain alias are undecided.

### Exit criteria

- `Dockerfile.vercel` image boots locally with `PORT` set and `/up` returns
  200 against a Postgres `DATABASE_URL`.
- Staging (preview) and production deployments of both apps succeed; the
  frontend renders records from its matching API environment.
- Migration workflow completes with `db:migrate:status` showing all
  migrations up in both environments.

### Validation

- Automated: `docker build -f Dockerfile.vercel`; workflow run on the staging
  branch and on `main`.
- Manual: `curl` local container and deployed `/up` endpoints; load the
  staging and production frontends; inspect Vercel logs for connection
  errors.
