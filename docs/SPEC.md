# Project specification

## Problem

Our bookclub wants a single page that records when each member started and
finished the books the club has read, and that conveys reading duration
visually rather than as a plain table of dates.

## Users

- Bookclub members viewing the reading history. Whether viewing is public or
  restricted is not yet decided.
- A single admin who logs in to create, update, and delete books. The admin's
  password is set through an environment variable.

## Required behavior

- The main page is a single shared club timeline containing every book
  record (one reader reading one book) for the club.
- The timeline loads book events from a paginated endpoint and uses
  continuous scrolling: as the user scrolls toward the end of loaded content,
  the next page is fetched and appended without a page reload.
- Each book renders two labels. The start label reads
  `Reader - start_date` on the first line and `Title by Author` on the
  second. The end label reads `Reader - end_date` on the first line and
  `Title by Author` on the second.
- The vertical distance from the bottom of a book's start label to the top
  of its end label is `elapsed_days * pixels_per_day`.
- `pixels_per_day` is user-adjustable through a slider on the page. Its
  default is computed on load so that 14 days occupy half the viewport
  height: `pixels_per_day = (viewport_height / 2) / 14`.
- No minimum or maximum height per book is applied.
- Handling of overlapping books (two books whose intervals intersect) is
  deferred; the layout must not break when overlaps occur, but their visual
  treatment will be decided later.
- In-progress books (no end date) render only the start label; no end label
  and no gap are drawn.
- A book detail view fetches a single book and, if the book is completed,
  its review.
- Behavior for books with missing start dates, empty states, and loading or
  error states is not yet defined.

## Data model

- **Admin**: `username`, `password_digest` (salted hash via
  `has_secure_password`/bcrypt). Exactly one admin exists. It is created by
  a one-time rake task that reads `ADMIN_USERNAME` and `ADMIN_PASSWORD` from
  environment variables; the password is never stored in plain text or in
  the repository.
- **Book**: `reader`, `title`, `author`, `start_date`, `end_date` (nullable;
  null means in progress).
- **Review**: `book_id`, `rating`, `review` (text). A book has at most one
  review. A review is only served when the book has an `end_date`. There is
  no review write endpoint; reviews are created only by seed data for
  staging. Review creation for production is out of scope.
- **BookEvent** is not a table. It is a derived item in the API: each book
  yields a start event and, if completed, an end event, each carrying the
  `book_id` so the frontend can pair them.

## API

- `GET /book-events`: public. Cursor-paginated list of book events ordered by
  event date, each with `book_id`, event type (`start` or `end`), date,
  reader, title, and author. The response includes `next_cursor` (null on the
  last page); the client passes it back as `?cursor=` to fetch the next page.
  Page size is fixed server-side.
- `GET /books/:id`: admin-authenticated. A single book with its review when
  the book is completed.
- `POST /login`: authenticates the admin with username and password and
  returns a bearer token.
- `GET /books`, `POST /books`, `PATCH /books/:id`, `DELETE /books/:id`:
  book CRUD. All `/books` endpoints require admin authentication.

### Authentication

- `POST /login` returns `{ "token": "..." }`. Clients send it as
  `Authorization: Bearer <token>` on `/books` requests.
- The token is generated with Rails' `generates_token_for` on the `Admin`
  model, signed with `secret_key_base`, expiring after 12 hours, and bound to
  the admin's `password_salt` so a password change revokes outstanding
  tokens. No refresh tokens or server-side denylist.
- Logout is the client discarding the token. The frontend holds the token in
  memory only, never in `localStorage` or cookies.
- Unauthenticated or invalid requests to protected endpoints return 401.

## User experience

The page is a vertically scrolling timeline with continuous loading and a
slider control that adjusts `pixels_per_day`. Accessibility requirements and
supported layouts remain to be defined.

## Environments and data

