# Bookfall

Bookfall is a web page that shows when the members of our bookclub started and
finished each book they have read.

## Goals

- The main page displays, for each book, when a reader began it and, further
  down the page, when they finished it.
- The timeline uses calendar-day rows with fixed-size event labels. Empty
  days have uniform height; event types and collision stacking can expand a
  day's row. Rank-based columns keep event pairs associated, with spill/stack
  resolution to prevent label overlap. There is no pixels-per-day slider.
- The site is built with a Rails API backend and a Next.js/React frontend and
  targets Vercel after both subprojects are completed. The proposed Next.js
  deployment is native; the proposed Rails API deployment is a container
  image on Vercel Functions using a `Dockerfile.vercel`
  (see [Vercel's Rails guide](https://vercel.com/kb/guide/does-vercel-support-ruby-on-rails-applications)
  and [container images](https://vercel.com/docs/functions/container-images)).

Product details are being re-established in the
[backend specification](docs/backend/SPEC.md) and
[frontend specification](docs/frontend/SPEC.md), using the accepted
[timeline layout](docs/BOOKEVENT_TIMELINE_LAYOUT_PLAN.md).

## Stack

- Backend: Ruby 3.4.11, Rails 8.1.4, API-only application
- Frontend: Next.js 16.4.2, React 19.3.0, TypeScript, Node.js 20.9 or newer
- Databases: SQLite for local development and test; PostgreSQL (Neon via
  Vercel) in production, read from `DATABASE_URL`. Solid Cache stores
  `Rails.cache` in the primary database.

## Requirements

- Ruby 3.4.11 and Bundler
- Ruby development headers and a C compiler for native gems
- Node.js 20.9 or newer and npm

## Run locally

In one terminal:

```sh
cd backend
bundle install
bin/rails db:migrate
bin/rails server -p 3001
```

In another terminal:

```sh
cd frontend
npm ci
npm run dev -- --port 3000
```

The frontend is available at <http://localhost:3000>. The Rails API listens on
<http://localhost:3001>. Backend product routes currently return explicit
HTTP 501 responses; business logic and frontend-to-backend integration are
not implemented yet.

## Validation

```sh
cd backend
bin/rails test
```

```sh
cd frontend
npm run lint
npm run build
```

## Planning documents

| Subproject | Requirements | Lifecycle and approvals | Tasks and validation |
| --- | --- | --- | --- |
| Backend | [SPEC](docs/backend/SPEC.md) | [ROADMAP](docs/backend/ROADMAP.md) | [TASKS](docs/backend/TASKS.md) |
| Frontend | [SPEC](docs/frontend/SPEC.md) | [ROADMAP](docs/frontend/ROADMAP.md) | [TASKS](docs/frontend/TASKS.md) |
| Deployment, after both complete | [SPEC](docs/SPEC.md) | [ROADMAP](docs/ROADMAP.md) | [TASKS](docs/TASKS.md) |

Backend is in Stage 2 (architecture/skeleton); frontend remains in requirements
planning (Stage 1). Both retain completed foundation history. Backend product
endpoints deliberately return HTTP 501 until Stage 3; its intended-behavior
tests are expected red, and fresh setup must use `bin/rails db:migrate` rather
than `db:prepare`, whose seed loader is also an explicit stub. See
[backend validation evidence](docs/backend/TASKS.md) for disposable checks.
Every subproject has independent approvals. The top-level documents cover
deployment, not application tasks.

## Learning resources

- [Rails Guides](https://guides.rubyonrails.org/) and the [Rails API-only
  applications guide](https://guides.rubyonrails.org/api_app.html)
- [Next.js documentation](https://nextjs.org/docs) and [Learn
  Next.js](https://nextjs.org/learn)
- [React Learn](https://react.dev/learn)
