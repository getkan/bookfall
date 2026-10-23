# Bookfall

Bookfall is a web page that shows when the members of our bookclub started and
finished each book they have read.

## Goals

- The main page displays, for each book, when a reader began it and, further
  down the page, when they finished it.
- The vertical distance between a book's start and end markers is proportional
  to the time elapsed between those dates, so longer reads take more room on
  the page as you scroll.
- The site is built with a Rails API backend and a Next.js/React frontend and
  is deployed to Vercel. The Next.js frontend deploys natively; the Rails API
  deploys as a container image on Vercel Functions using a `Dockerfile.vercel`
  (see [Vercel's Rails guide](https://vercel.com/kb/guide/does-vercel-support-ruby-on-rails-applications)
  and [container images](https://vercel.com/docs/functions/container-images)).

Product details beyond the goals above are still being defined; see
[docs/SPEC.md](docs/SPEC.md).

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
bin/rails db:prepare
bin/rails server -p 3001
```

In another terminal:

```sh
cd frontend
npm ci
npm run dev -- --port 3000
```

The frontend is available at <http://localhost:3000>. The Rails API listens on
<http://localhost:3001>. No application endpoints or frontend-to-backend
integration have been defined yet.

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

See [docs/SPEC.md](docs/SPEC.md) for known requirements and unresolved product
decisions, [docs/ROADMAP.md](docs/ROADMAP.md) for delivery phases, and
[docs/TASKS.md](docs/TASKS.md) for current work.

## Learning resources

- [Rails Guides](https://guides.rubyonrails.org/) and the [Rails API-only
  applications guide](https://guides.rubyonrails.org/api_app.html)
- [Next.js documentation](https://nextjs.org/docs) and [Learn
  Next.js](https://nextjs.org/learn)
- [React Learn](https://react.dev/learn)
