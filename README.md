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
HTTP 501 responses for book detail/write actions and timeline behavior not yet
implemented. Login, book listing and admin authorization are implemented;
book routes reject missing or
invalid credentials with 401 and authenticated non-admin users with 403.

### Initial admin and login

After migrations, set `ADMIN_USERNAME` and a strong `ADMIN_PASSWORD` in the
backend environment (locally, the gitignored `.env` is supported), then run:

```sh
cd backend
bin/rails admin:provision
```

Provisioning is explicit and one-time: it fails if an admin already exists or
the username is taken, and never replaces passwords or promotes existing users.
It is not run at server boot or by staging seeds.
`POST /login` returns a password-bound bearer token valid for 12 hours.
Changing the password revokes existing tokens; book requests check the current
admin role. No refresh token or cookie session is issued.

Login permits 10 attempts per IP per 3 minutes, counting successful and failed
credentials. Further attempts return 429 with a conservative `Retry-After: 180`.
The limiter uses database-backed Solid Cache in every environment, independent
of the timeline cache; database migrations must be applied before login.
Cache unavailability raises an error rather than disabling the limit.

`TRUSTED_PROXY_CIDRS` defaults to empty: forwarded IP headers are ignored for
rate limiting unless the direct peer belongs to an explicitly configured range.
For deployment, configure only verified proxy IPs/CIDRs and ensure the ingress
sanitizes client forwarding headers. Invalid CIDRs fail application boot.
Without that configuration, clients behind a proxy share the proxy's limit.

### Manual API requests

Open [backend/requests.http](backend/requests.http) with the VS Code REST Client
extension and send requests individually against the local API. Set
`ADMIN_USERNAME` and `ADMIN_PASSWORD` in the environment inherited by the
client; never put real credentials or tokens in the tracked file.
Run `bin/rails admin:provision` before login can succeed on a fresh database.

Run login first to capture the bearer token, then create the disposable sample
book before its read/update/delete requests. The delete request targets that
sample's returned ID. Timeline requests are public; send continuation requests
only when the preceding named response has a non-null `next_cursor`.
Expected statuses describe the intended contracts; unimplemented book detail/write actions
and timeline endpoints still return 501 after applicable authentication.
Book events appear only after synchronization is implemented and
run, and cached timelines may require a refresh to expose changes.

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

Backend Stage 2 is complete and Stage 3 is in progress; model work and BE-AUTH
are implemented. Other tasks require selection; frontend remains
in requirements planning (Stage 1).
Both retain completed foundation history. Backend product
endpoints remain explicit stubs except for BE-AUTH and `GET /books`.
`bin/rails db:seed` idempotently creates staging Books only; it creates no
users or BookEvents (run `bin/rails book_events:sync` once implemented).
Unimplemented intended-behavior tests remain red. See
[backend validation evidence](docs/backend/TASKS.md) for disposable checks.
Every subproject has independent approvals. The top-level documents cover
deployment, not application tasks.

## Learning resources

- [Rails Guides](https://guides.rubyonrails.org/) and the [Rails API-only
  applications guide](https://guides.rubyonrails.org/api_app.html)
- [Next.js documentation](https://nextjs.org/docs) and [Learn
  Next.js](https://nextjs.org/learn)
- [React Learn](https://react.dev/learn)