- Two deployed environments are required: staging and production. Each app is
  one Vercel project; production deploys from `main`, and staging uses
  Vercel's Preview environment (deployments from non-production branches),
  with environment variables scoped to Preview and Production separately.
  Neon provides a separate database branch per environment.
- Staging data is loaded from Rails seed data (`db/seeds.rb`) in the
  repository.
- Production data is entered by the admin through the book CRUD API; any bulk
  import from an external source is out of scope for now.

## Architecture and data flow

- `backend/` is an API-only Rails 8.1.4 application, generated for Ruby 3.4.11.
- `frontend/` is a Next.js 16.4.2 app using React 19.3.0 and TypeScript.
- Databases: SQLite for local development and test; Postgres on Neon
  (provisioned through the Vercel Marketplace) for production. The Neon store
  is connected to the Rails Vercel project, which injects `DATABASE_URL`
  (pooled) and `DATABASE_URL_UNPOOLED` as runtime environment variables.
- Production uses a single primary Postgres database. Solid Cache stays and
  points at that shared database. Solid Queue and Solid Cable are dropped
  because they need long-lived processes that do not fit Vercel Functions.
- The running app uses the pooled connection string with
  `prepared_statements: false` and `advisory_locks: false`. Migrations run
  from a GitHub Actions workflow on pushes to `main` using the unpooled
  connection string; the container does not migrate on boot.
- The frontend and backend run independently on ports 3000 and 3001. No
  frontend-to-backend requests, API contract, or CORS policy has been added.
- Deployment target is Vercel for both apps: the Next.js frontend as a native
  Vercel project, and the Rails API as a separate Vercel project (root
  directory `backend/`) deployed as a container image on Vercel Functions
  built from a `Dockerfile.vercel`. Puma listens on `$PORT`; the generated
  `Dockerfile` uses Thruster on port 80 and is not used for Vercel.
- The generated dependency lockfiles record resolved package versions.

## Security and privacy

- A single admin authenticates via `POST /login` and receives a 12-hour
  bearer token; all `/books` endpoints require it. The admin password comes
  from an environment variable and is stored only as a bcrypt digest.
- Bearer tokens in the `Authorization` header are not auto-attached by
  browsers, so CSRF does not apply. XSS is the residual risk; the frontend
  keeps the token in memory only.
- CORS allows the frontend origin from a `FRONTEND_ORIGIN` environment
  variable with `headers: :any` for the `Authorization` preflight and no
  credentials.
- Keep credentials and local environment files out of version control.
- Rate limiting on `/login` must be added before production.
- At foundation time, `npm audit --omit=dev` reports no production dependency
  advisories; a full `npm audit` reports five high-severity advisories in
  development-only lint dependencies. Review compatible updates before
  expanding the dependency set; do not apply a major-version downgrade
  automatically.

## Performance and compatibility

The generated baseline targets Node.js 20.9 or newer for Next.js and Ruby
3.4.11 for the Rails app. Performance budgets and additional browser or
deployment compatibility requirements remain undefined.

## Non-goals

- Product-specific pages, API endpoints, data models, and integrations are
  outside the foundation phase.
- Production deployment and release configuration are outside the foundation
  phase.

## Acceptance criteria

- A Rails API application and a Next.js/React frontend exist in separate
  directories.
- The setup and validation commands are documented in the root README.
- Rails tests and frontend lint/build checks pass for the generated baseline.

## Unresolved questions

- Fixed page size for `/book-events`?
- What is the slider's range for `pixels_per_day`, and should the chosen
  value persist across visits?
- How should overlapping books be displayed?
- Which branch is the staging branch, and should it get a stable domain
  alias so the staging URL does not change per deployment?
- Does the app need accounts or roles beyond the single admin?
- Confirm against current Vercel docs before implementing: the exact env var
  names the Neon integration injects and the `vercel.json` schema for
  container-image functions.
- Should the browser call the API directly, or should the Next.js server proxy
  API requests?
